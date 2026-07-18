# Backend (`server/`)

The backend is a [Hono](https://hono.dev) HTTP API (Node.js, TypeScript) backed by
PostgreSQL via [Drizzle ORM](https://orm.drizzle.team). It serves the run/aim
leaderboards, a lightweight admin panel API, a heartbeat/maintenance channel for the
game client, and an in-memory server browser used by dedicated game servers.

For hosting dedicated game servers (Docker, fleet compose, droplet deploy) see the
root `README.md` under "Local Setup > Hosting a game server". For test commands and
CI details across the whole repo (including this server) see
[`docs/testing.md`](./testing.md); for general prerequisites/setup see
[`docs/development.md`](./development.md). This document only covers `server/`.

## App boot

Entry point: `server/src/index.ts`.

1. Creates a `Hono` app and installs a permissive CORS middleware on `*`
   (`origin: '*'`, methods `GET/POST/PUT/DELETE/OPTIONS`, headers
   `Content-Type`/`Authorization`).
2. Mounts four route groups (see below) plus an OpenAPI document and Swagger UI.
3. Starts listening via `@hono/node-server`'s `serve()` on `process.env.PORT`
   (no fallback — the process throws if `PORT` is unset/non-numeric since
   `parseInt(process.env.PORT!)` is called unchecked).
4. Creates a `discord.js` `Client` (`Guilds`, `GuildMessages` intents), exported as
   `discord_client`, and logs it in with `DISCORD_TOKEN` if that variable is set;
   otherwise it logs a warning and continues running the API without Discord.

## Route groups

Mounted in `src/index.ts`:

| Prefix         | File                        | Purpose                                                                 |
|----------------|-----------------------------|--------------------------------------------------------------------------|
| `/leaderboard` | `src/routes/leaderboard.ts` | Movement-run leaderboards (submit/read/delete runs, overall points, replay recordings). Also nests `/leaderboard/aim/*`. |
| `/admin`       | `src/routes/admin.ts`       | Toggle maintenance mode, ban/unban a Steam ID or value, grant/revoke admin. |
| `/game`        | `src/routes/game.ts`        | Client heartbeat: reports admin status, maintenance flag, recent world records. |
| `/browser`     | `src/routes/browser.ts`     | In-memory dedicated-server registry used by the in-game server list.     |
| `/leaderboard/aim` | `src/routes/aim_leaderboard.ts` | Aim-trainer scenario leaderboards (submit/read scores, overall aggregate). |

Route summaries here are intentionally high-level — the OpenAPI document served at
`/openapi` (and rendered at `/docs`) is the canonical field-level reference for
request/response schemas, since every public route is annotated with
`describeRoute`/Zod resolvers.

## Response envelope convention

Handlers consistently return one of two JSON shapes:

- Success: `{ "data": <payload> }` (payload varies by route: a string message, an
  object, or an array).
- Failure: `{ "error": <string> }`, with an HTTP status of `400` (validation/lookup
  failure), `401` (auth failure), or `500` (unexpected/caught exception).

Some internal/administrative routes are excluded from the OpenAPI document via
`hide_route()` (`src/routes/common.ts`, a `describeRoute({ hide: true })` wrapper)
but still use the same envelope at runtime.

## Middleware (`src/middleware.ts`)

All Steam-related middleware calls the Steam Web API
(`https://partner.steam-api.com/ISteamUserAuth/AuthenticateUserTicket/v1/`) using
`STEAM_API_KEY`, a fixed `appid` (`3850480`), and `identity: 'munost'` to resolve an
`auth-ticket` header into a Steam ID. An empty/failed lookup returns `''`.

- **`version_compare`** — requires a `version` header that exactly matches
  `process.env.VERSION`; otherwise responds `401 { error: 'Invalid Version' }`.
- **`steam_auth`** — requires an `auth-ticket` header, resolves it to a Steam ID via
  the Steam API, sets `c.set('steam_id', sid)` on success, otherwise `401`.
- **`admin_auth`** — built from a factory, `createAdminAuth(deps)`, so the ticket
  Steam-API call and the admin-DB lookup are injectable dependencies
  (`AdminAuthDependencies`: `authenticateTicket`, `isAdmin`). The exported
  `admin_auth` wires it to the real `get_steam_id_from_ticket` and `is_admin`
  (`src/players.ts`). It requires the `auth-ticket` header, resolves the Steam ID,
  and rejects with `401` if the ticket is missing/invalid or if
  `await deps.isAdmin(sid)` is falsy. **This admin check is correctly awaited** —
  `if (!(await deps.isAdmin(sid)))` — fixing an earlier form of this middleware that
  checked the truthiness of the un-awaited `Promise` object returned by `is_admin`
  (which is always truthy, so the check never actually rejected anyone). The fix is
  covered by `src/middleware.test.ts` (see the "only after awaiting isAdmin" test,
  which asserts the 401 is returned only once the `isAdmin` promise resolves).
- **`ban_auth`** — requires an `auth-ticket` header, resolves a Steam ID, and
  rejects with `401` if the resolved ID is in `banned_values` (checked via
  `value_banned`, `src/players.ts`).

Note: `admin_auth` is applied per-route in `src/routes/admin.ts`, and one route
(`GET /admin/bans/:steam_id`) has no auth middleware attached — it is publicly
readable.

## PostgreSQL / Drizzle

- Connection: `src/db/index.ts` creates a single `drizzle(process.env.DATABASE_URL!)`
  Node-Postgres client, exported as the default `db`.
- Schema: `src/db/schema.ts` defines:
  - `run_mode` enum (`'bhop' | 'target'`) and `aim_scenario` enum (from
    `AIM_SCENARIOS` in `src/aim_leaderboard.ts`: `gridshot`, `flick`, `tracking`).
  - `runs` table — one best run per `(map_name, steam_id, mode)` composite primary
    key; columns `time_ms`, `recording`, `username`, `created_at`.
  - `aim_scores` table — one best score per `(steam_id, scenario)` composite primary
    key; columns `username`, `score`, `hits`, `misses`, `accuracy`,
    `avg_reaction_ms`, `created_at`; indexed on
    `(scenario, score, accuracy, avg_reaction_ms)` for leaderboard ordering.
  - `admins` table — `steam_id` primary key (presence = is an admin).
  - `banned_values` table — unique `value` column (can hold a Steam ID or an IP).
- Migrations live in `server/drizzle/` (currently one migration,
  `0000_chubby_selene.sql`), tracked by `drizzle/meta/_journal.json`.
  `src/migrate.ts` applies committed migrations from `./drizzle` via
  `drizzle-orm/node-postgres/migrator` and exits.
- Commands (see also `package.json` scripts, run from `server/`):
  - `pnpm db:generate` — generate a new migration from schema changes
    (`drizzle-kit generate`).
  - `pnpm db:migrate` — apply committed migrations (`drizzle-kit migrate`).
  - `pnpm db:push` — push the schema directly without a migration file
    (`drizzle-kit push`; used for local dev per the root README).
  - `pnpm db:studio` — open Drizzle Studio (`drizzle-kit studio`).
  - In the Docker image, the container entrypoint runs
    `node dist/migrate.js && node dist/index.js` on every start, so committed
    migrations are applied automatically before the server boots.

## Discord world-record notifications

- On `discord_client.on('ready', ...)` the bot logs its tag.
- When a run submission in `POST /leaderboard/mode/:mode_name/maps/:map_name/runs`
  is detected as a new world record (`is_new_world_record`, `src/world_records.ts` —
  true when the run was accepted as a personal best and is faster than the previous
  best, or there was no previous best), the server:
  1. Publishes the record to an in-memory recent-records cache
     (`recent_world_records.publish(...)`).
  2. Iterates every guild the bot is in, fetches that guild's channels, finds a
     `GuildText` channel literally named `wr-announcements`, and sends an
     announcement message there via `send_discord_update` (mode is rendered as
     "Target Practice" or "Movement Only"; time is formatted in seconds).
- If `DISCORD_TOKEN` is unset, or the bot cannot find a `wr-announcements` channel in
  a guild, notifications are silently skipped for that guild (errors from the
  Discord call are caught and logged, not thrown).

## In-memory server browser registry

`src/routes/browser.ts` keeps dedicated game servers in a process-local
`Map<string, Server>` (no persistence — restarting the API clears it):

- `POST /browser` — a game server heartbeats itself in by `name` (upsert): stores
  `port`, `mode`, `map`, `player_count`, `max_players`, the caller's IP (from the
  `CF-Connecting-IP` header, defaulting to `127.0.0.1` if absent), and
  `last_ping: new Date()`.
- `GET /browser` — returns all currently registered servers as `{ data: Server[] }`.
- A `setInterval` health check runs every `HEALTH_CHECK_INTERVAL_MS` (10s) and
  deletes any server whose `last_ping` is older than `SERVER_EXPIRY_THRESHOLD_MS`
  (10s), so a server must ping at least once every 10 seconds to stay listed.
- Similarly, `recent_world_records` (`src/world_records.ts`) is an in-memory,
  unpersisted list with a 60-second TTL (`RecentWorldRecords`, default
  `ttl_ms = 60_000`); expired entries are pruned lazily on `.list()`. It is read by
  the `/game/heartbeat` endpoint so connected clients can show recent world records.

## Environment variables

Inferred from `server/.env.example` and source code (no values reproduced here):

| Variable         | Used by                          | Notes |
|-------------------|----------------------------------|-------|
| `DATABASE_URL`    | `src/db/index.ts`, `src/migrate.ts`, `drizzle.config.ts` | Postgres connection string. Overridden to point at the Docker Compose `db` service when run via `docker compose`. |
| `VERSION`         | `src/middleware.ts` (`version_compare`) | Must match the game client's `version` request header exactly. |
| `STEAM_API_KEY`   | `src/middleware.ts`               | Steam Web API key used to validate auth tickets. |
| `DISCORD_TOKEN`   | `src/index.ts`                    | Optional; Discord bot login token. If unset, Discord login is skipped and the API still runs. |
| `PORT`            | `src/index.ts`                    | Port the Hono server listens on; required (no default). |

`dotenv/config` is imported at the top of `src/db/index.ts`, `src/middleware.ts`,
`src/migrate.ts`, and `drizzle.config.ts`, so a `server/.env` file (copied from
`.env.example`) is loaded automatically in local/dev runs; the Docker image instead
receives these as container environment variables (see `server/compose.yaml`).

## Setup, dev, test, build, start commands

All run from `server/` (package manager: pnpm, per `pnpm-lock.yaml`/`pnpm-workspace.yaml`,
though the scripts also work with `npm`/`npx` since they're plain Node scripts):

```bash
cp .env.example .env      # fill in STEAM_API_KEY and DISCORD_TOKEN
pnpm install               # or: npm install

pnpm dev                   # tsx watch src/index.ts  (local dev server, hot reload)
pnpm test                  # tsx --test src/*.test.ts (node:test based unit tests)
pnpm build                 # tsc (typecheck) && tsup src/index.ts src/migrate.ts --format esm --outDir dist
pnpm start                 # node dist/index.js  (run the built server; requires pnpm build first)

pnpm run populate          # node scripts/populate.js (dev DB seed helper)
```

Docker (from `server/`, full stack including Postgres):

```bash
docker compose up -d --build
```

This builds the server image (see `server/Dockerfile`, built from the repo root as
context so it can read `../maps.json`), waits for the `db` service's health check,
runs `node dist/migrate.js` then `node dist/index.js` in the container, and starts
the API on `http://localhost:3000`.

For local development without Docker for the server process itself, but using the
Dockerized database:

```bash
docker compose up -d db
pnpm install
pnpm db:push
pnpm dev
```

Server tests were verified as of this writing: `pnpm test` runs 13 unit tests
(middleware auth behavior, aim scenario parsing, world-record cache logic) with no
external dependencies (no live database required), all passing.

## OpenAPI / docs endpoints

- `GET /openapi` — serves the generated OpenAPI document (`hono-openapi`'s
  `openAPIRouteHandler`), titled "Straif API", version `0.0.3`, with `servers`
  pointing at `https://straifapi.pumped.software`.
- `GET /docs` — Swagger UI (`@hono/swagger-ui`) rendered against `/openapi`.

Routes wrapped in `hide_route()` (most mutation/auth-gated endpoints, including all
of `/admin`, run submission/deletion, and aim score submission) are omitted from
this document by design; they are still live, authenticated routes — just not
publicly documented.

## Error / security boundaries

- CORS is fully open (`origin: '*'`), and admin/ban/version checks are the only
  gating short of that; there is no rate limiting or IP allow-listing visible in
  the code.
- Auth is entirely Steam-ticket based (no session cookies/JWTs); every protected
  route re-validates the ticket against Steam's API on each request.
- Run submissions are size-bounded: a recording payload `>= 474854` characters
  is rejected with `400` before being persisted.
- World-record-sensitive writes (`POST`/`DELETE` on
  `/leaderboard/mode/:mode_name/maps/:map_name/runs*` only — not aim score
  submission) take a Postgres advisory transaction lock
  (`pg_advisory_xact_lock(hashtext(...))`, keyed by `world_record_lock_key(mode,
  map_name)`) to serialize concurrent writes to the same leaderboard row and
  avoid races when determining/announcing a new world record.
- All route handlers that touch the database wrap their logic in `try/catch` and
  return a generic `500 { error: 'Internal server error' }` on unexpected failure,
  logging the raw error server-side with `console.log(e)` (not a structured
  logger).
- `GET /admin/bans/:steam_id` has no auth middleware, unlike every other route
  under `/admin`; it is publicly readable.
