# Requirements: JackedLog

**Defined:** 2026-02-11
**Core Value:** Users can efficiently log and track their workouts with minimal friction

## v1.2 Requirements

Requirements for 5/3/1 Forever Block Programming milestone. Each maps to roadmap phases.

### Block Management

- [ ] **BLOCK-01**: User can create a new 11-week block with starting TMs for 4 lifts (Squat, Bench, Deadlift, OHP)
- [ ] **BLOCK-02**: Block overview page shows timeline of all cycles/weeks with current position highlighted
- [ ] **BLOCK-03**: User can manually advance to the next week within a cycle
- [ ] **BLOCK-04**: When advancing past a cycle (Leader 1, Leader 2, Anchor), TMs auto-bump with confirmation (+2.2kg upper, +4.5kg lower)
- [ ] **BLOCK-05**: Notes page banner shows current block position (e.g., "Leader 2 - Week 5") and navigates to block overview
- [x] **BLOCK-06**: When block completes (after TM Test), post-block summary shows TM progression across the block

### Calculator

- [x] **CALC-01**: Calculator shows correct main work scheme based on block position (5's PRO for Leader, PR Sets with AMRAP for Anchor)
- [x] **CALC-02**: Calculator shows 7th Week Deload scheme (70/80/90/100% x5,3-5,1,1)
- [x] **CALC-03**: Calculator shows 7th Week TM Test scheme (70/80/90/100% all x5) with validation warning
- [x] **CALC-04**: Calculator shows supplemental work below main sets (BBB 5x10@60% for Leader, FSL 5x5 for Anchor)

### Infrastructure

- [x] **INFRA-01**: New `fivethreeone_blocks` database table with block state (cycle, week, TMs, active status)
- [x] **INFRA-02**: `FiveThreeOneState` ChangeNotifier registered in Provider tree
- [x] **INFRA-03**: Pure `schemes.dart` module with all percentage/rep data for all cycle types

## Future Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Block Management (Enhanced)

- **BLOCK-07**: Template picker for different Leader/Anchor combinations
- **BLOCK-08**: Block history — view past completed blocks with drill-down
- **BLOCK-09**: TM history graph per lift across blocks
- **BLOCK-10**: "What's today?" auto-context calculator from exercise name

### Calculator (Enhanced)

- **CALC-05**: Plate breakdown display alongside calculated weights
- **CALC-06**: Joker sets / Beyond 5/3/1 extensions

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Auto-generated workout plans | JackedLog is a logging tool, not a plan generator. Calculator shows prescription, user logs actual performance. |
| Assistance work tracking in block system | Accessories are bodybuilding style, tracked as regular exercises |
| Scheduling / calendar integration | App has no calendar. Block tracks position, not dates. User advances manually. |
| Multiple concurrent blocks | User runs one program at a time. Single active block. |
| Automatic week detection from logged workouts | Unreliable. User might log partial weeks or train out of order. Manual advancement preferred. |
| Configurable TM increment amounts | Hardcoded +2.2kg upper / +4.5kg lower for now. Extend later if needed. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 6 | Complete |
| INFRA-02 | Phase 6 | Complete |
| INFRA-03 | Phase 6 | Complete |
| BLOCK-01 | Phase 7 | Complete |
| BLOCK-02 | Phase 7 | Complete |
| BLOCK-03 | Phase 7 | Complete |
| BLOCK-04 | Phase 7 | Complete |
| BLOCK-05 | Phase 7 | Complete |
| BLOCK-06 | Phase 9 | Complete |
| CALC-01 | Phase 8 | Complete |
| CALC-02 | Phase 8 | Complete |
| CALC-03 | Phase 8 | Complete |
| CALC-04 | Phase 8 | Complete |

**Coverage:**
- v1.2 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0

---
*Requirements defined: 2026-02-11*
*Last updated: 2026-02-11 after Phase 9 completion*
