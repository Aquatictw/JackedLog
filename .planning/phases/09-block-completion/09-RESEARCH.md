# Phase 9: Block Completion - Research

**Researched:** 2026-02-11
**Domain:** Flutter navigation (full-screen summary), Drift schema migration (starting TM columns), Provider state management, block lifecycle completion
**Confidence:** HIGH

## Summary

Phase 9 adds a post-block summary screen and block completion flow. When the user taps "Complete Week" on the final week of TM Test (cycle 4, week 1), a summary screen appears showing starting TMs vs ending TMs for all 4 lifts with delta gains. After viewing, "Done" returns to notes page. Completed blocks are listed on the block overview page as history. When starting a new block after completion, TMs pre-fill from the last block's ending values.

The central technical challenge is that the current `fivethreeone_blocks` table does NOT store starting TMs separately. The `squatTm`, `benchTm`, `deadliftTm`, `pressTm` columns get mutated by `bumpTms()` (up to 3 times per block) and by manual inline edits via `updateTm()`. This means starting TMs cannot be back-calculated. A schema migration (v64 -> v65) is required to add 4 `start_*_tm` columns, populated at block creation time and never mutated afterward. For existing completed blocks (if any), start values can be set to the current values (no delta info available).

All UI patterns exist in the codebase: full-page `Scaffold` with `MaterialPageRoute` push (like `BlockOverviewPage`), `Card` layouts with `colorScheme` theming (like `_TmCard`), and banner modifications in `notes_page.dart` (existing `_TrainingMaxBanner` already handles active/inactive states).

**Primary recommendation:** Add 4 `start_*_tm` columns to the blocks table via migration v65. Store starting TMs at block creation, never mutate them. Build summary as a new `BlockSummaryPage` pushed from the "Complete Week" button handler. Show completed blocks in `BlockOverviewPage` below the active block section via a Drift query on `isActive = false` ordered by `completed DESC`.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter Material 3 | SDK (installed) | Summary page UI, cards, navigation | Already used for all 5/3/1 UI |
| Drift | 2.30.0 (installed) | Schema migration for start_tm columns, completed block queries | Existing migration pattern in database.dart |
| Provider | 6.1.1 (installed) | FiveThreeOneState mutations and watch | Already registered in main.dart |

### Supporting

No new libraries needed. All UI built from existing Material 3 primitives.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Separate start_tm columns | Back-calculate from bump count | Users can manually edit TMs mid-block, making back-calculation impossible. Columns are the only reliable approach. |
| Full-page summary screen | Dialog or bottom sheet | Summary has enough content (4 lifts, deltas, block dates) to warrant a full Scaffold. Dialogs feel cramped. Decision locked in CONTEXT.md. |
| Drift query for completed blocks | Cache in FiveThreeOneState | Completed blocks are read-only history; a simple select query is sufficient and keeps state class focused on the active block. |

### Installation

No new packages. Schema migration requires `build_runner` to regenerate `database.g.dart` after adding columns.

## Architecture Patterns

### Recommended Project Structure

```
lib/
  database/
    fivethreeone_blocks.dart   # ADD 4 start_*_tm columns (MODIFY)
    database.dart              # ADD migration v64->v65, bump schemaVersion (MODIFY)
  fivethreeone/
    fivethreeone_state.dart    # ADD completeBlock(), getCompletedBlocks(), modify createBlock() (MODIFY)
    block_overview_page.dart   # ADD completed block history list, modify Complete Week handler (MODIFY)
    block_summary_page.dart    # Post-block summary screen (NEW)
  notes/
    notes_page.dart            # Modify banner for no-active-block state with "Start Block" (MODIFY)
```

### Pattern 1: Schema Migration for Starting TMs

**What:** Add 4 nullable `start_*_tm` columns to `fivethreeone_blocks` table. Populate at creation, never mutate.
**When to use:** Block creation and summary display.
**Source:** Existing migration pattern in `database.dart` (e.g., from63To64 block)

