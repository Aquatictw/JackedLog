# Architecture Patterns: Flutter UI Enhancements

**Domain:** Fitness tracking app - Flutter/Drift integration patterns
**Researched:** 2026-02-02
**Confidence:** HIGH (based on existing codebase analysis + official documentation)

## Executive Summary

This research examines how three new features integrate with JackedLog's existing Provider + Drift architecture:

1. **Notes table sequence column** - Drift migration for drag-drop reordering
2. **Edit mode for completed workouts** - Distinguishing active vs historical data editing
3. **Duration aggregation queries** - Stats computation patterns

The existing codebase already implements similar patterns (plan_exercises has sequence, start_plan_page has reorder mode, gym_sets.dart has aggregation queries), making these enhancements straightforward extensions rather than architectural changes.

---

## 1. Schema Changes: Notes Sequence Column

### Current Schema (Notes Table)

```dart
// lib/database/notes.dart - current
@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  DateTimeColumn get created => dateTime()();
  DateTimeColumn get updated => dateTime()();
  IntColumn get color => integer().nullable()();
}
```

### Required Schema Change

```dart
// lib/database/notes.dart - with sequence
@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  DateTimeColumn get created => dateTime()();
  DateTimeColumn get updated => dateTime()();
  IntColumn get color => integer().nullable()();
  IntColumn get sequence => integer().withDefault(const Constant(0))();  // NEW
}
```

### Migration Strategy

**Pattern from existing codebase:** The plan_exercises migration (v45->v46) demonstrates exact pattern needed:

```dart
// From database.dart lines 138-149
// v45->46: Add and backfill sequence column in plan_exercises
await m.database.customStatement(
  'ALTER TABLE plan_exercises ADD COLUMN sequence INTEGER',
).catchError((e) {});
await m.database.customStatement('''
  UPDATE plan_exercises
  SET sequence = (
    SELECT COUNT(*)
    FROM plan_exercises pe2
    WHERE pe2.plan_id = plan_exercises.plan_id
      AND pe2.id < plan_exercises.id
  )
''');
```

**For Notes table migration (v61->v62):**

```dart
// Migration in database.dart
if (from < 62 && to >= 62) {
  await m.database.customStatement(
    'ALTER TABLE notes ADD COLUMN sequence INTEGER',
  ).catchError((e) {});

  // Backfill: order by updated DESC (most recent first = sequence 0)
  await m.database.customStatement('''
    UPDATE notes
    SET sequence = (
      SELECT COUNT(*)
      FROM notes n2
      WHERE n2.updated > notes.updated
    )
  ''');
}
```

### Confidence: HIGH

