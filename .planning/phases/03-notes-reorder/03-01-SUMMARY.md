---
phase: 03-notes-reorder
plan: 01
subsystem: ui, database
tags: [flutter, drift, reorderable-list, sqlite, drag-drop]

# Dependency graph
requires:
  - phase: none
    provides: existing notes table and notes_page.dart
provides:
  - sequence column in notes table for order persistence
  - ReorderableListView with long-press drag
  - batch update on reorder for database persistence
  - new notes assigned highest sequence (appear at top)
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ReorderableListView.builder with proxyDecorator for visual lift
    - db.batch for efficient multi-row updates
    - local state sync with stream for responsive reordering

key-files:
  created: []
  modified:
    - lib/database/notes.dart
    - lib/database/database.dart
    - lib/notes/notes_page.dart
    - lib/notes/note_editor_page.dart

key-decisions:
  - "List layout instead of grid for ReorderableListView compatibility"
  - "Sequence stored descending (highest = top) for natural ordering"
  - "Local state tracking for responsive drag feedback before DB commit"

patterns-established:
  - "Notes reorder: long-press to drag, batch update sequences"
  - "Migration pattern: ALTER TABLE with catchError, then UPDATE for backfill"

# Metrics
duration: 8min
completed: 2026-02-02
---

# Phase 03 Plan 01: Notes Reorder Summary

**Drag-drop note reordering with database-backed sequence persistence using ReorderableListView and batch updates**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-02
- **Completed:** 2026-02-02
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Added sequence column to notes table with v62 migration
- Converted GridView to ReorderableListView with long-press drag
- New notes automatically assigned highest sequence (appear at top)
- Reorder disabled during search for UX clarity

## Files Created/Modified
- `lib/database/notes.dart` - Added sequence column definition
- `lib/database/database.dart` - v62 migration with sequence backfill
- `lib/database/database.g.dart` - Regenerated drift code
- `lib/notes/notes_page.dart` - ReorderableListView with batch update on reorder
- `lib/notes/note_editor_page.dart` - New note sequence assignment (MAX + 1)

## Decisions Made
- List layout instead of grid: ReorderableListView requires single-column layout
- Sequence stored descending: highest sequence = top of list for intuitive ordering
- Local state tracking: _localNotes syncs with stream, enables responsive drag feedback before DB commit
- proxyDecorator: elevation 8 with shadow for visual lift during drag

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Notes feature complete with reordering capability
- Order persists across app restarts via sequence column
- Ready for user testing

---
*Phase: 03-notes-reorder*
*Completed: 2026-02-02*
