---
phase: 12-dashboard-query-layer
plan: 02
subsystem: server-analytics
tags: [dart, sqlite, exercise-records, search, brzycki, 1rm]
dependency_graph:
  requires: [12-01]
  provides: [exercise-records-queries, rep-records-queries, exercise-search, category-filter]
  affects: [13-dashboard-frontend]
tech_stack:
  added: []
  patterns: [brzycki-1rm-formula, dynamic-sql-clauses, map-return-types]
key_files:
  created: []
  modified: [server/lib/services/dashboard_service.dart]
decisions:
  - id: D12-02-01
    choice: "Brzycki formula with negative weight branch"
    reason: "Matches app's existing 1RM calculation pattern from gym_sets.dart"
  - id: D12-02-02
    choice: "Integer-only rep filtering via CAST comparison"
    reason: "Excludes fractional reps (e.g. 2.5) from rep records table"
metrics:
  duration: 47s
  completed: 2026-02-15
---

# Phase 12 Plan 02: Exercise Query Methods Summary

Extended DashboardService with exercise analytics: personal records (best weight, 1RM, volume), rep records table (best weight at each rep count 1-15), exercise search with LIKE substring matching, and category filter -- all using hidden=0 filtering and safe null-db defaults.

## Tasks Completed

| # | Task | Status |
|---|------|--------|
| 1 | Add exercise records and rep records methods | Done |
| 2 | Add exercise search and category filter methods | Done |

## What Was Built

### getExerciseRecords(String exerciseName)
- Returns best weight, best 1RM (Brzycki), and best volume for a named exercise
- Brzycki formula: `weight / (1.0278 - 0.0278 * reps)` for positive weights, `weight * (1.0278 - 0.0278 * reps)` for negative
- Single query with 3 MAX aggregations, filtered by `hidden = 0 AND reps > 0`
- Returns `hasRecords: false` when no matching sets exist

### getRepRecords(String exerciseName)
- Returns best weight at each integer rep count 1 through 15
- Filters: `reps BETWEEN 1 AND 15 AND reps = CAST(reps AS INTEGER)` (integer reps only)
- Groups by cast rep count, includes created timestamp, unit, and workout_id
- Returns empty records list when no data

### getCategories()
- Returns `List<String>` of distinct non-null category names
- Ordered alphabetically, filtered by `hidden = 0`

### searchExercises({String search, String? category})
- Filters exercises by name LIKE `%search%` with optional category exact match
- Returns per-exercise: name, category, last used date, set count, workout count
- Ordered by workout count descending (most-used first)
- Dynamic SQL clause: category WHERE only added when parameter provided

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- `dart analyze server/` passes with zero errors/warnings (info-only style suggestions)
- All 9 DashboardService public methods confirmed present: open, close, getOverviewStats, getWorkoutHistory, getWorkoutDetail, getExerciseRecords, getRepRecords, getCategories, searchExercises
- All gym_sets queries include `hidden = 0` filter
- Null database returns safe defaults in all 4 new methods

## Next Phase Readiness

Phase 12 query layer is complete. DashboardService provides all data methods needed for Phase 13 dashboard frontend:
- Overview stats and workout history (plan 01)
- Exercise records, rep records, search, and category filter (plan 02)

No blockers for Phase 13.