- Exact pattern exists in codebase (plan_exercises)
- [Drift migration documentation](https://drift.simonbinder.eu/migrations/api/) confirms ALTER TABLE approach
- SQLite safely ignores .catchError() for idempotent re-runs

---

## 2. Drag-Drop Reordering for Notes

### Existing Pattern in Codebase

The `StartPlanPage` already implements full drag-drop reordering (lines 243-288):

```dart
// From start_plan_page.dart
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
      final item = _exerciseOrder[i];
      final oldSequence = item.sequence;
      await db.customUpdate(
        'UPDATE gym_sets SET sequence = ? WHERE workout_id = ? AND name = ? AND sequence = ?',
        updates: {db.gymSets},
        variables: [
          Variable.withInt(i),
          Variable.withInt(workoutId!),
          Variable.withString(exerciseName),
          Variable.withInt(oldSequence),
        ],
      );
      item.sequence = i;
    }
  }
}
```

### Recommended Pattern for NotesPage

**State Management Approach:**

Notes currently uses direct StreamBuilder without local state management. Two approaches:

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **A: Local State** | Simple, isolated to NotesPage | Duplicates data, sync issues | Use for small lists |
| **B: NotesState (ChangeNotifier)** | Consistent with app architecture, reusable | More code, new Provider | Use if notes used elsewhere |

**Recommendation: Local State (Approach A)** because:
1. Notes page is self-contained (not used by other features)
2. Existing codebase uses local state for edit_plan_page exercises
3. Simpler implementation, follows KISS principle

### Implementation Pattern

```dart
// NotesPage with reorder support
class _NotesPageState extends State<NotesPage> {
  List<Note> _notes = [];
  bool _isReorderMode = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Note>>(
      stream: (db.notes.select()
        ..orderBy([(n) => OrderingTerm(expression: n.sequence)]))
        .watch(),
      builder: (context, snapshot) {
        if (snapshot.hasData && !_isReorderMode) {
          _notes = snapshot.data!;
        }

        return _isReorderMode
            ? _buildReorderableList()
            : _buildGridView();
      },
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    setState(() {
      final item = _notes.removeAt(oldIndex);
      _notes.insert(newIndex, item);
    });

    // Batch update all sequence values
    await db.batch((batch) {
      for (int i = 0; i < _notes.length; i++) {
        batch.update(
          db.notes,
          NotesCompanion(sequence: Value(i)),
          where: (n) => n.id.equals(_notes[i].id),
        );
      }
    });
  }
}
```

### Key Considerations

1. **Grid vs List:** Current NotesPage uses GridView. ReorderableListView doesn't support grid layout. Options:
   - Switch to list layout in reorder mode (like StartPlanPage does)
   - Use `flutter_reorderable_grid_view` package (adds dependency)
   - **Recommended:** Toggle to list layout for reorder mode (matches existing pattern)

2. **Haptic Feedback:** Use `HapticFeedback.mediumImpact()` on reorder (existing pattern)

3. **Visual Feedback:** Use `proxyDecorator` for elevation during drag (see start_plan_page.dart lines 769-780)

### Confidence: HIGH

- Exact pattern exists in StartPlanPage
- [Flutter ReorderableListView](https://api.flutter.dev/flutter/material/ReorderableListView-class.html) well-documented
- Batch updates efficient for sequence renumbering

---

## 3. Edit Mode for Completed Workouts

### Current Architecture

**Active Workout Flow:**
```
WorkoutState.startWorkout() -> Creates Workout row (endTime=null)
                            -> Sets _activeWorkout, _activePlan
                            -> StartPlanPage uses workoutId for sets
                            -> WorkoutState.stopWorkout() sets endTime
```

**Viewing Completed Workout:**
```
WorkoutDetailPage -> Receives Workout (endTime != null)
                  -> Displays read-only exercise/set data
                  -> Resume button calls WorkoutState.resumeWorkout()
```

### Edit Mode Requirements

Edit mode for completed workouts differs from active workout flow:

| Aspect | Active Workout | Edit Mode (Completed) |
|--------|----------------|----------------------|
| Timer | Running | N/A |
| WorkoutState | Has activeWorkout | No activeWorkout |
| New sets | Adds with current timestamp | Preserves original timestamp |
| Reorder | Yes | Yes (if needed) |
| Delete sets | Yes | Yes |
| Modify sets | Yes | Yes |

### Recommended Architecture

**Option A: Reuse StartPlanPage with edit flag**

```dart
class StartPlanPage extends StatefulWidget {
  final Plan plan;
  final bool isEditMode;  // NEW: distinguishes active vs edit
  final int? editWorkoutId;  // NEW: workout being edited

  // When isEditMode=true:
  // - Don't start timer
  // - Don't show "Finish Workout" button
  // - Show "Save Changes" instead
  // - Don't modify WorkoutState
}
```

**Option B: Dedicated WorkoutEditPage**

```dart
class WorkoutEditPage extends StatefulWidget {
  final Workout workout;

  // Focused on editing existing data
  // No timer, no WorkoutState interaction
  // Direct database operations
}
```

**Recommendation: Option B (Dedicated Page)** because:
1. **Single Responsibility:** Edit mode has different concerns than active recording
2. **Simpler State:** No need to conditionally skip WorkoutState operations
3. **Clearer UX:** Users understand they're editing history, not recording
4. **Existing Pattern:** WorkoutDetailPage already handles completed workouts separately

### Edit Page Integration with Provider

The edit page should NOT modify WorkoutState (which is for active workouts). Instead:

```dart
class WorkoutEditPage extends StatefulWidget {
  final Workout workout;

  @override
  State<WorkoutEditPage> createState() => _WorkoutEditPageState();
}

class _WorkoutEditPageState extends State<WorkoutEditPage> {
  late Stream<List<GymSet>> setsStream;

  @override
  void initState() {
    super.initState();
    setsStream = (db.gymSets.select()
      ..where((s) => s.workoutId.equals(widget.workout.id) & s.hidden.equals(false))
      ..orderBy([(s) => OrderingTerm(expression: s.sequence)]))
      .watch();
  }

  // Direct database operations for edits
  Future<void> _updateSet(GymSet set, GymSetsCompanion update) async {
    await (db.gymSets.update()..where((s) => s.id.equals(set.id)))
        .write(update);
  }

  Future<void> _deleteSet(GymSet set) async {
    await (db.gymSets.delete()..where((s) => s.id.equals(set.id))).go();
  }

  Future<void> _addSet(GymSetsCompanion newSet) async {
    // Use original workout's date context for created timestamp
    await db.gymSets.insertOne(newSet.copyWith(
      created: Value(widget.workout.startTime),  // Or use endTime
      workoutId: Value(widget.workout.id),
    ));
  }
}
```

### Navigation Pattern

From WorkoutDetailPage:

```dart
// Current: Resume button reopens workout as active
IconButton(
  icon: const Icon(Icons.play_arrow),
  tooltip: 'Resume Workout',
  onPressed: () => _resumeWorkout(context),
),

// Add: Edit button for modifying without resuming
IconButton(
  icon: const Icon(Icons.edit_outlined),
  tooltip: 'Edit Workout',
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WorkoutEditPage(workout: widget.workout),
    ),
  ),
),
```

### Confidence: HIGH

- Pattern follows existing separation (StartPlanPage vs WorkoutDetailPage)
- Direct database operations already used throughout codebase
- No new state management complexity

---

## 4. Duration Aggregation Queries

### Existing Aggregation Patterns

The codebase already has extensive aggregation in `lib/database/gym_sets.dart`:

```dart
// Volume aggregation
const volumeCol = CustomExpression<double>('ROUND(SUM(weight * reps), 2)');

// One-rep max (Brzycki formula)
const ormCol = CustomExpression<double>(
  'MAX(CASE WHEN weight >= 0 THEN weight / (1.0278 - 0.0278 * reps) ELSE weight * (1.0278 - 0.0278 * reps) END)',
);

// Cardio aggregation
const inclineAdjustedPace = CustomExpression<double>(
  'SUM(distance) * POW(1.1, AVG(incline)) / SUM(duration)',
);
```

### Duration Stats Query Pattern

For workout duration aggregation, follow the existing pattern:

```dart
// In lib/database/workouts.dart or lib/database/gym_sets.dart

/// Get total workout duration in the period
Future<Duration> getTotalWorkoutDuration({
  required Period period,
}) async {
  final periodStart = getPeriodStart(period);

  final whereClause = periodStart != null
      ? 'WHERE end_time IS NOT NULL AND start_time >= ${periodStart.millisecondsSinceEpoch ~/ 1000}'
      : 'WHERE end_time IS NOT NULL';

  final result = await db.customSelect('''
    SELECT SUM(end_time - start_time) as total_seconds
    FROM workouts
    $whereClause
  ''').getSingleOrNull();

  final totalSeconds = result?.read<int?>('total_seconds') ?? 0;
  return Duration(seconds: totalSeconds);
}

/// Get average workout duration
Future<Duration> getAverageWorkoutDuration({
  required Period period,
}) async {
  final periodStart = getPeriodStart(period);

  final whereClause = periodStart != null
      ? 'WHERE end_time IS NOT NULL AND start_time >= ${periodStart.millisecondsSinceEpoch ~/ 1000}'
      : 'WHERE end_time IS NOT NULL';

  final result = await db.customSelect('''
    SELECT AVG(end_time - start_time) as avg_seconds
    FROM workouts
    $whereClause
  ''').getSingleOrNull();

  final avgSeconds = (result?.read<double?>('avg_seconds') ?? 0).toInt();
  return Duration(seconds: avgSeconds);
}

/// Get workout count
Future<int> getWorkoutCount({required Period period}) async {
  final periodStart = getPeriodStart(period);

  final whereClause = periodStart != null
      ? 'WHERE end_time IS NOT NULL AND start_time >= ${periodStart.millisecondsSinceEpoch ~/ 1000}'
      : 'WHERE end_time IS NOT NULL';

  final result = await db.customSelect('''
    SELECT COUNT(*) as count
    FROM workouts
    $whereClause
  ''').getSingleOrNull();

  return result?.read<int>('count') ?? 0;
}
```

### Combined Stats Query (Optimized)

For a stats dashboard, combine into single query:

```dart
typedef WorkoutStats = ({
  int workoutCount,
  Duration totalDuration,
  Duration avgDuration,
  double totalVolume,
});

Future<WorkoutStats> getWorkoutStats({required Period period}) async {
  final periodStart = getPeriodStart(period);

  final whereClause = periodStart != null
      ? 'AND w.start_time >= ${periodStart.millisecondsSinceEpoch ~/ 1000}'
      : '';

  final result = await db.customSelect('''
    SELECT
      COUNT(DISTINCT w.id) as workout_count,
      SUM(w.end_time - w.start_time) as total_seconds,
      AVG(w.end_time - w.start_time) as avg_seconds,
      SUM(gs.weight * gs.reps) as total_volume
    FROM workouts w
    LEFT JOIN gym_sets gs ON gs.workout_id = w.id AND gs.hidden = 0
    WHERE w.end_time IS NOT NULL
    $whereClause
  ''').getSingleOrNull();

  return (
    workoutCount: result?.read<int>('workout_count') ?? 0,
    totalDuration: Duration(seconds: result?.read<int?>('total_seconds') ?? 0),
    avgDuration: Duration(seconds: (result?.read<double?>('avg_seconds') ?? 0).toInt()),
    totalVolume: result?.read<double?>('total_volume') ?? 0.0,
  );
}
```

### Stream-Based Stats (for reactive UI)

```dart
Stream<WorkoutStats> watchWorkoutStats({required Period period}) {
  // Drift watches on workouts and gymSets tables
  return db.customSelect(
    // Same query as above
    '''...''',
    readsFrom: {db.workouts, db.gymSets},
  ).watchSingle().map((result) => (
    workoutCount: result.read<int>('workout_count'),
    totalDuration: Duration(seconds: result.read<int?>('total_seconds') ?? 0),
    avgDuration: Duration(seconds: (result.read<double?>('avg_seconds') ?? 0).toInt()),
    totalVolume: result.read<double?>('total_volume') ?? 0.0,
  ));
}
```

### Confidence: HIGH

- Exact query patterns exist in gym_sets.dart
- Drift custom SQL fully supported
- getPeriodStart() helper already implemented

---

## Component Boundaries

### Data Layer Changes

| Component | File | Change |
|-----------|------|--------|
| Notes schema | `lib/database/notes.dart` | Add `sequence` column |
| Database version | `lib/database/database.dart` | Bump to v62, add migration |
| Stats queries | `lib/database/workouts.dart` or `gym_sets.dart` | Add duration/stats functions |

### Presentation Layer Changes

| Component | File | Change |
|-----------|------|--------|
| NotesPage | `lib/notes/notes_page.dart` | Add reorder mode toggle, ReorderableListView |
| WorkoutDetailPage | `lib/workouts/workout_detail_page.dart` | Add Edit button |
| WorkoutEditPage | `lib/workouts/workout_edit_page.dart` | **NEW FILE** for edit mode |
| StatsWidget | `lib/widgets/stats/` | Display aggregated stats |

### State Management

| Component | Change | Reason |
|-----------|--------|--------|
| WorkoutState | **No change** | Edit mode doesn't use active workout state |
| NotesState | **Not needed** | Local state sufficient for isolated page |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Modifying WorkoutState for Edit Mode

**What:** Adding `isEditMode` flag to WorkoutState
**Why bad:** WorkoutState is for active workout tracking (timer, nav coordination). Edit mode is fundamentally different.
**Instead:** Create dedicated WorkoutEditPage with direct database operations.

### Anti-Pattern 2: Shared Mutable State for Reorder

**What:** Using a Provider to hold reorderable list state
**Why bad:** Introduces unnecessary complexity, sync issues with database stream
**Instead:** Use local state (`setState`) synchronized with database on reorder complete.

### Anti-Pattern 3: Eager Sequence Updates

**What:** Updating database sequence on every drag move
**Why bad:** Too many DB writes, poor performance, difficult to cancel
**Instead:** Update in-memory list immediately (optimistic UI), batch-write to database on reorder complete.

### Anti-Pattern 4: Missing Migration Idempotency

**What:** Migration that fails on re-run (e.g., column already exists error)
**Why bad:** Users who interrupted migration or restored backups will crash
**Instead:** Use `.catchError((e) {})` for ALTER TABLE statements (existing pattern in codebase).

---

## Data Flow Diagrams

### Notes Reorder Flow

```
User drags note → ReorderableListView.onReorder
                       ↓
              _notes.removeAt(oldIndex)
              _notes.insert(newIndex, note)
              setState() ← Optimistic UI update
                       ↓
              db.batch((batch) {
                for (i, note) in _notes:
                  batch.update(sequence: i)
              })
                       ↓
              Stream emits new order ← UI already correct
```

### Edit Mode Flow

```
WorkoutDetailPage → Edit Button tap
                          ↓
               Navigator.push(WorkoutEditPage)
                          ↓
               StreamBuilder(setsStream)
                          ↓
               User edits set → db.gymSets.update()
               User adds set → db.gymSets.insert()
               User deletes → db.gymSets.delete()
                          ↓
               Navigator.pop() ← Changes already persisted
```

### Stats Aggregation Flow

```
StatsPage/OverviewPage → watchWorkoutStats(period)
                              ↓
                    Drift streams from workouts + gymSets
                              ↓
                    StreamBuilder receives WorkoutStats
                              ↓
                    UI displays: count, total time, avg time, volume
```

---

## Migration Considerations

### Schema Version Bump

```dart
// database.dart
@override
int get schemaVersion => 62;  // Was 61
```

### Migration Code Location

Add to `onUpgrade` in `database.dart`, following existing consolidation pattern:

```dart
// from61To62: Notes sequence column
if (from < 62 && to >= 62) {
  await m.database.customStatement(
    'ALTER TABLE notes ADD COLUMN sequence INTEGER',
  ).catchError((e) {});

  await m.database.customStatement('''
    UPDATE notes
    SET sequence = (
      SELECT COUNT(*)
      FROM notes n2
      WHERE n2.updated > notes.updated
    )
  ''');
}
```

### Drift Schema Export

After migration, run:
```bash
dart run drift_dev schema dump lib/database/database.dart drift_schemas/
```

### Confidence: HIGH

- Follows established migration patterns in codebase
- SQLite ALTER TABLE is safe for adding nullable/default columns
- Backfill query tested conceptually against existing Notes schema

---

## Sources

### Official Documentation
- [Drift Migration API](https://drift.simonbinder.eu/migrations/api/) - Migration patterns
- [Drift Tables](https://drift.simonbinder.eu/dart_api/tables/) - Column definitions
- [Flutter ReorderableListView](https://api.flutter.dev/flutter/material/ReorderableListView-class.html) - Drag-drop API
- [Flutter State Management](https://docs.flutter.dev/data-and-backend/state-mgmt/options) - Provider patterns

### Community Resources
- [Drift Migration with Flutter](https://medium.com/@tagizada.nicat/migration-with-flutter-drift-c9e21e905eeb) - Practical migration examples
- [Mastering ReorderableListView.builder](https://medium.com/@jamshaidaslam/mastering-reorderablelistview-builder-in-flutter-a-deep-dive-for-advanced-developers-60d2f55ea771) - Advanced reorder patterns

### Codebase References (HIGH confidence - primary source)
- `lib/database/database.dart` - Migration patterns (lines 138-149 for sequence)
- `lib/plan/start_plan_page.dart` - Reorder implementation (lines 243-288, 765-797)
- `lib/database/gym_sets.dart` - Aggregation queries (lines 1-260)
- `lib/workouts/workout_state.dart` - Active workout management
- `lib/workouts/workout_detail_page.dart` - Completed workout display

---

## Quality Gate Checklist

- [x] Schema changes are explicit (Notes.sequence column defined)
- [x] State management integrates with existing Provider pattern (local state for notes, no WorkoutState changes for edit)
- [x] Migration considerations noted (v62, backfill query, idempotency)
- [x] Existing patterns referenced from codebase
- [x] Anti-patterns documented
- [x] Data flow diagrams provided

---

*Architecture research completed: 2026-02-02*
