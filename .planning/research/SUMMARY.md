# Project Research Summary

**Project:** JackedLog Flutter UI Enhancements
**Domain:** Mobile fitness tracking app
**Researched:** 2026-02-02
**Confidence:** HIGH

## Executive Summary

This milestone enhances JackedLog's existing Flutter app with three UI features: drag-drop reordering for notes, editing completed workouts, and a total workout time stat card. The research confirms that **all features can be implemented using Flutter's built-in widgets and the existing architecture** (Provider + Drift + fl_chart), requiring no new dependencies beyond optional `flutter_reorderable_grid_view` for grid reordering.

The existing codebase already contains reference implementations: `start_plan_page.dart` demonstrates drag-drop reordering with database persistence, exercise editing patterns exist throughout the workout flow, and aggregation queries are established in `gym_sets.dart`. This makes the features straightforward extensions rather than architectural changes. The main implementation challenges are: (1) adding a `sequence` column to the Notes table via Drift migration, (2) creating proper edit mode isolation to avoid corrupting active workout state, and (3) maintaining timezone-consistent duration calculations.

**Key risks:** Sequence/order column sync drift (UI reorder state diverging from database), edit mode without transactional rollback (corrupting workout data), and timezone mismatches in duration calculations. All risks have established mitigation patterns in the existing codebase.

## Key Findings

### Recommended Stack

No new packages needed. All features leverage Flutter's built-in Material widgets and existing project dependencies.

**Core technologies:**
- `ReorderableListView.builder` (Flutter SDK) — Handles drag-drop list reordering with platform-specific gestures
- `ExpansionTile` (Flutter SDK) — Collapsible hierarchical data for workout editing
- `TextEditingController` — Toggle-based inline editing pattern
- Drift migrations — Adding `sequence` column to Notes table with backfill
- Custom SQL aggregation — Duration stats calculated in database for timezone safety

**Why these choices:**
- Built into Flutter SDK or already dependencies (no bloat)
- Production-ready with proper documentation
- Patterns already exist in codebase (`start_plan_page.dart` for reorder, `gym_sets.dart` for aggregation)
- Performance efficient (SQL aggregation, batch updates)

**Optional enhancement:**
- `flutter_reorderable_grid_view` package — Only if maintaining grid layout during reorder is required (current notes page uses GridView)

### Expected Features

**Must have (table stakes):**
- **Notes reordering** — Users expect ability to organize notes, long-press drag is iOS/Android standard
- **Edit workout data** — Users need to fix mistakes in historical workouts (wrong weight/reps entry)
- **Duration stat display** — Total workout time is fundamental metric for fitness tracking
- **Haptic feedback on drag** — Platform convention, confirms drag started (300-500ms long-press delay)
- **Save/cancel workflow** — Edit mode must have explicit save or discard, not auto-save that can't be undone

**Should have (competitive differentiators):**
- **Visual lift during drag** — Elevation + subtle scale (1.02-1.05x) makes item feel "grabbed"
- **Smooth reorder animation** — Items slide aside smoothly (~100ms) rather than instant swap
- **Inline set editing** — Tap field to edit directly without modal dialog (reduced friction)
- **Consistent edit UX** — Edit mode mirrors active workout page (same exercise cards, same set rows)
- **Period-sensitive stats** — Duration updates with period selector like other stats

**Defer to v2+ (scope control):**
- **Undo snackbar** — "Reordered. Undo?" after drag operation (nice-to-have polish)
- **Change history** — Tracking when workout was last edited (complex feature)
- **Comparison to previous period** — "+15% vs last month" trend indicators (separate stats feature)
- **Auto-scroll during drag** — Scrolling while dragging to reorder long lists (package handles this if needed)

**Anti-features (explicitly avoid):**
- **Drag mode toggle button** — Adds friction, use long-press like native apps
- **Always-editable fields** — Performance cost, accidental edits; toggle edit mode instead
- **Read-only historical workouts** — Users need to fix mistakes, make edits safe not impossible
- **Overly precise duration display** — "12:45:32" is clutter, "12h 45m" is clear

