import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/backup/workout_archive.dart';
import 'package:jackedlog/database/database.dart';

void main() {
  late AppDatabase database;
  late WorkoutArchive backup;
  final recordedAt = DateTime(2026, 9, 13, 8);

  Future<void> seed() async {
    await database.into(database.workouts).insert(
          WorkoutsCompanion.insert(
            id: const Value(42),
            startTime: recordedAt,
            name: const Value('晨跑 🏃'),
            notes: const Value('公園, "easy"\n第二圈'),
          ),
        );
    await database.into(database.gymSets).insert(
          GymSetsCompanion.insert(
            id: const Value(101),
            name: '跑步 🏃',
            reps: 0,
            weight: 0,
            unit: 'km',
            created: recordedAt,
            workoutId: const Value(42),
            cardio: const Value(true),
            distance: const Value(5.25),
            duration: const Value(30.5),
            incline: const Value(2),
            notes: const Value('心率穩定 💗'),
            cardioMetric: const Value('duration'),
          ),
        );
  }

  CardioActivity standalone({String id = 'manual:run'}) => CardioActivity(
        id: id,
        workoutId: 42,
        name: 'Outdoor 跑步',
        sport: 'running',
        environment: 'outdoor',
        recordedAt: recordedAt,
        startedAt: recordedAt,
        endedAt: recordedAt.add(const Duration(minutes: 31)),
        distanceMeters: 5100.25,
        durationSeconds: 1800.5,
        durationBasis: 'moving',
        inclinePercent: -1.5,
        warmup: true,
        notes: '風很大\n💨',
        source: 'manual',
      );

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    backup = WorkoutArchive(database);
    await database.delete(database.gymSets).go();
    await database.delete(database.planExercises).go();
    await database.delete(database.plans).go();
  });
  tearDown(() => database.close());

  test('old ZIP imports through public restore and backfills cardio', () async {
    await seed();
    final oldZip = rewriteArchive(await backup.encode(), removeSidecar: true);
    await backup.restore(oldZip);
    final activity =
        await database.select(database.cardioActivities).getSingle();
    expect(activity.id, 'legacy-bout:101');
    expect(activity.distanceMeters, 5250);
    expect(activity.durationSeconds, 1830);
    expect(activity.workoutId, 42);
    expect(activity.source, 'legacy');
  });

  test('v54 bodyweight format preserves following columns', () async {
    final bytes = archiveFromFiles({
      'workouts.csv':
          'id,startTime,endTime,planId,name,notes\n42,2026-09-13T08:00:00,,,,',
      'gym_sets.csv': const ListToCsvConverter(eol: '\n').convert([
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
          'bodyWeight',
          'incline',
          'restMs',
          'hidden',
          'workoutId',
          'planId',
          'image',
          'category',
          'notes',
          'sequence',
          'warmup',
          'exerciseType',
          'brandName',
          'dropSet',
        ],
        [
          101,
          'Run',
          0,
          0,
          'mi',
          '2026-09-13T08:00:00',
          true,
          10,
          1,
          80,
          3,
          60000,
          false,
          42,
          '',
          '',
          'Cardio',
          'old',
          0,
          true,
          'machine',
          'brand',
          false,
        ],
      ]),
    });
    await backup.restore(bytes);
    final set = await database.select(database.gymSets).getSingle();
    expect(set.incline, 3);
    expect(set.restMs, 60000);
    expect(set.warmup, true);
    expect(set.brandName, 'brand');
    final activity =
        await database.select(database.cardioActivities).getSingle();
    expect(activity.distanceMeters, closeTo(1609.34, 0.01));
  });

  test('unicode CSV and all linked/standalone metadata roundtrip', () async {
    await seed();
    await (database.update(database.cardioActivities)
          ..where((row) => row.id.equals('legacy-bout:101')))
        .write(
      CardioActivitiesCompanion(
        sport: const Value('running'),
        environment: const Value('indoor'),
        startedAt: Value(recordedAt),
        endedAt: Value(recordedAt.add(const Duration(minutes: 32))),
        durationBasis: const Value('elapsed'),
      ),
    );
    await database.into(database.cardioActivities).insert(standalone());
    final expected = await database.select(database.cardioActivities).get();
    final bytes = await backup.encode();
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(
      utf8.decode(archive.findFile('gym_sets.csv')!.content as List<int>),
      contains('跑步 🏃'),
    );
    await backup.restore(bytes);
    expect(
      await database.select(database.cardioActivities).get(),
      unorderedEquals(expected),
    );
    final workout = await database.select(database.workouts).getSingle();
    expect(workout.name, '晨跑 🏃');
    expect(workout.notes, '公園, "easy"\n第二圈');
    final set = await database.select(database.gymSets).getSingle();
    expect(set.notes, '心率穩定 💗');
    expect(set.cardioMetric, 'duration');
  });

  test('replacement removes prior standalone activities', () async {
    await seed();
    final bytes = await backup.encode();
    await database.into(database.cardioActivities).insert(standalone());
    await backup.restore(bytes);
    expect(
      (await database.select(database.cardioActivities).get())
          .map((row) => row.id),
      ['legacy-bout:101'],
    );
  });

  test('sidecar cannot overwrite linked source measurements', () async {
    await seed();
    final bytes = rewriteArchive(
      await backup.encode(),
      editSidecar: (json) {
        final row = (json['activities'] as List).single as Map<String, dynamic>;
        row['distanceMeters'] = 999999;
        row['durationSeconds'] = 1;
        row['name'] = 'Overwritten';
        row['notes'] = 'Overwritten';
      },
    );
    await backup.restore(bytes);
    final row = await database.select(database.cardioActivities).getSingle();
    expect(row.distanceMeters, 5250);
    expect(row.durationSeconds, 1830);
    expect(row.name, '跑步 🏃');
    expect(row.notes, '心率穩定 💗');
  });

  for (final invalidCase in [
    'version',
    'negative',
    'end',
    'orphan',
    'identity',
    'missing-workout',
    'duplicate',
  ]) {
    test('invalid $invalidCase sidecar leaves entire database intact',
        () async {
      await seed();
      await database.into(database.cardioActivities).insert(standalone());
      final beforeActivities =
          await database.select(database.cardioActivities).get();
      final beforeSets = await database.select(database.gymSets).get();
      final beforeWorkouts = await database.select(database.workouts).get();
      final bytes = rewriteArchive(
        await backup.encode(),
        editSidecar: (json) {
          final rows = json['activities'] as List;
          final row = rows.first as Map<String, dynamic>;
          switch (invalidCase) {
            case 'version':
              json['version'] = 99;
            case 'negative':
              row['distanceMeters'] = -1;
            case 'end':
              row['endedAt'] = recordedAt.millisecondsSinceEpoch;
            case 'orphan':
              row['legacyGymSetId'] = 999;
              row['id'] = 'legacy-bout:999';
            case 'identity':
              row['id'] = 'manual:fake';
            case 'missing-workout':
              rows.last['workoutId'] = 999;
            case 'duplicate':
              rows.add(Map<String, dynamic>.from(row));
          }
        },
      );
      // Plans also survive failure, although successful import replaces them.
      await database.into(database.plans).insert(
            PlansCompanion.insert(days: '', title: const Value('Retain plan')),
          );
      await expectLater(backup.restore(bytes), throwsA(anything));
      expect(
        await database.select(database.cardioActivities).get(),
        beforeActivities,
      );
      expect(await database.select(database.gymSets).get(), beforeSets);
      expect(await database.select(database.workouts).get(), beforeWorkouts);
      expect(
        (await database.select(database.plans).get()).single.title,
        'Retain plan',
      );
    });
  }

  test('stale linked sidecar cannot resurrect a removed legacy set', () async {
    await seed();
    final bytes = rewriteArchive(
      await backup.encode(),
      editSets: (rows) {
        rows.removeLast();
      },
    );
    await expectLater(backup.restore(bytes), throwsFormatException);
    expect((await database.select(database.gymSets).get()).single.id, 101);
  });

  test('malformed CSV is fully parsed before replacement', () async {
    await seed();
    final bytes = rewriteArchive(
      await backup.encode(),
      editSets: (rows) {
        rows.add([999, 'Bad row']);
      },
    );
    await expectLater(backup.restore(bytes), throwsA(anything));
    expect((await database.select(database.gymSets).get()).single.id, 101);
    expect((await database.select(database.workouts).get()).single.id, 42);
  });
}

List<int> archiveFromFiles(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

List<int> rewriteArchive(
  List<int> bytes, {
  bool removeSidecar = false,
  void Function(Map<String, dynamic>)? editSidecar,
  void Function(List<List<dynamic>>)? editSets,
}) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = <String, String>{};
  for (final file in archive) {
    if (removeSidecar && file.name == 'cardio_activities.json') continue;
    var content = utf8.decode(file.content as List<int>);
    if (file.name == 'cardio_activities.json' && editSidecar != null) {
      final json = jsonDecode(content) as Map<String, dynamic>;
      editSidecar(json);
      content = jsonEncode(json);
    }
    if (file.name == 'gym_sets.csv' && editSets != null) {
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      editSets(rows);
      content = const ListToCsvConverter(eol: '\n').convert(rows);
    }
    files[file.name] = content;
  }
  return archiveFromFiles(files);
}
