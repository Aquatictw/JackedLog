# Phase 7: Block Management - Research

**Researched:** 2026-02-11
**Domain:** Flutter UI (forms, stepper/timeline, navigation), Drift CRUD operations, Provider state mutations
**Confidence:** HIGH

## Summary

Phase 7 builds the user-facing block management features on top of Phase 6's data foundation. Five deliverables: (1) block creation form in Settings, (2) block overview page with vertical stepper, (3) week/cycle advancement logic, (4) TM auto-bump with confirmation dialog, and (5) notes page banner showing current block position.

All components follow existing codebase patterns. The creation form mirrors `TrainingMaxEditor` (same 4-field TM layout, Dialog with header/content/footer). The overview page is a new `MaterialPageRoute`-pushed Scaffold (like sub-settings pages). Week advancement adds action methods to `FiveThreeOneState` (like `WorkoutState.startWorkout`). The banner replaces the existing `_TrainingMaxBanner` in `notes_page.dart` with block-aware content.

No new dependencies needed. No database schema changes. All mutations go through the existing `FiveThreeOneBlocksCompanion` and `db.fiveThreeOneBlocks` generated APIs.

**Primary recommendation:** Build all UI from existing Material 3 widgets (Card, ListTile, Column, Container). Do NOT use Flutter's built-in `Stepper` widget -- it has rigid styling and limited customization. Build a custom vertical timeline from basic layout widgets.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter Material 3 | SDK (installed) | All UI: forms, dialogs, cards, navigation | Already used everywhere in codebase |
| Drift | 2.30.0 (installed) | CRUD operations via generated companions | Phase 6 table + codegen already complete |
| Provider | 6.1.1 (installed) | State management via FiveThreeOneState | Phase 6 ChangeNotifier already registered |

### Supporting

No new libraries needed. All UI built from Material 3 primitives already in use.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom vertical timeline | Flutter `Stepper` widget | Stepper has rigid step numbering, limited color control, fixed layout. Custom timeline from Column + Row + Container gives full control over color-coding, expansion, and scheme info display. |
| Full-page overview route | Modal bottom sheet | Overview page has too much content for a sheet. Full Scaffold with AppBar matches settings sub-page pattern. |
| Dialog for TM bump confirmation | Separate page | AlertDialog is the codebase pattern for confirmations (delete note, end workout). Keep consistent. |

### Installation

No new packages. No build_runner needed (Phase 6 codegen already covers the table).

## Architecture Patterns

### Recommended Project Structure

```
lib/
  fivethreeone/
    fivethreeone_state.dart    # ADD action methods (MODIFY)
    schemes.dart               # ADD getMainSchemeName helper (MODIFY)
    block_overview_page.dart   # Block overview with stepper UI (NEW)
    block_creation_dialog.dart # Block creation form dialog (NEW)
  notes/
    notes_page.dart            # Replace _TrainingMaxBanner with block-aware banner (MODIFY)
  settings/
    settings_page.dart         # Add 5/3/1 ListTile entry point (MODIFY)
```

### Pattern 1: State Action Methods (CRUD in ChangeNotifier)

**What:** Add `createBlock`, `advanceWeek`, and `bumpTms` methods to `FiveThreeOneState`.
**When to use:** User-initiated mutations to the active block.
**Source:** `WorkoutState.startWorkout()`, `WorkoutState.endWorkout()` patterns in `lib/workouts/workout_state.dart`