```dart
// In database.dart, add new migration block:
// from64To65: Add starting TM columns for block summary
if (from < 65 && to >= 65) {
  await m.database.customStatement(
    'ALTER TABLE fivethreeone_blocks ADD COLUMN start_squat_tm REAL',
  ).catchError((e) {});
  await m.database.customStatement(
    'ALTER TABLE fivethreeone_blocks ADD COLUMN start_bench_tm REAL',
  ).catchError((e) {});
  await m.database.customStatement(
    'ALTER TABLE fivethreeone_blocks ADD COLUMN start_deadlift_tm REAL',
  ).catchError((e) {});
  await m.database.customStatement(
    'ALTER TABLE fivethreeone_blocks ADD COLUMN start_press_tm REAL',
  ).catchError((e) {});

  // Backfill existing blocks: set start TMs equal to current TMs
  // (no historical data available for already-bumped blocks)
  await m.database.customStatement('''
    UPDATE fivethreeone_blocks
    SET start_squat_tm = squat_tm,
        start_bench_tm = bench_tm,
        start_deadlift_tm = deadlift_tm,
        start_press_tm = press_tm
  ''');
}
```

**Table definition addition:**
```dart
// In fivethreeone_blocks.dart, add:
RealColumn get startSquatTm => real().nullable()();
RealColumn get startBenchTm => real().nullable()();
RealColumn get startDeadliftTm => real().nullable()();
RealColumn get startPressTm => real().nullable()();
```

**Key details:**
- Columns are nullable because existing rows won't have values until migration backfills them
- Migration backfills with current TMs (best available data for existing blocks)
- `schemaVersion` bumps from 64 to 65
- Must run `build_runner` after modifying table definition to regenerate `database.g.dart`
- CLAUDE.md says "Always do manual migration" -- add the `customStatement` ALTER TABLE calls manually

### Pattern 2: Block Completion Flow (Modify advanceWeek)

**What:** When `isBlockComplete` is true and user taps "Complete Week", navigate to summary page instead of just marking complete.
**When to use:** Final week of TM Test.
**Source:** Current `_CompleteWeekButton` in `block_overview_page.dart` (lines 420-485)

The current flow:
1. User taps "Complete Week"
2. If `needsTmBump`, show TM bump dialog
3. Call `state.advanceWeek()`
4. `advanceWeek()` sets `isActive = false` and `completed = DateTime.now()`

New flow:
1. User taps "Complete Week" on final week of TM Test
2. Call `state.completeBlock()` which marks block complete and returns the completed block data
3. Navigate to `BlockSummaryPage` with the block data
4. Summary shows starting vs ending TMs with deltas
5. "Done" button pops back to notes page

```dart
// Modified _CompleteWeekButton handler for block completion:
if (state.isBlockComplete) {
  // This is the final "Complete Week" tap -- complete and show summary
  final block = state.activeBlock!;
  await state.advanceWeek(); // marks inactive + sets completed timestamp

  if (context.mounted) {
    // Push summary page, replacing the overview page in the nav stack
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlockSummaryPage(block: block),
      ),
    );
  }
}
```

**Important:** Capture `block` reference BEFORE calling `advanceWeek()`, because after advance the block becomes inactive and `activeBlock` returns null. The captured block still has the ending TMs (current values) and start TMs (from the new columns).

### Pattern 3: Summary Page (New Full-Page Scaffold)

**What:** Full-page summary showing block results with starting vs ending TMs.
**When to use:** After block completion, and from block history.
**Source:** `BlockOverviewPage` layout pattern (Scaffold with AppBar and scrollable body)

```dart
class BlockSummaryPage extends StatelessWidget {
  const BlockSummaryPage({required this.block, super.key});
  final FiveThreeOneBlock block;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Block Complete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header card with dates
            // TM progression cards (4 lifts)
            // Each card: Exercise name, start -> end, delta with +/- sign
            // "Done" button
          ],
        ),
      ),
    );
  }
}
```

**TM delta calculation:**
```dart
// For each lift:
final startTm = block.startSquatTm ?? block.squatTm; // fallback for pre-migration blocks
final endTm = block.squatTm;
final delta = endTm - startTm;
// Display: "Squat: 100.0 -> 113.5 kg (+13.5)"
```

### Pattern 4: Completed Blocks List (Block History in Overview)

**What:** Show completed blocks below the active block in `BlockOverviewPage`.
**When to use:** Always, as a history list.
**Source:** Query pattern from existing `FiveThreeOneState._loadActiveBlock()`.

