# Phase 1: Quick Wins - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Display total workout time stats on overview page with period selection. Remove three-dots menu from history search bar. No new features — just surface existing data and clean up UI.

</domain>

<decisions>
## Implementation Decisions

### Stats card display
- Card appears alongside existing stat cards on overview page
- Duration formatted as compact "Xh Ym" (e.g., "12h 45m")
- Card label: "Total Time"
- Zero values show as "0h 0m" (consistent display, no special empty state)

### Claude's Discretion
- Card visual styling (match existing stat cards)
- Exact placement within stats row/grid
- How period selector updates trigger recalculation
- History three-dots menu removal approach

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches matching existing codebase patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-quick-wins*
*Context gathered: 2026-02-02*
