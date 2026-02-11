---
phase: quick-005
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/fivethreeone/schemes.dart
  - lib/fivethreeone/fivethreeone_state.dart
  - lib/fivethreeone/block_overview_page.dart
  - lib/notes/notes_page.dart
  - lib/widgets/five_three_one_calculator.dart
autonomous: true

must_haves:
  truths:
    - "Block overview page does not require scrolling to reach Complete Week button on typical phone screens"
    - "User can tap a TM value on the block overview page and edit it inline"
    - "Notes page banner shows phase-descriptive label like '5s Pro BBB - Week 1' instead of 'Leader 1 - Week 1'"
    - "Notes page banner shows phase badge (L1, L2, D, A, T) instead of barbell icon"
    - "Block overview AppBar title shows descriptive label like '5/3/1 5s Pro BBB - Week 1'"
  artifacts:
    - path: "lib/fivethreeone/schemes.dart"
      provides: "Phase-descriptive label helper and badge text helper"
    - path: "lib/fivethreeone/fivethreeone_state.dart"
      provides: "updateTm method and descriptive positionLabel"
    - path: "lib/fivethreeone/block_overview_page.dart"
      provides: "Compact TM card with inline editing, updated title"
    - path: "lib/notes/notes_page.dart"
      provides: "Phase badge and descriptive label in banner"
  key_links:
    - from: "lib/fivethreeone/fivethreeone_state.dart"
      to: "lib/fivethreeone/schemes.dart"
      via: "getDescriptiveLabel and getCycleBadge calls"
      pattern: "getDescriptiveLabel|getCycleBadge"
    - from: "lib/fivethreeone/block_overview_page.dart"
      to: "lib/fivethreeone/fivethreeone_state.dart"
      via: "updateTm call for inline editing"
      pattern: "updateTm"
---

<objective>
Three 5/3/1 UI improvements: (1) compact TM display in block overview so Complete Week button is visible without scrolling, (2) editable TM values on the block overview page, (3) phase-aware descriptive labels and cycle badges replacing generic "Leader 1 - Week 1" text and barbell icon.

Purpose: Reduce friction in the 5/3/1 workflow -- users should see their current workout scheme at a glance without scrolling, adjust TMs on the fly, and immediately understand which training template applies.
Output: Updated UI across block overview, notes banner, and calculator with compact layout, inline editing, and descriptive labels.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@lib/fivethreeone/schemes.dart
@lib/fivethreeone/fivethreeone_state.dart
@lib/fivethreeone/block_overview_page.dart
@lib/notes/notes_page.dart
@lib/widgets/five_three_one_calculator.dart
@lib/fivethreeone/block_creation_dialog.dart
@lib/database/fivethreeone_blocks.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add descriptive label helpers to schemes.dart and update FiveThreeOneState</name>
  <files>lib/fivethreeone/schemes.dart, lib/fivethreeone/fivethreeone_state.dart</files>
  <action>
  **In schemes.dart**, add two new helper functions:

  1. `String getDescriptiveLabel(int cycleType)` - returns the full descriptive label combining main scheme + supplemental:
     - cycleLeader1, cycleLeader2: `"5's Pro BBB"`
     - cycleAnchor: `"PR Sets FSL"`
     - cycleDeload: `"Deload"`
     - cycleTmTest: `"TM Test"`

  2. `String getCycleBadge(int cycleType)` - returns a short badge string:
     - cycleLeader1: `"L1"`
     - cycleLeader2: `"L2"`
     - cycleDeload: `"D"`
     - cycleAnchor: `"A"`
     - cycleTmTest: `"T"`

  **In fivethreeone_state.dart**, make two changes:

  1. Update the `positionLabel` getter to use `getDescriptiveLabel` instead of `cycleNames`:
     ```dart
     String get positionLabel {
       if (_activeBlock == null) return '';
       final block = _activeBlock!;
       return '${getDescriptiveLabel(block.currentCycle)} - Week ${block.currentWeek}';
     }
     ```
     This changes the label from "Leader 1 - Week 1" to "5's Pro BBB - Week 1".

  2. Add a `cycleBadge` getter:
     ```dart
     String get cycleBadge {
       if (_activeBlock == null) return '';
       return getCycleBadge(_activeBlock!.currentCycle);
     }
     ```

  3. Add an `updateTm` method to persist TM changes from inline editing:
     ```dart
     Future<void> updateTm({
       required String exercise,
       required double value,
     }) async {
       if (_activeBlock == null) return;
       final block = _activeBlock!;

       FiveThreeOneBlocksCompanion companion;
       switch (exercise) {
         case 'squat':
           companion = FiveThreeOneBlocksCompanion(squatTm: Value(value));
           break;
         case 'bench':
           companion = FiveThreeOneBlocksCompanion(benchTm: Value(value));
           break;
         case 'deadlift':
           companion = FiveThreeOneBlocksCompanion(deadliftTm: Value(value));
           break;
         case 'press':
           companion = FiveThreeOneBlocksCompanion(pressTm: Value(value));
           break;
         default:
           return;
       }

       await (db.update(db.fiveThreeOneBlocks)
             ..where((b) => b.id.equals(block.id)))
           .write(companion);

       await refresh();
     }
     ```
     Note: `fivethreeone_state.dart` already imports `package:drift/drift.dart` (for `Value`), so no new imports needed.
  </action>
  <verify>No syntax errors in the two files. `getDescriptiveLabel`, `getCycleBadge`, `updateTm`, `cycleBadge`, and updated `positionLabel` all present. Grep for `getDescriptiveLabel` in fivethreeone_state.dart confirms usage.</verify>
  <done>schemes.dart has two new functions. State has updateTm method, cycleBadge getter, and positionLabel uses descriptive labels.</done>
