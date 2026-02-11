# Technology Stack: 5/3/1 Forever Block Programming

**Project:** JackedLog v1.2 - 5/3/1 Block Programming Milestone
**Researched:** 2026-02-11
**Focus:** Database schema for block model, UI for timeline/overview, calculator enhancement, supplemental work display
**Overall Confidence:** HIGH

---

## Executive Summary

The 5/3/1 block programming feature requires **database schema additions** (new table + settings columns) and **no new Flutter packages**. The existing stack (Drift 2.30.0, Provider 6.1.1, Flutter Material 3) provides everything needed. The main technical work is designing the right data model and wiring it through the existing Provider/Drift reactive pipeline.

The key architectural decision is: **one new `fivethreeone_blocks` table** rather than extending the Settings table further. The current Settings table already has 5 columns for 5/3/1 data (4 TMs + week). Adding block/cycle/supplemental state to Settings would bloat a single-row config table into a domain model, violating single responsibility.

---

## Recommended Stack Changes

### Database: New Table + Migration (v63 -> v64)

**Current schema version:** 63 (added `last_backup_status` to settings)

The block model requires tracking:
- Which block is active (or historical)
- Current position within the 11-week structure
- Starting TMs for each block (snapshot, not live)
- Completed status per cycle

#### New Table: `fivethreeone_blocks`

| Column | Type | Purpose | Why |
|--------|------|---------|-----|
| `id` | INTEGER PK AUTO | Row identity | Standard Drift pattern |
| `created` | DATETIME | When block was created | Ordering, history |
| `squat_tm` | REAL NOT NULL | Squat TM at block start | Snapshot TM for this block's calculations |
| `bench_tm` | REAL NOT NULL | Bench TM at block start | Same |
| `deadlift_tm` | REAL NOT NULL | Deadlift TM at block start | Same |
| `press_tm` | REAL NOT NULL | OHP TM at block start | Same |
| `unit` | TEXT NOT NULL | kg or lb | Captured at block creation time |
| `current_cycle` | INTEGER NOT NULL DEFAULT 0 | 0=Leader1, 1=Leader2, 2=Deload, 3=Anchor, 4=TMTest | Single integer encodes 11-week position |
| `current_week` | INTEGER NOT NULL DEFAULT 1 | 1-3 within the current cycle | Week within cycle (1=5s, 2=3s, 3=5/3/1 or varies by cycle type) |
| `is_active` | INTEGER NOT NULL DEFAULT 1 | Whether this is the current block | Only one block active at a time |
| `completed` | DATETIME NULLABLE | When block was completed | NULL = in progress, set when TM Test done |

**Why this structure:**

1. **Snapshot TMs:** Each block records starting TMs. TM progression happens within the block (Leader1 complete -> bump TMs -> continue to Leader2). The settings table TMs remain the "live" values for the calculator. Block TMs are the starting reference point for history.

