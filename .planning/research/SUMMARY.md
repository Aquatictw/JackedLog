# Project Research Summary

**Project:** JackedLog v1.2 - 5/3/1 Forever Block Programming
**Domain:** Strength training periodization tracking (5/3/1 methodology)
**Researched:** 2026-02-11
**Confidence:** HIGH

## Executive Summary

The 5/3/1 Forever block programming feature transforms JackedLog from a simple 4-week cycle calculator into a full periodized program tracker. Research confirms this can be implemented with **zero new dependencies** using the existing Flutter Material 3 + Drift + Provider stack. The key architectural decision is to create a dedicated `fivethreeone_blocks` table rather than extending the already-bloated Settings table, enabling proper lifecycle management (create, advance, complete) and historical tracking without corrupting the existing calculator.

The feature requires three distinct but interconnected components: (1) a normalized database schema with proper TM snapshot management, (2) a full-page block overview with timeline visualization, and (3) context-aware calculator enhancement that switches between manual mode and block-driven mode. The existing calculator (562 lines with hardcoded 4-week scheme) must be refactored to consume data-driven percentage schemes, adding support for 5's PRO (Leader), PR Sets (Anchor), 7th Week Deload, TM Test, and supplemental work display (BBB 5x10, FSL 5x5).

Critical risks center on three areas: (1) TM progression timing (bumping at wrong cycle boundaries corrupts all subsequent weights), (2) Settings table overload (adding block state as flat columns prevents history tracking and creates denormalized mess), and (3) export/import backward compatibility (new tables must be additive, not breaking). All three are preventable with proper schema design and declarative progression rules established before any UI work begins.

## Key Findings

### Recommended Stack

**No new packages needed.** The existing stack provides everything required:

**Core technologies:**
- **Drift 2.30.0:** Database schema with reactive streams — perfect for block state management using the same ChangeNotifier + stream pattern as WorkoutState
- **Provider 6.1.1:** State propagation via FiveThreeOneState ChangeNotifier — follows existing pattern exactly
- **Flutter Material 3:** All UI built with standard widgets (Column/Row/Container for timeline, ListTile/Card for block overview) — no custom timeline packages needed

**What NOT to add:**
- Timeline packages (timelines, flutter_staggered_animations) — fixed 5-cycle layout doesn't justify dependency; custom Row+Container is 50 lines
- TM history table — progression is deterministic from block start TMs + cycle number, can be calculated not stored
- Charting additions — block progress is a 5-step bar, not a graph
- Junction tables for cycles — over-normalized; cycle state is a single integer (0-4) on block row

**Migration:** Manual v63→v64 migration adding one new table, following existing pattern from database.dart

### Expected Features

