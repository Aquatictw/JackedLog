# Roadmap: JackedLog

## Milestones

- [x] **v1.0 UI Enhancements** - Phases 1-3 (shipped 2026-02-02)
- [x] **v1.1 Error Handling & Stability** - Phases 4-5 (shipped 2026-02-05)
- [ ] **v1.2 5/3/1 Forever Block Programming** - Phases 6-9 (in progress)

## Phases

<details>
<summary>v1.0 UI Enhancements (Phases 1-3) - SHIPPED 2026-02-02</summary>

See: .planning/MILESTONES.md for details.

### Phase 1: Quick Wins
**Goal**: Add total workout time stat and clean up unused UI
**Plans**: 1 plan (complete)

### Phase 2: Edit Workout
**Goal**: Users can fully edit completed workouts
**Plans**: 2 plans (complete)

### Phase 3: Notes Reorder
**Goal**: Users can drag-drop reorder workout notes
**Plans**: 1 plan (complete)

</details>

<details>
<summary>v1.1 Error Handling & Stability (Phases 4-5) - SHIPPED 2026-02-05</summary>

**Milestone Goal:** Improve error visibility and app stability through consistent error handling patterns and async safety fixes.

#### Phase 4: Error Handling
**Goal**: Import and backup failures provide clear feedback to both developers (logs) and users (toasts)
**Depends on**: Nothing (standalone improvements)
**Requirements**: ERR-01, ERR-02, ERR-03, ERR-04
**Success Criteria** (what must be TRUE):
  1. When import fails, console shows exception type, message, and context (file path, format)
  2. When import fails, user sees toast with actionable description (not generic "Import failed")
  3. When backup fails, console shows specific error reason (permission denied, path invalid, disk full)
  4. When backup fails, user sees toast notification explaining what went wrong
**Plans**: 1 plan

Plans:
- [x] 04-01-PLAN.md — Enhanced error handling for import and backup operations

#### Phase 5: Backup Status & Stability
**Goal**: Users can see backup health at a glance; async operations are safe from context issues
**Depends on**: Phase 4 (backup error handling informs status tracking)
**Requirements**: BAK-01, BAK-02, STB-01, STB-02
**Success Criteria** (what must be TRUE):
  1. Settings page shows timestamp of last successful backup (or "Never" if none)
  2. Settings page shows backup status indicator (success/failed/never) with appropriate visual
  3. Active workout bar timer does not crash on hot reload or widget disposal
  4. Settings initialization handles missing rows gracefully without exceptions
**Plans**: 1 plan (complete)

Plans:
- [x] 05-01-PLAN.md — Backup status tracking and async stability fixes

</details>

### v1.2 5/3/1 Forever Block Programming (In Progress)

**Milestone Goal:** Add 5/3/1 Forever block programming support — users can create an 11-week training block, track their position through Leader/Anchor cycles, and get correct calculator prescriptions based on where they are in the block.

