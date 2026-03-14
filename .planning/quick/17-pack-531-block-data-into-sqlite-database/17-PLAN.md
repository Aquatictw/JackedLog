---
phase: quick-017
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/export_data.dart
  - lib/import_data.dart
autonomous: true
requirements: [QUICK-017]
must_haves:
  truths:
    - "Workouts ZIP export contains five_three_one_blocks.sqlite instead of five_three_one_blocks.csv"
    - "Workouts ZIP import reads five_three_one_blocks.sqlite and populates the table"
    - "Backward compatibility: import still handles old ZIPs that have neither the csv nor the sqlite file"
  artifacts:
    - path: "lib/export_data.dart"
      provides: "Sqlite-based 5/3/1 block export"
      contains: "five_three_one_blocks.sqlite"
    - path: "lib/import_data.dart"
      provides: "Sqlite-based 5/3/1 block import"
      contains: "five_three_one_blocks.sqlite"
  key_links:
    - from: "lib/export_data.dart"
      to: "sqlite3"
      via: "sqlite3.open() to create temp db file"
      pattern: "sqlite3\\.open"
    - from: "lib/import_data.dart"
      to: "sqlite3"
      via: "sqlite3.open() to read extracted db file"
      pattern: "sqlite3\\.open"
---

<objective>
Replace CSV-based 5/3/1 block export/import with sqlite-based export/import in the Workouts ZIP archive.

Purpose: Store 5/3/1 block data as a sqlite database file inside the ZIP instead of CSV, matching the user's preference for structured database storage.
Output: Modified export_data.dart and import_data.dart that write/read `five_three_one_blocks.sqlite` in the ZIP.
</objective>

<context>
@lib/export_data.dart
@lib/import_data.dart
@lib/database/database_connection_native.dart (for table schema reference)
</context>

<interfaces>
<!-- The project already has sqlite3 ^2.4.0 as a dependency. Use it directly to create/read standalone sqlite files. -->

From pubspec.yaml:
```yaml
sqlite3: ^2.4.0
```

From lib/database/database_connection_native.dart (canonical table schema):
```sql
CREATE TABLE IF NOT EXISTS five_three_one_blocks (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  created INTEGER NOT NULL,
  squat_tm REAL NOT NULL,
  bench_tm REAL NOT NULL,
  deadlift_tm REAL NOT NULL,
  press_tm REAL NOT NULL,
  start_squat_tm REAL,
  start_bench_tm REAL,
  start_deadlift_tm REAL,
  start_press_tm REAL,
  unit TEXT NOT NULL,
  current_cycle INTEGER NOT NULL DEFAULT 0,
  current_week INTEGER NOT NULL DEFAULT 1,
  is_active INTEGER NOT NULL DEFAULT 1,
  completed INTEGER
)
```

Drift stores DateTime as INTEGER (millisecondsSinceEpoch), booleans as INTEGER (0/1).
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Replace CSV export with sqlite export for 5/3/1 blocks</name>
  <files>lib/export_data.dart</files>
  <action>
In lib/export_data.dart:

1. Add import for `sqlite3` package: `import 'package:sqlite3/sqlite3.dart' as sqlite;` and `import 'package:path_provider/path_provider.dart';` (path_provider is already imported).

2. Remove the entire CSV-based 5/3/1 blocks export section (lines ~126-172, the `String? blocksCsv;` block and the `try/catch` that builds CSV from `db.fiveThreeOneBlocks.select().get()`).

3. Remove the CSV-based archive entry for blocks (lines ~190-198, the `if (blocksCsv != null)` block that adds `five_three_one_blocks.csv` to the archive).

4. Replace with sqlite-based export. After the `setsCsv` variable is created and before the `final archive = Archive();` line, add:

