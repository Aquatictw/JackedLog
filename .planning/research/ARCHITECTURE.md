# Architecture Patterns: 5/3/1 Forever Block Programming

**Domain:** 5/3/1 Forever block programming integration into existing Flutter fitness app
**Researched:** 2026-02-11
**Confidence:** HIGH (based on direct codebase analysis, not external sources)

## Current Architecture Snapshot

### What Exists Today

The current 5/3/1 implementation is minimal -- a "calculator overlay" bolted onto Settings:

```
Settings table (single row):
  fivethreeone_squat_tm    REAL nullable
  fivethreeone_bench_tm    REAL nullable
  fivethreeone_deadlift_tm REAL nullable
  fivethreeone_press_tm    REAL nullable
  fivethreeone_week        INTEGER default 1

Entry points:
  Notes page banner -> TrainingMaxEditor dialog (edit 4 TMs)
  Exercise long-press menu -> FiveThreeOneCalculator dialog (per-exercise)

Calculator:
  Hardcoded 4-week scheme: W1 (5s), W2 (3s), W3 (5/3/1), W4 (Deload)
  All exercises share same week number
  "Progress Cycle" button: bump TM + reset to W1
```

**Key limitation:** There is no concept of blocks, cycles, supplemental work, or program structure. The current system is a reference calculator, not a program tracker.

### Existing Patterns to Follow

| Pattern | How It Works | Where |
|---------|-------------|-------|
| State management | `ChangeNotifier` + `Provider` | `SettingsState`, `WorkoutState`, `PlanState` |
| Database access | Global `db` singleton, Drift ORM | `lib/main.dart`, all state classes |
| Reactive updates | Drift `.watch()` streams + `StreamSubscription` | `SettingsState.init()`, `NotesPage` |
| Navigation | Banner tap -> dialog/page, long-press -> bottom sheet | `NotesPage`, `ExerciseSetsCard` |
| Database schema changes | Manual `ALTER TABLE` in `onUpgrade`, version bump | `database.dart` migration blocks |
| Feature structure | `lib/{feature}/` with `*_page.dart` + `*_state.dart` | `workouts/`, `plan/`, `settings/` |

---

## Recommended Architecture

### 1. Data Model: New Table, Not Extended Settings

**Recommendation:** Create a new `fivethreeone_blocks` table. Do NOT extend Settings further.

**Rationale:**
- Settings is a single-row table already carrying 30+ columns (Spotify tokens, UI prefs, TMs, backup config). Adding block state (cycle index, supplemental scheme, anchor week, etc.) would further bloat a table that should only hold user preferences.
- Block state is temporal and program-specific. It has a lifecycle (created, advanced, completed). Settings has no lifecycle.
- A dedicated table enables future features: block history, multiple saved templates, undo.
- The 4 TM columns in Settings should remain there (they are user preferences -- the starting TMs). The block table references them but owns its own state.

**New table: `FiveThreeOneBlocks`**

```dart
class FiveThreeOneBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Block template configuration
  TextColumn get templateName => text().withDefault(const Constant('2 Leaders + Anchor'))();
  TextColumn get supplementalType => text().withDefault(const Constant('fsl'))();
  // Values: 'bbb' (Boring But Big), 'fsl' (First Set Last), 'ssl' (Second Set Last), 'bbs' (Boring But Strong), 'none'

  // Current position in the block
  IntColumn get currentCycleIndex => integer().withDefault(const Constant(0))();
  // 0=Leader1, 1=Leader2, 2=Deload, 3=Anchor, 4=TM Test, 5=Complete
  IntColumn get currentWeek => integer().withDefault(const Constant(1))();
  // 1, 2, or 3 within each cycle

  // TM snapshots at block creation (frozen values, not references)
  RealColumn get squatTm => real()();
  RealColumn get benchTm => real()();
  RealColumn get deadliftTm => real()();
  RealColumn get pressTm => real()();

  // Metadata
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
```

**Why snapshot TMs instead of referencing Settings:**
- When user creates a block, the TMs are locked in. If they manually edit TMs in Settings mid-block, the block should still use its own values.
- TM progression happens via the block's advance logic (bump by 5/10 lb per cycle), not by editing Settings.
- This prevents the subtle bug where editing Settings TMs silently corrupts a running block.