### Architecture Approach

The codebase follows Provider pattern for state management, Drift for database operations, and isolated page components. These features extend existing patterns rather than introducing new architecture.

**Major components:**

1. **Notes sequence migration (database layer)** — Add `sequence` INTEGER column to Notes table (schema v61→v62), backfill based on `updated DESC` order, follows exact pattern from `plan_exercises` migration v45→v46

2. **WorkoutEditPage (presentation layer)** — NEW dedicated page for editing completed workouts, isolated from WorkoutState (active workout tracking), uses draft pattern with explicit save/cancel, direct database operations without Provider state

3. **Duration aggregation queries (database layer)** — Add to `gym_sets.dart` or `workouts.dart`, SQL-based SUM(end_time - start_time) for timezone safety, stream-based for reactive UI updates with existing PeriodSelector integration

4. **Notes reorder mode (presentation layer)** — Local state pattern (not Provider), toggle between GridView (display) and ReorderableListView (reorder), batch update all sequence values on reorder complete

**Key patterns:**
- **Sequence persistence:** Update UI immediately (optimistic), batch-write to database, sync in-memory sequence values (prevents drift)
- **Edit mode isolation:** Deep copy workout data into draft, modify draft only, persist on explicit save, discard draft on cancel
- **Drift streams:** Database changes trigger UI updates automatically, no manual refresh needed
- **SQL aggregation:** Duration calculations in database avoid Dart timezone issues

### Critical Pitfalls

1. **Sequence/order column sync drift** — UI reorder state and database sequence become desynchronized. **Avoid by:** Batch updating ALL items' sequence values (not just moved item), awaiting database operations, syncing in-memory sequence values after persist. Pattern exists in `start_plan_page.dart:243-288`.

2. **Edit mode without transactional rollback** — User cancels edit but changes already persisted, corrupts workout data. **Avoid by:** Draft pattern with deep copy of workout + sets, modify draft only, persist on explicit save. PopScope wrapper to confirm exit with unsaved changes.

3. **Duration calculation timezone mismatch** — Negative durations or DST-related jumps due to mixing UTC and local times. **Avoid by:** Calculate duration in SQL using Unix epoch arithmetic (SUM(end_time - start_time)), format in Dart only for display. Never mix .toLocal() and .toUtc() in same calculation.

4. **ReorderableListView key management** — Using index as key causes "Multiple widgets used same GlobalKey" crash and wrong item animation. **Avoid by:** Use `ValueKey(note.id)` (stable database ID), never `ValueKey(index)` which changes when order changes.

5. **Drift migration column default** — Adding `sequence` column without backfill leaves existing notes with NULL or all at sequence=0. **Avoid by:** Add column with DEFAULT 0, immediately backfill with sensible order (by `updated DESC` for notes), test migration with production-like data.

## Implications for Roadmap

Based on research, suggested phase structure prioritizes low-risk, high-value features that leverage existing components, then builds to more complex features.

### Phase 1: Stats Display Foundation
**Rationale:** Simplest feature (no schema changes, no complex state), uses existing StatCard component and established aggregation patterns, delivers immediate user value.

**Delivers:** Total workout time stat card displayed on overview/history page with period selector integration.

**Addresses:**
- Must-have: Duration stat display (table stakes metric)
- Should-have: Period-sensitive calculation (matches existing stats)

**Avoids:**
- Pitfall #3: Duration timezone mismatch (use SQL SUM calculation)
- Pitfall #7: Display inconsistency (single formatting extension method)

**Implementation:** Add `getTotalWorkoutDuration()` and `watchWorkoutStats()` queries to `gym_sets.dart`, display with existing StatCard widget, integrate with PeriodSelector.

**Research flag:** Standard pattern, skip research-phase (well-documented aggregation).

### Phase 2: Workout Editing Capability
**Rationale:** High user value (fix data entry mistakes), mirrors existing workout flow UX (consistency), no schema changes required, moderate complexity with clear patterns.

**Delivers:** Edit button on WorkoutDetailPage opens WorkoutEditPage, users can modify workout name, add/remove exercises, edit set values, add/remove sets, change exercise order.

