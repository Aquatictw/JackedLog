# Phase 6: Data Foundation - Research

**Researched:** 2026-02-11
**Domain:** Drift database schema, Provider state management, pure Dart data module
**Confidence:** HIGH

## Summary

Phase 6 builds the data infrastructure for 5/3/1 Forever block programming. Three deliverables, zero new dependencies: (1) a `fivethreeone_blocks` Drift table with manual migration from v63 to v64, (2) a `FiveThreeOneState` ChangeNotifier registered in the Provider tree, and (3) a pure `schemes.dart` module defining percentage/rep schemes for all cycle types and supplemental variations.

All three components follow established codebase patterns exactly. The table definition mirrors `Notes`, `Workouts`, and `BodyweightEntries`. The state class mirrors `WorkoutState` (constructor-based async init with `.catchError()`). The migration follows the consolidated boundary pattern from `database.dart`. The schemes module is new but simple -- pure functions, no dependencies.

**Primary recommendation:** Follow existing codebase conventions line-for-line. Every pattern needed already exists in the codebase. No invention required.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Drift | 2.30.0 (installed) | Database table definition + migration | Already used for all 8 existing tables; `pubspec.lock` confirms version |
| Provider | 6.1.1 (installed) | State management via ChangeNotifier | Already used for 5 existing state classes; exact pattern in `main.dart` |
| Dart (pure) | N/A | Schemes data module | No dependency needed; typedef records + const maps |

### Supporting

No supporting libraries needed. Everything is built-in.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pure typedef records for SetScheme | Freezed-generated data classes | Over-engineering for 4-field records; adds build_runner dependency for no benefit |
| Manual migration SQL | Drift schema tools (`drift_dev schema steps`) | Codebase uses manual migrations exclusively (12+ migrations); changing pattern mid-project adds risk |
| Constructor async init | `ProxyProvider` with lazy init | Breaks existing convention; `WorkoutState`, `PlanState` both use constructor pattern |

### Installation

No new packages. After adding the Drift table definition:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Architecture Patterns

### Recommended Project Structure

```
lib/
  database/
    fivethreeone_blocks.dart   # Drift table definition (NEW)
    database.dart              # Add table + migration v64 (MODIFY)
  fivethreeone/
    fivethreeone_state.dart    # ChangeNotifier (NEW)
    schemes.dart               # Pure data module (NEW)
  main.dart                    # Register in MultiProvider (MODIFY)
```

### Pattern 1: Drift Table Definition with @DataClassName

**What:** Define the new table class with `@DataClassName` annotation.
**When to use:** Every new Drift table in this codebase.
**Source:** Existing codebase pattern from `notes.dart`, `bodyweight_entries.dart`, `workouts.dart` + Drift documentation (Context7 `/simolus3/drift`)

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

**Key details:**
- `@DataClassName('FiveThreeOneBlock')` generates singular `FiveThreeOneBlock` data class (table class is plural `FiveThreeOneBlocks`)
- `autoIncrement()` implies `NOT NULL PRIMARY KEY AUTOINCREMENT`
- `boolean()` maps to `INTEGER` in SQLite (Drift handles conversion)
- `dateTime()` stores as `INTEGER` (Unix epoch seconds) in SQLite
- `real()` maps to `REAL` in SQLite -- no nullable needed since TMs are required at block creation
- `text()` for unit -- matches `BodyweightEntries.unit` pattern

### Pattern 2: Manual Migration in onUpgrade

**What:** Add the new table via raw SQL in the `onUpgrade` handler.
**When to use:** Every schema version bump in this codebase.
**Source:** `database.dart` lines 60-413, specifically the `from62To63` block (most recent migration)

```dart
// In database.dart onUpgrade:
// from63To64: Add fivethreeone_blocks table
if (from < 64 && to >= 64) {
  await m.database.customStatement('''
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
    )
  ''');
}
```

**Critical details from codebase analysis:**
- Use `IF NOT EXISTS` for `CREATE TABLE` (safe to re-run) -- matches pattern in `from31To48` block (metadata, workouts, bodyweight_entries, notes tables)
- Do NOT use `.catchError((e) {})` for `CREATE TABLE` -- that pattern is only for `ALTER TABLE` where column may already exist
- `DateTimeColumn` maps to `INTEGER` in SQLite (Unix epoch seconds), NOT `DATETIME`
- `BoolColumn` maps to `INTEGER` in SQLite, NOT `BOOLEAN`
- Bump `schemaVersion` from 63 to 64
- Register `FiveThreeOneBlocks` in `@DriftDatabase(tables: [...])` list

