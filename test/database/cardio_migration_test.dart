import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/database/schema.dart';
import 'package:jackedlog/database/schema_v72.dart';

GymSetsCompanion bout({int? id, int? workoutId}) => GymSetsCompanion.insert(
      id: id == null ? const Value.absent() : Value(id),
      name: 'Run',
      reps: 0,
      weight: 0,
      unit: 'km',
      created: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      cardio: const Value(true),
      duration: const Value(5.5),
      distance: const Value(1.25),
      workoutId: Value(workoutId),
    );

/// Validate the upgrade itself against the full exported schema. The existing
/// beforeOpen hook drops bodyweight_entries.notes, an unrelated historical
/// mismatch with its Drift definition. The file/reopen test below exercises
/// the complete production strategy, including that hook.
class _UpgradeOnlyDatabase extends AppDatabase {
  _UpgradeOnlyDatabase(super.executor);

  @override
  MigrationStrategy get migration {
    final strategy = super.migration;
    return MigrationStrategy(
      onCreate: strategy.onCreate,
      onUpgrade: strategy.onUpgrade,
    );
  }
}

void main() {
  test('v73 gains nullable source offset without guessing old time zones', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(73);
    final db = _UpgradeOnlyDatabase(connection.executor);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 74);
  });

  test('v72 migration matches the v74 schema snapshot', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(72);
    final db = _UpgradeOnlyDatabase(connection.executor);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 74);
  });

  test('v72 file migration preserves rows and normalizes recorded bouts',
      () async {
    final directory = await Directory.systemTemp.createTemp('cardio-v72-');
    final file = File('${directory.path}/workouts.sqlite');
    addTearDown(() => directory.delete(recursive: true));
    final old = DatabaseAtV72(NativeDatabase(file));
    await old.customStatement(
      'INSERT INTO workouts (id, start_time) VALUES (1, 1700000000)',
    );
    for (final row in [
      [1, 'km', 1.25, 5.5, 0, 0, 1, 0],
      [2, 'mi', 1.0, 8.25, 0, 0, 1, 1],
      [3, 'm', 500.0, 2.75, 0, 0, 1, 0],
      [4, 'km', 0.0, 0.0, 0, 0, 1, 0],
      [5, 'yards', 100.0, 1.0, 0, 0, 1, 0],
      [6, 'km', -3.0, -2.0, 0, 0, 1, 0],
      [7, 'km', 1.0, 5.0, 1, 0, 1, 0], // hidden template
      [8, 'km', 1.0, 5.0, 0, -1, 1, 0], // incomplete
      [9, 'kg', 0.0, 0.0, 0, 0, 0, 0], // strength
    ]) {
      await old.customStatement(
        '''
        INSERT INTO gym_sets
          (id, name, created, unit, distance, duration, hidden, sequence,
           cardio, warmup, reps, weight, workout_id, notes, incline)
        VALUES (?, 'Run', 1700000000, ?, ?, ?, ?, ?, ?, ?, 0, 0, 1,
          'Original notes', 3)
      ''',
        row,
      );
    }
    final original =
        (await old.customSelect('SELECT * FROM gym_sets ORDER BY id').get())
            .map((row) => row.data)
            .toList();
    expect(
      (await old.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      72,
    );
    await old.close();

    var migrated = AppDatabase(NativeDatabase(file));
    var activities = await (migrated.select(migrated.cardioActivities)
          ..orderBy([(a) => OrderingTerm(expression: a.legacyGymSetId)]))
        .get();
    expect(activities, hasLength(6));
    expect(
      activities.map((a) => a.id),
      List.generate(6, (index) => 'legacy-bout:${index + 1}'),
    );
    expect(
      activities.map((a) => a.distanceMeters),
      [1250.0, 1609.344, 500.0, 0.0, null, null],
    );
    expect(
      activities.map((a) => a.durationSeconds),
      [330.0, 495.0, 165.0, 0.0, 60.0, null],
    );
    expect(activities[1].warmup, isTrue);
    for (final activity in activities) {
      expect(activity.recordedAt.millisecondsSinceEpoch, 1700000000000);
      expect(activity.startedAt, isNull);
      expect(activity.endedAt, isNull);
      expect(activity.durationBasis, 'unspecified');
      expect(activity.environment, 'unspecified');
      expect(activity.sport, 'other');
      expect(activity.inclinePercent, 3.0);
      expect(activity.notes, 'Original notes');
      expect(activity.source, 'legacy');
      expect(activity.workoutId, 1);
    }
    expect(
      (await migrated.customSelect('SELECT * FROM gym_sets ORDER BY id').get())
          .map((row) => row.data)
          .toList(),
      original,
    );
    final firstRead = activities;
    await migrated.close();
    migrated = AppDatabase(NativeDatabase(file));
    activities = await (migrated.select(migrated.cardioActivities)
          ..orderBy([(a) => OrderingTerm(expression: a.legacyGymSetId)]))
        .get();
    expect(activities, firstRead, reason: 'Reopen must not duplicate backfill');
    expect(
      (await migrated.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      74,
    );
    await migrated.close();
  });

  group('Legacy write adapter', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<CardioActivity?> activity(int setId) =>
        (db.select(db.cardioActivities)
              ..where((a) => a.legacyGymSetId.equals(setId)))
            .getSingleOrNull();

    test('fresh install updates metrics and preserves independent metadata',
        () async {
      final id = await db.into(db.gymSets).insert(bout());
      final start = DateTime.fromMillisecondsSinceEpoch(1699999670000);
      await (db.update(db.cardioActivities)
            ..where((a) => a.legacyGymSetId.equals(id)))
          .write(
        CardioActivitiesCompanion(
          sport: const Value('running'),
          environment: const Value('outdoor'),
          startedAt: Value(start),
          durationBasis: const Value('elapsed'),
        ),
      );
      await (db.update(db.gymSets)..where((s) => s.id.equals(id))).write(
        const GymSetsCompanion(
          name: Value('Trail run'),
          unit: Value('mi'),
          distance: Value(2),
          duration: Value(20.25),
          warmup: Value(true),
          notes: Value('Edited'),
        ),
      );
      final updated = (await activity(id))!;
      expect(updated.id, 'legacy-bout:$id');
      expect(updated.distanceMeters, 3218.688);
      expect(updated.durationSeconds, 1215);
      expect(updated.name, 'Trail run');
      expect(updated.notes, 'Edited');
      expect(updated.warmup, isTrue);
      expect(updated.sport, 'running');
      expect(updated.environment, 'outdoor');
      expect(updated.startedAt, start);
      expect(updated.durationBasis, 'elapsed');
    });

    test('undo, recomplete, hide, type change and deletion stay coherent',
        () async {
      final id = await db.into(db.gymSets).insert(bout());
      Future<void> change(GymSetsCompanion value) =>
          (db.update(db.gymSets)..where((s) => s.id.equals(id))).write(value);
      await change(const GymSetsCompanion(sequence: Value(-1)));
      expect(await activity(id), isNull);
      await change(const GymSetsCompanion(sequence: Value(0)));
      expect((await activity(id))!.id, 'legacy-bout:$id');
      await change(const GymSetsCompanion(hidden: Value(true)));
      expect(await activity(id), isNull);
      await change(const GymSetsCompanion(hidden: Value(false)));
      expect(await activity(id), isNotNull);
      await change(const GymSetsCompanion(cardio: Value(false)));
      expect(await activity(id), isNull);
      await change(const GymSetsCompanion(cardio: Value(true)));
      expect(await activity(id), isNotNull);
      await (db.delete(db.gymSets)..where((s) => s.id.equals(id))).go();
      expect(await activity(id), isNull);
    });

    test('legacy replace imports update existing identity and remove templates',
        () async {
      final id = await db.into(db.gymSets).insert(bout());
      await (db.update(db.cardioActivities)
            ..where((a) => a.legacyGymSetId.equals(id)))
          .write(const CardioActivitiesCompanion(sport: Value('running')));
      await db.into(db.gymSets).insert(
            bout(id: id).copyWith(
              distance: const Value(3),
            ),
            mode: InsertMode.insertOrReplace,
          );
      expect((await activity(id))!.distanceMeters, 3000);
      expect((await activity(id))!.sport, 'running');
      await db.into(db.gymSets).insert(
            bout(id: id).copyWith(
              hidden: const Value(true),
            ),
            mode: InsertMode.insertOrReplace,
          );
      expect(await activity(id), isNull);
    });

    test('workout deletion clears association and preserves standalone cardio',
        () async {
      final workout = await db
          .into(db.workouts)
          .insert(WorkoutsCompanion.insert(startTime: DateTime.now()));
      final id = await db.into(db.gymSets).insert(bout(workoutId: workout));
      await db.into(db.cardioActivities).insert(
            CardioActivitiesCompanion.insert(
              id: 'manual:1',
              name: 'Independent run',
              recordedAt: DateTime.now(),
              workoutId: Value(workout),
            ),
          );
      await (db.delete(db.workouts)..where((w) => w.id.equals(workout))).go();
      expect((await activity(id))!.workoutId, isNull);
      await (db.update(db.gymSets)..where((s) => s.id.equals(id)))
          .write(const GymSetsCompanion(notes: Value('Later edit')));
      final records = await db.select(db.cardioActivities).get();
      expect(records, hasLength(2));
      expect(records.every((a) => a.workoutId == null), isTrue);
      await (db.delete(db.gymSets)..where((s) => s.id.equals(id))).go();
      expect(
        (await db.select(db.cardioActivities).get()).single.id,
        'manual:1',
      );
    });

    test('transaction failure rolls back both legacy and cardio changes',
        () async {
      final id = await db.into(db.gymSets).insert(bout());
      final before = await activity(id);
      await expectLater(
        db.transaction(() async {
          await (db.update(db.gymSets)..where((s) => s.id.equals(id)))
              .write(const GymSetsCompanion(distance: Value(99)));
          await db.into(db.gymSets).insert(bout());
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(await activity(id), before);
      expect(await db.select(db.cardioActivities).get(), hasLength(1));
      expect(
        (await (db.select(db.gymSets)..where((s) => s.id.equals(id)))
                .getSingle())
            .distance,
        1.25,
      );
    });

    test('overflowing normalized metrics stay unknown and originals survive',
        () async {
      final id = await db.into(db.gymSets).insert(
            bout().copyWith(
              distance: const Value(1.0e308),
              duration: const Value(1.0e308),
            ),
          );
      expect((await activity(id))!.distanceMeters, isNull);
      expect((await activity(id))!.durationSeconds, isNull);
      final original = await (db.select(db.gymSets)
            ..where((s) => s.id.equals(id)))
          .getSingle();
      expect(original.distance, 1.0e308);
      expect(original.duration, 1.0e308);
    });

    test('changing a legacy primary key removes the previous association',
        () async {
      final id = await db.into(db.gymSets).insert(bout());
      final newId = id + 10000;
      await (db.update(db.gymSets)..where((s) => s.id.equals(id)))
          .write(GymSetsCompanion(id: Value(newId)));
      expect(await activity(id), isNull);
      expect((await activity(newId))!.id, 'legacy-bout:$newId');
      expect(await db.select(db.cardioActivities).get(), hasLength(1));
    });

    test('cardio streams invalidate for legacy edits and workout deletes',
        () async {
      final stream = StreamIterator(db.select(db.cardioActivities).watch());
      addTearDown(stream.cancel);
      expect(await stream.moveNext(), isTrue);
      expect(stream.current, isEmpty);
      final workout = await db
          .into(db.workouts)
          .insert(WorkoutsCompanion.insert(startTime: DateTime.now()));
      final id = await db.into(db.gymSets).insert(bout(workoutId: workout));
      expect(
        await stream.moveNext().timeout(const Duration(seconds: 3)),
        isTrue,
      );
      expect(stream.current.single.workoutId, workout);
      await (db.update(db.gymSets)..where((s) => s.id.equals(id)))
          .write(const GymSetsCompanion(distance: Value(2)));
      expect(
        await stream.moveNext().timeout(const Duration(seconds: 3)),
        isTrue,
      );
      expect(stream.current.single.distanceMeters, 2000);
      await (db.delete(db.workouts)..where((w) => w.id.equals(workout))).go();
      expect(
        await stream.moveNext().timeout(const Duration(seconds: 3)),
        isTrue,
      );
      expect(stream.current.single.workoutId, isNull);
    });
  });
}
