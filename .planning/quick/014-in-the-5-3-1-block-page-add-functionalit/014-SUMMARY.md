---
phase: quick-014
plan: 01
subsystem: fivethreeone
tags: [ui, ux, safety, 531]
dependency-graph:
  requires: []
  provides: [go-back-week, complete-week-confirmation]
  affects: [block-overview-page]
tech-stack:
  added: []
  patterns: [confirmation-dialog, inverse-operation]
key-files:
  created: []
  modified:
    - lib/fivethreeone/fivethreeone_state.dart
    - lib/fivethreeone/block_overview_page.dart
decisions:
  - TextButton.icon for Go Back to keep it visually subordinate to the primary Complete Week FilledButton
metrics:
  duration: 1 min
  completed: 2026-03-14
---

# Quick Task 014: Add Go Back Week and Complete Week Confirmation to 5/3/1 Block

Go-back-week method with cross-cycle navigation and confirmation dialogs on both Complete Week and Go Back actions.

## What Changed

### fivethreeone_state.dart
- Added `canGoBack` getter: returns true unless at cycle 0, week 1
- Added `goBackWeek()` method: decrements week within cycle, or moves to last week of previous cycle when at week 1

### block_overview_page.dart
- Complete Week / Complete Block button now shows confirmation AlertDialog before proceeding (Cancel/Confirm)
- Added Go Back TextButton.icon with undo icon above the Complete Week button
- Go Back shows its own confirmation dialog before calling goBackWeek()
- Go Back button conditionally rendered only when `state.canGoBack` is true

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 452fbe5d | feat: quick-014 add go-back-week and complete-week confirmation to 531 block |

## Verification

- User should run `flutter analyze` on the two modified files
- Manual testing: Go Back visible when not at start, hidden at cycle 0 week 1
- Manual testing: Complete Week shows confirmation, cancel does not advance
- Manual testing: Go Back from week 1 of cycle N moves to last week of cycle N-1

## Self-Check: PASSED
