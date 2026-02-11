# Phase 8: Calculator Enhancement - Research

**Researched:** 2026-02-11
**Domain:** Flutter UI modification — context-aware widget with Provider state consumption
**Confidence:** HIGH

## Summary

Phase 8 modifies the existing `FiveThreeOneCalculator` dialog widget to become block-aware. When an active block exists (via `FiveThreeOneState`), the calculator reads the block's cycle/week position and displays the correct scheme from `schemes.dart` instead of the hardcoded 4-week manual scheme. When no active block exists, the calculator preserves its current behavior exactly.

The infrastructure is fully in place from Phases 6 and 7. The `schemes.dart` module already has all the pure data functions (`getMainScheme`, `getSupplementalScheme`, `getMainSchemeName`, `getSupplementalName`). The `FiveThreeOneState` ChangeNotifier is already in the Provider tree with `activeBlock`, `currentCycle`, `currentWeek`, and `hasActiveBlock`. The calculator widget already has weight rounding, exercise-to-TM mapping, and set row rendering. This phase is purely a UI integration task — wiring existing data to existing UI with some display additions (header label, supplemental section, TM Test feedback).

**Primary recommendation:** Modify `FiveThreeOneCalculator` in-place. At `initState`/`_loadSettings`, check `FiveThreeOneState.hasActiveBlock`. If true, source TM from block instead of settings, source scheme from `getMainScheme()` instead of `_getWorkingSetScheme()`, disable the manual week selector, add a header label, and append a supplemental section below main sets. If false, keep all existing behavior unchanged.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Provider | 6.1.1 | Access `FiveThreeOneState` from calculator widget | Already in app, standard pattern for all state access |
| schemes.dart | N/A (internal) | All percentage/rep data for all cycle types | Built in Phase 6, pure Dart, zero dependencies, fully verified |
| FiveThreeOneState | N/A (internal) | Active block state (cycle, week, TMs) | Built in Phases 6-7, registered in Provider tree |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Flutter Material | SDK | UI components (Card, Container, Divider, etc.) | All display elements |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Modifying existing calculator | New separate block-aware calculator widget | Would duplicate weight rounding, set row rendering, exercise mapping; violates DRY. Modification is clearly better. |
| Reading FiveThreeOneState in calculator | Passing block data as constructor parameter | Would require changing all call sites and break encapsulation. Calculator should self-resolve its data source. |

## Architecture Patterns

### Recommended Approach: Dual-Mode Widget

The calculator already exists as a StatefulWidget dialog. Add a second data source path:

```
FiveThreeOneCalculator
├── initState() → _loadSettings()
│   ├── Check FiveThreeOneState.hasActiveBlock
│   ├── YES → source TM from block, scheme from getMainScheme()
│   └── NO  → source TM from settings, scheme from _getWorkingSetScheme() (existing)
├── build()
│   ├── Block mode: show header label, hide week selector, show supplemental
│   └── Manual mode: show week selector, no supplemental (existing)
```

### Pattern 1: Block-Aware Data Resolution
**What:** At load time, check `FiveThreeOneState` for an active block. If present, pull TM from the block (by exercise key) and set cycle/week from block state. If absent, keep existing settings-based behavior.
**When to use:** In `_loadSettings()` method.
**Key insight:** The `_getExerciseKey()` method already maps exercise names to keys (squat, bench, deadlift, press). The block has corresponding fields (`squatTm`, `benchTm`, `deadliftTm`, `pressTm`). Same mapping, different data source.

### Pattern 2: Scheme Delegation
**What:** Replace `_getWorkingSetScheme()` with `getMainScheme()` from schemes.dart when in block mode.
**When to use:** In `build()` when computing the set list.
**Key insight:** The existing `_getWorkingSetScheme()` returns `List<({double percentage, int reps, bool amrap})>` which is exactly the `SetScheme` typedef in schemes.dart. They are structurally identical. The schemes.dart functions use the same record type.

