# Development

Setup and day-to-day commands for working on the game client, backend server, and
website. For test commands and CI details, see [testing.md](./testing.md).

## Prerequisites

- **Godot 4.6.1** — the exact version pinned in CI (`.github/workflows/ci.yml`) and
  required by `config/features=PackedStringArray("4.6", ...)` in `project.godot`.
  Use this version for the editor and for running local Godot tests.
- **Python 3.11** — CI (`.github/workflows/ci.yml`) uses it to run the GDScript
  tooling (`gdformat`/`gdlint` from **gdtoolkit**) and the multi-process E2E harness.
  Locally, install the pinned dev tools with `pip install -r requirements-dev.txt`
  (or run `./scripts/setup-dev.sh`, below).
- **Node.js 22** with **Corepack** enabled (`corepack enable`) — CI uses Node 22 for
  both `server/` and `website/`. Corepack provisions the exact **pnpm 10.15.0**
  pinned by each workspace's `packageManager` field (`server/package.json` and
  `website/package.json`), so every `pnpm ...` command runs the same version.
- **Docker** (with Compose) — used to run PostgreSQL (and optionally the server
  itself) via `server/compose.yaml`. Required for any server work that touches the
  database.
- **PostgreSQL** — only needed directly if you choose not to run it via Docker; the
  server otherwise expects a reachable `DATABASE_URL`.

## One-command setup

