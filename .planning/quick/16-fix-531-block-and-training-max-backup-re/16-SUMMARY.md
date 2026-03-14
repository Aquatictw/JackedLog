---
phase: quick-016
plan: 01
subsystem: backup, workout-detail
tags: [export, import, 531-blocks, duration-edit]
dependency_graph:
  requires: []
  provides: [531-block-backup, duration-editing]
  affects: [export_data, import_data, workout_detail_page]
tech_stack:
  added: []
  patterns: [csv-export-import, stateful-dialog]
key_files:
  created: []
  modified:
    - lib/export_data.dart
    - lib/import_data.dart
    - lib/workouts/workout_detail_page.dart
decisions: []
metrics:
  duration: 2 min
  completed: 2026-03-14
---

# Quick Task 016: Fix 5/3/1 Block and Training Max Backup + Duration Editing

5/3/1 block data now included in CSV backup export/import with backward compatibility; workout duration editable via time picker dialog in edit mode.

## Changes Made

### Task 1: Add 5/3/1 blocks to CSV export and import

**Export (lib/export_data.dart):**
- Added query of `fiveThreeOneBlocks` table wrapped in try/catch (handles missing table in older DBs)
- Serializes all 15 block fields (id, created, squatTm, benchTm, deadliftTm, pressTm, start TMs, unit, currentCycle, currentWeek, isActive, completed) to CSV
- Adds `five_three_one_blocks.csv` to the ZIP archive alongside workouts.csv and gym_sets.csv

**Import (lib/import_data.dart):**
- Looks for optional `five_three_one_blocks.csv` in the archive (backward compatible - old exports skip silently)
- Parses CSV with utf8/latin1 decode fallback pattern
- Maps rows to `FiveThreeOneBlocksCompanion` objects with proper type handling
- Runs `CREATE TABLE IF NOT EXISTS` to ensure table exists before import
- Deletes existing blocks and inserts all parsed blocks
- Added `_parseNullableDouble` helper method for nullable double fields (start TMs)

### Task 2: Add workout duration editing in edit mode

**Workout detail page (lib/workouts/workout_detail_page.dart):**
- Changed `_buildStatsSection` to use `currentWorkout` instead of `widget.workout` for duration calculation (reflects edits)
- Duration stat becomes tappable (highlighted) when in edit mode and workout has endTime
- Added `_editDuration()` method with StatefulBuilder dialog containing:
  - "Start Time" ListTile with time picker
  - "End Time" ListTile with time picker
  - Validation: end time must be after start time
  - Saves to database and calls `_reloadWorkout()` on confirmation

## Deviations from Plan

None - plan executed exactly as written.

## Verification

1. Export: `export_data.dart` queries `fiveThreeOneBlocks` and adds CSV to archive
2. Import with 531: `import_data.dart` finds `five_three_one_blocks.csv`, parses it, ensures table exists, inserts blocks
3. Import without 531: If CSV is absent, the `blocksFile` is null and the block is skipped entirely
4. Duration edit: `_editDuration` method exists, `_buildStatsSection` uses `currentWorkout`, duration stat is tappable in edit mode

## Self-Check: PASSED

- lib/export_data.dart: FOUND (modified with 5/3/1 export)
- lib/import_data.dart: FOUND (modified with 5/3/1 import + _parseNullableDouble)
- lib/workouts/workout_detail_page.dart: FOUND (modified with duration editing)