### Pattern 3: Supplemental Section as Conditional Widget
**What:** Below main sets, conditionally render a supplemental section with divider and label.
**When to use:** In `build()`, after the main sets list, only when in block mode AND supplemental scheme is non-empty.
**Key insight:** CONTEXT.md specifies compact summary format: "BBB: 5 x 10 @ 60kg" as a single line. Since all supplemental sets are identical weight/reps, no need to render individual rows.

### Anti-Patterns to Avoid
- **Duplicating scheme data:** The existing `_getWorkingSetScheme()` hardcodes percentages that are already in `schemes.dart`. In block mode, use `getMainScheme()` exclusively. Do NOT create new scheme data.
- **Creating a separate widget:** Reuse the existing calculator dialog. Do NOT create `BlockAwareCalculator` as a new class.
- **Removing manual mode:** The existing 4-week manual mode must be preserved for users without an active block. Do NOT delete `_getWorkingSetScheme()` or the week selector.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Percentage/rep schemes | New const maps in calculator | `getMainScheme()` from schemes.dart | Already verified correct for all cycle types in Phase 6 |
| Supplemental scheme data | New BBB/FSL data in calculator | `getSupplementalScheme()` from schemes.dart | Handles FSL week-varying percentages correctly |
| Scheme name display text | String literals in calculator | `getMainSchemeName()` and `getSupplementalName()` from schemes.dart | Consistent naming across block overview and calculator |
| Active block detection | Manual DB query in calculator | `context.read<FiveThreeOneState>()` | Already loaded, already in Provider tree |
| Weight rounding | New rounding logic | Existing `_calculateWeight()` in calculator | Already handles kg (2.5) and lb (5.0) rounding |
| Exercise-to-TM mapping | New mapping logic | Existing `_getExerciseKey()` in calculator | Already maps exercise names to squat/bench/deadlift/press keys |

**Key insight:** Nearly every building block already exists. This phase is primarily a wiring/layout task.

## Common Pitfalls

### Pitfall 1: Breaking Manual Mode
**What goes wrong:** Modifying `_loadSettings()` or `build()` in a way that breaks the no-block path.
**Why it happens:** Getting focused on block-aware features and not testing the fallback.
**How to avoid:** Use an `_isBlockMode` boolean flag set once during `_loadSettings()`. All conditional UI branches check this flag. Manual mode code paths remain untouched behind `if (!_isBlockMode)`.
**Warning signs:** Week selector stops appearing when no block exists.

### Pitfall 2: TM Source Confusion
**What goes wrong:** In block mode, TM comes from the block table. In manual mode, TM comes from the settings table. Mixing these up causes wrong weights.
**Why it happens:** Both data sources have fields named the same way (squatTm, etc.).
**How to avoid:** Set `_trainingMax` to the correct source based on `_isBlockMode` during `_loadSettings()`. After that, all weight calculation uses `_trainingMax` regardless of source.
**Warning signs:** Calculator shows different weight than block overview TM card.

### Pitfall 3: TM TextField Editability in Block Mode
**What goes wrong:** In block mode, the TM comes from the block. If the user can edit the TM text field, they might expect it to change the block's TM, but the calculator shouldn't modify block data (that's block management's job).
**Why it happens:** The existing TM TextField has `onChanged: (_) => _saveTrainingMax()` which writes to settings.
**How to avoid:** In block mode, make the TM display read-only (disable the text field or show it as a label instead of a text field). The TM value comes from the block and should not be editable within the calculator.
**Warning signs:** User edits TM in calculator during block mode, block overview still shows old TM.

### Pitfall 4: Deload/TM Test Reps Display
**What goes wrong:** The deload scheme has 4 sets with varying reps (5, 5, 1, 1). The TM Test has 4 sets all x5. These differ from the 3-set structure of Leader/Anchor weeks.
**Why it happens:** Assuming all schemes have exactly 3 sets.
**How to avoid:** The set list rendering already uses `scheme.asMap().entries.map()` which handles any number of sets. Just ensure the list is scrollable (already in a `SingleChildScrollView`).
**Warning signs:** Missing 4th set in deload/TM Test view.

