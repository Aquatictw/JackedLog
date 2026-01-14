import 'package:csv/csv.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/database/database.dart';

import '../test_helpers.dart';

/// Create clean test database without default data
Future<AppDatabase> createCleanTestDatabase() async {
  final db = await createTestDatabase();
  // Clear default data that gets auto-populated
  await db.gymSets.deleteAll();
  await db.planExercises.deleteAll();
  await db.plans.deleteAll();
  return db;
}

void main() {
  group('Database export/import round-trip tests', () {
    test('exports and imports basic workout data', () async {
      // Create source database with test data
      final sourceDb = await createCleanTestDatabase();

      // Create a completed workout
      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(
          name: 'Basic Workout',
          startTime: DateTime(2026, 1, 13, 10),
          endTime: DateTime(2026, 1, 13, 11, 30),
          planId: 1,
          notes: 'Test workout notes',
        ),
      );

      // Add sets for the workout
      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          setOrder: 0,
          restMs: 120000,
        ),
      );

      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Squat',
          sequence: 1,
          setOrder: 0,
          weight: 150,
          reps: 8,
        ),
      );

      // Export data
      final (workoutsZip, setsZip) = await _exportData(sourceDb);

      // Import into fresh database
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify workouts
      final workouts = await targetDb.workouts.select().get();
      expect(workouts.length, equals(1));
      expect(workouts[0].name, equals('Basic Workout'));
      expect(workouts[0].startTime, equals(DateTime(2026, 1, 13, 10)));
      expect(workouts[0].endTime, equals(DateTime(2026, 1, 13, 11, 30)));
      expect(workouts[0].planId, equals(1));
      expect(workouts[0].notes, equals('Test workout notes'));

      // Verify sets
      final sets = await (targetDb.gymSets.select()
            ..orderBy([
              (s) => OrderingTerm(expression: s.sequence),
            ]))
          .get();
      expect(sets.length, equals(2));

      // First set
      expect(sets[0].name, equals('Bench Press'));
      expect(sets[0].sequence, equals(0));
      expect(sets[0].setOrder, equals(0));
      expect(sets[0].weight, equals(100.0));
      expect(sets[0].reps, equals(10.0));
      expect(sets[0].unit, equals('kg'));
      expect(sets[0].restMs, equals(120000));

      // Second set
      expect(sets[1].name, equals('Squat'));
      expect(sets[1].sequence, equals(1));
      expect(sets[1].weight, equals(150.0));
      expect(sets[1].reps, equals(8.0));
    });

    test('preserves active workout (null endTime)', () async {
      final sourceDb = await createCleanTestDatabase();

      // Create active workout (endTime = null)
      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(
          name: 'Active Workout',
          startTime: DateTime(2026, 1, 13, 10),
        ),
      );

      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          setOrder: 0,
        ),
      );

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify active workout preserved
      final workouts = await targetDb.workouts.select().get();
      expect(workouts.length, equals(1));
      expect(workouts[0].endTime, isNull);
      expect(workouts[0].name, equals('Active Workout'));
    });

    test('preserves null values in optional fields', () async {
      final sourceDb = await createCleanTestDatabase();

      // Create workout with minimal fields
      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(
          startTime: DateTime(2026, 1, 13, 10),
          endTime: DateTime(2026, 1, 13, 11),
        ),
      );

      // Create set with null optional fields
      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
        ),
      );

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify nulls preserved
      final workouts = await targetDb.workouts.select().get();
      expect(workouts[0].planId, isNull);
      expect(workouts[0].notes, isNull);

      final sets = await targetDb.gymSets.select().get();
      expect(sets[0].setOrder, isNull);
      expect(sets[0].notes, isNull);
      expect(sets[0].category, isNull);
      expect(sets[0].image, isNull);
      expect(sets[0].restMs, isNull);
      expect(sets[0].planId, isNull);
      expect(sets[0].incline, isNull);
      expect(sets[0].exerciseType, isNull);
      expect(sets[0].brandName, isNull);
    });

    test('handles unicode characters in exercise names and notes', () async {
      final sourceDb = await createCleanTestDatabase();

      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(
          name: '운동 세션 🏋️',
          notes: 'Unicode notes: 한글, 日本語, Emoji 💪',
        ),
      );

      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: unicodeExerciseName, // '벤치프레스 💪' from test_helpers
          notes: '세트 노트 with emojis 🔥',
        ),
      );

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify unicode preserved
      final workouts = await targetDb.workouts.select().get();
      expect(workouts[0].name, equals('운동 세션 🏋️'));
      expect(workouts[0].notes, equals('Unicode notes: 한글, 日本語, Emoji 💪'));

      final sets = await targetDb.gymSets.select().get();
      expect(sets[0].name, equals(unicodeExerciseName));
      expect(sets[0].notes, equals('세트 노트 with emojis 🔥'));
    });

    test('handles special characters in text fields', () async {
      final sourceDb = await createCleanTestDatabase();

      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(
          name: 'Workout with "quotes" & <brackets>',
          notes: specialCharsNote, // Multi-line with special chars
        ),
      );

      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Exercise [1,2,3]',
          notes: '''
Line 1 with "quotes"
Line 2 with <tags>
Line 3 with & symbols''',
          category: 'Category: A|B|C',
          brandName: 'Brand "X" & Co.',
        ),
      );

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify special characters preserved
      final workouts = await targetDb.workouts.select().get();
      expect(workouts[0].name, equals('Workout with "quotes" & <brackets>'));
      expect(workouts[0].notes, equals(specialCharsNote));

      final sets = await targetDb.gymSets.select().get();
      expect(sets[0].name, equals('Exercise [1,2,3]'));
      expect(sets[0].notes, contains('"quotes"'));
      expect(sets[0].notes, contains('<tags>'));
      expect(sets[0].notes, contains('& symbols'));
      expect(sets[0].category, equals('Category: A|B|C'));
      expect(sets[0].brandName, equals('Brand "X" & Co.'));
    });

    test('preserves all set type combinations: warmup, drop, cardio, regular',
        () async {
      final sourceDb = await createCleanTestDatabase();

      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(name: 'Mixed Workout'),
      );

      // Warmup set
      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          setOrder: 0,
          warmup: true,
          weight: 60,
        ),
      );

      // Regular set
      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          setOrder: 1,
          reps: 8,
        ),
      );

      // Drop set
      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          setOrder: 2,
          dropSet: true,
          weight: 80,
          reps: 12,
        ),
      );

      // Cardio set
      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Running',
          sequence: 1,
          setOrder: 0,
          cardio: true,
          duration: 1800, // 30 minutes
          distance: 5, // 5 km
          incline: 2,
        ),
      );

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify all set types
      final sets = await (targetDb.gymSets.select()
            ..orderBy([
              (s) => OrderingTerm(expression: s.sequence),
              (s) => OrderingTerm(expression: s.setOrder),
            ]))
          .get();

      expect(sets.length, equals(4));

      // Warmup set
      expect(sets[0].warmup, isTrue);
      expect(sets[0].dropSet, isFalse);
      expect(sets[0].cardio, isFalse);
      expect(sets[0].weight, equals(60.0));

      // Regular set
      expect(sets[1].warmup, isFalse);
      expect(sets[1].dropSet, isFalse);
      expect(sets[1].cardio, isFalse);
      expect(sets[1].weight, equals(100.0));

      // Drop set
      expect(sets[2].warmup, isFalse);
      expect(sets[2].dropSet, isTrue);
      expect(sets[2].cardio, isFalse);
      expect(sets[2].weight, equals(80.0));

      // Cardio set
      expect(sets[3].cardio, isTrue);
      expect(sets[3].duration, equals(1800.0));
      expect(sets[3].distance, equals(5.0));
      expect(sets[3].incline, equals(2));
    });

    test('preserves sequence and setOrder for multiple exercises', () async {
      final sourceDb = await createCleanTestDatabase();

      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(name: 'Ordered Workout'),
      );

      // Exercise 0: 3 sets
      for (int i = 0; i < 3; i++) {
        await sourceDb.gymSets.insertOne(
          createTestSet(
            workoutId: workoutId,
            name: 'Bench Press',
            setOrder: i,
            weight: 100.0 + (i * 10),
          ),
        );
      }

      // Exercise 1: 2 sets
      for (int i = 0; i < 2; i++) {
        await sourceDb.gymSets.insertOne(
          createTestSet(
            workoutId: workoutId,
            name: 'Squat',
            sequence: 1,
            setOrder: i,
            weight: 150.0 + (i * 10),
          ),
        );
      }

      // Exercise 2: 4 sets
      for (int i = 0; i < 4; i++) {
        await sourceDb.gymSets.insertOne(
          createTestSet(
            workoutId: workoutId,
            name: 'Deadlift',
            sequence: 2,
            setOrder: i,
            weight: 180.0 + (i * 10),
          ),
        );
      }

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify order preserved
      final sets = await (targetDb.gymSets.select()
            ..orderBy([
              (s) => OrderingTerm(expression: s.sequence),
              (s) => OrderingTerm(expression: s.setOrder),
            ]))
          .get();

      expect(sets.length, equals(9));

      // Exercise 0: Bench Press
      for (int i = 0; i < 3; i++) {
        expect(sets[i].name, equals('Bench Press'));
        expect(sets[i].sequence, equals(0));
        expect(sets[i].setOrder, equals(i));
        expect(sets[i].weight, equals(100.0 + (i * 10)));
      }

      // Exercise 1: Squat
      for (int i = 0; i < 2; i++) {
        expect(sets[3 + i].name, equals('Squat'));
        expect(sets[3 + i].sequence, equals(1));
        expect(sets[3 + i].setOrder, equals(i));
        expect(sets[3 + i].weight, equals(150.0 + (i * 10)));
      }

      // Exercise 2: Deadlift
      for (int i = 0; i < 4; i++) {
        expect(sets[5 + i].name, equals('Deadlift'));
        expect(sets[5 + i].sequence, equals(2));
        expect(sets[5 + i].setOrder, equals(i));
        expect(sets[5 + i].weight, equals(180.0 + (i * 10)));
      }
    });

    test('preserves workoutId linkage between workouts and sets', () async {
      final sourceDb = await createCleanTestDatabase();

      // Create multiple workouts
      final workout1Id = await sourceDb.workouts.insertOne(
        createTestWorkout(name: 'Workout 1'),
      );
      final workout2Id = await sourceDb.workouts.insertOne(
        createTestWorkout(name: 'Workout 2'),
      );
      final workout3Id = await sourceDb.workouts.insertOne(
        createTestWorkout(name: 'Workout 3'),
      );

      // Add sets to different workouts
      await sourceDb.gymSets.insertOne(
        createTestSet(workoutId: workout1Id, name: 'Exercise A'),
      );
      await sourceDb.gymSets.insertOne(
        createTestSet(workoutId: workout1Id, name: 'Exercise B', sequence: 1),
      );
      await sourceDb.gymSets.insertOne(
        createTestSet(workoutId: workout2Id, name: 'Exercise C'),
      );
      await sourceDb.gymSets.insertOne(
        createTestSet(workoutId: workout3Id, name: 'Exercise D'),
      );
      await sourceDb.gymSets.insertOne(
        createTestSet(workoutId: workout3Id, name: 'Exercise E', sequence: 1),
      );
      await sourceDb.gymSets.insertOne(
        createTestSet(workoutId: workout3Id, name: 'Exercise F', sequence: 2),
      );

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify workoutId linkage
      final workouts = await targetDb.workouts.select().get();
      expect(workouts.length, equals(3));

      // Verify sets belong to correct workouts
      final workout1Sets = await (targetDb.gymSets.select()
            ..where((s) => s.workoutId.equals(workout1Id)))
          .get();
      expect(workout1Sets.length, equals(2));
      expect(workout1Sets[0].name, equals('Exercise A'));
      expect(workout1Sets[1].name, equals('Exercise B'));

      final workout2Sets = await (targetDb.gymSets.select()
            ..where((s) => s.workoutId.equals(workout2Id)))
          .get();
      expect(workout2Sets.length, equals(1));
      expect(workout2Sets[0].name, equals('Exercise C'));

      final workout3Sets = await (targetDb.gymSets.select()
            ..where((s) => s.workoutId.equals(workout3Id)))
          .get();
      expect(workout3Sets.length, equals(3));
      expect(
        workout3Sets.map((s) => s.name).toList(),
        equals(['Exercise D', 'Exercise E', 'Exercise F']),
      );
    });

    test('handles all exercise metadata fields', () async {
      final sourceDb = await createCleanTestDatabase();

      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(name: 'Metadata Test'),
      );

      // Set with all metadata fields
      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bench Press',
          setOrder: 0,
          category: 'Chest',
          image: '/path/to/image.jpg',
          exerciseType: 'Barbell',
          brandName: 'Rogue',
          restMs: 180000,
          planId: 5,
        ),
      );

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify all metadata preserved
      final sets = await targetDb.gymSets.select().get();
      expect(sets[0].category, equals('Chest'));
      expect(sets[0].image, equals('/path/to/image.jpg'));
      expect(sets[0].exerciseType, equals('Barbell'));
      expect(sets[0].brandName, equals('Rogue'));
      expect(sets[0].restMs, equals(180000));
      expect(sets[0].planId, equals(5));
    });

    test('preserves exact row counts across tables', () async {
      final sourceDb = await createCleanTestDatabase();

      // Create 5 workouts
      for (int i = 0; i < 5; i++) {
        final workoutId = await sourceDb.workouts.insertOne(
          createTestWorkout(name: 'Workout ${i + 1}'),
        );

        // Add 3 sets to each workout
        for (int j = 0; j < 3; j++) {
          await sourceDb.gymSets.insertOne(
            createTestSet(
              workoutId: workoutId,
              name: 'Exercise ${j + 1}',
              sequence: j,
            ),
          );
        }
      }

      // Get source counts
      final sourceWorkoutCount = await sourceDb.workouts.count().getSingle();
      final sourceSetCount = await sourceDb.gymSets.count().getSingle();

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify counts match
      final targetWorkoutCount = await targetDb.workouts.count().getSingle();
      final targetSetCount = await targetDb.gymSets.count().getSingle();

      expect(targetWorkoutCount, equals(sourceWorkoutCount));
      expect(targetSetCount, equals(sourceSetCount));
      expect(targetWorkoutCount, equals(5));
      expect(targetSetCount, equals(15));
    });

    test('handles empty notes and zero values correctly', () async {
      final sourceDb = await createCleanTestDatabase();

      final workoutId = await sourceDb.workouts.insertOne(
        createTestWorkout(
          name: 'Edge Case Workout',
          notes: '', // Empty string (converted to null in CSV)
        ),
      );

      // Set with zero values and empty strings
      await sourceDb.gymSets.insertOne(
        createTestSet(
          workoutId: workoutId,
          name: 'Bodyweight Exercise',
          weight: 0, // Zero weight
          reps: 0, // Zero reps
          notes: '', // Empty string (converted to null in CSV)
        ),
      );

      // Export and import
      final (workoutsZip, setsZip) = await _exportData(sourceDb);
      final targetDb = await createCleanTestDatabase();
      await _importData(targetDb, workoutsZip, setsZip);

      // Verify zeros preserved, empty strings become null (as per import logic)
      final workouts = await targetDb.workouts.select().get();
      expect(
        workouts[0].notes,
        isNull,
      ); // Empty string exported as '', imported as null

      final sets = await targetDb.gymSets.select().get();
      expect(sets[0].weight, equals(0.0));
      expect(sets[0].reps, equals(0.0));
      expect(sets[0].duration, equals(0.0));
      expect(sets[0].distance, equals(0.0));
      expect(
        sets[0].notes,
        isNull,
      ); // Empty string exported as '', imported as null
    });
  });
}