#### Phase 6: Data Foundation
**Goal**: All data infrastructure exists so block management and calculator features can build on a solid, tested foundation
**Depends on**: Nothing (new subsystem)
**Requirements**: INFRA-01, INFRA-02, INFRA-03
**Success Criteria** (what must be TRUE):
  1. `fivethreeone_blocks` table exists in the database with columns for TMs, cycle position, week position, and active status
  2. `FiveThreeOneState` ChangeNotifier is registered in the Provider tree and accessible from any widget
  3. Pure `schemes.dart` module returns correct percentage/rep schemes for all cycle types (Leader 5's PRO, Anchor PR Sets, 7th Week Deload, TM Test) and supplemental variations (BBB, FSL)
  4. Database migration from previous version succeeds without data loss; existing app data is preserved
**Plans**: 1 plan

Plans:
- [x] 06-01-PLAN.md — Database table, state management, and schemes module

#### Phase 7: Block Management
**Goal**: Users can create a training block, see where they are, and advance through the 11-week structure with correct TM progression
**Depends on**: Phase 6 (database table, state, schemes)
**Requirements**: BLOCK-01, BLOCK-02, BLOCK-03, BLOCK-04, BLOCK-05
**Success Criteria** (what must be TRUE):
  1. User can create a new block by entering starting TMs for Squat, Bench, Deadlift, and OHP, and the block starts at Leader 1, Week 1
  2. Block overview page shows a timeline of all 5 cycles (Leader 1, Leader 2, 7th Week Deload, Anchor, TM Test) with the current position visually highlighted
  3. User can tap "Complete Week" to advance to the next week; advancing past Week 3 moves to the next cycle
  4. When advancing past Leader 1, Leader 2, or Anchor cycles, TMs auto-bump (+2.2kg upper, +4.5kg lower) with a confirmation dialog before applying
  5. Notes page banner shows current block position (e.g., "Leader 2 - Week 2") and tapping it navigates to the block overview page
**Plans**: TBD

Plans:
- [ ] 07-01-PLAN.md — Block creation flow and overview page
- [ ] 07-02-PLAN.md — Week/cycle advancement and TM progression

#### Phase 8: Calculator Enhancement
**Goal**: Calculator automatically shows the correct work scheme and supplemental sets based on block position, so users see exactly what to lift today
**Depends on**: Phase 7 (block state with valid cycle/week position)
**Requirements**: CALC-01, CALC-02, CALC-03, CALC-04
**Success Criteria** (what must be TRUE):
  1. When user has an active block in Leader cycle, calculator shows 5's PRO scheme (all sets x5, no AMRAP); in Anchor cycle, calculator shows PR Sets with AMRAP on final set
  2. When block is in 7th Week Deload position, calculator shows deload scheme (70/80/90/100% at x5, x3-5, x1, x1)
  3. When block is in TM Test position, calculator shows TM Test scheme (70/80/90/100% all x5) with a validation warning if user struggles at 100%
  4. Calculator displays supplemental work section below main sets: BBB 5x10 at 60% during Leader cycles, FSL 5x5 during Anchor cycle
  5. Calculator still works in manual mode (existing behavior) when no active block exists
**Plans**: TBD

Plans:
- [ ] 08-01-PLAN.md — Context-aware calculator with scheme switching and supplemental display

#### Phase 9: Block Completion
**Goal**: When a block finishes, user sees a meaningful summary of their TM progression across the entire 11-week block
**Depends on**: Phase 8 (full block lifecycle must be functional)
**Requirements**: BLOCK-06
**Success Criteria** (what must be TRUE):
  1. When user completes the final cycle (TM Test), a post-block summary screen appears showing starting TMs vs ending TMs for all 4 lifts
  2. Summary shows total weight gained per lift across the block (e.g., "+6.6kg Squat, +4.4kg Bench")
  3. After viewing summary, the block is marked complete and user can start a new block
**Plans**: TBD

Plans:
- [ ] 09-01-PLAN.md — Post-block summary and block completion flow

## Progress

**Execution Order:** Phases execute in numeric order.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Quick Wins | v1.0 | 1/1 | Complete | 2026-02-01 |
| 2. Edit Workout | v1.0 | 2/2 | Complete | 2026-02-02 |
| 3. Notes Reorder | v1.0 | 1/1 | Complete | 2026-02-02 |
| 4. Error Handling | v1.1 | 1/1 | Complete | 2026-02-05 |
| 5. Backup Status & Stability | v1.1 | 1/1 | Complete | 2026-02-05 |
| 6. Data Foundation | v1.2 | 1/1 | Complete | 2026-02-11 |
| 7. Block Management | v1.2 | 0/2 | Not started | - |
| 8. Calculator Enhancement | v1.2 | 0/1 | Not started | - |
| 9. Block Completion | v1.2 | 0/1 | Not started | - |

---
*Roadmap created: 2026-02-05*
*Last updated: 2026-02-11 after Phase 6 completion*