```dart
// In FiveThreeOneState or directly in the page:
Future<List<FiveThreeOneBlock>> getCompletedBlocks() async {
  return (db.select(db.fiveThreeOneBlocks)
    ..where((b) => b.isActive.equals(false))
    ..orderBy([(b) => OrderingTerm(
        expression: b.completed, mode: OrderingMode.desc)]))
    .get();
}
```

**Display in BlockOverviewPage:**
- Below the active block timeline (or in place of it when none active)
- Each completed block: a compact card showing dates, ending TMs, and a tap target to view the summary
- Tapping a completed block opens `BlockSummaryPage` with that block's data

### Pattern 5: Notes Page Banner (No Active Block State)

**What:** Modify existing `_TrainingMaxBanner` to show "No active block - Start one" when `hasActiveBlock` is false.
**When to use:** After block completion, before starting a new block.
**Source:** Existing `_TrainingMaxBanner` in `notes_page.dart` (lines 394-500)

The current banner already handles the no-active-block state (lines 412-414):
```dart
final label = hasBlock
    ? fiveThreeOneState.positionLabel
    : 'Start a 5/3/1 block →';
```

When tapped without an active block, it opens `BlockCreationDialog` (line 431-433). This existing behavior matches the CONTEXT.md requirement: "Notes page banner shows 'No active block' with a button to start a new block."

The modification needed is minor: when starting a new block after completion, pre-fill TMs from the last completed block's ending TMs instead of from Settings.

### Pattern 6: New Block TM Pre-fill from Last Block

**What:** When opening `BlockCreationDialog` after a completed block, pre-fill TMs from the last completed block's ending values.
**When to use:** Creating a new block when completed blocks exist.
**Source:** Current `BlockCreationDialog._loadSettings()` reads from Settings (lines 33-46)

```dart
// Modified _loadSettings in BlockCreationDialog:
void _loadSettings() async {
  // Try to get last completed block first
  final lastBlock = await (db.select(db.fiveThreeOneBlocks)
    ..where((b) => b.isActive.equals(false))
    ..orderBy([(b) => OrderingTerm(
        expression: b.completed, mode: OrderingMode.desc)])
    ..limit(1))
    .getSingleOrNull();

  if (lastBlock != null) {
    _unit = lastBlock.unit;
    _squatController.text = _formatTm(lastBlock.squatTm);
    _benchController.text = _formatTm(lastBlock.benchTm);
    _deadliftController.text = _formatTm(lastBlock.deadliftTm);
    _pressController.text = _formatTm(lastBlock.pressTm);
  } else {
    // Fallback to Settings TMs (no completed blocks)
    final settings = context.read<SettingsState>().value;
    _unit = settings.strengthUnit;
    _squatController.text = settings.fivethreeoneSquatTm?.toStringAsFixed(1) ?? '';
    // ... etc
  }
}
```

### Anti-Patterns to Avoid

- **Back-calculating starting TMs from bumps:** Users can manually edit TMs at any time via the `_TmCard` inline editor and the calculator. No reliable way to reverse-engineer the starting values. Store them at creation time.
- **Storing the summary as a separate data structure:** The block row itself contains all the data needed (start TMs, end TMs, created date, completed date). No need for a separate summary table.
- **Navigating to summary with `Navigator.push` instead of `pushReplacement`:** After completion, the overview page's active block is gone. Pushing on top of it means back-navigating to a stale overview. Use `pushReplacement` so "Done" pops cleanly to notes page.
- **Putting history fetching in FiveThreeOneState as persistent state:** Completed blocks are read-only history data. A simple `FutureBuilder` query in the overview page is simpler than caching history in the state class. Keep the state class focused on the active block.
- **Mutating start TM columns after creation:** Start TMs must be immutable. Only the regular TM columns (`squatTm`, etc.) are mutable via `bumpTms()` and `updateTm()`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Starting TM tracking | Bump counter / reverse calculation | 4 dedicated `start_*_tm` columns | Manual edits make reverse calculation impossible |
| Block history query | Complex caching system | Simple `db.select()..where(isActive.equals(false))` | Read-only data, Drift handles it efficiently |
| TM delta formatting | Custom formatting logic | `(endTm - startTm).toStringAsFixed(1)` with sign prefix | Standard Dart, no library needed |
| Navigation after completion | Custom route management | `Navigator.pushReplacement` | Standard Flutter; prevents stale overview page |
| Date formatting for summary | Custom formatter | `intl` package `DateFormat` (already used in notes_page.dart) | Already imported and used for note timestamps |

