---
phase: quick-013
plan: 01
subsystem: fivethreeone-calculator
tags: [ui-cleanup, bug-fix, dead-code-removal]
dependency_graph:
  requires: [FiveThreeOneState, schemes.dart]
  provides: [block-only-531-calculator]
  affects: [exercise_sets_card.dart]
tech_stack:
  patterns: [synchronous-context-read, block-only-mode]
key_files:
  modified:
    - lib/widgets/five_three_one_calculator.dart
  deleted:
    - lib/widgets/training_max_editor.dart
decisions:
  - Replaced async _loadSettings with synchronous _loadBlockData using context.read
  - No-active-block case shows informational dialog instead of falling back to manual mode
metrics:
  duration: 2 min
  completed: 2026-03-14
---

# Quick Task 13: Remove Old 5/3/1 Calculator UI — Keep Only Block Mode

Removed dual-mode (manual vs block) pattern from FiveThreeOneCalculator; now synchronously reads FiveThreeOneState and renders block-based layout only. Deleted dead TrainingMaxEditor widget.

## Task Results

| Task | Name | Status | Key Changes |
|------|------|--------|-------------|
| 1 | Rewrite FiveThreeOneCalculator to block-only mode | Done | Removed manual-mode fields, async loading, week selector, progress cycle button; added no-active-block message |
| 2 | Delete unused TrainingMaxEditor widget | Done | Deleted lib/widgets/training_max_editor.dart (dead code) |

## Changes Made

### Task 1: Rewrite FiveThreeOneCalculator to block-only mode

Rewrote `FiveThreeOneCalculator` to remove the dual-mode pattern:

- **Removed manual-mode state:** `_currentWeek`, `_isBlockMode`, `_getWorkingSetScheme()`, `_updateWeek()`, `_progressCycle()`, `_saveTrainingMax()`
- **Made loading synchronous:** Replaced async `_loadSettings()` with synchronous `_loadBlockData()` that uses `context.read<FiveThreeOneState>()` -- eliminates the async gap that caused the old manual UI to flash before block data loaded
- **Simplified build():** Removed all `if (!_isBlockMode)` / `if (_isBlockMode)` branches, `SegmentedButton` week selector, manual-mode week header, and "Complete Cycle & Increase TM" button
- **Added no-active-block case:** When `hasActiveBlock` is false, shows centered informational message with Close button instead of falling back to old manual mode
- **Cleaned imports:** Removed `database.dart`, `settings_state.dart`, `main.dart`; kept `fivethreeone_state.dart` and `schemes.dart`

### Task 2: Delete unused TrainingMaxEditor widget

Deleted `lib/widgets/training_max_editor.dart` entirely. Confirmed no imports reference it anywhere in the codebase.

## Deviations from Plan

None -- plan executed exactly as written.

## Verification Results

- `rg "SegmentedButton|_currentWeek|_isBlockMode|_updateWeek|_progressCycle"` -- no results (old UI code gone)
- `rg "TrainingMaxEditor|training_max_editor" lib/` -- no results (dead code removed)
- `rg "FiveThreeOneCalculator" lib/plan/exercise_sets_card.dart` -- still shows usage (widget still wired in)
- No database schema changes

## Self-Check: PASSED

- [x] lib/widgets/five_three_one_calculator.dart -- modified, manual-mode code removed
- [x] lib/widgets/training_max_editor.dart -- deleted
- [x] All verification commands pass
