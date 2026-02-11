# Phase 8: Calculator Enhancement - Context

**Gathered:** 2026-02-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Calculator automatically shows the correct work scheme and supplemental sets based on block position. Users see exactly what to lift today. Existing calculator behavior is preserved when no active block exists.

</domain>

<decisions>
## Implementation Decisions

### Scheme Display
- Header label above sets showing scheme name and block position (e.g., "5's PRO — Leader 1, Week 2")
- All sets visible at once (full list, user scrolls)
- Each set row shows weight + reps (e.g., "85kg x 5") — no percentage shown
- AMRAP sets (PR Sets in Anchor) use both '5+' notation AND a visual highlight on the row

### Supplemental Section
- Separated from main sets by a horizontal divider with label
- Label shows variation name: "BBB" or "FSL" (not generic "Supplemental")
- Compact summary format: single line like "BBB: 5 x 10 @ 60kg" (since all sets are identical)
- Hidden entirely during Deload and TM Test weeks (no supplemental those weeks)

### Mode Behavior
- Calculator is always block-aware when an active block exists — no manual toggle
- Falls back to existing behavior when no active block exists (success criterion 5)

### TM Test Feedback
- After TM Test, user can see whether their TM is correct
- When starting a new block, user gets the chance to manually enter TMs (already handled by block creation in Phase 7)

### Claude's Discretion
- Exact layout and spacing within the existing calculator page structure
- How the AMRAP highlight looks (color choice, style)
- Divider styling between main and supplemental sections
- How "TM is correct" feedback is presented

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches matching the existing calculator design.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-calculator-enhancement*
*Context gathered: 2026-02-11*
