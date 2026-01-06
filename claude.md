# Flexify - Claude Code Context

## DISCLAIMER, MUST READ FOR CLAUDE
## Always do manual migration, don't attempt to run any flutter commands I'll run them for you.
## If database version has been changed, and previous exported data from app can't be reimported, affirm me.

## Project Overview
Flexify is a Flutter/Dart fitness tracking mobile app (cross-platform: Android, iOS, Linux, macOS, Windows).


### Key Technologies
- **Framework**: Flutter with Dart (SDK >= 3.2.6)
- **Database**: Drift (Dart SQLite ORM) - Version 2.28.1
- **State Management**: Provider pattern (v6.1.1)
- **UI**: Material Design 3

## Database Architecture

### Current Schema (v55)

#### Tables

1. **Workouts** (workout sessions - groups sets together)
   - `id` (autoincrement, primary key)
   - `startTime` (DateTime - when workout started)
   - `endTime` (DateTime, nullable - when workout finished, null means workout is active)
   - `planId` (nullable int - which plan template was used)
   - `name` (nullable text - workout name, e.g., "Monday Chest")
   - `notes` (nullable text - workout notes)

2. **GymSets** (individual exercise sets)
   - `id` (autoincrement, primary key)
   - `name` (exercise name)
   - `reps`, `weight`, `unit`
   - `created` (DateTime)
   - `cardio`, `duration`, `distance`, `incline`
   - `restMs`, `hidden`
   - `planId` (nullable - plan template reference)
   - `workoutId` (nullable int - **links to Workouts.id** for session grouping)
   - `image`, `category`, `notes`
   - `sequence` (int, default 0 - **preserves exercise display order in history**)
   - `warmup` (bool, default false - **indicates if set is a warmup set**)
   - `exerciseType` (nullable text - **exercise equipment type**: "free weight", "machine", "cable", etc.)
   - `brandName` (nullable text - **machine brand name** for machine exercises, e.g., "Hammer Strength")
   - `dropSet` (bool, default false - **indicates if set is a drop set**)

3. **Plans** (workout templates)
   - `id` (autoincrement, primary key)
   - `days` (text - days of week or plan name)
   - `sequence` (int - display order)
   - `title` (nullable text - plan title)

4. **PlanExercises** (exercises in a plan template)
   - `id` (autoincrement, primary key)
   - `planId` (int - foreign key to Plans)
   - `exercise` (text - exercise name)
   - `enabled` (bool - whether exercise is active)
   - `maxSets` (nullable int - max sets for this exercise)
   - `warmupSets` (nullable int - number of warmup sets)
   - `timers` (nullable text)
   - `sequence` (int - display order within plan)

