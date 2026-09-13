import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'backup/workout_archive.dart';
import 'database/database.dart';
import 'fivethreeone/fivethreeone_state.dart';
import 'main.dart';
import 'settings/settings_state.dart';
import 'utils.dart';

class ImportData extends StatelessWidget {
  const ImportData({
    required this.ctx,
    super.key,
  });
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        showModalBottomSheet(
          useRootNavigator: true,
          context: context,
          builder: (context) {
            return SafeArea(
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: const Text('Workouts'),
                    onTap: () => importWorkouts(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: const Text('Database'),
                    onTap: () => importDatabase(context),
                  ),
                ],
              ),
            );
          },
        );
      },
      icon: const Icon(Icons.upload),
      label: const Text('Import data'),
    );
  }

  Future<void> importDatabase(BuildContext context) async {
    Navigator.pop(context);

    FilePickerResult? result;
    try {
      if (kIsWeb) {
        await _importDatabaseWeb(context);
      } else {
        result = await _importDatabaseNativeWithResult(context);
      }
    } catch (e) {
      if (!ctx.mounted) return;

      print('ERROR [ImportDatabase] Import failed');
      print('  File path: ${result?.files.single.path ?? 'unknown'}');
      print('  Exception type: ${e.runtimeType}');
      print('  Message: $e');
      if (e is FileSystemException) {
        print('  OS Error: ${e.osError}');
      }

      toast(
        _getImportErrorMessage(e, result?.files.single.path),
        duration: const Duration(seconds: 10),
      );
    }
  }

  Future<FilePickerResult?> _importDatabaseNativeWithResult(
    BuildContext context,
  ) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return null;

    final File sourceFile = File(result.files.single.path!);

    if (!await sourceFile.exists()) {
      throw Exception('Selected file does not exist');
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    await db.close();

    // Delete WAL and SHM files to prevent corruption from old write-ahead logs
    final walFile = File(p.join(dbFolder.path, 'jackedlog.sqlite-wal'));
    final shmFile = File(p.join(dbFolder.path, 'jackedlog.sqlite-shm'));
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    await sourceFile.copy(p.join(dbFolder.path, 'jackedlog.sqlite'));
    db = AppDatabase();

    // Reset alarm sound and set backup time to now for imported database
    await db.settings.update().write(
          SettingsCompanion(
            alarmSound: const Value(''),
            lastAutoBackupTime: Value(DateTime.now()),
          ),
        );

    if (!ctx.mounted) return result;
    final settingsState = ctx.read<SettingsState>();
    await settingsState.init();

    if (!ctx.mounted) return result;
    await ctx.read<FiveThreeOneState>().refresh();

    if (!ctx.mounted) return result;
    Navigator.of(ctx, rootNavigator: true)
        .pushNamedAndRemoveUntil('/', (_) => false);

    return result;
  }

  Future<void> _importDatabaseWeb(BuildContext context) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final Uint8List? fileBytes = result.files.single.bytes;
    if (fileBytes == null) {
      throw Exception('Could not read file data');
    }

    throw Exception(
      'Database import on web requires manual data migration. Please export your data as CSV files and import those instead.',
    );
  }

  Future<void> importWorkouts(BuildContext context) async {
    Navigator.pop(context);

    String? filePath;
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null) return;
      filePath = result.files.single.path;

      // Read ZIP file
      Uint8List zipBytes;
      if (kIsWeb) {
        final fileBytes = result.files.single.bytes;
        if (fileBytes == null) throw Exception('Could not read file data');
        zipBytes = fileBytes;
      } else {
        if (result.files.single.bytes != null) {
          zipBytes = result.files.single.bytes!;
        } else {
          final file = File(result.files.single.path!);
          zipBytes = await file.readAsBytes();
        }
      }

      await WorkoutArchive(db).restore(zipBytes);

      if (!ctx.mounted) return;
      Navigator.pop(ctx);

      toast('Workout data imported successfully!');
    } catch (e) {
      if (!ctx.mounted) return;

      print('ERROR [ImportWorkouts] Import failed');
      print('  File path: $filePath');
      print('  Exception type: ${e.runtimeType}');
      print('  Message: $e');

      toast(
        _getImportErrorMessage(e, filePath),
        duration: const Duration(seconds: 10),
      );
    }
  }

  String _getImportErrorMessage(Object error, String? filePath) {
    if (error is FormatException) {
      return 'Import failed: Invalid file format. Ensure this is a valid backup file.';
    }
    if (error is FileSystemException) {
      final osError = error.osError;
      if (osError != null) {
        if (osError.errorCode == 13) {
          return 'Import failed: Storage permission denied.';
        }
        if (osError.errorCode == 2) return 'Import failed: File not found.';
      }
      return 'Import failed: Could not read file.';
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('missing required csv')) {
      return 'Import failed: Invalid backup file (missing workouts or sets data).';
    }
    if (msg.contains('insufficient columns')) {
      return 'Import failed: Backup file format is outdated or corrupted.';
    }
    if (msg.contains('csv is empty')) {
      return 'Import failed: Backup file contains no data.';
    }
    final firstLine = error.toString().split('\n').first;
    return 'Import failed: ${firstLine.length > 80 ? '${firstLine.substring(0, 80)}...' : firstLine}';
  }
}
