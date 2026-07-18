# Testing

Test philosophy, exact commands, and CI details for the game client, server, and
website. For setup/prerequisites, see [development.md](./development.md).

## Test philosophy

Write tests that verify **behavior, regressions, and boundary conditions** —
not tests that merely restate the implementation. Concretely:

- **Behavior tests**: assert what the system does through its real interfaces
  (scene loads, methods return the right values, injected boundaries receive the
  right calls) rather than how it's implemented internally.
- **Regression tests**: lock in a bug fix or a scenario that previously broke, so it
  can't silently regress.
- **Boundary/edge-case tests**: cover empty input, zero/negative/out-of-range
  values, disabled flags, and gating logic (e.g. valid vs. invalid `RuntimeOptions`
  args, production vs. test-adapter selection).
- **Avoid**: source-text greps, "does this method/property exist" checks with no
  behavioral assertion, one-test-per-getter boilerplate, and tests that only
  restate a type annotation. `tests/offline_playtest_smoke.gd` and
  `tests/unit/bootstrap_test.gd` explicitly document this in their header comments
  and are the reference examples to follow.

**Adding a valuable test without getter-boilerplate**: don't write one test per
field/getter. Instead, pick one merged scenario per real boundary or decision point
and assert the *outcome* that matters (e.g. one test that drives `RuntimeOptions`
through several invalid arg combinations and checks each is rejected with a useful
error, rather than a separate test per invalid field). Reuse the shared
`tests/support/test_case.gd` helper (`TestCase.check` / `check_equal`) so failures
report expected-vs-actual without hand-rolled assertion code, and prefer extending
an existing scenario-based test file over adding a new file for a single trivial
check.

## Formatting and linting

