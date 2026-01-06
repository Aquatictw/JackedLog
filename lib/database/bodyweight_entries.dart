import 'package:drift/drift.dart';

@DataClassName('BodyweightEntry')
class BodyweightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get weight => real()();
  TextColumn get unit => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
}
