# Coding Conventions

**Analysis Date:** 2026-01-18

## Naming Patterns

**Files:**
- snake_case for all Dart files: `workout_state.dart`, `settings_page.dart`, `database_test.dart`
- Test files suffix: `_test.dart` (e.g., `database_test.dart`, `pr_detection_test.dart`)
- Helper/shared code suffix: `_helpers.dart` or `_state.dart` for state management classes
- Generated files suffix: `.g.dart` (e.g., `database.g.dart`) or `.steps.dart` (e.g., `database.steps.dart`)

**Classes:**
- PascalCase for class names: `WorkoutState`, `AppDatabase`, `StrengthPage`, `RecordAchievement`
- Widget classes use descriptive names ending in widget type: `StrengthPage`, `EditSetPage`, `WorkoutDetailPage`
- State classes end in `State`: `SettingsState`, `PlanState`, `TimerState`, `WorkoutState`
- Companion classes for database inserts: `GymSetsCompanion`, `WorkoutsCompanion`, `PlansCompanion`

**Functions:**
- camelCase for function names: `startWorkout()`, `checkForRecords()`, `createTestDatabase()`
- Helper/utility functions use descriptive verbs: `calculate1RM()`, `parseDate()`, `isSameDay()`
- Async functions prefixed with action verb: `_loadActiveWorkout()`, `_fetchWebApiData()`, `updatePlans()`
- Private methods prefixed with underscore: `_loadRecords()`, `_onTabChanged()`, `_pollPlayerState()`

**Variables:**
- camelCase for local variables and parameters: `workoutId`, `exerciseName`, `bestWeight`
- Private fields prefixed with underscore: `_activeWorkout`, `_activePlan`, `_connectionStatus`
- Boolean variables use `is`, `has`, or `should` prefix: `isPaused`, `hasActiveWorkout`, `isShuffling`
- Constants use lowerCamelCase: `weekdays`, `positiveReinforcement`, `defaultSettings`

**Types:**
- Enum types use PascalCase: `RecordType`, `StrengthMetric`, `Period`, `CardioMetric`
- Enum values use camelCase: `RecordType.best1RM`, `Period.months3`, `StrengthMetric.bestWeight`
- Type aliases use PascalCase: `GymCount` (typedef for record type)

## Code Style

**Formatting:**
- Tool: Included in Flutter SDK (dart format)
- Trailing commas required on all function calls and parameter lists (enforced by `require_trailing_commas` lint rule)
- Single quotes preferred for strings (`prefer_single_quotes` lint rule)
- End of file newline required (`eol_at_end_of_file`)

**Linting:**
- Tool: `flutter_lints` package version 6.0.0
- Config file: `analysis_options.yaml` with 150+ enabled lint rules
- Strict mode disabled: `strict-casts: false`, `strict-inference: false`, `strict-raw-types: false`
- Key enforced rules:
  - `prefer_single_quotes`: Use single quotes for strings
  - `always_declare_return_types`: All functions must declare return types
  - `prefer_const_constructors`: Use const constructors where possible
  - `prefer_final_locals`: Use final for variables that aren't reassigned
  - `require_trailing_commas`: Required on multi-line function calls
  - `type_annotate_public_apis`: All public APIs must have type annotations
  - `prefer_relative_imports`: Use relative imports within the package
- Errors promoted to build failures:
  - `unused_local_variable: error`
  - `unused_element: error`
  - `unused_field: error`
  - `dead_code: error`
- Disabled rules:
  - `curly_braces_in_flow_control_structures: false` (optional braces allowed)
  - `avoid_print: false` (print statements allowed)
  - `cascade_invocations: false` (cascades not enforced)

## Import Organization

**Order:**
1. Dart SDK imports: `import 'dart:async';`, `import 'dart:io';`
2. External package imports: `import 'package:drift/drift.dart';`, `import 'package:flutter/material.dart';`
3. Local package imports: `import 'database/database.dart';`, `import '../main.dart';`, `import '../utils.dart';`

**Example from `lib/main.dart`:**
```dart
import 'package:drift/drift.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'backup/auto_backup_service.dart';
import 'constants.dart';
import 'database/database.dart';
```

**Path Aliases:**
- Not used (relative imports preferred per lint rule)
- Parent directory imports: `import '../database/database.dart';`
- Sibling imports: `import 'workout_state.dart';`

**Import Modifiers:**
- `hide` used to avoid naming conflicts: `import 'package:drift/drift.dart' hide Column;`
- `as` used for aliasing: `import 'package:drift/drift.dart' as drift;`

## Error Handling

**Patterns:**
- Try-catch with specific error handling for critical operations
- Silent failure for non-critical errors with print statements
- Async errors caught with `.catchError()` on initialization

**Example from `lib/workouts/workout_state.dart`:**
```dart
WorkoutState() {
  _loadActiveWorkout().catchError((error) {
    print('⚠️ Error loading active workout: $error');
    // Don't crash, just continue with no active workout
  });
}
```

**Example from `lib/plan/plan_state.dart`:**
```dart
PlanState() {
  updatePlans(null).catchError((error) {
    print('⚠️ Error updating plans: $error');
  });
  updatePlanCounts();
  updateDefaults().catchError((error) {
    print('⚠️ Error updating defaults: $error');
  });
}
```

