import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/cardio/cardio_analytics.dart';
import 'package:jackedlog/constants.dart';
import 'package:jackedlog/database/database.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase database;
  final day = DateTime(2026, 8, 1, 10);

  setUp(() async {
    database = await createTestDatabase();
  });

  tearDown(() async => database.close());

  Future<void> bout({
    double distance = 1,
    double duration = 10,
    String unit = 'km',
    int? incline,
    bool cardio = true,
    bool hidden = false,
    bool warmup = false,
    DateTime? created,
  }) async {
    await database.gymSets.insertOne(
      createTestSet(
        name: 'Cardio query fixture',
        cardio: cardio,
        distance: distance,
        duration: duration,
        unit: unit,
        incline: incline,
        warmup: warmup,
      ).copyWith(created: Value(created ?? day), hidden: Value(hidden)),
    );
  }

  Future<List<double>> values(
    CardioMetric metric, {
    String target = 'km',
  }) async {
    final data = await CardioAnalytics(database).getData(
      name: 'Cardio query fixture',
      period: Period.allTime,
      metric: metric,
      target: target,
    );
    return data.map((point) => point.value).toList();
  }

  test('normalizes mixed units before computing daily distance and speed',
      () async {
    await bout(unit: 'mi', duration: 12);
    await bout(duration: 8);
    await bout(unit: 'm', distance: 500, duration: 5);

    expect(
      (await values(CardioMetric.distance)).single,
      closeTo(3.109344, 1e-8),
    );
    expect(
      (await values(CardioMetric.pace)).single,
      closeTo(3.109344 / 25 * 60, 1e-8),
    );
    expect(
      (await values(CardioMetric.distance, target: 'mi')).single,
      closeTo(3.109344 / 1.609344, 1e-8),
    );
    expect(
      (await values(CardioMetric.distance, target: 'm')).single,
      closeTo(3109.344, 1e-8),
    );
    expect(await values(CardioMetric.duration), [25]);
  });

  test('excludes hidden templates and strength rows but includes cardio warmup',
      () async {
    await bout();
    await bout(distance: 50, cardio: false);
    await bout(distance: 50, hidden: true);
    await bout(distance: 0.5, duration: 5, warmup: true);
    expect(await values(CardioMetric.distance), [1.5]);
    expect(await values(CardioMetric.duration), [15]);
  });

  test('undefined speed and incline produce no chart points', () async {
    await bout(distance: 0, duration: 0);
    expect(await values(CardioMetric.pace), isEmpty);
    expect(await values(CardioMetric.incline), isEmpty);
    expect(await values(CardioMetric.inclineAdjustedPace), isEmpty);
  });

  test('speed uses paired measurements without time-only or distance-only rows',
      () async {
    await bout(distance: 2);
    await bout(distance: 0, duration: 60);
    await bout(distance: 10, duration: 0);
    await bout(unit: 'unknown', distance: 100, duration: 60);
    expect(await values(CardioMetric.pace), [12]);
    expect(await values(CardioMetric.distance), [12]);
    expect(await values(CardioMetric.duration), [130]);
  });

  test('incline is independent of distance units and zero is a valid grade',
      () async {
    await bout(incline: 0, unit: 'mi');
    await bout(incline: 4);
    expect(await values(CardioMetric.incline, target: 'm'), [2]);
    expect(await values(CardioMetric.duration, target: 'mi'), [20]);
  });

  test('adjusted speed remains finite with known incline and mixed units',
      () async {
    await bout(unit: 'mi', incline: 0);
    await bout(incline: 0);
    expect(
      (await values(CardioMetric.inclineAdjustedPace)).single,
      closeTo(2.609344 / 20 * 60, 1e-8),
    );
  });

  test('daily points are chronological and retain a deterministic source time',
      () async {
    await bout(created: day.add(const Duration(days: 1)));
    await bout(created: day.add(const Duration(hours: 1)));
    await bout(created: day);
    final data = await CardioAnalytics(database).getData(
      name: 'Cardio query fixture',
      period: Period.allTime,
      metric: CardioMetric.distance,
    );
    expect(
      data.map((point) => point.created),
      [day, day.add(const Duration(days: 1))],
    );
    expect(data.map((point) => point.value), [2, 1]);
  });

  test('applies the requested lookback before aggregation', () async {
    await bout(distance: 100, created: DateTime(2000));
    await bout(created: DateTime.now());
    final data = await CardioAnalytics(database).getData(
      name: 'Cardio query fixture',
      metric: CardioMetric.distance,
    );
    expect(data.single.value, 1);
  });
}
