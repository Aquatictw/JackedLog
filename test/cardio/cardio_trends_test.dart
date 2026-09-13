import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/backup/workout_archive.dart';
import 'package:jackedlog/cardio/cardio_activity_store.dart';
import 'package:jackedlog/cardio/cardio_trends.dart';
import 'package:jackedlog/database/database.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase database;
  late CardioActivityStore store;
  final date = DateTime.utc(2026, 9, 7, 12);
  const running = CardioTrendFilter(
      sport: 'run', environment: 'outdoor', timeBasis: 'elapsed',);
  CardioActivity activity(String id, double? meters, double? seconds) =>
      CardioActivity(
        id: id,
        name: 'Run',
        sport: 'run',
        environment: 'outdoor',
        source: 'manual',
        recordedAt: date,
        startedAt: date,
        startUtcOffsetMinutes: 480,
        durationBasis: 'elapsed',
        distanceMeters: meters,
        durationSeconds: seconds,
        warmup: false,
      );
  setUp(() async {
    database = await createTestDatabase();
    store = CardioActivityStore(database);
  });
  tearDown(() async {
    await database.close();
  });

  test('paired weighted pace, time-only volume and warm-ups count once',
      () async {
    await store.save(activity('short', 1000, 300));
    await store.save(activity('long', 4000, 1440).copyWith(warmup: true));
    await store.save(activity('time-only', null, 600));
    await store.save(activity('distance-only', 2000, null));
    await store
        .save(activity('indoor', 10000, 200).copyWith(environment: 'indoor'));
    await database.gymSets
        .insertOne(createTestSet(duration: 500, restMs: 600000));
    final week = (await CardioTrends(database)
            .weekly(through: date, filter: running)
            .get())
        .single;
    expect(week.sessions, 4);
    expect(week.distanceMeters, 7000);
    expect(week.durationSeconds, 2340);
    expect(week.secondsPerKm, 348); // 5:48, not a mean of per-run paces.
    expect(week.recordingDateSessions, 0);
    await store.save(activity('short', 1000, 300));
    expect(
        (await CardioTrends(database)
                .weekly(through: date, filter: running)
                .get())
            .single
            .sessions,
        4,);
  });

  test('source-local Sunday and Monday stay separate across offset changes',
      () async {
    final boundary = DateTime.utc(2026, 9, 7, 0, 30);
    await store.save(activity('west', 1000, 300).copyWith(
        startedAt: Value(boundary), startUtcOffsetMinutes: const Value(-420),),);
    await store.save(activity('east', 1000, 300).copyWith(
        startedAt: Value(boundary), startUtcOffsetMinutes: const Value(480),),);
    final weeks = await CardioTrends(database)
        .weekly(through: date, filter: running)
        .get();
    expect(weeks.map((w) => w.start),
        [DateTime(2026, 8, 31), DateTime(2026, 9, 7)],);
    expect(weeks.map((w) => w.sessions), [1, 1]);
  });

  test('legacy unknowns remain explicit; mixed groups never imply pace',
      () async {
    await database.gymSets.insertOne(createTestSet(
            name: 'Not inferred as a run',
            cardio: true,
            unit: 'mi',
            distance: 1,
            duration: 10,)
        .copyWith(created: Value(date)),);
    final week =
        (await CardioTrends(database).weekly(through: date).get()).single;
    expect(week.distanceMeters, 1609.344);
    expect(week.recordingDateSessions, 1);
    expect(week.secondsPerKm, isNull);
    expect(
        await CardioTrends(database)
            .weekly(through: date, filter: running)
            .get(),
        isEmpty,);
    final legacy =
        (await database.select(database.cardioActivities).get()).single;
    await store.save(legacy.copyWith(
        sport: 'run', environment: 'outdoor', durationBasis: 'elapsed',),);
    expect(
        (await CardioTrends(database)
                .weekly(through: date, filter: running)
                .get())
            .single
            .secondsPerKm,
        closeTo(600 / 1.609344, .00001),);
    expect(
        (await database.select(database.gymSets).get())
            .where((s) => s.name == legacy.name)
            .single
            .unit,
        'mi',);
  });

  test('multiple legacy bouts in mixed units count once per activity', () async {
    final workoutId = await database.workouts.insertOne(createTestWorkout());
    for (final unit in ['km', 'mi']) {
      await database.gymSets.insertOne(createTestSet(
        name: 'Cardio',
        cardio: true,
        unit: unit,
        distance: 1,
        duration: 10,
      ).copyWith(created: Value(date), workoutId: Value(workoutId)),);
    }
    final week = (await CardioTrends(database).weekly(through: date).get()).single;
    expect(week.sessions, 2);
    expect(week.distanceMeters, closeTo(2609.344, .00001));
    expect(week.durationSeconds, 1200);
    expect((await (database.select(database.gymSets)
      ..where((s) => s.workoutId.equals(workoutId))).get()).length, 2,);
  });

  test('unknown measurements stay absent and bounds apply before aggregation',
      () async {
    await store.save(activity('unknown', null, null));
    await store.save(activity('old', 10000, 1000)
        .copyWith(startedAt: Value(date.subtract(const Duration(days: 400)))),);
    final weeks = await CardioTrends(database)
        .weekly(through: date, weeks: 1, filter: running)
        .get();
    expect(weeks.single.sessions, 1);
    expect(weeks.single.distanceMeters, isNull);
    expect(weeks.single.durationSeconds, isNull);
    expect(weeks.single.secondsPerKm, isNull);
    expect(() => CardioTrends(database).weekly(through: date, weeks: 53),
        throwsArgumentError,);
  });

  test('source offset survives archive restore and cannot exist without start',
      () async {
    final original = activity('portable', 5000, 1800);
    await store.save(original);
    final saved = await store.get(original.id);
    final zip = await WorkoutArchive(database).encode();
    await store.delete(original.id);
    await WorkoutArchive(database).restore(zip);
    expect(await store.get(original.id), saved);
    await expectLater(
        store.save(original.copyWith(startedAt: const Value(null))),
        throwsArgumentError,);
    await expectLater(
        store.save(original.copyWith(startUtcOffsetMinutes: const Value(9999))),
        throwsArgumentError,);
  });
}
