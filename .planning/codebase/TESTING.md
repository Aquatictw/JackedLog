# Testing Patterns

**Analysis Date:** 2026-02-02

## Test Framework

**Runner:**
- flutter_test (part of Flutter SDK)
- Test execution: `flutter test`

**Assertion Library:**
- flutter_test matchers (built-in)
- Common matchers: `expect()`, `isEmpty`, `isNotEmpty`, `isNull`, `isNotNull`, `equals()`, `closeTo()`

**Mocking:**
- mockito ^5.4.4 for code generation
- @GenerateMocks annotation for generating mocks
- Mocks generated via: `dart run build_runner build`

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --watch          # Watch mode for development
flutter test --coverage       # Generate coverage report
dart run build_runner build   # Generate mocks and other generated code
```

## Test File Organization

**Location:**
- Co-located with source code in `test/` directory parallel to `lib/`
- Directory structure mirrors source: `test/database/`, `test/workouts/`, `test/records/`, `test/spotify/`

**Naming:**
- Pattern: `{feature}_{type}_test.dart`
- Examples: `database_test.dart`, `pr_calculation_test.dart`, `workout_state_test.dart`, `spotify_state_test.dart`, `database_export_test.dart`
- Generated mock files: `test_helpers.mocks.dart` (generated from `@GenerateMocks` annotation)

**Structure:**
```
test/
├── database/
│   ├── database_test.dart          # Core database operations
│   ├── database_export_test.dart   # Export/import functionality
│   ├── database_import_test.dart   # Import validation
│   └── database_migration_test.dart # Schema migrations
├── records/
│   ├── pr_calculation_test.dart    # Personal record calculations
│   └── pr_detection_test.dart      # Record detection logic
├── workouts/
│   ├── workout_state_test.dart     # State transitions
│   └── workout_state_integration_test.dart  # Database integration
├── spotify/
│   ├── spotify_state_test.dart     # Spotify state and error handling
│   └── spotify_token_test.dart     # Token management
├── test_helpers.dart               # Shared test utilities
└── test_helpers.mocks.dart         # Generated mocks
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  group('Feature/Component under test', () {
    late AppDatabase db;
    late WorkoutState workoutState;
    late Plan testPlan;

    setUp(() async {
      // Setup executed before each test
      db = await createTestDatabase();
      workoutState = WorkoutState();
      testPlan = await db.into(db.plans).insertReturning(...);
    });

    tearDown(() async {
      // Cleanup executed after each test
      await db.close();
    });

    test('specific behavior being tested', () async {
      // Test body
    });
  });
}
```

**Patterns:**
- `group()` for logical grouping of related tests
- `setUp()` for test initialization (executes before each test)
- `tearDown()` for cleanup (executes after each test)
- `test()` for individual test cases
- Async tests use `async/await`

## Mocking

**Framework:** mockito ^5.4.4

**Generation Pattern:**
```dart
import 'package:mockito/annotations.dart';

@GenerateMocks([SpotifyService, SpotifyWebApiService])
void main() {} // Empty: mocks generated via: dart run build_runner build
```

Generated mocks available as:
- `MockSpotifyService`
- `MockSpotifyWebApiService`

**Patterns:**
```dart
// Setup mock to return value
when(mockService.getPlayerState()).thenAnswer((_) async => mockPlayerState);

// Setup mock to throw
when(mockService.getQueue()).thenThrow(Exception('API error'));

// Verify mock was called
verify(mockService.getPlayerState()).called(1);
```

**What to Mock:**
- External services: `SpotifyService`, `SpotifyWebApiService`
- Platform channels for Android/iOS integration
- Time-dependent operations (though usually avoided by using DateTime.now() in production)

**What NOT to Mock:**
- Database layer in integration tests (use real test database)
- Business logic functions (`calculate1RM()`, `calculateVolume()`)
- Core state management classes (test them directly with real dependencies)

## Fixtures and Factories

**Test Data:**
Factories defined in `test/test_helpers.dart` for creating consistent test objects:

```dart
/// Create in-memory database for testing
Future<AppDatabase> createTestDatabase() async {
  return AppDatabase(NativeDatabase.memory());
}

/// Create test GymSet with sensible defaults
GymSetsCompanion createTestSet({
  int? workoutId,
  String name = 'Test Exercise',
  double weight = 100.0,
  double reps = 10.0,
  int sequence = 0,
  // ... more optional fields with defaults
}) {
  return GymSetsCompanion.insert(
    name: name,
    reps: reps,
    weight: weight,
    unit: unit,
    created: DateTime.now(),
    // ... populate all fields
  );
}

