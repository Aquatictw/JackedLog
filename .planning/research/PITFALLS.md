# Domain Pitfalls: 5/3/1 Forever Block Programming

**Domain:** Adding 5/3/1 Forever block programming to existing Flutter fitness tracking app
**Researched:** 2026-02-11
**Codebase:** JackedLog (Flutter + Drift v63 + Provider)
**Mode:** Subsequent milestone -- integration with existing system

---

## Critical Pitfalls

Mistakes that cause data loss, incorrect weight calculations, or require rewrites.

---

### Pitfall 1: Settings Table Overload -- Block State Crammed Into Flat Columns

**What goes wrong:** The current 5/3/1 state lives in the Settings table as 5 flat columns (`fivethreeone_squat_tm`, `fivethreeone_bench_tm`, `fivethreeone_deadlift_tm`, `fivethreeone_press_tm`, `fivethreeone_week`). The temptation is to keep adding columns: `fivethreeone_cycle_type`, `fivethreeone_cycle_number`, `fivethreeone_block_week`, etc. This creates a denormalized mess that cannot support multiple blocks, history, or rollback.

**Why it happens:**
- Path of least resistance: adding columns is easier than creating tables
- Existing calculator already reads from Settings, so "just add more columns" feels natural
- Fear of migration complexity drives shortcuts
- Single-row Settings table creates false sense of simplicity

**Consequences:**
- No block history: when a block completes, all state is overwritten
- Cannot undo a mistaken TM bump (old TM is gone)
- Cannot support multiple concurrent blocks or block templates
- TM values become ambiguous: are they pre-bump or post-bump for the current cycle?
- Export/import breaks if Settings columns keep growing
- SettingsState notifies ALL listeners on ANY settings change (performance)

**Warning signs:**
- Settings table exceeds 10-15 5/3/1-related columns
- Code has conditionals like `if (settings.cycleType == 'leader1' && settings.cycleNumber == 1)`
- No way to answer "what was my squat TM 3 blocks ago?"
- TM values and cycle position disagree after an app crash mid-progression

**Prevention:**
Create a proper normalized schema with dedicated tables:

```
blocks table:
  id, created, status (active/completed/abandoned)

block_cycles table:
  id, block_id, cycle_type (leader1/leader2/deload/anchor/tm_test),
  cycle_number, status (active/completed/skipped)

block_cycle_weeks table:
  id, block_cycle_id, week_number, status (active/completed/skipped)

training_maxes table:
  id, block_cycle_id, exercise, value, unit, created
  (snapshot per cycle -- enables TM history and rollback)
```

**Keep existing Settings columns** as the "current" quick-access cache. The new tables are the source of truth; Settings columns are a derived cache for the calculator's fast path.

**Phase assignment:** Phase 1 (schema design) -- get this right before writing any UI code.

**Confidence:** HIGH -- Based on direct analysis of existing `settings.dart` (59 lines, already 5 531 columns) and `database.dart` (migration history shows Settings table growing with each feature).

---

### Pitfall 2: TM Progression Applied at Wrong Time or Wrong Amount

**What goes wrong:** Training Max is bumped at the wrong point in the block, by the wrong increment, or applied to the wrong exercise. User completes Leader 1 Week 3 and the app bumps TM immediately, making Leader 2 use wrong (already-bumped) values.

**Why it happens:**
- 5/3/1 Forever TM progression rules are nuanced and easy to misimplement:
  - TM bumps happen BETWEEN cycles, not at the end of a week
  - Upper body: +2.5kg / +5lb; Lower body: +5kg / +10lb
  - The user's specific bumps (+2.2kg upper, +4.5kg lower) differ from Wendler's standard
  - TM bumps after Leader 1, Leader 2, AND Anchor (3 bumps per 11-week block)
  - But NOT after the 7th Week Deload or TM Test
- Code path for "advance to next cycle" conflates cycle transition with TM bump
- Current `_progressCycle()` in `five_three_one_calculator.dart` bumps AND resets week in one action -- this pattern does not extend to selective bumps

