# Phase 9: Block Completion - Context

**Gathered:** 2026-02-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Post-block summary screen and block completion flow. When user finishes the TM Test cycle, they see a summary of TM progression across the 11-week block, then the block is marked complete. Includes block history viewing and new block creation with TM carry-over.

</domain>

<decisions>
## Implementation Decisions

### Completion flow
- Summary screen appears immediately after tapping "Complete Week" on the final week of TM Test — no confirmation dialog
- No undo mechanism for block completion — keep it simple
- After viewing summary, "Done" button returns to notes page (no "Start New Block" on summary screen)
- Summary is not a one-time view — user can revisit it from block history

### Post-completion state
- Notes page banner shows "No active block" with a button to start a new block when no block is active
- Completed blocks are listed on the block overview page below the current block (or in place of it when none active)
- When starting a new block after a completed one, starting TMs pre-fill from the last block's ending TMs (user can still edit)
- Calculator falls back to manual mode (existing behavior using Settings TMs) when no active block exists

### Claude's Discretion
- Summary screen layout and visual presentation (before/after format, emphasis on gains)
- Summary content beyond TM deltas (block duration, etc.)
- Block history list styling and how much detail to show per completed block
- How the "Start New Block" interaction works from the notes banner vs block overview page

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 09-block-completion*
*Context gathered: 2026-02-11*
