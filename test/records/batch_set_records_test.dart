import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/main.dart' as app;
import 'package:jackedlog/records/records_service.dart';

import '../test_helpers.dart';

class _SelectCounter extends QueryInterceptor {
  int count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    count++;
    return executor.runSelect(statement, args);
  }
}

void main() {
  late AppDatabase db;
  late _SelectCounter counter;

  setUp(() {
    counter = _SelectCounter();
    db = AppDatabase(NativeDatabase.memory().interceptWith(counter));
    app.db = db;
    clearPRCache();
  });

  tearDown(() async {
    await db.close();
  });

  Future<GymSet> add({
    String name = 'Treadmill',
    String unit = 'km',
    double distance = 5,
    double duration = 30,
    int? incline,
    double weight = 0,
    double reps = 0,
    bool cardio = true,
    bool warmup = false,
    bool hidden = false,
  }) =>
      db.gymSets.insertReturning(
        createTestSet(
          name: name,
          unit: unit,
          distance: distance,
          duration: duration,
          incline: incline,
          cardio: cardio,
          weight: weight,
          reps: reps,
          warmup: warmup,
        ).copyWith(hidden: Value(hidden)),
      );

  test('strict ties and runner-up comparison survive candidate exclusion',
      () async {
    final first = await add(distance: 4, duration: 20, incline: 2);
    final tied = await add(distance: 4, duration: 20, incline: 2);
    final farthest = await add(distance: 8, duration: 40, incline: 1);
    final fastest = await add(distance: 3, duration: 10, incline: 8);
    final results = await getBatchSetRecords([first, tied, farthest, fastest]);
    expect(results[first.id], isEmpty);
    expect(results[tied.id], isEmpty);
    expect(
      results[farthest.id],
      {RecordType.bestDuration, RecordType.bestDistance},
    );
    expect(results[fastest.id], {RecordType.bestSpeed, RecordType.bestIncline});
  });

  test(
      'first cardio bout retains legacy records and excludes hidden/warmup rows',
      () async {
    final first = await add(duration: 0, distance: 0);
    final warmup = await add(duration: 100, distance: 100, warmup: true);
    final hidden = await add(duration: 100, distance: 100, hidden: true);
    final results = await getBatchSetRecords([first, warmup, hidden]);
    expect(
      results[first.id],
      {
        RecordType.bestDuration,
        RecordType.bestDistance,
        RecordType.bestIncline,
      },
    );
    expect(results[warmup.id], isEmpty);
    expect(results[hidden.id], isEmpty);
    expect(calculateCardioRecords(first, [warmup, hidden]), results[first.id]);
  });

  test('strength and cardio with the same name cannot suppress each other',
      () async {
    final strength = await add(cardio: false, weight: 100, reps: 5);
    final cardio = await add(weight: 999, reps: 10);
    final results = await getBatchSetRecords([strength, cardio]);
    expect(
      results[strength.id],
      {RecordType.bestWeight, RecordType.bestVolume, RecordType.best1RM},
    );
    expect(
      results[cardio.id],
      {
        RecordType.bestDuration,
        RecordType.bestDistance,
        RecordType.bestSpeed,
        RecordType.bestIncline,
      },
    );
  });

  test('normalizes metres, kilometres and miles for distance and speed',
      () async {
    final kilometers = await add(distance: 1, duration: 10);
    final meters = await add(distance: 1100, duration: 10, unit: 'm');
    final miles = await add(distance: 1, duration: 10, unit: 'mi');
    final results = await getBatchSetRecords([kilometers, meters, miles]);
    expect(results[kilometers.id], isEmpty);
    expect(results[meters.id], isEmpty);
    expect(results[miles.id], {RecordType.bestDistance, RecordType.bestSpeed});
    expect(
      calculateCardioRecords(miles, [kilometers, meters]),
      results[miles.id],
    );

    final achievements = await checkForRecords(
      exerciseName: 'Treadmill',
      weight: 0,
      reps: 0,
      unit: 'mi',
      excludeSetId: miles.id,
      cardio: true,
      duration: 10,
      distance: 1,
    );
    expect(achievements.map((a) => a.type).toSet(), results[miles.id]);
    final distance =
        achievements.singleWhere((a) => a.type == RecordType.bestDistance);
    expect(distance.previousValue, closeTo(1.1 / 1.609344, 1e-9));
    expect(distance.unit, 'mi');
  });

  test('strength strict ties and zero/single-rep calculations remain unchanged',
      () async {
    final first = await add(cardio: false, weight: 100, reps: 5);
    final tied = await add(cardio: false, weight: 100, reps: 5);
    final singleRep = await add(cardio: false, weight: 120, reps: 1);
    final zeroRep = await add(cardio: false);
    final results = await getBatchSetRecords([first, tied, singleRep, zeroRep]);
    expect(results[first.id], isEmpty);
    expect(results[tied.id], isEmpty);
    expect(results[singleRep.id], {RecordType.bestWeight, RecordType.best1RM});
    expect(results[zeroRep.id], isEmpty);
  });

  test('batch summaries match an independent brute-force history scan',
      () async {
    final random = Random(943);
    final history = <GymSet>[];
    await db.transaction(() async {
      for (var i = 0; i < 180; i++) {
        history.add(
          await add(
            name: 'Mixed ${random.nextInt(6)}',
            cardio: random.nextBool(),
            unit: const ['km', 'm', 'mi'][random.nextInt(3)],
            distance: random.nextInt(8).toDouble(),
            duration: random.nextInt(6).toDouble(),
            incline: random.nextBool() ? null : random.nextInt(4),
            weight: (random.nextInt(6) - 1) * 20.0,
            reps: random.nextInt(12).toDouble(),
            warmup: random.nextInt(9) == 0,
            hidden: random.nextInt(9) == 0,
          ),
        );
      }
    });

    Map<RecordType, double> values(GymSet set) {
      if (set.cardio) {
        final distance = set.distance *
            (set.unit == 'mi'
                ? 1.609344
                : set.unit == 'm'
                    ? 0.001
                    : 1);
        return {
          RecordType.bestDuration: set.duration,
          RecordType.bestDistance: distance,
          RecordType.bestSpeed:
              set.duration <= 0 ? 0 : distance / set.duration * 60,
          RecordType.bestIncline: (set.incline ?? 0).toDouble(),
        };
      }
      final divisor = 1.0278 - 0.0278 * set.reps;
      return {
        RecordType.bestWeight: set.weight,
        RecordType.bestVolume: set.weight * set.reps,
        RecordType.best1RM: set.reps <= 0
            ? 0
            : set.reps == 1
                ? set.weight
                : set.weight >= 0
                    ? set.weight / divisor
                    : set.weight * divisor,
      };
    }

    final actual = await getBatchSetRecords(history);
    for (final set in history) {
      final expected = <RecordType>{};
      if (!set.hidden && !set.warmup) {
        final others = history
            .where(
              (other) =>
                  other.id != set.id &&
                  other.name == set.name &&
                  other.cardio == set.cardio &&
                  !other.hidden &&
                  !other.warmup,
            )
            .toList();
        if (set.cardio && others.isEmpty) {
          expected.addAll(
            {
              RecordType.bestDuration,
              RecordType.bestDistance,
              RecordType.bestIncline,
              if (set.duration > 0) RecordType.bestSpeed,
            },
          );
        } else {
          for (final entry in values(set).entries) {
            final best = others.fold<double>(
              0,
              (best, other) => max(best, values(other)[entry.key]!),
            );
            if (entry.value > best) expected.add(entry.key);
          }
        }
      }
      expect(actual[set.id], expected, reason: 'set ${set.id}');
    }
  });

  test('query count grows by chunks, not exercise or bout count', () async {
    final sets = <GymSet>[];
    // A transaction keeps the large regression fixture inexpensive.
    await db.transaction(() async {
      for (var i = 0; i < 401; i++) {
        sets.add(await add(name: 'Cardio $i'));
      }
    });
    counter.count = 0;
    expect(await getBatchSetRecords([]), isEmpty);
    expect(counter.count, 0);
    await getBatchSetRecords(sets.take(1).toList());
    expect(counter.count, 1);
    counter.count = 0;
    await getBatchSetRecords(sets.take(400).toList());
    expect(counter.count, 1);
    counter.count = 0;
    final records = await getBatchSetRecords(sets);
    expect(counter.count, 2);
    expect(records, hasLength(401));
    expect(records.values.every((types) => types.length == 4), isTrue);
  });
}
