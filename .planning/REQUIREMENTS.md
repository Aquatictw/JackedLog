# Requirements: v1.3 Self-Hosted Web Companion

## Milestone Requirements

### Server — Backup & Infrastructure

- [x] **SERVER-01**: Server receives SQLite backup file via POST with integrity validation (PRAGMA quick_check)
- [x] **SERVER-02**: Server lists backup history with date, file size, and DB version
- [x] **SERVER-03**: User can download any historical backup file from server
- [x] **SERVER-04**: User can delete individual backups from server
- [x] **SERVER-05**: All API endpoints authenticated via Bearer token (API key)
- [x] **SERVER-06**: Health check endpoint returns server status (GET /api/health)
- [x] **SERVER-07**: Backup management page shows total storage usage
- [x] **SERVER-08**: Server auto-cleans old backups using retention policy (GFS strategy)

### Dashboard — Web Visualizations

- [ ] **DASH-01**: Overview page shows stats cards (workout count, volume, streak, training time)
- [ ] **DASH-02**: Training heatmap displays workout frequency over time
- [ ] **DASH-03**: Muscle group volume bar chart (weight x reps by category)
- [ ] **DASH-04**: Muscle group set count chart (sets by category)
- [ ] **DASH-05**: Exercise progress charts (Best Weight, 1RM, Volume) with period selector
- [ ] **DASH-06**: Personal records display per exercise
- [ ] **DASH-07**: Rep records table (best weight at each rep count 1-15)
- [ ] **DASH-08**: Workout history list with pagination
- [ ] **DASH-09**: Workout detail view showing all sets/reps/weights
- [ ] **DASH-10**: Exercise search and category filter
- [ ] **DASH-11**: 5/3/1 block history page with TM progression over time
- [ ] **DASH-12**: Bodyweight trend chart
- [ ] **DASH-13**: Workout frequency by weekday chart
- [ ] **DASH-14**: Responsive layout (desktop sidebar, mobile hamburger menu)
- [ ] **DASH-15**: Dark/light theme toggle

### Deploy — Docker & Infrastructure

- [x] **DEPLOY-01**: Multi-stage Docker image (<50MB) with AOT-compiled Dart binary
- [x] **DEPLOY-02**: docker-compose.yml with env var config (API_KEY, PORT, DATA_DIR, MAX_BACKUPS)
- [x] **DEPLOY-03**: Persistent volume for backup data surviving container restarts

### App — Mobile Integration

- [x] **APP-01**: Server URL and API key settings fields (new Settings migration)
- [x] **APP-02**: Manual push backup button with upload progress indicator
- [x] **APP-03**: Connection test button with success/error feedback
- [x] **APP-04**: Last push timestamp and status display

## Future Requirements (Deferred)

- [ ] **DASH-F01**: Estimated 1RM leaderboard ranked across all exercises
- [ ] **DASH-F02**: CSV export from web dashboard
- [ ] **DASH-F03**: Backup diff summary (what changed between backups)
- [ ] **DEPLOY-F01**: ARM64 Docker image for Raspberry Pi
- [ ] **DEPLOY-F02**: Reverse proxy documentation (Nginx, Caddy examples)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Auto background sync | Breaks offline-first design; manual push only |
| Two-way sync / web editing | Entirely different product; dashboard is read-only |
| Multi-user support | Massive scope creep; single API key, separate containers per user |
| OAuth/SSO | Overkill for single-user self-hosted |
| Workout logging on web | Duplicates app functionality; app is the logging tool |
| Push notifications | Disproportionate complexity for self-hosted |
| WebSocket real-time updates | No data changes between backups; refresh on page load |
| Nutrition tracking | Different domain entirely |
| Progress photos on web | Privacy concerns, binary transfer complexity |

## Traceability

| REQ-ID | Phase | Plan | Status |
|--------|-------|------|--------|
| SERVER-01 | Phase 10 | 10-02 | Complete |
| SERVER-02 | Phase 10 | 10-02 | Complete |
| SERVER-03 | Phase 10 | 10-02 | Complete |
| SERVER-04 | Phase 10 | 10-02 | Complete |
| SERVER-05 | Phase 10 | 10-01 | Complete |
| SERVER-06 | Phase 10 | 10-01 | Complete |
| SERVER-07 | Phase 10 | 10-03 | Complete |
| SERVER-08 | Phase 10 | 10-02 | Complete |
| DEPLOY-01 | Phase 10 | 10-03 | Complete |
| DEPLOY-02 | Phase 10 | 10-03 | Complete |
| DEPLOY-03 | Phase 10 | 10-03 | Complete |
| APP-01 | Phase 11 | 11-01 | Complete |
| APP-02 | Phase 11 | 11-02 | Complete |
| APP-03 | Phase 11 | 11-01 | Complete |
| APP-04 | Phase 11 | 11-02 | Complete |
| DASH-01 | Phase 12 | — | Pending |
| DASH-06 | Phase 12 | — | Pending |
| DASH-07 | Phase 12 | — | Pending |
| DASH-08 | Phase 12 | — | Pending |
| DASH-09 | Phase 12 | — | Pending |
| DASH-10 | Phase 12 | — | Pending |
| DASH-02 | Phase 13 | — | Pending |
| DASH-03 | Phase 13 | — | Pending |
| DASH-04 | Phase 13 | — | Pending |
| DASH-05 | Phase 13 | — | Pending |
| DASH-14 | Phase 13 | — | Pending |
| DASH-15 | Phase 13 | — | Pending |
| DASH-11 | Phase 14 | — | Pending |
| DASH-12 | Phase 14 | — | Pending |
| DASH-13 | Phase 14 | — | Pending |

---
*30 requirements across 4 categories*
*Created: 2026-02-15*
