import 'package:drift/drift.dart';

import '../constants.dart';
import '../database/database.dart';
import '../database/gym_sets.dart' show getPeriodStart;
import '../graph/cardio_data.dart';

typedef CardioRecords = ({
  double bestSpeed,
  double bestDistance,
  double bestDuration,
  DateTime? bestSpeedDate,
  DateTime? bestDistanceDate,
  DateTime? bestDurationDate,
  int? bestSpeedWorkoutId,
  int? bestDistanceWorkoutId,
  int? bestDurationWorkoutId,
});

/// Charts and records read recorded cardio once, regardless of its input source.
/// Legacy bouts are projected into this model by the transactional adapter.
class CardioAnalytics {
  CardioAnalytics(this.database);

  final AppDatabase database;

  static double _metersPerUnit(String unit) => switch (unit) {
        'm' => 1,
        'km' => 1000,
        'mi' => 1609.344,
        _ => throw ArgumentError.value(unit, 'unit', 'Expected m, km, or mi'),
      };

  /// Daily totals. The legacy `pace` selection is still speed, in units/hour.
  /// Only the selected measurement is aggregated; unavailable evidence is null.
  Future<List<CardioData>> getData({
    Period period = Period.days30,
    String name = '',
    CardioMetric metric = CardioMetric.pace,
    String target = 'km',
  }) async {
    final targetMeters = _metersPerUnit(target);
    const validSpeed = 'duration_seconds > 0 AND distance_meters > 0';
    final value = CustomExpression<double>(
      switch (metric) {
        CardioMetric.pace =>
          'SUM(CASE WHEN $validSpeed THEN distance_meters END) * 3600.0 / '
              'SUM(CASE WHEN $validSpeed THEN duration_seconds END) / $targetMeters',
        CardioMetric.distance => 'SUM(distance_meters) / $targetMeters',
        CardioMetric.duration => 'SUM(duration_seconds) / 60.0',
        CardioMetric.incline => 'AVG(incline_percent)',
        CardioMetric.inclineAdjustedPace =>
          'SUM(CASE WHEN $validSpeed AND incline_percent IS NOT NULL '
              'THEN distance_meters END) * '
              'POW(1.1, AVG(CASE WHEN $validSpeed THEN incline_percent END)) * 3600.0 / '
              'SUM(CASE WHEN $validSpeed AND incline_percent IS NOT NULL '
              'THEN duration_seconds END) / $targetMeters',
      },
    );
    final table = database.cardioActivities;
    final created = table.recordedAt.min();
    final identity = table.id.min();
    final count = table.id.count();
    const day = CustomExpression<String>(
      "DATE(recorded_at, 'unixepoch', 'localtime')",
    );
    final query = database.selectOnly(table)
      ..addColumns([value, created, table.workoutId, identity, count])
      ..where(table.name.equals(name))
      ..groupBy([day])
      ..orderBy([OrderingTerm(expression: day)]);
    final periodStart = getPeriodStart(period);
    if (periodStart != null) {
      query.where(table.recordedAt.isBiggerOrEqualValue(periodStart));
    }
    final rows = await query.get();
    return [
      for (final row in rows)
        if (row.read(value) case final measurement? when measurement.isFinite)
          CardioData(
            created: row.read(created)!.toLocal(),
            value: measurement,
            unit: target,
            workoutId: row.read(count) == 1 ? row.read(table.workoutId) : null,
            activityId: row.read(count) == 1 ? row.read(identity) : null,
          ),
    ];
  }

  Future<CardioRecords?> getRecords({
    required String name,
    required String targetUnit,
  }) async {
    final factor = _metersPerUnit(targetUnit);
    final activities = await (database.select(database.cardioActivities)
          ..where((row) => row.name.equals(name) & row.warmup.equals(false))
          ..orderBy([
            (row) => OrderingTerm.asc(row.recordedAt),
            (row) => OrderingTerm.asc(row.id),
          ]))
        .get();
    if (activities.isEmpty) return null;
    CardioActivity? speedActivity;
    CardioActivity? distanceActivity;
    CardioActivity? durationActivity;
    var bestSpeed = 0.0;
    var bestDistance = 0.0;
    var bestDuration = 0.0;
    for (final activity in activities) {
      final distance = activity.distanceMeters;
      final duration = activity.durationSeconds;
      if (distance != null &&
          (distanceActivity == null || distance / factor > bestDistance)) {
        bestDistance = distance / factor;
        distanceActivity = activity;
      }
      if (duration != null &&
          (durationActivity == null || duration / 60 > bestDuration)) {
        bestDuration = duration / 60;
        durationActivity = activity;
      }
      if (distance != null && duration != null && duration > 0) {
        final speed = distance / factor / duration * 3600;
        if (speedActivity == null || speed > bestSpeed) {
          bestSpeed = speed;
          speedActivity = activity;
        }
      }
    }
    return (
      bestSpeed: bestSpeed,
      bestDistance: bestDistance,
      bestDuration: bestDuration,
      bestSpeedDate: speedActivity?.recordedAt,
      bestDistanceDate: distanceActivity?.recordedAt,
      bestDurationDate: durationActivity?.recordedAt,
      bestSpeedWorkoutId: speedActivity?.workoutId,
      bestDistanceWorkoutId: distanceActivity?.workoutId,
      bestDurationWorkoutId: durationActivity?.workoutId,
    );
  }
}
