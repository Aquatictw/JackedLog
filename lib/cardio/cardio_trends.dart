import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';

/// Stable source-local day when the original offset is known. Historical
/// timestamps without an offset use an explicitly labelled UTC recording day.
const cardioCalendarDaySql = '''
DATE(CASE
  WHEN started_at IS NOT NULL AND start_utc_offset_minutes IS NOT NULL
  THEN started_at + start_utc_offset_minutes * 60
  ELSE recorded_at END, 'unixepoch')''';

class CardioWeek {
  const CardioWeek({
    required this.start,
    required this.sessions,
    required this.recordingDateSessions,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.pairedMeters,
    required this.pairedSeconds,
  });
  final DateTime start;
  final int sessions;
  final int recordingDateSessions;
  final double? distanceMeters;
  final double? durationSeconds;
  final double? pairedMeters;
  final double? pairedSeconds;

  double? get secondsPerKm =>
      pairedMeters != null && pairedMeters! > 0 && pairedSeconds != null
          ? pairedSeconds! / pairedMeters! * 1000
          : null;
}

class CardioTrendFilter {
  const CardioTrendFilter(
      {this.sport, this.environment, this.timeBasis, this.name,});
  final String? sport;
  final String? environment;
  final String? timeBasis;
  final String? name;
  bool get supportsPace =>
      ['run', 'walk', 'cycle'].contains(sport) &&
      environment != null &&
      ['elapsed', 'timer', 'moving'].contains(timeBasis);
}

/// One row per effective activity in the recorded store. Legacy gym-set rows
/// are never unioned back into this query, so separate bouts count once each.
class CardioTrends {
  CardioTrends(this.database);
  final AppDatabase database;

  Selectable<CardioWeek> weekly({
    required DateTime through,
    int weeks = 12,
    CardioTrendFilter filter = const CardioTrendFilter(),
  }) {
    if (weeks < 1 || weeks > 52) throw ArgumentError('Choose 1–52 weeks');
    final today = DateTime.utc(through.year, through.month, through.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final start = monday.subtract(Duration(days: 7 * (weeks - 1)));
    final end = today.add(const Duration(days: 1));
    final predicates = <String>[];
    final parameters = <Variable>[
      Variable<String>(DateFormat('yyyy-MM-dd').format(start)),
      Variable<String>(DateFormat('yyyy-MM-dd').format(end)),
    ];
    for (final entry in {
      'sport': filter.sport,
      'environment': filter.environment,
      'duration_basis': filter.timeBasis,
      'name': filter.name,
    }.entries) {
      if (entry.value != null) {
        predicates.add('${entry.key} = ?');
        parameters.add(Variable<String>(entry.value));
      }
    }
    const validPair = 'distance_meters > 0 AND duration_seconds > 0';
    return database
        .customSelect(
      '''
      WITH activities AS (
        SELECT *, $cardioCalendarDaySql AS day,
          CASE WHEN started_at IS NOT NULL AND start_utc_offset_minutes IS NOT NULL THEN 0 ELSE 1 END AS recording_date
        FROM cardio_activities
      )
      SELECT DATE(day, '-' || ((CAST(STRFTIME('%w', day) AS INTEGER) + 6) % 7) || ' days') AS week,
        COUNT(*) AS sessions, SUM(recording_date) AS recording_dates,
        SUM(CASE WHEN distance_meters >= 0 THEN distance_meters END) AS meters,
        SUM(CASE WHEN duration_seconds >= 0 THEN duration_seconds END) AS seconds,
        SUM(CASE WHEN $validPair THEN distance_meters END) AS paired_meters,
        SUM(CASE WHEN $validPair THEN duration_seconds END) AS paired_seconds
      FROM activities WHERE day >= ? AND day < ?
        ${predicates.isEmpty ? '' : 'AND ${predicates.join(' AND ')}'}
      GROUP BY week ORDER BY week LIMIT 52
    ''',
      variables: parameters,
      readsFrom: {database.cardioActivities},
    )
        .map((row) {
      double? finite(String key) {
        final value = row.readNullable<double>(key);
        return value?.isFinite ?? false ? value : null;
      }

      return CardioWeek(
        start: DateTime.parse(row.read<String>('week')),
        sessions: row.read<int>('sessions'),
        recordingDateSessions: row.read<int>('recording_dates'),
        distanceMeters: finite('meters'),
        durationSeconds: finite('seconds'),
        pairedMeters: filter.supportsPace ? finite('paired_meters') : null,
        pairedSeconds: filter.supportsPace ? finite('paired_seconds') : null,
      );
    });
  }
}
