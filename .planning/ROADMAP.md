# Roadmap: JackedLog

## Milestones

- [x] **v1.0 UI Enhancements** - Phases 1-3 (shipped 2026-02-02)
- [ ] **v1.1 Error Handling & Stability** - Phases 4-5 (in progress)

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

### v1.1 Error Handling & Stability (In Progress)

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

## Progress

**Execution Order:** Phases execute in numeric order.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Quick Wins | v1.0 | 1/1 | Complete | 2026-02-01 |
| 2. Edit Workout | v1.0 | 2/2 | Complete | 2026-02-02 |
| 3. Notes Reorder | v1.0 | 1/1 | Complete | 2026-02-02 |
| 4. Error Handling | v1.1 | 1/1 | Complete | 2026-02-05 |
| 5. Backup Status & Stability | v1.1 | 1/1 | Complete | 2026-02-05 |

---
*Roadmap created: 2026-02-05*
*Last updated: 2026-02-05*