/// Export database to CSV format (simulating export_data.dart logic)
Future<(String, String)> _exportData(AppDatabase db) async {
  // Export workouts
  final workouts = await db.workouts.select().get();
  final List<List<dynamic>> workoutsData = [
    ['id', 'startTime', 'endTime', 'planId', 'name', 'notes'],
  ];
  for (final workout in workouts) {
    workoutsData.add([
      workout.id,
      workout.startTime.toIso8601String(),
      workout.endTime?.toIso8601String() ?? '',
      workout.planId ?? '',
      workout.name ?? '',
      workout.notes ?? '',
    ]);
  }
  final workoutsCsv = const ListToCsvConverter(eol: '\n').convert(workoutsData);

  // Export gym sets
  final gymSets = await db.gymSets.select().get();
  final List<List<dynamic>> setsData = [
    [
      'id',
      'name',
      'reps',
      'weight',
      'unit',
      'created',
      'cardio',
      'duration',
      'distance',
      'incline',
      'restMs',
      'hidden',
      'workoutId',
      'planId',
      'image',
      'category',
      'notes',
      'sequence',
      'setOrder',
      'warmup',
      'exerciseType',
      'brandName',
      'dropSet',
      'supersetId',
      'supersetPosition',
    ]
  ];
  for (final gymSet in gymSets) {
    setsData.add([
      gymSet.id,
      gymSet.name,
      gymSet.reps,
      gymSet.weight,
      gymSet.unit,
      gymSet.created.toIso8601String(),
      gymSet.cardio,
      gymSet.duration,
      gymSet.distance,
      gymSet.incline ?? '',
      gymSet.restMs ?? '',
      gymSet.hidden,
      gymSet.workoutId ?? '',
      gymSet.planId ?? '',
      gymSet.image ?? '',
      gymSet.category ?? '',
      gymSet.notes ?? '',
      gymSet.sequence,
      gymSet.setOrder ?? '',
      gymSet.warmup,
      gymSet.exerciseType ?? '',
      gymSet.brandName ?? '',
      gymSet.dropSet,
      gymSet.supersetId ?? '',
      gymSet.supersetPosition ?? '',
    ]);
  }
  final setsCsv = const ListToCsvConverter(eol: '\n').convert(setsData);

  return (workoutsCsv, setsCsv);
}