5. **Settings** (app preferences - 30+ fields including 5/3/1 training maxes)
   - General settings (theme, units, timers, etc.)
   - Default tabs: `"HistoryPage,PlansPage,GraphsPage,NotesPage,SettingsPage"` (TimerPage removed in v55)
   - Theme settings:
     - `themeMode` (text - "ThemeMode.system", "ThemeMode.dark", or "ThemeMode.light")
     - `systemColors` (bool - whether to use device's dynamic colors)
     - `customColorSeed` (int - custom color seed for Material Design 3 theme, default: 0xFF673AB7 deep purple)
   - 5/3/1 specific settings:
     - `fivethreeoneWeek` (int - current week in 5/3/1 cycle: 1, 2, or 3)
     - `fivethreeoneSquatTm` (nullable real - squat training max)
     - `fivethreeoneBenchTm` (nullable real - bench press training max)
     - `fivethreeoneDeadliftTm` (nullable real - deadlift training max)
     - `fivethreeonePressTm` (nullable real - overhead press training max)

6. **Notes** (general purpose notes, separate from workout/exercise notes)
   - `id` (autoincrement, primary key)
   - `title` (text - note title)
   - `content` (text - note content)
   - `created` (DateTime - creation timestamp)
   - `updated` (DateTime - last update timestamp)
   - `color` (nullable int - note color for categorization)

7. **BodyweightEntries** (bodyweight tracking - added in v55)
   - `id` (autoincrement, primary key)
   - `weight` (real - bodyweight value)
   - `unit` (text - weight unit, e.g., "kg" or "lb")
   - `date` (DateTime - entry timestamp)
   - `notes` (nullable text - optional notes for this entry)

8. **Metadata** (version tracking)

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
| `lib/database/database.dart` | Drift DB definition, all migrations (v1-v55) |
| `lib/database/database.steps.dart` | **Generated** migration steps, Schema classes, Shape classes |
| `lib/database/workouts.dart` | Workouts table definition |
| `lib/database/gym_sets.dart` | GymSets table + graph utilities |
| `lib/database/plans.dart` | Plans table |
| `lib/database/plan_exercises.dart` | PlanExercises junction table |
| `lib/database/bodyweight_entries.dart` | BodyweightEntries table for bodyweight tracking |
| `lib/sets/history_page.dart` | History tab - toggle between Workouts/Sets view |
| `lib/workouts/workouts_list.dart` | Workout cards list for history |
| `lib/workouts/workout_detail_page.dart` | View a complete workout session (sorts by sequence) |
| `lib/workouts/workout_state.dart` | WorkoutState provider - manages single active workout |
| `lib/workouts/active_workout_bar.dart` | Floating bar showing ongoing workout |
| `lib/plan/start_plan_page.dart` | Workout execution UI - creates workout sessions |
| `lib/plan/exercise_sets_card.dart` | Exercise card with sets, popup menu, notes dialog |
| `lib/plan/plans_page.dart` | Plans list page with freeform workout option |
| `lib/plan/plan_tile.dart` | Plan list tile - checks for active workout before starting |
| `lib/records/records_service.dart` | Personal record detection and calculation |
| `lib/records/record_notification.dart` | PR celebration UI and badge widgets |
| `lib/app_search.dart` | Reusable search AppBar with optional Add menu item |
| `lib/graph/overview_page.dart` | Workout overview with stats, heatmap, muscle charts, and bodyweight tracking |
| `lib/widgets/five_three_one_calculator.dart` | 5/3/1 powerlifting program calculator dialog |
| `lib/widgets/bodypart_tag.dart` | Compact muscle group/bodypart tag widget |
| `lib/widgets/artistic_color_picker.dart` | Custom color picker with palettes, HSL sliders, and color grid |
| `lib/widgets/bodyweight_entry_dialog.dart` | Dialog for logging bodyweight entries with date, notes |
| `lib/widgets/timer_quick_access.dart` | Quick access timer dialog with preset durations |
| `lib/settings/appearance_settings.dart` | Appearance settings page including theme and color customization |
| `lib/database/notes.dart` | Notes table definition for general notes |
| `drift_schemas/db/drift_schema_vN.json` | Schema JSON files for each version |

## Workout Overview & Statistics

The workout overview page (`lib/graph/overview_page.dart`) displays comprehensive statistics and visualizations:

**Features:**
- **Period Selector**: 7D, 1M, 3M, 6M, 1Y, All-time
- **Statistics Cards**: Workouts, Total Volume, Streak, Top Muscle, Current Bodyweight, Bodyweight Trend
- **Training Heatmap**:
  - GitHub-style activity calendar showing workout days
  - Days of week column is fixed (doesn't scroll)
  - Grid is reversed (latest workouts on left for consistency)
  - Days properly aligned to Monday-Sunday weeks
  - Clicking a day shows workout details popup with clickable workout name
- **Muscle Group Volume Chart**: Top 10 muscles by weight × reps
- **Muscle Group Set Count Chart**: Top 10 muscles by total sets performed

**Implementation Details:**
- Uses `fl_chart` package for bar charts
- Heatmap uses Monday as week start (weekday 1-7)
- All queries filter out hidden sets (`hidden = 0`)
- Popup navigation creates Workout object from query results
- Charts use different colors (primary for volume, secondary for sets)

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

8. **Active Workout Navigation**: Clicking the ActiveWorkoutBar switches to the Plans tab (if needed) and navigates to the active workout. It clears the Plans navigator stack before pushing the workout page to avoid duplicate routes.

9. **Resuming Ended Workouts**: Ended workouts (those with an `endTime` set) can be resumed from the `WorkoutDetailPage`:
   - A "Resume Workout" FloatingActionButton appears only for ended workouts
   - Tapping it clears the workout's `endTime`, making it active again
   - The workout is set as the active workout in `WorkoutState`
   - User is automatically navigated to the Plans tab and the workout execution page
   - If another workout is already active, shows a toast message "Finish your current workout first"

### Key Code Paths

**WorkoutState provider** (`lib/workouts/workout_state.dart`):
- `startWorkout(Plan plan)` - Creates new workout, returns null if one already exists
- `stopWorkout()` - Sets endTime on active workout and clears state
- `resumeWorkout(Workout workout)` - Clears endTime on ended workout to reactivate it, returns associated plan or null if another workout is active
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

**Resuming ended workout** (`lib/workouts/workout_detail_page.dart`):
```dart
final plan = await workoutState.resumeWorkout(widget.workout);
if (plan == null) {
  toast('Finish your current workout first');
  return;
}
// Navigate to workout execution page with the plan
```

## Multi-Select Workout Deletion

### Overview

The History tab's Workouts view supports multi-selection for batch deletion of workout sessions, mirroring the UI/UX pattern used in the Plans tab.

### How It Works

1. **Entering Selection Mode**:
   - Long press any workout card to begin selecting
   - The card shows a checkbox instead of the date badge
   - Card gets highlighted with primary color

2. **Selecting Multiple Workouts**:
   - When in selection mode, tap any workout to toggle its selection
   - Selected cards show a checked checkbox and highlighted background
   - Badge in AppSearch menu shows selection count

3. **Batch Operations**:
   - **Delete**: Removes selected workouts and all associated gym sets
   - **Select All**: Selects all currently visible workouts (respects limit/filters)
   - **Clear**: Exit selection mode

4. **Exiting Selection Mode**:
   - Tap the back arrow in the search bar
   - Or complete a delete operation

### Implementation Details

**Files Modified:**
- `lib/workouts/workouts_list.dart` - Added selection UI support
- `lib/sets/history_page.dart` - Integrated AppSearch with selection handlers

**Key Features:**
- Cards change appearance when selected (highlighted background, border color)
- Smooth animations for checkbox transitions (150ms ScaleTransition)
- Checkboxes conditionally replace date badges during selection
- More compact vertical spacing (reduced padding from 16 to 12, margins from 6 to 4)
- Deletion is cascading: removes both workouts and their gym sets

**Selection State Management:**
```dart
// In history_page.dart
Set<int> selectedWorkouts = {};

// Toggle selection
onSelect: (id) {
  if (selectedWorkouts.contains(id))
    setState(() {
      selectedWorkouts.remove(id);
    });
  else
    setState(() {
      selectedWorkouts.add(id);
    });
}

// Delete operation
onDelete: () async {
  final copy = selectedWorkouts.toList();
  setState(() {
    selectedWorkouts.clear();
  });
  // Delete all gym sets associated with these workouts
  await db.gymSets.deleteWhere((tbl) => tbl.workoutId.isIn(copy));
  // Delete the workouts themselves
  await db.workouts.deleteWhere((tbl) => tbl.id.isIn(copy));
}
```

**Card Behavior:**
```dart
// In workouts_list.dart
onTap: () {
  if (selected.isNotEmpty) {
    onSelect(workout.id);  // Toggle selection when in selection mode
  } else {
    Navigator.push(...);  // Navigate to details when not selecting
  }
}
onLongPress: () {
  onSelect(workout.id);  // Enter selection mode
}
```

**Visual Styling:**
- Selected: `primary.withValues(alpha: .08)` background, `primary.withValues(alpha: 0.3)` border
- Unselected: Default card color, `outlineVariant.withValues(alpha: 0.1)` border
- Checkbox size: 24x24 with AnimatedSwitcher for smooth transitions

### UI/UX Patterns

This implementation follows the same pattern as Plans tab (`lib/plan/plans_page.dart` and `lib/plan/plan_tile.dart`):
- Uses `Set<int>` for tracking selected IDs
- AppSearch component handles search, select all, clear, and delete
- Long press initiates selection mode
- Visual feedback with color changes and borders
- Confirmation dialog before deletion

## Rest Timers & Exercise Data Loading

### How Rest Timers Work

Rest timers start automatically after completing a set (when marking it as not hidden). The timer duration comes from:
1. **Custom rest time**: Stored in `GymSet.restMs` field (per exercise, in milliseconds)
2. **Global default**: Falls back to `Settings.timerDuration` if no custom time is set

**Key locations:**
- Timer state management: `lib/timer/timer_state.dart`
- Timer UI bar: `lib/timer/rest_timer_bar.dart`
- Timer started in: `_completeSet()` method in both `ExerciseSetsCard` and `_AdHocExerciseCard`

### Exercise Data Loading Pattern

When loading an exercise in workout execution, both `ExerciseSetsCard` (`lib/plan/exercise_sets_card.dart`) and `_AdHocExerciseCard` (`lib/plan/start_plan_page.dart`) follow this pattern:

**1. Load last set from exercise history** to get defaults:
```dart
final lastSet = await (db.gymSets.select()
  ..where((tbl) => tbl.name.equals(exerciseName))
  ..orderBy([(u) => OrderingTerm(expression: u.created, mode: OrderingMode.desc)])
  ..limit(1))
  .getSingleOrNull();

// Extract defaults from last set
_defaultWeight = lastSet?.weight ?? 0.0;
_defaultReps = lastSet?.reps.toInt() ?? 8;
_brandName = lastSet?.brandName;
_exerciseType = lastSet?.exerciseType;
_restMs = lastSet?.restMs; // Custom rest time (nullable)
```

**2. Load existing sets from current workout** (if resuming):
```dart
existingSets = await (db.gymSets.select()
  ..where((tbl) =>
      tbl.name.equals(exerciseName) &
      tbl.workoutId.equals(workoutId) &
      tbl.sequence.equals(sequence))) // sequence identifies exercise instance
  .get();
```

**3. Start timer after completing a set**:
```dart
if (settings.restTimers) {
  final timerState = context.read<TimerState>();
  // Use custom rest time if set, otherwise use global default
  final restMs = _restMs ?? settings.timerDuration;
  timerState.startTimer(
    "$exerciseName ($completedCount)",
    Duration(milliseconds: restMs),
    settings.alarmSound,
    settings.vibrate,
  );
}
```

### Setting Custom Rest Times

Custom rest times are configured via:
- **Edit exercise page**: `lib/graph/edit_graph_page.dart`
- Updates all sets for that exercise with `restMs: Value(duration?.inMilliseconds)`
- Stored per exercise, not per plan or workout

**Important**: Custom rest times are stored at the GymSet level (not PlanExercise level), meaning they're tied to the exercise name across all workouts.

## Timer Quick Access Feature

### Overview

The Timer Quick Access feature provides a convenient way to start standalone timers from anywhere in the app, replacing the standalone Timer tab (removed in v55).

### How It Works

**1. Access Points:**
- **App Bar Icons**: Timer icon appears in the app bar of:
  - Graphs/Overview page (`lib/graph/graphs_page.dart`)
  - Plans page (`lib/plan/plans_page.dart`)
- **Menu Item**: Timer option in AppSearch menu (History page uses AppSearch)

**2. Timer Dialog** (`lib/widgets/timer_quick_access.dart`):
- **Preset Durations**: Quick selection chips for 30s, 1m, 2m, 3m, 5m, 10m
- **Live Progress**: Circular progress indicator showing remaining time
- **Timer Controls**:
  - Start/Pause button
  - Stop button to dismiss
- **Sound & Vibration**: Uses settings from global timer configuration

**3. Implementation:**
```dart
// Show the timer dialog from anywhere
showTimerQuickAccess(context);

// Dialog uses TimerState provider for timer management
final timerState = context.read<TimerState>();
timerState.startTimer(
  "Timer",
  duration,
  settings.alarmSound,
  settings.vibrate,
);
```

**4. Visual Design:**
- Material Design 3 dialog with filled tonal buttons
- Selected duration chip highlighted with primary color
- Progress indicator animates countdown
- Auto-dismisses when timer completes

**Note**: Rest timers during workouts still use the floating RestTimerBar (`lib/timer/rest_timer_bar.dart`) which remains unchanged.

## Bodyweight Tracking Feature

### Overview

The Bodyweight Tracking feature (added in v55) allows users to log their bodyweight over time and view trends directly in the workout overview page.

### How It Works

**1. Database Table** (`lib/database/bodyweight_entries.dart`):
```dart
class BodyweightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get weight => real()();
  TextColumn get unit => text()();  // 'kg' or 'lb'
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
}
```

**2. Logging Entries** (`lib/widgets/bodyweight_entry_dialog.dart`):
- **FloatingActionButton**: "Log Weight" button in overview page bottom-right
- **Dialog Features**:
  - Weight input with increment/decrement buttons
  - Unit selector (uses current strength unit from settings)
  - Date picker (defaults to today)
  - Optional notes field
  - Input validation (weight must be > 0)
- **Visual Design**: Material Design 3 with outlined text fields and filled buttons

**3. Display in Overview** (`lib/graph/overview_page.dart`):
Two new stat cards appear in the overview page:

- **Current Bodyweight Card**:
  - Shows most recent bodyweight entry
  - Displays weight with unit
  - Shows date of entry
  - Icon: monitor_weight_outlined

- **Bodyweight Trend Card**:
  - Compares current weight to weight at start of selected period
  - Shows change amount and percentage
  - Color-coded trend indicator:
    - 🟢 Green: Weight gain (positive change)
    - 🔴 Red: Weight loss (negative change)
    - ⚪ Gray: No change or insufficient data
  - Icon: trending_up/trending_down/trending_flat

**4. Period Filtering:**
- Bodyweight data respects the period selector (7D, 1M, 3M, 6M, 1Y, All)
- Trend calculation compares current weight to weight at start of period
- Queries filter entries by date range

**5. Implementation Details:**
```dart
// Load current bodyweight (most recent entry)
final current = await (db.bodyweightEntries.select()
  ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
  ..limit(1))
  .getSingleOrNull();

// Load bodyweight at start of period for trend
final startDate = DateTime.now().subtract(periodDuration);
final previous = await (db.bodyweightEntries.select()
  ..where((t) => t.date.isSmallerThanValue(startDate))
  ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
  ..limit(1))
  .getSingleOrNull();

// Calculate change
if (current != null && previous != null) {
  final change = current.weight - previous.weight;
  final percentChange = (change / previous.weight) * 100;
}
```

**6. Data Refresh:**
- Dialog returns `true` on successful save
- Overview page reloads data when dialog closes with result
- UI updates immediately with new bodyweight data

### Migration Note

**Database Schema v54 → v55:**
- **Removed**: `GymSets.bodyWeight` column (was unused)
- **Removed**: `Settings.showBodyWeight` setting
- **Added**: `Settings.customColorSeed` column for custom color theming
- **Added**: New `BodyweightEntries` table
- **Updated**: Default tabs setting (removed "TimerPage")

### Export/Import Backward Compatibility

**Important**: The CSV export/import format changed in v55 due to removal of the `bodyWeight` column from `gym_sets.csv`.

**How Backward Compatibility Works:**
The import code (`lib/import_data.dart`) automatically detects the CSV format version:

```dart
// Check CSV header for bodyWeight column
final setsHeader = setsRows.first.map((e) => e.toString().toLowerCase()).toList();
final hasBodyWeightColumn = setsHeader.contains('bodyweight');

// Adjust column indices based on format version
final offset = hasBodyWeightColumn ? 1 : 0;

// Old format (v54 and earlier): id,name,reps,weight,unit,created,cardio,duration,distance,bodyWeight,incline,...
// New format (v55+): id,name,reps,weight,unit,created,cardio,duration,distance,incline,...
```

**What This Means:**
- ✅ Old exports (v54 and earlier with bodyWeight column) can be imported into v55
- ✅ New exports (v55+ without bodyWeight column) work correctly
- ✅ Column indices automatically adjust to skip the bodyWeight field when present
- ✅ No data corruption or import failures

**Affected Files:**
- `lib/export_data.dart`: Removed bodyWeight from CSV generation
- `lib/import_data.dart`: Added format detection and dynamic column indexing

## Personal Records (PR) Feature

### Overview

The Personal Records feature automatically detects and celebrates when a user achieves a new personal best during their workout. It tracks three types of records per exercise:

1. **Best 1RM** (💪): Estimated one-rep max using Brzycki formula
2. **Best Volume** (🔥): Single-set volume (weight × reps)
3. **Best Weight** (🏆): Heaviest weight lifted

### Key Files

| File | Purpose |
|------|---------|
| `lib/records/records_service.dart` | Record calculation and checking logic |
| `lib/records/record_notification.dart` | Celebration notification UI and badge widgets |
| `lib/plan/exercise_sets_card.dart` | PR checking for plan exercises |
| `lib/plan/start_plan_page.dart` | PR checking for ad-hoc exercises |

### How It Works

**1. Record Detection** (`records_service.dart`):

When a set is completed, `checkForRecords()` queries the database to compare against historical bests:

```dart
final achievements = await checkForRecords(
  exerciseName: exerciseName,
  weight: weight,
  reps: reps,
  unit: unit,
  excludeSetId: setId, // Exclude current set from comparison
);
```

The function:
- Calculates 1RM using Brzycki formula: `weight / (1.0278 - 0.0278 * reps)`
- Handles negative weights (bodyweight assistance): `weight * (1.0278 - 0.0278 * reps)`
- Compares current set against all-time bests for that exercise
- Returns list of `RecordAchievement` objects for each record broken

**2. Celebration Notification** (`record_notification.dart`):

When records are detected, `showRecordNotification()` displays an animated celebration dialog:

```dart
if (achievements.isNotEmpty && mounted) {
  showRecordNotification(
    context,
    achievements: achievements,
    exerciseName: exerciseName,
  );
}
```

Features:
- Heavy haptic feedback on record achievement
- Animated confetti particles (30 particles with physics)
- Elastic bounce animation using `Curves.elasticOut`
- Golden crown icon with shimmer effect
- Shows all records broken in one notification
- Displays improvement percentage over previous best
- Auto-dismisses after 3 seconds

**Important**: The notification uses `.clamp(0.0, 1.0)` on opacity values because `Curves.easeOutBack` overshoots 1.0, which would cause assertion errors in the `Opacity` widget.

**3. Visual Indicators**:

- **RecordCrown**: Badge showing crown icon for sets that hold records
  - Colored by record type (amber for weight, orange for 1RM, deep orange for volume)
  - Shows tooltip with record types (e.g., "PR: Weight, 1RM")
  - Used in workout detail view to highlight PR sets

- **RecordIndicator**: Compact row of mini icons for each record type
  - Used in history/list views where space is limited

**4. Implementation in Exercise Cards**:

Both `ExerciseSetsCard` (plan exercises) and `_AdHocExerciseCard` (ad-hoc exercises) check for PRs in their `_completeSet()` methods:

```dart
// Check for records (only for non-warmup, non-cardio sets)
final setData = sets[index];
if (!setData.isWarmup && setData.weight > 0 && setData.reps > 0) {
  final achievements = await checkForRecords(
    exerciseName: exerciseName,
    weight: setData.weight,
    reps: setData.reps.toDouble(),
    unit: unit,
    excludeSetId: sets[index].savedSetId,
  );

  if (achievements.isNotEmpty) {
    // Store record types on the set for badge display
    setState(() {
      sets[index].records = achievements.map((a) => a.type).toSet();
    });

    // Show celebration notification
    if (mounted) {
      showRecordNotification(
        context,
        achievements: achievements,
        exerciseName: exerciseName,
      );
    }
  }
}
```

**5. Record Queries**:

Other utility functions in `records_service.dart`:

- `getSetRecords()`: Check if a specific set holds any records
- `getWorkoutRecords()`: Get all record-holding sets in a workout
- `workoutHasRecords()`: Boolean check if workout contains any PRs
- `getWorkoutRecordCount()`: Count of record-breaking sets in a workout
- `getBatchWorkoutRecordCounts()`: Efficient batch query for multiple workouts

All queries exclude hidden sets (`hidden = 0`) and use SQL MAX aggregations for performance.

### Brzycki Formula Implementation

The 1RM calculation handles both standard weights and bodyweight assistance:

```dart
double calculate1RM(double weight, double reps) {
  if (reps <= 0) return 0;
  if (reps == 1) return weight;
  if (weight >= 0) {
    return weight / (1.0278 - 0.0278 * reps);  // Standard weights
  } else {
    return weight * (1.0278 - 0.0278 * reps);  // Bodyweight assistance
  }
}
```

### Important Notes

- PRs are checked **only** for non-warmup, non-cardio sets with weight > 0 and reps > 0
- Records are tracked per exercise name (case-sensitive)
- The `excludeSetId` parameter prevents comparing a set against itself when editing
- Multiple records can be broken in a single set (e.g., both best weight and best 1RM)
- Record badges are stored in the set's local state for immediate UI updates
- The notification dialog uses `useRootNavigator: true` to appear above overlays

## 5/3/1 Calculator Feature

### Overview

The 5/3/1 calculator (`lib/widgets/five_three_one_calculator.dart`) helps users calculate weights for Jim Wendler's 5/3/1 powerlifting program. It appears as a calculator icon next to exercise notes in the workout execution screen.

### How It Works

**1. Training Max (TM) Storage:**
- Training maxes are stored in the Settings table for 4 main lifts:
  - Squat (`fivethreeoneSquatTm`)
  - Bench Press (`fivethreeoneBenchTm`)
  - Deadlift (`fivethreeoneDeadliftTm`)
  - Overhead Press (`fivethreeonePressTm`)
- Current week (1, 2, or 3) is stored in `fivethreeoneWeek`

**2. Exercise Detection:**
The calculator automatically detects which lift based on exercise name:
```dart
static const Map<String, String> exerciseMapping = {
  'Squat': 'squat',
  'Bench Press': 'bench',
  'Deadlift': 'deadlift',
  'Overhead Press': 'press',
  'Press': 'press', // Alternative name
};
```

**3. Week Calculation:**
- **Week 1**: 65%, 75%, 85% of TM for 5+, 5+, 5+ reps
- **Week 2**: 70%, 80%, 90% of TM for 3+, 3+, 3+ reps
- **Week 3**: 75%, 85%, 95% of TM for 5+, 3+, 1+ reps

**4. UI Features:**
- Week selector (SegmentedButton for weeks 1, 2, 3)
- Training max input field
- Calculated percentages displayed as tappable chips
- Tapping a weight chip auto-fills it into the current exercise set
- Auto-saves TM to settings when changed
- Shows warmup sets (40%, 50%, 60%) below main sets

**5. Integration:**
- Appears in `ExerciseSetsCard` when exercise notes are present
- Uses `useRootNavigator: true` to appear above active workout bar
- Automatically loads saved TM and current week from settings

### Key Files

| File | Purpose |
|------|---------|
| `lib/widgets/five_three_one_calculator.dart` | Calculator dialog implementation |
| `lib/plan/exercise_sets_card.dart` | Integrates calculator icon into exercise cards |

## Drop Sets Feature

### Overview

Drop sets are a training technique where you perform a set to failure, then immediately reduce the weight and continue. The app visually distinguishes drop sets from regular working sets.

### Implementation

**1. Database Field:**
- `GymSets.dropSet` (bool, default false) marks a set as a drop set

**2. Visual Indicators:**
- **Badge**: Drop sets show a downward trending arrow icon (🔽) instead of set number
- **Background**: Uses `secondaryContainer` color to differentiate from regular sets
- **Sorting**: Drop sets are grouped with their parent working sets in history

**3. Display in Workout Detail:**
```dart
if (set.dropSet) {
  dropSetNumber++;
  return _buildSetTile(set, dropSetNumber, isDropSet: true, records: setRecords);
}
```

**4. Usage:**
- Drop sets follow immediately after a working set
- Numbered independently (Drop 1, Drop 2, etc.)
- Shown in workout history with distinct styling

## Bodypart Tags & Exercise Categorization

### Overview

Exercises can be categorized by muscle group/bodypart, displayed as compact colored tags throughout the app.

### Implementation

**1. Database Field:**
- `GymSets.category` (nullable text) stores the bodypart/muscle group name
- Examples: "Chest", "Back", "Legs", "Shoulders", "Arms", "Core"

**2. BodypartTag Widget** (`lib/widgets/bodypart_tag.dart`):
```dart
BodypartTag(
  bodypart: category,
  fontSize: 10, // Optional, defaults to 10
)
```

**3. Visual Styling:**
- Background: `tertiaryContainer` with 60% opacity
- Text: `onTertiaryContainer` color
- Compact: 6px horizontal padding, 2px vertical padding
- Rounded corners: 4px border radius

**4. Usage Locations:**
- Exercise tiles in workout execution (`ExerciseSetsCard`)
- Workout detail page (next to exercise names)
- Exercise lists and search results
- Graph pages showing exercise history

**5. Category Management:**
- Categories are stored per exercise across all sets with that name
- `getCategories()` function retrieves all unique categories from database
- Category can be set when adding/editing exercises

## Exercise Type & Brand Name

### Overview

Exercises can be tagged with equipment type and specific machine brands for better tracking and organization.

### Database Fields

**1. Exercise Type** (`GymSets.exerciseType`):
- Values: "free weight", "machine", "cable", "bodyweight", etc.
- Helps users filter and analyze exercises by equipment type
- Useful for program design and gym availability

**2. Brand Name** (`GymSets.brandName`):
- Stores machine manufacturer/brand (e.g., "Hammer Strength", "Life Fitness", "Nautilus")
- Displayed as a badge next to exercise name in workout detail
- Helps differentiate between different machines with same exercise name

**3. Visual Display:**
Brand names appear as small badges with:
- Background: `secondaryContainer` with 70% opacity
- Text: `onSecondaryContainer` color
- Small font (10pt), medium weight
- Appears next to bodypart tags in exercise headers

**4. Use Cases:**
- Tracking which specific machines were used
- Comparing performance on different equipment
- Gym-specific workout logging
- Import/export with machine-specific data (e.g., from Hevy)

### Example Display

```
Chest Press [Chest] [Hammer Strength]
  Set 1: 10 x 135 lb
  Set 2: 8 x 155 lb
```

Where:
- `[Chest]` = BodypartTag (category)
- `[Hammer Strength]` = Brand name badge

## Custom Color Theming

### Overview

The app supports full Material Design 3 color customization through an artistic color picker, allowing users to personalize their app's entire color scheme. Users can choose between system dynamic colors (Android 12+) or a custom color seed.

### How It Works

**1. Color System Options:**
- **System Colors**: Uses Android's dynamic color system (extracted from wallpaper on supported devices)
- **Custom Color**: User-selected color seed generates a complete Material Design 3 ColorScheme

**2. Database Storage:**
- `Settings.systemColors` (bool) - toggles between system and custom colors
- `Settings.customColorSeed` (int) - stores custom color as integer (default: 0xFF673AB7 - deep purple)

**3. Theme Generation** (`lib/main.dart`):
```dart
final customColor = context.select<SettingsState, int>(
  (settings) => settings.value.customColorSeed,
);

final light = ColorScheme.fromSeed(seedColor: Color(customColor));
final dark = ColorScheme.fromSeed(
  seedColor: Color(customColor),
  brightness: Brightness.dark,
);

return MaterialApp(
  theme: ThemeData(
    colorScheme: colors ? lightDynamic : light,
    // ...
  ),
  darkTheme: ThemeData(
    colorScheme: colors ? darkDynamic : dark,
    // ...
  ),
);
```

**4. Artistic Color Picker** (`lib/widgets/artistic_color_picker.dart`):

The color picker dialog provides three selection methods:

- **Palettes Tab**: 6 curated mood-based collections
  - Energetic (reds, oranges, yellows)
  - Calm (blues, cyans, teals)
  - Natural (greens, browns)
  - Elegant (purples, indigos)
  - Bold (pinks, reds, purples)
  - Pastel (soft pastels)

- **Custom Tab**: Precise HSL control
  - Hue slider (0-360°) with rainbow gradient preview
  - Saturation slider (0-100%) with dynamic gradient
  - Lightness slider (0-100%) with dynamic gradient
  - Live hex code display (selectable)
  - RGB values display

- **Grid Tab**: 360+ color variations
  - Generates colors across entire hue spectrum
  - Multiple saturation/lightness variations per hue
  - Visual browsing for color discovery

**5. Live Preview:**
- Shows Primary, Secondary, Tertiary, and Surface colors
- Updates in real-time as user adjusts sliders or selects colors
- Demonstrates how color will look in actual app

**6. Additional Features:**
- Random color generator (shuffle button)
- Disabled state when system colors are active
- Visual indicator (color circle) showing current custom color in settings

### Implementation Details

**Files:**
- `lib/widgets/artistic_color_picker.dart` - Color picker dialog (565 lines)
- `lib/settings/appearance_settings.dart` - Settings UI integration
- `lib/main.dart` - Theme generation and color application
- `lib/database/settings.dart` - Database schema

**Color Model:**
- Uses HSL (Hue, Saturation, Lightness) for intuitive color manipulation
- Stores as RGB integer for database compatibility
- Converts to Material Design 3 ColorScheme via `ColorScheme.fromSeed()`

**UX Patterns:**
- Dialog appears above all overlays using `useRootNavigator: true`
- Returns selected color on "Apply", null on "Cancel"
- Auto-saves to database when user applies color
- Immediate theme update via Provider state management

**Visual Styling:**
- Color chips: 56x56px with rounded corners and shadows
- Selected state: Primary color border with checkmark icon
- Sliders: Custom track height (12px) with dynamic gradients
- Dialog: Max 500px width, 700px height with responsive layout

### Key Code Paths

**Opening the color picker** (`lib/settings/appearance_settings.dart`):
```dart
final color = await showDialog<Color>(
  context: context,
  builder: (context) => ArtisticColorPicker(
    initialColor: Color(settings.value.customColorSeed),
    onColorChanged: (color) {},
  ),
);
if (color != null) {
  await db.settings.update().write(
    SettingsCompanion(
      customColorSeed: Value(color.value),
    ),
  );
}
```

**HSL to Color conversion** (`lib/widgets/artistic_color_picker.dart`):
```dart
void _updateFromHSL() {
  final color = HSLColor.fromAHSL(1.0, _hue, _saturation, _lightness).toColor();
  _updateColor(color);
}
```

**Dynamic gradient generation:**
```dart
// Saturation gradient based on current hue and lightness
Widget _buildSaturationGradientBar() {
  final baseColor = HSLColor.fromAHSL(1.0, _hue, 0, _lightness).toColor();
  final saturatedColor = HSLColor.fromAHSL(1.0, _hue, 1, _lightness).toColor();

  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [baseColor, saturatedColor]),
    ),
  );
}
```

### Important Notes

- Color changes apply immediately to entire app via reactive Provider state
- Material Design 3 automatically generates harmonious color palettes from the seed
- Custom colors are disabled when "System color scheme" is enabled
- The picker supports both light and dark theme modes
- Default color (deep purple #673AB7) provides good contrast in both themes

## Development Commands

```bash
# Run database migrations after schema changes (recommended)
./scripts/migrate.sh

# Generate Drift database code manually (if not using migrate.sh)
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

## UI/UX Implementation Patterns

### Modal Dialogs Over Overlays

When showing dialogs/bottom sheets that need to appear above other overlays (like the ActiveWorkoutBar), use `useRootNavigator: true`:

```dart
// Bottom sheet that appears above all overlays
showModalBottomSheet(
  context: parentContext,
  useRootNavigator: true,  // Critical for overlay visibility
  builder: (context) => ...
);

// Dialog that appears above all overlays
showDialog(
  context: parentContext,
  useRootNavigator: true,  // Critical for overlay visibility
  builder: (context) => AlertDialog(...)
);
```

### TextEditingController in Dialogs

**DO NOT** manually dispose TextEditingController in dialog callbacks. Flutter manages the dialog lifecycle automatically:

```dart
// CORRECT - let Flutter manage lifecycle
Future<void> _showNotesDialog(BuildContext parentContext) async {
  final controller = TextEditingController(text: existingNotes);
  final result = await showDialog<String>(
    context: parentContext,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      content: TextField(controller: controller),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text('Save'),
        ),
      ],
    ),
  );
  // DO NOT call controller.dispose() here - causes "_dependents.isEmpty" error
  if (result != null) onNotesChanged(result);
}
```

### Exercise Reordering

Exercise reordering uses a dedicated mode toggle in the AppBar rather than always-visible drag handles:
- `_isReorderMode` state variable toggles between normal and reorder views
- `ReorderableListView` used only in reorder mode
- Pass `sequence: index` when saving sets to preserve order in history

### Freeform Workouts

Freeform workouts use time-based titles:
```dart
String _getTimeBasedWorkoutTitle() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Morning Workout';
  if (hour < 14) return 'Noon Workout';
  if (hour < 18) return 'Afternoon Workout';
  return 'Evening Workout';
}
```

Create with a temporary Plan object (id: -1) that has no exercises.

## Migration Notes

When adding new columns or tables, you'll need to manually update both the schema JSON and `database.steps.dart`:

**a. Create the new schema JSON file** in `drift_schemas/db/`:
Copy the previous version's JSON (e.g., `drift_schema_v53.json` → `drift_schema_v54.json`) and add the new column to the appropriate table's columns array:
```json
{
  "name": "warmup",
  "getter_name": "warmup",
  "moor_type": "bool",
  "nullable": false,
  "customConstraints": null,
  "defaultConstraints": "CHECK (\"warmup\" IN (0, 1))",
  "dialectAwareDefaultConstraints": {"sqlite": "CHECK (\"warmup\" IN (0, 1))"},
  "default_dart": "const CustomExpression('0')",
  "default_client_dart": null,
  "dsl_features": []
}
```

**b. Add new column definition** in `database.steps.dart`:
```dart
i1.GeneratedColumn<bool> _column_89(String aliasedName) =>
    i1.GeneratedColumn<bool>('warmup', aliasedName, false,
        type: i1.DriftSqlType.bool,
        defaultValue: const CustomExpression('0'),
        defaultConstraints: i1.GeneratedColumn.constraintIsAlways(
            'CHECK ("warmup" IN (0, 1))'));
