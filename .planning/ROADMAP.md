# Roadmap: JackedLog UI Enhancements

## Overview

This milestone delivers three user-facing improvements to JackedLog: a total workout time statistic, the ability to edit completed workouts, and drag-drop reordering for notes. Phases are ordered by risk — quick wins first (no schema changes), edit functionality second (high value, established patterns), and notes reorder last (requires database migration). All features leverage existing codebase patterns from `start_plan_page.dart` and `gym_sets.dart`.

## Phases

- [x] **Phase 1: Quick Wins** - Stats card and history cleanup
- [x] **Phase 2: Edit Workout** - Full editing capability for completed workouts
- [x] **Phase 3: Notes Reorder** - Drag-drop with persistent sequence

## Phase Details

### Phase 1: Quick Wins
**Goal**: Users see total workout time stats and have a cleaner history UI
**Depends on**: Nothing (first phase)
**Requirements**: STATS-01, HIST-01
**Success Criteria** (what must be TRUE):
  1. User sees total workout time card on overview page showing accumulated duration for selected period
  2. Duration updates when user changes period selector (week/month/year)
  3. Three-dots menu no longer appears in history search bar
**Plans**: 1 plan

Plans:
- [x] 01-01-PLAN.md — Total time stat card and history menu cleanup

### Phase 2: Edit Workout
**Goal**: Users can correct mistakes in completed workouts
**Depends on**: Phase 1
**Requirements**: EDIT-01, EDIT-02, EDIT-03, EDIT-04, EDIT-05, EDIT-06, EDIT-07, EDIT-08, EDIT-09
**Success Criteria** (what must be TRUE):
  1. User can open edit mode from workout detail page and rename the workout
  2. User can add, remove, and reorder exercises within a completed workout
  3. User can edit set weight, reps, and type (normal/warmup/dropset) in a completed workout
  4. User can add and delete sets within exercises in a completed workout
  5. User can access selfie feature from edit panel instead of top bar
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — Edit mode foundation (toggle, name editing, exercise add/remove/reorder)
- [x] 02-02-PLAN.md — Set editing (weight/reps/type/add/delete) and selfie relocation

### Phase 3: Notes Reorder
**Goal**: Users can organize notes in their preferred order
**Depends on**: Phase 2
**Requirements**: NOTES-01, NOTES-02
**Success Criteria** (what must be TRUE):
  1. User can long-press and drag notes to reorder them
  2. Note order persists after app restart (database-backed sequence)
  3. Reorder provides haptic feedback and visual lift during drag
**Plans**: 1 plan

Plans:
- [x] 03-01-PLAN.md — Notes sequence migration and reorder UI

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Quick Wins | 1/1 | ✓ Complete | 2026-02-02 |
| 2. Edit Workout | 2/2 | ✓ Complete | 2026-02-02 |
| 3. Notes Reorder | 1/1 | ✓ Complete | 2026-02-02 |

---
*Roadmap created: 2026-02-02*
*Coverage: 13/13 v1 requirements mapped*