```dart
// Export 5/3/1 blocks as sqlite database (optional - table may not exist)
Uint8List? blocksSqliteBytes;
try {
  final blocks = await db.fiveThreeOneBlocks.select().get();
  if (blocks.isNotEmpty) {
    final tempDir = await getTemporaryDirectory();
    final tempDbPath = p.join(tempDir.path, 'five_three_one_blocks_export.sqlite');
    // Delete old temp file if it exists
    final tempFile = File(tempDbPath);
    if (await tempFile.exists()) await tempFile.delete();

    final exportDb = sqlite.sqlite3.open(tempDbPath);
    try {
      exportDb.execute('''
        CREATE TABLE five_three_one_blocks (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created INTEGER NOT NULL,
          squat_tm REAL NOT NULL,
          bench_tm REAL NOT NULL,
          deadlift_tm REAL NOT NULL,
          press_tm REAL NOT NULL,
          start_squat_tm REAL,
          start_bench_tm REAL,
          start_deadlift_tm REAL,
          start_press_tm REAL,
          unit TEXT NOT NULL,
          current_cycle INTEGER NOT NULL DEFAULT 0,
          current_week INTEGER NOT NULL DEFAULT 1,
          is_active INTEGER NOT NULL DEFAULT 1,
          completed INTEGER
        )
      ''');

      final stmt = exportDb.prepare('''
        INSERT INTO five_three_one_blocks (
          id, created, squat_tm, bench_tm, deadlift_tm, press_tm,
          start_squat_tm, start_bench_tm, start_deadlift_tm, start_press_tm,
          unit, current_cycle, current_week, is_active, completed
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      for (final block in blocks) {
        stmt.execute([
          block.id,
          block.created.millisecondsSinceEpoch,
          block.squatTm,
          block.benchTm,
          block.deadliftTm,
          block.pressTm,
          block.startSquatTm,
          block.startBenchTm,
          block.startDeadliftTm,
          block.startPressTm,
          block.unit,
          block.currentCycle,
          block.currentWeek,
          block.isActive ? 1 : 0,
          block.completed?.millisecondsSinceEpoch,
        ]);
      }
      stmt.dispose();
    } finally {
      exportDb.dispose();
    }

    blocksSqliteBytes = await tempFile.readAsBytes();
    await tempFile.delete();
  }
} catch (_) {
  // Table may not exist in older databases - skip
}
```

5. In the archive construction section, replace the CSV blocks entry with:
```dart
if (blocksSqliteBytes != null) {
  archive.addFile(
    ArchiveFile(
      'five_three_one_blocks.sqlite',
      blocksSqliteBytes.length,
      blocksSqliteBytes,
    ),
  );
}
```

6. Remove the `csv` import if it is no longer used elsewhere in the file. Check: `ListToCsvConverter` is still used for workouts and gym_sets CSVs, so keep the csv import.

7. Add the sqlite3 import at the top: `import 'package:sqlite3/sqlite3.dart' as sqlite;`
  </action>
  <verify>
    <automated>rg "five_three_one_blocks.sqlite" lib/export_data.dart && rg -v "five_three_one_blocks.csv" lib/export_data.dart > /dev/null && echo "PASS: export uses sqlite, no csv reference for blocks"</automated>
  </verify>
  <done>Export creates a five_three_one_blocks.sqlite file inside the ZIP instead of five_three_one_blocks.csv. The sqlite file contains the full table schema and all block rows with proper INTEGER datetime and boolean encoding.</done>
</task>

<task type="auto">
  <name>Task 2: Replace CSV import with sqlite import for 5/3/1 blocks</name>
  <files>lib/import_data.dart</files>
  <action>
In lib/import_data.dart:

1. Add imports at the top: `import 'package:sqlite3/sqlite3.dart' as sqlite;`

2. Remove the entire CSV-based 5/3/1 blocks import section (lines ~305-381). This is the block starting with `// Import 5/3/1 blocks if present` that searches for `five_three_one_blocks.csv`, parses CSV, and inserts into the database.

3. Replace with sqlite-based import. In the same location (after the gym_sets insertAll and before the `if (!ctx.mounted) return;` line), add:

