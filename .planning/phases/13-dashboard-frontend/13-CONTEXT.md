# Phase 13: Dashboard Frontend - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Server-rendered web dashboard for viewing workout statistics, progress charts, and workout history. Read-only, server-rendered HTML with vanilla CSS/JS (no build step, no framework). Chart.js for charts, SVG for heatmap. Responsive layout with desktop sidebar and mobile hamburger. Dark/light theme toggle.

</domain>

<decisions>
## Implementation Decisions

### Visual identity & layout
- Dark fitness app style — dark backgrounds, bold typography, gym/fitness vibe
- Deep/royal purple accent color (#7C3AED range) for highlights, active states, chart emphasis
- Stats cards in a single horizontal row of 4 (workout count, volume, streak, training time) on overview page
- On mobile, cards should stack/wrap responsively

### Chart presentation
- Training heatmap: Match the app's Workout Overview style — GitHub-style grid, day-of-week rows (M-S), weekly columns, set-count color intensity, month labels on top, Less/More legend. SVG implementation.
- Muscle group charts: Volume bars in purple accent, set count bars in a secondary/contrast color (teal/cyan) to differentiate the two charts
- Exercise progress charts: Match the app's FlexLine style — curved line with gradient area fill below (primary-to-transparent), no data point dots, optional dashed trend line in secondary color
- Period selector: Same as app — Week, Month, 3M, 6M, Year, All Time

### Navigation & page structure
- Sidebar contains 4 items: Overview, Exercises, History, Backups
- Overview page: stats cards + heatmap + muscle group charts
- Exercises page: full list with search bar and category filter dropdown, click exercise to see detail (PRs, rep records, progress charts)
- History page: paginated workout list, click to navigate to workout detail page
- Backups: link to existing backup management page integrated into sidebar nav
- Theme toggle (dark/light) as icon button in the top-right header bar

### Workout history display
- History list rows match app style: workout name, date, set count, best weight x reps — card-based layout
- Pagination: traditional page numbers (1, 2, 3...) at bottom, 20 workouts per page
- Workout detail: navigate to new page (/workout/:id), grouped by exercise (exercise name as header, sets listed below with weight/reps), mirroring the app's workout detail layout

### Claude's Discretion
- Exact CSS spacing, typography scale, and responsive breakpoints
- Loading states and error state design
- Mobile hamburger menu implementation details
- Exact secondary color choice for set count bars (teal/cyan range)
- Empty state messaging

</decisions>

<specifics>
## Specific Ideas

- "Match the app" is the guiding principle — heatmap, charts, and history should feel like a web version of the app's Workout Overview and exercise history pages
- The app uses fl_chart with curved lines, gradient fills, and trend lines — replicate this look in Chart.js
- Heatmap cells are 14x14px with 3px border radius in the app, tappable with intensity based on set count (0, <5, <10, <15, 15+)
- History card pattern: calendar icon, workout name + date, divider, stat chips (sets, best weight x reps)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-dashboard-frontend*
*Context gathered: 2026-02-15*
