import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/main.dart';
import 'package:jackedlog/settings/settings_state.dart';
import 'package:jackedlog/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ImportData extends StatelessWidget {
  final BuildContext ctx;

  const ImportData({
    super.key,
    required this.ctx,
  });

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

    try {
      if (kIsWeb) {
        await _importDatabaseWeb(context);
      } else {
        await _importDatabaseNative(context);
      }
    } catch (e, stackTrace) {
      if (!ctx.mounted) return;

      toast(
        'Failed to import database: ${e.toString()}',
        duration: Duration(seconds: 10),
      );
    }
  }

  Future<void> _importDatabaseNative(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    File sourceFile = File(result.files.single.path!);

    if (!await sourceFile.exists()) {
      throw Exception('Selected file does not exist');
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    await db.close();

    await sourceFile.copy(p.join(dbFolder.path, 'jackedlog.sqlite'));
    db = AppDatabase();

    await (db.settings.update())
        .write(const SettingsCompanion(alarmSound: Value('')));

    if (!ctx.mounted) return;
    final settingsState = ctx.read<SettingsState>();
    await settingsState.init();

    if (!ctx.mounted) return;
    Navigator.of(ctx, rootNavigator: true)
        .pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _importDatabaseWeb(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    Uint8List? fileBytes = result.files.single.bytes;
    if (fileBytes == null) {
      throw Exception('Could not read file data');
    }

    throw Exception(
      'Database import on web requires manual data migration. Please export your data as CSV files and import those instead.',
    );
  }

  Future<void> importWorkouts(BuildContext context) async {
    Navigator.pop(context);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null) return;

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

      // Extract ZIP
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Find workouts.csv and gym_sets.csv
      ArchiveFile? workoutsFile;
      ArchiveFile? setsFile;
      for (var file in archive) {
        if (file.name == 'workouts.csv') workoutsFile = file;
        if (file.name == 'gym_sets.csv') setsFile = file;
      }

      if (workoutsFile == null || setsFile == null) {
        throw Exception('Invalid backup file: missing required CSV files');
      }

      // Parse workouts CSV
      String workoutsCsvContent;
      try {
        workoutsCsvContent = utf8.decode(workoutsFile.content as List<int>, allowMalformed: false);
      } catch (e) {
        workoutsCsvContent = latin1.decode(workoutsFile.content as List<int>);
      }

      final workoutsRows = const CsvToListConverter(eol: "\n").convert(workoutsCsvContent);
      if (workoutsRows.isEmpty) throw Exception('Workouts CSV is empty');

      // Parse gym sets CSV
      String setsCsvContent;
      try {
        setsCsvContent = utf8.decode(setsFile.content as List<int>, allowMalformed: false);
      } catch (e) {
        setsCsvContent = latin1.decode(setsFile.content as List<int>);
      }

      final setsRows = const CsvToListConverter(eol: "\n").convert(setsCsvContent);
      if (setsRows.isEmpty) throw Exception('Gym sets CSV is empty');

      // Check CSV format version by examining header row
      final setsHeader = setsRows.first.map((e) => e.toString().toLowerCase()).toList();
      final hasBodyWeightColumn = setsHeader.contains('bodyweight');

      // Import workouts first (skip header row)
      final workoutsToInsert = workoutsRows.skip(1).map((row) {
        if (row.length < 6) {
          throw Exception('Workout row has insufficient columns: ${row.length}');
        }

        return WorkoutsCompanion(
          id: Value(int.tryParse(row[0]?.toString() ?? '0') ?? 0),
          startTime: Value(parseDate(row[1])),
          endTime: Value(_parseNullableDateTime(row[2])),
          planId: Value(_parseNullableInt(row[3])),
          name: Value(_parseNullableString(row[4])),
          notes: Value(_parseNullableString(row[5])),
        );
      });

      // Import gym sets (skip header row)
      final gymSets = setsRows.skip(1).map((row) {
        if (row.length < 6) {
          throw Exception('Set row has insufficient columns: ${row.length}');
        }

        final reps = _parseDouble(row[2], 'reps', setsRows.indexOf(row) + 1);
        final weight = _parseDouble(row[3], 'weight', setsRows.indexOf(row) + 1);

        // Adjust column indices based on CSV format version
        // Old format (v54 and earlier): had bodyWeight column at index 9
        // New format (v55+): removed bodyWeight column
        final offset = hasBodyWeightColumn ? 1 : 0;

        return GymSetsCompanion(
          id: Value(int.tryParse(row[0]?.toString() ?? '0') ?? 0),
          name: Value(row[1]?.toString() ?? ''),
          reps: reps,
          weight: weight,
          unit: Value(row[4]?.toString() ?? ''),
          created: Value(parseDate(row[5])),
          cardio: Value(parseBool(row.elementAtOrNull(6))),
          duration: Value(double.tryParse(row.elementAtOrNull(7)?.toString() ?? '0') ?? 0),
          distance: Value(double.tryParse(row.elementAtOrNull(8)?.toString() ?? '0') ?? 0),
          // Skip bodyWeight column (index 9) if present in old format
          incline: Value(_parseNullableInt(row.elementAtOrNull(9 + offset))),
          restMs: Value(_parseNullableInt(row.elementAtOrNull(10 + offset))),
          hidden: Value(parseBool(row.elementAtOrNull(11 + offset))),
          workoutId: Value(_parseNullableInt(row.elementAtOrNull(12 + offset))),
          planId: Value(_parseNullableInt(row.elementAtOrNull(13 + offset))),
          image: Value(_parseNullableString(row.elementAtOrNull(14 + offset))),
          category: Value(_parseNullableString(row.elementAtOrNull(15 + offset))),
          notes: Value(_parseNullableString(row.elementAtOrNull(16 + offset))),
          sequence: Value(int.tryParse(row.elementAtOrNull(17 + offset)?.toString() ?? '0') ?? 0),
          warmup: Value(parseBool(row.elementAtOrNull(18 + offset))),
          exerciseType: Value(_parseNullableString(row.elementAtOrNull(19 + offset))),
          brandName: Value(_parseNullableString(row.elementAtOrNull(20 + offset))),
          dropSet: Value(parseBool(row.elementAtOrNull(21 + offset))),
        );
      });

      // Delete existing data and import new data
      await db.workouts.deleteAll();
      await db.gymSets.deleteAll();
      await db.workouts.insertAll(workoutsToInsert);
      await db.gymSets.insertAll(gymSets);

      if (!ctx.mounted) return;
      Navigator.pop(ctx);

      toast('Workout data imported successfully!');
    } catch (e, stackTrace) {
      if (!ctx.mounted) return;

      toast(
        'Failed to import workouts: ${e.toString()}',
        duration: Duration(seconds: 10),
      );
    }
  }

  Value<double> _parseDouble(dynamic value, String fieldName, int rowNumber) {
    if (value is num) return Value(value.toDouble());
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed == null) {
        throw Exception('Invalid $fieldName value in row $rowNumber: $value');
      }
      return Value(parsed);
    }
    throw Exception(
      'Invalid $fieldName data type in row $rowNumber: ${value.runtimeType}',
    );
  }

  int? _parseNullableInt(dynamic value) {
    if (value == null || value == '') return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseNullableDouble(dynamic value) {
    if (value == null || value == '') return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _parseNullableString(dynamic value) {
    if (value == null || value == '') return null;
    return value.toString();
  }

  DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null || value == '') return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  bool parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    if (value is num) return value != 0;
    return false;
  }
}
