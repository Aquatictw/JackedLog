# Phase 2: Edit Workout - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can correct mistakes in completed workouts: rename workout, add/remove/reorder exercises, edit set weight/reps/type (normal/warmup/dropset), add/delete sets, access selfie from edit panel. This phase modifies existing workout data — creating new workouts is handled by the active workout flow.

</domain>

<decisions>
## Implementation Decisions

### Edit mode entry
- Edit button (pencil icon) in app bar on workout detail page
- Transforms in-place — same screen becomes editable, no navigation
- App bar changes to show "Editing Workout" with different accent color
- Workout name editable via tappable title in app bar

### Save behavior
- Explicit save button (checkmark) in app bar — user must tap to commit
- Confirmation dialog ("Discard changes?") if user tries to leave with unsaved changes
- After save, stay on detail page in read-only view
- No undo support — save is final, user can edit again if needed

### Visual approach
- UI should look similar to active workout page when in edit mode
- Leverage existing patterns from active workout for consistency

### Claude's Discretion
- Exercise management UX (add/remove/reorder controls)
- Set editing UX (inline fields, number input approach)
- Specific styling for edit mode indicator
- Delete confirmation behavior for exercises/sets

</decisions>

<specifics>
## Specific Ideas

- "UI can look similar to active workout page" — reuse visual patterns and interactions from the existing active workout flow

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-edit-workout*
*Context gathered: 2026-02-02*
