import 'package:drift/drift.dart';

/// Recorded cardio, independent of strength sets and exercise templates.
///
/// Canonical metrics are meters and seconds. Null means unknown; zero is a
/// recorded zero. Legacy completion timestamps are not actual start times.
@DataClassName('CardioActivity')
class CardioActivities extends Table {
  TextColumn get id => text()();
  IntColumn get legacyGymSetId => integer().nullable().unique()();
  IntColumn get workoutId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get sport => text().withDefault(const Constant('other'))();
  TextColumn get environment =>
      text().withDefault(const Constant('unspecified'))();
  DateTimeColumn get recordedAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();

  /// Offset at the actual source start, never guessed for migrated records.
  IntColumn get startUtcOffsetMinutes => integer().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  RealColumn get durationSeconds => real().nullable()();
  TextColumn get durationBasis =>
      text().withDefault(const Constant('unspecified'))();
  RealColumn get inclinePercent => real().nullable()();
  BoolColumn get warmup => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {id};
}
