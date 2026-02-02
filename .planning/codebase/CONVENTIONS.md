# Coding Conventions

**Analysis Date:** 2026-02-02

## Naming Patterns

**Files:**
- snake_case for all Dart files: `query_helpers.dart`, `auto_backup_service.dart`, `workout_state.dart`
- Test files follow pattern: `{module}_{type}_test.dart` (e.g., `database_test.dart`, `pr_calculation_test.dart`, `spotify_state_test.dart`)
- Widget files often prefixed with descriptive names or feature area: `animated_fab.dart`, `app_search.dart`, `bottom_nav.dart`

**Classes/Types:**
- PascalCase for all classes: `WorkoutState`, `AutoBackupService`, `QueryHelpers`, `RecordAchievement`, `AnimatedFab`
- Private classes use underscore prefix: `_AppState`, `_AnimatedFabState`, `_prCache`
- Enum types in PascalCase: `RecordType`, `ConnectionStatus`

**Functions:**
- camelCase for all functions: `performAutoBackup()`, `checkForRecords()`, `createTestDatabase()`, `loadExerciseData()`
- Private functions use underscore prefix: `_createBackup()`, `_getBackupFileName()`, `_pollPlayerState()`
- Static helper functions commonly start with action verb: `calculate1RM()`, `calculateVolume()`, `clearPRCache()`

**Variables & Properties:**
- camelCase for local variables: `previousSets`, `existingSets`, `workoutState`, `testPlan`
- Private fields use underscore prefix: `_activeWorkout`, `_activePlan`, `_showSplash`, `_prCache`
- Final fields preferred: `final List<GymSet> previousSets`
- Boolean variables use `is`/`has`/`can` prefix: `hasActiveWorkout`, `isNotNull`, `extended`

**Constants:**
- SCREAMING_SNAKE_CASE for compile-time constants: `_cacheDuration = Duration(seconds: 30)`, `const csvV59Format = '''...'''`
- Private compile-time constants: `const _brzycki1RMExpression = CustomExpression<double>(...)`
- Constants defined at module level outside classes

**Database/Generated:**
- Database table companions: `GymSetsCompanion`, `WorkoutsCompanion`, `PlansCompanion`
- Model classes match table names in PascalCase: `GymSet`, `Workout`, `Plan`
- Generated files suffixed with `.g.dart`: `database.g.dart`, `test_helpers.mocks.dart`

## Code Style

**Formatting:**
- flutter_lints ^6.0.0 provides linting rules
- Enforces trailing commas: `require_trailing_commas: true`
- Requires return type declarations: `always_declare_return_types: true`
- Prefers const constructors: `prefer_const_constructors: true`, `prefer_const_declarations: true`
- Requires final fields: `prefer_final_fields: true`, `prefer_final_locals: true`
- Single quotes preferred: `prefer_single_quotes: true`
- Requires proper null safety: No strict-casts, strict-inference, or strict-raw-types

**Linting:**
- Configuration: `analysis_options.yaml`
- Treats several categories as errors:
  - `unused_local_variable: error`
  - `unused_element: error`
  - `unused_field: error`
  - `dead_code: error`
  - `unnecessary_non_null_assertion: error`
- Most other rules enabled as warnings
- `avoid_print: false` - print() statements allowed (commonly used for debug logging with emojis like 🔵, 🟢, 🔴, ⚠️)

**Spacing & Structure:**
- Classes have blank line after class declaration before fields
- Constructor parameters on separate lines when complex
- Multi-line method chains indented consistently

## Import Organization

**Order:**
1. Dart standard library: `import 'dart:io';`, `import 'dart:async';`
2. Flutter packages: `import 'package:flutter/material.dart';`
3. Third-party pub.dev packages: `import 'package:drift/drift.dart';`, `import 'package:provider/provider.dart';`
4. Relative imports: `import '../database/database.dart';`, `import '../main.dart';`
5. Exports (when used): None detected in codebase

**Path Aliases:**
- `package:jackedlog/` prefix used in test files: `import 'package:jackedlog/database/database.dart';`
- Test imports use relative paths for helpers: `import '../test_helpers.dart';`

**Hide Directives:**
- Used to avoid name conflicts: `hide isNull, isNotNull` when importing drift to use test framework matchers instead

