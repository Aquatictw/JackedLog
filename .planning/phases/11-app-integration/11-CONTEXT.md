# Phase 11: App Integration - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

App can configure server connection, test connectivity, and manually push backups to the deployed server. This phase adds settings UI, a push mechanism, and status display to the existing Flutter app. The server (Phase 10) already accepts backups — this phase is the client side.

</domain>

<decisions>
## Implementation Decisions

### Settings placement & fields
- Dedicated server settings page (not inline in existing settings)
- Entry point: a "Backup Server" row in the existing settings list that navigates to the dedicated page
- Server URL: free text field with format validation (e.g., https://myserver.com)
- API key: masked field with reveal toggle (eye icon)

### Push experience
- Push button lives on the existing backup page (not on server settings page)
- Linear progress bar during upload
- No cancel support — uploads are small SQLite files, just let them finish
- After successful push: in-place status update near the button (no toast), showing "Last pushed: just now" with checkmark

### Status display
- Status area visible only on backup page, near the push button
- Shows: last push timestamp, success/failed indicator, backup file size
- Failed state: red text with error message (e.g., "Failed: Connection refused")
- Initial state before any push: shows "Never pushed" text (always visible, not hidden)

### Claude's Discretion
- Connection test UX (button style, placement, error messages)
- Exact layout and spacing of the server settings page
- How URL validation works (on blur, on save, on test)
- Error state handling for network timeouts

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-app-integration*
*Context gathered: 2026-02-15*
