import 'dart:io';

import 'sqlite_validator.dart';

/// Filename validation pattern for backup files
final _validFilenamePattern = RegExp(r'^jackedlog_backup_\d{4}-\d{2}-\d{2}\.db$');

class BackupInfo {
  final String filename;
  final DateTime date;
  final int sizeBytes;
  final int? dbVersion;
  final bool isValid;

  BackupInfo({
    required this.filename,
    required this.date,
    required this.sizeBytes,
    this.dbVersion,
    required this.isValid,
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'sizeBytes': sizeBytes,
        'dbVersion': dbVersion,
        'isValid': isValid,
      };
}

class BackupService {
  final String dataDir;

  BackupService(this.dataDir);

  /// Store a backup from an incoming byte stream.
  /// Validates the SQLite file, names it by today's date, and runs retention cleanup.
  Future<BackupInfo> storeBackup(Stream<List<int>> fileStream) async {
    final tempFile = File('$dataDir/.upload_temp');

    try {
      // Stream bytes to temp file
      final sink = tempFile.openWrite();
      await sink.addStream(fileStream);
      await sink.close();

      // Validate
      final result = validateBackup(tempFile.path);
      if (!result.isValid) {
        tempFile.deleteSync();
        throw FormatException('Invalid SQLite file: ${result.error}');
      }

      // Generate filename from today's date
      final now = DateTime.now();
      final filename = 'jackedlog_backup_'
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}.db';

      final destFile = File('$dataDir/$filename');

      // Rename temp to final (overwrites same-day backup)
      tempFile.renameSync(destFile.path);

      // Run retention cleanup
      cleanupOldBackups();

      final stat = destFile.statSync();
      return BackupInfo(
        filename: filename,
        date: now,
        sizeBytes: stat.size,
        dbVersion: result.dbVersion,
        isValid: true,
      );
    } catch (e) {
      // Clean up temp file on any error
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      rethrow;
    }
  }

  /// List all backup files in the data directory, newest first.
  List<BackupInfo> listBackups() {
    final dir = Directory(dataDir);
    if (!dir.existsSync()) return [];

    final entries = dir.listSync().whereType<File>().where((f) {
      final name = f.uri.pathSegments.last;
      return _validFilenamePattern.hasMatch(name);
    }).toList();

    final backups = <BackupInfo>[];
    for (final file in entries) {
      final name = file.uri.pathSegments.last;
      final date = _parseDateFromFilename(name);
      if (date == null) continue;

      final stat = file.statSync();
      final result = validateBackup(file.path);

      backups.add(BackupInfo(
        filename: name,
        date: date,
        sizeBytes: stat.size,
        dbVersion: result.dbVersion,
        isValid: result.isValid,
      ));
    }

    backups.sort((a, b) => b.date.compareTo(a.date));
    return backups;
  }

  /// Get a backup file by filename. Returns null if not found or invalid name.
  File? getBackup(String filename) {
    if (!_isSafeFilename(filename)) return null;

    final file = File('$dataDir/$filename');
    return file.existsSync() ? file : null;
  }

  /// Delete a backup file by filename. Returns true if deleted, false if not found.
  bool deleteBackup(String filename) {
    if (!_isSafeFilename(filename)) return false;

    final file = File('$dataDir/$filename');
    if (!file.existsSync()) return false;

    file.deleteSync();
    return true;
  }

  /// Sum of all backup file sizes in bytes.
  int totalStorageBytes() {
    final dir = Directory(dataDir);
    if (!dir.existsSync()) return 0;

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => _validFilenamePattern.hasMatch(f.uri.pathSegments.last))
        .fold<int>(0, (sum, f) => sum + f.statSync().size);
  }

  /// GFS retention cleanup ported from app's AutoBackupService.
  /// - Keep all backups from last 7 days
  /// - Keep weekly backups (closest to Sunday) for 4 weeks
  /// - Keep monthly backups (closest to month-end) for 12 months
  /// - Always keep the most recent backup
  void cleanupOldBackups() {
    final dir = Directory(dataDir);
    if (!dir.existsSync()) return;

    final now = DateTime.now();
    final backups = <DateTime, File>{};

    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      final date = _parseDateFromFilename(name);
      if (date != null) {
        backups[date] = file;
      }
    }

    if (backups.isEmpty) return;

    final sortedDates = backups.keys.toList()..sort((a, b) => b.compareTo(a));
    final filesToKeep = <String>{};

    // Always keep the most recent backup
    filesToKeep.add(backups[sortedDates.first]!.path);

    // 1. Daily: keep last 7 days
    for (var i = 0; i < 7 && i < sortedDates.length; i++) {
      filesToKeep.add(backups[sortedDates[i]]!.path);
    }

    // 2. Weekly: keep closest to Sunday for last 4 weeks
    final weeklySundays = <DateTime>{};
    for (final date in sortedDates) {
      if (date.isBefore(now.subtract(const Duration(days: 7)))) {
        final sunday = date.subtract(Duration(days: date.weekday % 7));
        weeklySundays.add(DateTime(sunday.year, sunday.month, sunday.day));
      }
    }

    final sortedSundays = weeklySundays.toList()
      ..sort((a, b) => b.compareTo(a));
    for (var i = 0; i < 4 && i < sortedSundays.length; i++) {
      final closest = _findClosestBackup(sortedSundays[i], backups.keys);
      if (closest != null && backups.containsKey(closest)) {
        filesToKeep.add(backups[closest]!.path);
      }
    }

    // 3. Monthly: keep closest to month-end for last 12 months
    final monthEnds = <DateTime>{};
    for (final date in sortedDates) {
      if (date.isBefore(now.subtract(const Duration(days: 35)))) {
        final lastDay = DateTime(date.year, date.month + 1, 0);
        monthEnds.add(DateTime(lastDay.year, lastDay.month, lastDay.day));
      }
    }

    final sortedMonthEnds = monthEnds.toList()
      ..sort((a, b) => b.compareTo(a));
    for (var i = 0; i < 12 && i < sortedMonthEnds.length; i++) {
      final closest = _findClosestBackup(sortedMonthEnds[i], backups.keys);
      if (closest != null && backups.containsKey(closest)) {
        filesToKeep.add(backups[closest]!.path);
      }
    }

    // Delete files not in retention set
    for (final entry in backups.entries) {
      if (!filesToKeep.contains(entry.value.path)) {
        try {
          entry.value.deleteSync();
        } catch (_) {
          // Ignore deletion errors
        }
      }
    }
  }

  // --- Helpers ---

  /// Reject filenames with path separators or non-matching patterns.
  bool _isSafeFilename(String filename) {
    if (filename.contains('/') ||
        filename.contains('\\') ||
        filename.contains('..')) {
      return false;
    }
    return _validFilenamePattern.hasMatch(filename);
  }

  /// Parse date from backup filename: jackedlog_backup_YYYY-MM-DD.db
  DateTime? _parseDateFromFilename(String filename) {
    final match =
        RegExp(r'jackedlog_backup_(\d{4}-\d{2}-\d{2})\.db').firstMatch(filename);
    if (match == null) return null;
    try {
      return DateTime.parse(match.group(1)!);
    } catch (_) {
      return null;
    }
  }

  /// Find the backup date closest to the target date.
  DateTime? _findClosestBackup(DateTime target, Iterable<DateTime> dates) {
    if (dates.isEmpty) return null;

    DateTime? closest;
    var minDiff = 999999;

    for (final date in dates) {
      final diff = date.difference(target).inDays.abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = date;
      }
    }

    return closest;
  }
}
