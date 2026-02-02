# Domain Pitfalls: Flutter UI Enhancements

**Domain:** Fitness app UI enhancements (drag-drop reorder, edit workflows, duration stats)
**Researched:** 2026-02-02
**Codebase:** JackedLog (Flutter + Drift + Provider)

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or major issues.

---

### Pitfall 1: Sequence/Order Column Sync Drift

**What goes wrong:** UI reorder state and database sequence values become desynchronized. User drags item A to position 3, but database still has it at position 1. On next app open, items appear in wrong order or in original order.

**Why it happens:**
- Optimistic UI updates without waiting for database confirmation
- Missing await on database operations in `onReorder` callback
- Not updating ALL affected rows (only updating moved item, not renumbering others)
- In-memory state diverges from database state during rapid reorders

**Consequences:**
- Items revert to old order on app restart
- Data corruption if partial updates occur
- Export/import produces wrong ordering
- Confusing UX where reorder "doesn't stick"

**Warning signs:**
- Reordered items "snap back" after navigating away
- Order correct until app restart
- Random order on resume from background
- Tests pass but production users report ordering issues

**Prevention:**
```dart
// BAD: Optimistic update without sync
void _onReorder(int oldIndex, int newIndex) {
  setState(() {
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
  });
  _updateDatabase(); // async without await
}

// GOOD: Sync state with database confirmation
Future<void> _onReorder(int oldIndex, int newIndex) async {
  if (newIndex > oldIndex) newIndex--;

  // 1. Update UI immediately for responsiveness
  setState(() {
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
  });

  // 2. Update ALL affected items in database (not just moved one)
  await db.transaction(() async {
    for (int i = 0; i < _items.length; i++) {
      await (db.notes.update()
        ..where((n) => n.id.equals(_items[i].id)))
        .write(NotesCompanion(sequence: Value(i)));
    }
  });

  // 3. Sync in-memory sequence values with database
  for (int i = 0; i < _items.length; i++) {
    _items[i] = _items[i].copyWith(sequence: i);
  }
}
```

**JackedLog-specific context:**
- Existing `start_plan_page.dart` already handles exercise reorder with database sync
- Pattern: Update DB, then sync in-memory `item.sequence` values
- Notes table currently lacks `sequence` column - must add via migration
- Match the existing pattern from `_onReorder` in `start_plan_page.dart`

**Confidence:** HIGH - Based on existing codebase patterns and official Flutter/Drift documentation.

---

### Pitfall 2: Edit Mode Without Transactional Rollback

**What goes wrong:** User enters edit mode for completed workout, modifies several exercises/sets, then presses "Cancel" - but some changes were already persisted to database. Partial state corruption.

**Why it happens:**
- Eager persistence: saving each field change immediately
- No copy-on-write pattern: modifying original objects directly
- Missing "draft" state concept: treating edit as immediate writes
- Provider/ChangeNotifier mutations without isolation

**Consequences:**
- Cancel button doesn't actually cancel
- Original workout data permanently lost
- Inconsistent state between related records
- Personal records incorrectly recalculated

**Warning signs:**
- Users report "my workout was corrupted after editing"
- Cancel and Save buttons behave identically
- Editing one field unexpectedly changes another

**Prevention:**
```dart
// BAD: Direct mutation during edit
class EditWorkoutState extends ChangeNotifier {
  Workout workout;

  void updateName(String name) {
    workout = workout.copyWith(name: name);
    db.workouts.update()...; // Persists immediately!
    notifyListeners();
  }
}

// GOOD: Draft pattern with explicit save
class EditWorkoutState extends ChangeNotifier {
  final Workout _original; // Immutable original
  late Workout _draft;     // Working copy

  EditWorkoutState(this._original) {
    _draft = _original.copyWith(); // Deep copy
  }

  void updateName(String name) {
    _draft = _draft.copyWith(name: name);
    notifyListeners(); // UI only, no persistence
  }

  Future<void> save() async {
    await db.workouts.update()
      ..where((w) => w.id.equals(_original.id))
      .write(_draft.toCompanion());
  }

  void cancel() {
    // Simply dispose - _original never changed
  }
}
```

**JackedLog-specific context:**
- Workouts have nested structure: Workout -> GymSets (exercises) -> individual sets
- Must deep-copy entire hierarchy for edit draft
- GymSets are linked by `workoutId` - batch update on save
- Consider whether edit affects personal records (may need recalculation)
- Export format includes `sequence`, `setOrder` - must maintain consistency

**Confidence:** HIGH - Standard pattern, verified against codebase structure.

---

### Pitfall 3: Duration Calculation Timezone Mismatch

**What goes wrong:** Workout duration shows as negative, wildly wrong, or inconsistent between views. Database stores UTC, but calculations mix local and UTC times.

