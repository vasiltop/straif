# Straif Website Redesign

## Summary

Redesign the existing Vue website as a two-route, minimalist black game site:

- `/` presents the game through the official trailer, a concise introduction, selected map imagery, and a small leaderboard preview.
- `/leaderboard` exposes every existing leaderboard discipline through a focused, filterable, paginated table.

The approved direction is cinematic editorial rather than overtly technical or game-themed. It uses a deep-black interface, restrained map color, large but factual typography, and quiet data presentation. Copy remains descriptive and avoids slogans.

## Goals

- Keep the frontend in Vue 3 and Vite.
- Add a real homepage without weakening leaderboard access.
- Expose Bhop, Target, Aim scenarios, and all available overall rankings.
- Make every leaderboard entry reachable with 25-row numbered pagination.
- Improve semantic HTML, keyboard usability, responsive behavior, and failure states.
- Reuse the supplied trailer and existing repository map screenshots.
- Preserve API compatibility for existing clients.

## Non-goals

- Player profiles, authentication, run replay, search, and leaderboard submission.
- A content-management system.
- New game modes, scoring rules, or map metadata.
- Browser end-to-end test infrastructure.
- Decorative animation beyond restrained transitions that respect reduced-motion preferences.

## Approved design direction

### Visual system

- Near-black page and surface colors with fine neutral borders.
- Off-white primary text and muted gray supporting text.
- Existing screenshots retain reduced, restrained color rather than becoming fully monochrome.
- Archivo is the primary interface and display typeface.
- IBM Plex Mono is limited to compact labels, ranks, dates, times, and pagination metadata.
- No gradients as decorative backgrounds, glow effects, heavy shadows, rounded dashboard cards, or gaming-style ornament.
- Ranking numbers remain visible because they are data, not decorative section markers.

### Navigation

A shared semantic app shell contains:

- A `header` with the Straif wordmark.
- A primary `nav` linking to Home and Leaderboard.
- A route-level `main` region.
- A restrained `footer` with repeated primary navigation and existing project links only when they have a verified destination.

The active route is visually and programmatically identifiable.

## Route design

### Home route

The homepage uses this order:

1. Shared header and navigation.
2. Trailer hero.
3. Concise game introduction.
4. Alternating map features.
5. Current leaderboard preview.
6. Footer.

#### Trailer hero

- The trailer is the opening visual and uses video ID `CfzotZZ3Sd0`.
- Initial rendering uses a lightweight thumbnail with an accessible play control.
- Activating the control replaces the thumbnail with a privacy-enhanced `youtube-nocookie.com` iframe.
- The iframe has a descriptive title and supports keyboard activation.
- The hero copy is limited to the game name and factual trailer metadata.

#### Game introduction

The introduction describes Straif as a fast-paced 3D platforming shooter with hand-crafted maps, precise movement, and global leaderboards. It does not introduce marketing slogans or unsupported claims.

#### Map gallery

- Use an alternating image-and-copy layout rather than a card grid or contact sheet.
- Curate a small set of strong screenshots, including Streets and Taurus, from `images/screenshots`.
- Copy identifies the map and the leaderboard disciplines available for it.
- Images use meaningful alt text when informative and empty alt text only when repeated decorative media is already described by adjacent text.
- On narrow screens, each feature becomes a vertical image-then-copy sequence.

#### Leaderboard preview

- Show a compact set of current Bhop Rooftops records.
- Use the same table primitives and formatting as the full leaderboard.
- Include a clear link to the matching filtered leaderboard route.
- Preview failure does not prevent the rest of the homepage from rendering.

### Leaderboard route

The route starts with one `h1`, a short factual description, category tabs, compatible filters, a status region, the result table, and pagination.

#### Categories

The category tabs map to the current APIs as follows:

