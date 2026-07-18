# Minimal Leaderboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimalist black two-route Straif website with a trailer-led homepage and complete paginated Movement, Target, Aim, and Overall leaderboards.

**Architecture:** Preserve Vue 3 and Vite, add Vue Router, and separate the shared app shell, route views, leaderboard transport, route-backed state, and presentational components. Extend the Hono leaderboard API with a shared validated pagination contract so the website can request 25 rows while existing callers retain the 10-row default.

**Tech Stack:** Vue 3, Vue Router 4, Vite 7, Vitest, Vue Test Utils, jsdom, Hono, Zod, Drizzle ORM, TypeScript, pnpm.

---

## File structure

### Server

- Create `server/src/leaderboard_pagination.ts` for the shared page/limit schema, OpenAPI parameters, offsets, and in-memory pagination.
- Create `server/src/leaderboard_pagination.test.ts` for default, validation, offset, ordering, and total-count behavior.
- Modify `server/src/routes/leaderboard.ts` to paginate map and overall Movement/Target boards.
- Modify `server/src/routes/aim_leaderboard.ts` to paginate scenario and overall Aim boards.
- Modify `server/package.json` to expose the existing Node test files through `pnpm test`.

### Website foundation

- Modify `website/package.json`, `website/pnpm-lock.yaml`, and `website/vite.config.js` for Vue Router and Vitest.
- Modify `website/index.html` for language and baseline metadata.
- Modify `website/src/main.js` to install the router and global styles.
- Replace `website/src/App.vue` with the shared app shell.
- Create `website/src/router/index.js` for lazy route definitions, memory-history test injection, and route metadata.
- Create `website/src/components/layout/SiteHeader.vue` and `website/src/components/layout/SiteFooter.vue`.
- Create `website/src/styles/base.css` for tokens, reset, typography, focus, layout, table, and responsive behavior.

### Website leaderboard domain

- Create `website/src/data/leaderboards.js` for category, map, scenario, discipline, default, and column metadata.
- Create `website/src/utils/formatters.js` for times, scores, percentages, reaction times, dates, and integer formatting.
- Create `website/src/services/leaderboardApi.js` for request construction, response validation, and normalized rows.
- Create `website/src/composables/useLeaderboard.js` for abortable loading, empty, success, and error states.
- Create `website/src/components/leaderboard/LeaderboardCategoryTabs.vue`.
- Create `website/src/components/leaderboard/LeaderboardFilters.vue`.
- Create `website/src/components/leaderboard/LeaderboardStatus.vue`.
- Create `website/src/components/leaderboard/LeaderboardTable.vue`.
- Create `website/src/components/leaderboard/LeaderboardPagination.vue`.
- Create `website/src/components/leaderboard/LeaderboardPreview.vue`.
- Create `website/src/views/LeaderboardView.vue`.

### Website homepage

- Create `website/src/components/home/TrailerHero.vue`.
- Create `website/src/components/home/GameIntro.vue`.
- Create `website/src/components/home/MapGallery.vue`.
- Create `website/src/views/HomeView.vue`.
- Copy selected screenshots to `website/src/assets/maps/`.

### Tests

- Create `website/src/router/index.test.js`.
- Create `website/src/data/leaderboards.test.js`.
- Create `website/src/utils/formatters.test.js`.
- Create `website/src/services/leaderboardApi.test.js`.
- Create `website/src/composables/useLeaderboard.test.js`.
- Create `website/src/components/home/TrailerHero.test.js`.
- Create `website/src/components/leaderboard/LeaderboardTable.test.js`.
- Create `website/src/components/leaderboard/LeaderboardPagination.test.js`.
- Create `website/src/views/HomeView.test.js`.
- Create `website/src/views/LeaderboardView.test.js`.

## Task 1: Add the shared server pagination contract

**Files:**
- Create: `server/src/leaderboard_pagination.test.ts`
- Create: `server/src/leaderboard_pagination.ts`
- Modify: `server/package.json`

- [ ] **Step 1: Write the failing pagination tests**

Create `server/src/leaderboard_pagination.test.ts`:

```ts
import assert from 'node:assert/strict';
import test from 'node:test';
import {
  LeaderboardPaginationQuery,
  get_leaderboard_offset,
  paginate_leaderboard,
} from './leaderboard_pagination';

test('leaderboard pagination preserves the compatibility defaults', () => {
  assert.deepEqual(LeaderboardPaginationQuery.parse({}), {
    page: 0,
    limit: 10,
  });
});

test('leaderboard pagination coerces valid query strings', () => {
  assert.deepEqual(
    LeaderboardPaginationQuery.parse({ page: '2', limit: '25' }),
    { page: 2, limit: 25 }
  );
});

test('leaderboard pagination rejects invalid and excessive values', () => {
  assert.equal(
    LeaderboardPaginationQuery.safeParse({ page: '-1', limit: '25' }).success,
    false
  );
  assert.equal(
    LeaderboardPaginationQuery.safeParse({ page: '0', limit: '0' }).success,
    false
  );
  assert.equal(
    LeaderboardPaginationQuery.safeParse({ page: '0', limit: '101' }).success,
    false
  );
});

test('get_leaderboard_offset uses zero-based pages', () => {
  assert.equal(get_leaderboard_offset({ page: 3, limit: 25 }), 75);
});

test('paginate_leaderboard preserves order and reports the unsliced total', () => {
  const result = paginate_leaderboard(
    ['first', 'second', 'third', 'fourth', 'fifth'],
    { page: 1, limit: 2 }
  );

  assert.deepEqual(result, {
    rows: ['third', 'fourth'],
    total: 5,
  });
});
```

- [ ] **Step 2: Run the focused test and verify the missing-module failure**

Run:

```bash
cd server
pnpm exec tsx --test src/leaderboard_pagination.test.ts
```

Expected: FAIL because `./leaderboard_pagination` does not exist.

- [ ] **Step 3: Implement the pagination module**

Create `server/src/leaderboard_pagination.ts`:

```ts
import type { DescribeRouteOptions } from 'hono-openapi';
import { z } from 'zod';

type OpenApiParameter = Exclude<
  NonNullable<DescribeRouteOptions['parameters']>[number],
  { $ref: string }
>;

export const LEADERBOARD_DEFAULT_LIMIT = 10;
export const LEADERBOARD_MAX_LIMIT = 100;

export const LeaderboardPaginationQuery = z.object({
  page: z.coerce.number().int().min(0).default(0),
  limit: z.coerce
    .number()
    .int()
    .min(1)
    .max(LEADERBOARD_MAX_LIMIT)
    .default(LEADERBOARD_DEFAULT_LIMIT),
});

export type LeaderboardPagination = z.infer<
  typeof LeaderboardPaginationQuery
>;

export const LeaderboardPaginationParameters = [
  {
    name: 'page',
    in: 'query',
    required: false,
    schema: {
      type: 'integer',
      minimum: 0,
      default: 0,
    },
    description: 'Zero-based leaderboard page number.',
  },
  {
    name: 'limit',
    in: 'query',
    required: false,
    schema: {
      type: 'integer',
      minimum: 1,
      maximum: LEADERBOARD_MAX_LIMIT,
      default: LEADERBOARD_DEFAULT_LIMIT,
    },
    description: 'Rows per page.',
  },
] satisfies OpenApiParameter[];

export function get_leaderboard_offset({
  page,
  limit,
}: LeaderboardPagination) {
  return page * limit;
}

export function paginate_leaderboard<T>(
  entries: readonly T[],
  pagination: LeaderboardPagination
) {
  const offset = get_leaderboard_offset(pagination);
  return {
    rows: entries.slice(offset, offset + pagination.limit),
    total: entries.length,
  };
}
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```bash
cd server
pnpm exec tsx --test src/leaderboard_pagination.test.ts
```

Expected: 5 tests pass.

- [ ] **Step 5: Add and verify the server test script**

Add this script to `server/package.json`:

```json
"test": "tsx --test src/*.test.ts"
```

Run:

```bash
cd server
pnpm test
```

Expected: all pagination, aim leaderboard, and world-record tests pass.

- [ ] **Step 6: Commit the pagination contract**

```bash
git add server/package.json server/src/leaderboard_pagination.ts server/src/leaderboard_pagination.test.ts
git commit -m "feat: add leaderboard pagination contract" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 2: Paginate map and aim-scenario endpoints

**Files:**
- Modify: `server/src/routes/leaderboard.ts:33-63,227-289`
- Modify: `server/src/routes/aim_leaderboard.ts:46-71,178-210,379-443`

- [ ] **Step 1: Extend the pagination test with the website page size**

Add to `server/src/leaderboard_pagination.test.ts`:

```ts
test('leaderboard pagination accepts the website page size', () => {
  const parsed = LeaderboardPaginationQuery.parse({
    page: '1',
    limit: '25',
  });

  assert.equal(parsed.limit, 25);
  assert.equal(get_leaderboard_offset(parsed), 25);
});
```

