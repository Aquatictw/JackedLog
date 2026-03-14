---
phase: quick-015
plan: 01
subsystem: fivethreeone-ui
tags: [ui, layout, buttons]
key-files:
  modified:
    - lib/fivethreeone/block_overview_page.dart
decisions: []
metrics:
  duration: 1 min
  completed: 2026-03-14
---

# Quick Task 015: Make Go Back 1/3 and Complete Week 2/3 Width Summary

Side-by-side Row layout for Go Back (1/3) and Complete Week (2/3) buttons in 5/3/1 block overview.

## What Changed

Refactored `_CompleteWeekButton` in `block_overview_page.dart`:

1. Extracted `_buildCompleteButton` and `_buildGoBackButton` helper methods from the monolithic `build` method
2. When `canGoBack` is true: renders a `Row` with `Expanded(flex: 1)` for Go Back and `Expanded(flex: 2)` for Complete Week, separated by `SizedBox(width: 8)`
3. When `canGoBack` is false: renders Complete Week at full width with `Size.fromHeight(48)`
4. Both buttons have `minimumSize` height of 48 for consistent tap targets
5. All confirmation dialogs, TM bump logic, and navigation preserved exactly as before

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED
