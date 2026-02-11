---
phase: quick-006
plan: 01
type: execute
wave: 1
depends_on: []
files_modified: [lib/database/database.dart]
autonomous: true

must_haves:
  truths:
    - "Block creation no longer crashes with SqliteException about missing start_*_tm columns"
    - "Databases that skipped v64->65 migration self-heal on next app open"
    - "Databases that already have the columns are unaffected"
  artifacts:
    - path: "lib/database/database.dart"
      provides: "beforeOpen safety checks for start TM columns"
      contains: "start_squat_tm"
  key_links:
    - from: "lib/database/database.dart (beforeOpen)"
      to: "fivethreeone_blocks table"
      via: "ALTER TABLE ADD COLUMN with try/catch"
      pattern: "ALTER TABLE fivethreeone_blocks ADD COLUMN start_"
---

<objective>
Fix crash when creating 5/3/1 blocks on databases where the v64->65 migration did not add start_*_tm columns.

Purpose: Users whose DB was already at v65 before the migration code was added get a SqliteException when creating a new block because the four start TM columns (start_squat_tm, start_bench_tm, start_deadlift_tm, start_press_tm) don't exist in their fivethreeone_blocks table.

Output: Updated beforeOpen handler in database.dart that ensures these columns exist on every app launch, following the existing safety-check pattern used for bodyweight_entries.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/database/database.dart
@lib/database/fivethreeone_blocks.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add start TM column safety checks to beforeOpen handler</name>
  <files>lib/database/database.dart</files>
  <action>
In lib/database/database.dart, inside the `beforeOpen` callback (currently lines 456-474), add four try/catch ALTER TABLE ADD COLUMN statements AFTER the existing bodyweight_entries safety checks (after line 473, before the closing `},` of beforeOpen).

Add this block:

```dart
// Ensure start TM columns exist (safety check for migration issues)
try {
  await customStatement(
    'ALTER TABLE fivethreeone_blocks ADD COLUMN start_squat_tm REAL',
  );
} catch (e) {
  // Column already exists, ignore
}
try {
  await customStatement(
    'ALTER TABLE fivethreeone_blocks ADD COLUMN start_bench_tm REAL',
  );
} catch (e) {
  // Column already exists, ignore
}
try {
  await customStatement(
    'ALTER TABLE fivethreeone_blocks ADD COLUMN start_deadlift_tm REAL',
  );
} catch (e) {
  // Column already exists, ignore
}
try {
  await customStatement(
    'ALTER TABLE fivethreeone_blocks ADD COLUMN start_press_tm REAL',
  );
} catch (e) {
  // Column already exists, ignore
}
```

This follows the exact same pattern as the existing DROP COLUMN safety check on lines 468-473. Each ALTER TABLE is wrapped in its own try/catch so that if the column already exists (the normal case), the error is silently caught and the next column is attempted.

Do NOT change the schemaVersion. Do NOT modify the migration callback. Only add to beforeOpen.
  </action>
  <verify>
Verify by reading database.dart and confirming:
1. The four ALTER TABLE statements appear inside beforeOpen
2. Each is wrapped in its own try/catch
3. They appear after the bodyweight_entries checks
4. No other lines were modified (schemaVersion still 65, migration unchanged)
  </verify>
  <done>
The beforeOpen handler contains try/catch-wrapped ALTER TABLE ADD COLUMN statements for all four start TM columns (start_squat_tm, start_bench_tm, start_deadlift_tm, start_press_tm). No version bump, no migration changes.
  </done>
</task>

</tasks>

<verification>
- `rg "start_squat_tm" lib/database/database.dart` shows the column in BOTH the migration block AND the beforeOpen block
- `rg "beforeOpen" lib/database/database.dart` confirms the handler is intact
- `rg "schemaVersion => 65" lib/database/database.dart` confirms no version bump
</verification>

<success_criteria>
- beforeOpen handler adds missing start_*_tm columns on app launch
- Existing databases with the columns are unaffected (errors silently caught)
- No schema version change required
- Block creation works on databases that missed the v64->65 migration
</success_criteria>

<output>
After completion, create `.planning/quick/006-fix-start-tm-columns-migration/006-SUMMARY.md`
</output>