**Why it happens:**
- SQLite stores timestamps as Unix epoch (seconds since 1970 UTC)
- Dart DateTime created with `DateTime.now()` is local time
- Mixing `.toLocal()` and `.toUtc()` inconsistently
- DST transitions cause 1-hour jumps

**Consequences:**
- Negative durations (endTime < startTime due to timezone confusion)
- Duration changes by 1 hour during DST transitions
- Aggregated stats wildly incorrect
- Different duration shown in different screens

**Warning signs:**
- Duration shows as "-1:00:00" or very large values
- Duration changes when phone changes timezone
- Duration differs between list view and detail view
- Users near DST boundary report issues twice yearly

**Prevention:**
```dart
// BAD: Inconsistent timezone handling
final duration = workout.endTime.difference(workout.startTime);
// If endTime is UTC and startTime is local, this is wrong

// GOOD: Consistent approach (all local or all UTC)
// JackedLog uses local time for display, stored as Unix epoch
final startTime = DateTime.fromMillisecondsSinceEpoch(
  row.read<int>('start_time') * 1000,
).toLocal();
final endTime = DateTime.fromMillisecondsSinceEpoch(
  row.read<int>('end_time') * 1000,
).toLocal();
final duration = endTime.difference(startTime);

// For aggregation, use Unix epoch math directly in SQL
// This avoids timezone issues entirely
SELECT SUM(end_time - start_time) as total_seconds FROM workouts;
```

**JackedLog-specific context:**
- Codebase uses `DateTime.now().toLocal()` for writes (see `workout_state.dart:81`)
- Database stores as Unix epoch seconds (see `'unixepoch'` in SQL queries)
- `workouts_list.dart:215` calculates: `workout.endTime?.difference(workout.startTime)`
- For aggregation, keep calculation in SQL to avoid Dart timezone issues
- Be careful with null endTime (active workouts)

