---
phase: quick-016
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/export_data.dart
  - lib/import_data.dart
  - lib/workouts/workout_detail_page.dart
autonomous: true
requirements: [QUICK-016]
must_haves:
  truths:
    - "Exported ZIP contains five_three_one_blocks.csv with all block data including training maxes"
    - "Importing a ZIP with five_three_one_blocks.csv restores all 5/3/1 block data"
    - "Importing a ZIP without five_three_one_blocks.csv still works (backward compatible)"
    - "User can edit workout duration from the workout detail edit mode"
  artifacts:
    - path: "lib/export_data.dart"
      provides: "5/3/1 blocks CSV export alongside workouts and gym_sets"
    - path: "lib/import_data.dart"
      provides: "5/3/1 blocks CSV import with backward compatibility"
    - path: "lib/workouts/workout_detail_page.dart"
      provides: "Tappable duration stat in edit mode to modify start/end times"
  key_links:
    - from: "lib/export_data.dart"
      to: "db.fiveThreeOneBlocks"
      via: "select().get() then CSV serialization"
    - from: "lib/import_data.dart"
      to: "db.fiveThreeOneBlocks"
      via: "CSV parse then deleteAll + insertAll"
---

<objective>
Fix 5/3/1 block and training max data missing from CSV backup export/import, and add workout duration editing capability in the workout detail edit mode.

Purpose: Users who export/import via the "Workouts" (ZIP) option lose all 5/3/1 block progress and training maxes. Additionally, users cannot correct workout duration after a workout ends (e.g., if they forgot to end the workout on time).

Output: Updated export_data.dart, import_data.dart, and workout_detail_page.dart.
</objective>

<context>
@.planning/STATE.md
@lib/export_data.dart
@lib/import_data.dart
@lib/database/fivethreeone_blocks.dart
@lib/workouts/workout_detail_page.dart
@lib/database/workouts.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add 5/3/1 blocks to CSV export and import</name>
  <files>lib/export_data.dart, lib/import_data.dart</files>
  <action>
**In `lib/export_data.dart`** - Inside the Workouts export onTap handler, after the gym_sets CSV block and before creating the ZIP archive:

1. Query all 5/3/1 blocks: `final blocks = await db.fiveThreeOneBlocks.select().get();`
   - Note: Wrap in try/catch since the table may not exist in older databases. If it fails, skip adding the CSV to the archive.
2. Build CSV with header row:
   ```
   ['id', 'created', 'squatTm', 'benchTm', 'deadliftTm', 'pressTm', 'startSquatTm', 'startBenchTm', 'startDeadliftTm', 'startPressTm', 'unit', 'currentCycle', 'currentWeek', 'isActive', 'completed']
   ```
3. For each block, add a data row matching the header (use `.toIso8601String()` for DateTime fields, `?? ''` for nullable fields like startTms and completed).
4. Convert to CSV string and add to the archive as `five_three_one_blocks.csv` (same pattern as workouts.csv and gym_sets.csv).

**In `lib/import_data.dart`** - Inside `importWorkouts()`, after inserting gym_sets and before the success toast:

1. Look for `five_three_one_blocks.csv` in the archive (same pattern as workouts/sets file lookup). This is OPTIONAL - old exports won't have it.
2. If found, parse the CSV content (same utf8/latin1 decode pattern as workouts).
3. Map rows to `FiveThreeOneBlocksCompanion` objects:
   - `id`: int
   - `created`: DateTime (use `parseDate`)
   - `squatTm`, `benchTm`, `deadliftTm`, `pressTm`: double
   - `startSquatTm`, `startBenchTm`, `startDeadliftTm`, `startPressTm`: nullable double
   - `unit`: String
   - `currentCycle`: int (default 0)
   - `currentWeek`: int (default 1)
   - `isActive`: bool (use existing `parseBool`)
   - `completed`: nullable DateTime (use `_parseNullableDateTime`)
4. Before inserting, ensure the table exists by running the same CREATE TABLE IF NOT EXISTS statement from `fivethreeone_state.dart` `_ensureTable()`.
5. Delete existing blocks: `await db.fiveThreeOneBlocks.deleteAll();`
6. Insert all parsed blocks: `await db.fiveThreeOneBlocks.insertAll(blocksToInsert);`
7. If `five_three_one_blocks.csv` is not in the archive, skip silently (backward compat).

Import needs `import '../database/database.dart';` which is already imported. Also need to add `FiveThreeOneBlocksCompanion` usage which comes from the generated database.g.dart via database.dart import.
  </action>
  <verify>
    <automated>Read both files and confirm: export_data.dart queries fiveThreeOneBlocks and adds CSV to archive; import_data.dart looks for five_three_one_blocks.csv and handles both present and absent cases.</automated>
  </verify>
  <done>Exporting workouts ZIP includes five_three_one_blocks.csv; importing a ZIP with or without that CSV works correctly; all 5/3/1 block fields (including start TMs, cycle, week, active state) are preserved through export/import cycle.</done>
</task>

<task type="auto">
  <name>Task 2: Add workout duration editing in edit mode</name>
  <files>lib/workouts/workout_detail_page.dart</files>
  <action>
In `_buildStatsSection`, make the duration stat tappable when in edit mode AND the workout has ended (has endTime). The approach:

