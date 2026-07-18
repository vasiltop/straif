# Gameplay

Covers the four playable modes and the shared `Player` controller. For how a
mode's runtime dependencies get selected/injected, see
[architecture.md](./architecture.md); for dedicated-server specifics see
[game-server.md](./game-server.md).

## Modes

| Mode | Scene/script | Players | Mode string(s) | Notes |
| --- | --- | --- | --- | --- |
| Speedrun | `src/maps/speedrun.gd` (`class_name Map`), maps in `src/maps/speedrun/*.tscn` | 1 (local, `multiplayer_peer = null`) | `target`, `bhop` | Timed run + target-clearing, ghost replays. |
| Deathmatch | `src/maps/deathmatch.gd`, maps in `src/maps/deathmatch/*.tscn` | Multiplayer (ENet) | `deathmatch` | Free-for-all, respawn on death. |
| Elimination | `src/maps/elimination.gd`, maps in `src/maps/elimination/*.tscn` | Multiplayer (ENet), 2 teams | `elimination` | Round-based, freeze/live/match-end phases. |
| Aim | `src/maps/aim/aim_trainer.gd` | 1 (local, `multiplayer_peer = null`) | `gridshot`, `flick`, `tracking` (scenarios, not pvp modes) | Timed accuracy trainer with its own leaderboard. |

Deathmatch/elimination are the two values `GameManager.pvp_mode_to_map`
recognizes (`src/game_manager.gd`); the dedicated server and the multiplayer
menu (`src/menus/multiplayer/multiplayer.gd`) only offer these two.

Both `Deathmatch` and `Elimination` extend `MultiplayerGame`
(`src/maps/multiplayer_game.gd`), which factors out their shared `PlayerScene`
preload, `get_player(id)`/`get_players()` roster lookup, and
`get_current_map_path()` (built from `Global.game_manager.current_pvp_mode`/
`current_pvp_map`).

### Speedrun (`Map`, `src/maps/speedrun.gd`)

- Single player; `_ready()` sets `Global.multiplayer.multiplayer_peer = null`
  and `player.hardcore = false` (disables the movement-spread-while-airborne
  penalty, see below).
- `start_zone`/`end_zone` `Area3D`s: exiting the start zone begins the run
  (`_start_run()`); entering the end zone with all targets cleared
  (`target_container.get_child_count() == 0`) triggers `_win()`, which stops
  the timer, plays a win sound, and calls
  `Global.server_bridge.publish_run(current_mode, recording_bytes, current_map.name, time_ms)`.
- `Killzone` (`src/maps/killzone.gd`) is an `Area3D` that calls `map.restart(player)`
  when the player enters it (out-of-bounds/void).
- Every physics frame while running, `_recorder_process()` captures inputs,
  position, rotation, ammo, and target state into a `Recorder.Frame` for replay
  (`src/recorder.gd`); replays scrub via `map_ui.replay_slider` and can be
  requested/played back through `Global.game_manager.replay_requested`.
- `reset_weapon_pickups()`/`reset_targets()` branch on `current_mode == "target"`:
  target mode resets weapon pickups and (re)spawns targets from
  `target_spawns_container`; `bhop` deactivates weapon pickups and spawns no
  targets.
- Map/mode selection happens from the main menu
  (`src/menus/main/map_button/map_button.gd`): pressing Play sets
  `Global.game_manager.current_map`/`current_mode` and changes scene directly
  to `res://src/maps/speedrun/<map_name>.tscn` — no server involved.

### Deathmatch (`src/maps/deathmatch.gd`)

- On join, a client RPCs `_send_info` to the server (peer id `1`), which
  replies with the current map, every existing player's position/weapon, then
  spawns the new player at a random `Spawns` child position with weapon index
  `1`.
- On death (`Player.dead` signal, server-only listener `_on_player_death`):
  logs a kill-feed line, ragdolls the victim, waits 1.5s
  (`await get_tree().create_timer(1.5).timeout`), then calls `respawn()` and
  repositions to a new random spawn. Damage is never explicitly disabled
  between deaths in this mode (see damage gating below).
- Map rotates automatically every `DmUi.TIME_PER_MAP` (180s), tracked by
  `DmUi`'s server-only countdown; `new_map()` also re-randomizes every
  connected player's spawn point.
