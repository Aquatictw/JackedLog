import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../cardio/cardio_activity_store.dart';
import '../database/database.dart';
import '../database/exercise_names.dart';

/// Versioned portable workout backup. Legacy CSVs remain readable by old apps.
/// All reads share a snapshot; restore validates before replacing data atomically.
class WorkoutArchive {
  WorkoutArchive(this.db);

  final AppDatabase db;

  Future<Uint8List> encode() => db.transaction(() async {
        // Export workouts table
        final workouts = await db.workouts.select().get();
        final List<List<dynamic>> workoutsData = [
          [
            'id',
            'startTime',
            'endTime',
            'planId',
            'name',
            'notes',
          ],
        ];
        for (final workout in workouts) {
          workoutsData.add([
            workout.id,
            workout.startTime.toIso8601String(),
            workout.endTime?.toIso8601String() ?? '',
            workout.planId ?? '',
            workout.name ?? '',
            workout.notes ?? '',
          ]);
        }
        final workoutsCsv =
            const ListToCsvConverter(eol: '\n').convert(workoutsData);

        // Export gym sets table
        final gymSets = await db.gymSets.select().get();
        final List<List<dynamic>> setsData = [
          [
            'id',
            'name',
            'reps',
            'weight',
            'unit',
            'created',
            'cardio',
            'duration',
            'distance',
            'incline',
            'restMs',
            'hidden',
            'workoutId',
            'planId',
            'image',
            'category',
            'notes',
            'sequence',
            'setOrder',
            'warmup',
            'exerciseType',
            'brandName',
            'cardio_metric',
            'dropSet',
            'supersetId',
            'supersetPosition',
          ]
        ];
        for (final gymSet in gymSets) {
          setsData.add([
            gymSet.id,
            gymSet.name,
            gymSet.reps,
            gymSet.weight,
            gymSet.unit,
            gymSet.created.toIso8601String(),
            gymSet.cardio,
            gymSet.duration,
            gymSet.distance,
            gymSet.incline ?? '',
            gymSet.restMs ?? '',
            gymSet.hidden,
            gymSet.workoutId ?? '',
            gymSet.planId ?? '',
            gymSet.image ?? '',
            gymSet.category ?? '',
            gymSet.notes ?? '',
            gymSet.sequence,
            gymSet.setOrder ?? '',
            gymSet.warmup,
            gymSet.exerciseType ?? '',
            gymSet.brandName ?? '',
            gymSet.cardioMetric ?? '',
            gymSet.dropSet,
            gymSet.supersetId ?? '',
            gymSet.supersetPosition ?? '',
          ]);
        }
        final setsCsv = const ListToCsvConverter(eol: '\n').convert(setsData);

        // Create ZIP archive
        final archive = Archive();
        archive.addFile(
          ArchiveFile(
            'workouts.csv',
            utf8.encode(workoutsCsv).length,
            utf8.encode(workoutsCsv),
          ),
        );
        archive.addFile(
          ArchiveFile(
            'gym_sets.csv',
            utf8.encode(setsCsv).length,
            utf8.encode(setsCsv),
          ),
        );

        final activities = await db.select(db.cardioActivities).get();
        final cardioBytes = utf8.encode(
          jsonEncode({
            'version': 1,
            'activities':
                activities.map((activity) => activity.toJson()).toList(),
          }),
        );
        archive.addFile(
          ArchiveFile(
            'cardio_activities.json',
            cardioBytes.length,
            cardioBytes,
          ),
        );
        return Uint8List.fromList(ZipEncoder().encode(archive));
      });

