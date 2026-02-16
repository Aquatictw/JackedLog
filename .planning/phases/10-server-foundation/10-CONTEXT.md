# Phase 10: Server Foundation - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Dart web server (Docker) that receives, validates, and stores SQLite backup files with API key authentication. Includes backup management web page, retention policy, and health check endpoint. Dashboard analytics and app-side integration are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Configuration & deployment
- API key configured via single env var (`JACKED_API_KEY`)
- Standard request logging by default: startup info + each request (method, path, status, duration)
- CORS allows all origins — self-hosted users control their own network
- All other config via env vars in docker-compose.yml (DEPLOY-02)

### Backup storage & retention
- Backup files named `jackedlog_backup_YYYY-MM-DD.db` — matches app's existing naming scheme
- Tiered retention policy with fixed defaults:
  - Keep all backups from last 7 days
  - Keep weekly backups for 30 days
  - Keep monthly backups beyond that
- No maximum storage limit — self-hosters manage their own disk space, retention handles cleanup

### Backup management page
- Server-rendered HTML page (simple, minimal styling) — not deferred to dashboard phase
- Access via URL parameter: `/manage?key=xxx` — no login form needed
- Actions available: view list, download any backup, delete individual backups
- Each backup row shows: date, file size, DB version, integrity check status (passed/failed)
- Page also shows total storage usage (SERVER-07)

### Claude's Discretion
- Default port selection
- Exact tiered retention cleanup schedule (daily cron vs on-upload check)
- Management page styling approach
- Error response format and shape
- Directory structure for stored backups

</decisions>

<specifics>
## Specific Ideas

- Backup file naming must match app pattern: `jackedlog_backup_YYYY-MM-DD.db` (from `lib/backup/auto_backup_service.dart`)
- Management page should be functional-first — no framework, just server-rendered HTML

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-server-foundation*
*Context gathered: 2026-02-15*
