# Testing Patterns

**Analysis Date:** 2026-01-18

## Test Framework

**Runner:**
- flutter_test (SDK package)
- Config: No dedicated test config file (uses default Flutter test settings)

**Assertion Library:**
- Built-in `expect()` from `package:flutter_test/flutter_test.dart`

**Mocking:**
- mockito version 5.4.4
- build_runner version 2.6.0 for mock generation

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --watch            # Watch mode (not commonly used in Flutter)
flutter test --coverage         # Generate coverage report
flutter test test/specific_test.dart  # Run specific test file
```

## Test File Organization

**Location:**
- Co-located with source in parallel `test/` directory
- Mirror source directory structure: `lib/workouts/workout_state.dart` → `test/workouts/workout_state_test.dart`

**Naming:**
- Test files: `*_test.dart` suffix (e.g., `database_test.dart`, `pr_detection_test.dart`)
- Helper files: `test_helpers.dart`, `test_helpers.mocks.dart` (generated)

**Structure:**
```
test/
├── database/
│   ├── database_test.dart
│   ├── database_export_test.dart
│   ├── database_import_test.dart
│   └── database_migration_test.dart
├── records/
│   ├── pr_calculation_test.dart
│   └── pr_detection_test.dart
├── spotify/
│   ├── spotify_state_test.dart
│   └── spotify_token_test.dart
├── workouts/
│   ├── workout_state_test.dart
│   └── workout_state_integration_test.dart
├── test_helpers.dart
└── test_helpers.mocks.dart
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  group('Set ordering tests', () {
    test('orders sets by sequence first, then setOrder', () async {
      // Test implementation
    });

    test('falls back to created timestamp when setOrder is null', () async {
      // Test implementation
    });
  });

  group('Active workout queries', () {
    test('finds only active workouts (endTime IS NULL)', () async {
      // Test implementation
    });
  });
}
```

**Patterns:**
- Use `group()` to organize related tests
- Use descriptive test names that explain expected behavior
- Async tests use `async` keyword and `await` for database operations
- Tests are self-contained and isolated

**Setup/Teardown:**
```dart
void main() {
  late AppDatabase db;
  late WorkoutState workoutState;
  late Plan testPlan;

  setUp(() async {
    db = await createTestDatabase();
    workoutState = WorkoutState();

    testPlan = await db.into(db.plans).insertReturning(
      PlansCompanion.insert(
        days: 'Push',
        sequence: const Value(0),
        title: const Value('Push Day'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('starts workout successfully when none active', () async {
    // Test uses db, workoutState, testPlan from setUp
  });
}
```

**Assertion patterns:**
```dart
expect(sets.length, equals(3));
expect(sets[0].name, equals('Bench Press'));
expect(sets[0].weight, equals(100.0));
expect(workout, isNotNull);
expect(workout!.endTime, isNull);
expect(best1RM, closeTo(expected, 0.01));
expect(workoutState.hasActiveWorkout, isTrue);
```

## Mocking

**Framework:** mockito with code generation

**Mock Generation:**
- Annotations in `test/test_helpers.dart`:
```dart
@GenerateMocks([SpotifyService, SpotifyWebApiService])
void main() {} // Empty: mocks generated via: dart run build_runner build
```

**Generated mocks:** `test/test_helpers.mocks.dart`

**Patterns:**
```dart
// Mock declaration in test_helpers.dart
@GenerateMocks([SpotifyService, SpotifyWebApiService])
void main() {}

// Usage in tests would be:
// final mockService = MockSpotifyService();
// when(mockService.getPlayerState()).thenAnswer((_) async => playerState);
```

**What to Mock:**
- External services: `SpotifyService`, `SpotifyWebApiService`
- Platform channels (Android/iOS native code)
- Network requests

**What NOT to Mock:**
- Database queries (use in-memory database instead)
- State classes (test real implementations)
- Data models/entities

## Fixtures and Factories

**Test Data Factories:**
Located in `test/test_helpers.dart`:

```dart
/// Create test GymSet with sensible defaults
GymSetsCompanion createTestSet({
  int? workoutId,
  String name = 'Test Exercise',
  double weight = 100.0,
  double reps = 10.0,
  int sequence = 0,
  int? setOrder,
  bool warmup = false,
  bool dropSet = false,
  bool cardio = false,
  String? notes,
  String unit = 'kg',
  // ... more optional parameters
}) {
  return GymSetsCompanion.insert(
    name: name,
    reps: reps,
    weight: weight,
    unit: unit,
    created: DateTime.now(),
    // ... field mappings
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
    planId: Value(planId),
    name: Value(name),
    notes: Value(notes),
    selfieImagePath: Value(selfieImagePath),
  );
}
```

**CSV Fixtures:**
For backward compatibility testing:
```dart
const csvV59Format = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,planId,workoutId,sequence,setOrder,image,category,notes,warmup,dropSet,exerciseType,brandName
1,Bench Press,10,225.0,kg,2026-01-13 10:00:00,0,,,,120000,0,,,0,0,,,Test notes,0,0,,''';

const csvV58Format = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,planId,workoutId,sequence,setorder,image,category,notes,warmup,dropSet,exerciseType,brandName
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
- Factory functions: `test/test_helpers.dart`
- CSV fixtures: `test/test_helpers.dart`
- No separate fixtures directory

## Coverage

**Requirements:** None enforced (no minimum coverage target)

**View Coverage:**
```bash
flutter test --coverage
# Coverage report generated in coverage/lcov.info
```

**Current Coverage Areas:**
- Database queries and migrations: Comprehensive coverage in `test/database/`
- State management: Tested in `test/workouts/`, `test/spotify/`
- Business logic (PR calculations): Tested in `test/records/`
- Data import/export: Tested in `test/database/database_import_test.dart`

## Test Types

**Unit Tests:**
- Scope: Individual functions and methods
- Approach: Test pure logic without dependencies
- Examples:
  - `test/records/pr_calculation_test.dart` - Tests `calculate1RM()` function
  - Formula calculations and utility functions

**Integration Tests:**
- Scope: Multiple components working together
- Approach: Use real database (in-memory), real state classes
- Examples:
  - `test/database/database_test.dart` - Database queries with actual Drift ORM
  - `test/workouts/workout_state_integration_test.dart` - State + database interactions
  - `test/records/pr_detection_test.dart` - PR detection with database queries

**Widget Tests:**
- Framework: flutter_test provides widget testing
- Current state: No widget tests present (backend/logic focused testing)

**E2E Tests:**
- Framework: integration_test (included in dev_dependencies)
- Current state: Package included but no E2E tests implemented yet

## Common Patterns

**In-Memory Database:**
```dart
/// Create in-memory database for testing
Future<AppDatabase> createTestDatabase() async {
  return AppDatabase(NativeDatabase.memory());
}

// Usage in tests:
setUp(() async {
  db = await createTestDatabase();
});

tearDown(() async {
  await db.close();
});
```

**Database State Setup:**
```dart
test('detects new volume PR correctly', () async {
  // Insert existing sets for Bench Press
  final workoutId = await testDb.workouts.insertOne(createTestWorkout());

  // Existing best: 100kg x 10 = 1000 volume
  await testDb.gymSets.insertOne(
    createTestSet(
      workoutId: workoutId,
      name: 'Bench Press',
    ),
  );

  // Test new PR detection
  final achievements = await checkForRecords(
    exerciseName: 'Bench Press',
    weight: 80,
    reps: 15,
    unit: 'kg',
    excludeSetId: null,
  );

  expect(achievements.length, 1);
});
```

**Async Testing:**
```dart
test('loads active workout on initialization', () async {
  // Create active workout in database
  final workout = await db.into(db.workouts).insertReturning(
    createTestWorkout(endTime: null),
  );

  // Create state (triggers async load)
  final state = WorkoutState();

  // Wait for async initialization
  await Future.delayed(Duration.zero);

  expect(state.hasActiveWorkout, isTrue);
  expect(state.activeWorkout!.id, equals(workout.id));
});
```

**Error Testing:**
```dart
test('handles stopping when no workout active', () async {
  expect(workoutState.hasActiveWorkout, isFalse);

  // Should not throw, just return silently
  await workoutState.stopWorkout();

  expect(workoutState.hasActiveWorkout, isFalse);
});
```

**Testing Null Values:**
```dart
test('returns null when no active workouts exist', () async {
  final db = await createTestDatabase();

  // Create only completed workouts
  await db.workouts.insertOne(
    createTestWorkout(
      name: 'Completed Workout',
      endTime: DateTime.now(),
    ),
  );

  final workout = await (db.workouts.select()
    ..where((w) => w.endTime.isNull()))
    .getSingleOrNull();

  expect(workout, isNull);

  await db.close();
});
```

**Complex Query Testing:**
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
  // ... more inserts

  // Query with complex ordering
  final sets = await (db.gymSets.select()
    ..where((s) => s.workoutId.equals(workoutId))
    ..orderBy([
      (s) => OrderingTerm(expression: s.sequence),
      (s) => OrderingTerm(
        expression: const CustomExpression<int>(
          'COALESCE(set_order, CAST((julianday(created) - 2440587.5) * 86400000 AS INTEGER))',
        ),
      ),
    ]))
    .get();

  // Verify complex ordering
  expect(sets[0].sequence, equals(0));
  expect(sets[0].setOrder, equals(0));
});
```

**Global State Override:**
```dart
setUp(() async {
  testDb = await createTestDatabase();
  // Override the global db instance for testing
  app.db = testDb;
});
```

## Test Documentation

**Inline Comments in Tests:**
Tests include extensive comments explaining:
- What behavior is being tested
- Why certain edge cases matter
- How the production code should handle scenarios

**Example from `test/spotify/spotify_state_test.dart`:**
```dart
test('polling preserves state on API error', () async {
  // According to spotify_state.dart lines 209-217:
  // When getPlayerState() throws in _pollPlayerState():
  // 1. Connection status changes to error (if was connected)
  // 2. Error message is set to 'Connection lost'
  // 3. Existing state is NOT reset (preserved)
  // 4. Error is logged to console
  // 5. notifyListeners() called

  // Expected behavior documented:
  // try {
  //   final playerState = await _service.getPlayerState();
  //   ...
  // } catch (e) {
  //   if (_connectionStatus == ConnectionStatus.connected) {
  //     _connectionStatus = ConnectionStatus.error;
  //     _errorMessage = 'Connection lost';
  //     notifyListeners();
  //   }
  // }

  expect(state.connectionStatus, ConnectionStatus.disconnected);
});
```

## Test Naming Conventions

**Test Names:**
- Use descriptive names that explain the behavior: `'detects new volume PR correctly'`
- Start with action verb: `'finds only active workouts'`, `'prevents starting workout when one already active'`
- Include the condition being tested: `'when no workout active'`, `'when setOrder is null'`

**Group Names:**
- Describe the feature area: `'Set ordering tests'`, `'Active workout queries'`, `'PR detection integration tests'`
- Use noun phrases: `'WorkoutState state transitions'`, `'Cascade deletion'`

---

*Testing analysis: 2026-01-18*