**Addresses:**
- Must-have: Edit workout data (fix mistakes)
- Must-have: Save/cancel workflow (explicit persistence control)
- Should-have: Inline editing (tap field to edit)
- Should-have: Consistent UX (mirrors start_plan_page patterns)

**Avoids:**
- Pitfall #2: Edit mode without rollback (draft pattern with deep copy)
- Pitfall #5: Nested state explosion (hierarchical state structure)
- Pitfall #9: Exit without confirmation (PopScope wrapper)

**Implementation:** Create WorkoutEditPage, reuse ExerciseSetsCard components, implement draft pattern (WorkoutDraft holds copy of data), direct database operations (no WorkoutState interaction), navigation from WorkoutDetailPage edit button.

**Research flag:** Standard pattern, skip research-phase (patterns exist in start_plan_page.dart).

### Phase 3: Notes Reordering
**Rationale:** Requires schema migration (risk), adds dependency if maintaining grid layout, lower priority than fixing workout data, builds on established patterns.

**Delivers:** User-defined note order persists across app sessions, long-press drag interaction with haptic feedback, smooth animation.

**Addresses:**
- Must-have: Notes reordering (organizational feature)
- Must-have: Haptic feedback (platform standard)
- Should-have: Visual lift during drag (polished feel)
- Should-have: Smooth animation (professional UX)

**Avoids:**
- Pitfall #1: Sequence sync drift (batch update all items, await persist)
- Pitfall #4: Key management (use ValueKey(note.id))
- Pitfall #6: Migration column default (backfill with sensible order)
- Pitfall #8: Missing haptic feedback (HapticFeedback.mediumImpact())

**Implementation:** Drift migration v61→v62 adds `sequence` column to Notes table with backfill by `updated DESC`, toggle between GridView (display) and ReorderableListView (reorder mode), follow `start_plan_page.dart` reorder pattern exactly, batch update sequences on reorder complete.

**Research flag:** Standard pattern, skip research-phase (exact pattern in start_plan_page.dart).

**Decision point:** Maintaining grid layout requires `flutter_reorderable_grid_view` package (adds dependency) or switching to list layout during reorder mode (matches existing pattern in start_plan_page.dart). **Recommend list layout toggle** for consistency.

### Phase Ordering Rationale

- **Stats first:** Zero risk (no schema changes, no complex state management), immediate value, validates duration calculation approach before edit mode needs it
- **Edit before reorder:** Higher user value (fixing mistakes vs organizing notes), no migration risk, patterns fully established in codebase
- **Reorder last:** Only feature requiring schema migration (database risk), optional package dependency decision, lower priority than data correction capability

**Dependencies identified:**
- Stats phase validates duration calculation pattern used in edit mode (duration display consistency)
- Edit mode establishes draft pattern that could be reused if notes gain more complex editing
- All phases are independent in implementation (parallel development possible if needed)

**Risk mitigation sequence:**
- Phase 1 has zero architectural risk, builds confidence
- Phase 2 highest complexity but no migration risk, gets user feedback on edit UX
- Phase 3 migration risk isolated to final phase, can defer if timeline pressure

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Stats):** Well-documented aggregation patterns exist in `gym_sets.dart`, StatCard component proven, Drift custom SQL established
- **Phase 2 (Edit):** Exact patterns in `start_plan_page.dart` for exercise editing, draft pattern is standard Flutter practice, WorkoutDetailPage navigation straightforward
- **Phase 3 (Reorder):** Reference implementation exists in `start_plan_page.dart:243-288`, Drift migration pattern proven in v45→v46, ReorderableListView officially documented

**Phases needing deeper research during planning:**
- **None** — All features have high-confidence patterns in codebase or official documentation