- [ ] **Step 2: Run the pagination test**

Run:

```bash
cd server
pnpm exec tsx --test src/leaderboard_pagination.test.ts
```

Expected: 6 tests pass and establish the route contract before route wiring.

- [ ] **Step 3: Extend the general leaderboard route descriptor**

In `server/src/routes/leaderboard.ts`, import `DescribeRouteOptions` and the shared pagination exports:

```ts
import {
  describeRoute,
  resolver,
  validator as zValidator,
  type DescribeRouteOptions,
} from 'hono-openapi';
import {
  get_leaderboard_offset,
  LeaderboardPaginationParameters,
  LeaderboardPaginationQuery,
  paginate_leaderboard,
} from '../leaderboard_pagination';
```

Change `describe_leaderboard_route` to accept optional route metadata:

```ts
function describe_leaderboard_route<T extends z.ZodTypeAny>(
  description: string,
  success_schema: T,
  options: Omit<DescribeRouteOptions, 'description' | 'responses'> = {}
) {
  return describeRoute({
    description,
    tags: ['leaderboard'],
    ...options,
    responses: {
      200: {
        description: 'Successful',
        content: {
          'application/json': {
            schema: resolver(success_schema),
          },
        },
      },
      400: {
        description: 'Error',
        content: {
          'application/json': {
            schema: resolver(z.object({ error: z.string() })),
          },
        },
      },
    },
  });
}
```

- [ ] **Step 4: Wire page and limit into map runs**

Replace manual `page_string` parsing in the map-runs handler with:

```ts
describe_leaderboard_route(
  'Retrieves a paginated leaderboard of runs for the specified map.',
  MapRunsResponse,
  { parameters: LeaderboardPaginationParameters }
),
zValidator('query', LeaderboardPaginationQuery),
async (c) => {
  const map_name = c.req.param('map_name');
  const run_mode = coerce_to_run_mode(c.req.param('mode_name'));
  const pagination = c.req.valid('query');

  try {
    const runs_result = await db
      .select({
        time_ms: runs.time_ms,
        steam_id: runs.steam_id,
        username: runs.username,
        created_at: runs.created_at,
      })
      .from(runs)
      .where(and(eq(runs.map_name, map_name), eq(runs.mode, run_mode)))
      .orderBy(asc(runs.time_ms))
      .limit(pagination.limit)
      .offset(get_leaderboard_offset(pagination));

    const formatted_result = runs_result.map((run) => ({
      ...run,
      created_at: format_date(run.created_at),
    }));

    return c.json({
      data: {
        runs: formatted_result,
        total: await get_run_count(run_mode, map_name),
      },
    });
  } catch (e) {
    console.log(e);
    return c.json({ error: 'Internal server error' }, 500);
  }
}
```

- [ ] **Step 5: Replace the aim route's local page schema**

In `server/src/routes/aim_leaderboard.ts`, remove `PaginationQuery` and `PageQueryParameter`, then import:

```ts
import {
  get_leaderboard_offset,
  LeaderboardPaginationParameters,
  LeaderboardPaginationQuery,
} from '../leaderboard_pagination';
```

Update the scenario endpoint metadata and query validation:

```ts
parameters: [ScenarioPathParameter, ...LeaderboardPaginationParameters]
```

```ts
zValidator('query', LeaderboardPaginationQuery)
```

Use:

```ts
const pagination = c.req.valid('query');
```

and replace the fixed query pagination with:

```ts
.limit(pagination.limit)
.offset(get_leaderboard_offset(pagination))
```

Set each returned position with:

```ts
formatAimScoreRow(
  score,
  get_leaderboard_offset(pagination) + index + 1
)
```

- [ ] **Step 6: Run server tests and build**

Run:

```bash
cd server
pnpm test
pnpm build
```

Expected: all tests pass and TypeScript/tsup complete without errors.

- [ ] **Step 7: Commit map and scenario pagination**

```bash
git add server/src/routes/leaderboard.ts server/src/routes/aim_leaderboard.ts server/src/leaderboard_pagination.test.ts
git commit -m "feat: paginate leaderboard routes" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 3: Paginate every overall leaderboard

**Files:**
- Modify: `server/src/leaderboard_pagination.test.ts`
- Modify: `server/src/routes/leaderboard.ts:76-131`
- Modify: `server/src/routes/aim_leaderboard.ts:148-161,163-176,445-483`

- [ ] **Step 1: Add the overall slicing regression test**

Add:

```ts
test('paginate_leaderboard can expose every overall entry across pages', () => {
  const entries = Array.from({ length: 53 }, (_, index) => ({
    rank: index + 1,
  }));

  const first = paginate_leaderboard(entries, { page: 0, limit: 25 });
  const last = paginate_leaderboard(entries, { page: 2, limit: 25 });

  assert.equal(first.rows.length, 25);
  assert.equal(last.rows.length, 3);
  assert.equal(last.rows[0].rank, 51);
  assert.equal(last.total, 53);
});
```

- [ ] **Step 2: Run the focused test**

Run:

```bash
cd server
pnpm exec tsx --test src/leaderboard_pagination.test.ts
```

Expected: all pagination tests pass.

- [ ] **Step 3: Paginate Movement and Target overall results**

Replace the overall response schema with:

```ts
const OverallLeaderboardResponse = z.object({
  data: z.array(PlayerPoints),
  total: z.number().int().min(0),
});
```

Add pagination metadata and validation to `/mode/:mode_name/overall`, retrieve:

```ts
const pagination = c.req.valid('query');
```

After constructing and sorting the complete `points_map`, paginate it:

```ts
const sorted_leaderboard = Array.from(points_map.values()).sort(
  (a, b) => b.points - a.points || a.steam_id.localeCompare(b.steam_id)
);
const page = paginate_leaderboard(sorted_leaderboard, pagination);

return c.json({
  data: page.rows,
  total: page.total,
});
```

The route declaration must include:

```ts
describe_leaderboard_route(
  'Fetches the overall leaderboard for a specific mode.',
  OverallLeaderboardResponse,
  { parameters: LeaderboardPaginationParameters }
),
zValidator('query', LeaderboardPaginationQuery)
```

- [ ] **Step 4: Paginate overall Aim in SQL**

Update the response:

```ts
const AimOverallLeaderboardResponse = z.object({
  data: z.object({
    scores: z.array(AimOverallScore),
    total: z.number().int().min(0),
  }),
});
```

Add:

```ts
const DistinctPlayerCount =
  sql<number>`count(distinct ${aim_scores.steam_id})`.mapWith(Number);
```

Add pagination metadata and validation to `/overall`, then replace its handler body with:

```ts
const pagination = c.req.valid('query');

try {
  const [scores, totals] = await Promise.all([
    db
      .select({
        steam_id: aim_scores.steam_id,
        username: DeterministicUsername,
        total_score: TotalScore,
        scenarios_completed: ScenariosCompleted,
        accuracy: AccuracyAverage,
        avg_reaction_ms: AvgReaction,
      })
      .from(aim_scores)
      .groupBy(aim_scores.steam_id)
      .orderBy(
        desc(TotalScoreExpression),
        desc(ScenariosCompletedExpression),
        desc(AccuracyAverageExpression),
        asc(AvgReactionExpression),
        asc(aim_scores.steam_id)
      )
      .limit(pagination.limit)
      .offset(get_leaderboard_offset(pagination)),
    db.select({ count: DistinctPlayerCount }).from(aim_scores),
  ]);

  return c.json({
    data: {
      scores,
      total: totals[0].count,
    },
  });
} catch (e) {
  console.log(e);
  return c.json({ error: 'Internal server error' }, 500);
}
```

- [ ] **Step 5: Run complete server verification**

Run:

```bash
cd server
pnpm test
pnpm build
```

Expected: all tests pass and the production server bundle succeeds.

- [ ] **Step 6: Commit complete API pagination**

```bash
git add server/src/leaderboard_pagination.test.ts server/src/routes/leaderboard.ts server/src/routes/aim_leaderboard.ts
git commit -m "feat: expose complete overall leaderboards" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 4: Establish the tested Vue router and semantic shell

**Files:**
- Modify: `website/package.json`
- Modify: `website/pnpm-lock.yaml`
- Modify: `website/vite.config.js`
- Modify: `website/src/main.js`
- Replace: `website/src/App.vue`
- Create: `website/src/router/index.js`
- Create: `website/src/router/index.test.js`
- Create: `website/src/components/layout/SiteHeader.vue`
- Create: `website/src/components/layout/SiteFooter.vue`
- Create: `website/src/views/HomeView.vue`
- Create: `website/src/views/LeaderboardView.vue`

- [ ] **Step 1: Install only the approved dependencies**

Run:

```bash
cd website
pnpm add vue-router@^4
pnpm add -D vitest @vue/test-utils jsdom
```

Expected: `package.json` and `pnpm-lock.yaml` update without unrelated dependency upgrades.