**Consequences:**
- Weights calculated too high or too low for entire 3-week cycles
- User lifts wrong percentages for weeks, eroding program effectiveness
- Compounding error: if Leader 1 bump is wrong, Leader 2 and Anchor are both off
- User loses trust in the calculator and reverts to spreadsheets

**Warning signs:**
- After advancing from Leader 1 to Leader 2, the 85% set weight changed when it should not have (or vice versa)
- TM Test weights do not match what the user expected
- User reports "my weights jumped twice" or "my weights did not increase"

**Prevention:**

1. **Separate cycle transition from TM bump.** Two distinct operations:
   - `advanceCycle()` -- moves position forward (e.g., Leader 1 -> Leader 2)
   - `bumpTrainingMax(exercise, amount)` -- creates new TM snapshot

2. **Make TM bumps configurable per user.** Store increment amounts in settings or block config, not hardcoded. Current code hardcodes `2.5 / 5.0` for kg and `5.0 / 10.0` for lb. User wants `2.2 / 4.5` for kg. This must be user-editable.

3. **Snapshot TMs per cycle.** When a cycle starts, snapshot the current TMs into `training_maxes`. The cycle uses its snapshot, not the live Settings value. This prevents mid-cycle corruption.

4. **Define bump rules declaratively:**
   ```dart
   const bumpAfterCycle = {
     CycleType.leader1: true,
     CycleType.leader2: true,
     CycleType.deload: false,
     CycleType.anchor: true,
     CycleType.tmTest: false,
   };
   ```

**Phase assignment:** Phase 2 (progression logic) -- implement after schema but before UI.

