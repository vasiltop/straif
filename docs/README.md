# Documentation index

| Doc | Covers |
| --- | --- |
| [architecture.md](./architecture.md) | Godot client/server binary composition root: `RuntimeOptions`, `Bootstrap`, `AppContext`, `IdentityProvider`, `ServerRegistry`, `GameManager`. |
| [gameplay.md](./gameplay.md) | The four playable modes (speedrun, deathmatch, elimination, aim) and the shared `Player` controller. |
| [game-server.md](./game-server.md) | Dedicated-server invocation, ENet networking, server-browser publication, player lifecycle, the `--e2e` test profile, and troubleshooting. |
| [development.md](./development.md) | Prerequisites, one-command `./scripts/setup-dev.sh`, day-to-day setup/run commands, and the format/lint toolchain (gdtoolkit + Oxfmt/Oxlint) with its Lefthook Git hooks. |
| [testing.md](./testing.md) | Test philosophy, exact Godot/server/website commands, formatting/linting, the multi-process ENet E2E test (`./scripts/test-e2e.sh`), and CI job details. |
| [backend.md](./backend.md) | `server/` Hono + Postgres API: routes, middleware, schema, environment variables, commands. |
| [website.md](./website.md) | `website/` Vue 3 + Vite leaderboard app: data flow, commands, known limitations. |
| [map_creation.md](./map_creation.md) | Elimination map authoring pipeline (Blender → `.glb` → `.tscn`), conventions, and scale budget. |
| [ASSET_ATTRIBUTION.md](./ASSET_ATTRIBUTION.md) | Third-party asset licensing (textures, etc.). |

For quick start, Docker game-server hosting, and Steam deployment, see the
[root README](../README.md).
