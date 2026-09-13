import 'package:drift/drift.dart';

import '../database/database.dart';

enum HistoryKind { workout, activity }

class ActivityHistoryEntry {
  const ActivityHistoryEntry(this.kind, this.id, this.date);
  final HistoryKind kind;
  final String id;
  final DateTime date;
  String get key => '${kind.name}:$id';
}

/// Apply filters before the mixed limit. Attached bouts appear inside their
/// workout, while standalone records have their own typed navigation identity.
class ActivityHistory {
  ActivityHistory(this.database);
  final AppDatabase database;

  Selectable<ActivityHistoryEntry> query({
    int limit = 100,
    int offset = 0,
    String search = '',
    DateTime? start,
    DateTime? end,
  }) {
    if (limit < 1 || offset < 0) throw ArgumentError('Invalid history page');
    final pattern =
        '%${search.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final filters = <String>[
      if (start != null) 'stamp >= ?',
      if (end != null) 'stamp <= ?',
    ];
    return database.customSelect(
      '''
      SELECT kind, identity, stamp FROM (
        SELECT 'workout' AS kind, CAST(w.id AS TEXT) AS identity,
          w.start_time AS stamp
        FROM workouts w
        WHERE COALESCE(w.name, '') LIKE ? ESCAPE '\\'
          OR EXISTS (SELECT 1 FROM gym_sets s WHERE s.workout_id = w.id
            AND s.hidden = 0 AND s.sequence >= 0 AND s.name LIKE ? ESCAPE '\\')
          OR EXISTS (SELECT 1 FROM cardio_activities a WHERE a.workout_id = w.id
            AND a.name LIKE ? ESCAPE '\\')
        UNION ALL
        SELECT 'activity', id, COALESCE(started_at, recorded_at)
        FROM cardio_activities WHERE workout_id IS NULL
          AND name LIKE ? ESCAPE '\\'
      ) ${filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}'}
      ORDER BY stamp DESC, kind, identity DESC LIMIT ? OFFSET ?
    ''',
      variables: [
        for (var i = 0; i < 4; i++) Variable<String>(pattern),
        if (start != null) Variable<DateTime>(start),
        if (end != null) Variable<DateTime>(end),
        Variable<int>(limit),
        Variable<int>(offset),
      ],
      readsFrom: {
        database.workouts,
        database.gymSets,
        database.cardioActivities,
      },
    ).map(
      (row) => ActivityHistoryEntry(
        HistoryKind.values.byName(row.read<String>('kind')),
        row.read<String>('identity'),
        DateTime.fromMillisecondsSinceEpoch(row.read<int>('stamp') * 1000),
      ),
    );
  }
}
