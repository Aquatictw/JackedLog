# Phase 3: Notes Reorder - Research

**Researched:** 2026-02-02
**Domain:** Flutter drag-drop reordering with Drift database persistence
**Confidence:** HIGH

## Summary

This phase implements drag-drop reordering for the standalone notes list with database-backed sequence persistence. The codebase already has multiple working examples of `ReorderableListView` with database persistence (tab settings, plan exercises, exercise sets), providing clear patterns to follow.

The implementation requires:
1. Adding a `sequence` column to the notes table (database migration v62)
2. Converting the notes page from `GridView` to `ReorderableListView`
3. Implementing instant-save on drop with batch sequence updates

The existing codebase patterns are mature and well-tested. This phase is low-risk because it follows established patterns already proven in `start_list.dart`, `tab_settings.dart`, and `exercise_sets_card.dart`.

**Primary recommendation:** Use `ReorderableListView.builder` with long-press drag (no handle), batch database updates on reorder, and the existing `proxyDecorator` pattern for visual lift effect.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter ReorderableListView | Built-in | Drag-drop list reordering | Native Flutter widget, already used 4x in codebase |
| Drift | 2.x | Database ORM with migrations | Already used throughout app, handles schema migrations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Material Design | Built-in | Visual feedback (elevation, shadows) | proxyDecorator for drag feedback |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ReorderableListView | flutter_reorderable_grid_view | Would preserve grid layout, but adds dependency and doesn't match existing patterns |
| Long-press anywhere | Drag handle icon | Handle is more discoverable but clutters UI and doesn't match CONTEXT.md decision |

## Architecture Patterns

### Recommended Structure
Current notes structure remains unchanged:
```
lib/
├── notes/
│   ├── notes_page.dart      # Modify: GridView → ReorderableListView
│   └── note_editor_page.dart # No changes needed
├── database/
│   ├── notes.dart           # Modify: Add sequence column
│   └── database.dart        # Modify: Add v62 migration
```

### Pattern 1: ReorderableListView with Database Persistence
**What:** Use ReorderableListView.builder with onReorder callback that batch-updates sequence values
**When to use:** Any list that needs user-controlled ordering persisted to database
**Example:**
```dart
// Source: lib/plan/start_list.dart (lines 81-108)
ReorderableListView.builder(
  itemCount: notes.length,
  onReorder: (oldIndex, newIndex) async {
    if (oldIndex < newIndex) {
      newIndex--;
    }

    // Update local state immediately for responsive UI
    final item = notes.removeAt(oldIndex);
    notes.insert(newIndex, item);

    // Batch update all sequences in database
    await db.batch((batch) {
      for (var i = 0; i < notes.length; i++) {
        batch.update(
          db.notes,
          NotesCompanion(sequence: Value(i)),
          where: (n) => n.id.equals(notes[i].id),
        );
      }
    });
  },
  itemBuilder: (context, index) => _NoteCard(
    key: ValueKey(notes[index].id),
    // ... card properties
  ),
);
```

### Pattern 2: proxyDecorator for Visual Lift
**What:** Wrap dragged item with elevated Material during drag
**When to use:** Any ReorderableListView to provide visual feedback
**Example:**
```dart
// Source: lib/plan/start_plan_page.dart (lines 769-780)
proxyDecorator: (child, index, animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) => Material(
      elevation: 8,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: child,
    ),
    child: child,
  );
},
```

### Pattern 3: Database Migration for New Column
**What:** Add sequence column with backfill for existing data
**When to use:** Adding ordered sequence to existing table
**Example:**
```dart
// Source: lib/database/database.dart (lines 137-149) - plan_exercises pattern
// v45→46: Add and backfill sequence column
await m.database.customStatement(
  'ALTER TABLE notes ADD COLUMN sequence INTEGER',
).catchError((e) {});

// Backfill: assign sequence based on updated timestamp (most recent = highest)
await m.database.customStatement('''
  UPDATE notes
  SET sequence = (
    SELECT COUNT(*)
    FROM notes n2
    WHERE n2.updated > notes.updated
  )
''');
```

### Anti-Patterns to Avoid
- **Updating sequence one-by-one:** Use batch updates to avoid N database calls
- **Not handling index adjustment:** Always adjust newIndex when oldIndex < newIndex
- **Missing ValueKey:** ReorderableListView requires unique keys for each item
- **Reordering during search/filter:** Disable reorder when list is filtered (per CONTEXT.md)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag-drop reordering | Custom gesture detectors | ReorderableListView | Built-in handles all edge cases (scroll, boundaries, animation) |
| Batch database updates | Sequential awaits | db.batch() | Single transaction, better performance |
| Drag visual feedback | Custom opacity/scale | proxyDecorator with Material elevation | Consistent with Material Design, already in codebase |