</task>

<task type="auto">
  <name>Task 2: Compact TM card with inline editing on block overview page</name>
  <files>lib/fivethreeone/block_overview_page.dart</files>
  <action>
  Redesign `_TmCard` and `_TmTile` to be compact and editable:

  1. **Convert `_TmCard` from StatelessWidget to StatefulWidget** so it can manage TextEditingControllers for the four TM fields.

  2. **Replace `_TmTile` display-only widgets with compact inline-editable fields.** Layout the 4 TM fields in a 2x2 grid using two Rows, each with two Expanded children. Each field should be a compact `TextField` with:
     - `isDense: true` on InputDecoration
     - `contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)`
     - `labelText` set to the lift name (Squat, Bench, Deadlift, OHP)
     - `suffixText` set to `block.unit`
     - `border: OutlineInputBorder()`
     - `keyboardType: TextInputType.numberWithOptions(decimal: true)`
     - `inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]`
     - `onSubmitted` callback that parses the value and calls `context.read<FiveThreeOneState>().updateTm(exercise: 'squat', value: parsedValue)` (matching exercise key per field)
     - Also call `updateTm` on `onEditingComplete` or when focus is lost (use `FocusNode` with `addListener` to detect unfocus and save)

  3. **Reduce spacing**: Remove `const SizedBox(height: 12)` between the header row and the TM fields. Use `SizedBox(height: 8)` between the two rows of fields. Reduce overall card padding from 16 to 12.

  4. **Remove the old `_TmTile` StatelessWidget** entirely (it's replaced by inline TextFields).

  5. **Keep the "Training Max" header row** with icon and unit badge but make it tighter: remove the Spacer and unit badge row if needed, or keep it slim.

  6. **Update the AppBar title** in `BlockOverviewPage.build()`:
     The current title is `'5/3/1 ${state.positionLabel}'`. Since `positionLabel` now returns descriptive labels (from Task 1), this automatically updates. No change needed here.

  Import `package:flutter/services.dart` (for `FilteringTextInputFormatter`) and ensure Provider is imported.
  </action>
  <verify>Grep block_overview_page.dart for `TextEditingController`, `updateTm`, `isDense`, and `FilteringTextInputFormatter` to confirm editable TM fields. Confirm `_TmTile` class is removed. Confirm padding values are reduced.</verify>
  <done>TM card is a compact 2x2 grid of editable TextFields. Editing a value and pressing done/losing focus persists the change via FiveThreeOneState.updateTm. Card uses less vertical space. Old _TmTile removed.</done>
</task>

<task type="auto">
  <name>Task 3: Phase badge and descriptive label in notes banner</name>
  <files>lib/notes/notes_page.dart</files>
  <action>
  Update `_TrainingMaxBanner` in notes_page.dart:

  1. **Replace barbell icon with phase badge** when a block is active. Instead of:
     ```dart
     child: Icon(
       Icons.fitness_center,
       size: 24,
       color: iconColor,
     ),
     ```
     Use a conditional: when `hasBlock`, show a Text badge with `fiveThreeOneState.cycleBadge` inside the same `Container(padding: EdgeInsets.all(8), ...)`. Style the badge text as bold, fontSize 14-16, same `iconColor`. When no block, keep the barbell icon as-is.

     The badge container should remain the same size/shape. Example:
     ```dart
     child: hasBlock
         ? Text(
             fiveThreeOneState.cycleBadge,
             style: TextStyle(
               fontSize: 14,
               fontWeight: FontWeight.bold,
               color: iconColor,
             ),
           )
         : Icon(
             Icons.fitness_center,
             size: 24,
             color: iconColor,
           ),
     ```

  2. **The label text is already `fiveThreeOneState.positionLabel`** which was updated in Task 1 to return descriptive labels. No change needed for the label text itself.

  3. Import `schemes.dart` is NOT needed in notes_page.dart because the badge comes from `FiveThreeOneState.cycleBadge` (added in Task 1).
  </action>
  <verify>Grep notes_page.dart for `cycleBadge` to confirm badge usage. Confirm `Icons.fitness_center` is now conditional (only shown when no active block).</verify>
  <done>Notes banner shows "L1"/"L2"/"D"/"A"/"T" badge instead of barbell icon when a block is active. Label reads "5's Pro BBB - Week 1" style due to positionLabel update.</done>
</task>

<task type="auto">
  <name>Task 4: Make calculator TM field editable in block mode</name>
  <files>lib/widgets/five_three_one_calculator.dart</files>
  <action>
  In `five_three_one_calculator.dart`, the block mode currently renders the TM TextField as `readOnly: true` (line 369). Change this:

  1. **Remove the `if (_isBlockMode)` / `else` branching** for the TextField (lines 366-391). Use a single TextField for both modes. The TextField should always be editable.

  2. **For block mode, update `onChanged`** to save to the block instead of settings. Create a method `_saveBlockTm()` that:
     - Parses `_tmController.text` to double
     - If valid, calls `context.read<FiveThreeOneState>().updateTm(exercise: _getExerciseKey(), value: tm)`
     - Updates local `_trainingMax` state

  3. **Update `onChanged` handler** to call `_saveBlockTm()` when `_isBlockMode` is true, and `_saveTrainingMax()` when false:
     ```dart
     onChanged: (_) {
       if (_isBlockMode) {
         _saveBlockTm();
       } else {
         _saveTrainingMax();
       }
     },
     ```

  4. **Also update the block mode position header** (line 398) to use `getDescriptiveLabel` instead of manual formatting. Change:
     ```dart
     '${getMainSchemeName(_blockCycleType)} — ${cycleNames[_blockCycleType]}, Week $_blockWeek',
     ```
     to:
     ```dart
     '${getDescriptiveLabel(_blockCycleType)} — Week $_blockWeek',
     ```
     This shows "5's Pro BBB — Week 1" instead of "5's PRO — Leader 1, Week 1".

  Import `schemes.dart` is already imported. No new imports needed.
  </action>
  <verify>Grep five_three_one_calculator.dart for `readOnly` -- should NOT appear. Grep for `_saveBlockTm` to confirm new method exists. Grep for `getDescriptiveLabel` to confirm updated header.</verify>
  <done>Calculator TM field is editable in block mode. Changes persist to the block via FiveThreeOneState.updateTm. Header shows descriptive label format.</done>
</task>

</tasks>

<verification>
- Block overview page: TM card is a compact 2x2 editable grid. Editing a value persists it. Page fits on screen without scrolling to reach Complete Week.
- Notes banner: Shows cycle badge (L1/L2/D/A/T) and descriptive label ("5's Pro BBB - Week 1").
- Calculator: TM field is editable in block mode with changes persisted. Header uses descriptive label.
- AppBar title in block overview automatically shows descriptive label.
- No regressions: manual mode (no active block) calculator still works as before. Banner without active block still shows barbell icon and "Start a 5/3/1 block" text.
</verification>

<success_criteria>
- All four files modified with no syntax errors
- TM values editable in both block overview page and calculator during active block
- Descriptive phase labels shown in notes banner, block overview AppBar, and calculator header
- Phase badge (L1/L2/D/A/T) shown in notes banner instead of barbell icon when block active
- Compact TM display reduces vertical space significantly (no individual _TmTile widgets)
</success_criteria>

<output>
After completion, create `.planning/quick/005-531-ui-compact-tm-editable-phase-labels/005-SUMMARY.md`
</output>