**File deletion error handling:**
```dart
try {
  final file = File(_activeWorkout!.selfieImagePath!);
  if (await file.exists()) {
    await file.delete();
  }
} catch (e) {
  // Ignore file deletion errors
}
```

## Logging

**Framework:** Built-in `print()` statements (allowed by lint rules)

**Patterns:**
- Use emoji prefixes for visibility: `print('⚠️ Error loading active workout: $error');`
- Success messages: `print('✓ Default settings created successfully');`
- Warning messages: `print('⚠️ Settings table is empty, creating default settings...');`
- Debug info: `print('🎵 Web API fetch error: $e');`

**Example from `lib/main.dart`:**
```dart
if (settingOrNull == null) {
  print('⚠️ Settings table is empty, creating default settings...');
  await db.settings.insertOne(defaultSettings);
  setting = await (db.settings.select()..limit(1)).getSingle();
  print('✓ Default settings created successfully');
}
```

## Comments

**When to Comment:**
- Document complex SQL expressions
- Explain formula calculations
- Clarify non-obvious business logic
- Describe error handling behavior

**Example from `test/database/database_test.dart`:**
```dart
// Brzycki formula SQL expression for calculating estimated 1RM
// Formula: weight / (1.0278 - 0.0278 * reps) for positive weights
// Formula: weight * (1.0278 - 0.0278 * reps) for negative weights (e.g., bodyweight exercises)
const _brzycki1RMExpression = CustomExpression<double>(
  'MAX(CASE WHEN weight >= 0 THEN weight / (1.0278 - 0.0278 * reps) ELSE weight * (1.0278 - 0.0278 * reps) END)',
);
```

**JSDoc/TSDoc:**
- Not applicable (Dart uses `///` for doc comments)
- Doc comments used for public APIs and test helpers

**Example from `test/test_helpers.dart`:**
```dart
/// Create in-memory database for testing
///
/// Returns a fresh database instance that automatically cleans up after tests.
/// No manual cleanup required - in-memory databases are garbage collected.
Future<AppDatabase> createTestDatabase() async {
  return AppDatabase(NativeDatabase.memory());
}
```

## Function Design

**Size:**
- No strict limit enforced
- State classes tend to have small, focused methods (20-50 lines)
- UI widgets can be larger (100+ lines for complex build methods)

**Parameters:**
- Use named parameters for optional parameters
- Use required keyword for mandatory named parameters
- Positional parameters for simple cases (1-3 params)

**Example:**
```dart
GymSetsCompanion createTestSet({
  int? workoutId,
  String name = 'Test Exercise',
  double weight = 100.0,
  double reps = 10.0,
  int sequence = 0,
  // ... many optional named parameters
}) {
  return GymSetsCompanion.insert(/* ... */);
}
```

**Return Values:**
- Always declare return types explicitly (`always_declare_return_types` lint rule)
- Use `Future<T>` for async operations
- Use `T?` for nullable returns
- Avoid return types on setters (`avoid_return_types_on_setters`)

## Module Design

**Exports:**
- No barrel files (each file imports what it needs)
- Database table classes exported via `part` directive in `database.dart`

**Example from `lib/database/database.dart`:**
```dart
part 'database.g.dart';
```

**Barrel Files:**
- Not used (prefer explicit imports)

## State Management

**Pattern:** Provider pattern (ChangeNotifier)

**State classes location:** Feature folders with `_state.dart` suffix
- `lib/settings/settings_state.dart`
- `lib/plan/plan_state.dart`
- `lib/timer/timer_state.dart`
- `lib/workouts/workout_state.dart`
- `lib/spotify/spotify_state.dart`

**State class structure:**
```dart
class SettingsState extends ChangeNotifier {
  SettingsState(Setting setting) {
    value = setting;
    init();
  }

  late Setting value;
  StreamSubscription? subscription;

  @override
  void dispose() {
    super.dispose();
    subscription?.cancel();
  }

  Future<void> init() async {
    subscription = (db.settings.select()..limit(1))
      .watchSingle()
      .listen((event) {
        value = event;
        notifyListeners();
      });
  }
}
```

**Global state access:** Global `db` instance in `main.dart`
```dart
AppDatabase db = AppDatabase();
```

## Database Conventions

**ORM:** Drift (version 2.28.1)

**Patterns:**
- Table classes define schema: `GymSets`, `Workouts`, `Plans`, `Settings`
- Companion classes for inserts: `GymSetsCompanion`, `WorkoutsCompanion`
- Use `Value()` wrapper for optional fields in companions
- Custom SQL expressions for complex queries: `CustomExpression<T>`

**Query patterns:**
```dart
final workout = await (db.workouts.select()
  ..where((w) => w.endTime.isNull())
  ..orderBy([
    (w) => OrderingTerm(expression: w.startTime, mode: OrderingMode.desc),
  ])
  ..limit(1))
  .getSingleOrNull();
```

**Insert patterns:**
```dart
final workout = await db.into(db.workouts).insertReturning(
  WorkoutsCompanion.insert(
    startTime: DateTime.now().toLocal(),
    planId: Value(plan.id),
    name: Value(workoutName),
  ),
);
```

---

*Convention analysis: 2026-01-18*