**Key insight:** Flutter's ReorderableListView handles all the complex gesture conflict resolution, scroll-during-drag, and animation timing. The codebase already has 4 working implementations.

## Common Pitfalls

### Pitfall 1: Index Adjustment on Reorder
**What goes wrong:** Items end up in wrong position after reorder
**Why it happens:** When dragging down, newIndex is one higher than expected because item hasn't been removed yet
**How to avoid:** Always include the index adjustment:
```dart
if (oldIndex < newIndex) {
  newIndex--;
}
```
**Warning signs:** Items consistently land one position off when dragging downward

### Pitfall 2: Missing Key on List Items
**What goes wrong:** Flutter throws error or items don't animate correctly
**Why it happens:** ReorderableListView requires unique keys to track items during reorder
**How to avoid:** Always use `key: ValueKey(item.id)` on each item
**Warning signs:** "Each child must have a unique key" error

### Pitfall 3: Reordering Filtered Lists
**What goes wrong:** User reorders filtered subset, but sequence updates affect wrong items
**Why it happens:** Sequence numbers are assigned based on filtered list position, not full list
**How to avoid:** Disable reorder when search query is active (per CONTEXT.md decision)
**Warning signs:** Items jump around unexpectedly after clearing search

### Pitfall 4: GridView to ListView Layout Shift
**What goes wrong:** Notes appear much smaller or layout looks odd after switch
**Why it happens:** GridView uses 2 columns with aspect ratio; ListView uses full width
**How to avoid:** Adjust card styling for single-column layout (taller, full-width cards)
**Warning signs:** Notes appear squished or have awkward proportions

### Pitfall 5: New Notes Not Getting Sequence
**What goes wrong:** New notes have null/0 sequence and appear at wrong position
**Why it happens:** Note creation doesn't assign sequence value
**How to avoid:** When creating note, assign sequence = MAX(sequence) + 1 (or 0 if empty)
**Warning signs:** New notes always appear at bottom regardless of setting

## Code Examples

### Query Notes Ordered by Sequence
```dart
// Order by sequence descending (highest = top, per CONTEXT.md: new notes at top)
stream: (db.notes.select()
  ..orderBy([
    (n) => OrderingTerm(expression: n.sequence, mode: OrderingMode.desc),
  ]))
  .watch(),
```

### Create Note with Sequence
```dart
Future<void> _createNote() async {
  // Get max sequence to put new note at top
  final maxSeq = await (db.notes.selectOnly()
    ..addColumns([db.notes.sequence.max()]))
    .map((row) => row.read(db.notes.sequence.max()))
    .getSingleOrNull();

  final newSequence = (maxSeq ?? -1) + 1;

  final companion = NotesCompanion.insert(
    title: title,
    content: content,
    created: now,
    updated: now,
    color: Value(colorValue),
    sequence: Value(newSequence),
  );
  // ...
}
```

### Disable Reorder During Search
```dart
// In notes_page.dart build method
if (_searchQuery.isNotEmpty) {
  // Return regular ListView (no reorder) when searching
  return ListView.builder(...);
}

// Return ReorderableListView when not searching
return ReorderableListView.builder(...);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom drag gestures | ReorderableListView | Flutter 1.22+ | Built-in widget handles all complexity |
| Individual sequence updates | db.batch() | Always | Single transaction for performance |

**Deprecated/outdated:**
- `ReorderableListView` (non-builder): Use `.builder` variant for better performance with lists

## Open Questions

None. All technical approaches are verified through existing codebase patterns.

## Sources

### Primary (HIGH confidence)
- `/simolus3/drift` - Migration patterns, addColumn, batch updates
- `/websites/flutter_cn` - ReorderableListView documentation
- Codebase: `lib/plan/start_list.dart` - Complete working example of reorder with DB persistence
- Codebase: `lib/plan/start_plan_page.dart` - proxyDecorator pattern
- Codebase: `lib/settings/tab_settings.dart` - ReorderableListView.builder pattern
- Codebase: `lib/database/database.dart` - Migration patterns (v45→46 sequence column)

### Secondary (MEDIUM confidence)
- Codebase: `lib/plan/exercise_sets_card.dart` - Nested ReorderableListView pattern

### Tertiary (LOW confidence)
None - all findings verified through codebase or Context7.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing codebase patterns with Flutter built-ins
- Architecture: HIGH - 4 existing implementations to reference
- Pitfalls: HIGH - Documented from existing code patterns and common Flutter issues

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (stable domain, no external dependencies)
