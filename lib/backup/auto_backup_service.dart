import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../main.dart';
import '../utils.dart';

class AutoBackupService {
  /// Performs an automatic backup if conditions are met
  /// Returns true if backup was performed, false otherwise
  static Future<bool> performAutoBackup() async {
    try {
      final settings = await db.settings.select().getSingle();

      // Check if auto-backup is enabled
      if (!settings.automaticBackups) {
        return false;
      }

      // Check if backup path is configured
      if (settings.backupPath == null || settings.backupPath!.isEmpty) {
        return false;
      }

      // Check if enough time has elapsed (24 hours)
      if (!shouldBackupNow(settings.lastAutoBackupTime)) {
        return false;
      }

      // Perform the backup
      await _createBackup(settings.backupPath!);

      // Update last backup time
      await db.settings.update().write(
            SettingsCompanion(
              lastAutoBackupTime: Value(DateTime.now()),
            ),
          );

      // Cleanup old backups according to retention policy
      await cleanupOldBackups(settings.backupPath!);

      return true;
    } catch (e) {
      // Silent fail for auto-backup
      return false;
    }
  }

  /// Performs a manual backup (ignores timing check)
  static Future<void> performManualBackup(String backupPath) async {
    await _createBackup(backupPath);

    await db.settings.update().write(
          SettingsCompanion(
            lastAutoBackupTime: Value(DateTime.now()),
          ),
        );

    await cleanupOldBackups(backupPath);
    toast('Backup completed successfully!');
  }

  /// Check if backup should be performed now
  static bool shouldBackupNow(DateTime? lastBackupTime) {
    if (lastBackupTime == null) {
      return true; // Never backed up before
    }

    final hoursSinceLastBackup =
        DateTime.now().difference(lastBackupTime).inHours;
    return hoursSinceLastBackup >= 24;
  }

  /// Creates a backup database file
  static Future<void> _createBackup(String backupPath) async {
    final now = DateTime.now();

    // Checkpoint WAL to ensure all changes are in the main database file
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    // Get the app database file
    final dbFolder = await getApplicationDocumentsDirectory();
    final sourceFile = File(p.join(dbFolder.path, 'jackedlog.sqlite'));

    // Determine backup filename
    final filename = _getBackupFileName(now);
    final backupFile = File(p.join(backupPath, filename));

    // Copy database file to backup location
    await sourceFile.copy(backupFile.path);
  }

  /// Generate backup filename based on date
  static String _getBackupFileName(DateTime date) {
    // Daily backup: jackedlog_backup_YYYY-MM-DD.db
    final dateFormat = DateFormat('yyyy-MM-dd');
    return 'jackedlog_backup_${dateFormat.format(date)}.db';
  }

  /// Cleanup old backups according to GFS retention policy
  static Future<void> cleanupOldBackups(String backupPath) async {
    try {
      final directory = Directory(backupPath);
      if (!await directory.exists()) {
        return;
      }

      final now = DateTime.now();
      final files = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .map((entity) => entity as File)
          .toList();

      // Parse backup files
      final backups = <DateTime, File>{};
      for (final file in files) {
        final filename = p.basename(file.path);
        final date = _parseDateFromFilename(filename);
        if (date != null) {
          backups[date] = file;
        }
      }

      if (backups.isEmpty) return;

      // Sort dates
      final sortedDates = backups.keys.toList()..sort((a, b) => b.compareTo(a));

      // Retention policy
      final filesToKeep = <String>{};

      // 1. Daily backups: Keep last 7 days
      for (int i = 0; i < 7 && i < sortedDates.length; i++) {
        final date = sortedDates[i];
        filesToKeep.add(backups[date]!.path);
      }

      // 2. Weekly backups: Keep last 4 weeks (Sunday of each week)
      final weeklySundays = <DateTime>{};
      for (final date in sortedDates) {
        if (date.isBefore(now.subtract(const Duration(days: 7)))) {
          // Find the Sunday of this week
          final sunday = date.subtract(Duration(days: date.weekday % 7));
          weeklySundays.add(DateTime(sunday.year, sunday.month, sunday.day));
        }
      }

      final sortedSundays = weeklySundays.toList()
        ..sort((a, b) => b.compareTo(a));
      for (int i = 0; i < 4 && i < sortedSundays.length; i++) {
        final sunday = sortedSundays[i];
        // Find closest backup to this Sunday
        final closestBackup = _findClosestBackup(sunday, backups.keys);
        if (closestBackup != null && backups.containsKey(closestBackup)) {
          filesToKeep.add(backups[closestBackup]!.path);
        }
      }

      // 3. Monthly backups: Keep last 12 months (last day of each month)
      final monthlyBackups = <DateTime>{};
      for (final date in sortedDates) {
        if (date.isBefore(now.subtract(const Duration(days: 35)))) {
          // Last day of month
          final lastDay = DateTime(date.year, date.month + 1, 0);
          monthlyBackups
              .add(DateTime(lastDay.year, lastDay.month, lastDay.day));
        }
      }

      final sortedMonthly = monthlyBackups.toList()
        ..sort((a, b) => b.compareTo(a));
      for (int i = 0; i < 12 && i < sortedMonthly.length; i++) {
        final monthEnd = sortedMonthly[i];
        // Find closest backup to end of month
        final closestBackup = _findClosestBackup(monthEnd, backups.keys);
        if (closestBackup != null && backups.containsKey(closestBackup)) {
          filesToKeep.add(backups[closestBackup]!.path);
        }
      }

      // Delete files not in retention policy
      for (final file in files) {
        if (!filesToKeep.contains(file.path)) {
          try {
            await file.delete();
          } catch (e) {
            // Ignore deletion errors
          }
        }
      }
    } catch (e) {
      // Silent fail for cleanup
    }
  }

  /// Find the closest backup date to target date
  static DateTime? _findClosestBackup(
      DateTime target, Iterable<DateTime> dates,) {
    if (dates.isEmpty) return null;

    DateTime? closest;
    int minDiff = 999999;

    for (final date in dates) {
      final diff = date.difference(target).inDays.abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = date;
      }
    }

    return closest;
  }

  /// Parse date from backup filename
  static DateTime? _parseDateFromFilename(String filename) {
    try {
      // Extract date from filename: jackedlog_backup_YYYY-MM-DD.db
      final regex = RegExp(r'jackedlog_backup_(\d{4}-\d{2}-\d{2})\.db');
      final match = regex.firstMatch(filename);

      if (match != null && match.groupCount >= 1) {
        final dateString = match.group(1);
        return DateTime.parse(dateString!);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