```dart
// Import 5/3/1 blocks from sqlite file if present (backward compatible)
ArchiveFile? blocksSqliteFile;
for (final file in archive) {
  if (file.name == 'five_three_one_blocks.sqlite') {
    blocksSqliteFile = file;
  }
}

if (blocksSqliteFile != null) {
  final tempDir = await getTemporaryDirectory();
  final tempDbPath = p.join(tempDir.path, 'five_three_one_blocks_import.sqlite');
  final tempFile = File(tempDbPath);
  await tempFile.writeAsBytes(blocksSqliteFile.content as List<int>);

  try {
    final importDb = sqlite.sqlite3.open(tempDbPath);
    try {
      final results = importDb.select('SELECT * FROM five_three_one_blocks');

      if (results.isNotEmpty) {
        // Ensure table exists in app database
        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS five_three_one_blocks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            created INTEGER NOT NULL,
            squat_tm REAL NOT NULL,
            bench_tm REAL NOT NULL,
            deadlift_tm REAL NOT NULL,
            press_tm REAL NOT NULL,
            start_squat_tm REAL,
            start_bench_tm REAL,
            start_deadlift_tm REAL,
            start_press_tm REAL,
            unit TEXT NOT NULL,
            current_cycle INTEGER NOT NULL DEFAULT 0,
            current_week INTEGER NOT NULL DEFAULT 1,
            is_active INTEGER NOT NULL DEFAULT 1,
            completed INTEGER
          )
        ''');

        await db.fiveThreeOneBlocks.deleteAll();

        final blocksToInsert = results.map((row) {
          return FiveThreeOneBlocksCompanion(
            id: Value(row['id'] as int),
            created: Value(
              DateTime.fromMillisecondsSinceEpoch(row['created'] as int),
            ),
            squatTm: Value((row['squat_tm'] as num).toDouble()),
            benchTm: Value((row['bench_tm'] as num).toDouble()),
            deadliftTm: Value((row['deadlift_tm'] as num).toDouble()),
            pressTm: Value((row['press_tm'] as num).toDouble()),
            startSquatTm: Value(
              row['start_squat_tm'] != null
                  ? (row['start_squat_tm'] as num).toDouble()
                  : null,
            ),
            startBenchTm: Value(
              row['start_bench_tm'] != null
                  ? (row['start_bench_tm'] as num).toDouble()
                  : null,
            ),
            startDeadliftTm: Value(
              row['start_deadlift_tm'] != null
                  ? (row['start_deadlift_tm'] as num).toDouble()
                  : null,
            ),
            startPressTm: Value(
              row['start_press_tm'] != null
                  ? (row['start_press_tm'] as num).toDouble()
                  : null,
            ),
            unit: Value(row['unit'] as String),
            currentCycle: Value(row['current_cycle'] as int),
            currentWeek: Value(row['current_week'] as int),
            isActive: Value((row['is_active'] as int) != 0),
            completed: Value(
              row['completed'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      row['completed'] as int,
                    )
                  : null,
            ),
          );
        });

        await db.fiveThreeOneBlocks.insertAll(blocksToInsert);
      }
    } finally {
      importDb.dispose();
    }
  } finally {
    if (await tempFile.exists()) await tempFile.delete();
  }
}
```

4. Note: The import does NOT need to handle old CSV-based exports (`five_three_one_blocks.csv`) since quick-016 only just added CSV export and the user wants to replace it immediately. No old CSV exports are in the wild that need backward compatibility. The import only needs to handle: (a) ZIPs with `five_three_one_blocks.sqlite` (new format), and (b) ZIPs with neither file (pre-016 exports).

5. Verify `path_provider` is imported (it is, used for `getApplicationDocumentsDirectory`). Also ensure `getTemporaryDirectory` is available from the same import.
  </action>
  <verify>
    <automated>rg "five_three_one_blocks.sqlite" lib/import_data.dart && rg -v "five_three_one_blocks.csv" lib/import_data.dart > /dev/null && echo "PASS: import uses sqlite, no csv reference for blocks"</automated>
  </verify>
  <done>Import reads five_three_one_blocks.sqlite from the ZIP, opens it with sqlite3, reads all rows, and inserts them into the app database. Old ZIPs without the file are handled gracefully (no blocks imported). No CSV-based block import code remains.</done>
</task>

</tasks>

<verification>
- Export: The Workouts export ZIP contains `workouts.csv`, `gym_sets.csv`, and `five_three_one_blocks.sqlite` (when blocks exist). No `five_three_one_blocks.csv` in the ZIP.
- Import: The Workouts import reads the sqlite file from the ZIP and populates the five_three_one_blocks table. Old ZIPs without the sqlite file import workouts and sets normally, skipping blocks.
- Round-trip: Export then import preserves all 5/3/1 block data including nullable fields (start TMs, completed date).
</verification>

<success_criteria>
- No CSV code for five_three_one_blocks remains in either file
- Export creates a proper sqlite database file with the blocks table and data
- Import reads the sqlite file and inserts all rows correctly
- DateTime fields use millisecondsSinceEpoch (matching Drift's storage format)
- Boolean isActive uses INTEGER 0/1 (matching Drift's storage format)
- Nullable columns (start TMs, completed) handled correctly in both directions
</success_criteria>

<output>
After completion, create `.planning/quick/17-pack-531-block-data-into-sqlite-database/17-SUMMARY.md`
</output>
