---
phase: quick-004
plan: 01
subsystem: ui
tags: [flutter, notes, cache-invalidation, navigation, snackbar]

requires:
  - phase: quick-003
    provides: notes save persistence fix
provides:
  - "_localNotes cache invalidation on navigation return in notes_page.dart"
  - "Guarded snackbar calls preventing deactivated widget errors"
affects: []

tech-stack:
  added: []
  patterns:
    - "setState(() { _localNotes = null; }) pattern for cache invalidation after navigation"
    - "try-catch FlutterError for snackbar safety on frame transitions"

key-files:
  created: []
  modified:
    - lib/notes/notes_page.dart

key-decisions:
  - "Invalidate cache unconditionally on nav return (not inside result!=null check) to handle auto-save scenarios"
  - "Use try-catch FlutterError instead of addPostFrameCallback for simpler snackbar guarding"

patterns-established:
  - "Cache invalidation: set _localNotes = null via setState to force StreamBuilder re-sync"

duration: 2min
completed: 2026-02-06
---

# Quick 004: Fix Notes Stale Cache After Edit Summary

**Invalidate _localNotes cache on navigation return and guard snackbar against deactivated widget errors**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-06T13:17:45Z
- **Completed:** 2026-02-06T13:19:45Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Notes list now refreshes immediately after editing or creating a note
- Snackbar calls wrapped in try-catch to prevent "deactivated widget" errors
- Cache invalidation happens unconditionally on navigation return (handles auto-save edge case)

## Files Modified
- `lib/notes/notes_page.dart` - Added `setState(() { _localNotes = null; })` after Navigator.push in `_createNote()` and `_editNote()`, wrapped snackbar calls in try-catch for FlutterError

## Decisions Made
- Invalidate cache unconditionally (outside `if (result != null)`) because the editor may auto-save even if it doesn't return a result
- Used `try-catch FlutterError` instead of `addPostFrameCallback` for snackbar safety -- simpler and catches the exact error

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## Next Phase Readiness
- Notes page cache invalidation complete
- No blockers for future work

---
*Phase: quick-004*
*Completed: 2026-02-06*
