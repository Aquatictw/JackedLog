import 'package:drift/drift.dart';

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get planId => integer().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get selfieImagePath => text().nullable()();
}
