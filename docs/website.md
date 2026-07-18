# Website (`website/`)

The website is a small single-page [Vue 3](https://vuejs.org) + [Vite](https://vite.dev)
app that renders the public Straif movement-run leaderboard as a read-only, paginated
table. Per the root `README.md`, the production build is hosted at
[straif.pumped.software](https://straif.pumped.software/). The whole application UI
and logic currently lives in one component, `src/App.vue` (mounted by `src/main.js`);
there is no router, store, or additional component tree.

For the leaderboard API this app consumes, see [backend.md](./backend.md); for
setup/build prerequisites and test/CI commands see [development.md](./development.md)
and [testing.md](./testing.md).

## Purpose

On mount, and whenever the user changes the mode or map selector, the app fetches a
page of runs for the selected mode/map from the backend leaderboard API and renders
them as a ranked table (position, player name, time in seconds, submission date),
with Prev/Next pagination controls.

## Current hardcoded configuration (limitation, not a recommendation)

`src/App.vue` hardcodes several values that a typical app would source from
environment/config instead. These are documented here as the **current state**,
not as how the app should work:

- **API base URL** — `const BASE_URL = "https://straifapi.pumped.software"` is a
  literal string in the component. There is no `.env`/`import.meta.env` usage, so
  the website always talks to the production API, including when run locally via
  `pnpm dev` — there is no way to point a local dev server at a local/staging
  backend without editing this line.
- **Default mode/map** — `current_mode` defaults to `'target'` and `current_map`
  defaults to `'map_rooftops'`, hardcoded as the initial `ref()` values.
- **Map list and labels** — `MODE_MAP_REF` (which map names are valid for each mode)
  and `MAP_LABELS` (display names) are hardcoded objects duplicated in the
  component. They are not derived from the server's `maps.json`
  (`server/src/maps.ts` / `get_maps_of_mode`), so the two lists can drift out of
  sync if maps are added, removed, or renamed on the server side without a matching
  edit here. (`server/scripts/populate.js` contains a third, separately
  hand-maintained copy of the same mode/map mapping.)

## Data flow / pagination

- State (`src/App.vue`, `<script setup>`): `runs`, `total_count`, `current_page`
  (1-based), `current_map`, `current_mode`.
- `load_runs()` calls
  `GET {BASE_URL}/leaderboard/mode/{current_mode}/maps/{current_map}/runs?page={current_page - 1}`
  (the API's `page` query parameter is 0-based, so the UI converts its 1-based page
  before the request), parses the JSON response, sets `runs.value = json.data.runs`,
  and computes `total_count.value = Math.ceil(json.data.total / PAGE_SIZE)` with a
  hardcoded `PAGE_SIZE = 10` matching the server's fixed page size of 10 rows.
- `load_runs()` is called: on `onMounted`, and on the `@change` handler of both the
  mode and map `<select>` elements.
- `modify_page(amount)` clamps `current_page` between `1` and
  `Math.max(total_count.value, 1)`, and only triggers `load_runs()` again if the
  page actually changed (guards against out-of-range clicks re-fetching
  needlessly).
- Table rendering: if `runs` is empty, a single "Unavailable" row spans all four
  columns; otherwise each run row shows a computed position
  (`(current_page - 1) * PAGE_SIZE + index + 1`), `run.username`, `run.time_ms / 1000`
  (converted from milliseconds to seconds, not otherwise formatted/rounded), and
  `run.created_at` truncated to a `YYYY-MM-DD`-length slice.
- There is no client-side error handling for failed/non-OK `fetch` responses (e.g.
  network failure, non-2xx status, or a response body without a `data` field).

## Dev, build, preview commands

Run from `website/` (package manager: pnpm, per `pnpm-lock.yaml`/`pnpm-workspace.yaml`;
Node engine constraint from `package.json`: `^20.19.0 || >=22.12.0`):

```bash
pnpm install     # or: npm install
pnpm dev         # vite — local dev server with HMR (talks to the hardcoded production API above)
pnpm build       # vite build — production build, output to website/dist/
pnpm preview     # vite preview — serves the built website/dist/ locally
```

These were verified as of this writing: `pnpm build` (invoked via `vite build`)
succeeds, producing `dist/index.html` plus a single hashed CSS and JS asset bundle.

## Deployment configuration considerations

- The repository contains no committed deployment/hosting configuration for the
  website (no Dockerfile, no static-host config such as Netlify/Vercel/Nginx, and
  no CI deploy step) — CI (`.github/workflows/ci.yml`, `website` job) only installs
  dependencies and runs `pnpm build` to verify the build succeeds; it does not
  publish or deploy the `dist/` output anywhere. How `dist/` actually reaches
  `straif.pumped.software` is not defined in this repo.
- `vite.config.js` uses only the default Vue + Vue Devtools plugins and a `@` ->
  `src/` path alias; there is no `base`, `server.proxy`, or environment-mode
  configuration, consistent with the API URL being hardcoded rather than
  environment-driven (see above).
- Because `BASE_URL` is compiled into the JS bundle as a literal, changing which
  API a deployed build talks to requires a source edit and rebuild — there is no
  runtime-configurable endpoint (e.g. via a served config file or env var
  substitution at deploy time).

## Testing

There is no test suite configured for the website: `package.json` defines only
`dev`, `build`, and `preview` scripts (no `test` script, and no test runner such as
Vitest/Cypress/Playwright is listed in `dependencies`/`devDependencies`). The
`.gitignore` in `website/` does list `/cypress/videos/` and `/cypress/screenshots/`
paths, but no `cypress/` directory or Cypress dependency exists in the project —
this appears to be inherited boilerplate rather than an active or planned test
setup. The CI website job builds but does not run any tests.