```

**c. Add new Shape class** (copy previous Shape, add new column getter):
```dart
class Shape39 extends i0.VersionedTable {
  Shape39({required super.source, required super.alias}) : super.aliased();
  // Copy all getters from Shape38, then add:
  i1.GeneratedColumn<bool> get warmup =>
      columnsByName['warmup']! as i1.GeneratedColumn<bool>;
}
```

**d. Add Schema class** (copy previous Schema, use new Shape for modified table, add new column to columns list):
```dart
final class Schema54 extends i0.VersionedSchema {
  Schema54({required super.database}) : super(version: 54);
  @override
  late final List<i1.DatabaseSchemaEntity> entities = [
    plans, gymSets, settings, planExercises, metadata, workouts, notes,
  ];
  // Use new Shape for modified table:
  late final ShapeXX gymSets = ShapeXX(
      source: i0.VersionedTable(
        entityName: 'gym_sets',
        // ... copy from previous Schema, add new column to columns list
        columns: [..., _column_XX],
      ),
      alias: null);
  // Copy other tables from previous Schema unchanged
}
```

**e. Update `migrationSteps()` function:**
- Add parameter: `required Future<void> Function(i1.Migrator m, Schema54 schema) from53To54,`
- Add switch case:
  ```dart
  case 53:
    final schema = Schema54(database: database);
    final migrator = i1.Migrator(database, schema);
    await from53To54(migrator, schema);
    return 54;
  ```

**f. Update `stepByStep()` function:**
- Add parameter: `required Future<void> Function(i1.Migrator m, Schema54 schema) from53To54,`
- Add to migrationSteps call: `from53To54: from53To54,`

**g. Run build_runner** to regenerate database.g.dart with the new column:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Type Usage in Migrations

- **In `constants.dart` `SettingsCompanion.insert()`**: required fields use plain values, optional use `Value()`
- **In migrations with `RawValuesInsertable()`**: ALL fields use `Variable()`
- **In table schema `withDefault()`**: use `const Constant(value)`

### Import Conflicts

When using both Drift and Flutter Material, hide Drift's `Column`:
```dart
import 'package:drift/drift.dart' hide Column;
```

## Common Gotchas

1. **Plan constructor**: The `Plan` class has no `exercises` field - exercises are in the separate `PlanExercises` table
2. **Popup menu context**: When showing dialogs from bottom sheets, capture the parent context before the bottom sheet opens
3. **Exercise order in history**: Use the `sequence` column in GymSets to sort, not creation time
4. **Schema JSON structure**: The JSON includes all tables and their columns - ensure column order matches the schema class
5. **Active workouts**: A workout is considered "active" when `endTime` is NULL in the Workouts table
6. **Drop sets vs warmup sets**: Both are boolean flags - a set can be marked as both, though UI typically prevents this
7. **Exercise metadata propagation**: Fields like `category`, `exerciseType`, and `brandName` are stored per set, not per exercise - update all sets for an exercise to change these globally
8. **5/3/1 calculator visibility**: Only appears for exercises matching the hardcoded exercise names in the mapping (Squat, Bench Press, Deadlift, Overhead Press)
