# Phase 2: Edit Workout - Research

**Researched:** 2026-02-02
**Domain:** Flutter in-place edit mode for workout data modification
**Confidence:** HIGH

## Summary

This phase implements edit mode functionality for completed workouts, allowing users to correct mistakes. The codebase already contains all the necessary patterns for this feature - the active workout flow (`StartPlanPage`, `ExerciseSetsCard`, `SetRow`) provides the exact editing UI needed, and the workout detail page (`WorkoutDetailPage`) provides the viewing structure to transform into edit mode.

The key insight is that this is NOT a new UI paradigm but rather a state transformation: the same `WorkoutDetailPage` will toggle between read-only and edit modes, reusing the existing set editing widgets (`SetRow`, `WeightInput`, `RepsInput`) that already handle weight/reps changes with database persistence.

**Primary recommendation:** Create an `_isEditMode` boolean state in `WorkoutDetailPage` that transforms the UI in-place, reusing `ExerciseSetsCard` components for exercise management and `SetRow` for inline set editing.

## Standard Stack

This phase uses existing codebase components - no new dependencies required.

### Core (Already in Codebase)
| Component | Location | Purpose | Reuse Strategy |
|-----------|----------|---------|----------------|
| WorkoutDetailPage | `lib/workouts/workout_detail_page.dart` | Workout viewing | Extend with edit mode |
| ExerciseSetsCard | `lib/plan/exercise_sets_card.dart` | Exercise + sets UI | Reuse for edit mode |
| SetRow | `lib/widgets/sets/set_row.dart` | Set editing row | Direct reuse |
| WeightInput | `lib/widgets/sets/weight_input.dart` | Weight input field | Direct reuse |
| RepsInput | `lib/widgets/sets/reps_input.dart` | Reps input with +/- | Direct reuse |
| SetData | `lib/models/set_data.dart` | Set display model | Direct reuse |
| ReorderableListView | Flutter SDK | Drag reordering | Direct reuse |
| PopScope | Flutter SDK | Back navigation interception | Pattern from NoteEditorPage |

### Supporting (Database Operations)
| Component | Location | Purpose | Notes |
|-----------|----------|---------|-------|
| GymSets table | `lib/database/gym_sets.dart` | Set storage | Already has all needed fields |
| Workouts table | `lib/database/workouts.dart` | Workout metadata | Has `name` field for rename |
| QueryHelpers | `lib/database/query_helpers.dart` | Optimized queries | Use existing patterns |

### No New Dependencies Needed
This phase requires zero new packages. All functionality exists in Flutter SDK and the current codebase.

## Architecture Patterns

### Recommended Approach: State-Based Mode Toggle

The `WorkoutDetailPage` will maintain an `_isEditMode` boolean that controls which widgets render.

```
WorkoutDetailPage
├── _isEditMode = false (default)
│   └── Read-only view (current implementation)
├── _isEditMode = true
│   └── Edit view (reuses ExerciseSetsCard-like components)
└── _hasUnsavedChanges tracking for discard confirmation
```

### Pattern 1: In-Place Edit Mode Toggle
**What:** Same screen renders differently based on edit state
**When to use:** When edit and view share most UI structure
**Example from codebase:** `StartPlanPage._isReorderMode` toggles between normal view and reorder mode

```dart
// Existing pattern in StartPlanPage (lines 58-59, 446-449)
bool _isReorderMode = false;

// AppBar changes based on mode
AppBar(
  title: _isReorderMode
      ? const Text('Reorder Exercises')
      : GestureDetector(
          onTap: _editWorkoutTitle,
          child: Row(...)
        ),
  leading: IconButton(
    icon: Icon(_isReorderMode ? Icons.close : Icons.arrow_back),
    onPressed: () {
      if (_isReorderMode) {
        setState(() => _isReorderMode = false);
      } else {
        Navigator.pop(context);
      }
    },
  ),
)
```

### Pattern 2: Unsaved Changes Protection with PopScope
**What:** Intercept back navigation to confirm discard
**When to use:** When user can lose work by navigating away
**Example from codebase:** `NoteEditorPage` (lines 176-188)