```dart
// In fivethreeone_state.dart
Future<void> createBlock({
  required double squatTm,
  required double benchTm,
  required double deadliftTm,
  required double pressTm,
  required String unit,
}) async {
  // Deactivate any existing active block
  await (db.fiveThreeOneBlocks.update()
    ..where((b) => b.isActive.equals(true)))
    .write(FiveThreeOneBlocksCompanion(
      isActive: const Value(false),
      completed: Value(DateTime.now()),
    ));

  // Insert new block
  await db.fiveThreeOneBlocks.insertOne(
    FiveThreeOneBlocksCompanion.insert(
      created: DateTime.now(),
      squatTm: squatTm,
      benchTm: benchTm,
      deadliftTm: deadliftTm,
      pressTm: pressTm,
      unit: unit,
    ),
  );

  await refresh();
}

Future<void> advanceWeek() async {
  final block = _activeBlock;
  if (block == null) return;

  final maxWeeks = cycleWeeks[block.currentCycle];

  if (block.currentWeek < maxWeeks) {
    // Advance within same cycle
    await (db.fiveThreeOneBlocks.update()
      ..where((b) => b.id.equals(block.id)))
      .write(FiveThreeOneBlocksCompanion(
        currentWeek: Value(block.currentWeek + 1),
      ));
  } else if (block.currentCycle < cycleTmTest) {
    // Advance to next cycle, week 1
    await (db.fiveThreeOneBlocks.update()
      ..where((b) => b.id.equals(block.id)))
      .write(FiveThreeOneBlocksCompanion(
        currentCycle: Value(block.currentCycle + 1),
        currentWeek: const Value(1),
      ));
  } else {
    // Block complete (past TM Test)
    await (db.fiveThreeOneBlocks.update()
      ..where((b) => b.id.equals(block.id)))
      .write(FiveThreeOneBlocksCompanion(
        isActive: const Value(false),
        completed: Value(DateTime.now()),
      ));
  }

  await refresh();
}

Future<void> bumpTms() async {
  final block = _activeBlock;
  if (block == null) return;

  const upperBump = 2.2; // kg, upper body (Bench, OHP)
  const lowerBump = 4.5; // kg, lower body (Squat, Deadlift)

  await (db.fiveThreeOneBlocks.update()
    ..where((b) => b.id.equals(block.id)))
    .write(FiveThreeOneBlocksCompanion(
      squatTm: Value(block.squatTm + lowerBump),
      benchTm: Value(block.benchTm + upperBump),
      deadliftTm: Value(block.deadliftTm + lowerBump),
      pressTm: Value(block.pressTm + upperBump),
    ));

  await refresh();
}
```

**Key details:**
- `FiveThreeOneBlocksCompanion` uses `Value()` wrappers for each field (like `SettingsCompanion`)
- `FiveThreeOneBlocksCompanion.insert(...)` requires `created`, `squatTm`, `benchTm`, `deadliftTm`, `pressTm`, `unit` -- other fields have defaults
- `db.fiveThreeOneBlocks.update()..where(...)` for targeted row updates
- `db.fiveThreeOneBlocks.insertOne(...)` for new rows
- Always call `refresh()` after mutations to reload state and notify listeners

### Pattern 2: Block Creation Dialog (Mirrors TrainingMaxEditor)

**What:** Dialog with 4 TM input fields, pre-filled from Settings values, "Start Block" button.
**When to use:** User taps "Start 5/3/1 Block" from Settings page.
**Source:** `lib/widgets/training_max_editor.dart` (same header/content/footer layout)

```dart
// Key structure -- mirrors TrainingMaxEditor exactly
Dialog(
  child: Container(
    constraints: const BoxConstraints(maxWidth: 500),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header container with primaryContainer background
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Row(/* icon, title, close button */),
        ),
        // Scrollable content with 4 TM fields
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(/* 4 _buildTmField widgets */),
          ),
        ),
        // Footer with info text + "Start Block" button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Info row
              FilledButton(
                onPressed: _createBlock,
                child: const Text('Start Block'),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
```

