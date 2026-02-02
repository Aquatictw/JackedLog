# Technology Stack: Flutter UI Enhancements

**Project:** JackedLog - Flutter Fitness App
**Researched:** 2026-02-02
**Focus:** Drag-drop reordering, inline editing of nested data, statistics display

## Executive Summary

This milestone adds three UI enhancement features to the existing JackedLog Flutter app. The research confirms that **all features can be implemented using Flutter's built-in widgets** - no additional packages required. This aligns with the existing architecture (Provider + Drift + fl_chart) and minimizes dependency bloat.

**Key Finding:** Flutter's Material library provides mature, well-documented solutions for all three requirements. The main implementation challenge is integrating reordering persistence with Drift.

---

## Recommended Stack

### 1. Drag-and-Drop List Reordering (Notes)

| Component | Recommendation | Why |
|-----------|---------------|-----|
| Widget | `ReorderableListView.builder` | Built-in Flutter widget, no package needed. The `.builder` variant is specifically designed for database-backed lists. |
| Persistence | Add `order` column to Notes table | Drift migration required; store integer position per note. |
| State | Existing Provider pattern | Update note order in ChangeNotifier, persist to Drift. |

**Confidence:** HIGH - Verified via [official Flutter documentation](https://api.flutter.dev/flutter/material/ReorderableListView-class.html)

**Why ReorderableListView over alternatives:**
- Built into Flutter SDK (no dependency)
- Handles platform-specific drag gestures automatically (long-press on mobile, drag handles on desktop)
- Integrates with existing GridView layout via `ReorderableListView.builder` (requires wrapping approach)
- Production-ready with proper key management

**Implementation Pattern:**
```dart
ReorderableListView.builder(
  itemCount: notes.length,
  itemBuilder: (context, index) {
    final note = notes[index];
    return NoteCard(
      key: ValueKey(note.id),  // CRITICAL: unique key required
      note: note,
    );
  },
  onReorder: (oldIndex, newIndex) {
    // Adjust for Flutter's index behavior
    if (newIndex > oldIndex) newIndex -= 1;

    // Update in-memory state
    final item = notes.removeAt(oldIndex);
    notes.insert(newIndex, item);

    // Persist to Drift (batch update order values)
    _persistNoteOrder(notes);
  },
)
```

**Drift Migration:**
```dart
// Add to Notes table
IntColumn get order => integer().withDefault(const Constant(0))();

// Query with ordering
(db.notes.select()
  ..orderBy([(n) => OrderingTerm(expression: n.order)]))
  .watch();
```

---

### 2. Inline Editing of Nested Data (Workout Sessions)

| Component | Recommendation | Why |
|-----------|---------------|-----|
| Container Widget | `ExpansionTile` | Built-in, designed for hierarchical data. Already used pattern in Flutter ecosystem for workout trackers. |
| Edit Mode | Toggle-based editing | Switch between view/edit modes rather than always-editable. Prevents accidental edits and simplifies UX. |
| Form State | `TextEditingController` per field | Standard Flutter pattern. Create controllers dynamically for each set row. |
| Nested Lists | `Column` inside ExpansionTile | Avoids nested ListView performance issues. Use `shrinkWrap: true` if ListView needed. |

**Confidence:** HIGH - Pattern verified across [multiple authoritative sources](https://api.flutter.dev/flutter/material/ExpansionTile-class.html)

**Data Structure (already exists in codebase):**
```
Workout (id, name, startTime, endTime, notes)
  -> GymSets (id, workoutId, name, weight, reps, setOrder, sequence)
```

**Why ExpansionTile over alternatives:**
- Built-in Material widget
- Proper state preservation with `PageStorageKey`
- `maintainState: true` preserves child widget state during collapse/expand
- Integrates cleanly with existing workout card design

**Recommended Widget Structure:**
```dart
// Workout editing page
ListView.builder(
  itemCount: exercises.length,
  itemBuilder: (context, index) {
    return ExpansionTile(
      key: PageStorageKey('exercise_$index'),  // Preserves expanded state
      maintainState: true,  // Keeps child state during collapse
      title: Text(exercise.name),
      children: [
        // Sets as Column (not nested ListView)
        Column(
          children: exercise.sets.map((set) =>
            _EditableSetRow(
              set: set,
              onChanged: (updated) => _updateSet(updated),
            ),
          ).toList(),
        ),
      ],
    );
  },
)
```

**Inline Edit Pattern:**
```dart
class _EditableSetRow extends StatefulWidget {
  final GymSet set;
  final ValueChanged<GymSet> onChanged;

  @override
  State<_EditableSetRow> createState() => _EditableSetRowState();
}

class _EditableSetRowState extends State<_EditableSetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.set.weight.toString());
    _repsController = TextEditingController(text: widget.set.reps.toString());
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: _isEditing
          ? Row(children: [
              Expanded(child: TextField(controller: _weightController)),
              Expanded(child: TextField(controller: _repsController)),
            ])
          : Text('${widget.set.weight} x ${widget.set.reps}'),
      trailing: IconButton(
        icon: Icon(_isEditing ? Icons.check : Icons.edit),
        onPressed: () {
          if (_isEditing) {
            widget.onChanged(widget.set.copyWith(
              weight: double.parse(_weightController.text),
              reps: double.parse(_repsController.text),
            ));
          }
          setState(() => _isEditing = !_isEditing);
        },
      ),
    );
  }
}
```

**Important Considerations:**
- Create separate `TextEditingController` for each editable field
- Dispose controllers properly to avoid memory leaks
- Use `SizedBox` or `Expanded` to constrain TextField width in ListTile
- Toggle edit mode rather than always showing TextFields (better UX, fewer rebuilds)

---

### 3. Statistics/Aggregation Display (Total Workout Time)

| Component | Recommendation | Why |
|-----------|---------------|-----|
| Display Widget | Existing `StatCard` widget | Already exists in codebase at `lib/widgets/stats/stat_card.dart`. Consistent design. |
| Charting | Existing `fl_chart` (v1.1.1) | Already a dependency. No new packages needed. |
| Data Aggregation | Drift query with SQL aggregation | Perform calculations in database, not Dart. More efficient for large datasets. |
| Layout | `GridView` or `Row`/`Wrap` | Responsive stat cards grid pattern. |

**Confidence:** HIGH - Uses existing codebase patterns, verified fl_chart is [current (v1.1.1)](https://pub.dev/packages/fl_chart)

**Existing StatCard Widget (from codebase):**
```dart
StatCard(
  icon: Icons.timer_outlined,
  label: 'Total Time',
  value: _formatDuration(totalDuration),
  color: colorScheme.primary,
)
```

**Total Workout Time Query (Drift):**
```dart
Future<Duration> getTotalWorkoutTime({DateTime? since}) async {
  final query = db.workouts.select()
    ..where((w) => w.endTime.isNotNull());

  if (since != null) {
    query.where((w) => w.startTime.isBiggerOrEqualValue(since));
  }

  final workouts = await query.get();

  return workouts.fold<Duration>(
    Duration.zero,
    (total, workout) => total + workout.endTime!.difference(workout.startTime),
  );
}

// Or more efficient SQL approach:
Future<int> getTotalWorkoutMinutes({DateTime? since}) async {
  final whereClause = since != null
    ? 'WHERE end_time IS NOT NULL AND start_time >= ${since.millisecondsSinceEpoch ~/ 1000}'
    : 'WHERE end_time IS NOT NULL';

  final result = await db.customSelect('''
    SELECT SUM((end_time - start_time) / 60) as total_minutes
    FROM workouts
    $whereClause
  ''').getSingleOrNull();

  return result?.read<int?>('total_minutes') ?? 0;
}
```

**Stats Display Pattern:**
```dart
// In a stats section widget
FutureBuilder<int>(
  future: getTotalWorkoutMinutes(since: thirtyDaysAgo),
  builder: (context, snapshot) {
    final minutes = snapshot.data ?? 0;
    return StatCard(
      icon: Icons.timer_outlined,
      label: 'Total Time (30d)',
      value: _formatMinutes(minutes),
      color: Theme.of(context).colorScheme.tertiary,
    );
  },
)
```

---

## Alternatives Considered

| Feature | Recommended | Alternative | Why Not Alternative |
|---------|-------------|-------------|---------------------|
| Drag-Drop | `ReorderableListView.builder` | `flutter_reorderable_grid_view` package | Adds dependency. Built-in works for list; grid reordering is complex but achievable. |
| Drag-Drop | `ReorderableListView.builder` | `Draggable` + `DragTarget` | Lower-level, more code. ReorderableListView handles all the complexity. |
| Nested Editing | `ExpansionTile` | `ExpansionPanel` + `ExpansionPanelList` | ExpansionTile is simpler, integrates better with ListView. Panel requires more boilerplate. |
| Nested Editing | Toggle edit mode | Always-editable | Accidental edits, more complex state management, worse performance (all fields have controllers). |
| Stats Display | `StatCard` (existing) | Custom Card implementation | Reinventing existing pattern. Consistency with current app design. |
| Charting | `fl_chart` (existing) | `syncfusion_flutter_charts` | Already using fl_chart. Syncfusion is more feature-rich but adds large dependency. |

---

## No New Dependencies Required

All features use Flutter's built-in widgets and existing project dependencies:

**Already in pubspec.yaml:**
- `flutter` (SDK) - ReorderableListView, ExpansionTile, StatCard building blocks
- `provider: ^6.1.1` - State management
- `drift: ^2.28.1` - Database queries and persistence
- `fl_chart: ^1.0.0` - Charts (if stats include visualization)

**No packages to add for this milestone.**

---

## Implementation Sequence

Based on dependencies and complexity:

1. **Notes Reordering** (Foundation)
   - Add `order` column to Notes table (Drift migration)
   - Update notes query to order by new column
   - Replace GridView with ReorderableListView pattern
   - Implement `onReorder` persistence

2. **Workout Editing** (Most Complex)
   - Create WorkoutEditPage with ExpansionTile structure
   - Implement toggle-based inline editing for sets
   - Add save/cancel workflow
   - Test with existing workout data

3. **Stats Display** (Quick Win)
   - Add totalWorkoutTime query to database helpers
   - Create stats section widget using existing StatCard
   - Integrate into appropriate page (likely History or Overview)

---

## Sources

**HIGH Confidence (Official Documentation):**
- [ReorderableListView class - Flutter API](https://api.flutter.dev/flutter/material/ReorderableListView-class.html)
- [ExpansionTile class - Flutter API](https://api.flutter.dev/flutter/material/ExpansionTile-class.html)
- [Simple app state management - Flutter docs](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)
- [fl_chart package - pub.dev](https://pub.dev/packages/fl_chart)

**MEDIUM Confidence (Verified Community Patterns):**
- [Working with ReorderableListView - KindaCode](https://www.kindacode.com/article/working-with-reorderablelistview-in-flutter)
- [Mastering ExpansionTile in Flutter](https://medium.com/my-technical-journey/mastering-expansiontile-in-flutter-collapsible-ui-made-easy-cec8cec3650a)
- [Complex list editors without state management](https://medium.com/flutter-senior/complex-list-editors-without-state-management-in-flutter-33408c35bac7)

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Drag-Drop Reordering | HIGH | Official Flutter widget, well-documented, standard pattern |
| Inline Editing | HIGH | Standard Flutter patterns, toggle-based approach is established |
| Stats Display | HIGH | Uses existing codebase patterns and widgets |
| Drift Persistence | HIGH | Straightforward migration, existing patterns in codebase |
| Grid Reordering (if needed) | MEDIUM | May need workaround since ReorderableListView is list-focused |

---

## Pitfalls to Avoid

1. **Missing Keys on Reorderable Items**
   - Every child of ReorderableListView MUST have a unique `key`
   - Use `ValueKey(item.id)` not `ValueKey(index)`

2. **Nested ListView Performance**
   - Don't nest ListView inside ExpansionTile
   - Use Column with shrinkWrap or fixed-height containers

3. **TextEditingController Leaks**
   - Always dispose controllers in `dispose()`
   - Consider creating controllers dynamically only when entering edit mode

4. **Reorder Index Adjustment**
   - When `newIndex > oldIndex`, subtract 1 from `newIndex`
   - Flutter's API quirk - documented but easy to forget

5. **ExpansionTile State Loss**
   - Use `PageStorageKey` when inside a ListView
   - Set `maintainState: true` if child state must persist

6. **Editing Completed Workouts**
   - Consider whether to allow edits or just viewing
   - If allowing edits, implement proper save/discard workflow
   - May affect PR calculations - clear PR cache after edits (pattern exists in codebase)
