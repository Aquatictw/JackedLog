---
phase: 12-dashboard-query-layer
plan: 01
subsystem: server-query-layer
tags: [sqlite3, dashboard, queries, read-only]
dependency_graph:
  requires: [10-server-foundation, 11-app-integration]
  provides: [DashboardService with lifecycle and core query methods]
  affects: [12-02 (exercise/PR queries build on this class)]
tech_stack:
  added: []
  patterns: [service-layer-with-cached-db-handle, raw-sql-query-translation]
key_files:
  created:
    - server/lib/services/dashboard_service.dart
  modified: []
decisions:
  - id: D12-01
    decision: "Use db.close() matching existing sqlite_validator.dart pattern"
    rationale: "Consistency with existing codebase"
  - id: D12-02
    decision: "Return plain Maps (not Records/typedefs) from query methods"
    rationale: "Phase 13 will JSON-encode these for HTTP responses; Maps serialize directly"
metrics:
  duration: ~1 min
  completed: 2026-02-15
---

# Phase 12 Plan 01: DashboardService Core Query Layer Summary

DashboardService class with read-only SQLite lifecycle, overview stats (count/volume/streak/time), paginated workout history, and workout detail queries.

## What Was Done

### Task 1: DashboardService with lifecycle and overview stats
Created `server/lib/services/dashboard_service.dart` with:
- `open({String? filename})` - finds latest backup or opens specified file in read-only mode, validates schema >= 48
- `close()` - disposes database handle, clears state
- `isOpen` / `currentFile` getters for lifecycle inspection
- `getOverviewStats({String? period})` - returns workout count, total volume, current streak, training time with week/month/year/all period filtering
- `_periodToEpoch()` - converts period string to Unix epoch seconds
- `_calculateStreak()` - walks backwards from today checking each date for workouts
- `_findLatestBackupPath()` - lists backup files matching `jackedlog_backup_*.db`, sorts by name descending

### Task 2: Workout history and detail query methods
Added to the same class:
- `getWorkoutHistory({page, pageSize, startEpoch, endEpoch})` - paginated workout list (20/page default) with LEFT JOIN aggregation for exercise count, set count, total volume per workout
- `getWorkoutDetail(int workoutId)` - returns workout metadata plus all non-hidden sets ordered by sequence then set_order/created

## Key Design Points

- All gym_sets queries include `hidden = 0` filter (prevents counting soft-deleted sets)
- Epoch timestamps consistently in seconds (millisecondsSinceEpoch ~/ 1000)
- Database always opened `OpenMode.readOnly` (never writes to backups)
- Null-safe: all methods return sensible defaults when `_db == null`
- SQL patterns translated directly from app's Drift queries (overview_page.dart, gym_sets.dart)

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `dart analyze server/` passes with zero errors/warnings (only pre-existing info-level lint suggestions)
- All six public API methods present: open, close, isOpen, getOverviewStats, getWorkoutHistory, getWorkoutDetail
- Schema version gate rejects databases with user_version < 48

## Next Phase Readiness

Plan 12-02 will add exercise-level queries (PR detection, rep records, exercise search) to this same DashboardService class. The class structure, lifecycle management, and import patterns are all established and ready to extend.