### Pattern 3: ChangeNotifier with Constructor Async Init

**What:** State class that loads from DB on construction, provides getters and action methods.
**When to use:** Every new state class in this codebase.
**Source:** `WorkoutState` constructor pattern (lines 11-16), `PlanState` constructor pattern (lines 27-37)

```dart
// lib/fivethreeone/fivethreeone_state.dart
import 'package:flutter/material.dart';
import '../database/database.dart';
import '../main.dart';

class FiveThreeOneState extends ChangeNotifier {
  FiveThreeOneState() {
    _loadActiveBlock().catchError((error) {
      print('Warning: Error loading active 5/3/1 block: $error');
    });
  }

  FiveThreeOneBlock? _activeBlock;

  FiveThreeOneBlock? get activeBlock => _activeBlock;
  bool get hasActiveBlock => _activeBlock != null;

  Future<void> _loadActiveBlock() async {
    _activeBlock = await (db.fiveThreeOneBlocks.select()
      ..where((b) => b.isActive.equals(true))
      ..limit(1))
      .getSingleOrNull();
    notifyListeners();
  }
}
```

**Key details from codebase analysis:**
- Use `db` global singleton from `main.dart` (NOT constructor injection) -- matches all 5 existing state classes
- Constructor calls async load with `.catchError()` -- matches `WorkoutState` exactly
- Do NOT use stream watching (`watchSingleOrNull`) -- block changes are user-initiated, not external events. This matches the rationale from ARCHITECTURE.md: "Stream-backed state with manual control (like WorkoutState, NOT auto-watching like SettingsState)"
- `getSingleOrNull()` for nullable result -- matches `WorkoutState._loadActiveWorkout()` pattern
- Expose nullable `_activeBlock` with `hasActiveBlock` convenience getter -- matches `WorkoutState.hasActiveWorkout`

### Pattern 4: Provider Registration in MultiProvider

**What:** Add the new ChangeNotifier to the `appProviders()` function.
**When to use:** Every new state class.
**Source:** `main.dart` lines 51-60

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

**Key details:**
- All providers use `create: (context) => ClassName()` factory pattern
- No `lazy: false` needed -- default lazy creation is fine (block state not needed until user accesses 5/3/1 features)
- Import added: `import 'fivethreeone/fivethreeone_state.dart';`

### Pattern 5: Pure Data Module (schemes.dart)

**What:** Percentage/rep scheme definitions as pure data with no imports from database, Flutter, or Provider.
**When to use:** When data is reusable across multiple consumers (calculator, overview page, tests).
**Source:** Novel pattern for this codebase, but follows KISS -- just Dart records and maps.

```dart
// lib/fivethreeone/schemes.dart
// NO imports from database or flutter packages

/// A single set prescription within a working set scheme
typedef SetScheme = ({double percentage, int reps, bool amrap});

/// Returns main work scheme for a given cycle type and week
List<SetScheme> getMainScheme({
  required int cycleType,  // 0-4
  required int week,       // 1-3
}) { ... }

/// Returns supplemental work scheme
List<SetScheme> getSupplementalScheme({
  required String supplementalType,  // 'bbb', 'fsl'
  required int cycleType,
  required int week,
}) { ... }
```

### Anti-Patterns to Avoid

- **Adding block state to Settings table:** Settings is a single-row preference table with 30+ columns. Block state has lifecycle (create/advance/complete) that Settings does not model. Use dedicated table.
- **Using `.catchError((e) {})` on CREATE TABLE:** This silently swallows real errors. Only use `.catchError()` on ALTER TABLE (where column may already exist). CREATE TABLE failures indicate real problems.
- **Stream-watching block state:** Block changes are user-initiated. Using `.watchSingleOrNull()` like SettingsState adds unnecessary overhead. Load on init, reload after mutations.
- **Importing Flutter/database in schemes.dart:** The schemes module must remain pure Dart -- no UI or DB dependencies. This enables unit testing without Flutter test harness.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Database table definition | Raw SQL table class | Drift `extends Table` with `@DataClassName` | Drift generates type-safe companions, data classes, and query builders |
| State propagation | Manual InheritedWidget | `ChangeNotifierProvider` | Provider handles subscription, disposal, and rebuild optimization |
| Migration versioning | Custom version tracking | Drift's `schemaVersion` + `onUpgrade` | Drift handles version comparison and migration orchestration |
| Boolean storage in SQLite | Custom 0/1 mapping | Drift `BoolColumn` | Drift handles bool <-> integer conversion transparently |

