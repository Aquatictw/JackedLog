---
phase: quick-017
plan: 01
subsystem: backup/export-import
tags: [sqlite, export, import, 531-blocks]
key-files:
  created: []
  modified:
    - lib/export_data.dart
    - lib/import_data.dart
decisions:
  - "sqlite3 package (already a dependency) used directly to create standalone .sqlite files for ZIP archive"
  - "No backward compatibility for CSV-based 531 block exports since quick-016 just added them and no old CSV exports are in the wild"
metrics:
  duration: "2 min"
  completed: "2026-03-14"
---

# Quick Task 17: Pack 5/3/1 Block Data into SQLite Database

Replaced CSV-based 5/3/1 block export/import with sqlite-based export/import using the sqlite3 package to create a standalone database file inside the Workouts ZIP archive.

## Tasks Completed

| Task | Name | Files |
|------|------|-------|
| 1 | Replace CSV export with sqlite export for 5/3/1 blocks | lib/export_data.dart |
| 2 | Replace CSV import with sqlite import for 5/3/1 blocks | lib/import_data.dart |

## Changes Made

### Export (lib/export_data.dart)
- Added `import 'package:sqlite3/sqlite3.dart' as sqlite;`
- Replaced CSV-based block export with sqlite-based export that:
  - Creates a temporary sqlite database file
  - Creates the `five_three_one_blocks` table with the canonical schema
  - Inserts all block rows with proper INTEGER datetime (millisecondsSinceEpoch) and boolean (0/1) encoding
  - Reads the temp file as bytes and adds as `five_three_one_blocks.sqlite` to the ZIP
  - Cleans up the temp file
- Removed all CSV references for blocks (no `five_three_one_blocks.csv`)

### Import (lib/import_data.dart)
- Added `import 'package:sqlite3/sqlite3.dart' as sqlite;`
- Replaced CSV-based block import with sqlite-based import that:
  - Extracts `five_three_one_blocks.sqlite` from ZIP to a temp file
  - Opens with sqlite3 and reads all rows via SELECT
  - Converts INTEGER back to DateTime (millisecondsSinceEpoch) and boolean (int != 0)
  - Handles nullable columns (start TMs, completed) correctly
  - Inserts into app database via Drift companions
  - Cleans up temp file in finally block
- Old ZIPs without the sqlite file are handled gracefully (blocks section skipped)

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- Export file contains `five_three_one_blocks.sqlite` reference, no `.csv` reference for blocks
- Import file contains `five_three_one_blocks.sqlite` reference, no `.csv` reference for blocks
- DateTime fields use millisecondsSinceEpoch matching Drift's storage format
- Boolean isActive uses INTEGER 0/1 matching Drift's storage format
- Nullable columns handled correctly in both directions