### Pitfall 5: Supplemental Section During Deload/TM Test
**What goes wrong:** Showing supplemental sets during deload or TM Test weeks when there should be none.
**Why it happens:** Not checking `getSupplementalScheme()` return value.
**How to avoid:** `getSupplementalScheme()` already returns `[]` for deload and TM Test cycles. The supplemental section should be hidden when the scheme list is empty. CONTEXT.md confirms: "Hidden entirely during Deload and TM Test weeks."
**Warning signs:** Supplemental section label appears with no sets during deload week.

### Pitfall 6: Week Selector Visibility in Block Mode
**What goes wrong:** Showing the manual week selector (SegmentedButton) when in block mode, confusing the user about which week they're on.
**Why it happens:** Not hiding the week selector UI.
**How to avoid:** In block mode, replace the week selector with the header label showing scheme name and block position.
**Warning signs:** Two conflicting week indicators visible simultaneously.

## Code Examples

### Block Mode Detection at Load Time
```dart
// In _loadSettings():
final fiveThreeOneState = context.read<FiveThreeOneState>();
_isBlockMode = fiveThreeOneState.hasActiveBlock;

if (_isBlockMode) {
  final block = fiveThreeOneState.activeBlock!;
  _blockCycleType = block.currentCycle;
  _blockWeek = block.currentWeek;
  _unit = block.unit;

  // Source TM from block instead of settings
  final exerciseKey = _getExerciseKey();
  switch (exerciseKey) {
    case 'squat': _trainingMax = block.squatTm;
    case 'bench': _trainingMax = block.benchTm;
    case 'deadlift': _trainingMax = block.deadliftTm;
    case 'press': _trainingMax = block.pressTm;
  }
  if (_trainingMax != null) {
    _tmController.text = _trainingMax!.toStringAsFixed(1);
  }
} else {
  // Existing settings-based code path (unchanged)
  ...
}
```
Source: Codebase analysis of existing `_loadSettings()` and `FiveThreeOneState`

### Scheme Resolution in Block Mode
```dart
// Replace _getWorkingSetScheme() call in build():
List<SetScheme> scheme;
if (_isBlockMode) {
  scheme = getMainScheme(cycleType: _blockCycleType, week: _blockWeek);
} else {
  scheme = _getWorkingSetScheme(); // existing manual mode
}
```
Source: Codebase analysis of existing `build()` and `schemes.dart` API

### Header Label in Block Mode
```dart
// Instead of week selector, show block position:
if (_isBlockMode) ...[
  Text(
    "${getMainSchemeName(_blockCycleType)} — ${cycleNames[_blockCycleType]}, Week $_blockWeek",
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    ),
  ),
] else ...[
  // Existing SegmentedButton week selector
  SegmentedButton<int>(...),
]
```
Source: CONTEXT.md decision: "Header label above sets showing scheme name and block position"

### Supplemental Section
```dart
// After main sets, conditionally show supplemental:
if (_isBlockMode) ...[
  final supplemental = getSupplementalScheme(
    cycleType: _blockCycleType,
    week: _blockWeek,
  );
  if (supplemental.isNotEmpty) ...[
    const SizedBox(height: 16),
    Divider(color: colorScheme.outlineVariant),
    const SizedBox(height: 8),
    // Compact summary: "BBB: 5 x 10 @ 60kg"
    final weight = _calculateWeight(supplemental.first.percentage);
    final name = getSupplementalName(_blockCycleType);
    Text(
      '$name: ${supplemental.length} x ${supplemental.first.reps} @ ${weight.toStringAsFixed(1)} $_unit',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  ],
]
```
Source: CONTEXT.md decision: "Compact summary format: single line like 'BBB: 5 x 10 @ 60kg'"