**Key insight:** This phase is entirely about following established patterns. Every component has a direct analog in the codebase. The value is in getting the data model right, not in inventing new patterns.

## Common Pitfalls

### Pitfall 1: Wrong SQLite Column Types in Migration SQL

**What goes wrong:** Using `DATETIME`, `BOOLEAN`, or `TEXT` for columns that Drift maps differently. For example, writing `created DATETIME NOT NULL` when Drift stores DateTimeColumn as `INTEGER` (Unix epoch seconds).
**Why it happens:** Drift's Dart types (`DateTimeColumn`, `BoolColumn`) look like they map to SQL types of the same name, but they do not.
**How to avoid:** Match the existing migration SQL exactly:
- `DateTimeColumn` -> `INTEGER` in SQL
- `BoolColumn` -> `INTEGER` in SQL
- `RealColumn` -> `REAL` in SQL
- `TextColumn` -> `TEXT` in SQL
- `IntColumn` -> `INTEGER` in SQL
**Warning signs:** Migration succeeds but reads return null or wrong types. Data inserted via Drift cannot be read back correctly.

### Pitfall 2: Forgetting to Register Table in @DriftDatabase

**What goes wrong:** Table definition file exists, migration SQL runs, but Drift codegen does not generate the companion class or data class because the table is not listed in `@DriftDatabase(tables: [...])`.
**Why it happens:** Two steps needed (file creation + registration) but only one is done.
**How to avoid:** Always update both:
1. Create `lib/database/fivethreeone_blocks.dart`
2. Add `FiveThreeOneBlocks` to `@DriftDatabase(tables: [...])` in `database.dart`
3. Add import for the new file in `database.dart`
4. Run `dart run build_runner build --delete-conflicting-outputs`
**Warning signs:** Compile error: `db.fiveThreeOneBlocks` does not exist.

### Pitfall 3: Migration SQL Column Names Not Matching Drift Definition

**What goes wrong:** Drift converts camelCase Dart names to snake_case SQL names. If the migration SQL uses different names, the table columns won't match what Drift expects.
**Why it happens:** Manual migration means the developer must manually match Drift's naming convention.
**How to avoid:** Drift's convention: `squatTm` -> `squat_tm`, `currentCycle` -> `current_cycle`, `isActive` -> `is_active`, `currentWeek` -> `current_week`. Verify each column name in the migration SQL matches the Drift snake_case conversion of the Dart property name.
**Warning signs:** Runtime error when reading rows; columns appear to be null when they have data.

### Pitfall 4: Not Bumping schemaVersion

**What goes wrong:** Migration code added to `onUpgrade` but `schemaVersion` still returns 63. Migration never runs because Drift sees the database is already at version 63.
**Why it happens:** Forgetting the one-line change.
**How to avoid:** Always update `int get schemaVersion => 64;` in the same commit as the migration code.
**Warning signs:** New table does not exist at runtime. `CREATE TABLE IF NOT EXISTS` silently succeeds on fresh installs (via `onCreate`) but migration never runs for existing users.

### Pitfall 5: Export/Import Backward Compatibility

**What goes wrong:** New database version (v64) cannot reimport data exported from v63 or earlier, or vice versa.
**Why it happens:** Schema change without considering import path.
**How to avoid:** The new table is purely additive:
- **CSV export/import:** Only covers `workouts` and `gym_sets` tables. The new `fivethreeone_blocks` table is NOT part of CSV export. No changes needed to `export_data.dart` or `import_data.dart`.
- **Database export/import:** The `.sqlite` file copy mechanism in `_importDatabaseNativeWithResult()` copies the entire DB file and reopens it. On reopen, `onUpgrade` runs if the imported DB has a lower schema version. The `CREATE TABLE IF NOT EXISTS` migration handles this gracefully.
- **CLAUDE.md requirement:** "If database version has been changed, and previous exported data from app can't be reimported, affirm me." -- For this phase, the answer is: previous exports CAN be reimported. The migration adds a new table; it does not modify or remove existing tables or columns.
**Warning signs:** Import fails with "table not found" or "unknown column" errors.