Formatting and linting are enforced in CI and by the local Lefthook hooks (installed
by `./scripts/setup-dev.sh`; see [development.md](./development.md#one-command-setup)).

- **GDScript** (`src/`, `tests/`) — **gdtoolkit** (pinned `gdtoolkit==4.5.0` in
  `requirements-dev.txt`), reading `gdformatrc` / `gdlintrc`:

  ```bash
  gdformat --check src tests   # formatting (CI); drop --check to format in place
  gdlint src tests             # lint
  ```

  `gdlintrc` disables four structural rules (`class-definitions-order`,
  `function-arguments-number`, `max-public-methods`, `max-returns`) so the linter
  reports genuine defects instead of architecture opinions.

- **TypeScript / Vue** (`server/`, `website/`) — **Oxfmt** + **Oxlint**, run from the
  `server/` workspace (reading `.oxfmtrc.json`):

  ```bash
  cd server
  pnpm format:check   # oxfmt --check server + website
  pnpm lint           # oxlint server + scripts + website
  pnpm quality        # format:check + lint together (CI)
  ```

  A single `pnpm quality` covers both Oxfmt and Oxlint across the server **and** the
  website source.

### Pre-commit / pre-push hooks and CI parity

- **pre-commit** runs `gdformat`/`gdlint` on staged `*.gd` files (excluding
  `addons/`) and `oxfmt`/`oxlint` on staged `*.{ts,tsx,js,jsx,vue}` files,
  auto-staging formatter fixes — so unformatted or lint-failing code can't be
  committed. Note that `stage_fixed` re-stages the **whole** formatted file, so if
  you partially stage a file, commit or `git stash --keep-index` the unstaged hunks
  first (see [development.md](./development.md#git-hooks-lefthook)).
- **pre-push** runs three commands (`lefthook.yml`): a sequential **`godot-suite`**
  (`./scripts/test-godot.sh` then `./scripts/test-e2e.sh` — the multi-process E2E
  test below) alongside **`server-quality`** (`cd server && pnpm quality && pnpm test
  && pnpm build`) and **`website-build`** (`cd website && pnpm build`), which run in
  parallel with it. The two Godot suites are chained, not parallelized, to avoid
  racing on the shared `.godot` import cache. Because the E2E test is part of the
  push gate, keep tests **lean** (see the philosophy above) so the hook stays fast.
- **CI parity**: the hooks run the same underlying checks CI runs, but CI splits them
  across parallel jobs and invokes them directly — `gdformat --check src tests` /
  `gdlint src tests` in the `godot` job, `./scripts/test-e2e.sh` in `godot-e2e`, and
  `pnpm quality` in the `server` job — not through Lefthook.

## Godot tests

Run all headless Godot tests:

```bash
./scripts/test-godot.sh
```

This runs each test script with `godot --headless --path <repo root> --script <test> -- --offline-playtest`
and fails (non-zero exit) if any script fails. `GODOT_BIN` can point at a specific
Godot executable if `godot` isn't on `PATH`:

```bash
GODOT_BIN=/path/to/godot ./scripts/test-godot.sh
```

The script requires **Godot 4.6.1** — the version pinned in CI and matching the
`config/features` entry in `project.godot`. Other 4.6.x builds may work but are
unverified; mismatched major/minor versions can fail to open the project or import
resources differently.

> This machine has no `godot`/Godot binary installed, so these tests could not be
> executed as part of writing this doc. The list below and the pass/fail behavior
> are read directly from the current test scripts and CI configuration, not
> independently re-run.

Current tests (`scripts/test-godot.sh`, in run order) and what each covers:

| Test | Behavior covered |
|---|---|
| `tests/unit/runtime_options_test.gd` | `RuntimeOptions.parse()` argument parsing: defaults to menu client, valid `server` args, missing/invalid positionals (empty name/mode, bad port range, bad max-players), unknown commands/flags, extra positionals, `--offline-playtest` exact-match vs. partial-match, `--e2e` allowed vs. rejected by build flag, and flag-like server positionals being rejected with a descriptive error. |
| `tests/unit/bootstrap_test.gd` | Composition root (`Bootstrap.build`) boundary selection: production menu/connect clients select the real Steam identity with no side effects and no server registry; an E2E **connect client** is gated behind `allow_test_adapters` and selects a per-instance fake identity (e.g. `alice`→"Alice") with a `null` server registry; an E2E **dedicated server** is gated the same way and selects a `null` identity plus a `RecordingServerRegistry` (no `server_bridge` required); offline-playtest is always available and selects the fake identity with a `null` server registry; invalid role/dependency combinations (production dedicated server without a bridge) fail instead of half-wiring; `RecordingServerRegistry` deep-copies snapshots so callers can't mutate stored state; `HttpServerRegistry` publishes to `/browser` and maps HTTP status to `OK`/error/`ERR_CANT_CONNECT`; `GameManager` assembles and publishes its own snapshot through an injected registry. |
| `tests/world_record_announcement_test.gd` | `WorldRecordAnnouncement.format_message()` output formatting; `consume_unseen()` dedupes an already-announced record id and still marks disabled-announcement records as seen; `clear_if_disabled()` clears queued messages when announcements are off. |
| `tests/offline_playtest_smoke.gd` | Real `Global` boot with `--offline-playtest`: offline flag parsing (exact vs. partial flag), `Global.offline_playtest` reporting true, an `AppContext` being built, and the injected offline identity delivering an auth ticket synchronously with no Steam call. |
| `tests/aim_menu_smoke.gd` | Aim menu and main menu scenes load and expose their key nodes (scenario list, start button, leaderboard tabs with 2 tabs); `Global.server_bridge` is initialized. |
| `tests/aim_trainer_smoke.gd` | Aim target/trainer scenes load with expected structure and groups; `calculate_accuracy` avoids divide-by-zero; `calculate_average_reaction_ms` converts seconds to ms; HUD label sizing/layout ordering; a runtime-spawned `Player` exists and behaves correctly when toggling pause after a session finishes (menu stays closed, movement/turning stay disabled, mouse stays visible); leaderboard rows render from data. |
| `tests/death_camera_test.gd` | Player's local-view switching: entering the ragdoll/death view makes the ragdoll camera current, keeps the third-person body visible, and hides the weapon handler/gun viewport; returning to first person restores the original camera/visibility state. |
| `tests/elimination_round_state_test.gd` | Authoritative damage application respects `set_damage_enabled` (damage applies when enabled, is ignored when disabled); an alive local player never renders its own third-person body; a spectated remote player hides its body in first person and restores it after spectating ends. |

## End-to-end test (multi-process ENet)

A real multi-process, ENet-networked end-to-end test **exists** and runs headless:

```bash
./scripts/test-e2e.sh
```

The script first runs `godot --headless --import` to prime the import cache, then
runs the Python harness (`python3 -m unittest test_deathmatch -v`) from
`tests/e2e/`. The harness launches **three separate Godot processes** — a dedicated
`server` plus two connect clients, `alice` and `bob` — each in its own OS process
with its own ENet peer, all started with the `--e2e` profile (see
[game-server.md](./game-server.md#offline-playtest-and-e2e)). A small TCP control
server (`tests/e2e/control_server.py` ↔ `tests/e2e/godot/control_client.gd`) drives
each instance with JSON commands (`snapshot`, `teleport`, `fire`, `reload`, …).

The single vertical-slice test (`tests/e2e/test_deathmatch.py`) exercises the whole
combat lifecycle across processes: two clients connect and mirror each other's
identities, the server loads an arena fixture, players teleport and converge on all
three snapshots, Alice equips an AK-47 and shoots Bob, damage/tracer/blood effects
propagate, Bob dies and both killfeeds announce the kill, Bob respawns at full
health, Alice reloads, and a disconnect is observed everywhere.

- **Requirements**: Godot 4.6.1 (`GODOT_BIN` if `godot` isn't on `PATH`) and Python
  3.11. No Python packages are needed — the harness uses only the standard library.
- **Runtime**: roughly **11–17 s** locally end-to-end. The test carries an internal
  210 s safety budget, and CI caps the whole `godot-e2e` job at **5 minutes**
  (`timeout-minutes: 5`).
- **Artifacts**: each process streams stdout/stderr to `artifacts/e2e/<instance>.*.log`;
  CI uploads that directory as the `e2e-artifacts` bundle **only on failure**.

## Server tests (`server/`)

```bash
cd server
corepack enable
pnpm install --frozen-lockfile
pnpm test
```

Runs `tsx --test src/*.test.ts` (Node's built-in test runner). Verified locally:
13 tests pass across `aim_leaderboard.test.ts` (aim-scenario name validation),
`middleware.test.ts` (admin-auth middleware: missing/invalid ticket, non-admin
rejection only after awaiting the admin check, and the authorized pass-through
path), and `world_records.test.ts` (world-record acceptance rules, cache
lock-key stability, publish/expire behavior of the recent-records cache). These
are pure unit tests with fakes/mocks — no live Postgres connection is required.

Build (also run in CI):

```bash
pnpm build
```

Runs `tsc` (typecheck) then `tsup` to bundle `src/index.ts` and `src/migrate.ts`
into `dist/`. Verified locally to complete successfully.

## Website tests (`website/`)

```bash
cd website
corepack enable
pnpm install --frozen-lockfile
pnpm build
```

There is currently **no test script** in `website/package.json` — CI only installs
and builds the website (`vite build`), it does not run any test command. Verified
locally: `pnpm build` completes successfully.

## GitHub Actions (`.github/workflows/ci.yml`)

- **Triggers**: `pull_request` (any target) and `push` to `main`.
- **Concurrency**: grouped by `${{ github.workflow }}-${{ github.ref }}` with
  `cancel-in-progress: true`, so a new push cancels an in-flight run on the same
  ref/branch.
- **Jobs** (all run in parallel on `ubuntu-latest`, no `needs:` between them):
  - `godot` — installs Godot 4.6.1 via `chickensoft-games/setup-godot` (pinned to the
    `v2.4.1` commit SHA)
    (`use-dotnet: false`, `include-templates: false`) and Python 3.11, installs the
    pinned GDScript tooling with `pip install -r requirements-dev.txt`, then runs
    `gdformat --check src tests`, `gdlint src tests`, and `./scripts/test-godot.sh`.
  - `godot-e2e` — Godot 4.6.1 + Python 3.11, runs `./scripts/test-e2e.sh` with a
    5-minute `timeout-minutes` cap, and uploads `artifacts/e2e/` as `e2e-artifacts`
    on failure.
  - `server` — Node 22 + Corepack, `pnpm install --frozen-lockfile`, `pnpm quality`
    (Oxfmt + Oxlint for server **and** website), `pnpm test`, then `pnpm build`, all
    with `working-directory: server`.
  - `website` — Node 22 + Corepack, `pnpm install --frozen-lockfile`, then
    `pnpm build`, with `working-directory: website` (no test step; its formatting and
    lint are covered by the `server` job's `pnpm quality`).

## Current limitations

- **The server test suite has no live-database test.** All server tests use
  fakes/mocks; nothing in CI currently exercises a real Postgres connection
  end-to-end (`server/compose.yaml`'s `db` service is only used for local dev, not
  by the `server` CI job).
- **The E2E test covers only deathmatch.** The multi-process harness exercises a
  single deathmatch vertical slice (`tests/e2e/test_deathmatch.py`); elimination and
  the other modes are still covered only by the in-process Godot tests.
