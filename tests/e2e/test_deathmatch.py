#!/usr/bin/env python3
import time
import unittest

from cluster import Cluster, SERVER_INSTANCE, ALICE_INSTANCE, BOB_INSTANCE

FIXTURE_PATH = "res://tests/e2e/fixtures/deathmatch_arena.tscn"
ALICE_POSITION = [0.0, 1.0, 0.0]
BOB_POSITION = [0.0, 1.0, -4.0]
POSITION_TOLERANCE = 0.5
FULL_HEALTH = 100.0
TEST_BUDGET_SECONDS = 210


def player_by_pid(snapshot, pid):
    for player in snapshot.get("players", []):
        if player["pid"] == pid:
            return player
    return None


def player_by_name(snapshot, name):
    for player in snapshot.get("players", []):
        if player["name"] == name:
            return player
    return None


def close_enough(actual, expected):
    return all(abs(actual[axis] - expected[axis]) <= POSITION_TOLERANCE for axis in range(3))


class DeathmatchVerticalSliceTest(unittest.TestCase):
    def setUp(self):
        self.cluster = Cluster()
        self.addCleanup(self.cluster.stop)
        self.deadline = time.monotonic() + TEST_BUDGET_SECONDS

    def snapshot(self, instance):
        return self.cluster.command(instance, "snapshot")

    def _check_budget(self, description):
        if time.monotonic() > self.deadline:
            self.fail("overall test budget of %ds exceeded while waiting for %s" % (TEST_BUDGET_SECONDS, description))

    def poll(self, description, produce, timeout, interval=0.15):
        deadline = time.monotonic() + timeout
        observation = None
        while True:
            self._check_budget(description)
            observation = produce()
            if observation:
                return observation
            if time.monotonic() > deadline:
                self.fail("timed out after %.1fs waiting for %s; last observation: %r" % (timeout, description, observation))
            time.sleep(interval)

    def player_count_reached(self, instance, count):
        def produce():
            snapshot = self.snapshot(instance)
            if len(snapshot.get("players", [])) >= count:
                return snapshot
            return None
        return produce

    def test_deathmatch_vertical_slice(self):
        cluster = self.cluster

        cluster.start_server()
        cluster.await_connection(SERVER_INSTANCE)

        cluster.start_client(ALICE_INSTANCE)
        cluster.await_connection(ALICE_INSTANCE)
        self.poll(
            "Alice spawns before Bob joins",
            lambda: self.snapshot(SERVER_INSTANCE) if player_by_name(self.snapshot(SERVER_INSTANCE), "Alice") else None,
            timeout=30,
        )

        cluster.start_client(BOB_INSTANCE)
        cluster.await_connection(BOB_INSTANCE)

        for instance in (SERVER_INSTANCE, ALICE_INSTANCE, BOB_INSTANCE):
            self.poll("two players spawned on %s" % instance, self.player_count_reached(instance, 2), timeout=45)

        server_snapshot = self.snapshot(SERVER_INSTANCE)
        alice = player_by_name(server_snapshot, "Alice")
        bob = player_by_name(server_snapshot, "Bob")
        self.assertIsNotNone(alice, "server must know a player named Alice: %r" % server_snapshot)
        self.assertIsNotNone(bob, "server must know a player named Bob: %r" % server_snapshot)
        alice_pid = alice["pid"]
        bob_pid = bob["pid"]

        alice_view = self.snapshot(ALICE_INSTANCE)
        bob_view = self.snapshot(BOB_INSTANCE)
        self.assertEqual(player_by_pid(alice_view, bob_pid)["name"], "Bob", "Alice must see the other player as Bob")
        self.assertEqual(player_by_pid(bob_view, alice_pid)["name"], "Alice", "Bob must see the other player as Alice")

        fixture = self.cluster.command(SERVER_INSTANCE, "load_fixture", {"path": FIXTURE_PATH})
        self.assertTrue(fixture.get("loaded"), "server must load the arena fixture: %r" % fixture)
        for instance in (SERVER_INSTANCE, ALICE_INSTANCE, BOB_INSTANCE):
            self.poll(
                "fixture observed on %s" % instance,
                lambda instance=instance: self.snapshot(instance) if self.snapshot(instance)["fixture"]["path"] == FIXTURE_PATH else None,
                timeout=30,
            )

        self.cluster.command(ALICE_INSTANCE, "teleport", {"position": ALICE_POSITION})
        self.cluster.command(BOB_INSTANCE, "teleport", {"position": BOB_POSITION})

        def mirrors_converged():
            server_state = self.snapshot(SERVER_INSTANCE)
            alice_state = self.snapshot(ALICE_INSTANCE)
            bob_state = self.snapshot(BOB_INSTANCE)
            server_alice = player_by_pid(server_state, alice_pid)
            server_bob = player_by_pid(server_state, bob_pid)
            bob_sees_alice = player_by_pid(bob_state, alice_pid)
            alice_sees_bob = player_by_pid(alice_state, bob_pid)
            if not all([server_alice, server_bob, bob_sees_alice, alice_sees_bob]):
                return None
            if close_enough(server_alice["position"], ALICE_POSITION) \
                    and close_enough(server_bob["position"], BOB_POSITION) \
                    and close_enough(bob_sees_alice["position"], ALICE_POSITION) \
                    and close_enough(alice_sees_bob["position"], BOB_POSITION):
                return True
            return None

        self.poll("teleport mirrors to converge", mirrors_converged, timeout=30)

        self.cluster.command(ALICE_INSTANCE, "equip_ak47")
        self.poll(
            "Alice AK47 ready",
            lambda: self.snapshot(ALICE_INSTANCE) if _weapon_ready(self.snapshot(ALICE_INSTANCE), "Ak47") else None,
            timeout=30,
        )

        self.cluster.command(ALICE_INSTANCE, "aim", {"target": bob_pid})

        first_hit = self.poll(
            "Alice's first shot to hit Bob",
            lambda: _fired_hit(self.cluster.command(ALICE_INSTANCE, "fire"), bob_pid),
            timeout=30,
        )
        self.assertTrue(first_hit["decremented"], "first shot must decrement the magazine: %r" % first_hit)
        self.assertEqual(first_hit["ammo_after"], first_hit["ammo_before"] - 1, "first shot removes one round: %r" % first_hit)
        self.assertTrue(first_hit["hit_is_body_part"], "first shot must hit a body part: %r" % first_hit)
        self.assertEqual(first_hit["hit_pid"], bob_pid, "first shot must hit Bob: %r" % first_hit)

        self.poll(
            "server observes Bob taking damage",
            lambda: True if player_by_pid(self.snapshot(SERVER_INSTANCE), bob_pid)["health"] < FULL_HEALTH else None,
            timeout=20,
        )
        self.poll(
            "Bob observes his own health drop",
            lambda: True if player_by_pid(self.snapshot(BOB_INSTANCE), bob_pid)["health"] < FULL_HEALTH else None,
            timeout=20,
        )
        self.poll(
            "tracer and blood effects recorded on Alice",
            lambda: True if _effects(self.snapshot(ALICE_INSTANCE), "tracer") >= 1 and _effects(self.snapshot(ALICE_INSTANCE), "blood") >= 1 else None,
            timeout=20,
        )

        def bob_is_dead_on_server():
            server_state = self.snapshot(SERVER_INSTANCE)
            record = player_by_pid(server_state, bob_pid)
            if record is not None and record["dead"]:
                return server_state
            return None

        kill_deadline = time.monotonic() + 45
        while bob_is_dead_on_server() is None:
            self._check_budget("Bob to die from repeated fire")
            if time.monotonic() > kill_deadline:
                self.fail("Bob never died from repeated fire; server: %r" % self.snapshot(SERVER_INSTANCE))
            self.cluster.command(ALICE_INSTANCE, "aim", {"target": bob_pid})
            self.cluster.command(ALICE_INSTANCE, "fire")
            time.sleep(0.1)

        for instance in (ALICE_INSTANCE, BOB_INSTANCE):
            self.poll(
                "%s killfeed announces the kill" % instance,
                lambda instance=instance: True if _killfeed_has(self.snapshot(instance), ["Alice", "Bob", "Ak47"]) else None,
                timeout=20,
            )

        self.poll(
            "Bob respawns with restored health",
            lambda: True if _alive_full_health(player_by_pid(self.snapshot(SERVER_INSTANCE), bob_pid)) else None,
            timeout=20,
        )
        self.poll(
            "Bob observes his own respawn",
            lambda: True if _alive_full_health(player_by_pid(self.snapshot(BOB_INSTANCE), bob_pid)) else None,
            timeout=20,
        )

        before_reload = self.snapshot(ALICE_INSTANCE)["weapon"]
        self.assertLess(before_reload["mag"], before_reload["max"], "magazine must be partially spent before reload")
        reload_result = self.cluster.command(ALICE_INSTANCE, "reload")
        self.assertEqual(reload_result["mag"], reload_result["max"], "reload must refill the magazine: %r" % reload_result)
        self.poll(
            "Alice magazine restored",
            lambda: True if _weapon_full(self.snapshot(ALICE_INSTANCE)) else None,
            timeout=20,
        )

        self.cluster.terminate(BOB_INSTANCE)
        for instance in (SERVER_INSTANCE, ALICE_INSTANCE):
            self.poll(
                "%s removes disconnected Bob" % instance,
                lambda instance=instance: True if player_by_pid(self.snapshot(instance), bob_pid) is None else None,
                timeout=45,
            )

        self.cluster.command(ALICE_INSTANCE, "shutdown")
        self.cluster.command(SERVER_INSTANCE, "shutdown")


def _weapon_ready(snapshot, name):
    weapon = snapshot.get("weapon")
    return bool(weapon) and weapon.get("name") == name and weapon.get("ready")


def _weapon_full(snapshot):
    weapon = snapshot.get("weapon")
    return bool(weapon) and weapon.get("mag") == weapon.get("max")


def _fired_hit(result, target_pid):
    if result.get("fired") and result.get("hit_pid") == target_pid:
        return result
    return None


def _effects(snapshot, kind):
    return snapshot.get("effects", {}).get(kind, 0)


def _killfeed_has(snapshot, needles):
    for line in snapshot.get("killfeed", []):
        if all(needle in line for needle in needles):
            return True
    return False


def _alive_full_health(record):
    return record is not None and not record["dead"] and record["health"] >= FULL_HEALTH


if __name__ == "__main__":
    unittest.main()