`./scripts/setup-dev.sh` bootstraps the local toolchain. It creates a `.venv`,
installs the pinned Python dev tools from `requirements-dev.txt` (**gdtoolkit 4.5.0**
for `gdformat`/`gdlint`, plus **Lefthook 2.1.10**), enables Corepack and runs
`pnpm install --frozen-lockfile` in **both** the `server/` and `website/` directories
(Corepack provisions the pinned **pnpm 10.15.0** from each workspace's `packageManager`
field), and finally runs `lefthook install` to register the Git hooks. After it
completes, the pre-commit and pre-push hooks are active and `gdformat`/`gdlint` are
available under `.venv/bin`. See [testing.md](./testing.md#formatting-and-linting) for
the exact format/lint commands and the hook behavior. Node dependencies live **per
workspace** — there is **no root-level `package.json` or JS workspace**; `server/` and
`website/` are independent pnpm projects, and GDScript tooling is Python-based rather
than part of any Node workspace.

## Repo layout

```
src/            Godot game client (GDScript), organized by app/platform/player/maps/menus
tests/          Headless Godot tests + multi-process E2E harness (see testing.md)
addons/         Godot addons (godotsteam, gdmaim, better_http)
scripts/        Bash tooling: dev setup, exports, Docker game-server helpers, Steam upload, test runners
server/         Node/TypeScript backend (Hono API + Postgres via Drizzle)
website/        Vue 3 + Vite leaderboard website
docker/         Dockerfiles/compose for the standalone game-server fleet
steam/          Steam depot/build config and upload scripts
docs/           Project documentation — see docs/README.md for the full index
```

See [`docs/README.md`](./README.md) for the full documentation index (architecture,
gameplay, game server, backend, website, map creation, asset attribution). The
backend's field-level API reference is the live OpenAPI docs at
[straifapi.pumped.software/docs](https://straifapi.pumped.software/docs); this
repo's [`docs/backend.md`](./backend.md) covers its structure/behavior instead.

## Game client (editor / local run)

```bash
git clone https://github.com/vasiltop/straif
cd straif
godot -e
```

Run the game headless as a dedicated server (see [README.md](../README.md) for the
full Docker/deployment flow):

```bash
./straif server <name> <port> <max_players> <mode> --headless
```

## Server (`server/`)

With Docker (recommended — builds the server image and a Postgres 16 container from
`server/compose.yaml`):

```bash
cd server
cp .env.example .env   # fill in STEAM_API_KEY and DISCORD_TOKEN
docker compose up -d --build
```

Without Docker for the app process (Postgres still runs via Docker):

```bash
cd server
cp .env.example .env
docker compose up -d db
corepack enable
pnpm install --frozen-lockfile
pnpm db:push        # drizzle-kit push — applies the schema to the local db
pnpm dev            # tsx watch src/index.ts
```

Other package scripts (`server/package.json`): `pnpm build` (`tsc` + `tsup` →
`dist/`), `pnpm start` (run the built server), `pnpm test` (see
[testing.md](./testing.md)), `pnpm db:generate` / `pnpm db:migrate` / `pnpm db:studio`
(Drizzle Kit), `pnpm populate` (`scripts/populate.js` seed script).

## Website (`website/`)

```bash
cd website
corepack enable
pnpm install --frozen-lockfile
pnpm dev       # vite dev server
pnpm build     # vite build -> dist/
pnpm preview   # preview a production build
```

The website has no test script; CI only installs and builds it (see
[testing.md](./testing.md)).

## Formatting & linting

Two toolchains, both enforced in CI and by the Lefthook hooks:

- **GDScript** (`src/`, `tests/`) — **gdtoolkit** (`gdformat`/`gdlint`), installed
  from `requirements-dev.txt` into `.venv`. Config lives in `gdformatrc` / `gdlintrc`
  at the repo root. Run these with the venv active (or prefix with `.venv/bin/`):

  ```bash
  gdformat src tests          # format in place
  gdformat --check src tests  # verify formatting (CI uses this)
  gdlint src tests            # lint
  ```

- **TypeScript / Vue** (`server/`, `website/`) — **Oxfmt** + **Oxlint**, run from the
  `server/` workspace (which owns the dev dependency and reaches up into `website/`).
  Config lives in `.oxfmtrc.json` at the repo root.

  ```bash
  cd server
  pnpm format          # oxfmt server + website
  pnpm format:check    # verify formatting
  pnpm lint            # oxlint server + scripts + website
  pnpm quality         # format:check + lint (CI uses this)
  ```

`gdlint` deliberately disables four structural rules in `gdlintrc`
(`class-definitions-order`, `function-arguments-number`, `max-public-methods`,
`max-returns`) so it flags real issues rather than architectural preferences; the
pinned **gdtoolkit 4.5.0** is the version whose parser is compatible with the
project's GDScript.

### Git hooks (Lefthook)

`./scripts/setup-dev.sh` runs `lefthook install`, wiring two hooks (`lefthook.yml`):

- **pre-commit** — runs `gdformat`/`gdlint` on staged `*.gd` files (excluding
  `addons/`) and `oxfmt`/`oxlint` on staged `*.{ts,tsx,js,jsx,vue}` files,
  auto-staging any formatter fixes so a commit can't introduce unformatted or
  lint-failing code.
- **pre-push** — runs three commands (`lefthook.yml`), with **`server-quality`**
  (`cd server && pnpm quality && pnpm test && pnpm build`) and **`website-build`**
  (`cd website && pnpm build`) in parallel alongside a **`godot-suite`** that runs
  `./scripts/test-godot.sh` **then** `./scripts/test-e2e.sh` sequentially in one
  command. The two Godot suites are chained rather than run in parallel so they don't
  race on the shared `.godot` import cache. This mirrors the CI jobs so a push can't
  break the build.

Lefthook is invoked only by these local Git hooks; CI runs the same checks directly
(`gdformat --check` / `gdlint` / `pnpm quality` / the test scripts) rather than
through Lefthook.

> **Caveat — partially staged files.** The pre-commit formatters (`gdformat`,
> `oxfmt`) use `stage_fixed: true`, which formats and **re-stages the whole file**,
> not just your staged hunks. If you've staged only part of a file and left other
> hunks unstaged, a formatter fix will pull those unstaged hunks into the commit.
> Commit or `git stash --keep-index` your unstaged changes before committing when you
> rely on partial staging.

## Environment / config files

| File | Purpose | Commit? |
|---|---|---|
| `server/.env.example` | Template for `DATABASE_URL`, `VERSION`, `STEAM_API_KEY`, `DISCORD_TOKEN`, `PORT` | Yes (template only) |
| `server/.env` | Your real local secrets/config, copied from `.env.example` | **No** — git-ignored |
| `settings-dev.json` / `settings-prod.json` | Client `api_url`/`version` selection baked into exports | Yes |
| `steam/steam.env.example` | Template for Steam publisher username + depot IDs | Yes (template only) |
| `steam/steam.env` | Your real Steam credentials/depot IDs | **No** — git-ignored |

Never commit `.env`, `steam/steam.env`, API keys, tokens, or Steam credentials.

## Generated / build outputs (do not commit)

All of the following are git-ignored and regenerated by tooling — do not hand-edit
or commit them:

- `.godot/` — Godot's local import/editor cache
- `build/` — platform export output (`scripts/export-*.sh`)
- `server/dist/`, `website/dist/` — compiled/bundled output (`pnpm build`)
- `server/node_modules/`, `website/node_modules/` — installed dependencies
- `steam/output/` — Steam upload artifacts

`server/drizzle/` (SQL migrations) is the exception: those files are generated by
`drizzle-kit generate` but are committed, since they are the durable migration
history applied by `pnpm db:migrate` / `pnpm db:push`.

## Further reading

- [README.md](./README.md) — full documentation index
- [architecture.md](./architecture.md) — client/server composition root
- [testing.md](./testing.md) — test philosophy, exact test/build commands, CI jobs
- [backend.md](./backend.md) — `server/` API structure and behavior
- [website.md](./website.md) — `website/` leaderboard app
- [map_creation.md](./map_creation.md) — elimination-map authoring pipeline
- [ASSET_ATTRIBUTION.md](./ASSET_ATTRIBUTION.md) — third-party asset licensing
- [../README.md](../README.md) — quick start, Docker game-server fleet, Steam deployment