  Future<void> restore(List<int> bytes) async {
    // Extract ZIP
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = <String>{};
    for (final file in archive) {
      if (!names.add(file.name)) {
        throw FormatException('Duplicate archive file: ${file.name}');
      }
    }

    // Find workouts.csv and gym_sets.csv
    ArchiveFile? workoutsFile;
    ArchiveFile? setsFile;
    for (final file in archive) {
      if (file.name == 'workouts.csv') workoutsFile = file;
      if (file.name == 'gym_sets.csv') setsFile = file;
    }

    if (workoutsFile == null || setsFile == null) {
      throw Exception('Invalid backup file: missing required CSV files');
    }

    // Parse workouts CSV
    String workoutsCsvContent;
    try {
      workoutsCsvContent = utf8.decode(
        workoutsFile.content as List<int>,
        allowMalformed: false,
      );
    } catch (e) {
      workoutsCsvContent = latin1.decode(workoutsFile.content as List<int>);
    }

    final workoutsRows =
        const CsvToListConverter(eol: '\n').convert(workoutsCsvContent);
    if (workoutsRows.isEmpty) throw Exception('Workouts CSV is empty');

    // Parse gym sets CSV
    String setsCsvContent;
    try {
      setsCsvContent =
          utf8.decode(setsFile.content as List<int>, allowMalformed: false);
    } catch (e) {
      setsCsvContent = latin1.decode(setsFile.content as List<int>);
    }

    final setsRows =
        const CsvToListConverter(eol: '\n').convert(setsCsvContent);
    if (setsRows.isEmpty) throw Exception('Gym sets CSV is empty');

    // Check CSV format version by examining header row
    final setsHeader =
        setsRows.first.map((e) => e.toString().toLowerCase()).toList();
    final hasBodyWeightColumn = setsHeader.contains('bodyweight');
    final hasSupersetColumns = setsHeader.contains('supersetid');
    final hasSetOrderColumn = setsHeader.contains('setorder');
    final cardioMetricIndex = setsHeader.indexWhere(
      (column) => column == 'cardio_metric' || column == 'cardiometric',
    );
    final hasCardioMetricColumn = cardioMetricIndex != -1;

    // Import workouts first (skip header row)
    final workoutsToInsert = workoutsRows.skip(1).map((row) {
      if (row.length < 6) {
        throw Exception(
          'Workout row has insufficient columns: ${row.length}',
        );
      }

      return WorkoutsCompanion(
        id: Value(int.parse(row[0].toString())),
        startTime: Value(_parseDate(row[1])),
        endTime: Value(_parseNullableDateTime(row[2])),
        planId: Value(_parseNullableInt(row[3])),
        name: Value(_parseNullableString(row[4])),
        notes: Value(_parseNullableString(row[5])),
      );
    }).toList();

    // Import gym sets (skip header row)
    final gymSets = setsRows.skip(1).indexed.map((entry) {
      final (index, row) = entry;
      if (row.length < 6) {
        throw Exception('Set row has insufficient columns: ${row.length}');
      }

      final reps = _parseDouble(row[2], 'reps', index + 2);
      final weight = _parseDouble(row[3], 'weight', index + 2);

      // Adjust column indices based on CSV format version
      // Old format (v54 and earlier): had bodyWeight column at index 9
      // New format (v55+): removed bodyWeight column
      final offset = hasBodyWeightColumn ? 1 : 0;
      final cardioMetricOffset = hasCardioMetricColumn ? 1 : 0;

      return GymSetsCompanion(
        id: Value(int.parse(row[0].toString())),
        name: Value(normalizeExerciseName(row[1]?.toString() ?? '')),
        reps: reps,
        weight: weight,
        unit: Value(row[4]?.toString() ?? ''),
        created: Value(_parseDate(row[5])),
        cardio: Value(parseBool(row.elementAtOrNull(6))),
        duration: _parseDouble(
          _defaultZero(row.elementAtOrNull(7)),
          'duration',
          index + 2,
        ),
        distance: _parseDouble(
          _defaultZero(row.elementAtOrNull(8)),
          'distance',
          index + 2,
        ),
        // Skip bodyWeight column (index 9) if present in old format
        incline: Value(_parseNullableInt(row.elementAtOrNull(9 + offset))),
        restMs: Value(_parseNullableInt(row.elementAtOrNull(10 + offset))),
        hidden: Value(parseBool(row.elementAtOrNull(11 + offset))),
        workoutId: Value(_parseNullableInt(row.elementAtOrNull(12 + offset))),
        planId: Value(_parseNullableInt(row.elementAtOrNull(13 + offset))),
        image: Value(_parseNullableString(row.elementAtOrNull(14 + offset))),
        category: Value(_parseNullableString(row.elementAtOrNull(15 + offset))),
        notes: Value(_parseNullableString(row.elementAtOrNull(16 + offset))),
        sequence: Value(
          int.tryParse(
                row.elementAtOrNull(17 + offset)?.toString() ?? '0',
              ) ??
              0,
        ),
        setOrder: Value(
          hasSetOrderColumn
              ? _parseNullableInt(row.elementAtOrNull(18 + offset))
              : null,
        ),
        warmup: Value(
          parseBool(
            row.elementAtOrNull(hasSetOrderColumn ? 19 + offset : 18 + offset),
          ),
        ),
        exerciseType: Value(
          _parseNullableString(
            row.elementAtOrNull(hasSetOrderColumn ? 20 + offset : 19 + offset),
          ),
        ),
        brandName: Value(
          _parseNullableString(
            row.elementAtOrNull(hasSetOrderColumn ? 21 + offset : 20 + offset),
          ),
        ),
        cardioMetric: Value(
          hasCardioMetricColumn
              ? _parseNullableString(row.elementAtOrNull(cardioMetricIndex))
              : null,
        ),
        dropSet: Value(
          parseBool(
            row.elementAtOrNull(
              hasSetOrderColumn
                  ? 22 + offset + cardioMetricOffset
                  : 21 + offset + cardioMetricOffset,
            ),
          ),
        ),
        supersetId: Value(
          hasSupersetColumns
              ? _parseNullableString(
                  row.elementAtOrNull(
                    hasSetOrderColumn
                        ? 23 + offset + cardioMetricOffset
                        : 22 + offset + cardioMetricOffset,
                  ),
                )
              : null,
        ),
        supersetPosition: Value(
          hasSupersetColumns
              ? _parseNullableInt(
                  row.elementAtOrNull(
                    hasSetOrderColumn
                        ? 24 + offset + cardioMetricOffset
                        : 23 + offset + cardioMetricOffset,
                  ),
                )
              : null,
        ),
      );
    }).toList();

    if (workoutsToInsert.map((row) => row.id.value).toSet().length !=
            workoutsToInsert.length ||
        gymSets.map((row) => row.id.value).toSet().length != gymSets.length) {
      throw const FormatException('Duplicate workout or set id');
    }
    final activities = _parseActivities(archive, gymSets, workoutsToInsert);
    await db.transaction(() async {
      await db.delete(db.cardioActivities).go();
      await db.delete(db.planExercises).go();
      await db.delete(db.plans).go();
      await db.delete(db.gymSets).go();
      await db.delete(db.workouts).go();
      await db.batch((batch) {
        batch.insertAll(db.workouts, workoutsToInsert);
        batch.insertAll(db.gymSets, gymSets);
      });
      for (final activity in activities) {
        if (activity.legacyGymSetId == null) {
          await db.into(db.cardioActivities).insert(activity);
        } else {
          await (db.update(db.cardioActivities)
                ..where((row) => row.id.equals(activity.id)))
              .write(
            CardioActivitiesCompanion(
              sport: Value(activity.sport),
              environment: Value(activity.environment),
              startedAt: Value(activity.startedAt),
              startUtcOffsetMinutes: Value(activity.startUtcOffsetMinutes),
              endedAt: Value(activity.endedAt),
              durationBasis: Value(activity.durationBasis),
              source: Value(activity.source),
            ),
          );
        }
      }
    });
  }

