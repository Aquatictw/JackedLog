# Phase 3: Notes Reorder - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Drag-drop reordering for standalone notes list with persistent sequence. Users can reorganize their notes in preferred order. Database migration required to store sequence. No new note capabilities — just reordering existing notes.

</domain>

<decisions>
## Implementation Decisions

### Drag interaction
- Long-press anywhere on note to initiate drag (no dedicated handle)
- Always available — no reorder mode toggle needed
- Instant save on drop — order persists immediately to database
- No haptic feedback during drag operations

### Reorder scope
- Applies to standalone notes list (not workout-attached notes)
- Reorder disabled when search/filter is active — only works on full list
- No pinned notes — all notes are equal and fully reorderable
- New notes appear at top of list (highest sequence number)

### Claude's Discretion
- Visual feedback during drag (lift effect, placeholder style)
- Animation timing and easing
- Database migration approach for sequence column
- Edge case handling (list boundaries, gesture conflicts)

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

*Phase: 03-notes-reorder*
*Context gathered: 2026-02-02*
