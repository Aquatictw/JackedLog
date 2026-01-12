# JackedLog - Claude Code Context

## CRITICAL RULES - READ FIRST

### DO NOT run any Flutter commands other than `flutter analyze`(user will test manually later)
### Always do manual migration
### If database version has been changed, and previous exported data from app can't be reimported, affirm me.

## Core Development Philosophy

### KISS (Keep It Simple, Stupid)

Simplicity should be a key goal in design. Choose straightforward solutions over complex ones whenever possible. Simple solutions are easier to understand, maintain, and debug.

### YAGNI (You Aren't Gonna Need It)

Avoid building functionality on speculation. Implement features only when they are needed, not when you anticipate they might be useful in the future.

### Design Principles

- **Open/Closed Principle**: Software entities should be open for extension but closed for modification.
- **Single Responsibility**: Each function, class, and module should have one clear purpose.
- **Fail Fast**: Check for potential errors early and raise exceptions immediately when issues occur.

## Code Search & Analysis Tools
### Primary Tool: ripgrep (rg)
Use `rg` (ripgrep) as your **PRIMARY and FIRST** tool for:
- ANY code search or pattern matching
- Finding function/class definitions
- Locating method calls or usage patterns
- Refactoring preparation
- Code structure analysis
- Fast, repository-wide searches using regex or literals

### Secondary Tool: grep
Use `grep` **ONLY** when:
- `rg` is not available
- Searching plain text, comments, or documentation
- Searching non-code files (markdown, configs, etc.)
- `rg` explicitly fails or is not applicable

**NEVER** use `grep` for searches without trying `rg` first.

## Token Efficiency

### Optimize Responses By
- **Focused Context**: Only include relevant code sections
- **Avoid Repetition**: Don't restate what I've already confirmed
- **Summarize When Asked**: Always respond in a very concise and direct manner, providing only relevant information 
- Avoid **repeated or broad search commands** that may waste tokens

### Ask Before
- **Large File Changes**: "Should I show the entire file or just the diff?"
- **Multiple Approaches**: "Would you like me to explain alternatives or just go with the best option?"
- **Deep Dives**: "Do you need detailed explanation or just the solution?"

## Prohibited Actions

❌ **Never**:
- Run Flutter commands without explicit permission
- Modify database schema without impact analysis
- Suggest complex solutions when simple ones exist
- Add dependencies without discussing alternatives
- Generate large amounts of boilerplate without asking first

✅ **Always**:
- Consider backward compatibility
- Prefer Flutter/Dart built-ins over third-party packages when reasonable
- Think about edge cases and error scenarios
- Validate assumptions before implementing


## Project Overview
JackedLog is a Flutter/Dart fitness tracking mobile app (cross-platform: Android, iOS, Linux, macOS, Windows).

### Key Technologies
- **Framework**: Flutter with Dart (SDK >= 3.2.6)
- **Database**: Drift (Dart SQLite ORM) - Version 2.28.1
- **State Management**: Provider pattern (v6.1.1)
- **UI**: Material Design 3

## Database Architecture

### Current Schema (v58)

#### Tables

1. **Workouts** (workout sessions - groups sets together)
   - `id`, `startTime`, `endTime` (nullable - null means active), `planId`, `name`, `notes`

2. **GymSets** (individual exercise sets)
   - Core: `id`, `name`, `reps`, `weight`, `unit`, `created`
   - Cardio: `cardio`, `duration`, `distance`, `incline`
   - Metadata: `restMs`, `hidden`, `planId`, `workoutId` (links to Workouts.id)
   - Organization: `sequence` (exercise position), `setOrder` (set position, nullable), `image`, `category`, `notes`
   - Training: `warmup` (bool), `dropSet` (bool), `exerciseType`, `brandName`

3. **Plans** - `id`, `days`, `sequence`, `title`

4. **PlanExercises** - `id`, `planId`, `exercise`, `enabled`, `maxSets`, `warmupSets`, `timers`, `sequence`