1. Replace the duration `_buildStatItem` call (around line 1182-1186) with a conditional wrapper:
   - If `_isEditMode` and `widget.workout.endTime != null`: Wrap in `GestureDetector` with `onTap: _editDuration`. Add a small edit icon indicator or use an InkWell for visual feedback.
   - Otherwise: Keep the existing `_buildStatItem` as-is.

2. Create a new `_editDuration()` method that shows a dialog to edit start time and end time:
   - Show a dialog with two fields: start time and end time.
   - Use `showTimePicker` for each. Show two buttons in the dialog: "Edit Start Time" and "Edit End Time", each opening a time picker.
   - Actually, simpler approach: Show a dialog with two ListTiles - "Start Time" and "End Time" - each showing current value and opening a `showTimePicker` on tap. Keep the date the same, only change the time portion.
   - When a time is picked, compute new DateTime by replacing hour/minute on the existing startTime/endTime, keeping the date.
   - Validate: endTime must be after startTime. If not, show toast error and don't save.
   - Save to database: `(db.workouts.update()..where((w) => w.id.equals(widget.workout.id))).write(WorkoutsCompanion(startTime: Value(newStart), endTime: Value(newEnd)))`.
   - Call `_reloadWorkout()` and set `_hasUnsavedChanges = true`.

3. The `_buildStatsSection` currently uses `widget.workout` for duration calculation (line 1153). Change it to use `currentWorkout` instead so it reflects edits:
   ```dart
   final duration = currentWorkout.endTime != null
       ? currentWorkout.endTime!.difference(currentWorkout.startTime)
       : DateTime.now().difference(currentWorkout.startTime);
   ```

4. The `_editDuration` dialog structure:
   ```dart
   Future<void> _editDuration() async {
     DateTime editStart = currentWorkout.startTime;
     DateTime editEnd = currentWorkout.endTime!;

     await showDialog(
       context: context,
       builder: (context) => StatefulBuilder(
         builder: (context, setDialogState) => AlertDialog(
           title: const Text('Edit Duration'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               ListTile(
                 title: const Text('Start Time'),
                 trailing: Text(DateFormat('HH:mm').format(editStart)),
                 onTap: () async {
                   final time = await showTimePicker(
                     context: context,
                     initialTime: TimeOfDay.fromDateTime(editStart),
                   );
                   if (time != null) {
                     setDialogState(() {
                       editStart = DateTime(editStart.year, editStart.month, editStart.day, time.hour, time.minute);
                     });
                   }
                 },
               ),
               ListTile(
                 title: const Text('End Time'),
                 trailing: Text(DateFormat('HH:mm').format(editEnd)),
                 onTap: () async {
                   final time = await showTimePicker(
                     context: context,
                     initialTime: TimeOfDay.fromDateTime(editEnd),
                   );
                   if (time != null) {
                     setDialogState(() {
                       editEnd = DateTime(editEnd.year, editEnd.month, editEnd.day, time.hour, time.minute);
                     });
                   }
                 },
               ),
             ],
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: const Text('Cancel'),
             ),
             FilledButton(
               onPressed: () {
                 if (editEnd.isBefore(editStart) || editEnd.isAtSameMomentAs(editStart)) {
                   toast('End time must be after start time');
                   return;
                 }
                 Navigator.pop(context, true);
               },
               child: const Text('Save'),
             ),
           ],
         ),
       ),
     ).then((saved) async {
       if (saved == true) {
         await (db.workouts.update()..where((w) => w.id.equals(widget.workout.id)))
             .write(WorkoutsCompanion(
           startTime: Value(editStart),
           endTime: Value(editEnd),
         ));
         await _reloadWorkout();
         setState(() {
           _hasUnsavedChanges = true;
         });
       }
     });
   }
   ```

5. For the tappable duration stat in the stats section, wrap only the duration column:
   ```dart
   if (_isEditMode && currentWorkout.endTime != null)
     GestureDetector(
       onTap: _editDuration,
       child: _buildStatItem(
         Icons.timer,
         _formatDuration(duration),
         'duration',
         isHighlighted: true,  // or use a subtle edit indicator
       ),
     )
   else
     _buildStatItem(
       Icons.timer,
       _formatDuration(duration),
       'duration',
     ),
   ```
  </action>
  <verify>
    <automated>Read workout_detail_page.dart and confirm: _editDuration method exists, _buildStatsSection uses currentWorkout (not widget.workout) for duration, duration stat is tappable in edit mode.</automated>
  </verify>
  <done>In edit mode, tapping the duration stat opens a dialog to edit start/end times; saving updates the workout in DB and reflects new duration in the stats section; validation prevents end time before start time.</done>
</task>

</tasks>

<verification>
1. Export: The exported ZIP file contains three CSVs: workouts.csv, gym_sets.csv, five_three_one_blocks.csv
2. Import with 531: Importing a ZIP that has five_three_one_blocks.csv restores all block data
3. Import without 531: Importing an older ZIP without five_three_one_blocks.csv still works without errors
4. Duration edit: In workout detail edit mode, tapping duration opens time picker dialog, changes persist after save
</verification>

<success_criteria>
- 5/3/1 block data (all fields including start TMs, cycle position, active state) survives a full export+import cycle
- Old exports without 5/3/1 data can still be imported without errors
- Workout duration can be edited via the workout detail edit mode by adjusting start/end times
- End time validation prevents invalid duration (end before start)
</success_criteria>

<output>
After completion, create `.planning/quick/16-fix-531-block-and-training-max-backup-re/16-SUMMARY.md`
</output>
