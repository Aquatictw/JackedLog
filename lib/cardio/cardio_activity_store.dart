import 'package:drift/drift.dart';

import '../database/database.dart';

/// Validates recorded measurements without inventing missing sensor evidence.
void validateCardioActivity(CardioActivity activity) {
  for (final field in {
    'id': activity.id,
    'name': activity.name,
    'source': activity.source,
    'sport': activity.sport,
    'environment': activity.environment,
    'durationBasis': activity.durationBasis,
  }.entries) {
    if (field.value.trim().isEmpty) {
      throw ArgumentError.value(field.value, field.key, 'Must not be empty');
    }
  }
  final legacyId = activity.legacyGymSetId;
  if (legacyId != null) {
    if (activity.id != 'legacy-bout:$legacyId' || activity.source != 'legacy') {
      throw ArgumentError(
        'Legacy activities must retain their source identity',
      );
    }
  } else if (activity.id.startsWith('legacy-bout:') ||
      activity.source == 'legacy') {
    throw ArgumentError('Legacy identity requires a linked bout');
  }
  for (final measurement in {
    'distanceMeters': activity.distanceMeters,
    'durationSeconds': activity.durationSeconds,
  }.entries) {
    final value = measurement.value;
    if (value != null && (!value.isFinite || value < 0)) {
      throw ArgumentError.value(
        value,
        measurement.key,
        'Must be finite and >= 0',
      );
    }
  }
  if (activity.inclinePercent?.isFinite == false) {
    throw ArgumentError.value(activity.inclinePercent, 'inclinePercent');
  }
  if (activity.endedAt != null &&
      (activity.startedAt == null ||
          activity.endedAt!.isBefore(activity.startedAt!))) {
    throw ArgumentError(
      'End time requires a start time and must not precede it',
    );
  }
}

/// Owns recorded cardio writes during the legacy-bout migration.
///
/// Standalone activities have no weight/reps row. Linked activities route shared
/// measurements through the existing bout so all old editors and exports agree;
/// SQLite projects those writes atomically into the recorded activity model.
class CardioActivityStore {
  CardioActivityStore(this.database);

  final AppDatabase database;

  Future<CardioActivity?> get(String id) =>
      (database.select(database.cardioActivities)
            ..where((activity) => activity.id.equals(id)))
          .getSingleOrNull();

  Future<void> save(CardioActivity activity) async {
    validateCardioActivity(activity);
    await database.transaction(() async {
      if (activity.workoutId != null) {
        final workout = await (database.select(database.workouts)
              ..where((workout) => workout.id.equals(activity.workoutId!)))
            .getSingleOrNull();
        if (workout == null) throw ArgumentError('Workout does not exist');
      }

      final existing = await get(activity.id);
      if (existing != null &&
          (existing.legacyGymSetId != activity.legacyGymSetId ||
              existing.source != activity.source)) {
        throw ArgumentError('An activity cannot change its source identity');
      }

      final legacyId = activity.legacyGymSetId;
      if (legacyId == null) {
        await database.into(database.cardioActivities).insertOnConflictUpdate(
              activity.toCompanion(false),
            );
        return;
      }

      final bout = await (database.select(database.gymSets)
            ..where((set) => set.id.equals(legacyId)))
          .getSingleOrNull();
      if (bout == null || !bout.cardio || bout.hidden || bout.sequence < 0) {
        throw ArgumentError('The linked bout is not a recorded cardio entry');
      }
      const metersPerUnit = {'m': 1.0, 'km': 1000.0, 'mi': 1609.344};
      final factor = metersPerUnit[bout.unit];
      if (factor == null && activity.distanceMeters != null) {
        throw ArgumentError('Correct the legacy distance unit before editing');
      }
      final incline = activity.inclinePercent;
      if (incline != null && incline != incline.roundToDouble()) {
        throw ArgumentError('Legacy bouts support whole-number incline only');
      }
      // Null legacy measurements retain their raw evidence: invalid/unknown
      // input is not silently overwritten with a guessed zero or unit.
      await (database.update(database.gymSets)
            ..where((set) => set.id.equals(legacyId)))
          .write(
        GymSetsCompanion(
          name: Value(activity.name),
          created: Value(activity.recordedAt),
          workoutId: Value(activity.workoutId),
          distance: activity.distanceMeters == null
              ? const Value.absent()
              : Value(activity.distanceMeters! / factor!),
          duration: activity.durationSeconds == null
              ? const Value.absent()
              : Value(activity.durationSeconds! / 60),
          incline: Value(incline?.toInt()),
          warmup: Value(activity.warmup),
          notes: Value(activity.notes),
        ),
      );
      await (database.update(database.cardioActivities)
            ..where((row) => row.id.equals(activity.id)))
          .write(
        CardioActivitiesCompanion(
          sport: Value(activity.sport),
          environment: Value(activity.environment),
          startedAt: Value(activity.startedAt),
          endedAt: Value(activity.endedAt),
          durationBasis: Value(activity.durationBasis),
        ),
      );
    });
  }

  Future<void> delete(String id) => database.transaction(() async {
        final activity = await get(id);
        if (activity == null) return;
        if (activity.legacyGymSetId != null) {
          await (database.delete(database.gymSets)
                ..where((set) => set.id.equals(activity.legacyGymSetId!)))
              .go();
        } else {
          await (database.delete(database.cardioActivities)
                ..where((row) => row.id.equals(id)))
              .go();
        }
      });
}