2. **Single `current_cycle` integer:** The 11-week structure maps cleanly to 5 cycles (0-4). No need for separate tables per cycle. The cycle index determines the set scheme (Leader uses 5's PRO, Anchor uses PR Sets, etc.).

3. **`current_week` within cycle:** Each cycle has 3 weeks. Combined with `current_cycle`, this gives exact position in the 11-week block (e.g., cycle=1, week=2 means Leader 2, Week 2 = "3s Week").

4. **Historical blocks:** When a block completes, `is_active` = 0 and `completed` is set. Users can see past blocks. When starting a new block, the old one is marked complete.

**What NOT to add:**
- No `fivethreeone_cycles` sub-table. Cycles are derived from the `current_cycle` enum. Adding a table per cycle is over-engineering for what is fundamentally a counter (0-4).
- No `fivethreeone_weeks` table. Week state is a simple integer on the block.
- No per-exercise TM history table. TM progression is deterministic (add 2.5kg upper / 5kg lower per cycle). Historical TMs can be calculated from the block's starting TMs + cycle position.

#### Settings Table: No Changes Needed

The existing 5/3/1 columns in Settings remain as-is:

| Column | Current Use | New Use |
|--------|-------------|---------|
| `fivethreeone_squat_tm` | Live TM for calculator | Same -- updated as cycles progress |
| `fivethreeone_bench_tm` | Live TM for calculator | Same |
| `fivethreeone_deadlift_tm` | Live TM for calculator | Same |
| `fivethreeone_press_tm` | Live TM for calculator | Same |
| `fivethreeone_week` | Global week (1-4) | **Deprecated in favor of block's `current_week`**, but kept for backward compat |

The live TMs in Settings continue to serve the calculator. When a block is active, advancing cycles auto-updates these Settings values. This preserves backward compatibility -- users who never create a block still have their TMs in Settings working as before.

#### Migration Code Pattern

```sql
-- v63 -> v64: Add fivethreeone_blocks table
CREATE TABLE IF NOT EXISTS fivethreeone_blocks (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  created INTEGER NOT NULL,
  squat_tm REAL NOT NULL,
  bench_tm REAL NOT NULL,
  deadlift_tm REAL NOT NULL,
  press_tm REAL NOT NULL,
  unit TEXT NOT NULL,
  current_cycle INTEGER NOT NULL DEFAULT 0,
  current_week INTEGER NOT NULL DEFAULT 1,
  is_active INTEGER NOT NULL DEFAULT 1,
  completed INTEGER
);
```

This follows the project's established manual migration pattern (see `database.dart` lines 283-405 for existing examples). No Drift codegen migration -- raw SQL in the `onUpgrade` handler with `.catchError((e) {})` guard.

**Backup/Import Compatibility:** Database imports work by copying the .sqlite file directly (see `import_data.dart` line 106). The migration handler runs on `onUpgrade`, so importing an older database (v63) into a v64 app will trigger the migration and create the new table. CSV export only covers `workouts` and `gym_sets` tables, so the new table does not affect CSV import/export.

---

### Drift Table Definition

```dart
// lib/database/fivethreeone_blocks.dart
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
  IntColumn get currentCycle => integer().withDefault(const Constant(0))();
  IntColumn get currentWeek => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get completed => dateTime().nullable()();
}
```

Register in `database.dart`:
```dart
@DriftDatabase(tables: [
  Plans,
  GymSets,
  Settings,
  PlanExercises,
  Metadata,
  Workouts,
  Notes,
  BodyweightEntries,
  FiveThreeOneBlocks,  // NEW
])
```

Then run `dart run build_runner build` to regenerate `database.g.dart`.

**Confidence:** HIGH -- follows exact pattern of existing tables (Notes, Workouts, BodyweightEntries).

---

### UI Components: No New Packages

#### Timeline / Block Overview

**Recommendation:** Custom widget using `Column` + `Row` + `Container` with Material 3 styling.

**Why NOT a timeline package:**
- The block structure is fixed (always 5 segments: L1, L2, Deload, Anchor, TM Test)
- A generic timeline package adds dependency weight for a static 5-item layout
- Custom styling matches app's Material 3 theme (colorScheme.primaryContainer, etc.)
- KISS principle -- a `Row` of 5 styled containers with progress indication is simpler than learning a package API

**Why NOT Flutter's built-in Stepper:**
- Stepper is designed for form wizards with expandable content per step
- It has a vertical/horizontal layout but imposes its own visual style (circles + connecting lines)
- The 5/3/1 block overview needs a compact progress bar style, not a form stepper
- Stepper also manages its own state (activeStep), which conflicts with our database-driven state

**Implementation approach:**
```dart
// A horizontal bar showing 5 segments
Row(
  children: [
    _CycleSegment(label: 'L1', status: _getStatus(0)),
    _CycleSegment(label: 'L2', status: _getStatus(1)),
    _CycleSegment(label: 'DL', status: _getStatus(2)),
    _CycleSegment(label: 'AN', status: _getStatus(3)),
    _CycleSegment(label: 'TM', status: _getStatus(4)),
  ],
)
```

Each segment uses `Container` with `BoxDecoration` -- completed = filled primary, active = primary outline + glow, future = surfaceContainerHighest. This is ~50 lines of widget code vs. adding a package dependency.

**Confidence:** HIGH -- standard Flutter layout, no external API to learn or break.

#### Calculator Enhancement

The existing `FiveThreeOneCalculator` widget (562 lines) already handles week selection and set scheme display. Enhancements needed:

1. **Cycle-awareness:** Read `current_cycle` from active block to determine set scheme variant (5's PRO for Leader, PR Sets for Anchor, Deload percentages, TM Test scheme)
2. **Supplemental work display:** Add a section below the main sets showing supplemental work (BBB 5x10@60% for Leader, FSL 5x5 for Anchor)

These are modifications to the existing widget, not new packages. The `_getWorkingSetScheme()` method (line 179) already returns a list of (percentage, reps, amrap) records -- it just needs to branch on cycle type in addition to week.

**Confidence:** HIGH -- extending existing code path.

#### State Management

**Recommendation:** Extend existing Provider pattern with a new `FiveThreeOneState` ChangeNotifier, or integrate into existing `SettingsState`.

**Option A: New ChangeNotifier (Recommended)**

```dart
class FiveThreeOneState extends ChangeNotifier {
  FiveThreeOneBlock? activeBlock;
  StreamSubscription? _subscription;

  Future<void> init() async {
    _subscription = (db.fiveThreeOneBlocks.select()
      ..where((b) => b.isActive.equals(true))
      ..limit(1))
      .watchSingleOrNull()
      .listen((block) {
        activeBlock = block;
        notifyListeners();
      });
  }
}
```

Add to `MultiProvider` in `main.dart` alongside existing state providers.

**Why a separate state class:**
- SettingsState already handles 50+ settings fields. Adding block lifecycle management bloats it.
- Block state has its own lifecycle (create, advance, complete) that doesn't map to settings updates.
- Follows existing pattern: WorkoutState, PlanState, TimerState are all separate ChangeNotifiers.

**Option B: Integrate into SettingsState (NOT recommended)**
- Simpler (no new provider), but violates single responsibility
- Settings is already a single-row table pattern; blocks are multi-row

**Confidence:** HIGH -- mirrors WorkoutState pattern exactly.

---

## What NOT to Add

| Rejected Addition | Why Not |
|-------------------|---------|
| `timelines` package | Fixed 5-item layout doesn't justify a dependency. Custom Row+Container is simpler. |
| `flutter_staggered_animations` | Animation on cycle transitions is nice-to-have but YAGNI for MVP. Flutter's built-in `AnimatedContainer` suffices if needed later. |
| `step_progress_indicator` | Another package for what is a styled Row. |
| Separate TM history table | TM progression is deterministic from block start TMs + cycle number. Can be calculated, not stored. |
| `fivethreeone_cycles` junction table | Over-normalized. Cycle state is a single integer (0-4) on the block row. |
| `fivethreeone_supplementals` config table | Supplemental schemes (BBB, FSL) are hardcoded per cycle type. They don't vary per user in this implementation. If user-configurable supplementals are added later, that's a separate feature. |
| Any charting additions | Block progress is a 5-step bar, not a graph. `fl_chart` is overkill for this. |

---

## Integration Points with Existing Stack

### Drift Streams (Reactive Updates)

The block table should use Drift's `.watch()` streams so the UI updates reactively when:
- A new block is created
- The user advances to the next week/cycle
- A block is completed

This matches the existing pattern in `SettingsState` (line 26: `db.settings.select()...watchSingleOrNull()`) and `gym_sets.dart` (line 222: `query.watch()`).

### Provider (State Propagation)

The new `FiveThreeOneState` provides:
- `activeBlock` -- the current block (or null if no block exists)
- Methods: `createBlock()`, `advanceWeek()`, `advanceCycle()`, `completeBlock()`

Widgets access via `context.watch<FiveThreeOneState>()` or `context.read<FiveThreeOneState>()`.

### Calculator Widget Integration

The `FiveThreeOneCalculator` currently reads week from Settings (`setting.fivethreeoneWeek`). With blocks:
1. Check if an active block exists via `FiveThreeOneState`
2. If yes: use block's `currentCycle` and `currentWeek` to determine scheme
3. If no: fall back to current behavior (Settings-based week)

This preserves backward compatibility for users who don't use blocks.

### Notes Page Entry Point

The "5/3/1 Training Max" banner in `notes_page.dart` (line 462) currently opens `TrainingMaxEditor`. This should:
1. If active block exists: navigate to block overview page
2. If no block: show "Create Block" option alongside existing TM editor

### Export/Import Considerations

**CSV Export:** Currently exports `workouts` and `gym_sets` only. The `fivethreeone_blocks` table does NOT need CSV export -- it's configuration data, not workout data. Database export (.sqlite file) captures everything automatically.

**Database Import:** Migration handler ensures the table is created when importing an older database. No changes needed to import logic.

**Backward Compatibility:** Importing a v64 database into a v63 app would fail on the unknown table, but this is the existing behavior for any schema upgrade and is acceptable.

---

## Installation / Build Commands

No new packages. The only build step is regenerating Drift code after adding the new table definition:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This updates `database.g.dart` with the new table's generated code.

---

## Sources

**HIGH Confidence:**
- Codebase analysis: `lib/database/database.dart` (migration patterns, schema version 63)
- Codebase analysis: `lib/database/settings.dart` (existing 5/3/1 columns)
- Codebase analysis: `lib/widgets/five_three_one_calculator.dart` (current calculator implementation)
- Codebase analysis: `lib/settings/settings_state.dart` (Provider + Drift stream pattern)
- Codebase analysis: `lib/import_data.dart` (database import mechanism)
- Codebase analysis: `lib/export_data.dart` (CSV export scope)
- Codebase analysis: `pubspec.lock` (Drift 2.30.0 actual installed version)
- [Drift Tables Documentation](https://drift.simonbinder.eu/dart_api/tables/) -- foreign keys, column types
- [Flutter Stepper class](https://api.flutter.dev/flutter/material/Stepper-class.html) -- evaluated and rejected

**MEDIUM Confidence:**
- [Flutter timeline packages landscape](https://fluttergems.dev/timeline/) -- confirmed no compelling built-in alternative

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Database schema design | HIGH | Follows exact patterns of existing tables (Workouts, Notes). Manual migration pattern established in 12+ prior migrations. |
| No new packages needed | HIGH | All UI is standard Flutter Material 3 widgets. Block timeline is a fixed 5-item Row. |
| Provider integration | HIGH | Mirrors existing WorkoutState/PlanState pattern exactly. |
| Calculator enhancement | HIGH | Extending existing `_getWorkingSetScheme()` method with cycle branching. |
| Export/import compatibility | HIGH | Verified: CSV only touches workouts/gym_sets; database import triggers migration handler. |
| Supplemental work display | HIGH | Static data (BBB percentages, FSL percentages) rendered as additional set rows in existing calculator UI. |

---

## Summary for Roadmap

1. **Phase 1 (Foundation):** Create `fivethreeone_blocks` table + Drift definition + migration v63->v64. Create `FiveThreeOneState` provider. No UI yet -- just data layer.

2. **Phase 2 (Block Overview):** Block overview page with timeline bar, create/advance/complete actions. Entry point from Notes page banner.

3. **Phase 3 (Calculator Enhancement):** Make calculator cycle-aware (5's PRO vs PR Sets vs Deload vs TM Test). Add supplemental work section.

4. **Phase 4 (Polish):** TM auto-progression on cycle advance, historical block viewing, edge cases (mid-block TM edits).

All phases use existing stack. Zero new dependencies.
