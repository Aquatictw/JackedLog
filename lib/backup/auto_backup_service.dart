import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../main.dart';


class AutoBackupService {
  /// Performs an automatic backup if conditions are met
  /// Returns true if backup was performed, false otherwise
  static Future<bool> performAutoBackup() async {
    try {
      final settings = await db.settings.select().getSingleOrNull();

      // Return early if settings not found
      if (settings == null) {
        print('⚠️ Auto-backup skipped: Settings not found');
        return false;
      }

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

      // Update last backup time and status
      await db.settings.update().write(
            SettingsCompanion(
              lastAutoBackupTime: Value(DateTime.now()),
              lastBackupStatus: const Value('success'),
            ),
          );

      // Cleanup old backups according to retention policy
      await cleanupOldBackups(settings.backupPath!);

      return true;
    } catch (e) {
      print('ERROR [AutoBackup] Backup failed');
      print('  Exception type: ${e.runtimeType}');
      print('  Message: $e');
      if (e is FileSystemException) {
        print('  OS Error: ${e.osError}');
        print('  Path: ${e.path}');
      }
      if (e is PlatformException) {
        print('  Platform code: ${e.code}');
        print('  Platform message: ${e.message}');
      }

      // Track failure status
      await db.settings.update().write(
            const SettingsCompanion(
              lastBackupStatus: Value('failed'),
            ),
          );

      return false;
    }
  }

  /// Performs a manual backup (ignores timing check)
  static Future<void> performManualBackup(String backupPath) async {
    await _createBackup(backupPath);

    await db.settings.update().write(
          SettingsCompanion(
            lastAutoBackupTime: Value(DateTime.now()),
            lastBackupStatus: const Value('success'),
          ),
        );

    await cleanupOldBackups(backupPath);
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
    print('🔵 Starting backup to: $backupPath');

    // Checkpoint WAL to ensure all changes are in the main database file
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    // Use native Android backup for SAF URIs
    if (Platform.isAndroid && backupPath.startsWith('content://')) {
      print('🟢 Using native Android SAF backup');
      const platform = MethodChannel('com.presley.jackedlog/android');
      try {
        await platform.invokeMethod('performBackup', {
          'backupUri': backupPath,
        });
        print('🟢 Native backup completed successfully');
      } on PlatformException catch (e) {
        print('🔴 Platform exception: ${e.code} - ${e.message}');
        throw Exception('Backup failed: ${e.message}');
      } catch (e) {
        print('🔴 Unexpected error: $e');
        rethrow;
      }
    } else {
      print('🟡 Using fallback file backup for path: $backupPath');
      // Fallback for non-SAF paths (shouldn't happen on Android 10+)
      final now = DateTime.now();
      final dbFolder = await getApplicationDocumentsDirectory();
      final sourceFile = File(p.join(dbFolder.path, 'jackedlog.sqlite'));
      final filename = _getBackupFileName(now);
      final backupFile = File(p.join(backupPath, filename));
      await sourceFile.copy(backupFile.path);
      print('🟡 Fallback backup completed');
    }
  }

  /// Generate backup filename based on date
  static String _getBackupFileName(DateTime date) {
    // Daily backup: jackedlog_backup_YYYY-MM-DD.db
    final dateFormat = DateFormat('yyyy-MM-dd');
    return 'jackedlog_backup_${dateFormat.format(date)}.db';
  }

  /// Cleanup old backups according to GFS retention policy
  static Future<void> cleanupOldBackups(String backupPath) async {
    // Use native Android cleanup for SAF URIs
    if (Platform.isAndroid && backupPath.startsWith('content://')) {
      try {
        const platform = MethodChannel('com.presley.jackedlog/android');
        await platform.invokeMethod('cleanupOldBackups', {
          'backupUri': backupPath,
        });
      } on PlatformException catch (e) {
        // Silent fail for cleanup
        print('Cleanup failed: ${e.message}');
      }
      return;
    }

    // Fallback for non-SAF paths
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