### Pitfall 6: schemes.dart Coupling to Database or Flutter

**What goes wrong:** The schemes module imports Drift types, Flutter widgets, or Provider, making it untestable in isolation and creating circular dependencies.
**Why it happens:** Temptation to use `FiveThreeOneBlock` data class (generated by Drift) directly in scheme functions.
**How to avoid:** schemes.dart takes primitive parameters (int cycleType, int week, String supplementalType) and returns records. It never imports from `database/` or `package:flutter/`.
**Warning signs:** Cannot unit test schemes.dart without `flutter test` harness or database setup.

## Code Examples

### Complete Table Definition

```dart
// lib/database/fivethreeone_blocks.dart
// Source: Existing codebase pattern (notes.dart, bodyweight_entries.dart)
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
  // 0=Leader1, 1=Leader2, 2=7th Week Deload, 3=Anchor, 4=TM Test
  IntColumn get currentWeek => integer().withDefault(const Constant(1))();
  // 1-3 within each cycle (7th Week cycles only use week 1)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get completed => dateTime().nullable()();
}
```

### Complete Migration SQL

```dart
// In database.dart onUpgrade, after the from62To63 block:
// Source: Existing migration pattern (from62To63, from52To57)

// from63To64: Add fivethreeone_blocks table for block programming
if (from < 64 && to >= 64) {
  await m.database.customStatement('''
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
    )
  ''');
}
```

### Complete State Class (Phase 6 scope)

```dart
// lib/fivethreeone/fivethreeone_state.dart
// Source: WorkoutState pattern (constructor async init)
import 'package:flutter/material.dart';

import '../database/database.dart';
import '../main.dart';

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
  int get currentCycle => _activeBlock?.currentCycle ?? 0;
  int get currentWeek => _activeBlock?.currentWeek ?? 1;

  Future<void> _loadActiveBlock() async {
    _activeBlock = await (db.fiveThreeOneBlocks.select()
          ..where((b) => b.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
    notifyListeners();
  }

  /// Reload active block from database (call after mutations)
  Future<void> refresh() async {
    await _loadActiveBlock();
  }
}
```

Note: Action methods (`createBlock`, `advanceWeek`, `advanceCycle`) are Phase 7 scope. Phase 6 only needs the read path and Provider registration.

### Schemes Module Structure (Core Data)