5. **Settings** (30+ fields)
   - Theme: `themeMode`, `systemColors`, `customColorSeed` (default: 0xFF673AB7)
   - 5/3/1: `fivethreeoneWeek`, `fivethreeoneSquatTm`, `fivethreeoneBenchTm`, `fivethreeoneDeadliftTm`, `fivethreeonePressTm`
   - Default tabs: `"HistoryPage,PlansPage,GraphsPage,NotesPage,SettingsPage"`

6. **Notes** - `id`, `title`, `content`, `created`, `updated`, `color`

7. **BodyweightEntries** - `id`, `weight`, `unit`, `date`, `notes`

8. **Metadata** (version tracking)

### Data Hierarchy
```
Workout Session → Exercises → Sets
  workoutId links sets to workout session
  sequence = exercise position (0, 1, 2...)
  setOrder = set position within exercise (0, 1, 2...), nullable
```

## Key Files

| File                                         | Purpose                                               |
| -------------------------------------------- | ----------------------------------------------------- |
| `lib/database/database.dart`                 | Drift DB definition, all migrations                   |
| `lib/database/database.steps.dart`           | **Generated** migration steps                         |
| `lib/workouts/workout_state.dart`            | WorkoutState provider - manages single active workout |
| `lib/workouts/active_workout_bar.dart`       | Floating bar showing ongoing workout                  |
| `lib/plan/start_plan_page.dart`              | Workout execution UI                                  |
| `lib/plan/exercise_sets_card.dart`           | Exercise card with sets                               |
| `lib/records/records_service.dart`           | PR detection and calculation                          |
| `lib/records/record_notification.dart`       | PR celebration UI                                     |
| `lib/graph/overview_page.dart`               | Stats, heatmap, muscle charts, bodyweight             |
| `lib/widgets/five_three_one_calculator.dart` | 5/3/1 calculator                                      |
| `lib/widgets/artistic_color_picker.dart`     | Custom color picker                                   |

## Core Features

### Workout Sessions
- **WorkoutState**: Manages single active workout (`startWorkout()`, `stopWorkout()`, `resumeWorkout()`)
- **Active workout**: `endTime` is NULL in Workouts table
- **Single workout limit**: Toast message if trying to start another workout
- **ActiveWorkoutBar**: Floating bar above navigation with workout name, elapsed time, "End" button
- **History views**: Toggle between Workouts (sessions) and Sets (legacy)
- **Multi-select deletion**: Long press → checkbox mode → batch delete workouts + sets

### Personal Records (PR)
Tracks 3 types per exercise: Best 1RM (Brzycki formula), Best Volume (weight × reps), Best Weight
- Auto-detects PRs on set completion (non-warmup, non-cardio only)
- Celebration notification with confetti animation
- Record badges on sets in workout history
- Uses `.clamp(0.0, 1.0)` for opacity (Curves.easeOutBack overshoots 1.0)

### Rest Timers
- Custom per exercise: `GymSet.restMs` (nullable)
- Global default: `Settings.timerDuration`
- Timer starts in `_completeSet()` after marking set as not hidden
- Quick access timer dialog: 30s, 1m, 2m, 3m, 5m, 10m presets

### Exercise Data Loading
Loads last set for defaults (weight, reps, brandName, exerciseType, restMs) → loads existing sets from current workout by `workoutId` and `sequence`

### Bodyweight Tracking
- Log via FloatingActionButton in overview page
- Dialog: weight input, unit selector, date picker, optional notes
- Overview cards: Current Bodyweight, Bodyweight Trend (% change over period)
- Respects period selector (7D, 1M, 3M, 6M, 1Y, All)

### 5/3/1 Calculator
- Appears when exercise name matches: Squat, Bench Press, Deadlift, Overhead Press
- Week selector (1, 2, 3), training max input, calculated percentages as tappable chips
- Auto-fills weight into current set, auto-saves TM to settings
- Uses `useRootNavigator: true` to appear above active workout bar

