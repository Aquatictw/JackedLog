import 'package:drift/drift.dart';

/// Hand-written additive v73 migration. Original sets remain exportable and
/// editable while recorded cardio acquires its own identity and measurements.
Future<void> migrateRecordedCardio(GeneratedDatabase db) async {
  await db.customStatement('''
    CREATE TABLE cardio_activities (
      id TEXT NOT NULL,
      legacy_gym_set_id INTEGER NULL UNIQUE,
      workout_id INTEGER NULL,
      name TEXT NOT NULL,
      sport TEXT NOT NULL DEFAULT 'other',
      environment TEXT NOT NULL DEFAULT 'unspecified',
      recorded_at INTEGER NOT NULL,
      started_at INTEGER NULL,
      ended_at INTEGER NULL,
      distance_meters REAL NULL,
      duration_seconds REAL NULL,
      duration_basis TEXT NOT NULL DEFAULT 'unspecified',
      incline_percent REAL NULL,
      warmup INTEGER NOT NULL DEFAULT 0 CHECK (warmup IN (0, 1)),
      notes TEXT NULL,
      source TEXT NOT NULL DEFAULT 'manual',
      PRIMARY KEY (id)
    )
  ''');
  await db.customStatement('''
    INSERT INTO cardio_activities ($_columns)
    SELECT ${_values('gym_sets')}
    FROM gym_sets WHERE ${_completed('gym_sets')}
  ''');
  await installCardioLegacyAdapter(db);
}

const _columns = '''
  id, legacy_gym_set_id, workout_id, name, recorded_at, distance_meters,
  duration_seconds, incline_percent, warmup, notes, source
''';

String _completed(String row) =>
    '$row.cardio = 1 AND $row.hidden = 0 AND $row.sequence >= 0';

String _values(String row) => '''
  'legacy-bout:' || $row.id, $row.id,
  (SELECT id FROM workouts WHERE id = $row.workout_id),
  $row.name, $row.created,
  CASE WHEN $row.distance >= 0 THEN
    CASE $row.unit
      WHEN 'km' THEN CASE WHEN $row.distance <= 1.7976931348623157e308 / 1000.0
        THEN $row.distance * 1000.0 END
      WHEN 'mi' THEN CASE WHEN $row.distance <= 1.7976931348623157e308 / 1609.344
        THEN $row.distance * 1609.344 END
      WHEN 'm' THEN CASE WHEN $row.distance <= 1.7976931348623157e308
        THEN $row.distance END
      ELSE NULL
    END
  ELSE NULL END,
  CASE WHEN $row.duration >= 0 AND $row.duration <= 1.7976931348623157e308 / 60.0
    THEN $row.duration * 60.0 ELSE NULL END,
  $row.incline, $row.warmup, $row.notes, 'legacy'
''';

/// Installed once on fresh creation or upgrade, never backfilled at startup.
/// Triggers keep existing editors, CSV imports and transactional bulk updates
/// coherent without adding a second app-level write that can fail separately.
Future<void> installCardioLegacyAdapter(GeneratedDatabase db) async {
  await db.customStatement('''
    CREATE INDEX cardio_activities_name_recorded
    ON cardio_activities(name, recorded_at)
  ''');
  await db.customStatement('''
    CREATE INDEX cardio_activities_workout_id
    ON cardio_activities(workout_id)
  ''');
  for (final event in ['INSERT', 'UPDATE']) {
    // INSERT OR REPLACE of a gym_set may not invoke its DELETE trigger. Clean
    // up a replacement template/incomplete row explicitly in the INSERT path.
    await db.customStatement('''
      CREATE TRIGGER cardio_legacy_${event.toLowerCase()}
      AFTER $event ON gym_sets
      BEGIN
        ${event == 'UPDATE' ? 'DELETE FROM cardio_activities WHERE legacy_gym_set_id = OLD.id AND OLD.id != NEW.id;' : ''}
        DELETE FROM cardio_activities
        WHERE legacy_gym_set_id = NEW.id AND NOT (${_completed('NEW')});
        INSERT INTO cardio_activities ($_columns)
        SELECT ${_values('NEW')} WHERE ${_completed('NEW')}
        ON CONFLICT(legacy_gym_set_id) DO UPDATE SET
          workout_id = excluded.workout_id,
          name = excluded.name,
          recorded_at = excluded.recorded_at,
          distance_meters = excluded.distance_meters,
          duration_seconds = excluded.duration_seconds,
          incline_percent = excluded.incline_percent,
          warmup = excluded.warmup,
          notes = excluded.notes;
      END
    ''');
  }
  await db.customStatement('''
    CREATE TRIGGER cardio_legacy_delete AFTER DELETE ON gym_sets
    BEGIN
      DELETE FROM cardio_activities WHERE legacy_gym_set_id = OLD.id;
    END
  ''');
  await db.customStatement('''
    CREATE TRIGGER cardio_workout_delete AFTER DELETE ON workouts
    BEGIN
      UPDATE cardio_activities SET workout_id = NULL WHERE workout_id = OLD.id;
    END
  ''');
}
