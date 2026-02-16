# Phase 14: Dashboard Differentiators - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Dashboard provides unique features leveraging JackedLog's specialized data model: 5/3/1 block history with TM progression, and bodyweight tracking with moving averages. Weekday frequency chart (DASH-13) dropped per user decision.

</domain>

<decisions>
## Implementation Decisions

### 5/3/1 Block History Page
- Card-based layout similar to app's `_CompletedBlockHistory` widget — each completed block gets a card showing date range and TM values for all 4 lifts (Squat, Bench, Deadlift, OHP)
- Clicking a block card expands inline to show detail similar to app's `BlockSummaryPage` — per-lift TM progression (start → end) with delta badges, and cycle structure (Leader 1, Leader 2, 7th Week, Anchor, 7th Week)
- TM progression chart: grouped bar chart showing start and end TMs per block for all 4 lifts
- No separate detail page — expand/collapse inline is sufficient
- Note: DB schema has `current_cycle` field (0-4) tracking cycle position, and `start_*_tm` / `*_tm` columns for start/end TMs. All blocks follow the same fixed 5-cycle structure.

### Bodyweight Trend Page
- Line chart matching app's style: curved line with dots, filled area below, period selector (7D/1M/3M/6M/1Y/All)
- Include moving average toggles: 3-day, 7-day, 14-day — same as app
- Include stats cards: Current, Average, Change, Entries — same 4-card grid as app
- Include entry history list below chart showing individual entries
- Replicate app's `BodyweightOverviewPage` layout for the web dashboard using Chart.js

### Weekday Frequency (DASH-13)
- **Dropped** — user decided this isn't needed. Not in the app either.

### Claude's Discretion
- Navigation placement for new pages (own section vs mixed into existing nav)
- Chart.js configuration details (colors, tooltips, animations)
- Moving average calculation approach for server-side

</decisions>

<specifics>
## Specific Ideas

- "Make it similar to the block overview page in the app" — reference `_CompletedBlockHistory` and `BlockSummaryPage` in `lib/fivethreeone/`
- "Something similar to the app" for bodyweight — reference `BodyweightOverviewPage` in `lib/graph/bodyweight_overview_page.dart`
- Block card expand should show "what type of leader/anchor was ran" — show the cycle structure labels

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-dashboard-differentiators*
*Context gathered: 2026-02-15*