### Custom Color Theming
- System colors (Android 12+ dynamic colors) or custom seed color
- Color picker: 6 palette collections, HSL sliders, 360+ color grid
- Material Design 3 generates full ColorScheme from seed
- Uses `useRootNavigator: true` for dialog

### Workout Overview
- Period selector: 7D, 1M, 3M, 6M, 1Y, All
- Stats cards: Workouts, Volume, Streak, Top Muscle, Bodyweight, Bodyweight Trend
- GitHub-style heatmap: Monday-Sunday weeks, clickable days
- Muscle charts: Volume (weight × reps) and Set Count (top 10)

## UI/UX Patterns

### Navigation
The app uses a **Segmented Pill Navigation Bar** (as of 2026-01-11):
- Single unified pill container with sliding background indicator
- Morphing navigation icons using Rive animations (fallback to Material icons)
- 5 tabs: History, Plans, Graphs, Notes, Settings
- Smooth 300ms transitions with easeInOutCubic curve
- Long-press to hide tabs (stored in Settings.tabs)
- Swipe gesture support (controlled by Settings.scrollableTabs)
- Integrates with ActiveWorkoutBar and RestTimerBar overlays

**Implementation:**
- `lib/widgets/segmented_pill_nav.dart` - Main navigation widget
- `lib/widgets/morphing_nav_icon.dart` - Rive animation wrapper
- `assets/animations/` - Navigation icon animations (.riv files)
- Configured in `lib/home_page.dart` with TabController

**Previous Implementation:** `lib/bottom_nav.dart` (deprecated, individual pill buttons)

### Modal Dialogs Over Overlays
Use `useRootNavigator: true` for dialogs/bottom sheets that need to appear above ActiveWorkoutBar:
```dart
showModalBottomSheet(
  context: context,
  useRootNavigator: true,
  builder: (context) => ...
);
```

### TextEditingController in Dialogs
DO NOT manually dispose controllers in dialog callbacks - Flutter manages lifecycle automatically.

### Exercise Reordering
- Toggle mode via AppBar button
- `ReorderableListView` only in reorder mode
- Save with `sequence: index` to preserve order

### Freeform Workouts
Time-based titles: Morning/Noon/Afternoon/Evening Workout
Create with temporary Plan object (id: -1, no exercises)

## Migration Notes

**Manual steps for schema changes:**
1. Create new `drift_schema_vN.json` (copy previous, add columns)
2. Add column definition in `database.steps.dart`: `_column_XX()`
3. Add new Shape class (copy previous, add column getter)
4. Add new Schema class (use new Shape for modified table)
5. Update `migrationSteps()` and `stepByStep()` functions
6. Run `dart run build_runner build --delete-conflicting-outputs`

**Type usage:**
- `SettingsCompanion.insert()`: required fields plain values, optional use `Value()`
- Migrations with `RawValuesInsertable()`: ALL fields use `Variable()`
- Table schema `withDefault()`: use `const Constant(value)`

**Import conflicts:**
```dart
import 'package:drift/drift.dart' hide Column;
```

## Common Gotchas

1. **Plan class**: No `exercises` field - use separate PlanExercises table
2. **Set ordering**: Order by `sequence` (exercise), then `setOrder` with COALESCE fallback: `COALESCE(set_order, CAST((julianday(created) - 2440587.5) * 86400000 AS INTEGER))`
3. **Active workouts**: `endTime` is NULL
4. **Drop sets & warmup sets**: Both are boolean flags
5. **Exercise metadata**: `category`, `exerciseType`, `brandName` stored per set - update all sets for an exercise to change globally
6. **Popup menu context**: Capture parent context before opening bottom sheets
7. **5/3/1 calculator**: Only appears for hardcoded exercise names

## Export/Import Backward Compatibility

**v57→v58**: Added `setOrder` column to gym_sets.csv. Import auto-detects by checking header for `setorder`.
**v54→v55**: Removed `bodyWeight` column. Import auto-detects by checking header for `bodyweight`.