**Key insight:** The only schema change needed is 4 columns. Everything else is UI composition from existing patterns and simple Drift queries.

## Common Pitfalls

### Pitfall 1: Missing Starting TMs (Schema Gap)

**What goes wrong:** Summary page shows "0.0" or null for starting TMs because the columns don't exist or weren't populated.
**Why it happens:** Current table has no start TM columns. If migration doesn't backfill existing blocks, or if `createBlock()` isn't updated to set start TMs, the values will be null.
**How to avoid:** Migration must backfill ALL existing rows (`SET start_squat_tm = squat_tm`). `createBlock()` must set start TMs equal to the initial TM values at creation time. Summary page must handle null with fallback (`block.startSquatTm ?? block.squatTm`).
**Warning signs:** Summary shows "+0.0" for all lifts, or crashes on null access.

### Pitfall 2: Capturing Block Data After advanceWeek()

**What goes wrong:** After `advanceWeek()` marks the block inactive, `state.activeBlock` returns null. If the summary page tries to read from `state.activeBlock`, it crashes.
**Why it happens:** `advanceWeek()` updates the database row (`isActive = false`), then calls `refresh()` which sets `_activeBlock = null` and calls `notifyListeners()`.
**How to avoid:** Capture the block's data (or the block object itself with its current TM values) BEFORE calling `advanceWeek()`. Pass the captured block to `BlockSummaryPage` as a constructor parameter. The summary page should never read from `FiveThreeOneState`.
**Warning signs:** Null pointer exception after tapping "Complete Week"; summary page shows empty data.

### Pitfall 3: pushReplacement vs push Navigation

**What goes wrong:** After viewing summary and tapping "Done", user navigates back to the block overview page which now shows "No active block" (stale state).
**Why it happens:** If summary is pushed on top of overview, back navigation returns to overview with no active block.
**How to avoid:** Use `Navigator.of(context).pushReplacement(...)` when navigating from overview to summary after completion. The "Done" button then uses `Navigator.pop()` to return to notes page. Alternatively, pop the overview and then push the summary.
**Warning signs:** User sees the "No active block" empty state on the overview page after back-navigating from summary.

### Pitfall 4: Pre-fill Logic Order of Precedence

**What goes wrong:** New block creation pre-fills from Settings TMs instead of the last completed block's ending TMs, showing outdated values.
**Why it happens:** The current `_loadSettings()` only reads from Settings, not from completed blocks.
**How to avoid:** Check for completed blocks FIRST. If one exists, use its ending TMs. Only fall back to Settings TMs when no completed blocks exist.
**Warning signs:** User completes a block where TMs bumped to 113.5, but new block creation form shows 100.0 (the old Settings value).

### Pitfall 5: Database Migration Ordering

**What goes wrong:** Migration fails or columns are missing because the migration block doesn't match the schema version bump.
**Why it happens:** `schemaVersion` is bumped to 65 but the migration guard checks wrong version boundary, or the `.catchError` masks a real error.
**How to avoid:** Migration guard must be `if (from < 65 && to >= 65)`. Use `.catchError((e) {})` on each ALTER TABLE (standard pattern in codebase). Backfill runs after all columns are added. Test with both fresh install (onCreate) and upgrade (onUpgrade).
**Warning signs:** App crashes on startup after update; `start_squat_tm` column not found errors.

### Pitfall 6: Completed Block Without Completion Timestamp

**What goes wrong:** Block is marked `isActive = false` but `completed` is null, causing history queries to fail or sort incorrectly.
**Why it happens:** `createBlock()` deactivates existing blocks with `completed: Value(DateTime.now())`, but `advanceWeek()` block-complete branch does the same. Both paths are correct. The risk is a code path that sets `isActive = false` without setting `completed`.
**How to avoid:** Audit all code paths that set `isActive = false` and ensure they also set `completed`. Currently: `createBlock()` line 82 and `advanceWeek()` line 123 both do this correctly.
**Warning signs:** Completed blocks with null completed timestamp appear at wrong position in history list.

## Code Examples

### Block Summary Page Layout