```dart
// Existing pattern in NoteEditorPage
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop) return;

    if (await _onWillPop()) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  },
  child: Scaffold(...)
)

Future<bool> _onWillPop() async {
  if (!_isModified) return true;

  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Save changes?'),
      content: const Text('You have unsaved changes...'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (shouldSave ?? false) {
    await _saveNote();
    return false;
  }
  return shouldSave == false;
}
```

### Pattern 3: Exercise Reordering with ReorderableListView
**What:** Drag-to-reorder list with database sync
**When to use:** User needs to change order of items
**Example from codebase:** `StartPlanPage._buildReorderableList` and `_onReorder` (lines 243-288)

```dart
// Existing pattern for reordering exercises
Future<void> _onReorder(int oldIndex, int newIndex) async {
  if (newIndex > oldIndex) newIndex--;

  setState(() {
    final item = _exerciseOrder.removeAt(oldIndex);
    _exerciseOrder.insert(newIndex, item);
  });

  HapticFeedback.mediumImpact();

  // Update sequence numbers in database
  if (workoutId != null) {
    for (int i = 0; i < _exerciseOrder.length; i++) {
      // ... update database sequence
    }
  }
}
```

### Pattern 4: Inline Set Editing with SetRow
**What:** Editable row with weight/reps inputs and type changing
**When to use:** Editing set data inline
**Example from codebase:** `SetRow` widget with callbacks (lines 1111-1141 of ExerciseSetsCard)

```dart
SetRow(
  key: ValueKey('set_${sets[index].savedSetId ?? index}'),
  index: displayIndex,
  setData: sets[index],
  unit: unit,
  records: sets[index].records,
  onWeightChanged: (value) {
    setState(() => sets[index].weight = value);
    if (sets[index].savedSetId != null) {
      _updateSet(index);
    }
  },
  onRepsChanged: (value) {
    setState(() => sets[index].reps = value);
    if (sets[index].savedSetId != null) {
      _updateSet(index);
    }
  },
  onToggle: () => _toggleSet(index),
  onDelete: () => _deleteSet(index),
  onTypeChanged: (isWarmup, isDropSet) =>
      _changeSetType(index, isWarmup, isDropSet),
)
```

### Anti-Patterns to Avoid
- **Separate Edit Page:** Don't create a new `EditWorkoutPage` - use in-place transformation
- **Deep Copy for Editing:** Don't clone workout data for editing - edit in place with rollback capability
- **Custom Number Inputs:** Don't build new weight/reps inputs - reuse existing `WeightInput` and `RepsInput`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Set reordering | Custom drag logic | `ReorderableListView.builder` | Handles drag animations, accessibility, state |
| Number input | TextField with validation | Existing `WeightInput`, `RepsInput` | Already handles edge cases, formatting |
| Set type change | Custom dropdown | Existing `SetRow` bottom sheet | Already has warmup/dropset/working logic |
| Discard confirmation | Custom dialog flow | `PopScope` + AlertDialog pattern | Already implemented in `NoteEditorPage` |
| Exercise add modal | New picker | `ExercisePickerModal` | Already built for active workout |
| Database batch updates | Manual SQL | Existing `QueryHelpers` patterns | Optimized query patterns |

**Key insight:** The active workout flow (`StartPlanPage` + `ExerciseSetsCard`) already implements 90% of edit functionality. Editing a completed workout is nearly identical to the "resume workout" flow.

## Common Pitfalls

### Pitfall 1: Forgetting Sequence Number Updates
**What goes wrong:** Reordering exercises visually but not updating `sequence` in database
**Why it happens:** `sequence` field on GymSets determines exercise order; visual order diverges from stored order
**How to avoid:** Use `StartPlanPage._onReorder` pattern - update `sequence` for ALL exercises after reorder, not just moved one
**Warning signs:** Exercises appear in wrong order when reopening workout

### Pitfall 2: Set Order vs Exercise Sequence Confusion
**What goes wrong:** Mixing up `setOrder` (position within exercise) and `sequence` (exercise position in workout)
**Why it happens:** Two similar concepts with different scopes
**How to avoid:**
- `sequence` = exercise position (0, 1, 2... for exercises)
- `setOrder` = set position within exercise (0, 1, 2... for sets within one exercise)
**Warning signs:** Sets appear under wrong exercise or in wrong order