- Players can request any weapon at any time via `DmUi`'s weapon-select panel
  (held `leaderboard` action), which RPCs `set_weapon_to_index` to both the
  requester and the server.

### Elimination (`src/maps/elimination.gd`)

Round state machine, server-authoritative, `enum Phase { WAITING, FREEZE, LIVE, MATCH_END }`:

| Phase | Duration | Behavior |
| --- | --- | --- |
| `WAITING` | — | Waits until both teams have ≥1 player (`has_enough_players()`); players are frozen, damage disabled. |
| `FREEZE` | `FREEZE_TIME` = 4s | Players reset to team spawns, frozen, damage disabled. |
| `LIVE` | `ROUND_TIME` = 60s | Damage enabled, players unfrozen; ends early once one team is fully eliminated or on round timeout. |
| `MATCH_END` | `MATCH_END_TIME` = 8s | Shown after a team reaches `WIN_SCORE` = 5 round wins; damage disabled, then `_reset_match()` picks a new map and restarts at `FREEZE`. |

- New joiners are assigned to the smaller team, or alternate
  (`_next_tie_team`) when team sizes are equal.
- **Damage gating**: `player.set_damage_enabled.rpc(...)` is the only place
  that flips `Player.damage_enabled`, and elimination calls it explicitly for
  every phase transition (`true` only entering `LIVE`; `false` entering
  `FREEZE`/`MATCH_END`/`WAITING`, and for a just-joined player when the phase
  isn't `LIVE`). This is the mode that makes real use of the phase gate
  described under [Player damage](#damage-and-death).
- On death, the victim is ragdolled and frozen server-side; the round is
  re-evaluated (`_evaluate_live_round()`), ending immediately if either team
  has 0 living players.
- **Spectate**: while the local player is dead, `EliminationUi._update_spectator()`
  cycles through living teammates (`attack` action advances to the next one),
  calling `Player.begin_local_spectate_view()` / `end_local_spectate_view()` on
  the target so the dead player's camera follows a teammate's first-person
  view; falls back to the player's own ragdoll camera if no teammates remain.

### Aim (`src/maps/aim/aim_trainer.gd`)

- Single player; clears `multiplayer.multiplayer_peer` on ready. Scenario is
  resolved from `Global.game_manager.get_current_aim_scenario()` (defaults to
  `"gridshot"` if unset/invalid).
- Fixed session shape: `COUNTDOWN_DURATION` = 3s, then `SESSION_DURATION` = 60s
  of live scoring, then results + leaderboard submission.
- Scenarios: `gridshot` (3 concurrent targets in a 3×3 grid, respawn on hit),
  `flick` (single target that repositions ≥1.35 units away on hit),
  `tracking` (single moving target sampled every `TRACKING_SAMPLE_INTERVAL` =
  0.05s via a center-screen raycast; no discrete "shots").
  `player.weapon_handler.unlimited_ammo = true` and shooting is disabled during
  `tracking`.
  Scoring: `_gridshot_hit_score`/`_flick_hit_score` reward faster reaction
  time; `tracking` awards `TRACKING_SCORE_PER_SAMPLE` = 8 points per on-target
  sample.
- On session end, submits via `Global.server_bridge.submit_aim_score(...)` and
  loads `Global.server_bridge.get_aim_scores(scenario, 1)` for the scenario
  leaderboard.

## Player (`src/player/player.gd`)

### Movement

Source-engine-style ground/air movement in `_movement_process()`:
`MAX_G_SPEED` = 5.5, `MAX_G_ACCEL` = 44 (ground), `MAX_A_SPEED` = 0.8,
`MAX_A_ACCEL` = 220 (air), `JUMP_FORCE` = 4, gravity = 12. `grounded()` uses
`test_move(global_transform, Vector3(0, -0.01, 0))`. Ground friction is
applied only when grounded and not jumping; air strafing has no friction.
`is_pre_capped` (set by the speedrun `Map`) clamps ground speed to `MAX_PRE`
= 7.5 until the player's first jump, then is cleared permanently for that run.
State syncs to remote peers every physics frame via an unreliable
`_update_state` RPC (position, yaw, camera pitch, speed).

### Weapon

Delegated to the `WeaponHandler` child (`src/player/weapon/weapon_handler.gd`):
equip/reload/fire, sway, recoil, muzzle flash/tracer/bullet-hole/blood VFX,
melee hitbox toggling, and sniper-scope FOV changes. `WeaponData` resources
(`src/player/weapon/resources/*.tres`) define `name`, `weapon_shot_delay`,
`damage`, `scene`, `shoot_sound`, `recoil`, `attack_range`, `is_melee`,
`automatic`, `is_sniper`, `spread`, `moving_spread`, `bullet_count`,
`mag_ammo`, `reserve_ammo`. `moving_spread` only applies when the shooter is
airborne **and** `player.hardcore` is true — speedrun and aim trainer set
`hardcore = false`; deathmatch/elimination leave it at the default `true`.

### Damage and death

`BodyPart.apply_damage()` is the entry point from a hit: in multiplayer it
RPCs `owned_by.on_damage.rpc_id(1, amount * multiplier, weapon_name)` to peer
id `1` (the authority/server); offline (`not Global.mp()`) it calls
`_apply_authoritative_damage()` directly.

```gdscript
# src/player/player.gd
@rpc("call_remote", "any_peer", "reliable")
func on_damage(value, weapon_name) -> void:
    if not Global.is_sv():
        return
    _apply_authoritative_damage(value, weapon_name, multiplayer.get_remote_sender_id())
```

`_apply_authoritative_damage()` is the single authoritative damage path (real
server, or the local peer acting as its own authority offline). It is a no-op
unless `damage_enabled` is true, the player is not already `is_dead`, and
`value > 0`. On lethal damage it sets `damage_enabled = false` and emits
`dead(sender, pid, weapon_name)`; the health change is pushed back to the
owning client via `_sync_health` (RPC in multiplayer, direct call offline).

**`damage_enabled` phase gating**: the flag defaults to `true` and is only
ever changed through the `set_damage_enabled` RPC. Elimination is the mode
that actively drives it (disabled outside the `LIVE` phase, see above);
deathmatch and the single-player modes never toggle it, so damage stays
enabled continuously in those modes (deathmatch relies on ragdoll + a fixed
respawn delay instead of a freeze phase).

### View and spectate

`refresh_view_visibility()` decides first-person vs third-person rendering:
first-person view (viewmodel + hidden body) applies when `is_me()` or the
player is under local spectate; the viewmodel/gun viewport is additionally
hidden while `is_dead`. `ragdoll()` (RPC) starts physical bone simulation,
disables movement/damage, hides the weapon viewmodel, and — for the locally
controlled player — switches to the `ragdoll_camera` (third-person, death
view). `respawn(enable_damage)` (RPC) reverses all of this and restores the
first-person camera/viewmodel for the local player.

`begin_local_spectate_view()` / `end_local_spectate_view()` let one client
temporarily view another `Player` instance in first person (used only by
elimination's dead-player spectate cycle, see above); they make that player's
cameras current and force first-person rendering regardless of whether it is
the local player's own body.

## UI responsibilities

| Script | Scope |
| --- | --- |
| `MapUi` (`src/maps/map_ui.gd`) | Speedrun HUD: timer, target counter, speed readout, ammo, replay scrubber/controls. |
| `DmUi` (`src/maps/dm_ui.gd`) | Deathmatch HUD: kill feed, join/leave log, ammo/health, map time-left, weapon-select panel. |
| `EliminationUi` (`src/maps/elimination_ui.gd`) | Elimination HUD: phase/timer/team-score banner, held-key scoreboard, spectator label, match-end banner, ammo/health. |
| Aim trainer's own `@export` labels/panels | Countdown/score/stat readouts and results/leaderboard panel, driven directly by `AimTrainer` (no separate UI class). |

## Map and weapon resources

- `maps.json` (repo root) lists speedrun maps: `name`, `tier`, `modes`
  (`target`/`bhop`), and per-mode medal time arrays (`medals_target`,
  `medals_bhop`). Loaded by `MapManager.load_maps()`
  (`src/maps/map_manager.gd`) into `MapData` resources
  (`src/maps/map_data.gd`).
- `MapManager.get_random_map(mode)` picks a random `.tscn` by scanning
  `res://src/maps/<mode>/`; `get_full_map_path(mode, name)` builds the load
  path used by deathmatch/elimination when changing maps.
- Weapon resources live under `res://src/player/weapon/resources/*.tres` and
  are loaded once into `GameManager.weapons` (index `0` is reserved/`null` for
  "no weapon").
