---
phase: "08"
plan: "01"
subsystem: "calculator"
tags: ["5/3/1", "block-aware", "dual-mode", "supplemental"]
dependency-graph:
  requires: ["06-data-foundation", "07-block-management"]
  provides: ["block-aware calculator with scheme switching and supplemental display"]
  affects: ["09-polish"]
tech-stack:
  added: []
  patterns: ["dual-mode widget (block vs manual)", "Provider-based feature detection"]
key-files:
  created: []
  modified: ["lib/widgets/five_three_one_calculator.dart"]
decisions:
  - id: "calc-dual-mode"
    choice: "Single widget with _isBlockMode flag"
    why: "Avoids duplicating the entire calculator widget; all changes gated by one boolean"
  - id: "calc-supplemental-display"
    choice: "Compact single-line format: 'BBB 5x10 @ 120.0 kg'"
    why: "Supplemental sets are uniform (same weight/reps) so a summary line is cleaner than repeating 5 identical rows"
metrics:
  duration: "3 min"
  completed: "2026-02-11"
---

# Phase 8 Plan 1: Calculator Enhancement Summary

Block-aware 5/3/1 calculator with auto scheme resolution, supplemental display, and TM Test feedback

## What Was Done

### Task 1: Block-aware data resolution and state fields
- Added imports for `fivethreeone_state.dart` and `schemes.dart`
- Added `_isBlockMode`, `_blockCycleType`, `_blockWeek` state fields
- Modified `_loadSettings()` to check `FiveThreeOneState.hasActiveBlock` first
- Block mode: reads TM from block fields (squatTm, benchTm, etc.), unit from block
- Manual mode: original settings DB query preserved unchanged in else branch

### Task 2: Dual-mode build() with supplemental section
- Scheme resolution: `getMainScheme()` in block mode, `_getWorkingSetScheme()` in manual
- TM field: read-only in block mode (no `onChanged`), editable in manual mode
- Week selector: replaced with bold header label showing scheme name + cycle position in block mode
- Working Sets header: "Week X: WeekName" row hidden in block mode (position already in header)
- Supplemental section: Divider + compact line ("BBB 5x10 @ weight unit") after main sets, only when supplemental is non-empty (Leader/Anchor cycles)
- TM Test feedback banner: info container with "get 5 strong reps at 100%" warning, only during TM Test cycle
- Progress Cycle button: hidden in block mode via `!_isBlockMode` guard
- Pre-computed supplemental data outside widget tree to avoid Dart collection spread limitations

## Verification

| Criterion | Status | Evidence |
|-----------|--------|----------|
| CALC-01: 5's PRO in Leader, PR Sets in Anchor | Pass | `getMainScheme()` dispatches by cycleType |
| CALC-02: Deload scheme (70/80/90/100%) | Pass | `getMainScheme()` returns `deloadScheme` for cycleDeload |
| CALC-03: TM Test scheme + feedback banner | Pass | `tmTestScheme` returned + banner gated by `cycleTmTest` |
| CALC-04: Supplemental BBB/FSL/hidden | Pass | `getSupplementalScheme()` returns BBB for Leader, FSL for Anchor, empty for Deload/TM Test |
| SC-5: Manual mode preserved | Pass | All new UI gated by `_isBlockMode`, existing methods untouched |

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Hash | Message |
|------|---------|
| 7801347a | feat: 08 calculator enhancement |