**Confidence:** HIGH -- Based on analysis of `_progressCycle()` in `five_three_one_calculator.dart:144-176`, user requirements in `PROJECT.md`, and 5/3/1 Forever program rules from [Jim Wendler's blog](https://www.jimwendler.com/blogs/jimwendler-com/101082310-the-training-max-what-you-need-to-know) and [T-Nation discussions](https://t-nation.com/t/increasing-tm-after-anchor-deload/235856).

---

### Pitfall 3: Weight Rounding Produces Unloadable Plates

**What goes wrong:** Calculator shows 67.3kg or 142.7lb -- weights that cannot be physically loaded on a barbell. Or worse, rounding accumulates errors across sets: warmup rounds down, working set rounds up, creating a larger gap than intended.

**Why it happens:**
- Current `_calculateWeight()` rounds to nearest 2.5kg or 5lb, which is correct for working sets
- But supplemental work adds new percentage calculations (BBB 5x10 @ 60%, FSL 5x5 @ first-set weight) that may round differently
- Floating-point arithmetic: `100.0 * 0.65 = 64.99999999999999` (not 65.0)
- Different rounding for warmup vs working vs supplemental creates inconsistency
- Plate availability varies by gym (some have 1.25kg plates, some do not)

**Consequences:**
- User cannot load the displayed weight
- Weights appear to "jump" by 5kg between sets that should differ by 2.5kg
- Supplemental work at 60% of TM rounds to same weight as a 65% working set, confusing the user
- Users in lb units see different rounding behavior than kg users

**Warning signs:**
- Displayed weight ends in .1, .3, .7, .9 (not loadable)
- Two sets at "different" percentages show same weight after rounding
- User reports "BBB weight is too high" or "FSL weight doesn't match week 1 working set"

**Prevention:**

1. **Single rounding function used everywhere:**
   ```dart
   double roundWeight(double weight, String unit) {
     final increment = unit == 'kg' ? 2.5 : 5.0;
     return (weight / increment).round() * increment;
   }
   ```
   The existing `_calculateWeight()` already does this correctly. Extract it to a shared utility and ensure ALL new percentage calculations use it.

2. **Round AFTER all arithmetic, never in intermediate steps:**
   ```dart
   // BAD: Round intermediate values
   final fslWeight = roundWeight(tm * 0.65, unit); // First set
   final bbbWeight = roundWeight(fslWeight * 0.92, unit); // Compounds error

   // GOOD: Calculate from TM, round once
   final fslWeight = roundWeight(tm * 0.65, unit);
   final bbbWeight = roundWeight(tm * 0.60, unit);
   ```

3. **Test rounding at boundary values.** The dangerous inputs are TM values that produce percentages landing exactly between rounding targets:
   - TM = 102.5kg -> 65% = 66.625 -> rounds to 67.5 (correct) or 65.0 (wrong)
   - TM = 135lb -> 60% = 81.0 -> rounds to 80 (correct, both round to same)

4. **Display the actual percentage after rounding** so users can verify:
   `"82.5 kg (65% TM)"` not just `"82.5 kg"`

**Phase assignment:** Phase 2 (calculator refactoring) -- when adding new percentage schemes.

**Confidence:** HIGH -- Based on existing `_calculateWeight()` at line 210-217 of `five_three_one_calculator.dart` and [floating-point rounding bugs reported in gym calculator apps](https://apps.apple.com/us/app/bar-is-loaded-gym-calculator/id1509374210).

---

### Pitfall 4: Migration Breaks Export/Import Backward Compatibility

**What goes wrong:** Adding new tables (blocks, cycles, training_maxes) to database v63+ means older exports cannot be reimported, or new exports crash on older app versions. The existing CSV export only covers `workouts` and `gym_sets` tables -- new block data would be lost on export.

**Why it happens:**
- Export code (`export_data.dart`) hardcodes table names and column lists
- Import code (`import_data.dart`) hardcodes expected CSV headers and column indices
- Database import copies the raw `.sqlite` file, which WILL include new tables -- but older app version cannot read them
- New tables have no CSV export/import path at all
- Settings table changes (new 5/3/1 columns) affect database import but not CSV import

**Consequences:**
- User exports data, reinstalls app (older version), imports -- crash or data loss
- User exports CSV workouts, imports on new version -- block state is completely lost
- Auto-backup creates database file with new schema -- restore to old version fails
- CLAUDE.md explicitly states: "If database version has been changed, and previous exported data from app can't be reimported, affirm me"

**Warning signs:**
- Import crashes with "missing column" or "table not found" after schema change
- Export file size unchanged despite new block data (block data not exported)
- Settings import silently drops new 5/3/1 block columns

**Prevention:**

1. **Block data stored in new tables, not Settings columns.** Existing Settings columns (`fivethreeone_*`) remain as backward-compatible cache. New block tables are additive -- older imports that lack them just result in "no block configured."

2. **Migration must handle gracefully:**
   ```sql
   -- New tables created with IF NOT EXISTS
   CREATE TABLE IF NOT EXISTS blocks (...);

   -- Existing Settings columns kept as-is (no removal)
   -- New columns nullable or with defaults
   ALTER TABLE settings ADD COLUMN fivethreeone_block_id INTEGER;
   ```

3. **Export must include block tables** if data exists (add to ZIP archive alongside workouts.csv and gym_sets.csv).

4. **Import must tolerate missing block files** (older exports lack them -- just skip).

5. **Test the round-trip:** Export from new version -> Import to new version. Export from old version -> Import to new version. Confirm CLAUDE.md requirement is met.

**Phase assignment:** Phase 1 (schema) AND Phase 4 (export/import update).

**Confidence:** HIGH -- Based on direct analysis of `export_data.dart` (hardcoded columns at lines 64-91), `import_data.dart` (hardcoded column parsing at lines 235-294), and CLAUDE.md requirement about backward compatibility.

---

## Moderate Pitfalls

Mistakes that cause bugs, UX confusion, or technical debt.

---

### Pitfall 5: Block State and Workout State Interaction Complexity

**What goes wrong:** Block state (which cycle, which week) and workout state (active workout, plan exercises) become entangled. Starting a workout should show the correct 5/3/1 scheme for the current block position, but the two state systems do not communicate cleanly.

**Why it happens:**
- `WorkoutState` manages active workout lifecycle (start/stop/discard)
- `SettingsState` manages 5/3/1 TMs and week number
- New `BlockState` would need to inform both: calculator reads block position for percentages, workout may need to know which cycle type for supplemental work display
- Three ChangeNotifiers that depend on each other create circular update chains
- Provider does not handle cross-notifier dependencies well without careful design

**Consequences:**
- Calculator shows Leader 1 percentages while block state says user is in Anchor
- Advancing the block does not update the calculator until app restart
- Race condition: user starts workout, advances week in calculator, stops workout -- block position corrupted
- UI shows stale block position after manual advancement

**Warning signs:**
- Calculator displays wrong cycle type or week number
- Block timeline shows different position than calculator header
- Advancing a week requires navigating away and back for UI to update
- Two simultaneous writes to block state (one from workout completion, one from manual advance)

**Prevention:**

1. **BlockState as single source of truth.** Calculator and workout UI both READ from BlockState. Neither writes block position directly -- they call BlockState methods.

2. **Unidirectional data flow:**
   ```
   User action -> BlockState.advanceWeek() -> writes to DB -> stream triggers SettingsState update
                                                            -> stream triggers BlockState update
                                                            -> Calculator reads from BlockState
   ```

3. **Do NOT couple workout completion to block advancement.** The user advances weeks/cycles manually (per PROJECT.md: "User advances weeks/cycles manually (not auto-detect)"). This simplifies the state flow enormously -- workout state does not need to know about block state at all.

4. **Use Drift's stream-based reactivity** (existing pattern in `SettingsState`). BlockState watches block tables, notifies listeners on change. Calculator reads from BlockState, not directly from database.

**Phase assignment:** Phase 2 (state management design) -- before building UI.

**Confidence:** HIGH -- Based on analysis of `workout_state.dart`, `settings_state.dart` (stream subscription pattern at line 26), and `five_three_one_calculator.dart` (reads Settings directly at line 49).

---

### Pitfall 6: Calculator Becomes Unmanageable With Multiple Percentage Schemes

**What goes wrong:** Current calculator has ONE scheme method `_getWorkingSetScheme()` with a 4-case switch. Block programming requires FIVE different schemes (5's PRO, original 5/3/1 PR sets, 7th Week Deload, 7th Week TM Test, plus supplemental variations BBB/FSL). Adding all as switch cases creates an unmaintainable method.

**Why it happens:**
- Existing code is a simple widget with inline logic (`five_three_one_calculator.dart`)
- Temptation to keep extending the switch statement
- Supplemental work has its own sets/reps/percentages that multiply the display complexity
- Different cycle types have different AMRAP rules (5's PRO has no AMRAP, original 5/3/1 does)

**Consequences:**
- Single 300+ line method that handles all schemes
- Bugs where changing one scheme accidentally affects another
- Cannot add new templates (e.g., SSL, BBS) without touching core logic
- Testing becomes impractical

**Warning signs:**
- `_getWorkingSetScheme()` exceeds 50 lines
- Method has nested conditionals: `if (cycleType == ... && week == ... && supplemental == ...)`
- Same percentage appears in multiple places with slightly different logic
- Adding a new scheme requires changing 4+ locations

**Prevention:**

1. **Extract scheme definitions into data, not code:**
   ```dart
   class SetScheme {
     final double percentage;
     final int reps;
     final bool amrap;
     const SetScheme(this.percentage, this.reps, {this.amrap = false});
   }

   // Leader: 5's PRO (no AMRAP)
   const fivesProSchemes = {
     1: [SetScheme(0.65, 5), SetScheme(0.75, 5), SetScheme(0.85, 5)],
     2: [SetScheme(0.70, 3), SetScheme(0.80, 3), SetScheme(0.90, 3)],
     3: [SetScheme(0.75, 5), SetScheme(0.85, 3), SetScheme(0.95, 1)],
   };

   // Anchor: Original 5/3/1 (AMRAP on top set)
   const prSetSchemes = {
     1: [SetScheme(0.65, 5), SetScheme(0.75, 5), SetScheme(0.85, 5, amrap: true)],
     // ...
   };
   ```

2. **Supplemental work as separate data structure:**
   ```dart
   class SupplementalScheme {
     final String name; // "BBB", "FSL"
     final int sets;
     final int reps;
     final double percentage; // of TM
     const SupplementalScheme(this.name, this.sets, this.reps, this.percentage);
   }

   const bbb = SupplementalScheme('BBB', 5, 10, 0.60);
   const fsl = SupplementalScheme('FSL', 5, 5, 0.65); // Uses week 1 first-set %
   ```

3. **Calculator widget consumes data, does not generate it.** The widget receives a `List<SetScheme>` and renders it. It does not decide which scheme to use -- that is BlockState's job.

**Phase assignment:** Phase 2 (calculator refactoring).

**Confidence:** HIGH -- Based on analysis of `_getWorkingSetScheme()` at lines 179-208 in `five_three_one_calculator.dart`.

---

### Pitfall 7: Block Timeline UI Overcomplicates the Simple App

**What goes wrong:** Adding an 11-week visual timeline with week markers, cycle labels, and progress indicators turns a clean, focused app into a cluttered experience. The block overview page becomes the most complex screen in the app.

**Why it happens:**
- Desire to show the "full picture" of the 11-week block all at once
- Complex timeline widgets with custom painting, scroll behavior, state indicators
- Overloading a single page with setup, progress, TM display, and navigation
- Not following the app's existing KISS principle

**Consequences:**
- Block overview takes as long to build as all other v1.2 features combined
- Mobile screens too narrow for meaningful 11-week horizontal timeline
- Performance issues from complex custom widgets
- Scope creep: "while we are building the timeline, let us add..."

**Warning signs:**
- Block overview page exceeds 500 lines
- Custom paint code for timeline visualization
- Horizontal scroll required to see full block
- Multiple design iterations that delay the milestone

**Prevention:**

1. **Start with the simplest possible representation:**
   ```
   Block 1 - Week 5 of 11
   [Leader 2] Week 2 of 3

   Squat TM: 130.0 kg
   Bench TM: 85.0 kg
   ...

   [Advance Week]
   ```
   Text-based status, no custom graphics. This can ship in hours.

2. **Timeline as enhancement, not MVP.** If a visual timeline is desired, add it in a later phase AFTER the core logic works.

3. **Follow existing UI patterns.** The app uses ListTile, Card, SegmentedButton. Use these, not custom timeline widgets.

4. **Scope guard:** The block overview is a STATUS DISPLAY, not an interactive planner. Users advance manually. No drag-drop week rearrangement, no "what-if" projections.

**Phase assignment:** Phase 3 (UI) -- build simple first, enhance later.

**Confidence:** HIGH -- Based on app's existing design language (Material, simple widgets) and KISS principle from CLAUDE.md.

---

### Pitfall 8: Mid-Block Edge Cases Corrupt State

**What goes wrong:** User skips a week, restarts a cycle, adjusts TM mid-cycle, or abandons a block partway through. The block state machine does not handle these non-linear transitions and enters an invalid state.

**Why it happens:**
- Happy-path development: code assumes linear progression through weeks 1-2-3, then cycle advance
- Real users skip weeks (vacation, injury, schedule conflicts)
- Users want to adjust TM mid-cycle after a bad day
- Users want to restart the current cycle after a deload
- No state machine formalization -- just increment/decrement logic

**Consequences:**
- Skipping a week leaves block stuck on "Week 3 of 3" with no way to advance
- Mid-cycle TM adjustment uses wrong TMs for remaining weeks (partially old, partially new)
- Restarting a cycle does not reset the TM snapshot, so week 1 uses post-bump weights
- Abandoning a block leaves orphaned database records

**Warning signs:**
- "Advance Week" button grayed out or missing after non-linear navigation
- Block position shows "Week 4 of 3" or negative values
- After TM adjustment, some exercises use old TM and some use new TM
- No way to go backward (only forward)

**Prevention:**

1. **Manual advancement means simple operations.** Since the user controls week/cycle advancement (not auto-detect), the state machine is just:
   - `advanceWeek()` -- increment week within cycle, or advance to next cycle
   - `skipWeek()` -- mark week as skipped, advance position
   - No need for complex auto-detection or workout-completion triggers

2. **TM adjustments create new snapshots:**
   ```dart
   Future<void> adjustTm(String exercise, double newTm) async {
     // Create new TM record for current cycle
     // All future calculations use this new value
     // Previous TM records preserved for history
   }
   ```

3. **Block abandonment is just status change:**
   ```dart
   Future<void> abandonBlock() async {
     // Set block status to 'abandoned'
     // Do NOT delete records
     // User can start a new block
   }
   ```

4. **Validate transitions.** Before advancing, check:
   - Is there a next week/cycle in the block definition?
   - If advancing to next cycle, should TM be bumped? (per cycle type rules)

5. **Provide "Reset Current Cycle" option** that creates fresh TM snapshots for the cycle without affecting block history.

**Phase assignment:** Phase 2 (state logic) -- model all transitions including edge cases.

**Confidence:** MEDIUM -- Edge cases are speculative based on how users interact with periodized programs. The specific edge cases listed come from [T-Nation 5/3/1 forum discussions](https://t-nation.com/t/doubt-about-leader-anchor-setup-in-forever/229773) and user behavior patterns.

---

### Pitfall 9: Database Migration Error Handling Gaps

**What goes wrong:** Migration from v63 to v64+ fails partway through (adding multiple new tables), leaving database in an inconsistent state. Tables partially created, no rollback.

**Why it happens:**
- Block programming requires 3-4 new tables, potentially created in a single migration step
- SQLite does not support transactional DDL (CREATE TABLE) rollback in all cases
- Current migration pattern uses `.catchError((e) {})` which silently swallows errors
- If table creation succeeds but backfill fails, schema version is already bumped
- App re-opens, sees version 64, skips migration, but data is incomplete

**Consequences:**
- App crashes on startup after failed migration
- User stuck in broken state requiring reinstall
- Data loss if migration partially applied
- FailedMigrationsPage shown but no recovery path

**Warning signs:**
- Migration creates table A successfully, table B fails -- but table A cannot be rolled back
- `.catchError` on ALTER TABLE hides real errors (column already exists vs. table not found)
- Migration block has 10+ SQL statements without intermediate error checking

**Prevention:**

1. **Create new tables with IF NOT EXISTS** (safe to re-run):
   ```sql
   CREATE TABLE IF NOT EXISTS blocks (...);
   CREATE TABLE IF NOT EXISTS block_cycles (...);
   ```

2. **Use multiple migration boundaries** if changes are independent:
   ```dart
   // v63 -> v64: Create block tables
   if (from < 64 && to >= 64) {
     await m.database.customStatement('CREATE TABLE IF NOT EXISTS blocks (...)');
     await m.database.customStatement('CREATE TABLE IF NOT EXISTS block_cycles (...)');
   }

   // v64 -> v65: Add settings columns for block reference
   if (from < 65 && to >= 65) {
     await m.database.customStatement(
       'ALTER TABLE settings ADD COLUMN fivethreeone_block_id INTEGER',
     ).catchError((e) {});
   }
   ```
   BUT: consider whether splitting across multiple schema versions is necessary. If the tables and columns are all part of one coherent feature, a single version bump with idempotent statements (IF NOT EXISTS, .catchError for ALTER) is cleaner and matches the existing codebase pattern.

3. **Follow existing pattern:** The codebase consolidates related changes into single version boundaries (e.g., `from52To57` handles 5 version changes). This is fine as long as individual statements are idempotent.

4. **Do NOT use `.catchError((e) {})` for CREATE TABLE** -- only for ALTER TABLE (where column may already exist). CREATE TABLE failures indicate real problems.

**Phase assignment:** Phase 1 (schema migration).

**Confidence:** HIGH -- Based on analysis of migration patterns in `database.dart` lines 60-413, particularly the catchError pattern used for ALTER TABLE statements.

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable without major rework.

---

### Pitfall 10: Hardcoded 11-Week Block Structure

**What goes wrong:** Code assumes all blocks are exactly 11 weeks (L1:3 + L2:3 + D:1 + A:3 + TT:1). User wants to try a different template (e.g., 1 Leader + 1 Anchor, or 3 Leaders), and the app cannot accommodate it.

**Why it happens:**
- YAGNI says build for the current use case (11-week blocks)
- But hardcoding `11` and `[3, 3, 1, 3, 1]` throughout the codebase makes future changes painful
- Constants embedded in UI strings, progression logic, and timeline display

**Prevention:**
- Define block structure as data, not code constants:
  ```dart
  class BlockTemplate {
    final List<CycleDefinition> cycles;
    int get totalWeeks => cycles.fold(0, (sum, c) => sum + c.weeks);
  }

  final standardBlock = BlockTemplate(cycles: [
    CycleDefinition(type: CycleType.leader, weeks: 3, bumpTm: true),
    CycleDefinition(type: CycleType.leader, weeks: 3, bumpTm: true),
    CycleDefinition(type: CycleType.deload, weeks: 1, bumpTm: false),
    CycleDefinition(type: CycleType.anchor, weeks: 3, bumpTm: true),
    CycleDefinition(type: CycleType.tmTest, weeks: 1, bumpTm: false),
  ]);
  ```
- For now, only support ONE template. But define it as data so adding another later is trivial.
- Do NOT expose template customization UI in v1.2 (YAGNI).

**Phase assignment:** Phase 1 (data model design).

**Confidence:** MEDIUM -- Balance between YAGNI (just hardcode) and extensibility. Data-driven approach costs minutes more but saves hours later.

---

### Pitfall 11: FSL Percentage Ambiguity

**What goes wrong:** FSL (First Set Last) supplemental work uses the weight from the first working set of that week. But "first set" percentage changes per week (65% in week 1, 70% in week 2, 75% in week 3). Code incorrectly uses a fixed 65% for all weeks.

**Why it happens:**
- Misunderstanding FSL: it is "First Set _Last_" meaning you repeat the first (lightest) working set at the end
- The first set percentage depends on which week you are in
- Easy to hardcode `0.65` instead of looking up the week's scheme

**Prevention:**
- FSL percentage is always `scheme[currentWeek][0].percentage` -- the first entry in the current week's working set scheme
- Store this relationship explicitly:
  ```dart
  double getFslPercentage(int week) {
    return _getWorkingSetScheme(week).first.percentage;
  }
  ```
- Unit test: FSL week 1 = 65%, week 2 = 70%, week 3 = 75%

**Phase assignment:** Phase 2 (supplemental logic).

**Confidence:** HIGH -- Based on 5/3/1 program definition: FSL uses the first working set weight, which varies by week.

---

### Pitfall 12: Unit Switching Mid-Block

**What goes wrong:** User starts a block with TMs in kg, then switches their preferred unit to lb mid-block. All stored TM values are in kg, but the calculator now displays and rounds in lb. The converted values do not round to plate-loadable weights.

**Why it happens:**
- TM values stored as raw numbers without unit tag
- Current Settings columns (`fivethreeone_squat_tm REAL`) have no associated unit column
- `strengthUnit` setting is global, not per-TM
- Converting 100kg to lb gives 220.462lb, which rounds to 220lb (losing 0.462lb)

**Prevention:**
- Store unit alongside each TM snapshot in the new `training_maxes` table
- On unit preference change, do NOT convert stored values -- let user re-enter TMs or explicitly trigger conversion
- Display a warning if stored TM unit does not match current preference:
  ```
  "TM stored in kg. Your current unit is lb. Convert?"
  ```
- If converting, round to nearest loadable weight in the target unit and show the user what happened

**Phase assignment:** Phase 2 (TM management).

**Confidence:** MEDIUM -- Edge case. Current code stores TMs without unit metadata (`settings.dart` line 45-48 show `REAL` columns with no unit column).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Severity | Mitigation |
|-------------|---------------|----------|------------|
| Schema design | Settings overload (#1) | CRITICAL | Create normalized block tables |
| Schema design | Migration errors (#9) | MODERATE | IF NOT EXISTS, idempotent statements |
| Schema design | Export/import break (#4) | CRITICAL | Additive schema, backward-compatible |
| Schema design | Hardcoded structure (#10) | MINOR | Data-driven block template |
| Progression logic | Wrong TM bump timing (#2) | CRITICAL | Separate advance from bump, declarative rules |
| Progression logic | Weight rounding (#3) | CRITICAL | Single rounding function, round-once rule |
| Progression logic | FSL percentage (#11) | MINOR | Derive from week's first set |
| Progression logic | Unit switching (#12) | MINOR | Store unit with TM, warn on mismatch |
| State management | Block/workout interaction (#5) | MODERATE | Unidirectional flow, manual advance only |
| Calculator UI | Scheme complexity (#6) | MODERATE | Data-driven schemes, calculator renders only |
| Block overview UI | Over-engineering (#7) | MODERATE | Text-based status first, enhance later |
| Edge cases | Mid-block state corruption (#8) | MODERATE | Validate transitions, snapshot TMs |

---

## Codebase-Specific Integration Points

### Files That Must Change

| File | Why | Risk |
|------|-----|------|
| `lib/database/database.dart` | Migration v63->v64+, new table registration | HIGH -- migration must be bulletproof |
| `lib/database/settings.dart` | Possible new columns for block reference | LOW -- additive only |
| `lib/widgets/five_three_one_calculator.dart` | Complete rewrite to support multiple schemes | HIGH -- core feature |
| `lib/widgets/training_max_editor.dart` | Read/write TMs from new table instead of Settings | MEDIUM |
| `lib/settings/settings_state.dart` | May need to expose block state | LOW -- keep existing pattern |
| `lib/export_data.dart` | Export block tables | MEDIUM -- must add new CSV files |
| `lib/import_data.dart` | Import block tables (optional, tolerant) | MEDIUM -- must handle missing data |
| `lib/constants.dart` | Default block template, scheme definitions | LOW -- additive |

### New Files Needed

| File | Purpose |
|------|---------|
| `lib/database/blocks.dart` | Block table definition |
| `lib/database/block_cycles.dart` | Block cycle table definition |
| `lib/database/training_maxes.dart` | TM history table definition |
| `lib/block/block_state.dart` | Block ChangeNotifier state management |
| `lib/block/block_overview_page.dart` | Block status and navigation UI |
| `lib/block/block_setup_page.dart` | Initial block configuration |
| `lib/widgets/five_three_one_schemes.dart` | Data-driven scheme definitions |

---

## Sources

**Codebase Analysis (HIGH confidence):**
- `/home/aquatic/Documents/JackedLog/lib/widgets/five_three_one_calculator.dart` -- Current calculator implementation, `_getWorkingSetScheme()`, `_calculateWeight()`, `_progressCycle()`
- `/home/aquatic/Documents/JackedLog/lib/database/database.dart` -- Migration patterns (v31-v63), Settings table growth pattern
- `/home/aquatic/Documents/JackedLog/lib/database/settings.dart` -- 5/3/1 columns (lines 44-49)
- `/home/aquatic/Documents/JackedLog/lib/workouts/workout_state.dart` -- State management patterns
- `/home/aquatic/Documents/JackedLog/lib/settings/settings_state.dart` -- Stream subscription pattern
- `/home/aquatic/Documents/JackedLog/lib/export_data.dart` -- Export column lists
- `/home/aquatic/Documents/JackedLog/lib/import_data.dart` -- Import parsing logic
- `/home/aquatic/Documents/JackedLog/.planning/PROJECT.md` -- User requirements, TM bump amounts, manual advancement

**5/3/1 Program Rules (MEDIUM confidence):**
- [Jim Wendler - The Training Max](https://www.jimwendler.com/blogs/jimwendler-com/101082310-the-training-max-what-you-need-to-know)
- [T-Nation - Increasing TM After Anchor](https://t-nation.com/t/increasing-tm-after-anchor-deload/235856)
- [T-Nation - Leader/Anchor Setup](https://t-nation.com/t/doubt-about-leader-anchor-setup-in-forever/229773)
- [Lift Vault - Leader & Anchor Cycles Explained](https://liftvault.com/resources/leader-anchor-cycles/)

**Technical References (MEDIUM confidence):**
- [Drift Migrations Documentation](https://drift.simonbinder.eu/docs/advanced-features/migrations/)
- [Floating-point rounding in barbell calculators](https://apps.apple.com/us/app/bar-is-loaded-gym-calculator/id1509374210)
- [Drift Migration Article](https://medium.com/@tagizada.nicat/migration-with-flutter-drift-c9e21e905eeb)
