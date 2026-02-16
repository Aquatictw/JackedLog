# Phase 12: Dashboard Query Layer - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Server can open uploaded SQLite backups in read-only mode and execute SQL queries for dashboard analytics. Provides internal query functions that Phase 13 (Dashboard Frontend) will consume. Covers: overview stats, personal records, rep records, workout history/detail, and exercise search/filter.

</domain>

<decisions>
## Implementation Decisions

### Stats definitions
- Mirror the app's existing calculations exactly — dashboard shows same numbers as the app
- All four overview stats as listed: workout count, total volume, current streak, training time
- Volume calculation includes weighted exercises only (skip bodyweight/zero-weight sets)
- Overview stats support optional period parameter (this week, this month, this year, all-time)

### PR & records logic
- 1RM formula matches whatever the app currently uses — replicate existing logic
- PRs show all-time bests only (no "recent PR" highlights)
- Rep records table (best weight at each rep count 1-15) available for all exercise types that have weight x reps data
- Three PR metrics per exercise: 1RM, best weight, volume — no additional metrics

### Data scope & freshness
- Default to latest backup, but support selecting an older backup for analysis
- When no backup exists: return empty results with a `no_backup` status flag (frontend handles empty state)
- Workout history supports both flat pagination (20 per page) AND optional date range filtering
- Overview stats support optional period filtering (week/month/year/all-time)

### Claude's Discretion
- Streak calculation logic (read app code and replicate)
- Training time calculation method (replicate app)
- Internal function signatures and data structures
- How backup file is opened and cached in memory
- Schema version validation approach (minimum v48)

</decisions>

<specifics>
## Specific Ideas

- Replicate app query patterns from gym_sets.dart — same SQL logic, same edge case handling
- Handle known edge cases: hidden=0 filter, workout_id NULL, epoch timestamps
- Query layer is internal Dart functions (not REST API) — Phase 13 server-rendered pages call these directly

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-dashboard-query-layer*
*Context gathered: 2026-02-15*