**Must have (table stakes):**
- **Block overview page** — users need to see where they are in the 11-week structure (Leader1→Leader2→Deload→Anchor→TM Test)
- **Context-aware calculator** — scheme must auto-switch based on cycle type (5's PRO for Leader, PR Sets for Anchor, Deload percentages, TM Test scheme)
- **Supplemental work display** — show BBB 5x10@60% for Leader, FSL 5x5 for Anchor below main sets in calculator
- **TM auto-progression** — bump TMs at correct boundaries (after Leader1, Leader2, and Anchor; NOT after Deload or TM Test) with user's custom increments (+2.2kg upper, +4.5kg lower)
- **Manual week/cycle advancement** — "Complete Week" button advances position; no auto-detection from workout completion
- **Block setup flow** — create new block with starting TMs

**Should have (competitive):**
- **At-a-glance block progress badge** — Notes page banner shows "Leader 2, W2" without opening block page
- **Plate breakdown integration** — calculator shows weight AND plate composition using existing PlateCalculator widget
- **Post-block summary** — completion flow showing starting vs ending TMs, total progression
- **TM Test validation warning** — prompt to reduce TM if user cannot complete 5 reps at 100% TM

**Defer (v2+):**
- TM history graph per lift — nice visualization but not essential for MVP
- Template picker — user runs one specific setup (5's PRO + BBB / Original + FSL); hardcode it
- Auto-generated workout plans — JackedLog is a logging tool, not a plan generator
- Calendar integration — user trains when they train, not on a schedule
- Multiple concurrent blocks — user runs one program at a time

### Architecture Approach

A dedicated `fivethreeone_blocks` table separates block state (which has lifecycle: create→advance→complete) from Settings (which stores preferences). The block table snapshots TMs at creation time, preventing mid-block corruption if user manually edits Settings. State management follows the exact WorkoutState pattern: FiveThreeOneState ChangeNotifier watches the active block, provides derived getters (currentCycleName, isLeader, isAnchor), and exposes actions (createBlock, advanceWeek, advanceCycle). The calculator checks for active block first; if present, uses block TMs and scheme; otherwise falls back to manual mode (existing Settings-based behavior).

**Major components:**
1. **Database layer** — `fivethreeone_blocks` table with columns: id, created, squat_tm, bench_tm, deadlift_tm, press_tm, unit, current_cycle (0-4), current_week (1-3), is_active, completed; Settings table unchanged (backward compat)
2. **State management** — `FiveThreeOneState` ChangeNotifier registered in MultiProvider; loads active block on init, provides scheme getters, handles advancement logic
3. **Block overview page** — full-screen push (not dialog) showing vertical timeline, current position, TM values per lift, advance/complete controls; replaces TrainingMaxEditor dialog as banner target
4. **Context-aware calculator** — extended `FiveThreeOneCalculator` reads FiveThreeOneState, uses data-driven schemes module, displays supplemental work section below main sets
5. **Pure schemes module** — `schemes.dart` with no UI/DB dependencies; defines SetScheme records (percentage, reps, amrap) for all cycle types and supplemental variations

**Key patterns to follow:**
- Stream-backed state with manual control (like WorkoutState, NOT auto-watching like SettingsState) — block changes are user-initiated
- Pure data schemes module — testable in isolation, reusable across calculator and overview page
- Graceful degradation — every component works when no active block exists (manual mode)

### Critical Pitfalls

1. **Settings table overload** — Adding block state as flat columns (`fivethreeone_cycle_type`, `fivethreeone_block_week`, etc.) prevents history tracking and creates denormalized mess. **Prevention:** Create normalized `fivethreeone_blocks` table; keep existing Settings columns as backward-compatible cache.

2. **TM progression timing errors** — Bumping TMs at wrong cycle boundaries (e.g., after Deload when it should not bump) compounds errors across remaining cycles. **Prevention:** Separate cycle transition from TM bump operations; define bump rules declaratively (`bumpAfterCycle` map); snapshot TMs per cycle to prevent mid-cycle corruption.

3. **Weight rounding produces unloadable plates** — Supplemental work percentages (60% for BBB, 65% for FSL) can round to weights like 67.3kg that cannot be loaded. **Prevention:** Single rounding function used everywhere; round AFTER all arithmetic, never in intermediate steps; test boundary values where percentages land between rounding targets.

4. **Migration breaks export/import compatibility** — New tables crash older app versions or get lost in CSV export. **Prevention:** New tables are additive (Settings columns preserved); database import triggers migration handler; CSV export scope unchanged (workouts/gym_sets only); affirm user per CLAUDE.md requirement.

5. **Block/workout state interaction complexity** — Three ChangeNotifiers (BlockState, WorkoutState, SettingsState) create circular update chains. **Prevention:** Unidirectional flow: user action → BlockState method → DB write → stream triggers update → UI reads from BlockState; do NOT couple workout completion to block advancement (manual only).

6. **Calculator scheme complexity** — Adding 5 different percentage schemes (5's PRO, Original, Deload, TM Test, plus supplemental variations) as switch cases creates unmaintainable 300+ line method. **Prevention:** Extract schemes into data not code; calculator consumes `List<SetScheme>` and renders, does not generate schemes.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation - Data Model & Schema
**Rationale:** Everything depends on the database schema being correct. This is pure backend work with zero UI, making it independently testable. Getting this right prevents all 4 critical pitfalls related to schema (Settings overload, migration errors, export/import breaks, hardcoded structure).

**Delivers:**
- `fivethreeone_blocks` table definition (Drift schema)
- Migration v63→v64 with proper error handling (IF NOT EXISTS)
- `FiveThreeOneState` ChangeNotifier with block lifecycle methods
- Pure `schemes.dart` module with all percentage scheme definitions
- Registration in database.dart and main.dart MultiProvider

**Addresses:**
- TS-06 (Block setup foundation)
- Database schema from STACK.md
- Data model from ARCHITECTURE.md

**Avoids:**
- Pitfall 1 (Settings table overload)
- Pitfall 4 (Migration breaks compatibility)
- Pitfall 9 (Migration error handling gaps)
- Pitfall 10 (Hardcoded block structure)

**Key decisions:**
- Snapshot TMs per block (not references to Settings)
- Single integer `current_cycle` (0-4) encodes 11-week position
- Keep existing Settings columns for backward compatibility
- Bump rules as declarative data

### Phase 2: Block Overview & Progression Logic
**Rationale:** With data layer complete, build the primary user interface for block management. This phase implements the full lifecycle (create→advance→complete) and validates the state machine handles all transitions correctly. Establishing progression logic here prevents TM timing errors before the calculator depends on it.

**Delivers:**
- `FiveThreeOnePage` with vertical timeline visualization
- Block creation flow (reusing TrainingMaxEditor for TM input)
- Manual week/cycle advancement with "Complete Week" button
- TM bump flow at correct boundaries (after Leader1, Leader2, Anchor)
- Notes page banner update to show current position and navigate to overview
- Historical blocks viewing (completed blocks with is_active=false)

**Addresses:**
- TS-01 (Block overview page)
- TS-04 (TM progression tracking)
- TS-05 (Manual advancement)
- TS-06 (Block setup/initialization)
- DF-01 (Progress badge on banner)
- DF-05 (Post-block summary)

**Uses:**
- FiveThreeOneState from Phase 1
- Schemes module for timeline labels
- Existing Material 3 widgets (no custom timeline packages)

**Implements:**
- Block overview page component from ARCHITECTURE.md
- State advancement logic

**Avoids:**
- Pitfall 2 (TM progression timing)
- Pitfall 5 (Block/workout interaction — user advances manually, NOT auto-detect)
- Pitfall 7 (Over-complex timeline UI — start with text-based status)
- Pitfall 8 (Mid-block edge cases — validate transitions, support skip/reset)

**Key decisions:**
- Full page push, not dialog (room for timeline + controls)
- Vertical timeline (mobile-friendly, no horizontal scroll)
- TM bump confirmation UI before applying
- Separate advanceWeek() and advanceCycle() operations

### Phase 3: Calculator Enhancement & Supplemental Display
**Rationale:** With block state working and progression logic validated, extend the calculator to consume block context. This is where the research effort pays off for users — correct weights at correct times. Refactoring the calculator to be data-driven prevents scheme complexity explosion.

**Delivers:**
- Context-aware calculator (reads FiveThreeOneState, switches scheme based on cycle type)
- Supplemental work section in calculator (BBB 5x10@60% for Leader, FSL 5x5 for Anchor)
- Manual mode toggle (users can still use calculator without active block)
- "What's Today?" auto-context (calculator knows which exercise, shows correct scheme immediately)
- Plate breakdown integration (reuse existing PlateCalculator widget)

**Addresses:**
- TS-02 (Context-aware calculator)
- TS-03 (Supplemental work display)
- DF-02 (Plate breakdown integration)
- DF-04 ("What's Today?" quick view)

**Uses:**
- Schemes module from Phase 1
- FiveThreeOneState from Phase 1
- Block position from Phase 2
- Existing PlateCalculator widget

**Implements:**
- Calculator context-awareness from ARCHITECTURE.md
- Supplemental work display component

**Avoids:**
- Pitfall 3 (Weight rounding — single function, round-once rule)
- Pitfall 6 (Scheme complexity — data-driven, calculator renders only)
- Pitfall 11 (FSL percentage ambiguity — derive from first set)
- Pitfall 12 (Unit switching — store unit with TM snapshot)

**Key decisions:**
- Calculator checks hasActiveBlock first, falls back to manual mode
- Supplemental section visually separated (divider + label)
- No auto-generation of GymSet entries (informational only)
- FSL percentage = first working set % (varies by week)

### Phase 4: Polish & Edge Cases
**Rationale:** Core functionality complete; this phase handles refinements that improve UX and handle edge cases discovered during testing. These are incremental improvements that don't block core feature use.

**Delivers:**
- TM Test validation warning (prompt to reduce TM if struggling with 100% x5)
- Mid-block TM adjustment flow (creates new snapshot, preserves history)
- Block abandonment (status change, not deletion)
- Skip week functionality (mark skipped, advance position)
- Reset current cycle option (fresh TM snapshots without affecting history)
- Export/import block data (add to ZIP archive, import tolerates missing files)

**Addresses:**
- DF-06 (TM Test validation warning)
- Edge cases from PITFALLS.md
- Export/import compatibility

**Avoids:**
- Pitfall 4 (Export/import breaks — additive schema, backward-compatible)
- Pitfall 8 (Mid-block state corruption — validate transitions, snapshot on adjustment)

**Key decisions:**
- CSV export unchanged (workouts/sets only)
- Database export includes new table automatically
- Import tolerates missing block data (older exports)
- TM adjustments create snapshots, do not overwrite history

### Phase Ordering Rationale

**Why data layer first:** Schema mistakes are expensive to fix after UI is built. Establishing the normalized block table prevents Settings overload pitfall and enables all subsequent features. Migration must be bulletproof — this takes time and testing.

**Why overview before calculator:** The overview page validates the state machine (create→advance→complete lifecycle) without the complexity of percentage scheme switching. If progression logic is wrong, it's caught here before the calculator depends on it.

**Why calculator last in core phases:** Calculator refactoring touches the most code (562 lines, core feature). Doing this after state management and progression logic are proven reduces risk. Data-driven schemes from Phase 1 make the refactor tractable.

**Why polish is separate:** Edge cases and export/import are refinements, not blockers. Shipping v1.2 without TM adjustment flow or block abandonment is acceptable — users can start fresh blocks. These can be added in patch releases if time runs short.

**Dependency chain:**
```
Phase 1 (Data)
  ↓
Phase 2 (Overview) ← validates state machine
  ↓
Phase 3 (Calculator) ← consumes validated block state
  ↓
Phase 4 (Polish) ← handles edge cases after core works
```

### Research Flags

Phases with well-documented patterns (skip research-phase):
- **Phase 1:** Drift table creation and migration follow exact pattern from existing codebase (database.dart lines 60-413); ChangeNotifier + Provider matches WorkoutState exactly
- **Phase 3:** Calculator refactoring is codebase-specific work, not domain research

Phases likely needing deeper research during planning:
- **Phase 2:** Timeline visualization UX — research suggests vertical over horizontal for mobile, but specific implementation details (progress indicators, completed/active/future styling) may need iteration
- **Phase 4:** Export/import for new tables — existing code only handles workouts/gym_sets CSV; adding block data to ZIP archive needs research into format compatibility

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Direct codebase analysis confirms existing stack (Drift 2.30.0, Provider 6.1.1) provides all needed capabilities; zero new dependencies required |
| Features | HIGH | User provided exact specification (11-week structure, set schemes, TM increments); verified against 5/3/1 Forever program documentation from multiple sources |
| Architecture | HIGH | Data model and state management patterns match existing codebase conventions exactly; integration points identified with file-level precision |
| Pitfalls | HIGH | Critical pitfalls (Settings overload, TM timing, rounding, migration) based on direct code analysis of existing calculator and database patterns; prevention strategies validated against codebase conventions |

**Overall confidence:** HIGH

### Gaps to Address

**7th Week scheme variations:** Research found minor inconsistencies in 7th Week Deload and TM Test rep schemes across sources. User specified exact schemes (Deload: 70%x5, 80%x3-5, 90%x1, 100%x1; TM Test: 70/80/90/100% all x5), which differ slightly from some sources that suggest 100%x3-5 for TM Test. **Resolution:** Use user's specification; this is their program preference, not a standardization requirement.

**Unit switching mid-block:** Current Settings table stores TMs without unit metadata. Storing unit alongside TM snapshot in block table prevents conversion issues, but UI flow for "user switches preferred unit mid-block" needs validation. **Resolution:** Display warning if stored TM unit doesn't match preference; offer conversion with rounding disclosure; test during Phase 4 (edge cases).

**Block template extensibility:** While hardcoding the user's specific setup (2 Leaders + Anchor with BBB/FSL) is correct for v1.2, the data model should support future template additions without schema changes. **Resolution:** Define block structure as data (BlockTemplate with List<CycleDefinition>) even though only one template is supported in v1.2; this costs minutes now, saves hours later.

**Historical block storage growth:** No performance concern identified, but should monitor. Single-active-block constraint means only 1 active row at a time; completed blocks accumulate at ~1 row per 11 weeks (4-5 blocks per year). **Resolution:** No action needed for v1.2; can add archive/cleanup in future if users request it.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis (JackedLog):**
  - `lib/database/database.dart` — migration patterns (v31-v63), schema version tracking
  - `lib/database/settings.dart` — existing 5/3/1 columns, Settings table structure
  - `lib/widgets/five_three_one_calculator.dart` — current calculator implementation, scheme logic, rounding function
  - `lib/widgets/training_max_editor.dart` — TM editor dialog
  - `lib/notes/notes_page.dart` — banner entry point, TrainingMaxBanner widget
  - `lib/settings/settings_state.dart` — ChangeNotifier + stream subscription pattern
  - `lib/workouts/workout_state.dart` — state management with async init pattern
  - `lib/main.dart` — Provider registration in appProviders()
  - `lib/export_data.dart`, `lib/import_data.dart` — export/import scope and compatibility
  - `.planning/codebase/ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`
  - `.planning/PROJECT.md` — user requirements, TM increment values, manual advancement requirement
  - `CLAUDE.md` — commit rules, backward compatibility requirement
  - `pubspec.lock` — verified Drift 2.30.0 actual installed version
- **Drift documentation:**
  - [Drift Tables Documentation](https://drift.simonbinder.eu/dart_api/tables/) — foreign keys, column types
  - [Drift Migrations Documentation](https://drift.simonbinder.eu/docs/advanced-features/migrations/) — migration patterns
- **Flutter documentation:**
  - [Flutter Stepper class](https://api.flutter.dev/flutter/material/Stepper-class.html) — evaluated and rejected for block timeline

### Secondary (MEDIUM confidence)
- **5/3/1 Forever program rules:**
  - [Lift Vault Leader/Anchor Guide](https://liftvault.com/resources/leader-anchor-cycles/) — Leader/Anchor cycle definitions
  - [The Fitness Wiki 5/3/1 Primer](https://thefitness.wiki/5-3-1-primer/) — 5/3/1 fundamentals reference
  - [Jim Wendler - The Training Max](https://www.jimwendler.com/blogs/jimwendler-com/101082310-the-training-max-what-you-need-to-know) — TM progression rules
  - [T-Nation 7th Week Protocol Discussion](https://t-nation.com/t/confusion-on-7th-week-tm-test-after-anchor/246002) — TM Test protocol details
  - [T-Nation - Increasing TM After Anchor](https://t-nation.com/t/increasing-tm-after-anchor-deload/235856) — TM bump timing
  - [T-Nation Leader/Anchor Setup](https://t-nation.com/t/doubt-about-leader-anchor-setup-in-forever/229773) — edge cases in block progression
- **Feature reference (existing 5/3/1 apps):**
  - [KeyLifts 531 App](https://www.keylifts.com/) — feature reference for 5/3/1 app capabilities
  - [Five/Three/One App](https://fivethreeone.app/) — cycle management patterns
  - [Boostcamp BBB Guide](https://www.boostcamp.app/blogs/531-boring-but-big-app-program-guide) — BBB template implementation
- **UX patterns:**
  - [UX Planet Progress Trackers](https://uxplanet.org/progress-trackers-in-ux-design-4319cef1c600) — timeline/stepper UX patterns
  - [Eleken Stepper UI Examples](https://www.eleken.co/blog-posts/stepper-ui-examples) — mobile stepper design patterns
  - [Flutter timeline packages landscape](https://fluttergems.dev/timeline/) — evaluated and rejected

### Tertiary (LOW confidence)
- [Floating-point rounding in barbell calculators](https://apps.apple.com/us/app/bar-is-loaded-gym-calculator/id1509374210) — weight rounding pitfall reference
- [Drift Migration Article](https://medium.com/@tagizada.nicat/migration-with-flutter-drift-c9e21e905eeb) — migration patterns

---
*Research completed: 2026-02-11*
*Ready for roadmap: yes*