| Category | Data source | Secondary control |
| --- | --- | --- |
| Movement | Bhop map runs | Map |
| Target | Target map runs | Map |
| Aim | Aim scenario scores | Scenario: Gridshot, Flick, Tracking |
| Overall | Overall rankings | Discipline: Movement, Target, Aim |

Category labels are user-facing terms; API mode values remain `bhop` and `target`.

#### URL state

The route query string is the source of truth for:

- `category`
- `map`
- `scenario`
- `discipline`
- `page`

Invalid or incompatible values are normalized to a valid default and reflected in the URL. Changing a category or filter resets the page to 1. Browser back and forward navigation restores the visible board.

Examples:

- `/leaderboard?category=movement&map=map_rooftops&page=1`
- `/leaderboard?category=aim&scenario=gridshot&page=2`
- `/leaderboard?category=overall&discipline=aim&page=1`

#### Table presentation

- Render a real `table` with a descriptive `caption`, `thead`, `tbody`, and scoped column headers.
- Movement and Target columns: rank, player, time, date.
- Aim scenario columns: rank, player, score, accuracy, reaction time, date.
- Overall Movement and Target columns: rank, player, points.
- Overall Aim columns: rank, player, total score, scenarios completed, accuracy, average reaction time.
- Format times consistently to three decimal places in seconds.
- Format scores, percentages, reaction time, and dates consistently through shared formatters.
- Preserve the table structure on mobile and place it in a keyboard-accessible horizontal overflow region instead of converting rows into cards.

#### Pagination

- The website requests 25 rows per page.
- Numbered pagination provides previous, next, nearby page numbers, current-page state, total entries, and the displayed range.
- Pagination is contained in an aria-labeled `nav`.
- Page changes retain the selected category and filters.
- The route scrolls or focuses back to the leaderboard heading after a page change without forcing motion when reduced motion is enabled.

## Frontend architecture

Keep presentation, route state, and transport responsibilities separate.

### App shell

`App.vue` owns the shared site shell and renders a `RouterView`. It does not contain leaderboard fetching or route-specific content.

### Views

- `HomeView` composes trailer, introduction, map gallery, and leaderboard preview components.
- `LeaderboardView` coordinates route-backed filters and renders the selected board.

### Components

Use focused components with explicit props and emitted events:

- `SiteHeader`
- `SiteFooter`
- `TrailerHero`
- `GameIntro`
- `MapGallery`
- `LeaderboardPreview`
- `LeaderboardCategoryTabs`
- `LeaderboardFilters`
- `LeaderboardTable`
- `LeaderboardPagination`
- `LeaderboardStatus`

The table remains one reusable component driven by explicit column definitions and normalized rows rather than separate duplicated tables for every discipline.

### Data and helpers

- A dedicated API module owns endpoint construction, fetch error handling, and response parsing.
- A leaderboard composable maps route state to requests, cancels stale requests, and exposes loading, success, empty, and error states.
- A normalizer maps the current API response variants to a stable frontend shape.
- Shared formatting helpers handle times, scores, percentages, reaction times, and dates.
- Static map and scenario metadata lives outside components.

No fetch calls or API URL construction remain inside templates or presentational components.

## API changes

The website needs full paginated access while existing game and API clients must retain current behavior.

### Pagination query

Applicable leaderboard endpoints accept:

- `page`: zero-based non-negative integer, default `0`.
- `limit`: positive integer capped at `100`, default `10`.

The website sends `limit=25`. Existing callers that omit `limit` continue receiving 10 entries.

### Map and scenario boards

Add the validated `limit` parameter to:

- `GET /leaderboard/mode/:mode_name/maps/:map_name/runs`
- `GET /leaderboard/aim/scenarios/:scenario/scores`

Both responses retain their existing data fields and totals.

### Overall Movement and Target

`GET /leaderboard/mode/:mode_name/overall` accepts `page` and `limit`.

- Compute the complete points-ranked player list using the existing scoring rules.
- Slice the ordered list by page and limit.
- Keep the existing `data` array for compatibility.
- Add a top-level `total` count.