- [ ] **Step 2: Add the test script and environment**

Add to `website/package.json`:

```json
"test": "vitest run"
```

Add to `defineConfig` in `website/vite.config.js`:

```js
test: {
  environment: 'jsdom',
  clearMocks: true,
}
```

- [ ] **Step 3: Write the failing router test**

Create `website/src/router/index.test.js`:

```js
import { describe, expect, it } from 'vitest'
import { createMemoryHistory } from 'vue-router'
import { createStraifRouter } from './index'

describe('Straif router', () => {
  it('defines home and leaderboard routes with document metadata', async () => {
    const router = createStraifRouter(createMemoryHistory())

    await router.push('/leaderboard')
    await router.isReady()

    expect(router.currentRoute.value.name).toBe('leaderboard')
    expect(router.currentRoute.value.meta.title).toBe('Leaderboard — Straif')
    expect(router.getRoutes().map((route) => route.path)).toEqual(
      expect.arrayContaining(['/', '/leaderboard'])
    )
  })
})
```

- [ ] **Step 4: Run the test and verify it fails**

Run:

```bash
cd website
pnpm test -- src/router/index.test.js
```

Expected: FAIL because `createStraifRouter` does not exist.

- [ ] **Step 5: Create the router**

Create `website/src/router/index.js`:

```js
import {
  createRouter,
  createWebHistory,
} from 'vue-router'

const routes = [
  {
    path: '/',
    name: 'home',
    component: () => import('@/views/HomeView.vue'),
    meta: {
      title: 'Straif',
      description:
        'Straif is a fast-paced 3D platforming shooter built around movement and global leaderboards.',
    },
  },
  {
    path: '/leaderboard',
    name: 'leaderboard',
    component: () => import('@/views/LeaderboardView.vue'),
    meta: {
      title: 'Leaderboard — Straif',
      description:
        'Browse Straif movement, target, aim, and overall leaderboards.',
    },
  },
]

export function createStraifRouter(history = createWebHistory()) {
  const router = createRouter({ history, routes })

  router.afterEach((to) => {
    document.title = to.meta.title
    document
      .querySelector('meta[name="description"]')
      ?.setAttribute('content', to.meta.description)
  })

  return router
}
```

- [ ] **Step 6: Create the semantic shell**

Create `SiteHeader.vue`:

```vue
<template>
  <header class="site-header">
    <RouterLink class="wordmark" to="/" aria-label="Straif home">Straif</RouterLink>
    <nav aria-label="Primary navigation">
      <RouterLink to="/">Home</RouterLink>
      <RouterLink to="/leaderboard">Leaderboard</RouterLink>
    </nav>
  </header>
</template>
```

Create `SiteFooter.vue`:

```vue
<template>
  <footer class="site-footer">
    <p>© {{ new Date().getFullYear() }} Straif</p>
    <nav aria-label="Footer navigation">
      <RouterLink to="/">Home</RouterLink>
      <RouterLink to="/leaderboard">Leaderboard</RouterLink>
      <a href="https://straifapi.pumped.software/docs">API</a>
    </nav>
  </footer>
</template>
```

Replace `App.vue`:

```vue
<script setup>
import SiteFooter from '@/components/layout/SiteFooter.vue'
import SiteHeader from '@/components/layout/SiteHeader.vue'
</script>

<template>
  <a class="skip-link" href="#main-content">Skip to content</a>
  <SiteHeader />
  <RouterView />
  <SiteFooter />
</template>
```

Use minimal temporary route views:

```vue
<!-- HomeView.vue -->
<template><main id="main-content"><h1>Straif</h1></main></template>
```

```vue
<!-- LeaderboardView.vue -->
<template><main id="main-content"><h1>Leaderboard</h1></main></template>
```

Update `main.js`:

```js
import { createApp } from 'vue'
import App from './App.vue'
import { createStraifRouter } from './router'
import './styles/base.css'

createApp(App).use(createStraifRouter()).mount('#app')
```

Create an initial `styles/base.css` containing the reset and focus contract:

```css
:root {
  color-scheme: dark;
  font-family: Archivo, Arial, sans-serif;
  background: #050505;
  color: #f2f2ed;
}

* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body { margin: 0; min-width: 320px; background: #050505; }
a { color: inherit; }
button, select { font: inherit; }
:focus-visible { outline: 2px solid #f2f2ed; outline-offset: 4px; }
.skip-link { position: fixed; left: 1rem; top: -5rem; z-index: 100; }
.skip-link:focus { top: 1rem; }
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, *::before, *::after { transition-duration: 0.01ms !important; }
}
```

- [ ] **Step 7: Run router test and build**

Run:

```bash
cd website
pnpm test -- src/router/index.test.js
pnpm build
```

Expected: router test passes and Vite builds both lazy routes.

- [ ] **Step 8: Commit the Vue foundation**

```bash
git add website
git commit -m "feat: add website routes and semantic shell" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 5: Define leaderboard metadata and formatters

**Files:**
- Create: `website/src/data/leaderboards.test.js`
- Create: `website/src/data/leaderboards.js`
- Create: `website/src/utils/formatters.test.js`
- Create: `website/src/utils/formatters.js`

- [ ] **Step 1: Write the failing metadata and formatter tests**

Create `website/src/data/leaderboards.test.js`:

```js
import { describe, expect, it } from 'vitest'
import {
  getCategoryMaps,
  normalizeLeaderboardQuery,
} from './leaderboards'

describe('leaderboard metadata', () => {
  it('excludes bhop-only maps from Target', () => {
    expect(getCategoryMaps('target').map((map) => map.value)).not.toContain(
      'map_taurus'
    )
    expect(getCategoryMaps('movement').map((map) => map.value)).toContain(
      'map_taurus'
    )
  })

  it('normalizes incompatible route values', () => {
    expect(
      normalizeLeaderboardQuery({
        category: 'aim',
        scenario: 'unknown',
        page: '-4',
      })
    ).toEqual({
      category: 'aim',
      scenario: 'gridshot',
      page: 1,
    })
  })
})
```

Create `website/src/utils/formatters.test.js`:

```js
import { describe, expect, it } from 'vitest'
import {
  formatDate,
  formatInteger,
  formatPercentage,
  formatReaction,
  formatTime,
} from './formatters'

describe('leaderboard formatters', () => {
  it('formats leaderboard metrics consistently', () => {
    expect(formatTime(18_442)).toBe('18.442s')
    expect(formatInteger(84220)).toBe('84,220')
    expect(formatPercentage(92.456)).toBe('92.46%')
    expect(formatReaction(243.6)).toBe('244ms')
    expect(formatDate('2026-07-18T11:00:00.000Z')).toBe('2026.07.18')
  })
})
```

- [ ] **Step 2: Run tests and verify missing-module failures**

Run:

```bash
cd website
pnpm test -- src/data/leaderboards.test.js src/utils/formatters.test.js
```

Expected: FAIL because both implementation modules are missing.

- [ ] **Step 3: Implement metadata**

Create `website/src/data/leaderboards.js` with:

```js
export const PAGE_SIZE = 25

export const CATEGORIES = [
  { value: 'movement', label: 'Movement' },
  { value: 'target', label: 'Target' },
  { value: 'aim', label: 'Aim' },
  { value: 'overall', label: 'Overall' },
]

export const MAPS = [
  ['Tutorial', 'Tutorial', ['movement', 'target']],
  ['map_rooftops', 'Rooftops', ['movement', 'target']],
  ['map_streets', 'Streets', ['movement', 'target']],
  ['map_flow', 'Flow', ['movement', 'target']],
  ['map_line', 'Line', ['movement']],
  ['map_rookie', 'Rookie', ['movement']],
  ['map_dawn', 'Dawn', ['movement']],
  ['map_structure', 'Structure', ['movement', 'target']],
  ['map_graybox', 'Graybox', ['movement', 'target']],
  ['map_graybox2', 'Graybox 2', ['movement', 'target']],
  ['map_subway', 'Subway', ['movement', 'target']],
  ['map_rooftops2', 'Rooftops 2', ['movement', 'target']],
  ['map_slope', 'Slope', ['movement']],
  ['map_taurus', 'Taurus', ['movement']],
].map(([value, label, categories]) => ({ value, label, categories }))

export const AIM_SCENARIOS = [
  { value: 'gridshot', label: 'Gridshot' },
  { value: 'flick', label: 'Flick' },
  { value: 'tracking', label: 'Tracking' },
]

export const OVERALL_DISCIPLINES = [
  { value: 'movement', label: 'Movement' },
  { value: 'target', label: 'Target' },
  { value: 'aim', label: 'Aim' },
]

export function getCategoryMaps(category) {
  return MAPS.filter((map) => map.categories.includes(category))
}