**Validation during implementation:**
- Phase 2: Test draft pattern with nested data (workout → exercises → sets hierarchy) to ensure memory efficient
- Phase 3: Test migration with production-like data volume, validate backfill query performance

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Built-in Flutter widgets, no new dependencies (optional grid package), existing patterns in codebase |
| Features | HIGH | UX patterns verified from official docs and competitor analysis, table stakes well-defined |
| Architecture | HIGH | Extends existing Provider + Drift architecture, reference implementations in codebase (start_plan_page.dart, gym_sets.dart) |
| Pitfalls | HIGH | Based on official docs, existing codebase analysis, and established Flutter community patterns |

**Overall confidence:** HIGH

All three features follow established patterns with reference implementations in the codebase. The main unknowns are execution details (exact widget composition, edge case handling) rather than architectural questions.

### Gaps to Address

**GridView vs ListView for reorder:**
- Notes page currently uses GridView for visual layout
- ReorderableListView is list-based (vertical scrolling)
- Options: (1) Toggle to list layout during reorder mode (matches start_plan_page pattern), (2) Add flutter_reorderable_grid_view package (new dependency)
- **Recommendation:** List layout toggle for consistency with existing patterns
- **Validation:** During Phase 3 planning, confirm with user that list layout for reorder is acceptable UX

**Edit mode component reuse:**
- start_plan_page.dart has ExerciseSetsCard and SetRow components
- Need to verify these components work when workoutId exists but workout is not active (endTime != null)
- May need `isEditMode` flag to disable timer integration
- **Validation:** During Phase 2 planning, audit component dependencies on WorkoutState

**Personal records recalculation:**
- Editing completed workout may change PR calculations (weight/reps modified)
- Existing codebase has PR cache clearing pattern
- **Validation:** During Phase 2 implementation, determine if PR recalculation needed or automatic via Drift stream

**Duration stat placement:**
- Research assumes integration with existing stats grid on overview/history page
- Need to confirm which page and exact placement
- **Validation:** During Phase 1 planning, determine StatCard location and icon choice

## Sources

### Primary (HIGH confidence)
- **JackedLog codebase** — `lib/plan/start_plan_page.dart` (reorder implementation), `lib/database/database.dart` (migration patterns), `lib/database/gym_sets.dart` (aggregation queries), `lib/workouts/workout_state.dart` (active workout management)
- [Flutter ReorderableListView API](https://api.flutter.dev/flutter/material/ReorderableListView-class.html) — Official widget documentation
- [Flutter ExpansionTile API](https://api.flutter.dev/flutter/material/ExpansionTile-class.html) — Official widget documentation
- [Drift Migration API](https://drift.simonbinder.eu/migrations/api/) — TableMigration, ALTER TABLE patterns
- [Dart DateTime class](https://api.flutter.dev/flutter/dart-core/DateTime-class.html) — Timezone handling
- [fl_chart package](https://pub.dev/packages/fl_chart) — Already dependency v1.0.0

### Secondary (MEDIUM confidence)
- [NN/g Drag-Drop UX](https://www.nngroup.com/articles/drag-drop/) — Animation timing, haptic feedback standards
- [KindaCode ReorderableListView guide](https://www.kindacode.com/article/working-with-reorderablelistview-in-flutter) — Implementation patterns
- [Medium: Mastering ExpansionTile](https://medium.com/my-technical-journey/mastering-expansiontile-in-flutter-collapsible-ui-made-easy-cec8cec3650a) — Collapsible UI patterns
- [Medium: Complex list editors](https://medium.com/flutter-senior/complex-list-editors-without-state-management-in-flutter-33408c35bac7) — Toggle-based editing patterns
- [Drift migration article](https://medium.com/@tagizada.nicat/migration-with-flutter-drift-c9e21e905eeb) — Practical migration examples

### Tertiary (LOW confidence, informational)
- [UX Pickle Duration Display](https://uxpickle.com/how-to-display-duration-hhmm-so-it-isnt-confusing/) — Format recommendations
- [Smart Interface Design Patterns](https://smart-interface-design-patterns.com/articles/drag-and-drop-ux/) — Drag-drop best practices
- [flutter_reorderable_grid_view package](https://pub.dev/packages/flutter_reorderable_grid_view) — Optional dependency for grid reordering

---
*Research completed: 2026-02-02*
*Ready for roadmap: yes*