### Overall Aim

`GET /leaderboard/aim/overall` accepts `page` and `limit`.

- Paginate the ordered aggregate ranking.
- Keep `data.scores`.
- Add `data.total`.

### Validation and errors

- Invalid `page` or `limit` values return the route's established 400 error shape.
- Unknown aim scenarios continue returning 400.
- Limits above 100 are rejected rather than silently expanded.
- Database and internal failures continue returning explicit 500 responses.

## Loading, empty, and error behavior

- Filter changes immediately identify the table region as busy while preserving the surrounding route structure.
- A loading state appears inside the result region and does not fabricate skeleton rows that resemble results.
- Empty responses show a specific no-records message for the selected category and filter.
- API failures show an inline error with a retry button.
- Retry preserves current URL state.
- Stale requests are aborted when filters or pages change.
- The homepage preview handles its loading, empty, and error states independently from the rest of the page.

## Semantics and accessibility

- Set the document language to English and provide route-specific document titles and descriptions.
- Use semantic landmarks and meaningful heading order.
- Use native links, buttons, and selects rather than clickable generic elements.
- Label every filter visibly.
- Expose active tabs and pagination state programmatically.
- Announce asynchronous status changes through an appropriately scoped `aria-live` region.
- Provide strong focus-visible styles with sufficient contrast.
- Meet WCAG AA contrast for text, controls, and focus indicators.
- Respect `prefers-reduced-motion`.
- Avoid autoplaying video or audio.
- Ensure touch targets remain comfortably usable on mobile.

## Responsive behavior

- Home sections use a wide editorial layout on desktop and a single reading column on small screens.
- Alternating map features preserve source order so mobile reading order remains image, heading, and description.
- Leaderboard tabs may scroll horizontally when necessary.
- Filters stack vertically on narrow screens.
- Tables retain semantic columns inside a labeled horizontal overflow container.
- Pagination remains reachable without requiring the user to scroll the table horizontally first.
- Typography uses bounded fluid sizing to prevent oversized headings on laptops and phones.

## Dependencies

Add only the dependencies needed for the approved architecture and tests:

- Runtime: `vue-router`.
- Development: `vitest`, `@vue/test-utils`, and `jsdom`.

Use hosted Archivo and IBM Plex Mono font files through a deliberate font-loading strategy with local fallbacks. No component framework, icon library, animation library, or CSS framework is required.

## Testing strategy

### Frontend

Use Vitest, Vue Test Utils, and jsdom to cover:

- Home and Leaderboard route rendering.
- Semantic landmarks, headings, labels, captions, and scoped headers.
- Trailer activation and privacy-enhanced embed creation.
- Category and filter transitions.
- URL normalization and browser navigation behavior.
- Page reset rules and 25-row request parameters.
- Response normalization for every leaderboard category.
- Loading, empty, error, retry, and stale-request behavior.
- Pagination labels and disabled states.

Avoid brittle pixel-level snapshot tests.

### Server

Extend the existing leaderboard tests to cover:

- Default 10-row compatibility.
- Explicit 25-row requests.
- Page offset behavior.
- Total counts.
- Overall Movement, Target, and Aim pagination.
- Invalid and over-limit pagination inputs.
- Existing score ordering and tie-breaking.

### Verification

Run the targeted frontend and server tests, then the existing production builds for both packages. Review the rendered pages at desktop and mobile widths, including keyboard navigation and API failure states.

## Accepted trade-offs

- Numbered pagination is less continuous than an infinite list but provides stable URLs, predictable performance, and better keyboard and return navigation.
- Keeping tables intact on mobile requires horizontal overflow, but it preserves comparison semantics better than converting each row into a card.
- Click-to-load YouTube requires one extra activation but improves initial load, privacy, and page stability.
- Curating a small map set means the homepage does not display every map; the leaderboard remains the complete index.