### TM Test Feedback
```dart
// In block mode when cycleType is cycleTmTest:
if (_isBlockMode && _blockCycleType == cycleTmTest) ...[
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: colorScheme.onTertiaryContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'You should be able to get 5 strong reps at 100%. If not, lower your TM.',
            style: TextStyle(color: colorScheme.onTertiaryContainer),
          ),
        ),
      ],
    ),
  ),
]
```
Source: CONTEXT.md decision on TM Test feedback + CALC-03 requirement

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded 4-week scheme in calculator | Pure scheme module (schemes.dart) consumed by calculator | Phase 6 (2026-02-11) | Calculator can now display any cycle type's scheme |
| TM stored only in settings table | TM stored in block table per active block | Phase 6-7 (2026-02-11) | Calculator can source TM from block instead of settings |
| Manual week selection only | Block position auto-detected from FiveThreeOneState | Phase 7 (2026-02-11) | Calculator can show correct scheme without user selecting week |

**Note:** The existing manual mode with settings-stored TMs and `_getWorkingSetScheme()` must be preserved as the fallback. It is NOT deprecated.

## Open Questions

1. **Progress Cycle button behavior in block mode**
   - What we know: The manual mode has a "Complete Cycle & Increase TM" button at week 4. In block mode, week advancement is handled via `BlockOverviewPage`.
   - What's unclear: Should the progress cycle button appear in block mode?
   - Recommendation: Hide it in block mode. Block advancement is the responsibility of the block overview page, not the calculator. This prevents conflicting state modifications.

2. **Saving TM to settings in block mode**
   - What we know: In manual mode, typing in the TM text field calls `_saveTrainingMax()` which writes to the settings table.
   - What's unclear: In block mode, the TM text field should be read-only. But should we also sync the block TM to settings?
   - Recommendation: No. In block mode, make the TM field read-only. The block is the single source of truth. Settings TMs are only for manual mode.

3. **AMRAP highlight specifics**
   - What we know: CONTEXT.md says Claude's discretion for "How the AMRAP highlight looks (color choice, style)."
   - Recommendation: Keep the existing AMRAP styling (primary-colored border + primary container background on the set number circle). It already works well and matches the existing PR Sets look.

## Sources

### Primary (HIGH confidence)
- `lib/widgets/five_three_one_calculator.dart` — existing calculator widget (561 lines), full read
- `lib/fivethreeone/schemes.dart` — scheme data module (170 lines), full read
- `lib/fivethreeone/fivethreeone_state.dart` — block state (149 lines), full read
- `lib/database/fivethreeone_blocks.dart` — block table schema (20 lines), full read
- `lib/fivethreeone/block_overview_page.dart` — block overview page (434 lines), full read
- `lib/fivethreeone/block_creation_dialog.dart` — block creation dialog (267 lines), full read
- `lib/plan/exercise_sets_card.dart` — calculator invocation site (lines 261-369), partial read
- `lib/main.dart` — Provider tree registration (lines 1-62), partial read
- `.planning/phases/06-data-foundation/06-VERIFICATION.md` — Phase 6 verification (179 lines)
- `.planning/phases/07-block-management/VERIFICATION.md` — Phase 7 verification (99 lines)
- `.planning/phases/08-calculator-enhancement/08-CONTEXT.md` — User decisions (62 lines)
- `.planning/codebase/ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`, `STACK.md` — codebase docs

### Secondary (MEDIUM confidence)
None needed — all research is based on direct codebase analysis.

### Tertiary (LOW confidence)
None — no external research needed for this phase. All infrastructure is internal.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components already exist in the codebase, verified in Phase 6-7
- Architecture: HIGH — dual-mode pattern is a straightforward conditional branch in an existing widget
- Pitfalls: HIGH — identified from direct code analysis of existing data flows and state management

**Research date:** 2026-02-11
**Valid until:** 2026-03-11 (stable — internal codebase, no external dependencies changing)