**Migration (version 64):**

```sql
CREATE TABLE IF NOT EXISTS fivethreeone_blocks (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  template_name TEXT NOT NULL DEFAULT '2 Leaders + Anchor',
  supplemental_type TEXT NOT NULL DEFAULT 'fsl',
  current_cycle_index INTEGER NOT NULL DEFAULT 0,
  current_week INTEGER NOT NULL DEFAULT 1,
  squat_tm REAL NOT NULL,
  bench_tm REAL NOT NULL,
  deadlift_tm REAL NOT NULL,
  press_tm REAL NOT NULL,
  created_at INTEGER NOT NULL,
  completed_at INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1
);
```

**Import/export impact:** The new table is independent of the existing CSV export (which only covers workouts + gym_sets). Database export (.sqlite) will automatically include it. No changes needed to export_data.dart or import_data.dart for the initial implementation. Older databases imported will simply not have this table, which is fine -- no active block means the feature shows the "Start Block" setup screen.

### 2. State Management: Lightweight ChangeNotifier

**Recommendation:** Create `FiveThreeOneState` as a `ChangeNotifier` registered in `appProviders`, following the exact pattern of `WorkoutState`.

**Rationale:**
- The block state is consumed by multiple disconnected widgets: the Notes page banner, the calculator dialog, and the new block overview page. Provider is the right way to share this.
- A simpler approach (just reading from DB each time) would work for the overview page, but the calculator dialog needs instant access to block state without async initialization delays.
- Follows existing convention: `WorkoutState`, `PlanState`, `SettingsState` all use this pattern.

```dart
// lib/fivethreeone/fivethreeone_state.dart

class FiveThreeOneState extends ChangeNotifier {
  FiveThreeOneState() {
    _loadActiveBlock().catchError((error) {
      print('Warning: Error loading active 5/3/1 block: $error');
    });
  }

  FiveThreeOneBlock? _activeBlock;

  FiveThreeOneBlock? get activeBlock => _activeBlock;
  bool get hasActiveBlock => _activeBlock != null;

  // Derived getters for current position
  String get currentCycleName { ... }  // "Leader 1", "Leader 2", etc.
  int get currentWeek { ... }          // 1, 2, or 3
  bool get isLeader { ... }
  bool get isAnchor { ... }
  bool get isDeload { ... }

  // Get percentage scheme for current position
  List<SetScheme> getMainScheme(String exerciseKey) { ... }
  List<SetScheme> getSupplementalScheme(String exerciseKey) { ... }

  // TM for a given exercise from the active block
  double? getTm(String exerciseKey) { ... }

  // Actions
  Future<void> createBlock({ ... }) { ... }
  Future<void> advanceWeek() { ... }
  Future<void> advanceCycle() { ... }
}
```

**Registration in main.dart:**

```dart
Widget appProviders(SettingsState state) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (context) => state),
    ChangeNotifierProvider(create: (context) => TimerState()),
    ChangeNotifierProvider(create: (context) => PlanState()),
    ChangeNotifierProvider(create: (context) => WorkoutState()),
    ChangeNotifierProvider(create: (context) => SpotifyState()),
    ChangeNotifierProvider(create: (context) => FiveThreeOneState()),  // NEW
  ],
  child: const App(),
);
```

### 3. Navigation: Banner -> Full Page (Not Dialog)

**Recommendation:** Replace the TrainingMaxEditor dialog with a full `FiveThreeOnePage` that pushes via `Navigator.push`. Keep the banner as the entry point.

**Rationale:**
- The current TrainingMaxEditor is a dialog because it only has 4 text fields. The block feature needs: block overview timeline, TM display for 4 lifts, current week indicator, supplemental scheme display, advance/create controls. This is too much for a dialog.
- A full page is consistent with how other rich features work (workout detail, graph pages).
- The banner stays in Notes page and becomes more informative (shows "Leader 1 / Week 2" instead of just "5/3/1 Training Max").

**Banner update:**

```
Current:  "5/3/1 Training Max" -> TrainingMaxEditor dialog
New:      "5/3/1 Block: Leader 1 - Week 2 (FSL)" -> FiveThreeOnePage push
Fallback: "5/3/1 Setup Block" -> FiveThreeOnePage push (setup mode)
```