```dart
// lib/fivethreeone/schemes.dart
// NO imports from database/ or package:flutter/

/// A single set prescription
typedef SetScheme = ({double percentage, int reps, bool amrap});

/// Cycle type constants
const int cycleLeader1 = 0;
const int cycleLeader2 = 1;
const int cycleDeload = 2;
const int cycleAnchor = 3;
const int cycleTmTest = 4;

/// Human-readable cycle names
const List<String> cycleNames = [
  'Leader 1',
  'Leader 2',
  '7th Week Deload',
  'Anchor',
  'TM Test',
];

/// Number of weeks per cycle type
const List<int> cycleWeeks = [3, 3, 1, 3, 1];

/// Whether TM bumps after completing this cycle
const List<bool> cycleBumpsTm = [true, true, false, true, false];

/// Total weeks in a complete block
const int totalBlockWeeks = 11; // 3+3+1+3+1

/// 5's PRO scheme (Leader cycles) - all sets x5, no AMRAP
const Map<int, List<SetScheme>> fivesProScheme = {
  1: [(percentage: 0.65, reps: 5, amrap: false),
      (percentage: 0.75, reps: 5, amrap: false),
      (percentage: 0.85, reps: 5, amrap: false)],
  2: [(percentage: 0.70, reps: 5, amrap: false),
      (percentage: 0.80, reps: 5, amrap: false),
      (percentage: 0.90, reps: 5, amrap: false)],
  3: [(percentage: 0.75, reps: 5, amrap: false),
      (percentage: 0.85, reps: 5, amrap: false),
      (percentage: 0.95, reps: 5, amrap: false)],
};

/// PR Sets scheme (Anchor cycle) - AMRAP on final set
const Map<int, List<SetScheme>> prSetsScheme = {
  1: [(percentage: 0.65, reps: 5, amrap: false),
      (percentage: 0.75, reps: 5, amrap: false),
      (percentage: 0.85, reps: 5, amrap: true)],
  2: [(percentage: 0.70, reps: 3, amrap: false),
      (percentage: 0.80, reps: 3, amrap: false),
      (percentage: 0.90, reps: 3, amrap: true)],
  3: [(percentage: 0.75, reps: 5, amrap: false),
      (percentage: 0.85, reps: 3, amrap: false),
      (percentage: 0.95, reps: 1, amrap: true)],
};

/// 7th Week Deload scheme (single week)
const List<SetScheme> deloadScheme = [
  (percentage: 0.70, reps: 5, amrap: false),
  (percentage: 0.80, reps: 5, amrap: false),
  (percentage: 0.90, reps: 1, amrap: false),
  (percentage: 1.00, reps: 1, amrap: false),
];

/// 7th Week TM Test scheme (single week)
const List<SetScheme> tmTestScheme = [
  (percentage: 0.70, reps: 5, amrap: false),
  (percentage: 0.80, reps: 5, amrap: false),
  (percentage: 0.90, reps: 5, amrap: false),
  (percentage: 1.00, reps: 5, amrap: false),
];

/// Returns main work scheme for given cycle type and week
List<SetScheme> getMainScheme({
  required int cycleType,
  required int week,
}) {
  switch (cycleType) {
    case cycleLeader1:
    case cycleLeader2:
      return fivesProScheme[week] ?? [];
    case cycleAnchor:
      return prSetsScheme[week] ?? [];
    case cycleDeload:
      return deloadScheme;
    case cycleTmTest:
      return tmTestScheme;
    default:
      return [];
  }
}

/// BBB supplemental: 5 sets x 10 reps at 60% TM
const List<SetScheme> bbbScheme = [
  (percentage: 0.60, reps: 10, amrap: false),
  (percentage: 0.60, reps: 10, amrap: false),
  (percentage: 0.60, reps: 10, amrap: false),
  (percentage: 0.60, reps: 10, amrap: false),
  (percentage: 0.60, reps: 10, amrap: false),
];

/// FSL supplemental: 5 sets x 5 reps at first working set %
/// The percentage varies by week (matches first set of main work)
List<SetScheme> getFslScheme({required int week}) {
  final firstSetPct = [0.65, 0.70, 0.75][week - 1];
  return List.generate(5, (_) =>
    (percentage: firstSetPct, reps: 5, amrap: false));
}

/// Returns supplemental scheme for given type, cycle, and week
List<SetScheme> getSupplementalScheme({
  required int cycleType,
  required int week,
}) {
  switch (cycleType) {
    case cycleLeader1:
    case cycleLeader2:
      return bbbScheme; // BBB 5x10 @ 60% for Leader cycles
    case cycleAnchor:
      return getFslScheme(week: week); // FSL 5x5 for Anchor
    case cycleDeload:
    case cycleTmTest:
      return []; // No supplemental for 7th Week cycles
    default:
      return [];
  }
}

/// Returns the supplemental type name for display
String getSupplementalName(int cycleType) {
  switch (cycleType) {
    case cycleLeader1:
    case cycleLeader2:
      return 'BBB 5x10';
    case cycleAnchor:
      return 'FSL 5x5';
    default:
      return '';
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Drift generated migrations (`drift_dev schema steps`) | Manual SQL in `onUpgrade` | Codebase convention from v31+ | All 12+ migrations are manual; keep this pattern |
| `SettingsState` stream watching | `WorkoutState` constructor async init | Both patterns coexist | Block state should use WorkoutState pattern (manual control) |
| Hardcoded 4-week scheme in calculator | Data-driven schemes module | This phase introduces it | Calculator will consume schemes instead of generating them |

**Deprecated/outdated:**
- The existing `fivethreeoneWeek` column in Settings (1-4 week counter) will be deprecated in favor of block's `currentCycle` + `currentWeek`. However, the column is NOT removed for backward compatibility. When no active block exists, the calculator continues using `fivethreeoneWeek` from Settings (graceful degradation).

## Open Questions

1. **Deload scheme rep counts**
   - What we know: User specified 70%x5, 80%x3-5, 90%x1, 100%x1. Some sources say 70%x5, 80%x3, 90%x1, 100%x1.
   - What's unclear: Whether "3-5" means minimum 3 or exactly 5 for the 80% set.
   - Recommendation: Use 70%x5, 80%x5, 90%x1, 100%x1 (simpler, matches spirit of deload). The user can adjust later. This is a one-line change in `deloadScheme`.

2. **Unit storage in block table**
   - What we know: Block stores `unit TEXT NOT NULL` (kg or lb) captured at creation time. Settings also has `strengthUnit`.
   - What's unclear: What happens if user changes `strengthUnit` in Settings after creating a block.
   - Recommendation: Phase 6 stores the unit. Phase 7+ can decide whether to show a warning on mismatch. For now, just store it.

3. **schemes.dart testing strategy**
   - What we know: Pure Dart module can be tested with plain `dart test` (no Flutter harness needed).
   - What's unclear: Whether to write tests in Phase 6 or defer to Phase 7 when the schemes are consumed.
   - Recommendation: Write basic scheme correctness tests in Phase 6 if the plan includes them. The module is small enough that manual verification is also feasible.

## Sources

### Primary (HIGH confidence)

- **Codebase analysis (direct file reads):**
  - `lib/database/database.dart` -- migration patterns (v31-v63), schema version 63, `@DriftDatabase` table list, migration SQL patterns
  - `lib/database/settings.dart` -- existing 5/3/1 columns (lines 44-49), 59 total columns confirming table bloat
  - `lib/database/notes.dart` -- `@DataClassName('Note')` pattern for table definition
  - `lib/database/bodyweight_entries.dart` -- simple table definition pattern with `unit` text column
  - `lib/database/workouts.dart` -- table with nullable columns pattern
  - `lib/main.dart` -- `appProviders()` MultiProvider registration, `db` global singleton
  - `lib/settings/settings_state.dart` -- stream-watching ChangeNotifier pattern (lines 24-33)
  - `lib/workouts/workout_state.dart` -- constructor async init pattern (lines 11-16)
  - `lib/plan/plan_state.dart` -- another constructor async init pattern (lines 27-37)
  - `lib/widgets/five_three_one_calculator.dart` -- existing scheme structure (typedef at line 179), `_getWorkingSetScheme()` method
  - `lib/export_data.dart` -- CSV export only covers workouts + gym_sets (lines 39-148)
  - `lib/import_data.dart` -- database import mechanism (line 106, `.sqlite` file copy)
  - `lib/constants.dart` -- `defaultSettings` companion pattern
  - `.planning/codebase/CONVENTIONS.md` -- naming patterns, import order, error handling style
- **Context7 Drift documentation (`/simolus3/drift`):**
  - Table definitions with `@DataClassName` annotation
  - Manual migration with `onUpgrade`, `from < X && to >= X` pattern
  - `customStatement` for raw SQL in migrations
- **Context7 Provider documentation (`/websites/pub_dev_packages_provider`):**
  - `ChangeNotifierProvider` registration in `MultiProvider`
  - Constructor-based initialization pattern

### Secondary (MEDIUM confidence)

- **Milestone research files (codebase-specific analysis):**
  - `.planning/research/SUMMARY.md` -- recommended stack, phase structure
  - `.planning/research/ARCHITECTURE.md` -- data model design, state management patterns
  - `.planning/research/PITFALLS.md` -- migration error handling, Settings overload
  - `.planning/research/STACK.md` -- Drift table definition, migration code pattern
  - `.planning/research/FEATURES.md` -- scheme definitions per cycle type

### Tertiary (LOW confidence)

None. All findings verified against codebase and Context7 documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero new dependencies, all patterns from existing codebase
- Architecture: HIGH -- direct analog for every component (table, state, registration)
- Pitfalls: HIGH -- pitfalls derived from actual codebase analysis (SQLite type mappings, migration patterns, naming conventions)

**Research date:** 2026-02-11
**Valid until:** 2026-03-11 (stable -- no external dependencies to become outdated)