```dart
// lib/fivethreeone/block_summary_page.dart
// Source: BlockOverviewPage layout pattern

class BlockSummaryPage extends StatelessWidget {
  const BlockSummaryPage({required this.block, super.key});
  final FiveThreeOneBlock block;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Block Complete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Achievement/celebration header
            _buildHeader(context, colorScheme),
            const SizedBox(height: 16),
            // 4 lift progression cards
            _buildLiftCard(context, 'Squat',
                block.startSquatTm ?? block.squatTm, block.squatTm, block.unit),
            _buildLiftCard(context, 'Bench',
                block.startBenchTm ?? block.benchTm, block.benchTm, block.unit),
            _buildLiftCard(context, 'Deadlift',
                block.startDeadliftTm ?? block.deadliftTm, block.deadliftTm, block.unit),
            _buildLiftCard(context, 'OHP',
                block.startPressTm ?? block.pressTm, block.pressTm, block.unit),
            const SizedBox(height: 24),
            // Done button
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### TM Progression Card Widget

```dart
// Source: _TmCard in block_overview_page.dart for Card styling
Widget _buildLiftCard(BuildContext context, String name,
    double startTm, double endTm, String unit) {
  final delta = endTm - startTm;
  final sign = delta >= 0 ? '+' : '';
  final colorScheme = Theme.of(context).colorScheme;

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${_formatTm(startTm)} → ${_formatTm(endTm)} $unit',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: delta > 0
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$sign${_formatTm(delta)} $unit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: delta > 0
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

### Modified createBlock with Starting TMs

```dart
// Source: Existing createBlock in fivethreeone_state.dart
Future<void> createBlock({
  required double squatTm,
  required double benchTm,
  required double deadliftTm,
  required double pressTm,
  required String unit,
}) async {
  // Deactivate any existing active block
  await (db.update(db.fiveThreeOneBlocks)
    ..where((b) => b.isActive.equals(true)))
    .write(FiveThreeOneBlocksCompanion(
      isActive: const Value(false),
      completed: Value(DateTime.now()),
    ));

  // Insert new block with both current and starting TMs
  await db.into(db.fiveThreeOneBlocks).insert(
    FiveThreeOneBlocksCompanion.insert(
      created: DateTime.now(),
      squatTm: squatTm,
      benchTm: benchTm,
      deadliftTm: deadliftTm,
      pressTm: pressTm,
      unit: unit,
      // Starting TMs snapshot (immutable)
      startSquatTm: Value(squatTm),
      startBenchTm: Value(benchTm),
      startDeadliftTm: Value(deadliftTm),
      startPressTm: Value(pressTm),
    ),
  );

  await refresh();
}
```

### Completed Blocks Query

```dart
// Source: Drift select pattern from _loadActiveBlock
Future<List<FiveThreeOneBlock>> getCompletedBlocks() async {
  return (db.select(db.fiveThreeOneBlocks)
    ..where((b) => b.isActive.equals(false))
    ..where((b) => b.completed.isNotNull())
    ..orderBy([(b) => OrderingTerm(
        expression: b.completed, mode: OrderingMode.desc)]))
    .get();
}
```

### Complete Week Handler (Modified)

```dart
// Source: Existing _CompleteWeekButton in block_overview_page.dart
// Key change: navigate to summary when completing the final week

onPressed: () async {
  final state = context.read<FiveThreeOneState>();

  if (state.isBlockComplete) {
    // Final week of TM Test: complete block and show summary
    final completedBlock = state.activeBlock!;
    await state.advanceWeek(); // sets isActive=false, completed=now

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BlockSummaryPage(block: completedBlock),
        ),
      );
    }
    return;
  }

  // Normal week advancement (existing logic)
  if (state.needsTmBump) {
    // ... existing TM bump dialog ...
  }
  await state.advanceWeek();
},
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Only current TMs stored | Starting + current TMs stored per block | Phase 9 (this phase) | Enables before/after summary display |
| Block completion = silent deactivation | Block completion = summary screen + deactivation | Phase 9 (this phase) | User sees meaningful progress feedback |
| No block history | Completed blocks listed in overview page | Phase 9 (this phase) | Users can revisit past block summaries |
| New block TMs from Settings only | New block TMs from last completed block | Phase 9 (this phase) | Smooth progression carry-over between blocks |

**Deprecated/outdated:**
- The `createBlock()` method's current version does not store starting TMs. Phase 9 must update it.
- The `_CompleteWeekButton` currently shows static "Block Complete" text when the block is at its final position. Phase 9 replaces this with an active "Complete Block" button that triggers the summary flow.

## Open Questions

1. **What to do with the existing "Block Complete" text state**
   - What we know: When `isBlockComplete` is true, `_CompleteWeekButton` shows "Block Complete" text instead of a button (line 429-434). But the user decision says summary screen appears after tapping "Complete Week" on the final week.
   - What's unclear: The `isBlockComplete` getter returns true when `currentCycle == cycleTmTest && currentWeek >= cycleWeeks[cycleTmTest]`. Since TM Test only has 1 week, this is true when `currentCycle == 4 && currentWeek >= 1`. So on the TM Test week, `isBlockComplete` is already true and the button shows text, not a tappable button.
   - Recommendation: Change the logic so `isBlockComplete` returns true only AFTER the final advance (when the block is marked inactive). While on TM Test week 1 (the last week), show the "Complete Week" button. The `isBlockComplete` check in the button should be adjusted so the button appears and triggers summary navigation when tapped on the final week. The simplest approach: check if `currentCycle == cycleTmTest` (we're on the last cycle) to show "Complete Block" as the button label, but still show it as a tappable button, not static text.

2. **History list FutureBuilder vs state caching**
   - What we know: Completed blocks are read-only. CONTEXT.md says summary is revisitable.
   - What's unclear: Whether to use `FutureBuilder` in the overview page or cache in `FiveThreeOneState`.
   - Recommendation: Use `FutureBuilder` in `BlockOverviewPage`. The state class should stay focused on the active block. A `getCompletedBlocks()` method on the state class (or directly using `db`) is sufficient.

3. **Export/import of block data**
   - What we know: The export system (`export_data.dart`) only exports workouts and gym_sets tables. It does NOT export the `fivethreeone_blocks` table. Database export (SQLite file) includes everything.
   - What's unclear: Whether Phase 9 should add CSV export for blocks.
   - Recommendation: Out of scope for Phase 9. Database export already includes blocks. CSV export for blocks can be a future enhancement.

## Sources

### Primary (HIGH confidence)

- **Codebase analysis (direct file reads):**
  - `lib/database/fivethreeone_blocks.dart` -- Table definition confirming NO start_tm columns exist
  - `lib/fivethreeone/fivethreeone_state.dart` -- `createBlock()`, `advanceWeek()`, `bumpTms()`, `updateTm()` methods showing TM mutation
  - `lib/fivethreeone/block_overview_page.dart` -- `_CompleteWeekButton`, `_TmCard` (inline editing), `_CycleEntry` timeline
  - `lib/fivethreeone/block_creation_dialog.dart` -- TM pre-fill from Settings pattern
  - `lib/fivethreeone/schemes.dart` -- `cycleWeeks`, `cycleBumpsTm`, `cycleTmTest` constants
  - `lib/notes/notes_page.dart` -- `_TrainingMaxBanner` with active/inactive block states
  - `lib/database/database.dart` -- Migration pattern (from63To64), schemaVersion=64
  - `lib/widgets/five_three_one_calculator.dart` -- Block-mode TM resolution, `_saveBlockTm()`
  - `lib/export_data.dart` -- Confirmed blocks table NOT exported in CSV format
  - `lib/main.dart` -- Provider tree, `FiveThreeOneState` registration
  - `.planning/phases/07-block-management/07-RESEARCH.md` -- Prior phase research
  - `.planning/phases/09-block-completion/09-CONTEXT.md` -- Locked decisions and discretion areas

### Secondary (MEDIUM confidence)

- **Codebase conventions:** `.planning/codebase/CONVENTIONS.md`, `.planning/codebase/ARCHITECTURE.md` -- Naming, navigation, state management patterns

### Tertiary (LOW confidence)

None. All findings verified against codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero new dependencies, all patterns from existing codebase
- Architecture: HIGH -- schema migration follows exact codebase pattern (from63To64); UI follows BlockOverviewPage pattern
- Pitfalls: HIGH -- pitfalls derived from actual code analysis (missing start TMs, stale activeBlock after advance, navigation stack)

**Research date:** 2026-02-11
**Valid until:** 2026-03-11 (stable -- no external dependencies, pure codebase patterns)
