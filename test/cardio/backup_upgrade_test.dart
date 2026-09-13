import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/backup/workout_archive.dart';
import 'package:jackedlog/cardio/activity_history.dart';
import 'package:jackedlog/cardio/cardio_activity_store.dart';
import 'package:jackedlog/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Opt-in compatibility test; never modifies or commits a personal backup.
void main() {
  final source = Platform.environment['JACKEDLOG_TEST_BACKUP'];
  test(
    'upgrade a backup copy, preserve legacy rows and round-trip activities',
    () async {
      final directory =
          await Directory.systemTemp.createTemp('cardio-upgrade-');
      final copy = await File(source!).copy('${directory.path}/copy.db');
      final original = sqlite.sqlite3.open(copy.path);
      final rawSets = original
          .select('SELECT * FROM gym_sets ORDER BY id')
          .map(Map<String, Object?>.from)
          .toList();
      final workoutCount =
          original.select('SELECT COUNT(*) AS n FROM workouts').single['n'];
      original.dispose();
      final database = AppDatabase(NativeDatabase(copy));
      final restored = AppDatabase(NativeDatabase.memory());
      try {
        final upgraded = await database
            .customSelect('SELECT * FROM gym_sets ORDER BY id')
            .get();
        expect(upgraded.map((r) => r.data).toList(), rawSets);
        expect((await database.select(database.workouts).get()).length,
            workoutCount,);
        final page = await ActivityHistory(database).query().get();
        expect(page.length, lessThanOrEqualTo(100));
        final activity = CardioActivity(
            id: 'upgrade-check',
            name: 'Upgrade check',
            sport: 'run',
            environment: 'outdoor',
            recordedAt: DateTime(2026, 9, 13),
            distanceMeters: 5000,
            durationSeconds: 1800,
            durationBasis: 'elapsed',
            warmup: false,
            source: 'manual',);
        await CardioActivityStore(database).save(activity);
        final zip = await WorkoutArchive(database).encode();
        await WorkoutArchive(restored).restore(zip);
        expect(await CardioActivityStore(restored).get(activity.id), activity);
        expect((await restored.select(restored.workouts).get()).length,
            workoutCount,);
        expect((await restored.select(restored.gymSets).get()).length,
            rawSets.length,);
        expect((await restored.select(restored.cardioActivities).get()).length,
            (await database.select(database.cardioActivities).get()).length,);
        await CardioActivityStore(restored).delete(activity.id);
        expect(await CardioActivityStore(restored).get(activity.id), isNull);
      } finally {
        await database.close();
        await restored.close();
        await directory.delete(recursive: true);
      }
    },
    skip: source == null
        ? 'Set JACKEDLOG_TEST_BACKUP to a local backup path'
        : false,
  );
}