/// Create test Workout with sensible defaults
WorkoutsCompanion createTestWorkout({
  DateTime? startTime,
  DateTime? endTime, // null = active workout
  int? planId,
  String name = 'Test Workout',
  String? notes,
  String? selfieImagePath,
}) {
  return WorkoutsCompanion.insert(
    startTime: startTime ?? DateTime.now(),
    endTime: Value(endTime),
    // ... populate fields
  );
}
```

**CSV Test Fixtures:**
Backward compatibility test data in `test/test_helpers.dart`:
```dart
const csvV59Format = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,planId,workoutId,sequence,setOrder,image,category,notes,warmup,dropSet,exerciseType,brandName
1,Bench Press,10,225.0,kg,2026-01-13 10:00:00,0,,,,120000,0,,,0,0,,,Test notes,0,0,,''';
```

**Edge Case Data:**
```dart
const unicodeExerciseName = '벤치프레스 💪';
const specialCharsNote = '''
Test "quotes" & <brackets>
with newlines''';
```

**Location:**
- `test/test_helpers.dart` - Main factory functions
- `test/database/database_export_test.dart` - Specific helpers like `createCleanTestDatabase()`

## Coverage

**Requirements:** Not enforced (no coverage threshold in configuration)

**View Coverage:**
```bash
flutter test --coverage
# Coverage report generated to coverage/lcov.info
```

## Test Types

**Unit Tests:**
- Scope: Individual functions and methods
- Example: `pr_calculation_test.dart` tests `calculate1RM()` and `calculateVolume()` functions in isolation
```dart
test('calculates 1RM correctly for 5 reps', () {
  final result = calculate1RM(225, 5);
  expect(result, closeTo(253.9, 0.1));
});
```
- Pattern: Create simple inputs, call function, assert output

**Integration Tests:**
- Scope: Multiple components working together
- Example: `workout_state_integration_test.dart` tests full workflow with database
```dart
test('full workout lifecycle persists to database correctly', () async {
  // Verify no active workouts initially
  final initialActive = await (db.workouts.select()
    ..where((w) => w.endTime.isNull())).get();
  expect(initialActive, isEmpty);

  // Start workout
  final workout = await workoutState.startWorkout(testPlan);
  expect(workout, isNotNull);

  // Add sets and verify persistence
  final set1 = await db.gymSets.insertReturning(
    createTestSet(workoutId: workout?.id, name: 'Bench Press', setOrder: 0),
  );

  // Stop workout and verify final state
});
```
- Uses real database (in-memory) and state classes
- Tests actual data persistence and relationships

**E2E Tests:**
- Not detected in codebase
- Uses `integration_test` package (listed in dev_dependencies but no tests found)

## Common Patterns

**Database Setup Pattern:**
```dart
group('Database operations', () {
  late AppDatabase db;

  setUp(() async {
    db = await createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('some database operation', () async {
    final workout = await db.workouts.insertOne(
      createTestWorkout(name: 'Test Workout'),
    );
    expect(workout.id, isNotNull);
  });
});
```

**Async Testing Pattern:**
```dart
test('async operation completes successfully', () async {
  // Await futures
  final result = await someAsyncFunction();

  // Use expect with async results
  expect(result, isNotNull);
  expect(result.value, equals(expectedValue));
});
```

**Null Safety Testing Pattern:**
```dart
test('handles null values', () async {
  final result = await db.settings.select().getSingleOrNull();

  // Test null case
  expect(result, isNull);
});

test('handles non-null values', () async {
  await db.settings.insertOne(defaultSettings);
  final result = await db.settings.select().getSingleOrNull();

  expect(result, isNotNull);
  expect(result!.automaticBackups, isTrue);
});
```

**Complex Query Testing Pattern (from database_test.dart):**
```dart
test('orders sets by sequence first, then setOrder', () async {
  final db = await createTestDatabase();
  final workoutId = await db.workouts.insertOne(
    createTestWorkout(name: 'Test Workout'),
  );

  // Insert sets with different sequences and setOrders
  await db.gymSets.insertOne(
    createTestSet(
      workoutId: workoutId,
      name: 'Bench Press',
      sequence: 0,
      setOrder: 2,
      weight: 100.0,
    ),
  );

  // ... insert more test data

  // Query with ordering
  final sets = await (db.gymSets.select()
    ..where((s) => s.workoutId.equals(workoutId))
    ..orderBy([
      (s) => OrderingTerm(expression: s.sequence),
      (s) => OrderingTerm(expression: s.setOrder),
    ])
  ).get();

  // Verify ordering
  expect(sets[0].sequence, equals(0));
  expect(sets[0].setOrder, equals(0));
  expect(sets[1].setOrder, equals(1));
});
```

**State Management Testing Pattern (from workout_state_test.dart):**
```dart
group('WorkoutState state transitions', () {
  late AppDatabase db;
  late WorkoutState workoutState;

  setUp(() async {
    db = await createTestDatabase();
    workoutState = WorkoutState();
  });

  test('starts workout successfully when none active', () async {
    expect(workoutState.hasActiveWorkout, isFalse);
    expect(workoutState.activeWorkout, isNull);

    final workout = await workoutState.startWorkout(testPlan);

    expect(workout, isNotNull);
    expect(workoutState.hasActiveWorkout, isTrue);
    expect(workoutState.activeWorkout!.id, equals(workout!.id));
  });

  test('prevents starting workout when one already active', () async {
    // Start first workout
    final firstWorkout = await workoutState.startWorkout(testPlan);
    expect(workoutState.hasActiveWorkout, isTrue);

    // Try to start second
    final secondWorkout = await workoutState.startWorkout(secondPlan);

    // Should return null
    expect(secondWorkout, isNull);
    expect(workoutState.activeWorkout!.id, equals(firstWorkout!.id));
  });
});
```

**Error Handling Testing (from spotify_state_test.dart):**
Test error handling logic through behavior documentation and state verification:
```dart
test('polling preserves state on API error', () async {
  // According to spotify_state.dart lines 209-217:
  // When getPlayerState() throws in _pollPlayerState():
  // 1. Connection status changes to error (if was connected)
  // 2. Error message is set to 'Connection lost'
  // 3. Existing state is NOT reset (preserved)
  // 4. Error is logged to console

  expect(state.connectionStatus, ConnectionStatus.disconnected);
  expect(state.errorMessage, isNull);
});
```

## Test Execution

**Run all tests:**
```bash
flutter test
```

**Run specific test file:**
```bash
flutter test test/records/pr_calculation_test.dart
```

**Run tests matching pattern:**
```bash
flutter test -k "database"
```

**Generate code (mocks, Drift models):**
```bash
dart run build_runner build
dart run build_runner watch  # Watch mode
```

---

*Testing analysis: 2026-02-02*