  List<CardioActivity> _parseActivities(
    Archive archive,
    List<GymSetsCompanion> sets,
    List<WorkoutsCompanion> workouts,
  ) {
    final sidecar = archive.findFile('cardio_activities.json');
    // Pre-v73 archives are projected into activities by the legacy adapter.
    if (sidecar == null) return [];
    final document = jsonDecode(utf8.decode(sidecar.content as List<int>));
    if (document is! Map<String, dynamic> ||
        document['version'] != 1 ||
        document['activities'] is! List) {
      throw const FormatException('Unsupported cardio backup format');
    }
    final workoutsById = workouts.map((row) => row.id.value).toSet();
    final setsById = {for (final row in sets) row.id.value: row};
    final activityIds = <String>{};
    final legacyIds = <int>{};
    return (document['activities'] as List).map((json) {
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Invalid cardio activity');
      }
      final activity = CardioActivity.fromJson(json);
      validateCardioActivity(activity);
      if (!activityIds.add(activity.id)) {
        throw const FormatException('Duplicate cardio activity id');
      }
      if (activity.workoutId != null &&
          !workoutsById.contains(activity.workoutId)) {
        throw const FormatException(
          'Cardio activity references a missing workout',
        );
      }
      final legacyId = activity.legacyGymSetId;
      if (legacyId == null) {
        if (activity.id.startsWith('legacy-bout:') ||
            activity.source == 'legacy') {
          throw const FormatException(
            'Standalone activity has a legacy identity',
          );
        }
      } else {
        final set = setsById[legacyId];
        if (!legacyIds.add(legacyId) ||
            activity.id != 'legacy-bout:$legacyId' ||
            activity.source != 'legacy' ||
            set == null ||
            !set.cardio.value ||
            set.hidden.value ||
            set.sequence.value < 0) {
          throw const FormatException(
            'Cardio activity has an invalid legacy link',
          );
        }
        final expectedWorkoutId = workoutsById.contains(set.workoutId.value)
            ? set.workoutId.value
            : null;
        if (activity.workoutId != expectedWorkoutId) {
          throw const FormatException(
            'Cardio activity workout does not match its set',
          );
        }
        // CSV remains authoritative for linked measurements, name, notes and
        // recording time. The sidecar only restores independent metadata.
      }
      return activity;
    }).toList();
  }

  Value<double> _parseDouble(dynamic value, String fieldName, int rowNumber) {
    final parsed =
        value is num ? value.toDouble() : double.tryParse(value.toString());
    if (parsed == null || !parsed.isFinite) {
      throw FormatException(
        'Invalid $fieldName value in row $rowNumber: $value',
      );
    }
    return Value(parsed);
  }

  dynamic _defaultZero(dynamic value) =>
      value == null || value == '' ? 0 : value;

  int? _parseNullableInt(dynamic value) {
    if (value == null || value == '') return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _parseNullableString(dynamic value) {
    if (value == null || value == '') return null;
    return value.toString();
  }

  DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null || value == '') return null;
    if (value is DateTime) return value;
    return _parseDate(value);
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

  DateTime _parseDate(dynamic value) {
    final text = value.toString();
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    try {
      return DateFormat('dd.MM.yyyy').parseStrict(text);
    } on FormatException {
      throw FormatException('Invalid date: $text');
    }
  }
}
