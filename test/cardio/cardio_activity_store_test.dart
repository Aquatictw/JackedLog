import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/cardio/cardio_activity_store.dart';
import 'package:jackedlog/cardio/cardio_analytics.dart';
import 'package:jackedlog/constants.dart';
import 'package:jackedlog/database/database.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase database;
  late CardioActivityStore store;
  final day = DateTime(2026, 9, 1, 12);

  CardioActivity run({String id = 'manual-run', double? distance = 5000}) =>
      CardioActivity(
        id: id,
        name: 'Recorded run',
        sport: 'run',
        environment: 'outdoor',
        recordedAt: day,
        startedAt: day,
        endedAt: day.add(const Duration(minutes: 30)),
        distanceMeters: distance,
        durationSeconds: 1800,
        durationBasis: 'timer',
        warmup: false,
        notes: 'Morning run',
        source: 'manual',
      );

  setUp(() async {
    database = await createTestDatabase();
    store = CardioActivityStore(database);
  });

  tearDown(() async => database.close());

  test('standalone activity saves and updates without a strength-set row',
      () async {
    await store.save(run());
    final saved = await store.get('manual-run');
    expect(saved, run());
    expect(
      await (database.select(database.gymSets)
            ..where((row) => row.name.equals('Recorded run')))
          .get(),
      isEmpty,
    );
    await store.save(
      saved!.copyWith(
        distanceMeters: const Value(null),
        notes: const Value(null),
      ),
    );
    expect((await store.get('manual-run'))!.distanceMeters, isNull);
    expect((await store.get('manual-run'))!.notes, isNull);
  });

  test(
      'legacy and standalone activities contribute to one chart without doubles',
      () async {
    await store.save(run());
    await database.gymSets.insertOne(
      createTestSet(
        name: 'Recorded run',
        cardio: true,
        unit: 'km',
        distance: 1,
        duration: 10,
      ).copyWith(created: Value(day)),
    );
    final analytics = CardioAnalytics(database);
    final distance = await analytics.getData(
      name: 'Recorded run',
      period: Period.allTime,
      metric: CardioMetric.distance,
    );
    expect(distance.single.value, 6);
    final speed = await analytics.getData(
      name: 'Recorded run',
      period: Period.allTime,
    );
    expect(speed.single.value, 9); // 6 km / 40 minutes.
    final records = await analytics.getRecords(
      name: 'Recorded run',
      targetUnit: 'km',
    );
    expect(records!.bestDistance, 5);
    expect(records.bestDuration, 30);
    expect(records.bestSpeed, 10);
    await store.delete('manual-run');
    expect(
      (await analytics.getData(
        name: 'Recorded run',
        period: Period.allTime,
        metric: CardioMetric.distance,
      ))
          .single
          .value,
      1,
    );
  });

  test('editing a linked activity updates its original bout in original units',
      () async {
    final id = await database.gymSets.insertOne(
      createTestSet(
        cardio: true,
        unit: 'mi',
        distance: 1,
        duration: 5.5,
      ),
    );
    final activity = (await store.get('legacy-bout:$id'))!;
    await store.save(
      activity.copyWith(
        distanceMeters: const Value(3218.688),
        durationSeconds: const Value(660),
        notes: const Value('Corrected'),
        sport: 'run',
        environment: 'indoor',
      ),
    );
    final bout = await (database.select(database.gymSets)
          ..where((row) => row.id.equals(id)))
        .getSingle();
    expect(bout.distance, 2);
    expect(bout.duration, 11);
    expect(bout.unit, 'mi');
    final updated = (await store.get(activity.id))!;
    expect(updated.distanceMeters, 3218.688);
    expect(updated.sport, 'run');
    expect(updated.notes, 'Corrected');
    await store.delete(activity.id);
    expect(await store.get(activity.id), isNull);
    expect(
      await (database.select(database.gymSets)
            ..where((row) => row.id.equals(id)))
          .getSingleOrNull(),
      isNull,
    );
  });

  test('unknown legacy measurements remain untouched when metadata is edited',
      () async {
    final id = await database.gymSets.insertOne(
      createTestSet(
        cardio: true,
        unit: 'unknown',
        distance: 12,
        duration: -1,
      ),
    );
    final activity = (await store.get('legacy-bout:$id'))!;
    expect(activity.distanceMeters, isNull);
    expect(activity.durationSeconds, isNull);
    await store.save(activity.copyWith(sport: 'walk'));
    final bout = await (database.select(database.gymSets)
          ..where((row) => row.id.equals(id)))
        .getSingle();
    expect(bout.distance, 12);
    expect(bout.duration, -1);
    expect((await store.get(activity.id))!.sport, 'walk');
  });

  test(
      'invalid measurements, timestamps and identity cannot overwrite activity',
      () async {
    final activity = run();
    await store.save(activity);
    for (final invalid in [
      activity.copyWith(distanceMeters: const Value(-1)),
      activity.copyWith(distanceMeters: const Value(double.infinity)),
      activity.copyWith(durationSeconds: const Value(double.nan)),
      activity.copyWith(
        endedAt: Value(day.subtract(const Duration(seconds: 1))),
      ),
      activity.copyWith(id: 'legacy-bout:1'),
      activity.copyWith(source: 'different-source'),
      activity.copyWith(workoutId: const Value(999999)),
    ]) {
      await expectLater(store.save(invalid), throwsArgumentError);
    }
    expect(await store.get(activity.id), activity);
  });

  test('deleted or hidden legacy bout cannot be resurrected by a stale edit',
      () async {
    final id = await database.gymSets.insertOne(createTestSet(cardio: true));
    final activity = (await store.get('legacy-bout:$id'))!;
    await (database.update(database.gymSets)..where((row) => row.id.equals(id)))
        .write(const GymSetsCompanion(hidden: Value(true)));
    await expectLater(store.save(activity), throwsArgumentError);
    expect(await store.get(activity.id), isNull);
  });
}