**Page structure:**

```
lib/fivethreeone/
  fivethreeone_state.dart     # ChangeNotifier state
  fivethreeone_page.dart      # Main page (block overview OR setup)
  block_timeline_widget.dart  # Visual cycle/week timeline
  scheme_display_widget.dart  # Shows percentage scheme for current position
  schemes.dart                # Pure data: percentage schemes, no UI/DB deps
```

**Why not a dialog:**
- The TrainingMaxEditor dialog is 243 lines for just 4 text fields + save button.
- The block page will need: timeline visualization, per-lift TM display, week/cycle navigation, supplemental scheme display, advance controls, "Start New Block" flow. A dialog would be cramped and require excessive scrolling on small screens.
- Full page allows future expansion (history of past blocks, comparison views) without re-navigation.

### 4. Calculator Integration: Context-Aware via FiveThreeOneState

**Recommendation:** Modify the existing `FiveThreeOneCalculator` to check `FiveThreeOneState` first, falling back to current behavior if no active block.

**Rationale:**
- The calculator already knows the exercise name (passed via constructor). It already loads TM from Settings. The change is: if an active block exists, read TM and week scheme from the block instead of Settings.
- This keeps the calculator usable even without an active block (manual mode), which is important for users who haven't set up blocks.

**Current flow:**
```
FiveThreeOneCalculator(exerciseName: "Squat")
  -> _loadSettings()
  -> reads fivethreeone_squat_tm from Settings
  -> reads fivethreeone_week from Settings
  -> shows hardcoded 4-week scheme
```

**New flow:**
```
FiveThreeOneCalculator(exerciseName: "Squat")
  -> check context.read<FiveThreeOneState>().hasActiveBlock
  -> IF active block:
       -> TM from block.squatTm
       -> Week/scheme from block state (Leader: 5's PRO, Anchor: PR Sets, etc.)
       -> Supplemental scheme shown below main sets
       -> Week selector disabled (driven by block)
  -> ELSE (no active block):
       -> Existing behavior (Settings TMs, manual week selector)
```

**Key changes to `_getWorkingSetScheme()`:**

The current method returns a fixed 4-week cycle. With blocks, the scheme depends on cycle type:

