# Game server

Dedicated-server operation: invocation, networking, supported modes, server
browser publication, player lifecycle, and troubleshooting. For the
composition-root code that selects server adapters, see
[architecture.md](./architecture.md); for mode gameplay rules see
[gameplay.md](./gameplay.md).

## Invocation

```
<binary> server <name> <port> <max_players> <mode> [--e2e --e2e-instance <name> --e2e-control-port <port>]
```

Parsed by `RuntimeOptions.parse()` (`src/app/runtime_options.gd`):

| Argument | Constraint |
| --- | --- |
| `<name>` | Non-empty, must not start with `--`. |
| `<port>` | Integer, `1`–`65535`. |
| `<max_players>` | Integer, `> 0`. |
| `<mode>` | Non-empty, must not start with `--`; only `deathmatch` and `elimination` are wired to a map (see [Supported modes](#supported-modes)). |

Real-world example (exported Linux binary, headless):

```bash
./straif.x86_64 server DM-1 3005 8 deathmatch --headless
```

`--headless` is a native Godot engine flag, not part of `RuntimeOptions`; it
must come after the `server ...` arguments as shown. `--offline-playtest` is
rejected on a `server` launch (it is a client-only profile). `--e2e` **is**
accepted on a `server` launch, but only inside an editor/test build and only
together with `--e2e-instance`/`--e2e-control-port`; it selects the in-memory
recording registry used by the end-to-end harness (see
[Offline playtest and E2E](#offline-playtest-and-e2e)). Dockerized
deployment (`docker/`, `scripts/game-server-docker.sh`) and Steam upload are
documented in the repository [README](../README.md); this document covers the
runtime behavior of the binary itself once launched.

## ENet networking

`GameManager.init_server()` (`src/game_manager.gd`):

```gdscript
var peer := ENetMultiplayerPeer.new()
var err := peer.create_server(_options.port, _options.max_players)
```

- On failure (e.g. port already in use), `create_server` returns a non-OK
  `Error`; the server logs `push_error("Failed to create server on port %d: %s" % ...)`
  and returns **without** exiting the process — `multiplayer.multiplayer_peer`
  is left unset, so the process keeps running but never accepts connections.
- On success, `multiplayer.multiplayer_peer` is assigned, `is_server`/`port`/
  `max_players`/`current_pvp_mode`/`server_name` are set from `RuntimeOptions`,
  a random map for `mode` is chosen (`MapManager.get_random_map`), the scene
  changes to `pvp_mode_to_map[mode]`, and the server-browser ping timer
  starts.

## Supported modes

`GameManager.pvp_mode_to_map` is the source of truth:

```gdscript
var pvp_mode_to_map := {
    "deathmatch": "res://src/maps/deathmatch.tscn",
    "elimination": "res://src/maps/elimination.tscn"
}
```

Only `deathmatch` and `elimination` are supported. `<mode>` is not validated
against this list before startup — an unrecognized value fails at
`MapManager.get_random_map(mode)` (scans a nonexistent
`res://src/maps/<mode>/` directory) or at the `pvp_mode_to_map[mode]` lookup,
both of which raise a script error rather than a clean validation message.

## Map selection

- **Startup**: `MapManager.get_random_map(mode)` scans `res://src/maps/<mode>/*.tscn`
  and picks one at random.
- **Deathmatch**: rotates automatically every `DmUi.TIME_PER_MAP` (180s),
  independent of round/match state; `new_map()` also respawns every connected
  player.
- **Elimination**: picks a new random map after every completed match
  (`_reset_match()` → `_new_map()`), retrying up to 8 times to avoid repeating
  the just-played map.

## Server browser publication

Every `GameManager.SERVER_BROWSER_PING_INTERVAL` (5s), `_publish_server_snapshot()`
builds and publishes:

```json
{
  "port": 3005,
  "name": "DM-1",
  "mode": "deathmatch",
  "map": "map_gamma",
  "player_count": 2,
  "max_players": 8
}
```

`HttpServerRegistry.publish()` POSTs this JSON to `<api_url>/browser` using
the `ServerBridge`'s `BetterHTTPClient` (`api_url` comes from
`settings-prod.json` or `settings-dev.json`, selected by
`OS.has_feature("editor_runtime")`). The backend (`server/src/routes/browser.ts`)
upserts by `name`, stamping `ip` from the `CF-Connecting-IP` header (falls
back to `127.0.0.1`) and `last_ping = now()`. A listing is dropped once it
hasn't been pinged for `SERVER_EXPIRY_THRESHOLD_MS` (10s) — i.e. two missed
pings at the default 5s interval. A publish failure (unreachable API, non-200
response) only `push_warning`s; it does not stop the server, but the listing
will expire from the browser if failures persist past 10s.

## Player lifecycle

1. A connecting ENet peer triggers `multiplayer.peer_connected` →
   `GameManager.on_peer_connected(id)`, which performs the **server-delivered mode
   handshake** — it RPCs `_server_ready(current_pvp_mode)` to that peer, telling its
   client to change scene to `pvp_mode_to_map[mode]` — and increments
   `player_count`. The joining client never chooses a mode itself; it loads whatever
   map the server dictates (and `push_error`s on an unknown mode).
2. The client-side mode script then RPCs its own "send info" method to the
   server (`_send_info` in both deathmatch and elimination), which replies
   with the current map/roster and spawns the new player for everyone
   (deathmatch: random spawn, weapon index `1`; elimination: team-assigned
   spawn, damage enabled only if the match is already `LIVE`).
3. On disconnect, `multiplayer.peer_disconnected` →
   `GameManager.on_peer_disconnected(id)` decrements `player_count` and emits
   `player_diconnected`; each mode's `_on_player_disconnected` handler removes
   the player node (elimination additionally re-evaluates the round/match
   state if the disconnect leaves a team empty or ends a live round).

## Offline playtest and E2E

Both are test profiles that swap `FakeIdentityProvider` in for Steam, but they
apply to **different roles** and select different adapters:

- **`--offline-playtest`** is **client-only** — `Bootstrap.build` rejects it on a
  `server` launch. It is always available (no gating) and selects a fixed fake
  identity (id `1`, "Playtester") with a `null` `server_registry`.
- **`--e2e`** is gated behind `allow_test_adapters` (`OS.has_feature("editor")` by
  default, so it is rejected outside editor/test builds) and applies to the
  **dedicated-server and connect-client roles** used by the multi-process harness:
  - an `--e2e` **connect client** gets a per-instance fake identity derived from
    `--e2e-instance` (`alice`→"Alice", `bob`→"Bob", each with a distinct positive
    account id) and a `null` `server_registry`;
  - an `--e2e` **dedicated server** gets a `null` identity and a
    `RecordingServerRegistry`, which records snapshots in memory instead of POSTing
    them to the browser (so no `server_bridge` is required).

Unlike the earlier design, a real multi-process, ENet-networked end-to-end test now
**exists** and is what consumes `--e2e`: `./scripts/test-e2e.sh` launches a
dedicated `server` plus two connect clients (`alice`, `bob`) as separate processes
and drives them over a TCP control channel through the combat lifecycle. See
[testing.md](./testing.md#end-to-end-test-multi-process-enet) for the full
walkthrough. `--e2e` is also exercised by the in-process
`tests/unit/bootstrap_test.gd` / `tests/unit/runtime_options_test.gd` for
adapter-selection coverage.

A `null` `server_registry` is safe for any client role:
`GameManager._publish_server_snapshot()` is only ever invoked by the server-browser
ping timer, which `init_server()` starts solely for the dedicated-server role, so a
menu, connect, or offline-playtest client never calls it in practice.

Neither profile starts the Steam Web API heartbeat (`Global._on_auth_ticket_ready`
only starts it for a non-empty ticket obtained through `SteamIdentityProvider`).

## Failure behavior and troubleshooting

| Symptom | Cause | Where |
| --- | --- | --- |
| Process exits immediately with code 1 | Malformed launch arguments (bad port/max_players/mode syntax, unknown flag). | `RuntimeOptions.parse` error → `Global._abort_startup()`. |
| Process exits immediately with code 1 | `server --e2e` in a non-test build (`allow_test_adapters` false), `server` combined with `--offline-playtest`, or `--e2e-instance`/`--e2e-control-port` without `--e2e`. | `RuntimeOptions.parse` / `Bootstrap.build` reject the combination. |
| Process stays running but no client can connect | `port` already in use or otherwise invalid for `ENetMultiplayerPeer.create_server`. | `GameManager.init_server()` logs and returns; the process is not restarted automatically — restart it manually. |
| Script error at startup | `<mode>` is not `deathmatch`/`elimination` (no matching `res://src/maps/<mode>/` directory or `pvp_mode_to_map` entry). | `MapManager.get_random_map` / `GameManager.init_server`. Use only `deathmatch` or `elimination`. |
| Server never appears in the browser, or drops out during play | Backend API unreachable, non-200 `/browser` response, or the process has been running >10s without a successful publish. | `_publish_server_snapshot` only `push_warning`s on failure; check the server's own console output and the backend's reachability from that host. |
| Dedicated server fails to build at all | `Bootstrap.build` requires a `server_bridge` for `HttpServerRegistry`; `Global` always constructs one before calling `Bootstrap.build`, so this only indicates a code-level regression, not a runtime misconfiguration. | `src/app/bootstrap.gd`. |

No credentials or API keys are read from the command line or logged by the
dedicated-server path; `api_url` values in `settings-dev.json`/`settings-prod.json`
are public endpoints already referenced in the project [README](../README.md).
