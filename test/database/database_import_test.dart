import 'package:csv/csv.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/database/database.dart';

import '../test_helpers.dart';

/// Create clean test database without default data
Future<AppDatabase> createCleanTestDatabase() async {
  final db = await createTestDatabase();
  // Clear default data that gets auto-populated
  await db.gymSets.deleteAll();
  await db.planExercises.deleteAll();
  await db.plans.deleteAll();
  return db;
}

void main() {
  group('Backward compatibility CSV import tests', () {
    test('imports v59 format (current: has setOrder column)', () async {
      final db = await createCleanTestDatabase();

      // v59 format: has setOrder column (header: setOrder)
      const csvContent = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,setOrder,warmup,exerciseType,brandName,dropSet
1,Bench Press,10,100.0,kg,2026-01-13 10:00:00,0,0.0,0.0,,120000,0,1,,,,Test notes,0,0,0,,,0
2,Bench Press,8,110.0,kg,2026-01-13 10:05:00,0,0.0,0.0,,120000,0,1,,,,Second set,0,1,0,,,0
3,Squat,5,150.0,kg,2026-01-13 10:10:00,0,0.0,0.0,,180000,0,1,,,,Heavy set,1,0,0,,,0''';

      // Import CSV
      await _importCsvSets(db, csvContent);

      // Verify all rows imported successfully
      final sets = await (db.gymSets.select()
            ..orderBy([
              (s) => OrderingTerm(expression: s.sequence),
              (s) => OrderingTerm(expression: s.setOrder),
            ]))
          .get();

      expect(sets.length, equals(3));

      // First set
      expect(sets[0].name, equals('Bench Press'));
      expect(sets[0].weight, equals(100.0));
      expect(sets[0].reps, equals(10.0));
      expect(sets[0].sequence, equals(0));
      expect(sets[0].setOrder, equals(0));
      expect(sets[0].notes, equals('Test notes'));
      expect(sets[0].restMs, equals(120000));

      // Second set
      expect(sets[1].name, equals('Bench Press'));
      expect(sets[1].weight, equals(110.0));
      expect(sets[1].reps, equals(8.0));
      expect(sets[1].sequence, equals(0));
      expect(sets[1].setOrder, equals(1));
      expect(sets[1].notes, equals('Second set'));

      // Third set (different exercise)
      expect(sets[2].name, equals('Squat'));
      expect(sets[2].weight, equals(150.0));
      expect(sets[2].reps, equals(5.0));
      expect(sets[2].sequence, equals(1));
      expect(sets[2].setOrder, equals(0));
      expect(sets[2].notes, equals('Heavy set'));
      expect(sets[2].restMs, equals(180000));

      await db.close();
    });

    test('imports v58 format (lowercase setorder header)', () async {
      final db = await createCleanTestDatabase();

      // v58 format: has setOrder column with lowercase header (setorder)
      const csvContent = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,setorder,warmup,exerciseType,brandName,dropSet
1,Deadlift,5,200.0,kg,2026-01-13 11:00:00,0,0.0,0.0,,240000,0,2,,,,PR attempt,0,0,0,Barbell,Rogue,0
2,Deadlift,5,210.0,kg,2026-01-13 11:05:00,0,0.0,0.0,,240000,0,2,,,,New PR!,0,1,0,Barbell,Rogue,0''';

      // Import CSV
      await _importCsvSets(db, csvContent);

      // Verify all rows imported successfully
      final sets = await (db.gymSets.select()
            ..orderBy([
              (s) => OrderingTerm(expression: s.setOrder),
            ]))
          .get();

      expect(sets.length, equals(2));

      // First set
      expect(sets[0].name, equals('Deadlift'));
      expect(sets[0].weight, equals(200.0));
      expect(sets[0].reps, equals(5.0));
      expect(sets[0].setOrder, equals(0));
      expect(sets[0].notes, equals('PR attempt'));
      expect(sets[0].exerciseType, equals('Barbell'));
      expect(sets[0].brandName, equals('Rogue'));

      // Second set
      expect(sets[1].name, equals('Deadlift'));
      expect(sets[1].weight, equals(210.0));
      expect(sets[1].reps, equals(5.0));
      expect(sets[1].setOrder, equals(1));
      expect(sets[1].notes, equals('New PR!'));

      await db.close();
    });

    test('imports v57 format (missing setOrder column)', () async {
      final db = await createCleanTestDatabase();

      // v57 format: no setOrder column - should use created timestamp fallback
      // Created times: 10:00, 10:05, 10:10 to establish order
      const csvContent = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,warmup,exerciseType,brandName,dropSet
1,Overhead Press,8,60.0,kg,2026-01-13 10:00:00,0,0.0,0.0,,90000,0,3,,,Chest,First set,0,0,Barbell,,0
2,Overhead Press,8,65.0,kg,2026-01-13 10:05:00,0,0.0,0.0,,90000,0,3,,,Chest,Second set,0,0,Barbell,,0
3,Overhead Press,6,70.0,kg,2026-01-13 10:10:00,0,0.0,0.0,,90000,0,3,,,Chest,Third set,0,0,Barbell,,0''';

      // Import CSV
      await _importCsvSets(db, csvContent);

      // Verify all rows imported successfully
      final sets = await (db.gymSets.select()
            ..orderBy([
              (s) => OrderingTerm(
                    expression: const CustomExpression<int>(
                      'COALESCE(set_order, CAST((julianday(created) - 2440587.5) * 86400000 AS INTEGER))',
                    ),
                  ),
            ]))
          .get();

      expect(sets.length, equals(3));

      // Verify setOrder is null (missing column)
      expect(sets[0].setOrder, isNull);
      expect(sets[1].setOrder, isNull);
      expect(sets[2].setOrder, isNull);

      // Verify order by created timestamp (oldest to newest)
      expect(sets[0].name, equals('Overhead Press'));
      expect(sets[0].weight, equals(60.0));
      expect(sets[0].notes, equals('First set'));
      expect(sets[0].created, equals(DateTime(2026, 1, 13, 10)));

      expect(sets[1].name, equals('Overhead Press'));
      expect(sets[1].weight, equals(65.0));
      expect(sets[1].notes, equals('Second set'));
      expect(sets[1].created, equals(DateTime(2026, 1, 13, 10, 5)));

      expect(sets[2].name, equals('Overhead Press'));
      expect(sets[2].weight, equals(70.0));
      expect(sets[2].notes, equals('Third set'));
      expect(sets[2].created, equals(DateTime(2026, 1, 13, 10, 10)));

      // Verify metadata preserved
      expect(sets[0].category, equals('Chest'));
      expect(sets[0].exerciseType, equals('Barbell'));
      expect(sets[0].restMs, equals(90000));

      await db.close();
    });

    test('handles missing optional columns with proper defaults', () async {
      final db = await createCleanTestDatabase();

      // v57 format with minimal data: many null/empty optional fields
      const csvContent = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,warmup,exerciseType,brandName,dropSet
1,Pull-ups,10,0.0,kg,2026-01-13 12:00:00,0,0.0,0.0,,,0,4,,,,,0,0,,,0''';

      // Import CSV
      await _importCsvSets(db, csvContent);

      // Verify row imported with proper defaults
      final sets = await db.gymSets.select().get();
      expect(sets.length, equals(1));

      expect(sets[0].name, equals('Pull-ups'));
      expect(sets[0].weight, equals(0.0)); // Zero weight for bodyweight
      expect(sets[0].reps, equals(10.0));
      expect(sets[0].setOrder, isNull); // Missing column
      expect(sets[0].notes, isNull); // Empty string becomes null
      expect(sets[0].category, isNull); // Empty string becomes null
      expect(sets[0].restMs, isNull); // Empty string becomes null
      expect(sets[0].incline, isNull); // Empty string becomes null
      expect(sets[0].exerciseType, isNull); // Empty string becomes null
      expect(sets[0].brandName, isNull); // Empty string becomes null

      await db.close();
    });

    test('header detection is case-insensitive', () async {
      final db = await createCleanTestDatabase();

      // Mixed case headers (SETORDER vs setorder vs setOrder)
      const csvContent = '''
id,NAME,reps,WEIGHT,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,SETORDER,warmup,exerciseType,brandName,dropSet
1,Test Exercise,5,100.0,kg,2026-01-13 13:00:00,0,0.0,0.0,,120000,0,5,,,,Test,0,0,0,,,0''';

      // Import CSV - should detect SETORDER despite uppercase
      await _importCsvSets(db, csvContent);

      // Verify setOrder column was detected and imported
      final sets = await db.gymSets.select().get();
      expect(sets.length, equals(1));
      expect(sets[0].setOrder,
          equals(0)); // Should be detected despite uppercase header

      await db.close();
    });

    test('preserves set type flags across all versions', () async {
      final db = await createCleanTestDatabase();

      // v57 format with warmup, drop, and cardio sets
      const csvContent = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,warmup,exerciseType,brandName,dropSet
1,Bench Press,10,60.0,kg,2026-01-13 14:00:00,0,0.0,0.0,,60000,0,6,,,,Warmup,0,1,,,0
2,Bench Press,5,100.0,kg,2026-01-13 14:05:00,0,0.0,0.0,,180000,0,6,,,,Working,0,0,,,0
3,Bench Press,12,80.0,kg,2026-01-13 14:10:00,0,0.0,0.0,,60000,0,6,,,,Drop set,0,0,,,1
4,Running,0,0.0,kg,2026-01-13 14:15:00,1,1800.0,5.0,2,0,0,6,,,,Cardio,1,0,,,0''';

      // Import CSV
      await _importCsvSets(db, csvContent);

      // Verify all set types
      final sets = await (db.gymSets.select()
            ..orderBy([
              (s) => OrderingTerm(expression: s.sequence),
            ]))
          .get();

      expect(sets.length, equals(4));

      // Warmup set
      expect(sets[0].warmup, isTrue);
      expect(sets[0].dropSet, isFalse);
      expect(sets[0].cardio, isFalse);
      expect(sets[0].notes, equals('Warmup'));

      // Working set
      expect(sets[1].warmup, isFalse);
      expect(sets[1].dropSet, isFalse);
      expect(sets[1].cardio, isFalse);
      expect(sets[1].notes, equals('Working'));

      // Drop set
      expect(sets[2].warmup, isFalse);
      expect(sets[2].dropSet, isTrue);
      expect(sets[2].cardio, isFalse);
      expect(sets[2].notes, equals('Drop set'));

      // Cardio set
      expect(sets[3].warmup, isFalse);
      expect(sets[3].dropSet, isFalse);
      expect(sets[3].cardio, isTrue);
      expect(sets[3].duration, equals(1800.0));
      expect(sets[3].distance, equals(5.0));
      expect(sets[3].incline, equals(2));
      expect(sets[3].notes, equals('Cardio'));

      await db.close();
    });

    test('handles realistic multi-workout import from v57', () async {
      final db = await createCleanTestDatabase();

      // Multiple sets from v57 format (no setOrder)
      const csvContent = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,warmup,exerciseType,brandName,dropSet
1,Bench Press,10,80.0,kg,2026-01-13 09:00:00,0,0.0,0.0,,120000,0,1,,,Chest,,0,0,Barbell,,0
2,Bench Press,8,90.0,kg,2026-01-13 09:05:00,0,0.0,0.0,,120000,0,1,,,Chest,,0,0,Barbell,,0
3,Bench Press,6,100.0,kg,2026-01-13 09:10:00,0,0.0,0.0,,120000,0,1,,,Chest,,0,0,Barbell,,0
4,Squat,5,140.0,kg,2026-01-13 09:20:00,0,0.0,0.0,,180000,0,1,,,Legs,,1,0,Barbell,,0
5,Squat,5,150.0,kg,2026-01-13 09:25:00,0,0.0,0.0,,180000,0,1,,,Legs,,1,0,Barbell,,0
6,Deadlift,5,180.0,kg,2026-01-13 09:35:00,0,0.0,0.0,,240000,0,1,,,Back,,2,0,Barbell,,0''';

      // Import CSV
      await _importCsvSets(db, csvContent);

      // Verify all rows imported successfully
      final sets = await db.gymSets.select().get();
      expect(sets.length, equals(6));

      // Verify no data corruption
      final benchSets = await (db.gymSets.select()
            ..where((s) => s.name.equals('Bench Press')))
          .get();
      expect(benchSets.length, equals(3));
      expect(benchSets.every((s) => s.category == 'Chest'), isTrue);

      final squatSets = await (db.gymSets.select()
            ..where((s) => s.name.equals('Squat')))
          .get();
      expect(squatSets.length, equals(2));
      expect(squatSets.every((s) => s.sequence == 1), isTrue);

      final deadliftSets = await (db.gymSets.select()
            ..where((s) => s.name.equals('Deadlift')))
          .get();
      expect(deadliftSets.length, equals(1));
      expect(deadliftSets[0].sequence, equals(2));

      await db.close();
    });

    test('handles unicode and special characters in v57 format', () async {
      final db = await createCleanTestDatabase();

      // v57 format with unicode characters
      const csvContent = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,warmup,exerciseType,brandName,dropSet
1,벤치프레스 💪,10,100.0,kg,2026-01-13 15:00:00,0,0.0,0.0,,120000,0,7,,,가슴,한글 노트 🔥,0,0,,,0''';

      // Import CSV
      await _importCsvSets(db, csvContent);

      // Verify unicode preserved
      final sets = await db.gymSets.select().get();
      expect(sets.length, equals(1));
      expect(sets[0].name, equals('벤치프레스 💪'));
      expect(sets[0].category, equals('가슴'));
      expect(sets[0].notes, equals('한글 노트 🔥'));

      await db.close();
    });

    test('verifies setOrder fallback uses correct timestamp ordering',
        () async {
      final db = await createCleanTestDatabase();

      // v57 format: 3 sets with deliberately non-sequential created times
      // Goal: Verify COALESCE fallback uses created timestamp correctly
      const csvContent = '''
id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,workoutId,planId,image,category,notes,sequence,warmup,exerciseType,brandName,dropSet
3,Test,5,100.0,kg,2026-01-13 10:30:00,0,0.0,0.0,,120000,0,8,,,,Third,0,0,,,0
1,Test,5,100.0,kg,2026-01-13 10:10:00,0,0.0,0.0,,120000,0,8,,,,First,0,0,,,0
2,Test,5,100.0,kg,2026-01-13 10:20:00,0,0.0,0.0,,120000,0,8,,,,Second,0,0,,,0''';

      // Import CSV
      await _importCsvSets(db, csvContent);

      // Query with COALESCE ordering (same as production)
      final sets = await (db.gymSets.select()
            ..orderBy([
              (s) => OrderingTerm(
                    expression: const CustomExpression<int>(
                      'COALESCE(set_order, CAST((julianday(created) - 2440587.5) * 86400000 AS INTEGER))',
                    ),
                  ),
            ]))
          .get();

      // Should be ordered by created timestamp: First, Second, Third
      expect(sets.length, equals(3));
      expect(sets[0].notes, equals('First'));
      expect(sets[1].notes, equals('Second'));
      expect(sets[2].notes, equals('Third'));

      await db.close();
    });
  });
}

/// Import CSV sets into database (simulates import_data.dart logic)
Future<void> _importCsvSets(AppDatabase db, String csvContent) async {
  // Parse CSV
  final rows = const CsvToListConverter(eol: '\n').convert(csvContent);
  if (rows.isEmpty) throw Exception('CSV is empty');

  // Check CSV format version by examining header row
  final header = rows.first.map((e) => e.toString().toLowerCase()).toList();
  final hasSetOrderColumn = header.contains('setorder');

  // Import gym sets (skip header row)
  final gymSets = rows.skip(1).map((row) {
    final reps =
        row[2] is num ? row[2].toDouble() : double.parse(row[2].toString());
    final weight =
        row[3] is num ? row[3].toDouble() : double.parse(row[3].toString());

    return GymSetsCompanion(
      id: Value(int.tryParse(row[0]?.toString() ?? '0') ?? 0),
      name: Value(row[1]?.toString() ?? ''),
      reps: Value(reps),
      weight: Value(weight),
      unit: Value(row[4]?.toString() ?? ''),
      created: Value(DateTime.parse(row[5].toString())),
      cardio: Value(_parseBool(row[6])),
      duration: Value(double.tryParse(row[7]?.toString() ?? '0') ?? 0),
      distance: Value(double.tryParse(row[8]?.toString() ?? '0') ?? 0),
      incline: Value(_parseNullableInt(row[9])),
      restMs: Value(_parseNullableInt(row[10])),
      hidden: Value(_parseBool(row[11])),
      workoutId: Value(_parseNullableInt(row[12])),
      planId: Value(_parseNullableInt(row[13])),
      image: Value(_parseNullableString(row[14])),
      category: Value(_parseNullableString(row[15])),
      notes: Value(_parseNullableString(row[16])),
      sequence: Value(int.tryParse(row[17]?.toString() ?? '0') ?? 0),
      setOrder: Value(hasSetOrderColumn ? _parseNullableInt(row[18]) : null),
      warmup: Value(_parseBool(row[hasSetOrderColumn ? 19 : 18])),
      exerciseType:
          Value(_parseNullableString(row[hasSetOrderColumn ? 20 : 19])),
      brandName: Value(_parseNullableString(row[hasSetOrderColumn ? 21 : 20])),
      dropSet: Value(_parseBool(row[hasSetOrderColumn ? 22 : 21])),
    );
  });

  // Import data
  await db.gymSets.insertAll(gymSets);
}

int? _parseNullableInt(dynamic value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _parseNullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  if (str.isEmpty) return null;
  return str;
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1';
  }
  if (value is num) return value != 0;
  return false;
}
