---
phase: quick-013
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/widgets/five_three_one_calculator.dart
  - lib/widgets/training_max_editor.dart
autonomous: true
requirements: [QUICK-013]
must_haves:
  truths:
    - "Long-pressing exercise then tapping 5/3/1 Calculator always shows block-based layout when active block exists"
    - "No flash of old week-selector UI on first open"
    - "When no active block exists, calculator shows a 'no active block' message instead of old manual mode"
  artifacts:
    - path: "lib/widgets/five_three_one_calculator.dart"
      provides: "Block-only 5/3/1 calculator dialog"
  key_links:
    - from: "lib/widgets/five_three_one_calculator.dart"
      to: "FiveThreeOneState"
      via: "context.read<FiveThreeOneState>() synchronous access"
      pattern: "context\\.read<FiveThreeOneState>"
---

<objective>
Remove old manual-mode 5/3/1 calculator UI (week selector W1-W4, settings-based TMs, progress cycle button) from FiveThreeOneCalculator. Keep only the block-based layout that reads from the active FiveThreeOneBlock.

Purpose: Fix bug where long-pressing exercise and tapping "5/3/1 Calculator" first shows old manual UI (because _isBlockMode defaults false and _loadSettings is async), then on second open shows correct block UI.

Output: FiveThreeOneCalculator that synchronously reads FiveThreeOneState and only renders block-based layout. Delete unused TrainingMaxEditor widget.
</objective>

<execution_context>
@C:/Users/USER/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/USER/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/widgets/five_three_one_calculator.dart
@lib/fivethreeone/fivethreeone_state.dart
@lib/plan/exercise_sets_card.dart (lines 306-369: menu item + _show531Calculator)
@lib/widgets/training_max_editor.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Rewrite FiveThreeOneCalculator to block-only mode</name>
  <files>lib/widgets/five_three_one_calculator.dart</files>
  <action>
Rewrite `FiveThreeOneCalculator` to remove the dual-mode (manual vs block) pattern:

1. **Remove all manual-mode state and methods:**
   - Remove `_currentWeek` field
   - Remove `_isBlockMode` field (everything is now block-only)
   - Remove `_getWorkingSetScheme()` method (hardcoded week schemes)
   - Remove `_updateWeek()` method (settings week persistence)
   - Remove `_progressCycle()` method (cycle completion + TM increment)
   - Remove `_saveTrainingMax()` method (settings-based TM save)

2. **Make _loadSettings synchronous for block data:**
   - In `initState`, read `FiveThreeOneState` from context synchronously via `context.read<FiveThreeOneState>()`
   - If `state.hasActiveBlock`, populate `_trainingMax`, `_unit`, `_blockCycleType`, `_blockWeek` immediately (no async gap, no setState needed)
   - Keep `_tmController` initialization with the resolved TM value
   - Keep `_saveBlockTm()` for inline TM editing (writes to block via FiveThreeOneState.updateTm)

3. **Update build() method:**
   - Remove all `if (!_isBlockMode)` / `if (_isBlockMode)` branches -- only keep the block-mode branches
   - Remove the `SegmentedButton<int>` week selector entirely
   - Remove the `weekName` variable and manual-mode week header
   - Remove the "Complete Cycle & Increase TM" `FilledButton` at the bottom
   - Keep: header with cycle/week label, TM input field, working sets list from `getMainScheme()`, supplemental section, TM test banner, info footer

4. **Handle no-active-block case:**
   - If `FiveThreeOneState.hasActiveBlock` is false, show a simple centered message: "No active 5/3/1 block" with a subtitle "Create a block from the 5/3/1 page to use the calculator" and a Close button
   - This replaces the old fallback to manual mode

5. **Clean up imports:**
   - Remove `import '../database/database.dart'` if no longer needed (was used for settings queries)
   - Remove `import '../settings/settings_state.dart'` (was used for manual mode unit)
   - Keep `import '../fivethreeone/fivethreeone_state.dart'` and `import '../fivethreeone/schemes.dart'`
  </action>
  <verify>Run `rg "SegmentedButton|_currentWeek|_isBlockMode|_updateWeek|_progressCycle|_saveTrainingMax|_getWorkingSetScheme" lib/widgets/five_three_one_calculator.dart` returns no results (all manual-mode code removed). Run `rg "FiveThreeOneCalculator" lib/` confirms widget still exists and is imported.</verify>
  <done>FiveThreeOneCalculator only shows block-based layout. No manual week selector. No async race condition. No-active-block case shows informational message instead of old manual UI.</done>
</task>

<task type="auto">
  <name>Task 2: Delete unused TrainingMaxEditor widget</name>
  <files>lib/widgets/training_max_editor.dart</files>
  <action>
Delete `lib/widgets/training_max_editor.dart` entirely. This widget edits settings-based TM values (fivethreeoneSquatTm etc.) and is not imported or used anywhere in the codebase (confirmed via grep -- only self-references found). It is dead code from the pre-block era.

Verify no imports reference it before deleting: `rg "training_max_editor" lib/ --glob "!training_max_editor.dart"` should return nothing.
  </action>
  <verify>File `lib/widgets/training_max_editor.dart` no longer exists. `rg "TrainingMaxEditor" lib/` returns no results.</verify>
  <done>Dead TrainingMaxEditor widget removed from codebase.</done>
</task>

</tasks>

<verification>
- `rg "SegmentedButton|_currentWeek|_isBlockMode|_updateWeek|_progressCycle" lib/widgets/five_three_one_calculator.dart` returns empty (old UI code gone)
- `rg "TrainingMaxEditor|training_max_editor" lib/` returns empty (dead code removed)
- `rg "FiveThreeOneCalculator" lib/plan/exercise_sets_card.dart` still shows the import and usage (widget still wired in)
- No database schema changes (settings table columns remain for backward compatibility)
</verification>

<success_criteria>
- 5/3/1 Calculator opened from exercise long-press menu always shows block-based layout immediately (no flash of old UI)
- When no active block exists, shows informational "no active block" message
- Old manual-mode code (week selector, settings TMs, progress cycle) fully removed
- Dead TrainingMaxEditor widget deleted
- No breaking changes to database schema or other features
</success_criteria>

<output>
After completion, create `.planning/quick/13-remove-old-531-calculator-ui-keep-only-n/13-SUMMARY.md`
</output>