export function normalizeLeaderboardQuery(query = {}) {
  const category = CATEGORIES.some((entry) => entry.value === query.category)
    ? query.category
    : 'movement'
  const page = Math.max(Number.parseInt(query.page, 10) || 1, 1)

  if (category === 'aim') {
    const scenario = AIM_SCENARIOS.some(
      (entry) => entry.value === query.scenario
    )
      ? query.scenario
      : 'gridshot'
    return { category, scenario, page }
  }

  if (category === 'overall') {
    const discipline = OVERALL_DISCIPLINES.some(
      (entry) => entry.value === query.discipline
    )
      ? query.discipline
      : 'movement'
    return { category, discipline, page }
  }

  const maps = getCategoryMaps(category)
  const map = maps.some((entry) => entry.value === query.map)
    ? query.map
    : 'map_rooftops'
  return { category, map, page }
}
```

- [ ] **Step 4: Implement formatters**

Create `website/src/utils/formatters.js`:

```js
const integerFormatter = new Intl.NumberFormat('en-US', {
  maximumFractionDigits: 0,
})

export const formatInteger = (value) => integerFormatter.format(value)
export const formatTime = (value) => `${(value / 1000).toFixed(3)}s`
export const formatPercentage = (value) => `${Number(value).toFixed(2)}%`
export const formatReaction = (value) => `${Math.round(value)}ms`
export const formatDate = (value) =>
  new Date(value).toISOString().slice(0, 10).replaceAll('-', '.')
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
cd website
pnpm test -- src/data/leaderboards.test.js src/utils/formatters.test.js
```

Expected: all metadata and formatter tests pass.

- [ ] **Step 6: Commit domain metadata**

```bash
git add website/src/data website/src/utils
git commit -m "feat: define leaderboard metadata" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 6: Build and test the normalized leaderboard API client

**Files:**
- Create: `website/src/services/leaderboardApi.test.js`
- Create: `website/src/services/leaderboardApi.js`

- [ ] **Step 1: Write failing request and normalization tests**

Create tests covering these exact cases:

```js
import { describe, expect, it, vi } from 'vitest'
import { fetchLeaderboard } from './leaderboardApi'

function response(body, ok = true) {
  return { ok, json: vi.fn().mockResolvedValue(body) }
}

describe('fetchLeaderboard', () => {
  it('requests a 25-row Movement page and normalizes ranks', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      response({
        data: {
          runs: [{
            steam_id: '1',
            username: 'Alice',
            time_ms: 18442,
            created_at: '2026-07-18',
          }],
          total: 26,
        },
      })
    )

    const result = await fetchLeaderboard(
      { category: 'movement', map: 'map_rooftops', page: 2 },
      { fetchImpl }
    )

    expect(fetchImpl).toHaveBeenCalledWith(
      expect.stringContaining(
        '/leaderboard/mode/bhop/maps/map_rooftops/runs?page=1&limit=25'
      ),
      expect.objectContaining({ signal: undefined })
    )
    expect(result.rows[0]).toMatchObject({
      id: '1',
      rank: 26,
      username: 'Alice',
      time_ms: 18442,
    })
    expect(result.total).toBe(26)
  })

  it('normalizes overall Aim scores', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      response({
        data: {
          scores: [{
            steam_id: '2',
            username: 'Bob',
            total_score: 84220,
            scenarios_completed: 3,
            accuracy: 92.4,
            avg_reaction_ms: 240,
          }],
          total: 1,
        },
      })
    )

    const result = await fetchLeaderboard(
      { category: 'overall', discipline: 'aim', page: 1 },
      { fetchImpl }
    )

    expect(result.rows[0].total_score).toBe(84220)
    expect(result.total).toBe(1)
  })

  it('throws the API message for failed requests', async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValue(response({ error: 'Leaderboard unavailable.' }, false))

    await expect(
      fetchLeaderboard(
        { category: 'aim', scenario: 'gridshot', page: 1 },
        { fetchImpl }
      )
    ).rejects.toThrow('Leaderboard unavailable.')
  })
})
```

- [ ] **Step 2: Run the test and verify failure**

Run:

```bash
cd website
pnpm test -- src/services/leaderboardApi.test.js
```

Expected: FAIL because `fetchLeaderboard` does not exist.

- [ ] **Step 3: Implement endpoint selection and normalization**

Create `website/src/services/leaderboardApi.js`:

```js
import { PAGE_SIZE } from '@/data/leaderboards'

const BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? 'https://straifapi.pumped.software'

function endpointFor(query) {
  const params = new URLSearchParams({
    page: String(query.page - 1),
    limit: String(PAGE_SIZE),
  })

  if (query.category === 'aim') {
    return `/leaderboard/aim/scenarios/${query.scenario}/scores?${params}`
  }

  if (query.category === 'overall') {
    if (query.discipline === 'aim') {
      return `/leaderboard/aim/overall?${params}`
    }
    const mode = query.discipline === 'target' ? 'target' : 'bhop'
    return `/leaderboard/mode/${mode}/overall?${params}`
  }

  const mode = query.category === 'target' ? 'target' : 'bhop'
  return `/leaderboard/mode/${mode}/maps/${query.map}/runs?${params}`
}

function normalizeRows(query, body) {
  if (query.category === 'aim') return body.data.scores
  if (query.category === 'overall' && query.discipline === 'aim') {
    return body.data.scores
  }
  if (query.category === 'overall') return body.data
  return body.data.runs
}

function normalizeTotal(query, body) {
  if (query.category === 'aim') return body.data.total
  if (query.category === 'overall' && query.discipline === 'aim') {
    return body.data.total
  }
  if (query.category === 'overall') return body.total
  return body.data.total
}

export async function fetchLeaderboard(
  query,
  { signal, fetchImpl = fetch } = {}
) {
  const response = await fetchImpl(`${BASE_URL}${endpointFor(query)}`, {
    signal,
  })
  const body = await response.json()

  if (!response.ok) {
    throw new Error(body.error ?? 'Could not load the leaderboard.')
  }

  const offset = (query.page - 1) * PAGE_SIZE
  return {
    rows: normalizeRows(query, body).map((row, index) => ({
      ...row,
      id: row.steam_id,
      rank: row.position ?? offset + index + 1,
    })),
    total: normalizeTotal(query, body),
  }
}
```

- [ ] **Step 4: Run the focused API tests**

Run:

```bash
cd website
pnpm test -- src/services/leaderboardApi.test.js
```

Expected: all API client tests pass.

- [ ] **Step 5: Commit the API client**

