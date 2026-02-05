# Requirements: JackedLog

**Defined:** 2026-02-05
**Core Value:** Users can efficiently log and track their workouts with minimal friction

## v1.1 Requirements

Requirements for Error Handling & Stability milestone. Each maps to roadmap phases.

### Error Handling

- [x] **ERR-01**: Import failures log exception type and context to console
- [x] **ERR-02**: Import failures show toast message to user with actionable description
- [x] **ERR-03**: Backup failures log specific error reason (permission, path, disk space)
- [x] **ERR-04**: Backup failures show toast notification to user

### Backup Status

- [x] **BAK-01**: Settings page shows last successful backup timestamp
- [x] **BAK-02**: Settings page shows backup status indicator (success/failed/never)

### Stability

- [x] **STB-01**: Active workout bar timer checks `mounted` before accessing context
- [x] **STB-02**: Settings initialization uses `getSingleOrNull()` with safe defaults

## Future Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Error Handling (Enhanced)

- **ERR-05**: Database migration failures logged with version context
- **ERR-06**: User-facing error page with recovery options for critical failures

### Backup (Enhanced)

- **BAK-03**: Backup verification (checksum/integrity check after backup)
- **BAK-04**: Pre-backup path validation (permission, disk space, accessibility)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Silent migration error fixes (25+ instances) | Requires careful approach, not a quick win |
| Database lifecycle management | Architectural change, beyond quick fix scope |
| Spotify token expiry enforcement | Needs careful testing, separate milestone |
| Backup path validation (SAF complexity) | Complex Android SAF edge cases, defer |
| Security hardening (token encryption) | Scope creep, separate security milestone |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ERR-01 | Phase 4 | Complete |
| ERR-02 | Phase 4 | Complete |
| ERR-03 | Phase 4 | Complete |
| ERR-04 | Phase 4 | Complete |
| BAK-01 | Phase 5 | Complete |
| BAK-02 | Phase 5 | Complete |
| STB-01 | Phase 5 | Complete |
| STB-02 | Phase 5 | Complete |

**Coverage:**
- v1.1 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0

---
*Requirements defined: 2026-02-05*
*Last updated: 2026-02-05 after phase 5 execution*