**Pre-fill logic:**
- Read `fivethreeoneSquatTm`, `fivethreeoneBenchTm`, etc. from `SettingsState.value`
- If values exist, populate controllers with `toStringAsFixed(1)`
- If all 4 are null, show empty fields (user hasn't set TMs before)
- On "Start Block": validate all 4 fields are non-empty, call `FiveThreeOneState.createBlock()`

### Pattern 3: Block Overview Page (Full-page Scaffold)

**What:** Standalone page showing the 5-cycle vertical timeline with week details.
**When to use:** Navigation from banner tap or settings entry.
**Source:** Settings sub-pages pattern (e.g., `AppearanceSettings`, `WorkoutSettings` -- all push `MaterialPageRoute` with `Scaffold` + `AppBar`)

```dart
// Navigation pattern (from notes_page.dart banner or settings)
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const BlockOverviewPage(),
  ),
);
```

**Timeline rendering (custom, NOT Flutter Stepper):**

```dart
// For each of the 5 cycles:
for (int cycleIdx = 0; cycleIdx < 5; cycleIdx++) {
  // Cycle header row with connector line
  // Color: completed=green/muted, current=primary/bold, future=grey
  // If cycle is expanded (current or tapped), show week rows underneath
  // Each week row: "Week N" status indicator
  // Show scheme name and TM values for current/expanded cycle
}
```

**Custom timeline building blocks:**
- Vertical connector: `Container(width: 2, height: X, color: lineColor)` in a Column
- Circle indicator: `Container` with `BoxDecoration(shape: BoxShape.circle)`, colored by state
- Cycle card: `Card` or `Container` with rounded corners, color per state
- Expansion: `AnimatedCrossFade` or simple conditional rendering based on `_expandedCycle` index

### Pattern 4: Notes Page Banner (Replace _TrainingMaxBanner)

**What:** Replace static "5/3/1 Training Max" banner with dynamic block-aware banner.
**When to use:** Always visible at top of NotesPage.
**Source:** Existing `_TrainingMaxBanner` widget in `notes_page.dart` (lines 412-483)

```dart
// Use Provider to read block state
final fiveThreeOneState = context.watch<FiveThreeOneState>();

if (fiveThreeOneState.hasActiveBlock) {
  // Show: "Leader 2 — Week 2 • 5's PRO"
  // Tap: Navigate to BlockOverviewPage
  final block = fiveThreeOneState.activeBlock!;
  final cycleName = cycleNames[block.currentCycle];
  final schemeName = getMainSchemeName(block.currentCycle);
  // Banner text: "$cycleName — Week ${block.currentWeek} • $schemeName"
} else {
  // Show: "Start a 5/3/1 block →"
  // Tap: Open block creation dialog
}
```

### Pattern 5: TM Bump Confirmation Dialog

**What:** AlertDialog showing old/new TMs before applying bump.
**When to use:** When `advanceWeek()` crosses a cycle boundary where `cycleBumpsTm[cycle] == true`.
**Source:** Confirmation dialogs throughout codebase (`showDialog<bool>` pattern in workout_detail_page.dart, notes_page.dart)

```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Bump Training Max?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Cycle complete. Update TMs?'),
        // Show each lift: "Squat: 100.0 → 104.5 kg"
        // Show each lift: "Bench: 70.0 → 72.2 kg"
        // etc.
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Skip'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Bump TMs'),
      ),
    ],
  ),
);

if (confirmed == true) {
  await fiveThreeOneState.bumpTms();
}
```

### Anti-Patterns to Avoid

- **Using Flutter's built-in `Stepper` widget:** It enforces numbered circle indicators, specific button layout ("Continue"/"Cancel"), and resists custom color coding. The block overview needs custom colors (green/accent/grey), cycle names, and expandable week details. Build from Column + Row + Container instead.
- **Splitting advancement + TM bump into one method:** Keep `advanceWeek()` and `bumpTms()` separate. The UI layer decides whether to show the confirmation dialog and call `bumpTms()`. The state class should not show UI.
- **Calling `notifyListeners()` multiple times in one operation:** When deactivating an old block and creating a new one, do both DB writes before the single `refresh()` call. This prevents intermediate states from triggering rebuilds.
- **Hardcoding cycle/week logic in UI:** Use `cycleWeeks`, `cycleBumpsTm`, and `cycleNames` from `schemes.dart`. The UI should read these constants, not duplicate the "3 weeks for Leader, 1 week for Deload" logic.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TM input validation | Custom validators | `double.tryParse()` + null check | Standard Dart; already used in TrainingMaxEditor and Calculator |
| Cycle/week state transitions | Switch statements in UI | `cycleWeeks[cycleType]` from schemes.dart | Already defined as const data; no duplication |
| Confirmation dialogs | Custom overlay | `showDialog<bool>` + `AlertDialog` | Codebase convention in 5+ places |
| Page navigation | Custom route manager | `Navigator.of(context).push(MaterialPageRoute(...))` | Standard Flutter; settings pages use this pattern |
| Color-coded states | Inline color logic | Helper function mapping state to colorScheme | Single source of truth for completed/current/future colors |

**Key insight:** This phase is entirely UI + state methods. No new architecture, no new dependencies, no schema changes. Every pattern already exists in the codebase.

## Common Pitfalls

### Pitfall 1: Advancement Logic Off-by-One Errors

**What goes wrong:** Block advances to wrong cycle or week due to boundary confusion. For example, advancing from Week 3 of Leader 1 should go to Week 1 of Leader 2 (not Week 4 of Leader 1 or Week 1 of Deload).
**Why it happens:** `cycleWeeks` is `[3, 3, 1, 3, 1]`. Deload and TM Test only have 1 week. Easy to assume all cycles have 3 weeks.
**How to avoid:** Always check `cycleWeeks[currentCycle]` for the max week of the current cycle. Test transitions at every boundary: Leader1 W3 -> Leader2 W1, Leader2 W3 -> Deload W1, Deload W1 -> Anchor W1, Anchor W3 -> TM Test W1, TM Test W1 -> block complete.
**Warning signs:** User advances from Deload and skips to Anchor Week 3, or block never completes.

### Pitfall 2: TM Bump at Wrong Boundaries

**What goes wrong:** TMs bump after Deload or TM Test (which should NOT bump), or fail to bump after Leader 1, Leader 2, or Anchor (which SHOULD bump).
**Why it happens:** Confusing "advance past a cycle" with "advance within a cycle." TM bump should happen when leaving cycles where `cycleBumpsTm[cycle] == true`.
**How to avoid:** Check `cycleBumpsTm[currentCycle]` BEFORE advancing to the next cycle. Show confirmation dialog only when this is `true`. The `cycleBumpsTm` array is `[true, true, false, true, false]` -- Leaders and Anchor bump, Deload and TM Test do not.
**Warning signs:** TMs are higher than expected after Deload, or unchanged after Leaders.

### Pitfall 3: Stale State After Block Creation

**What goes wrong:** Banner or overview page shows no active block immediately after creating one, because `FiveThreeOneState` hasn't reloaded.
**Why it happens:** `createBlock()` writes to DB but caller forgets to `await` the `refresh()` call, or the Provider tree doesn't trigger a rebuild because `notifyListeners()` hasn't been called.
**How to avoid:** `createBlock()` must `await refresh()` at the end (which calls `_loadActiveBlock()` which calls `notifyListeners()`). The UI must `context.watch<FiveThreeOneState>()` to receive updates.
**Warning signs:** Need to restart app to see changes; banner doesn't update.

### Pitfall 4: Old Block Not Deactivated

**What goes wrong:** Two blocks have `isActive = true` simultaneously, causing `_loadActiveBlock()` (which uses `..limit(1)`) to return the wrong one.
**Why it happens:** `createBlock()` inserts a new block but doesn't deactivate the existing one first.
**How to avoid:** `createBlock()` must first run an update setting `isActive = false` on all existing active blocks BEFORE inserting the new one. This is a single `UPDATE ... WHERE is_active = 1` query.
**Warning signs:** Block overview shows old block data after creating a new one.

### Pitfall 5: TM Bump Values Mismatch

**What goes wrong:** Using wrong increment values. The requirements specify +2.2kg upper / +4.5kg lower, but the existing calculator uses +2.5kg / +5.0kg.
**Why it happens:** The calculator (`five_three_one_calculator.dart` line 154) has different increment logic (`_unit == 'kg' ? 2.5 : 5.0` for upper, `_unit == 'kg' ? 5.0 : 10.0` for lower).
**How to avoid:** Block management uses **hardcoded +2.2kg upper / +4.5kg lower** per REQUIREMENTS.md BLOCK-04. These are the user's specific values. The lb equivalents would be approximately +5lb upper / +10lb lower (standard 5/3/1 increments). However, the requirements say "Out of Scope: Configurable TM increment amounts" and only specify kg values. Use +2.2/+4.5 for kg blocks.
**Warning signs:** TMs don't match user expectations after bumps.

### Pitfall 6: Banner Not Showing Without Active Block

**What goes wrong:** When there's no active block, the banner area is completely empty (no "Start a 5/3/1 block" prompt).
**Why it happens:** The `hasActiveBlock` check hides the banner entirely instead of showing the prompt state.
**How to avoid:** Always render the banner widget. When `hasActiveBlock` is false, show "Start a 5/3/1 block" prompt card. When true, show position info.
**Warning signs:** User doesn't know 5/3/1 feature exists because there's no entry point visible.

## Code Examples

### Scheme Name Helper (Add to schemes.dart)

```dart
// lib/fivethreeone/schemes.dart
// Source: Existing getSupplementalName pattern

/// Returns the main scheme type name for display
String getMainSchemeName(int cycleType) {
  switch (cycleType) {
    case cycleLeader1:
    case cycleLeader2:
      return "5's PRO";
    case cycleAnchor:
      return 'PR Sets';
    case cycleDeload:
      return '7th Week Deload';
    case cycleTmTest:
      return '7th Week TM Test';
    default:
      return '';
  }
}
```

### Settings Page Entry Point

```dart
// In settings_page.dart, add to the ListView children (between Workouts and Spotify):
// Source: Existing ListTile pattern in settings_page.dart

ListTile(
  leading: const Icon(Icons.fitness_center),
  title: const Text('5/3/1 Block'),
  onTap: () {
    showDialog(
      context: context,
      builder: (context) => const BlockCreationDialog(),
    );
  },
),
```

### Complete Week Advancement Logic

```dart
// Source: cycleWeeks and cycleBumpsTm from schemes.dart

/// Returns true if advancing past the current week requires a TM bump
bool get needsTmBump {
  final block = _activeBlock;
  if (block == null) return false;
  final maxWeeks = cycleWeeks[block.currentCycle];
  // Only bump when leaving the last week of a bump-eligible cycle
  return block.currentWeek >= maxWeeks && cycleBumpsTm[block.currentCycle];
}

/// Returns true if the block is at the very last position (TM Test, week 1)
bool get isBlockComplete {
  final block = _activeBlock;
  if (block == null) return false;
  return block.currentCycle == cycleTmTest &&
         block.currentWeek >= cycleWeeks[cycleTmTest];
}
```

### Banner Text Construction

```dart
// Source: cycleNames from schemes.dart, getMainSchemeName (new helper)

String get positionLabel {
  if (!hasActiveBlock) return '';
  final block = _activeBlock!;
  final cycleName = cycleNames[block.currentCycle];
  final schemeName = getMainSchemeName(block.currentCycle);
  return '$cycleName — Week ${block.currentWeek} • $schemeName';
  // Example: "Leader 2 — Week 2 • 5's PRO"
}
```

### Cycle Color State Helper

```dart
// Source: Standard Material 3 colorScheme usage throughout codebase

Color getCycleColor(int cycleIndex, int currentCycle, ColorScheme colorScheme) {
  if (cycleIndex < currentCycle) {
    // Completed: muted green
    return colorScheme.surfaceContainerHighest;
  } else if (cycleIndex == currentCycle) {
    // Current: accent/primary
    return colorScheme.primaryContainer;
  } else {
    // Future: dimmed grey
    return colorScheme.surfaceContainerLow;
  }
}
```

### Drift Insert Pattern for Block Creation

```dart
// Source: Generated FiveThreeOneBlocksCompanion.insert() in database.g.dart (line 5412)

await db.fiveThreeOneBlocks.insertOne(
  FiveThreeOneBlocksCompanion.insert(
    created: DateTime.now(),
    squatTm: squatTm,
    benchTm: benchTm,
    deadliftTm: deadliftTm,
    pressTm: pressTm,
    unit: unit,
    // currentCycle defaults to 0 (Leader 1)
    // currentWeek defaults to 1
    // isActive defaults to true
    // completed defaults to null
  ),
);
```

### Drift Update Pattern for TM Bump

```dart
// Source: Existing update patterns in workout_state.dart, settings writes

await (db.fiveThreeOneBlocks.update()
  ..where((b) => b.id.equals(block.id)))
  .write(FiveThreeOneBlocksCompanion(
    squatTm: Value(block.squatTm + 4.5),
    benchTm: Value(block.benchTm + 2.2),
    deadliftTm: Value(block.deadliftTm + 4.5),
    pressTm: Value(block.pressTm + 2.2),
  ));
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flutter `Stepper` widget for progress | Custom timeline from Column/Row/Container | Material 3 made Stepper more rigid | Custom gives full control over colors, layout, content |
| Single `fivethreeoneWeek` in Settings | `currentCycle` + `currentWeek` in blocks table | Phase 6 (this milestone) | Full 11-week tracking instead of 4-week cycle |
| Calculator hardcoded schemes | `schemes.dart` pure data module | Phase 6 (this milestone) | Reusable across overview page, banner, calculator |
| TM values only in Settings | TM snapshots per block + Settings | Phase 6 (this milestone) | Each block has its own TM values; Settings keeps latest for pre-fill |

**Deprecated/outdated:**
- The `fivethreeoneWeek` column in Settings (1-4 week counter) is not removed but becomes secondary when an active block exists. The calculator (Phase 8) will prefer block position over Settings week.

## Open Questions

1. **TM bump amounts for lb units**
   - What we know: Requirements specify +2.2kg upper / +4.5kg lower for kg. The existing calculator uses +5lb upper / +10lb lower for lb.
   - What's unclear: Should lb blocks use +5/+10 (standard Wendler values) or convert +2.2/+4.5 to lb (4.85/9.92)?
   - Recommendation: Use +5lb upper / +10lb lower for lb blocks (matches standard 5/3/1). The +2.2/+4.5 values are the user's specific kg increments. Standard lb increments are whole-plate-friendly.

2. **Block history view**
   - What we know: CONTEXT.md says "completed blocks kept as history (viewable later)" and "Block history view design" is Claude's Discretion.
   - What's unclear: Whether history viewing is in Phase 7 scope or deferred.
   - Recommendation: Phase 7 scope is the active block only. The `isActive = false` + `completed` fields preserve history data. A history view can be added as a simple list page later (BLOCK-08 in Future Requirements). Don't build it in Phase 7.

3. **Settings TM sync on block creation**
   - What we know: Block creation pre-fills from Settings TMs. Block stores its own TM snapshot.
   - What's unclear: Should creating a block also update Settings TMs to match? Or should they drift independently?
   - Recommendation: Block creation reads from Settings for pre-fill only. Block TMs are independent after creation. When a block's TMs bump, also update Settings TMs so the calculator (pre-Phase 8) stays in sync. This prevents confusing mismatch.

4. **"Complete Week" button position**
   - What we know: CONTEXT.md marks this as Claude's Discretion.
   - What's unclear: Should it be inside the stepper (inline with current week), in the AppBar, or as a FAB?
   - Recommendation: Place as a prominent `FilledButton` at the bottom of the overview page content (below the stepper). This is the primary action on the page. When the block is complete, show a completion message instead.

## Sources

### Primary (HIGH confidence)

- **Codebase analysis (direct file reads):**
  - `lib/database/fivethreeone_blocks.dart` -- Table definition with all columns and types
  - `lib/database/database.g.dart` (lines 5203-5450) -- Generated `FiveThreeOneBlock` data class and `FiveThreeOneBlocksCompanion` with `insert()` constructor
  - `lib/fivethreeone/fivethreeone_state.dart` -- Current state class with `refresh()`, `hasActiveBlock`, `activeBlock` getters
  - `lib/fivethreeone/schemes.dart` -- `cycleNames`, `cycleWeeks`, `cycleBumpsTm`, `getMainScheme`, `getSupplementalName`
  - `lib/widgets/training_max_editor.dart` -- Dialog layout pattern (header/content/footer), TM field construction, Settings read pattern
  - `lib/widgets/five_three_one_calculator.dart` -- TM increment values (2.5/5.0 kg), weight rounding logic, week selector UI
  - `lib/notes/notes_page.dart` -- `_TrainingMaxBanner` widget (lines 412-483), banner placement in page layout
  - `lib/settings/settings_page.dart` -- Settings ListTile entry points, `Navigator.of(context).push(MaterialPageRoute(...))` pattern
  - `lib/settings/settings_state.dart` -- `SettingsState.value` for reading TM pre-fill values
  - `lib/database/settings.dart` -- `fivethreeoneSquatTm`, `fivethreeoneBenchTm`, etc. nullable columns
  - `lib/main.dart` -- Provider tree with `FiveThreeOneState` registered
  - `.planning/REQUIREMENTS.md` -- BLOCK-01 through BLOCK-05 requirements, +2.2/+4.5 kg increments
  - `.planning/phases/07-block-management/07-CONTEXT.md` -- Locked decisions (form layout, stepper design, banner design)
  - `.planning/phases/06-data-foundation/06-01-SUMMARY.md` -- Phase 6 deliverables confirming infrastructure completeness

### Secondary (MEDIUM confidence)

- **Flutter Stepper widget assessment:** Based on Context7 Flutter docs query. Stepper exists as Material widget but has limited customization for custom colors and expandable content per step. Custom implementation recommended per codebase style.
- **Milestone research files:** `.planning/research/FEATURES.md` (TM bump values +2.2/+4.5), `.planning/research/PITFALLS.md` (increment configurability)

### Tertiary (LOW confidence)

None. All findings verified against codebase and documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero new dependencies, all patterns from existing codebase
- Architecture: HIGH -- every UI component has a direct analog in the codebase (dialog, page, banner, state methods)
- Pitfalls: HIGH -- pitfalls derived from actual codebase analysis (advancement logic, TM bump boundaries, stale state, deactivation)

**Research date:** 2026-02-11
**Valid until:** 2026-03-11 (stable -- no external dependencies, pure codebase patterns)