**Confidence:** HIGH - Based on [DateTime class documentation](https://api.flutter.dev/flutter/dart-core/DateTime-class.html) and codebase analysis.

---

## Moderate Pitfalls

Mistakes that cause delays, bugs, or technical debt.

---

### Pitfall 4: ReorderableListView Key Management

**What goes wrong:** Reorder animation glitches, wrong item moves, or crash with "Multiple widgets used the same GlobalKey" error.

**Why it happens:**
- Using index as key instead of unique identifier
- Keys change when list is modified
- Using GlobalKey instead of ValueKey
- Key collisions after delete + reorder

**Warning signs:**
- Animation shows wrong item being dragged
- App crashes during reorder with key conflict error
- Items swap instead of insert at position
- Delete + reorder causes visual glitches

**Prevention:**
```dart
// BAD: Index-based keys
ReorderableListView.builder(
  itemBuilder: (context, index) {
    return ListTile(
      key: ValueKey(index), // Changes when order changes!
      ...
    );
  },
);

// GOOD: Stable unique keys
ReorderableListView.builder(
  itemBuilder: (context, index) {
    final note = notes[index];
    return ListTile(
      key: ValueKey(note.id), // Stable database ID
      ...
    );
  },
);
```

**JackedLog-specific context:**
- `start_plan_page.dart` uses `ValueKey(item.key)` where `item.key` is `uniqueId`
- Notes have `id` column that can be used as stable key
- If implementing ReorderableListView for notes grid, convert from GridView

**Confidence:** HIGH - Based on [Flutter ReorderableListView documentation](https://api.flutter.dev/flutter/material/ReorderableListView-class.html).

---

### Pitfall 5: Nested Data Edit State Explosion

**What goes wrong:** Editing a workout with 5 exercises, each with 4 sets = 20+ stateful objects to track. State becomes unmaintainable, bugs emerge from partial updates.

**Why it happens:**
- Flat state structure for inherently hierarchical data
- Each set has its own TextEditingController
- No clear ownership of mutable state
- Manual synchronization between parent and child state

**Warning signs:**
- Edit page has 10+ TextEditingControllers
- Changes to one set affect another
- Memory grows during editing session
- Dispose() calls missing for controllers

**Prevention:**
```dart
// BAD: Flat state with many controllers
class EditWorkoutPage extends StatefulWidget {
  // Dozens of controllers, one per field
  final nameController = TextEditingController();
  final set1WeightController = TextEditingController();
  final set1RepsController = TextEditingController();
  final set2WeightController = TextEditingController();
  // ... explosion of state
}

// GOOD: Hierarchical state with single source of truth
class EditWorkoutState extends ChangeNotifier {
  late WorkoutDraft draft;

  WorkoutDraft loadFromDb(Workout workout, List<GymSet> sets) {
    return WorkoutDraft(
      name: workout.name,
      exercises: groupSetsByExercise(sets).map((e) =>
        ExerciseDraft(
          name: e.name,
          sets: e.sets.map((s) => SetDraft.from(s)).toList(),
        )
      ).toList(),
    );
  }
}

// Child widgets read from draft, write via callbacks
class SetEditor extends StatelessWidget {
  final SetDraft set;
  final ValueChanged<SetDraft> onChanged;

  // Controllers created locally, disposed automatically
}
```

**JackedLog-specific context:**
- Existing `start_plan_page.dart` groups sets by exercise using sequence numbers
- GymSets have `sequence` (exercise order) and `setOrder` (set order within exercise)
- Edit page should mirror this grouping structure
- Consider reusing `ExerciseSetsCard` component with edit mode flag

**Confidence:** MEDIUM - Architecture pattern, not verified against specific documentation.

---

### Pitfall 6: Drift Migration Column Default Gotcha

**What goes wrong:** Adding `sequence` column to Notes table breaks existing rows that have NULL sequence, or all notes end up with sequence = 0.

**Why it happens:**
- Column added without proper default value
- Backfill query runs before column exists
- Default value doesn't match application logic

**Warning signs:**
- All notes show in wrong order after migration
- Query errors about NULL in non-null column
- Existing notes all have sequence = 0

**Prevention:**
```dart
// BAD: Add column without backfill
await m.database.customStatement(
  'ALTER TABLE notes ADD COLUMN sequence INTEGER',
);
// All existing rows now have NULL sequence

// GOOD: Add column with default, then backfill
await m.database.customStatement(
  'ALTER TABLE notes ADD COLUMN sequence INTEGER DEFAULT 0',
);
// Backfill with sensible order (e.g., by created date descending)
await m.database.customStatement('''
  UPDATE notes
  SET sequence = (
    SELECT COUNT(*)
    FROM notes n2
    WHERE n2.created > notes.created
  )
''');
```

**JackedLog-specific context:**
- Database currently at schema v61
- Manual migrations only (no drift migration generator)
- Look at existing patterns: v45->46 adds `sequence` to `plan_exercises` with backfill
- Notes currently ordered by `updated DESC` - use this for initial sequence assignment
- Test migration with production-like data before release

**Confidence:** HIGH - Based on [Drift migration documentation](https://drift.simonbinder.eu/migrations/api/) and existing codebase patterns.

---

### Pitfall 7: Duration Display Inconsistency

**What goes wrong:** Same workout shows different duration in different places (list view: 45 min, detail view: 47 min, stats: 43 min).

**Why it happens:**
- Multiple implementations of duration formatting
- Different rounding strategies
- Some views exclude null endTime, others show "ongoing"
- Stats aggregate differently than individual display

**Warning signs:**
- Users report "workout time doesn't match"
- QA finds different durations in different views
- Total weekly time doesn't sum to individual workouts

**Prevention:**
```dart
// GOOD: Single source of truth for duration calculation
extension WorkoutDuration on Workout {
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  String get formattedDuration {
    final d = duration;
    if (d == null) return 'In progress';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

// For aggregation stats, use SQL SUM of seconds
// then format the total once
```

**JackedLog-specific context:**
- `workouts_list.dart:215` calculates duration inline
- Overview stats calculate in SQL queries
- New "total workout time" stat card must use same calculation
- Consider adding `formattedDuration` extension to Workout model

**Confidence:** MEDIUM - Based on codebase analysis, standard practice.

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable.

---

### Pitfall 8: Missing Haptic Feedback on Reorder

**What goes wrong:** Drag-and-drop feels unresponsive compared to native apps. Users unsure if drag started.

**Why it happens:**
- Default ReorderableListView has no haptic feedback
- Forgetting to add HapticFeedback.mediumImpact()

**Prevention:**
```dart
Future<void> _onReorder(int oldIndex, int newIndex) async {
  HapticFeedback.mediumImpact(); // Add this
  // ... rest of reorder logic
}
```

**JackedLog-specific context:**
- `start_plan_page.dart:251` already uses `HapticFeedback.mediumImpact()`
- Maintain consistency - add to notes reorder too

**Confidence:** HIGH - Existing pattern in codebase.

---

### Pitfall 9: Edit Mode Exit Without Confirmation

**What goes wrong:** User makes changes, accidentally taps back button, loses all edits without warning.

**Why it happens:**
- No `WillPopScope` or `PopScope` wrapper
- No "unsaved changes" tracking
- Back button treated same as explicit Cancel

**Prevention:**
```dart
PopScope(
  canPop: !hasUnsavedChanges,
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop) return;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Discard'),
          ),
        ],
      ),
    );

    if (shouldDiscard ?? false) {
      Navigator.pop(context);
    }
  },
  child: Scaffold(...),
)
```

**JackedLog-specific context:**
- Active workout already has discard confirmation in `workout_state.dart`
- Apply same pattern to edit completed workout flow

**Confidence:** HIGH - Standard Flutter pattern.

---

### Pitfall 10: Reorder Mode UI Collision with Delete

**What goes wrong:** User tries to delete item while in reorder mode, gesture conflicts cause unexpected behavior.

**Why it happens:**
- Dismissible and ReorderableListView fighting for gestures
- Both respond to horizontal swipe
- State management confusion

**Warning signs:**
- Swipe to delete triggers reorder
- Items jump unexpectedly during delete attempt

**Prevention:**
- Disable Dismissible while in reorder mode
- Use explicit mode toggle (like existing `_isReorderMode` in `start_plan_page.dart`)
- Separate delete action to long-press menu or edit mode

**JackedLog-specific context:**
- `start_plan_page.dart` already uses mode toggle approach
- Notes page uses delete icon button in card, not swipe
- Maintain consistency - don't add swipe-to-delete if using reorder

**Confidence:** HIGH - Based on [known Flutter issues](https://medium.com/@seulinger/flutter-resolving-error-when-using-dismissible-and-reorderablelistview-together-28a6d1eb30e1) and existing codebase patterns.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Notes reorder | Sequence sync drift (#1) | Follow start_plan_page pattern exactly |
| Notes reorder | Key management (#4) | Use `note.id` as ValueKey |
| Notes migration | Column default (#6) | Backfill based on `updated DESC` |
| Edit workout | Transactional rollback (#2) | Draft pattern with explicit save |
| Edit workout | Nested state (#5) | Reuse ExerciseSetsCard structure |
| Edit workout | Exit confirmation (#9) | Add PopScope wrapper |
| Duration stat | Timezone mismatch (#3) | Calculate in SQL, format in Dart |
| Duration stat | Display inconsistency (#7) | Single extension method |

---

## Codebase-Specific Recommendations

### For Notes Reorder Feature

1. **Migration pattern** - Copy from schema v45->46 (`plan_exercises.sequence`)
2. **UI pattern** - Copy from `start_plan_page.dart` reorder mode
3. **State pattern** - Use Drift stream for live updates
4. **Do NOT convert GridView to ReorderableListView** - GridView doesn't support reorder. Either:
   - Switch to ReorderableListView (loses grid layout)
   - Use `ReorderableGridView` package
   - Implement custom drag-drop for grid

### For Edit Workout Feature

1. **Mirror active workout UX** - User expects same interaction as `start_plan_page.dart`
2. **Group by exercise** - Use existing `sequence` grouping logic
3. **Draft state** - Deep copy workout + all gym sets before editing
4. **Personal records** - May need recalculation after edit (weight/reps changed)
5. **Superset handling** - Must preserve `supersetId` and `supersetPosition`

### For Duration Stat Feature

1. **SQL aggregation** - `SUM(end_time - start_time)` in Unix epoch
2. **Handle NULL** - Exclude active workouts (NULL endTime)
3. **Match existing pattern** - See `overview_page.dart` stats queries
4. **Period filtering** - Reuse `PeriodSelector` component

---

## Sources

**Official Documentation:**
- [Flutter ReorderableListView](https://api.flutter.dev/flutter/material/ReorderableListView-class.html) - Key management, onReorder API
- [Drift Migrations](https://drift.simonbinder.eu/migrations/api/) - TableMigration, column defaults
- [Dart DateTime](https://api.flutter.dev/flutter/dart-core/DateTime-class.html) - Timezone handling
- [Dart Duration](https://api.flutter.dev/flutter/dart-core/Duration-class.html) - Duration is context-independent

**Community Sources (LOW-MEDIUM confidence, verify):**
- [Dismissible + ReorderableListView conflict](https://medium.com/@seulinger/flutter-resolving-error-when-using-dismissible-and-reorderablelistview-together-28a6d1eb30e1)
- [DateTime DST pitfalls](https://www.flutterclutter.dev/flutter/troubleshooting/datetime-add-and-subtract-daylight-saving-time/2021/2317/)
- [Drift migration article](https://medium.com/@tagizada.nicat/migration-with-flutter-drift-c9e21e905eeb)
- [Provider nested data patterns](https://www.geeksforgeeks.org/flutter-using-nested-models-and-providers/)

**Codebase Analysis:**
- `/home/aquatic/Documents/JackedLog/lib/plan/start_plan_page.dart` - Reorder pattern reference
- `/home/aquatic/Documents/JackedLog/lib/database/database.dart` - Migration patterns
- `/home/aquatic/Documents/JackedLog/lib/workouts/workout_state.dart` - Workout lifecycle
- `/home/aquatic/Documents/JackedLog/lib/export_data.dart` - Data format requirements