| Cycle Type | Main Work | Top Set |
|-----------|-----------|---------|
| Leader (5's PRO) | 65/75/85, 70/80/90, 75/85/95 | No AMRAP (prescribed reps only) |
| Anchor (PR Sets) | Same percentages | AMRAP on top set (current behavior) |
| Deload | 40/50/60 x5 | No AMRAP |
| TM Test | 100% TM x3-5 | Single set validation |

This is a data-only change to the calculator -- the UI structure (set cards with percentage/weight/reps) stays identical. Only the data source changes.

### 5. Supplemental Work Display

**Recommendation:** Show supplemental sets as a separate section below main work in the calculator dialog. Do NOT create actual GymSet entries automatically.

**Rationale:**
- Supplemental work (BBB 5x10 @ 50%, FSL 5x5 @ 65%) is informational guidance, not tracked sets. The user will log the actual sets they do via the workout recording flow (ExerciseSetsCard).
- Auto-creating GymSet entries would fight the existing workout flow where users add sets manually, adjust weights, and mark completion.
- The calculator already displays "what to do." Adding supplemental display is a natural extension.

**Supplemental scheme data:**

```dart
enum SupplementalType {
  bbb,   // Boring But Big: 5x10 @ 50-60%
  fsl,   // First Set Last: 5x5 @ first set %
  ssl,   // Second Set Last: 5x5 @ second set %
  bbs,   // Boring But Strong: 10x5 @ first set %
  none,  // No supplemental
}

List<SetScheme> getSupplementalScheme(SupplementalType type, int week) {
  switch (type) {
    case SupplementalType.bbb:
      return List.generate(5, (_) =>
        (percentage: [0.50, 0.55, 0.60][week - 1], reps: 10, amrap: false));
    case SupplementalType.fsl:
      final firstSetPct = [0.65, 0.70, 0.75][week - 1];
      return List.generate(5, (_) =>
        (percentage: firstSetPct, reps: 5, amrap: false));
    // ...
  }
}
```

**Display in calculator:**

```
--- Main Work (5's PRO) ---
Set 1: 127.5 kg x5  (65%)
Set 2: 147.5 kg x5  (75%)
Set 3: 167.5 kg x5  (85%)

--- Supplemental (FSL 5x5) ---
5 x 5 @ 127.5 kg (65%)
```

---

## Component Boundaries

### New Components

| Component | Location | Responsibility |
|-----------|----------|---------------|
| `FiveThreeOneBlocks` table | `lib/database/fivethreeone_blocks.dart` | Schema definition for block data |
| `FiveThreeOneState` | `lib/fivethreeone/fivethreeone_state.dart` | Block lifecycle, current position, TM management |
| `FiveThreeOnePage` | `lib/fivethreeone/fivethreeone_page.dart` | Block overview page (timeline, TMs, controls) |
| `BlockTimelineWidget` | `lib/fivethreeone/block_timeline_widget.dart` | Visual cycle/week progress indicator |
| `SchemeDisplayWidget` | `lib/fivethreeone/scheme_display_widget.dart` | Percentage/weight table for current position |
| Scheme data module | `lib/fivethreeone/schemes.dart` | Pure data: percentage schemes for all cycle types and supplemental variations |

### Modified Components

| Component | Location | What Changes |
|-----------|----------|-------------|
| `database.dart` | `lib/database/database.dart` | Add `FiveThreeOneBlocks` to `@DriftDatabase` tables, add migration v64 |
| `main.dart` | `lib/main.dart` | Add `FiveThreeOneState` to Provider tree |
| `notes_page.dart` | `lib/notes/notes_page.dart` | Banner reads from `FiveThreeOneState`, navigates to `FiveThreeOnePage` |
| `five_three_one_calculator.dart` | `lib/widgets/five_three_one_calculator.dart` | Reads block state if active, shows supplemental section |
| `training_max_editor.dart` | `lib/widgets/training_max_editor.dart` | May be preserved as "manual TM editor" accessible from FiveThreeOnePage settings |

### Unchanged Components

| Component | Why Unchanged |
|-----------|--------------|
| `ExerciseSetsCard` | Workout recording stays manual. Users log whatever they actually do. |
| `GymSets` table | No schema changes. Recorded sets are just normal gym sets. |
| `Plans` / `PlanExercises` | Plans are orthogonal to 5/3/1 blocks. A plan says "do Squat, Bench, Rows." The block says "this week Squat is 65/75/85%." |
| `WorkoutState` | Workout lifecycle is independent of block programming. |
| `export_data.dart` / `import_data.dart` | CSV export covers workouts/sets only. Database export handles new table automatically. |
| `SettingsState` | Still holds TM values (for manual mode), but block reads its own snapshot. |

---

## Data Flow

### Block Creation Flow

```
User taps banner -> FiveThreeOnePage (setup mode)
  -> User selects template: "2 Leaders + Anchor"
  -> User selects supplemental: "FSL"
  -> User confirms TMs (pre-populated from Settings)
  -> FiveThreeOneState.createBlock()
    -> INSERT into fivethreeone_blocks
    -> TMs snapshotted from Settings into block row
    -> currentCycleIndex = 0, currentWeek = 1
    -> notifyListeners()
  -> Banner updates to "Leader 1 - Week 1 (FSL)"
```

### Week Advance Flow

```
User taps "Complete Week" on FiveThreeOnePage
  -> FiveThreeOneState.advanceWeek()
    -> currentWeek++ (1->2->3)
    -> If currentWeek > 3: advanceCycle()
    -> UPDATE fivethreeone_blocks
    -> notifyListeners()
  -> UI updates everywhere (banner, calculator, page)
```

### Cycle Advance Flow

```
FiveThreeOneState.advanceCycle()
  -> currentCycleIndex++ (Leader1 -> Leader2 -> Deload -> Anchor -> TMTest -> Complete)
  -> currentWeek = 1
  -> If crossing Leader2 -> Deload: TMs stay same
  -> If crossing TMTest -> Complete:
    -> Bump TMs: upper +2.5kg/5lb, lower +5kg/10lb
    -> Update both block row AND Settings table (so manual mode stays current)
    -> Mark block completed (completedAt, isActive=false)
  -> notifyListeners()
```

### Calculator Context-Aware Flow

```
User long-presses Squat in workout -> "5/3/1 Calculator"
  -> FiveThreeOneCalculator(exerciseName: "Squat")
  -> initState: check FiveThreeOneState
    -> hasActiveBlock?
      YES: tm = block.squatTm, scheme = block scheme for current position
      NO:  tm = settings.fivethreeoneSquatTm, scheme = manual 4-week
  -> Display main sets + supplemental (if block active)
```

---

## Patterns to Follow

### Pattern 1: Stream-Backed State with Manual Control

**What:** Like `WorkoutState`, the block state loads from DB on init and updates via explicit actions (not automatic stream watching).

**When:** Block state changes are user-initiated (advance week, create block), not driven by external events.

**Why not stream-watching like SettingsState:** Settings changes from any UI immediately propagate everywhere. Block state only changes when the user explicitly advances. Watching adds unnecessary complexity.

```dart
class FiveThreeOneState extends ChangeNotifier {
  Future<void> _loadActiveBlock() async {
    _activeBlock = await (db.fiveThreeOneBlocks.select()
      ..where((b) => b.isActive.equals(true))
      ..limit(1))
      .getSingleOrNull();
    notifyListeners();
  }

  Future<void> advanceWeek() async {
    if (_activeBlock == null) return;
    // ... update logic ...
    await (db.fiveThreeOneBlocks.update()
      ..where((b) => b.id.equals(_activeBlock!.id)))
      .write(FiveThreeOneBlocksCompanion(
        currentWeek: Value(newWeek),
        currentCycleIndex: Value(newCycle),
      ));
    await _loadActiveBlock(); // Reload to sync
  }
}
```

### Pattern 2: Pure Data Schemes Module

**What:** All percentage schemes, supplemental calculations, and cycle definitions are pure functions in a separate module with no UI or database dependencies.

**Why:** This makes the scheme logic testable in isolation and reusable across calculator, overview page, and any future "workout suggestion" feature.

```dart
// lib/fivethreeone/schemes.dart - NO imports from database or flutter

typedef SetScheme = ({double percentage, int reps, bool amrap});

List<SetScheme> getMainScheme({
  required int cycleType, // 0=leader, 1=anchor, 2=deload, 3=tmtest
  required int week,      // 1, 2, or 3
}) { ... }

List<SetScheme> getSupplementalScheme({
  required String supplementalType, // 'bbb', 'fsl', 'ssl', etc.
  required int week,
}) { ... }

double calculateWeight(double tm, double percentage, String unit) { ... }
```

### Pattern 3: Graceful Degradation

**What:** Every component that reads `FiveThreeOneState` must work when no active block exists.

**Why:** Users may not use 5/3/1 blocks at all. The calculator must still work in manual mode. The banner must still show something useful.

```dart
// In calculator:
final blockState = context.read<FiveThreeOneState>();
if (blockState.hasActiveBlock) {
  // Block-driven mode
} else {
  // Manual mode (existing behavior)
}

// In banner:
if (blockState.hasActiveBlock) {
  '5/3/1: ${blockState.currentCycleName} - Week ${blockState.currentWeek}'
} else {
  '5/3/1 Training Max'  // Original text
}
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing Block State in Settings

**What:** Adding `fivethreeone_cycle_index`, `fivethreeone_supplemental_type`, etc. to the Settings table.

**Why bad:** Settings is already overloaded (30+ columns). Block state has a lifecycle (create/advance/complete) that Settings doesn't model. You'd need to add `fivethreeone_block_started_at`, `fivethreeone_block_completed_at`, and soon you're building a table inside a row.

**Instead:** Dedicated `FiveThreeOneBlocks` table with proper schema.

### Anti-Pattern 2: Auto-Generating Workout Sets

**What:** When user starts a workout during an active block, automatically creating GymSet rows with pre-calculated weights.

**Why bad:** Fights the existing workout flow. Users adjust weights, skip sets, add extra sets. Pre-populating creates ghost data that needs cleanup logic. The calculator already tells users what to do -- they record what they actually did.

**Instead:** Calculator shows the prescription. User records actual performance via normal ExerciseSetsCard flow.

### Anti-Pattern 3: Complex Cycle State Machine

**What:** Building an elaborate state machine with transitions, guards, and rollback logic for cycle advancement.

**Why bad:** YAGNI. The block progression is strictly linear: Leader1 W1->W2->W3 -> Leader2 W1->W2->W3 -> Deload W1->W2->W3 -> Anchor W1->W2->W3 -> TM Test -> Complete. Two integers (cycleIndex, week) fully describe the state.

**Instead:** Simple integer math with a `CYCLE_NAMES` list for display.

### Anti-Pattern 4: Making Calculator Modal About Block State

**What:** If an active block exists, preventing the user from using the calculator in manual mode.

**Why bad:** Users may want to look up different week percentages, calculate for a non-block lift, or compare options. Locking them into block mode removes flexibility.

**Instead:** Block mode is the default when a block is active, but a toggle/tab allows switching to manual mode.

---

## Suggested Build Order

Build order is designed so each phase is independently useful and testable.

### Phase 1: Data Foundation + State
**Build:** Table definition, migration, `FiveThreeOneState`, schemes module
**Why first:** Everything else depends on this. Can be tested without UI.
**Deliverable:** State class that can create/advance/complete blocks, pure scheme functions
**Integration points:** `database.dart` (table + migration), `main.dart` (Provider registration)

### Phase 2: Block Overview Page + Banner Update
**Build:** `FiveThreeOnePage`, `BlockTimelineWidget`, banner context-awareness
**Why second:** Gives users the primary interface to create and manage blocks.
**Deliverable:** Full page showing block timeline, TMs, advance controls. Banner shows current position.
**Integration points:** `notes_page.dart` (banner navigation change)

### Phase 3: Calculator Context-Awareness + Supplemental Display
**Build:** Calculator reads block state, shows supplemental section
**Why third:** This is where the block state becomes actionable during workouts.
**Deliverable:** Calculator shows correct scheme based on block position, supplemental sets displayed below main work.
**Integration points:** `five_three_one_calculator.dart` (logic + UI changes)

### Phase 4: Polish + Edge Cases
**Build:** Manual mode toggle in calculator, block completion flow with TM bump, block history view
**Why last:** These are refinements that depend on all prior phases working.
**Deliverable:** Complete block lifecycle from creation to completion with TM progression.

---

## Scalability Considerations

| Concern | Current (No Blocks) | With Blocks | At Scale (Many Completed Blocks) |
|---------|---------------------|-------------|----------------------------------|
| DB size | 0 extra rows | 1 active row | Grows by 1 row per completed block (negligible) |
| Provider overhead | N/A | 1 additional ChangeNotifier | Same -- only 1 active block at a time |
| Calculator startup | 1 DB read (Settings) | 1 DB read (Settings) + 1 Provider read (in-memory) | Same -- Provider caches active block |
| Migration complexity | N/A | 1 new table, no data migration | No migration needed for block growth |

The single-active-block constraint means this feature adds essentially zero overhead to the existing app. The table could accumulate hundreds of completed blocks over years without any performance concern.

---

## Sources

- Direct codebase analysis (HIGH confidence):
  - `lib/database/database.dart` -- migration patterns, schema version 63
  - `lib/database/settings.dart` -- existing 5/3/1 columns (lines 44-49)
  - `lib/widgets/five_three_one_calculator.dart` -- current calculator logic
  - `lib/widgets/training_max_editor.dart` -- current TM editor
  - `lib/notes/notes_page.dart` -- banner entry point, `_TrainingMaxBanner` widget
  - `lib/plan/exercise_sets_card.dart` -- calculator launch via `_show531Calculator`
  - `lib/settings/settings_state.dart` -- ChangeNotifier + StreamSubscription pattern
  - `lib/workouts/workout_state.dart` -- state management pattern with async init
  - `lib/main.dart` -- Provider registration in `appProviders()`
  - `lib/export_data.dart`, `lib/import_data.dart` -- import/export impact assessment
  - `.planning/codebase/ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`
- 5/3/1 Forever program knowledge (MEDIUM confidence -- based on training knowledge, not verified against the book):
  - Leader/Anchor cycle structure
  - 5's PRO vs PR Sets distinction
  - Supplemental volume schemes (BBB, FSL, SSL, BBS)
  - TM progression rules (upper +2.5kg, lower +5kg)

---

*Architecture analysis: 2026-02-11*
