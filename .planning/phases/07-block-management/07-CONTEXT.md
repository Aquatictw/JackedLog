# Phase 7: Block Management - Context

**Gathered:** 2026-02-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can create a training block, see where they are in the 11-week structure, and advance through cycles with correct TM progression. Block creation, overview visualization, week/cycle advancement, TM bumps, and notes page integration are in scope. Calculator integration and block completion summary are separate phases (8 and 9).

</domain>

<decisions>
## Implementation Decisions

### Block creation flow
- Single form with all 4 TM fields (Squat, Bench, Deadlift, OHP) visible at once
- Entry point is the Settings page (within the 5/3/1 settings section)
- Pre-fill TM fields from existing settings values, but user can adjust before confirming
- One active block at a time; completed blocks kept as history (viewable later)

### Block overview visual
- Vertical stepper layout: top-to-bottom list of 5 cycles, each expanding to show weeks
- Each expanded cycle step shows: Week 1/2/3 status, scheme type name (e.g., "5's PRO", "PR Sets"), and TM values for that cycle
- Color-coded states: completed = green/muted, current = accent color/bold, future = grey/dimmed

### Notes page banner
- Card-style banner with visual weight (not just a thin bar)
- Shows cycle/week position plus scheme type: "Leader 2 — Week 2 • 5's PRO"
- Placed at top of notes page, above the notes list (first thing visible, no scrolling needed)
- Tapping the banner navigates to the block overview page
- When no active block exists, banner area shows a "Start a 5/3/1 block →" prompt linking to settings creation flow

### Claude's Discretion
- "Complete Week" button placement within the stepper layout
- TM bump confirmation dialog design
- Exact card/banner styling, spacing, and typography
- Week advancement UX details (confirmation, feedback animation)
- Block history view design

</decisions>

<specifics>
## Specific Ideas

No specific references — open to standard approaches that fit the existing app style.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-block-management*
*Context gathered: 2026-02-11*