/// Import CSV data into database (simulating import_data.dart logic)
Future<void> _importData(
  AppDatabase db,
  String workoutsCsv,
  String setsCsv,
) async {
  // Parse workouts CSV
  final workoutsRows = const CsvToListConverter(eol: '\n').convert(workoutsCsv);

  // Parse gym sets CSV
  final setsRows = const CsvToListConverter(eol: '\n').convert(setsCsv);

  // Check CSV format version by examining header row
  final setsHeader =
      setsRows.first.map((e) => e.toString().toLowerCase()).toList();
  final hasSupersetColumns = setsHeader.contains('supersetid');
  final hasSetOrderColumn = setsHeader.contains('setorder');

  // Import workouts (skip header row)
  final workoutsToInsert = workoutsRows.skip(1).map((row) {
    return WorkoutsCompanion(
      id: Value(int.tryParse(row[0]?.toString() ?? '0') ?? 0),
      startTime: Value(DateTime.parse(row[1].toString())),
      endTime: Value(_parseNullableDateTime(row[2])),
      planId: Value(_parseNullableInt(row[3])),
      name: Value(_parseNullableString(row[4])),
      notes: Value(_parseNullableString(row[5])),
    );
  });

  // Import gym sets (skip header row)
  final gymSets = setsRows.skip(1).map((row) {
    final reps =
        row[2] is num ? row[2].toDouble() : double.parse(row[2].toString());
    final weight =
        row[3] is num ? row[3].toDouble() : double.parse(row[3].toString());

    return GymSetsCompanion(
      id: Value(int.tryParse(row[0]?.toString() ?? '0') ?? 0),
      name: Value(row[1]?.toString() ?? ''),
      reps: Value(reps),
      weight: Value(weight),
      unit: Value(row[4]?.toString() ?? ''),
      created: Value(DateTime.parse(row[5].toString())),
      cardio: Value(_parseBool(row[6])),
      duration: Value(
        double.tryParse(row[7]?.toString() ?? '0') ?? 0,
      ),
      distance: Value(
        double.tryParse(row[8]?.toString() ?? '0') ?? 0,
      ),
      incline: Value(_parseNullableInt(row[9])),
      restMs: Value(_parseNullableInt(row[10])),
      hidden: Value(_parseBool(row[11])),
      workoutId: Value(_parseNullableInt(row[12])),
      planId: Value(_parseNullableInt(row[13])),
      image: Value(_parseNullableString(row[14])),
      category: Value(_parseNullableString(row[15])),
      notes: Value(_parseNullableString(row[16])),
      sequence: Value(int.tryParse(row[17]?.toString() ?? '0') ?? 0),
      setOrder: Value(hasSetOrderColumn ? _parseNullableInt(row[18]) : null),
      warmup: Value(_parseBool(row[hasSetOrderColumn ? 19 : 18])),
      exerciseType:
          Value(_parseNullableString(row[hasSetOrderColumn ? 20 : 19])),
      brandName: Value(_parseNullableString(row[hasSetOrderColumn ? 21 : 20])),
      dropSet: Value(_parseBool(row[hasSetOrderColumn ? 22 : 21])),
      supersetId: Value(
        hasSupersetColumns
            ? _parseNullableString(row[hasSetOrderColumn ? 23 : 22])
            : null,
      ),
      supersetPosition: Value(
        hasSupersetColumns
            ? _parseNullableInt(row[hasSetOrderColumn ? 24 : 23])
            : null,
      ),
    );
  });

  // Clear and import
  await db.workouts.deleteAll();
  await db.gymSets.deleteAll();
  await db.workouts.insertAll(workoutsToInsert);
  await db.gymSets.insertAll(gymSets);
}

int? _parseNullableInt(dynamic value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _parseNullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  if (str.isEmpty) return null;
  return str;
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null || value == '') return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1';
  }
  if (value is num) return value != 0;
  return false;
}