## Error Handling

**Patterns:**
- Try/catch with specific exception types:
  ```dart
  try {
    await platform.invokeMethod('performBackup', {...});
  } on PlatformException catch (e) {
    print('🔴 Platform exception: ${e.code} - ${e.message}');
    throw Exception('Backup failed: ${e.message}');
  } catch (e) {
    print('🔴 Unexpected error: $e');
    rethrow;
  }
  ```
- Silent failures with early returns for non-critical operations:
  ```dart
  if (settings == null) {
    print('⚠️ Auto-backup skipped: Settings not found');
    return false;
  }
  ```
- Async error handling with `.catchError()`:
  ```dart
  _loadActiveWorkout().catchError((error) {
    print('⚠️ Error loading active workout: $error');
  });
  ```
- State preservation on errors (maintain existing state rather than clearing):
  ```dart
  catch (e) {
    if (_connectionStatus == ConnectionStatus.connected) {
      _connectionStatus = ConnectionStatus.error;
      _errorMessage = 'Connection lost';
    }
    // Keep existing state, don't clear it
  }
  ```

## Logging

**Framework:** console via `print()` statements (not a dedicated logger)

**Patterns:**
- Emoji prefixes for log levels:
  - 🔵 Info: `print('🔵 Starting backup to: $backupPath')`
  - 🟢 Success: `print('🟢 Native backup completed successfully')`
  - 🔴 Error: `print('🔴 Platform exception: ${e.code} - ${e.message}')`
  - ⚠️ Warning: `print('⚠️ Auto-backup skipped: Settings not found')`
  - 🎵 Domain-specific: `print('🎵 Web API fetch error: $e')` for Spotify
- Logs used for debugging, not for production logging infrastructure
- Print statements allowed per linting configuration
- Descriptive messages with context about what operation is being performed

## Comments

**When to Comment:**
- Doc comments (///) for public APIs and important functions
- Line comments (//) for implementation details and algorithm explanations
- Inline comments for non-obvious logic or workarounds
- Comments explaining the "why" not just the "what"

**JSDoc/TSDoc Style:**
- Used for public methods and classes: `/// Loads exercise data in a single query instead of 3+ sequential queries.`
- Parameter documentation in doc comments
- Return value documentation
- Example from query_helpers.dart:
  ```dart
  /// Loads exercise data in a single query instead of 3+ sequential queries.
  ///
  /// Returns a record containing:
  /// - previousSets: All sets from the most recent workout with this exercise
  /// - existingSets: Sets from current workout for this exercise instance
  /// - supersetInfo: Superset metadata if exercise is in a superset
  static Future<ExerciseLoadData> loadExerciseData({...})
  ```

## Function Design

**Size:** Generally keep functions focused and modular. Query helpers can be more complex (50+ lines) but database methods kept ~30-50 lines. Async operations broken into smaller helpers.

**Parameters:**
- Named parameters preferred for clarity: `loadExerciseData({required String exerciseName, required int sequence, int? workoutId})`
- `required` keyword for mandatory parameters
- Optional parameters follow required parameters
- Default values provided where sensible: `String name = 'Test Exercise'`, `double weight = 100.0`

**Return Values:**
- Always declare explicit return types: `Future<bool>`, `List<GymSet>`, `ExerciseLoadData`
- Return early for guard clauses
- Null-safe returns preferred: `Future<T?>` for optional results
- Records used for multiple returns: `final (workoutsZip, setsZip) = await _exportData(sourceDb)`

## Module Design

**Exports:**
- No barrel files detected
- Each module imports what it needs directly
- Public APIs exposed via well-named functions and classes

**Structure:**
- Service classes for business logic: `AutoBackupService`, `QueryHelpers`, `RecordAchievement`
- State classes extend `ChangeNotifier` for state management: `WorkoutState`, `SpotifyState`, `SettingsState`
- Database models generated by Drift from `.drift` files
- Separate concerns: database layer, service layer, state layer, UI layer

**Dependency Management:**
- Services access database via global `db` instance: `import '../main.dart'` provides `final rootScaffoldMessenger`, `AppDatabase db`
- State classes receive database reference or use global
- Tests inject test database via `createTestDatabase()`

---

*Convention analysis: 2026-02-02*