```bash
git add website/src/services
git commit -m "feat: add leaderboard API client" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 7: Add abortable leaderboard state

**Files:**
- Create: `website/src/composables/useLeaderboard.test.js`
- Create: `website/src/composables/useLeaderboard.js`

- [ ] **Step 1: Write failing state-transition tests**

Create tests that mount the composable in an effect scope:

```js
import { computed, effectScope, nextTick, ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'
import { useLeaderboard } from './useLeaderboard'

describe('useLeaderboard', () => {
  it('loads rows and exposes success state', async () => {
    const request = ref({ category: 'movement', map: 'map_rooftops', page: 1 })
    const loader = vi.fn().mockResolvedValue({ rows: [{ id: '1' }], total: 1 })
    const scope = effectScope()
    const state = scope.run(() =>
      useLeaderboard(computed(() => request.value), loader)
    )

    await vi.waitFor(() => expect(state.status.value).toBe('success'))
    expect(state.rows.value).toEqual([{ id: '1' }])
    scope.stop()
  })

  it('aborts the stale request when filters change', async () => {
    const request = ref({ category: 'movement', map: 'map_rooftops', page: 1 })
    const signals = []
    const loader = vi.fn((_query, { signal }) => {
      signals.push(signal)
      return new Promise(() => {})
    })
    const scope = effectScope()
    scope.run(() => useLeaderboard(computed(() => request.value), loader))

    request.value = { category: 'movement', map: 'map_streets', page: 1 }
    await nextTick()

    expect(signals[0].aborted).toBe(true)
    scope.stop()
  })
})
```

- [ ] **Step 2: Run the test and verify failure**

Run:

```bash
cd website
pnpm test -- src/composables/useLeaderboard.test.js
```

Expected: FAIL because the composable is missing.

- [ ] **Step 3: Implement the composable**

Create `website/src/composables/useLeaderboard.js`:

```js
import { onScopeDispose, ref, watch } from 'vue'
import { fetchLeaderboard } from '@/services/leaderboardApi'

export function useLeaderboard(request, loader = fetchLeaderboard) {
  const rows = ref([])
  const total = ref(0)
  const status = ref('loading')
  const error = ref('')
  let controller

  async function load() {
    controller?.abort()
    controller = new AbortController()
    status.value = 'loading'
    error.value = ''

    try {
      const result = await loader(request.value, {
        signal: controller.signal,
      })
      rows.value = result.rows
      total.value = result.total
      status.value = result.rows.length === 0 ? 'empty' : 'success'
    } catch (cause) {
      if (cause?.name === 'AbortError') return
      rows.value = []
      total.value = 0
      error.value =
        cause instanceof Error ? cause.message : 'Could not load the leaderboard.'
      status.value = 'error'
    }
  }

  watch(request, load, { deep: true, immediate: true })
  onScopeDispose(() => controller?.abort())

  return { rows, total, status, error, reload: load }
}
```

- [ ] **Step 4: Run composable tests**

Run:

```bash
cd website
pnpm test -- src/composables/useLeaderboard.test.js
```

Expected: all composable tests pass.

- [ ] **Step 5: Commit leaderboard state**

```bash
git add website/src/composables
git commit -m "feat: add abortable leaderboard state" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 8: Build the semantic leaderboard primitives

**Files:**
- Create: `website/src/components/leaderboard/LeaderboardTable.test.js`
- Create: `website/src/components/leaderboard/LeaderboardPagination.test.js`
- Create: `website/src/components/leaderboard/LeaderboardCategoryTabs.vue`
- Create: `website/src/components/leaderboard/LeaderboardFilters.vue`
- Create: `website/src/components/leaderboard/LeaderboardStatus.vue`
- Create: `website/src/components/leaderboard/LeaderboardTable.vue`
- Create: `website/src/components/leaderboard/LeaderboardPagination.vue`

- [ ] **Step 1: Write the failing semantic table test**

Create:

```js
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import LeaderboardTable from './LeaderboardTable.vue'

describe('LeaderboardTable', () => {
  it('renders a caption, scoped headers, and formatted cells', () => {
    const wrapper = mount(LeaderboardTable, {
      props: {
        caption: 'Rooftops Bhop leaderboard',
        columns: [
          { key: 'rank', label: 'Rank', format: (row) => row.rank },
          { key: 'username', label: 'Player', format: (row) => row.username },
          { key: 'time', label: 'Time', format: (row) => `${row.time_ms}ms` },
        ],
        rows: [{ id: '1', rank: 1, username: 'Alice', time_ms: 18442 }],
      },
    })

    expect(wrapper.get('caption').text()).toBe('Rooftops Bhop leaderboard')
    expect(wrapper.findAll('th[scope="col"]')).toHaveLength(3)
    expect(wrapper.get('tbody th[scope="row"]').text()).toBe('1')
    expect(wrapper.text()).toContain('Alice')
  })
})
```

- [ ] **Step 2: Write the failing pagination test**

Create:

```js
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import LeaderboardPagination from './LeaderboardPagination.vue'

describe('LeaderboardPagination', () => {
  it('labels navigation and emits the selected page', async () => {
    const wrapper = mount(LeaderboardPagination, {
      props: { page: 2, total: 76, pageSize: 25 },
    })

    expect(wrapper.get('nav').attributes('aria-label')).toBe(
      'Leaderboard pages'
    )
    expect(wrapper.text()).toContain('26–50 of 76')
    await wrapper.get('button[aria-label="Go to page 3"]').trigger('click')
    expect(wrapper.emitted('update:page')).toEqual([[3]])
  })
})
```

- [ ] **Step 3: Run tests and verify missing-component failures**

Run:

```bash
cd website
pnpm test -- src/components/leaderboard/LeaderboardTable.test.js src/components/leaderboard/LeaderboardPagination.test.js
```

Expected: FAIL because both components are missing.

- [ ] **Step 4: Implement the generic table**

Create `LeaderboardTable.vue`:

```vue
<script setup>
defineProps({
  caption: { type: String, required: true },
  columns: { type: Array, required: true },
  rows: { type: Array, required: true },
})
</script>

<template>
  <div class="table-scroll" tabindex="0" aria-label="Scrollable leaderboard">
    <table class="leaderboard-table">
      <caption>{{ caption }}</caption>
      <thead>
        <tr>
          <th v-for="column in columns" :key="column.key" scope="col">
            {{ column.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.id">
          <template v-for="(column, index) in columns" :key="column.key">
            <th v-if="index === 0" scope="row">{{ column.format(row) }}</th>
            <td v-else>{{ column.format(row) }}</td>
          </template>
        </tr>
      </tbody>
    </table>
  </div>
</template>
```

- [ ] **Step 5: Implement numbered pagination**

Create `LeaderboardPagination.vue` with computed total pages, displayed range, and a bounded five-page window:

```vue
<script setup>
import { computed } from 'vue'

const props = defineProps({
  page: { type: Number, required: true },
  total: { type: Number, required: true },
  pageSize: { type: Number, required: true },
})
const emit = defineEmits(['update:page'])

const totalPages = computed(() => Math.max(Math.ceil(props.total / props.pageSize), 1))
const start = computed(() => (props.total ? (props.page - 1) * props.pageSize + 1 : 0))
const end = computed(() => Math.min(props.page * props.pageSize, props.total))
const pages = computed(() => {
  const first = Math.max(1, Math.min(props.page - 2, totalPages.value - 4))
  const last = Math.min(totalPages.value, first + 4)
  return Array.from({ length: last - first + 1 }, (_, index) => first + index)
})
</script>

<template>
  <nav class="pagination" aria-label="Leaderboard pages">
    <p>{{ start }}–{{ end }} of {{ total }}</p>
    <div class="pagination-controls">
      <button
        type="button"
        :disabled="page === 1"
        aria-label="Go to previous page"
        @click="emit('update:page', page - 1)"
      >←</button>
      <button
        v-for="pageNumber in pages"
        :key="pageNumber"
        type="button"
        :aria-current="pageNumber === page ? 'page' : undefined"
        :aria-label="`Go to page ${pageNumber}`"
        @click="emit('update:page', pageNumber)"
      >{{ pageNumber }}</button>
      <button
        type="button"
        :disabled="page === totalPages"
        aria-label="Go to next page"
        @click="emit('update:page', page + 1)"
      >→</button>
    </div>
  </nav>
</template>
```

- [ ] **Step 6: Implement tabs, filters, and status**

Create `LeaderboardCategoryTabs.vue`:

```vue
<script setup>
defineProps({
  categories: { type: Array, required: true },
  modelValue: { type: String, required: true },
})
const emit = defineEmits(['update:modelValue'])
</script>

<template>
  <nav class="leaderboard-tabs" aria-label="Leaderboard categories">
    <button
      v-for="category in categories"
      :key="category.value"
      type="button"
      :data-category="category.value"
      :aria-current="category.value === modelValue ? 'page' : undefined"
      @click="emit('update:modelValue', category.value)"
    >
      {{ category.label }}
    </button>
  </nav>
</template>
```

Create `LeaderboardFilters.vue` so only the compatible native select is present:

```vue
<script setup>
defineProps({
  category: { type: String, required: true },
  map: { type: String, default: '' },
  scenario: { type: String, default: '' },
  discipline: { type: String, default: '' },
  maps: { type: Array, required: true },
  scenarios: { type: Array, required: true },
  disciplines: { type: Array, required: true },
})
defineEmits(['update:map', 'update:scenario', 'update:discipline'])
</script>

<template>
  <div class="leaderboard-filters">
    <label v-if="category === 'movement' || category === 'target'">
      <span>Map</span>
      <select :value="map" @change="$emit('update:map', $event.target.value)">
        <option v-for="option in maps" :key="option.value" :value="option.value">
          {{ option.label }}
        </option>
      </select>
    </label>
    <label v-else-if="category === 'aim'">
      <span>Scenario</span>
      <select :value="scenario" @change="$emit('update:scenario', $event.target.value)">
        <option v-for="option in scenarios" :key="option.value" :value="option.value">
          {{ option.label }}
        </option>
      </select>
    </label>
    <label v-else>
      <span>Discipline</span>
      <select :value="discipline" @change="$emit('update:discipline', $event.target.value)">
        <option v-for="option in disciplines" :key="option.value" :value="option.value">
          {{ option.label }}
        </option>
      </select>
    </label>
  </div>
</template>
```

Create `LeaderboardStatus.vue`:

```vue
<script setup>
defineProps({
  status: { type: String, required: true },
  error: { type: String, default: '' },
})
defineEmits(['retry'])
</script>

<template>
  <div class="leaderboard-status" aria-live="polite">
    <p v-if="status === 'loading'">Loading leaderboard…</p>
    <p v-else-if="status === 'empty'">No records exist for this selection.</p>
    <div v-else-if="status === 'error'">
      <p>{{ error }}</p>
      <button type="button" @click="$emit('retry')">Try again</button>
    </div>
  </div>
</template>
```

- [ ] **Step 7: Run component tests**

Run:

```bash
cd website
pnpm test -- src/components/leaderboard
```

Expected: table and pagination tests pass.

- [ ] **Step 8: Commit leaderboard primitives**

```bash
git add website/src/components/leaderboard
git commit -m "feat: add semantic leaderboard components" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 9: Assemble the complete route-backed leaderboard

**Files:**
- Create: `website/src/views/LeaderboardView.test.js`
- Replace: `website/src/views/LeaderboardView.vue`
- Modify: `website/src/data/leaderboards.js`

- [ ] **Step 1: Add column factories to leaderboard metadata**

Import formatters and export `getLeaderboardColumns(query)` with these exact column sets:

```js
const rank = { key: 'rank', label: 'Rank', format: (row) => row.rank }
const player = {
  key: 'username',
  label: 'Player',
  format: (row) => row.username,
}

export function getLeaderboardColumns(query) {
  if (query.category === 'aim') {
    return [
      rank,
      player,
      { key: 'score', label: 'Score', format: (row) => formatInteger(row.score) },
      { key: 'accuracy', label: 'Accuracy', format: (row) => formatPercentage(row.accuracy) },
      { key: 'reaction', label: 'Reaction', format: (row) => formatReaction(row.avg_reaction_ms) },
      { key: 'date', label: 'Date', format: (row) => formatDate(row.created_at) },
    ]
  }

  if (query.category === 'overall' && query.discipline === 'aim') {
    return [
      rank,
      player,
      { key: 'total', label: 'Total score', format: (row) => formatInteger(row.total_score) },
      { key: 'scenarios', label: 'Scenarios', format: (row) => row.scenarios_completed },
      { key: 'accuracy', label: 'Accuracy', format: (row) => formatPercentage(row.accuracy) },
      { key: 'reaction', label: 'Reaction', format: (row) => formatReaction(row.avg_reaction_ms) },
    ]
  }

  if (query.category === 'overall') {
    return [
      rank,
      player,
      { key: 'points', label: 'Points', format: (row) => formatInteger(row.points) },
    ]
  }

  return [
    rank,
    player,
    { key: 'time', label: 'Time', format: (row) => formatTime(row.time_ms) },
    { key: 'date', label: 'Date', format: (row) => formatDate(row.created_at) },
  ]
}
```

- [ ] **Step 2: Write the failing view test**

Create a test that mocks `fetchLeaderboard`, mounts with a memory router, and verifies URL normalization and page resets:

```js
it('normalizes filters and resets the page when the category changes', async () => {
  const router = createStraifRouter(createMemoryHistory())
  await router.push('/leaderboard?category=movement&map=map_taurus&page=3')
  await router.isReady()
  const wrapper = mount(LeaderboardView, {
    global: { plugins: [router] },
  })

  await vi.waitFor(() => expect(wrapper.text()).toContain('Leaderboard'))
  await wrapper.get('button[data-category="target"]').trigger('click')

  expect(router.currentRoute.value.query).toMatchObject({
    category: 'target',
    map: 'map_rooftops',
    page: '1',
  })
})
```

- [ ] **Step 3: Run the test and verify it fails**

Run:

```bash
cd website
pnpm test -- src/views/LeaderboardView.test.js
```

Expected: FAIL because the temporary view has no route-backed controls.

- [ ] **Step 4: Implement `LeaderboardView.vue`**

Replace `LeaderboardView.vue` with:

```vue
<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import LeaderboardCategoryTabs from '@/components/leaderboard/LeaderboardCategoryTabs.vue'
import LeaderboardFilters from '@/components/leaderboard/LeaderboardFilters.vue'
import LeaderboardPagination from '@/components/leaderboard/LeaderboardPagination.vue'
import LeaderboardStatus from '@/components/leaderboard/LeaderboardStatus.vue'
import LeaderboardTable from '@/components/leaderboard/LeaderboardTable.vue'
import { useLeaderboard } from '@/composables/useLeaderboard'
import {
  AIM_SCENARIOS,
  CATEGORIES,
  OVERALL_DISCIPLINES,
  PAGE_SIZE,
  getCategoryMaps,
  getLeaderboardColumns,
  normalizeLeaderboardQuery,
} from '@/data/leaderboards'

const route = useRoute()
const router = useRouter()
const resultsHeading = ref()
const normalized = computed(() => normalizeLeaderboardQuery(route.query))
const serialized = computed(() =>
  Object.fromEntries(
    Object.entries(normalized.value).map(([key, value]) => [key, String(value)])
  )
)
const request = computed(() => normalized.value)
const { rows, total, status, error, reload } = useLeaderboard(request)

watch(
  serialized,
  (query) => {
    const current = Object.fromEntries(
      Object.entries(route.query).map(([key, value]) => [key, String(value)])
    )
    if (JSON.stringify(current) !== JSON.stringify(query)) {
      router.replace({ name: 'leaderboard', query })
    }
  },
  { immediate: true }
)

const maps = computed(() => getCategoryMaps(normalized.value.category))
const columns = computed(() => getLeaderboardColumns(normalized.value))

function optionLabel(options, value) {
  return options.find((option) => option.value === value)?.label ?? value
}

const boardTitle = computed(() => {
  const query = normalized.value
  if (query.category === 'aim') {
    return optionLabel(AIM_SCENARIOS, query.scenario)
  }
  if (query.category === 'overall') {
    return `Overall ${optionLabel(OVERALL_DISCIPLINES, query.discipline)}`
  }
  return optionLabel(maps.value, query.map)
})
const caption = computed(() => `${boardTitle.value} leaderboard`)

async function setQuery(patch, resetPage = false) {
  const next = normalizeLeaderboardQuery({
    ...normalized.value,
    ...patch,
    page: resetPage ? 1 : patch.page ?? normalized.value.page,
  })
  return router.push({
    name: 'leaderboard',
    query: Object.fromEntries(
      Object.entries(next).map(([key, value]) => [key, String(value)])
    ),
  })
}

async function setPage(page) {
  await setQuery({ page })
  await nextTick()
  resultsHeading.value?.focus({ preventScroll: true })
  resultsHeading.value?.scrollIntoView({
    behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches
      ? 'auto'
      : 'smooth',
  })
}
</script>

<template>
<main id="main-content" class="leaderboard-page">
  <header class="page-heading">
    <p class="eyebrow">Global records</p>
    <h1>Leaderboard</h1>
    <p>Movement, target, aim, and overall rankings.</p>
  </header>
  <LeaderboardCategoryTabs
    :categories="CATEGORIES"
    :model-value="normalized.category"
    @update:model-value="setQuery({ category: $event }, true)"
  />
  <LeaderboardFilters
    :category="normalized.category"
    :map="normalized.map"
    :scenario="normalized.scenario"
    :discipline="normalized.discipline"
    :maps="maps"
    :scenarios="AIM_SCENARIOS"
    :disciplines="OVERALL_DISCIPLINES"
    @update:map="setQuery({ map: $event }, true)"
    @update:scenario="setQuery({ scenario: $event }, true)"
    @update:discipline="setQuery({ discipline: $event }, true)"
  />
  <section class="leaderboard-results" aria-labelledby="results-title">
    <div class="section-heading">
      <h2 id="results-title" ref="resultsHeading" tabindex="-1">
        {{ boardTitle }}
      </h2>
      <p>{{ total }} entries</p>
    </div>
    <LeaderboardStatus
      v-if="status !== 'success'"
      :status="status"
      :error="error"
      @retry="reload"
    />
    <template v-else>
      <LeaderboardTable :caption="caption" :columns="columns" :rows="rows" />
      <LeaderboardPagination
        :page="normalized.page"
        :total="total"
        :page-size="PAGE_SIZE"
        @update:page="setPage"
      />
    </template>
  </section>
</main>
</template>
```

- [ ] **Step 5: Run view and domain tests**

Run:

```bash
cd website
pnpm test -- src/views/LeaderboardView.test.js src/data/leaderboards.test.js src/services/leaderboardApi.test.js
```

Expected: all route normalization, metadata, and API tests pass.

- [ ] **Step 6: Commit the full leaderboard route**

```bash
git add website/src/views/LeaderboardView.vue website/src/views/LeaderboardView.test.js website/src/data/leaderboards.js
git commit -m "feat: build full leaderboard route" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 10: Build the trailer-led homepage

**Files:**
- Copy: `images/screenshots/map_streets.png` to `website/src/assets/maps/map_streets.png`
- Copy: `images/screenshots/map_taurus.png` to `website/src/assets/maps/map_taurus.png`
- Copy: `images/screenshots/map_rooftops.png` to `website/src/assets/maps/map_rooftops.png`
- Create: `website/src/components/home/TrailerHero.test.js`
- Create: `website/src/components/home/TrailerHero.vue`
- Create: `website/src/components/home/GameIntro.vue`
- Create: `website/src/components/home/MapGallery.vue`
- Create: `website/src/components/leaderboard/LeaderboardPreview.vue`
- Create: `website/src/views/HomeView.test.js`
- Replace: `website/src/views/HomeView.vue`

- [ ] **Step 1: Copy the approved map assets**

Run:

```bash
mkdir -p website/src/assets/maps
cp images/screenshots/map_streets.png website/src/assets/maps/
cp images/screenshots/map_taurus.png website/src/assets/maps/
cp images/screenshots/map_rooftops.png website/src/assets/maps/
```

Expected: three tracked images exist under the website source tree.

- [ ] **Step 2: Write the failing trailer test**

Create:

```js
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import TrailerHero from './TrailerHero.vue'

describe('TrailerHero', () => {
  it('loads the privacy-enhanced embed only after activation', async () => {
    const wrapper = mount(TrailerHero)

    expect(wrapper.find('iframe').exists()).toBe(false)
    await wrapper.get('button[aria-label="Play the Straif trailer"]').trigger('click')

    const iframe = wrapper.get('iframe')
    expect(iframe.attributes('src')).toContain(
      'https://www.youtube-nocookie.com/embed/CfzotZZ3Sd0'
    )
    expect(iframe.attributes('title')).toBe('Straif official trailer')
  })
})
```

- [ ] **Step 3: Run the trailer test and verify failure**

Run:

```bash
cd website
pnpm test -- src/components/home/TrailerHero.test.js
```

Expected: FAIL because `TrailerHero.vue` is missing.

- [ ] **Step 4: Implement the click-to-load trailer**

Create:

```vue
<script setup>
import { ref } from 'vue'

const isPlaying = ref(false)
</script>

<template>
  <section class="trailer-hero" aria-labelledby="trailer-title">
    <div v-if="!isPlaying" class="trailer-poster">
      <img
        src="https://i.ytimg.com/vi/CfzotZZ3Sd0/maxresdefault.jpg"
        alt=""
        width="1280"
        height="720"
        fetchpriority="high"
      >
      <button
        type="button"
        class="trailer-play"
        aria-label="Play the Straif trailer"
        @click="isPlaying = true"
      ><span aria-hidden="true">▶</span></button>
    </div>
    <iframe
      v-else
      src="https://www.youtube-nocookie.com/embed/CfzotZZ3Sd0?autoplay=1&rel=0"
      title="Straif official trailer"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
      allowfullscreen
    />
    <div class="trailer-copy">
      <div>
        <p class="eyebrow">Official trailer · YouTube</p>
        <h1 id="trailer-title">Straif</h1>
      </div>
      <p class="eyebrow">Watch film</p>
    </div>
  </section>
</template>
```

- [ ] **Step 5: Implement the factual intro and alternating gallery**

`GameIntro.vue`:

```vue
<template>
  <section class="game-intro" aria-labelledby="game-intro-title">
    <h2 id="game-intro-title">Built around movement.</h2>
    <p>
      Straif is a fast-paced 3D platforming shooter with hand-crafted maps,
      precise movement, and global leaderboards for movement, target, and aim.
    </p>
  </section>
</template>
```

Create `MapGallery.vue`:

```vue
<script setup>
import rooftopsImage from '@/assets/maps/map_rooftops.png'
import streetsImage from '@/assets/maps/map_streets.png'
import taurusImage from '@/assets/maps/map_taurus.png'

const maps = [
  { name: 'Streets', modes: 'Movement and target', image: streetsImage },
  { name: 'Taurus', modes: 'Movement', image: taurusImage },
  { name: 'Rooftops', modes: 'Movement and target', image: rooftopsImage },
]
</script>

<template>
  <section class="map-gallery" aria-labelledby="maps-title">
    <header class="section-heading">
      <div>
        <p class="eyebrow">Selected maps</p>
        <h2 id="maps-title">Environments</h2>
      </div>
      <p class="eyebrow">14 maps</p>
    </header>
    <div class="map-list">
      <figure v-for="map in maps" :key="map.name" class="map-feature">
        <img
          :src="map.image"
          :alt="`${map.name} map in Straif`"
          width="1920"
          height="1080"
          loading="lazy"
        >
        <figcaption>
          <p class="eyebrow">{{ map.modes }}</p>
          <h3>{{ map.name }}</h3>
          <p>{{ map.modes }} leaderboards are available.</p>
        </figcaption>
      </figure>
    </div>
  </section>
</template>
```

Alternate figures through CSS using `:nth-child(even)` without changing DOM order.

- [ ] **Step 6: Implement the leaderboard preview**

Create `LeaderboardPreview.vue`:

```vue
<script setup>
import { computed } from 'vue'
import LeaderboardStatus from './LeaderboardStatus.vue'
import LeaderboardTable from './LeaderboardTable.vue'
import { useLeaderboard } from '@/composables/useLeaderboard'
import { getLeaderboardColumns } from '@/data/leaderboards'

const request = computed(() => ({
  category: 'movement',
  map: 'map_rooftops',
  page: 1,
}))
const { rows, status, error, reload } = useLeaderboard(request)
const columns = getLeaderboardColumns(request.value).filter(
  (column) => column.key !== 'date'
)
const previewRows = computed(() => rows.value.slice(0, 5))
</script>

<template>
  <section class="leaderboard-preview" aria-labelledby="preview-title">
    <header class="section-heading">
      <div>
        <p class="eyebrow">Current records</p>
        <h2 id="preview-title">Rooftops · Bhop</h2>
      </div>
      <RouterLink
        :to="{
          name: 'leaderboard',
          query: { category: 'movement', map: 'map_rooftops', page: '1' },
        }"
      >Full leaderboard</RouterLink>
    </header>
    <LeaderboardStatus
      v-if="status !== 'success'"
      :status="status"
      :error="error"
      @retry="reload"
    />
    <LeaderboardTable
      v-else
      caption="Rooftops Bhop leaderboard preview"
      :columns="columns"
      :rows="previewRows"
    />
  </section>
</template>
```

The preview deliberately slices the normalized response to five rows while the shared API request remains 25 rows.

- [ ] **Step 7: Write the semantic homepage test**

Create `HomeView.test.js`:

```js
import { mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'
import HomeView from './HomeView.vue'

vi.mock('@/components/leaderboard/LeaderboardPreview.vue', () => ({
  default: { template: '<section aria-label="Leaderboard preview" />' },
}))

describe('HomeView', () => {
  it('uses one main landmark and semantic content sections', () => {
    const wrapper = mount(HomeView, {
      global: {
        stubs: {
          RouterLink: { template: '<a><slot /></a>' },
        },
      },
    })

    expect(wrapper.findAll('main')).toHaveLength(1)
    expect(wrapper.get('h1').text()).toBe('Straif')
    expect(wrapper.get('[aria-labelledby="game-intro-title"]').exists()).toBe(true)
    expect(wrapper.findAll('figure')).toHaveLength(3)
  })
})
```

- [ ] **Step 8: Run the homepage test and verify it fails before composition**

Run:

```bash
cd website
pnpm test -- src/views/HomeView.test.js
```

Expected: FAIL while `HomeView.vue` is still the temporary route.

- [ ] **Step 9: Compose the homepage**

Replace `HomeView.vue`:

```vue
<script setup>
import GameIntro from '@/components/home/GameIntro.vue'
import MapGallery from '@/components/home/MapGallery.vue'
import TrailerHero from '@/components/home/TrailerHero.vue'
import LeaderboardPreview from '@/components/leaderboard/LeaderboardPreview.vue'
</script>

<template>
  <main id="main-content">
    <TrailerHero />
    <GameIntro />
    <MapGallery />
    <LeaderboardPreview />
  </main>
</template>
```

- [ ] **Step 10: Run homepage tests**

Run:

```bash
cd website
pnpm test -- src/components/home/TrailerHero.test.js src/views/HomeView.test.js
```

Expected: trailer and homepage semantic tests pass.

- [ ] **Step 11: Commit the homepage**

```bash
git add website/src/assets website/src/components/home website/src/components/leaderboard/LeaderboardPreview.vue website/src/views/HomeView.vue website/src/views/HomeView.test.js
git commit -m "feat: add trailer-led homepage" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 11: Apply the approved visual system and responsive behavior

**Files:**
- Modify: `website/index.html`
- Modify: `website/src/styles/base.css`
- Modify: all new Vue components only where required to add stable class names

- [ ] **Step 1: Update document language, fonts, and baseline metadata**

Use:

```html
<html lang="en">
```

Add:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link
  href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap"
  rel="stylesheet"
>
<meta
  name="description"
  content="Straif is a fast-paced 3D platforming shooter built around movement and global leaderboards."
>
<meta name="theme-color" content="#050505">
```

- [ ] **Step 2: Define the complete design tokens**

At the top of `base.css`:

```css
:root {
  color-scheme: dark;
  --color-bg: #050505;
  --color-surface: #090909;
  --color-text: #f2f2ed;
  --color-muted: #969690;
  --color-subtle: #73736e;
  --color-border: #292929;
  --color-border-strong: #444440;
  --content-width: 82rem;
  --page-gutter: clamp(1rem, 4vw, 3.5rem);
  --section-space: clamp(4rem, 10vw, 8.5rem);
  font-family: Archivo, Arial, sans-serif;
  font-synthesis: none;
  background: var(--color-bg);
  color: var(--color-text);
}
```

Use IBM Plex Mono only for `.eyebrow`, table metrics, dates, pagination, and compact metadata.

- [ ] **Step 3: Implement the desktop editorial layout**

Append these stable layout rules, then tune only values that fail the browser checks:

```css
.site-header,
.site-footer,
.page-heading,
.leaderboard-tabs,
.leaderboard-filters,
.leaderboard-results,
.game-intro,
.map-gallery,
.leaderboard-preview {
  width: min(100%, var(--content-width));
  margin-inline: auto;
  padding-inline: var(--page-gutter);
}

.site-header,
.site-footer {
  display: flex;
  min-height: 4rem;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--color-border);
}

.site-header nav,
.site-footer nav {
  display: flex;
  gap: 1.5rem;
}

.wordmark {
  font-size: 1.125rem;
  font-weight: 700;
  letter-spacing: -.05em;
  text-decoration: none;
}

.site-header a,
.site-footer a {
  color: var(--color-muted);
  text-decoration: none;
}

.site-header .router-link-exact-active {
  color: var(--color-text);
}

.trailer-hero {
  position: relative;
  width: min(100%, 100rem);
  margin-inline: auto;
  aspect-ratio: 16 / 9;
  max-height: calc(100vh - 4rem);
  overflow: hidden;
  background: #000;
}

.trailer-poster,
.trailer-hero iframe,
.trailer-poster img {
  width: 100%;
  height: 100%;
}

.trailer-poster img {
  display: block;
  object-fit: cover;
  filter: saturate(.62) contrast(1.07);
}

.trailer-play {
  position: absolute;
  inset: 50% auto auto 50%;
  display: grid;
  width: 4rem;
  height: 4rem;
  place-items: center;
  border: 1px solid rgba(255,255,255,.72);
  border-radius: 50%;
  background: rgba(0,0,0,.35);
  color: white;
  transform: translate(-50%, -50%);
}

.trailer-copy {
  position: absolute;
  inset: auto var(--page-gutter) var(--page-gutter);
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  pointer-events: none;
}

.trailer-copy h1,
.page-heading h1 {
  margin: .35rem 0 0;
  font-size: clamp(3rem, 8vw, 7.5rem);
  letter-spacing: -.075em;
  line-height: .88;
}

.eyebrow,
.pagination,
.leaderboard-table th {
  font-family: "IBM Plex Mono", monospace;
  font-size: .75rem;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.game-intro {
  display: grid;
  grid-template-columns: 2fr 3fr;
  gap: clamp(2rem, 7vw, 7rem);
  padding-block: var(--section-space);
  border-bottom: 1px solid var(--color-border);
}

.game-intro h2,
.section-heading h2,
.page-heading h1 {
  letter-spacing: -.06em;
}

.game-intro p,
.page-heading > p,
.map-feature figcaption > p {
  color: var(--color-muted);
  line-height: 1.7;
}

.map-gallery,
.leaderboard-preview,
.leaderboard-page {
  padding-block: var(--section-space);
}

.section-heading {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 2rem;
  margin-bottom: 2rem;
}

.map-list {
  display: grid;
  gap: 2rem;
}

.map-feature {
  display: grid;
  grid-template-columns: minmax(0, 3fr) minmax(16rem, 2fr);
  min-height: 28rem;
  margin: 0;
}

.map-feature:nth-child(even) {
  grid-template-columns: minmax(16rem, 2fr) minmax(0, 3fr);
}

.map-feature:nth-child(even) img {
  grid-column: 2;
}

.map-feature:nth-child(even) figcaption {
  grid-column: 1;
  grid-row: 1;
}

.map-feature img {
  width: 100%;
  height: 100%;
  min-height: 22rem;
  object-fit: cover;
  filter: saturate(.62) contrast(1.07);
}

.map-feature figcaption {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  padding: clamp(1.5rem, 4vw, 3rem);
  border: 1px solid var(--color-border);
}

.leaderboard-tabs {
  display: flex;
  gap: 2rem;
  border-bottom: 1px solid var(--color-border);
}

.leaderboard-tabs button {
  padding: 1rem 0;
  border: 0;
  border-bottom: 1px solid transparent;
  background: transparent;
  color: var(--color-subtle);
}

.leaderboard-tabs button[aria-current="page"] {
  border-color: var(--color-text);
  color: var(--color-text);
}

.leaderboard-filters {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  padding-block: 1.5rem;
}

.leaderboard-filters label {
  display: grid;
  gap: .5rem;
  color: var(--color-muted);
}

.leaderboard-filters select {
  min-height: 3rem;
  border: 1px solid var(--color-border-strong);
  border-radius: 0;
  background: var(--color-surface);
  color: var(--color-text);
  padding-inline: .875rem;
}

.table-scroll {
  overflow-x: auto;
  border-top: 1px solid var(--color-border);
}

.leaderboard-table {
  width: 100%;
  border-collapse: collapse;
}

.leaderboard-table caption {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
}

.leaderboard-table th,
.leaderboard-table td {
  padding: 1rem .75rem;
  border-bottom: 1px solid var(--color-border);
  text-align: left;
}

.leaderboard-table tbody th {
  color: var(--color-muted);
  font-weight: 400;
}

.pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding-top: 1.5rem;
  color: var(--color-muted);
}

.pagination-controls {
  display: flex;
  gap: .25rem;
}

.pagination button {
  min-width: 2.75rem;
  min-height: 2.75rem;
  border: 1px solid var(--color-border);
  border-radius: 0;
  background: transparent;
  color: var(--color-muted);
}

.pagination button[aria-current="page"] {
  border-color: var(--color-text);
  color: var(--color-text);
}

.pagination button:disabled {
  opacity: .35;
}
```

Do not add slogans, gradients used as decoration, glow, glass surfaces, or pill-shaped controls.

- [ ] **Step 4: Implement narrow-screen behavior**

At `max-width: 48rem`:

```css
.site-header,
.site-footer,
.section-heading {
  align-items: flex-start;
}

.trailer-copy {
  inset: auto 1rem 1rem;
}

.trailer-copy > .eyebrow {
  display: none;
}

.game-intro,
.map-feature,
.map-feature:nth-child(even) {
  grid-template-columns: 1fr;
}

.map-feature:nth-child(even) img,
.map-feature:nth-child(even) figcaption {
  grid-column: 1;
}

.map-feature:nth-child(even) img {
  grid-row: 1;
}

.map-feature:nth-child(even) figcaption {
  grid-row: 2;
}

.leaderboard-filters {
  grid-template-columns: 1fr;
}

.leaderboard-tabs {
  overflow-x: auto;
  white-space: nowrap;
}

.table-scroll {
  overflow-x: auto;
  overscroll-behavior-inline: contain;
}

.leaderboard-table {
  min-width: 42rem;
}

.pagination {
  align-items: flex-start;
  flex-direction: column;
}
```

This preserves image-then-caption reading order on every map feature.

- [ ] **Step 5: Run the complete frontend suite and build**

Run:

```bash
cd website
pnpm test
pnpm build
```

Expected: all Vitest files pass and Vite produces `dist/`.

- [ ] **Step 6: Inspect in a live browser**

Start:

```bash
cd website
pnpm dev --host 127.0.0.1
```

Verify at widths 1440×900, 1024×768, 768×1024, and 390×844:

- Header and focus order.
- Trailer poster and click-to-load iframe.
- Alternating map order and restrained color.
- All category/filter combinations.
- Table horizontal scrolling.
- Loading, empty, API error, and retry states.
- Page URL restoration through back and forward.
- Reduced-motion behavior.

- [ ] **Step 7: Commit the visual system**

```bash
git add website/index.html website/src/styles website/src/components website/src/views
git commit -m "style: apply Straif editorial visual system" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```

## Task 12: Document and verify the complete redesign

**Files:**
- Modify: `README.md:14-18`

- [ ] **Step 1: Update website documentation**

Replace the website section with:

````md
## Website

The Straif website includes a trailer-led game overview and complete Movement,
Target, Aim, and Overall leaderboards at
[straif.pumped.software](https://straif.pumped.software/).

Run it locally:

```bash
cd website
pnpm install
pnpm dev
```
````

- [ ] **Step 2: Run final server verification**

Run:

```bash
cd server
pnpm test
pnpm build
```

Expected: all Node tests pass and the production server bundle succeeds.

- [ ] **Step 3: Run final website verification**

Run:

```bash
cd website
pnpm test
pnpm build
```

Expected: all Vitest tests pass and the production website bundle succeeds.

- [ ] **Step 4: Verify the exact change set**

Run:

```bash
git diff --check
git status --short
git --no-pager diff --stat origin/main...HEAD
```

Expected: no whitespace errors; only the approved server pagination, website redesign, tests, assets, dependency locks, README, spec, and plan are changed.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md
git commit -m "docs: document redesigned website" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: da0c9d87-f2bf-4cb3-b656-7f17cd105012"
```
