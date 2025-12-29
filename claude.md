# Flexify - Claude Code Context

## Project Overview
Flexify is a Flutter/Dart fitness tracking mobile app (cross-platform: Android, iOS, Linux, macOS, Windows).

### Key Technologies
- **Framework**: Flutter with Dart (SDK >= 3.2.6)
- **Database**: Drift (Dart SQLite ORM) - Version 2.28.1
- **State Management**: Provider pattern (v6.1.1)
- **UI**: Material Design 3

## Database Architecture

### Current Schema (v48)

#### Tables

1. **Workouts** (workout sessions - groups sets together)
   - `id` (autoincrement, primary key)
   - `startTime` (DateTime - when workout started)
   - `endTime` (DateTime, nullable - when workout finished)
   - `planId` (nullable int - which plan template was used)
   - `name` (nullable text - workout name, e.g., "Monday Chest")
   - `notes` (nullable text)

2. **GymSets** (individual exercise sets)
   - `id` (autoincrement, primary key)
   - `name` (exercise name)
   - `reps`, `weight`, `unit`
   - `created` (DateTime)
   - `cardio`, `duration`, `distance`, `incline`
   - `bodyWeight`, `restMs`, `hidden`
   - `planId` (nullable - plan template reference)
   - `workoutId` (nullable int - **links to Workouts.id** for session grouping)
   - `image`, `category`, `notes`

3. **Plans** (workout templates)
   - `id`, `days`, `sequence`, `title`

4. **PlanExercises** (exercises in a plan template)
   - `id`, `planId`, `exercise`, `enabled`, `maxSets`, `warmupSets`, `timers`, `sequence`

5. **Settings** (app preferences - 30+ fields)

6. **Metadata** (version tracking)

### Data Hierarchy
```
Workout Session (e.g., "Monday Chest - Dec 29, 5pm")
  └── Exercise 1 (e.g., Bench Press)
  │     ├── Set 1: 10x135lb
  │     ├── Set 2: 8x155lb
  │     └── Set 3: 6x175lb
  └── Exercise 2 (e.g., Incline Press)
        ├── Set 1: 12x50lb
        └── Set 2: 10x55lb
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, database init, Provider setup |
| `lib/database/database.dart` | Drift DB definition, all migrations (v1-v48) |
| `lib/database/workouts.dart` | Workouts table definition |
| `lib/database/gym_sets.dart` | GymSets table + graph utilities |
| `lib/database/plans.dart` | Plans table |
| `lib/database/plan_exercises.dart` | PlanExercises junction table |
| `lib/sets/history_page.dart` | History tab - toggle between Workouts/Sets view |
| `lib/workouts/workouts_list.dart` | Workout cards list for history |
| `lib/workouts/workout_detail_page.dart` | View a complete workout session |
| `lib/workouts/workout_state.dart` | WorkoutState provider - manages single active workout |
| `lib/workouts/active_workout_bar.dart` | Floating bar showing ongoing workout |
| `lib/plan/start_plan_page.dart` | Workout execution UI - creates workout sessions |
| `lib/plan/plan_tile.dart` | Plan list tile - checks for active workout before starting |

## Workout Session Feature

### How It Works

1. **Starting a Workout**: When user opens `StartPlanPage`, `WorkoutState` manages workout creation. Only ONE workout can be active at a time.

2. **Logging Sets**: Each set saved gets the current `workoutId` attached, linking it to the workout session.

3. **Active Workout Bar**: A floating bar appears above the bottom navigation showing the current workout with:
   - Workout name and elapsed time
   - Tap to resume (navigate to StartPlanPage)
   - "End" button to stop the workout

4. **Single Workout Limit**: If a user tries to start a different plan while a workout is active, they see a toast message "Finish your current workout first" with a "Resume" option.

5. **Ending a Workout**: User must explicitly end via the ActiveWorkoutBar dialog. Workout persists even when navigating away from StartPlanPage.

6. **Viewing History**: The History tab has a toggle between:
   - **Workouts view**: Shows workout session cards with exercise count, set count, and duration
   - **Sets view**: Shows individual sets (legacy view)

7. **Workout Details**: Tapping a workout card opens `WorkoutDetailPage` showing all exercises and sets grouped together.

### Key Code Paths

**WorkoutState provider** (`lib/workouts/workout_state.dart`):
- `startWorkout(Plan plan)` - Creates new workout, returns null if one already exists
- `stopWorkout()` - Sets endTime on active workout and clears state
- `hasActiveWorkout` - Boolean indicating if a workout is in progress

**Starting a workout via WorkoutState** (`lib/plan/start_plan_page.dart`):
```dart
final workoutState = context.read<WorkoutState>();
if (workoutState.activeWorkout == null) {
  final workout = await workoutState.startWorkout(widget.plan);
  workoutId = workout.id;
}
```

**Preventing multiple workouts** (`lib/plan/plan_tile.dart`):
```dart
if (workoutState.hasActiveWorkout && workoutState.activePlan?.id != widget.plan.id) {
  toast('Finish your current workout first');
  return;
}
```

**Linking sets to workout** (`lib/plan/start_plan_page.dart`):
```dart
workoutId: Value(workoutId),
```

**Ending workout via ActiveWorkoutBar** (`lib/workouts/active_workout_bar.dart`):
```dart
await workoutState.stopWorkout();
```

## Development Commands

```bash
# Generate Drift database code after schema changes
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Build for release
flutter build apk
flutter build ios
```

## Architecture Notes

- **Stream-based UI**: Real-time updates via Drift watchers
- **Provider State**: Global state managed through Provider pattern
- **Offline-first**: Pure SQLite, no network dependency
- **Workout Grouping**: Sets are grouped into workout sessions via `workoutId` foreign key

## Migration Notes

When adding new columns or tables, see `docs/DRIFT_MIGRATIONS.md` for detailed instructions.

### Quick Reference

1. Add to table definition (e.g., `lib/database/workouts.dart`)
2. Update `@DriftDatabase` annotation in `database.dart`
3. Add migration in `onUpgrade: stepByStep(...)`
4. Increment `schemaVersion`
5. Copy schema files:
   ```bash
   cp drift_schemas/db/drift_schema_vN.json drift_schemas/db/drift_schema_vN+1.json
   cp test/drift/db/generated/schema_vN.dart test/drift/db/generated/schema_vN+1.dart
   sed -i 's/SchemaN/SchemaN+1/g' test/drift/db/generated/schema_vN+1.dart
   ```
6. Run `dart run build_runner build --delete-conflicting-outputs`
7. If build_runner doesn't generate migration steps, manually add to `database.steps.dart`:
   - Add `SchemaNN` class (copy from previous, add new columns/tables)
   - Add `fromN-1ToN` parameter to both `migrationSteps()` and `stepByStep()` functions
   - Add case N-1 to the switch statement

### Type Usage in Migrations

- **In `constants.dart` `SettingsCompanion.insert()`**: required fields use plain values, optional use `Value()`
- **In migrations with `RawValuesInsertable()`**: ALL fields use `Variable()`
- **In table schema `withDefault()`**: use `const Constant(value)`

### Import Conflicts

When using both Drift and Flutter Material, hide Drift's `Column`:
```dart
import 'package:drift/drift.dart' hide Column;
```
