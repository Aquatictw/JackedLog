import 'dart:io';

import 'package:jackedlog_server/services/dashboard_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late DashboardService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('jackedlog_dashboard_');
    service = DashboardService(tempDir.path);
  });

  tearDown(() {
    service.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('reads bodyweight entries from backups without notes column', () {
    final backup = File('${tempDir.path}/jackedlog_backup_2026-06-14.db');
    _writeBackup(backup, workoutCount: 1, includeBodyweightNotes: false);

    expect(service.ensureOpen(), isTrue);

    final data = service.getBodyweightData();
    final entries = data['entries'] as List<Map<String, dynamic>>;

    expect(entries, hasLength(1));
    expect(entries.single['weight'], 80.0);
    expect(entries.single['notes'], isNull);
  });

  test('reopens same filename when the backup file changes', () {
    final backup = File('${tempDir.path}/jackedlog_backup_2026-06-14.db');
    _writeBackup(backup, workoutCount: 1);
    backup.setLastModifiedSync(DateTime(2026, 6, 14, 10));

    expect(service.ensureOpen(), isTrue);
    expect(service.getOverviewStats()['workoutCount'], 1);

    _writeBackup(backup, workoutCount: 3);
    backup.setLastModifiedSync(DateTime(2026, 6, 14, 11));

    expect(service.ensureOpen(), isTrue);
    expect(service.getOverviewStats()['workoutCount'], 3);
  });
}

void _writeBackup(
  File file, {
  required int workoutCount,
  bool includeBodyweightNotes = true,
}) {
  final db = sqlite3.open(file.path);
  try {
    db.execute('PRAGMA user_version = 66');
    db.execute('DROP TABLE IF EXISTS workouts');
    db.execute('DROP TABLE IF EXISTS gym_sets');
    db.execute('DROP TABLE IF EXISTS bodyweight_entries');
    db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        name TEXT,
        notes TEXT
      )
    ''');
    db.execute('''
      CREATE TABLE gym_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        weight REAL NOT NULL,
        reps REAL NOT NULL,
        created INTEGER NOT NULL,
        hidden INTEGER NOT NULL DEFAULT 0,
        cardio INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        workout_id INTEGER,
        sequence INTEGER NOT NULL DEFAULT 0
      )
    ''');
    db.execute('''
      CREATE TABLE bodyweight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL NOT NULL,
        unit TEXT NOT NULL,
        date INTEGER NOT NULL
        ${includeBodyweightNotes ? ', notes TEXT' : ''}
      )
    ''');

    final insertWorkout = db.prepare(
      'INSERT INTO workouts (start_time, end_time, name) VALUES (?, ?, ?)',
    );
    final insertSet = db.prepare('''
      INSERT INTO gym_sets (
        name, weight, reps, created, hidden, cardio, category, workout_id,
        sequence
      ) VALUES (?, ?, ?, ?, 0, 0, ?, ?, 0)
    ''');
    try {
      for (var i = 1; i <= workoutCount; i++) {
        final start = 1700000000 + i * 86400;
        insertWorkout.execute([start, start + 3600, 'Workout $i']);
        insertSet.execute(['Squat', 100.0, 5.0, start, 'Legs', i]);
      }
    } finally {
      insertWorkout.dispose();
      insertSet.dispose();
    }

    final bodyweightSql = includeBodyweightNotes
        ? 'INSERT INTO bodyweight_entries (weight, unit, date, notes) VALUES (?, ?, ?, ?)'
        : 'INSERT INTO bodyweight_entries (weight, unit, date) VALUES (?, ?, ?)';
    db.execute(
      bodyweightSql,
      includeBodyweightNotes
          ? [80.0, 'kg', 1700000000, 'morning']
          : [80.0, 'kg', 1700000000],
    );
  } finally {
    db.dispose();
  }
}
