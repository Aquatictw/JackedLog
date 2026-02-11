import 'package:drift/drift.dart';

@DataClassName('FiveThreeOneBlock')
class FiveThreeOneBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get created => dateTime()();
  RealColumn get squatTm => real()();
  RealColumn get benchTm => real()();
  RealColumn get deadliftTm => real()();
  RealColumn get pressTm => real()();
  TextColumn get unit => text()();

  /// 0=Leader1, 1=Leader2, 2=7th Week Deload, 3=Anchor, 4=TM Test
  IntColumn get currentCycle => integer().withDefault(const Constant(0))();

  /// 1-3 within each cycle (7th Week cycles only use week 1)
  IntColumn get currentWeek => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get completed => dateTime().nullable()();
}
