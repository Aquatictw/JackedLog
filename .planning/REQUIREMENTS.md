# Requirements: JackedLog UI Enhancements

**Defined:** 2026-02-02
**Core Value:** Users can efficiently log and track their workouts with minimal friction

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Notes

- [ ] **NOTES-01**: User can long-press and drag notes to reorder them
- [ ] **NOTES-02**: Note order persists across app restarts (database-backed sequence)

### Overview Stats

- [x] **STATS-01**: User sees total workout time card in overview (sum of durations for selected period)

### History Cleanup

- [x] **HIST-01**: Three-dots menu removed from history search bar

### Edit Workout

- [ ] **EDIT-01**: User can edit workout name from workout detail page
- [ ] **EDIT-02**: User can add exercises to completed workout
- [ ] **EDIT-03**: User can remove exercises from completed workout
- [ ] **EDIT-04**: User can reorder exercises in completed workout
- [ ] **EDIT-05**: User can edit set weight/reps in completed workout
- [ ] **EDIT-06**: User can add sets to exercises in completed workout
- [ ] **EDIT-07**: User can delete sets from exercises in completed workout
- [ ] **EDIT-08**: User can change set type (normal/warmup/dropset) in completed workout
- [ ] **EDIT-09**: Workout selfie feature accessible from edit panel (moved from top bar)

## v2 Requirements

Deferred to future milestones.

- **NOTES-03**: Drag-drop in grid layout (requires package or custom implementation)
- **EDIT-10**: Bulk edit multiple sets at once
- **STATS-02**: Average workout duration stat

## Out of Scope

Explicitly excluded for this milestone.

| Feature | Reason |
|---------|--------|
| PR recalculation on edit | Complexity — edits to historical data shouldn't retroactively change records |
| Undo/redo for edits | YAGNI — save on each action, user can re-edit if needed |
| Notes search | Not requested, keep scope tight |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| STATS-01 | Phase 1 | Complete |
| HIST-01 | Phase 1 | Complete |
| EDIT-01 | Phase 2 | Pending |
| EDIT-02 | Phase 2 | Pending |
| EDIT-03 | Phase 2 | Pending |
| EDIT-04 | Phase 2 | Pending |
| EDIT-05 | Phase 2 | Pending |
| EDIT-06 | Phase 2 | Pending |
| EDIT-07 | Phase 2 | Pending |
| EDIT-08 | Phase 2 | Pending |
| EDIT-09 | Phase 2 | Pending |
| NOTES-01 | Phase 3 | Pending |
| NOTES-02 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0

---
*Requirements defined: 2026-02-02*
*Last updated: 2026-02-02 after roadmap creation*