### Pitfall 3: Not Handling Superset Consistency
**What goes wrong:** Deleting an exercise breaks superset (leaves single exercise in superset)
**Why it happens:** Superset requires 2+ exercises; deleting one should unlink the remaining
**How to avoid:** Use existing `_checkAndUnmarkSingleSuperset` pattern from `StartPlanPage` (lines 296-320)
**Warning signs:** Single exercise shows superset badge after its pair was deleted

### Pitfall 4: Record Cache Invalidation
**What goes wrong:** PRs not recalculated after editing weight/reps
**Why it happens:** PR cache from `records_service.dart` not cleared
**How to avoid:** Call `clearPRCache()` after any weight/reps modification
**Warning signs:** Incorrect PR badges after editing historical sets

### Pitfall 5: Edit Mode Memory State Without Save
**What goes wrong:** Changes applied to database immediately without explicit save
**Why it happens:** `ExerciseSetsCard` pattern updates DB on every change for active workouts
**How to avoid:** For edit mode, either:
  1. Track changes in memory, apply on save (more complex)
  2. Update DB immediately but track "original state" for rollback (simpler, recommended)
**Warning signs:** Changes persist even when user taps "discard"

### Pitfall 6: Not Refreshing Workout State After Save
**What goes wrong:** `WorkoutDetailPage` shows stale data after editing
**Why it happens:** Page holds reference to original `Workout` object
**How to avoid:** Reload workout from database after save, update local state with `_reloadWorkout()` pattern (already exists, line 1255)
**Warning signs:** Name change not visible until page is popped and revisited

## Code Examples

### Example 1: Mode Toggle State Structure
```dart
// Pattern for WorkoutDetailPage edit mode
class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  bool _isEditMode = false;
  bool _hasUnsavedChanges = false;

  // Original values for rollback
  String? _originalName;
  List<GymSet>? _originalSets;

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _originalName = currentWorkout.name;
      // Snapshot current state for potential rollback
    });
  }

  void _exitEditMode({bool save = false}) {
    if (!save && _hasUnsavedChanges) {
      _showDiscardDialog();
      return;
    }
    if (save) {
      _saveChanges();
    } else {
      _rollbackChanges();
    }
    setState(() {
      _isEditMode = false;
      _hasUnsavedChanges = false;
    });
  }
}
```

### Example 2: Editable Title in AppBar
```dart
// Pattern from StartPlanPage (lines 422-444)
AppBar(
  title: _isEditMode
      ? GestureDetector(
          onTap: _editWorkoutTitle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  currentWorkout.name ?? 'Workout',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        )
      : Text(currentWorkout.name ?? 'Workout'),
  actions: [
    if (_isEditMode) ...[
      IconButton(
        icon: const Icon(Icons.check),
        tooltip: 'Save changes',
        onPressed: () => _exitEditMode(save: true),
      ),
    ] else ...[
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: 'Edit workout',
        onPressed: _enterEditMode,
      ),
    ],
  ],
)
```

### Example 3: Database Update Pattern for Set Changes
```dart
// Pattern from ExerciseSetsCard._updateSet (lines 734-753)
Future<void> _updateSet(int index) async {
  final setData = sets[index];
  if (setData.savedSetId == null) return;

  await (db.gymSets.update()
        ..where((tbl) => tbl.id.equals(setData.savedSetId!)))
      .write(
    GymSetsCompanion(
      weight: Value(setData.weight),
      reps: Value(setData.reps.toDouble()),
    ),
  );

  // Clear PR cache since a set was updated
  clearPRCache();
}
```

