import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/records/records_service.dart';

import '../test_helpers.dart';

// Brzycki formula SQL expression for calculating estimated 1RM
// Formula: weight / (1.0278 - 0.0278 * reps) for positive weights
// Formula: weight * (1.0278 - 0.0278 * reps) for negative weights (e.g., bodyweight exercises)
const _brzycki1RMExpression = CustomExpression<double>(
  'MAX(CASE WHEN weight >= 0 THEN weight / (1.0278 - 0.0278 * reps) ELSE weight * (1.0278 - 0.0278 * reps) END)',
);

void main() {
  group('Set ordering tests', () {
    test('orders sets by sequence first, then setOrder', () async {
      final db = await createTestDatabase();

      // Create a workout
      final workoutId = await db.workouts.insertOne(
        createTestWorkout(name: 'Test Workout'),
      );

      // Insert sets with different sequences and setOrders
      // Exercise 0 (Bench Press): sets 0, 1, 2
      await db.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          sequence: 0,
          setOrder: 2,
          weight: 100.0,
        ),
      );
      await db.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          sequence: 0,
          setOrder: 0,
          weight: 90.0,
        ),
      );
      await db.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          sequence: 0,
          setOrder: 1,
          weight: 95.0,
        ),
      );

      // Exercise 1 (Squat): sets 0, 1
      await db.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Squat',
          sequence: 1,
          setOrder: 1,
          weight: 150.0,
        ),
      );
      await db.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Squat',
          sequence: 1,
          setOrder: 0,
          weight: 140.0,
        ),
      );

      // Query with the complex ordering
      // COALESCE: Use setOrder if present, otherwise fall back to created timestamp (as milliseconds since epoch)
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

      // Verify ordering: sequence 0 first, then sequence 1
      // Within each sequence, setOrder ascending
      expect(sets.length, equals(5));

      // Exercise 0: sequence 0, setOrder 0, 1, 2
      expect(sets[0].sequence, equals(0));
      expect(sets[0].setOrder, equals(0));
      expect(sets[0].weight, equals(90.0));

      expect(sets[1].sequence, equals(0));
      expect(sets[1].setOrder, equals(1));
      expect(sets[1].weight, equals(95.0));

      expect(sets[2].sequence, equals(0));
      expect(sets[2].setOrder, equals(2));
      expect(sets[2].weight, equals(100.0));

      // Exercise 1: sequence 1, setOrder 0, 1
      expect(sets[3].sequence, equals(1));
      expect(sets[3].setOrder, equals(0));
      expect(sets[3].weight, equals(140.0));

      expect(sets[4].sequence, equals(1));
      expect(sets[4].setOrder, equals(1));
      expect(sets[4].weight, equals(150.0));

      await db.close();
    });

    test('falls back to created timestamp when setOrder is null', () async {
      final db = await createTestDatabase();

      final workoutId = await db.workouts.insertOne(
        createTestWorkout(name: 'Test Workout'),
      );

      // Insert sets with null setOrder, different created times
      final now = DateTime.now();

      // First set (oldest)
      await db.gymSets.insertOne(
        GymSetsCompanion.insert(
          name: 'Deadlift',
          reps: 5.0,
          weight: 200.0,
          unit: 'kg',
          created: now.subtract(const Duration(minutes: 2)),
          sequence: const Value(0),
          setOrder: const Value(null), // Explicitly null
          workoutId: Value(workoutId),
          hidden: const Value(false),
        ),
      );

      // Second set (middle)
      await db.gymSets.insertOne(
        GymSetsCompanion.insert(
          name: 'Deadlift',
          reps: 5.0,
          weight: 210.0,
          unit: 'kg',
          created: now.subtract(const Duration(minutes: 1)),
          sequence: const Value(0),
          setOrder: const Value(null),
          workoutId: Value(workoutId),
          hidden: const Value(false),
        ),
      );

      // Third set (newest)
      await db.gymSets.insertOne(
        GymSetsCompanion.insert(
          name: 'Deadlift',
          reps: 5.0,
          weight: 220.0,
          unit: 'kg',
          created: now,
          sequence: const Value(0),
          setOrder: const Value(null),
          workoutId: Value(workoutId),
          hidden: const Value(false),
        ),
      );

      // Query with COALESCE ordering
      final sets = await (db.gymSets.select()
            ..where((s) => s.workoutId.equals(workoutId))
            ..orderBy([
              (s) => OrderingTerm(
                    expression: const CustomExpression<int>(
                      'COALESCE(set_order, CAST((julianday(created) - 2440587.5) * 86400000 AS INTEGER))',
                    ),
                  ),
            ]))
          .get();

      // Should be ordered by created timestamp
      expect(sets.length, equals(3));
      expect(sets[0].weight, equals(200.0)); // Oldest
      expect(sets[1].weight, equals(210.0)); // Middle
      expect(sets[2].weight, equals(220.0)); // Newest

      await db.close();
    });
  });

  group('Active workout queries', () {
    test('finds only active workouts (endTime IS NULL)', () async {
      final db = await createTestDatabase();

      // Create completed workout (has endTime)
      await db.workouts.insertOne(
        createTestWorkout(
          name: 'Completed Workout',
          startTime: DateTime.now().subtract(const Duration(hours: 2)),
          endTime: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      // Create active workout (no endTime)
      await db.workouts.insertOne(
        createTestWorkout(
          name: 'Active Workout',
          startTime: DateTime.now(),
          endTime: null,
        ),
      );

      // Query for active workouts
      final activeWorkouts = await (db.workouts.select()
            ..where((w) => w.endTime.isNull()))
          .get();

      expect(activeWorkouts.length, equals(1));
      expect(activeWorkouts[0].name, equals('Active Workout'));
      expect(activeWorkouts[0].endTime, isNull);

      await db.close();
    });

    test('finds most recent active workout', () async {
      final db = await createTestDatabase();

      final now = DateTime.now();

      // Create multiple active workouts (edge case: shouldn't happen in app)
      await db.workouts.insertOne(
        createTestWorkout(
          name: 'Active Workout 1',
          startTime: now.subtract(const Duration(hours: 3)),
          endTime: null,
        ),
      );

      await db.workouts.insertOne(
        createTestWorkout(
          name: 'Active Workout 2',
          startTime: now.subtract(const Duration(hours: 1)),
          endTime: null,
        ),
      );

      await db.workouts.insertOne(
        createTestWorkout(
          name: 'Active Workout 3',
          startTime: now,
          endTime: null,
        ),
      );

      // Query for most recent active workout
      final workout = await (db.workouts.select()
            ..where((w) => w.endTime.isNull())
            ..orderBy([
              (w) =>
                  OrderingTerm(expression: w.startTime, mode: OrderingMode.desc),
            ])
            ..limit(1))
          .getSingleOrNull();

      expect(workout, isNotNull);
      expect(workout!.name, equals('Active Workout 3'));

      await db.close();
    });

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
  });

  group('Cascade deletion', () {
    test('deleting workout deletes associated sets', () async {
      final db = await createTestDatabase();

      // Create workout with sets
      final workoutId = await db.workouts.insertOne(
        createTestWorkout(name: 'Workout to Delete'),
      );

      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Bench Press'),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Squat'),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Deadlift'),
      );

      // Verify sets exist
      final setsBefore = await (db.gymSets.select()
            ..where((s) => s.workoutId.equals(workoutId)))
          .get();
      expect(setsBefore.length, equals(3));

      // Delete workout and its sets (manual cascade)
      await db.gymSets.deleteWhere((tbl) => tbl.workoutId.equals(workoutId));
      await db.workouts.deleteWhere((tbl) => tbl.id.equals(workoutId));

      // Verify sets are deleted
      final setsAfter = await (db.gymSets.select()
            ..where((s) => s.workoutId.equals(workoutId)))
          .get();
      expect(setsAfter.length, equals(0));

      // Verify workout is deleted
      final workout = await (db.workouts.select()
            ..where((w) => w.id.equals(workoutId)))
          .getSingleOrNull();
      expect(workout, isNull);

      await db.close();
    });

    test('deleting multiple workouts deletes all associated sets', () async {
      final db = await createTestDatabase();

      // Create multiple workouts with sets
      final workout1Id = await db.workouts.insertOne(
        createTestWorkout(name: 'Workout 1'),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workout1Id, name: 'Exercise 1'),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workout1Id, name: 'Exercise 2'),
      );

      final workout2Id = await db.workouts.insertOne(
        createTestWorkout(name: 'Workout 2'),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workout2Id, name: 'Exercise 3'),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workout2Id, name: 'Exercise 4'),
      );

      final workout3Id = await db.workouts.insertOne(
        createTestWorkout(name: 'Workout 3'),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workout3Id, name: 'Exercise 5'),
      );

      // Delete workouts 1 and 2
      final idsToDelete = [workout1Id, workout2Id];
      await db.gymSets.deleteWhere((tbl) => tbl.workoutId.isIn(idsToDelete));
      await db.workouts.deleteWhere((tbl) => tbl.id.isIn(idsToDelete));

      // Verify sets for deleted workouts are gone
      final deletedSets = await (db.gymSets.select()
            ..where((s) => s.workoutId.isIn(idsToDelete)))
          .get();
      expect(deletedSets.length, equals(0));

      // Verify workout 3 and its set remain
      final remainingSets = await (db.gymSets.select()
            ..where((s) => s.workoutId.equals(workout3Id)))
          .get();
      expect(remainingSets.length, equals(1));

      final remainingWorkout = await (db.workouts.select()
            ..where((w) => w.id.equals(workout3Id)))
          .getSingleOrNull();
      expect(remainingWorkout, isNotNull);

      await db.close();
    });
  });

  group('Exercise grouping', () {
    test('groups sets by sequence within a workout', () async {
      final db = await createTestDatabase();

      final workoutId = await db.workouts.insertOne(
        createTestWorkout(name: 'Test Workout'),
      );

      // Exercise 0: Bench Press (3 sets)
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Bench Press', sequence: 0),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Bench Press', sequence: 0),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Bench Press', sequence: 0),
      );

      // Exercise 1: Squat (2 sets)
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Squat', sequence: 1),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Squat', sequence: 1),
      );

      // Exercise 2: Deadlift (1 set)
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Deadlift', sequence: 2),
      );

      // Get distinct sequences
      final sequences = await (db.gymSets.selectOnly(distinct: true)
            ..addColumns([db.gymSets.sequence])
            ..where(db.gymSets.workoutId.equals(workoutId))
            ..orderBy([OrderingTerm(expression: db.gymSets.sequence)]))
          .get();

      expect(sequences.length, equals(3));
      expect(sequences[0].read(db.gymSets.sequence), equals(0));
      expect(sequences[1].read(db.gymSets.sequence), equals(1));
      expect(sequences[2].read(db.gymSets.sequence), equals(2));

      // Get sets for each sequence
      final sequence0Sets = await (db.gymSets.select()
            ..where((s) =>
                s.workoutId.equals(workoutId) & s.sequence.equals(0),))
          .get();
      expect(sequence0Sets.length, equals(3));
      expect(sequence0Sets.every((s) => s.name == 'Bench Press'), isTrue);

      final sequence1Sets = await (db.gymSets.select()
            ..where((s) =>
                s.workoutId.equals(workoutId) & s.sequence.equals(1),))
          .get();
      expect(sequence1Sets.length, equals(2));
      expect(sequence1Sets.every((s) => s.name == 'Squat'), isTrue);

      final sequence2Sets = await (db.gymSets.select()
            ..where((s) =>
                s.workoutId.equals(workoutId) & s.sequence.equals(2),))
          .get();
      expect(sequence2Sets.length, equals(1));
      expect(sequence2Sets[0].name, equals('Deadlift'));

      await db.close();
    });

    test('same exercise can appear at different sequences', () async {
      final db = await createTestDatabase();

      final workoutId = await db.workouts.insertOne(
        createTestWorkout(name: 'Test Workout'),
      );

      // Bench Press as first exercise
      await db.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          sequence: 0,
          weight: 100.0,
        ),
      );

      // Squat as second exercise
      await db.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Squat',
          sequence: 1,
          weight: 150.0,
        ),
      );

      // Bench Press again as third exercise (drop set)
      await db.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          sequence: 2,
          weight: 80.0,
          dropSet: true,
        ),
      );

      // Query sets ordered by sequence
      final sets = await (db.gymSets.select()
            ..where((s) => s.workoutId.equals(workoutId))
            ..orderBy([
              (s) => OrderingTerm(expression: s.sequence),
            ]))
          .get();

      expect(sets.length, equals(3));
      expect(sets[0].sequence, equals(0));
      expect(sets[0].name, equals('Bench Press'));
      expect(sets[0].weight, equals(100.0));

      expect(sets[1].sequence, equals(1));
      expect(sets[1].name, equals('Squat'));

      expect(sets[2].sequence, equals(2));
      expect(sets[2].name, equals('Bench Press'));
      expect(sets[2].weight, equals(80.0));
      expect(sets[2].dropSet, isTrue);

      await db.close();
    });
  });

  group('PR queries', () {
    test('finds best 1RM for exercise', () async {
      final db = await createTestDatabase();

      // Create sets with different weights and reps
      await db.gymSets.insertOne(
        createTestSet(name: 'Bench Press', weight: 100.0, reps: 5.0),
      );
      await db.gymSets.insertOne(
        createTestSet(name: 'Bench Press', weight: 120.0, reps: 3.0),
      );
      await db.gymSets.insertOne(
        createTestSet(name: 'Bench Press', weight: 90.0, reps: 10.0),
      );

      // Query for max 1RM using Brzycki formula
      // Must filter out hidden, warmup, and cardio sets (same as production code)
      final result = await (db.gymSets.selectOnly()
            ..addColumns([_brzycki1RMExpression])
            ..where(
              db.gymSets.name.equals('Bench Press') &
                  db.gymSets.hidden.equals(false) &
                  db.gymSets.warmup.equals(false) &
                  db.gymSets.cardio.equals(false),
            ))
          .getSingleOrNull();

      expect(result, isNotNull);
      final best1RM = result!.read(_brzycki1RMExpression);

      // 120kg × 3 reps should give highest 1RM
      final expected = calculate1RM(120.0, 3.0);
      expect(best1RM, closeTo(expected, 0.01));

      await db.close();
    });

    test('finds best volume for exercise', () async {
      final db = await createTestDatabase();

      // Create sets with different volume (weight × reps)
      await db.gymSets.insertOne(
        createTestSet(name: 'Squat', weight: 100.0, reps: 5.0), // 500
      );
      await db.gymSets.insertOne(
        createTestSet(name: 'Squat', weight: 80.0, reps: 10.0), // 800
      );
      await db.gymSets.insertOne(
        createTestSet(name: 'Squat', weight: 120.0, reps: 3.0), // 360
      );

      // Query for max volume
      // Must filter out hidden, warmup, and cardio sets (same as production code)
      final result = await (db.gymSets.selectOnly()
            ..addColumns([
              const CustomExpression<double>('MAX(weight * reps)'),
            ])
            ..where(
              db.gymSets.name.equals('Squat') &
                  db.gymSets.hidden.equals(false) &
                  db.gymSets.warmup.equals(false) &
                  db.gymSets.cardio.equals(false),
            ))
          .getSingleOrNull();

      expect(result, isNotNull);
      final bestVolume = result!.read(const CustomExpression<double>('MAX(weight * reps)'));
      expect(bestVolume, equals(800.0));

      await db.close();
    });

    test('finds best weight for exercise', () async {
      final db = await createTestDatabase();

      await db.gymSets.insertOne(
        createTestSet(name: 'Deadlift', weight: 180.0, reps: 5.0),
      );
      await db.gymSets.insertOne(
        createTestSet(name: 'Deadlift', weight: 200.0, reps: 1.0),
      );
      await db.gymSets.insertOne(
        createTestSet(name: 'Deadlift', weight: 150.0, reps: 10.0),
      );

      // Query for max weight
      // Must filter out hidden, warmup, and cardio sets (same as production code)
      final result = await (db.gymSets.selectOnly()
            ..addColumns([db.gymSets.weight.max()])
            ..where(
              db.gymSets.name.equals('Deadlift') &
                  db.gymSets.hidden.equals(false) &
                  db.gymSets.warmup.equals(false) &
                  db.gymSets.cardio.equals(false),
            ))
          .getSingleOrNull();

      expect(result, isNotNull);
      final bestWeight = result!.read(db.gymSets.weight.max());
      expect(bestWeight, equals(200.0));

      await db.close();
    });

    test('finds all PR types for multiple exercises', () async {
      final db = await createTestDatabase();

      // Bench Press sets
      await db.gymSets.insertOne(
        createTestSet(name: 'Bench Press', weight: 100.0, reps: 5.0),
      );
      await db.gymSets.insertOne(
        createTestSet(name: 'Bench Press', weight: 120.0, reps: 3.0),
      );

      // Squat sets
      await db.gymSets.insertOne(
        createTestSet(name: 'Squat', weight: 150.0, reps: 5.0),
      );
      await db.gymSets.insertOne(
        createTestSet(name: 'Squat', weight: 140.0, reps: 8.0),
      );

      // Query for PRs grouped by exercise
      // Must filter out hidden, warmup, and cardio sets (same as production code)
      final result = await (db.gymSets.selectOnly()
            ..addColumns([
              db.gymSets.name,
              db.gymSets.weight.max(),
              const CustomExpression<double>('MAX(weight * reps)'),
              _brzycki1RMExpression,
            ])
            ..where(
              db.gymSets.hidden.equals(false) &
                  db.gymSets.warmup.equals(false) &
                  db.gymSets.cardio.equals(false),
            )
            ..groupBy([db.gymSets.name]))
          .get();

      expect(result.length, equals(2));

      // Bench Press records
      final benchPress = result.firstWhere(
        (r) => r.read(db.gymSets.name) == 'Bench Press',
      );
      expect(benchPress.read(db.gymSets.weight.max()), equals(120.0));
      expect(benchPress.read(const CustomExpression<double>('MAX(weight * reps)')),
          equals(500.0),); // 100 × 5

      // Squat records
      final squat = result.firstWhere(
        (r) => r.read(db.gymSets.name) == 'Squat',
      );
      expect(squat.read(db.gymSets.weight.max()), equals(150.0));
      expect(squat.read(const CustomExpression<double>('MAX(weight * reps)')),
          equals(1120.0),); // 140 × 8

      await db.close();
    });

    test('excludes warmup and cardio sets from PR calculations', () async {
      final db = await createTestDatabase();

      // Regular working set
      await db.gymSets.insertOne(
        createTestSet(
          name: 'Bench Press',
          weight: 100.0,
          reps: 5.0,
          warmup: false,
          cardio: false,
        ),
      );

      // Warmup set (should be excluded)
      await db.gymSets.insertOne(
        createTestSet(
          name: 'Bench Press',
          weight: 120.0,
          reps: 5.0,
          warmup: true,
          cardio: false,
        ),
      );

      // Cardio set (should be excluded)
      await db.gymSets.insertOne(
        createTestSet(
          name: 'Bench Press',
          weight: 110.0,
          reps: 5.0,
          warmup: false,
          cardio: true,
        ),
      );

      // Query for best weight excluding warmup and cardio
      final result = await (db.gymSets.selectOnly()
            ..addColumns([db.gymSets.weight.max()])
            ..where(
              db.gymSets.name.equals('Bench Press') &
                  db.gymSets.hidden.equals(false) &
                  db.gymSets.warmup.equals(false) &
                  db.gymSets.cardio.equals(false),
            ))
          .getSingleOrNull();

      expect(result, isNotNull);
      final bestWeight = result!.read(db.gymSets.weight.max());
      expect(bestWeight, equals(100.0)); // Only the working set

      await db.close();
    });

    test('excludeSetId parameter excludes specific set from PR query', () async {
      final db = await createTestDatabase();

      // Create a current PR holder
      final existingSetId = await db.gymSets.insertOne(
        createTestSet(name: 'Squat', weight: 200.0, reps: 5.0),
      );

      // Create an older, lighter set
      await db.gymSets.insertOne(
        createTestSet(name: 'Squat', weight: 180.0, reps: 5.0),
      );

      // Query without exclusion - should return 200.0
      final resultWithoutExclusion = await (db.gymSets.selectOnly()
            ..addColumns([db.gymSets.weight.max()])
            ..where(
              db.gymSets.name.equals('Squat') &
                  db.gymSets.hidden.equals(false) &
                  db.gymSets.warmup.equals(false) &
                  db.gymSets.cardio.equals(false),
            ))
          .getSingleOrNull();

      expect(resultWithoutExclusion, isNotNull);
      expect(
        resultWithoutExclusion!.read(db.gymSets.weight.max()),
        equals(200.0),
      );

      // Query with exclusion - should return 180.0 (the next best)
      final resultWithExclusion = await (db.gymSets.selectOnly()
            ..addColumns([db.gymSets.weight.max()])
            ..where(
              db.gymSets.name.equals('Squat') &
                  db.gymSets.hidden.equals(false) &
                  db.gymSets.warmup.equals(false) &
                  db.gymSets.cardio.equals(false) &
                  db.gymSets.id.equals(existingSetId).not(),
            ))
          .getSingleOrNull();

      expect(resultWithExclusion, isNotNull);
      expect(
        resultWithExclusion!.read(db.gymSets.weight.max()),
        equals(180.0),
      );

      await db.close();
    });
  });
}
