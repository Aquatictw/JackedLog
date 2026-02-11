---
phase: quick-005
plan: 01
subsystem: fivethreeone-ui
tags: [531, training-max, inline-editing, phase-labels, compact-ui]
dependency-graph:
  requires: [phase-07-block-management, phase-08-calculator-enhancement]
  provides: [editable-tm-fields, descriptive-phase-labels, cycle-badges, compact-tm-card]
  affects: []
tech-stack:
  added: []
  patterns: [inline-editing-with-focus-listeners, stateful-card-with-controllers]
file-tracking:
  key-files:
    created: []
    modified:
      - lib/fivethreeone/schemes.dart
      - lib/fivethreeone/fivethreeone_state.dart
      - lib/fivethreeone/block_overview_page.dart
      - lib/notes/notes_page.dart
      - lib/widgets/five_three_one_calculator.dart
decisions: []
metrics:
  duration: "2 min"
  completed: 2026-02-11
---

# Quick Task 005: 5/3/1 UI - Compact TM, Editable TMs, Phase Labels Summary

**One-liner:** Compact editable TM card in block overview, descriptive phase labels ("5's Pro BBB - Week 1"), and cycle badges (L1/L2/D/A/T) in notes banner.

## What Was Done

### Task 1: Descriptive label helpers and state updates
- Added `getDescriptiveLabel(int cycleType)` to `schemes.dart` -- returns "5's Pro BBB", "PR Sets FSL", "Deload", "TM Test"
- Added `getCycleBadge(int cycleType)` to `schemes.dart` -- returns "L1", "L2", "D", "A", "T"
- Updated `positionLabel` getter in `FiveThreeOneState` to use `getDescriptiveLabel` instead of `cycleNames`
- Added `cycleBadge` getter to `FiveThreeOneState`
- Added `updateTm({exercise, value})` method to persist inline TM edits to database

### Task 2: Compact TM card with inline editing
- Converted `_TmCard` from StatelessWidget to StatefulWidget with TextEditingControllers and FocusNodes
- Replaced `_TmTile` display-only widgets with compact inline-editable TextFields in 2x2 grid
- Each field: isDense, OutlineInputBorder, labelText, suffixText (unit), numeric keyboard, input formatting
- Save on submit and focus loss via FocusNode listeners
- Reduced card padding from 16 to 12, header-to-fields spacing from 12 to 8
- Removed `_TmTile` class entirely
- Added `didUpdateWidget` to sync controller values when block data changes externally (e.g. TM bump)

### Task 3: Phase badge in notes banner
- Replaced barbell icon with text badge (`cycleBadge`) when active block exists
- Conditional: hasBlock shows "L1"/"L2"/"D"/"A"/"T" badge; no block keeps barbell icon

### Task 4: Editable calculator TM in block mode
- Removed `readOnly: true` from block mode TextField -- single TextField for both modes
- Added `_saveBlockTm()` method that calls `FiveThreeOneState.updateTm`
- `onChanged` dispatches to `_saveBlockTm()` or `_saveTrainingMax()` based on mode
- Updated position header to use `getDescriptiveLabel` ("5's Pro BBB -- Week 1")

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- [x] `getDescriptiveLabel` and `getCycleBadge` present in schemes.dart
- [x] `updateTm`, `cycleBadge`, updated `positionLabel` present in fivethreeone_state.dart
- [x] `TextEditingController`, `updateTm`, `isDense`, `FilteringTextInputFormatter` in block_overview_page.dart
- [x] `_TmTile` class removed from block_overview_page.dart
- [x] `cycleBadge` used in notes_page.dart, `Icons.fitness_center` is conditional
- [x] `readOnly` removed from calculator, `_saveBlockTm` method present, `getDescriptiveLabel` in header