### Example 4: Adding Sets to Existing Exercise
```dart
// Pattern from ExerciseSetsCard._addSet (lines 596-732)
Future<void> _addSet({bool isWarmup = false, bool isDropSet = false}) async {
  HapticFeedback.selectionClick();

  // Determine insert position
  int insertIndex;
  if (isWarmup) {
    insertIndex = sets.where((s) => s.isWarmup).length;
  } else if (isDropSet) {
    insertIndex = sets.length;
  } else {
    insertIndex = sets.length - sets.where((s) => s.isDropSet).length;
  }

  // Insert to database
  final gymSet = await db.into(db.gymSets).insertReturning(
    GymSetsCompanion.insert(
      name: exerciseName,
      reps: reps.toDouble(),
      weight: weight,
      unit: unit,
      created: DateTime.now().toLocal(),
      workoutId: Value(workoutId),
      sequence: Value(sequence),
      setOrder: Value(insertIndex),
      hidden: const Value(false), // Mark as completed for edit mode
      warmup: Value(isWarmup),
      dropSet: Value(isDropSet),
    ),
  );

  // Update UI
  setState(() {
    sets.insert(insertIndex, SetData(
      weight: weight,
      reps: reps,
      isWarmup: isWarmup,
      isDropSet: isDropSet,
      savedSetId: gymSet.id,
      completed: true, // Already completed in edit mode
    ));
  });

  // Update setOrder for all subsequent sets
  for (int i = 0; i < sets.length; i++) {
    if (sets[i].savedSetId != null) {
      await (db.gymSets.update()
            ..where((tbl) => tbl.id.equals(sets[i].savedSetId!)))
          .write(GymSetsCompanion(setOrder: Value(i)));
    }
  }
}
```

### Example 5: Delete Set with Confirmation
```dart
// Pattern for delete confirmation (simple, per decision)
Future<void> _deleteSet(int index) async {
  // For sets: no confirmation needed per CONTEXT.md discretion
  HapticFeedback.mediumImpact();

  if (sets[index].savedSetId != null) {
    await (db.gymSets.delete()
          ..where((tbl) => tbl.id.equals(sets[index].savedSetId!)))
        .go();

    clearPRCache();
  }

  setState(() {
    sets.removeAt(index);
    _hasUnsavedChanges = true;
  });
}

// For exercises: recommend confirmation
Future<void> _deleteExercise(String exerciseName, int sequence) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove Exercise?'),
      content: Text('Remove $exerciseName and all its sets?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );

  if (confirmed ?? false) {
    await (db.gymSets.delete()
          ..where((s) =>
              s.workoutId.equals(workoutId!) &
              s.name.equals(exerciseName) &
              s.sequence.equals(sequence)))
        .go();

    clearPRCache();
    // ... update UI state
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WillPopScope | PopScope with onPopInvokedWithResult | Flutter 3.16+ | More flexible pop interception |
| Separate edit pages | In-place mode toggle | Current pattern | Less navigation, smoother UX |
| Custom number steppers | Integrated input widgets | Current pattern | Consistent UX across app |

**Deprecated/outdated:**
- `WillPopScope`: Replaced by `PopScope` with `onPopInvokedWithResult` callback

## Open Questions

### 1. Selfie Button Placement in Edit Mode
**What we know:** User decided selfie should be accessible from edit panel instead of top bar
**What's unclear:** Exact placement - should it be an action button in edit app bar, or a button in the expanded UI?
**Recommendation:** Add camera icon as app bar action when in edit mode, next to save checkmark. This matches the current placement pattern while consolidating edit actions.

### 2. Save vs Auto-Save Behavior
**What we know:** User wants explicit save button with discard confirmation
**What's unclear:** Whether individual field changes should auto-save to DB or only on explicit save
**Recommendation:** Auto-save to DB (like active workout) but track "entered edit mode" state for showing discard dialog. This avoids complex rollback logic while still giving users the mental model of "explicit save".

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `lib/workouts/workout_detail_page.dart` - current view implementation
- Codebase analysis: `lib/plan/start_plan_page.dart` - edit mode toggle pattern, reorder pattern
- Codebase analysis: `lib/plan/exercise_sets_card.dart` - set editing, add/delete sets
- Codebase analysis: `lib/widgets/sets/set_row.dart` - inline editing UI
- Codebase analysis: `lib/notes/note_editor_page.dart` - PopScope + discard confirmation pattern

### Secondary (MEDIUM confidence)
- Codebase analysis: `lib/database/gym_sets.dart` - database schema for sets
- Codebase analysis: `lib/database/workouts.dart` - workout name field
- Codebase analysis: `.planning/codebase/STRUCTURE.md` - file organization patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components exist in codebase, verified by reading source
- Architecture: HIGH - Patterns directly observed in similar features (edit mode, reordering)
- Pitfalls: HIGH - Derived from actual codebase patterns and database schema

**Research date:** 2026-02-02
**Valid until:** 60 days (stable codebase, no external dependencies)
