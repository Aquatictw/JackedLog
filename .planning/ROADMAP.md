# Roadmap: v1.3 Self-Hosted Web Companion

## Overview

Build a self-hosted Dart web server (Docker) that receives manual backup pushes from the app and provides a read-only web dashboard for viewing workout statistics and progress. The server stores SQLite backup files and opens them in read-only mode for analytics queries.

**Phases:** 5
**Coverage:** 30/30 requirements mapped

---

## Phase 10: Server Foundation

**Goal:** Server can receive, validate, and store SQLite backup files with API key authentication in a Docker container.

**Dependencies:** None (milestone foundation)

**Requirements:**
- SERVER-01: Server receives SQLite backup file via POST with integrity validation
- SERVER-02: Server lists backup history with date, file size, and DB version
- SERVER-03: User can download any historical backup file from server
- SERVER-04: User can delete individual backups from server
- SERVER-05: All API endpoints authenticated via Bearer token (API key)
- SERVER-06: Health check endpoint returns server status
- SERVER-07: Backup management page shows total storage usage
- SERVER-08: Server auto-cleans old backups using retention policy
- DEPLOY-01: Multi-stage Docker image (<50MB) with AOT-compiled Dart binary
- DEPLOY-02: docker-compose.yml with env var config
- DEPLOY-03: Persistent volume for backup data surviving container restarts

**Success Criteria:**
1. Server receives backup file via POST /api/backup, validates checksum and SQLite integrity (PRAGMA quick_check), stores timestamped file
2. Server lists all backups with metadata (date, size, DB version) and allows download/delete via API endpoints
3. All API endpoints reject requests with missing or invalid Bearer token
4. Health check endpoint (GET /api/health) returns JSON status with server version and uptime
5. Docker container starts successfully, persists backup files across restarts, and produces <50MB final image

**Plans:** 3 plans

Plans:
- [x] 10-01-PLAN.md — Server scaffolding, config, middleware, and health check endpoint
- [x] 10-02-PLAN.md — SQLite validator, backup service, and backup API endpoints
- [x] 10-03-PLAN.md — Management page and Docker deployment files

**Status:** Complete (2026-02-15)

---

## Phase 11: App Integration

**Goal:** App can configure server connection, test connectivity, and manually push backups to the deployed server.

**Dependencies:** Phase 10 (server must accept backups)

**Requirements:**
- APP-01: Server URL and API key settings fields (new Settings migration)
- APP-02: Manual push backup button with upload progress indicator
- APP-03: Connection test button with success/error feedback
- APP-04: Last push timestamp and status display

**Success Criteria:**
1. User can enter server URL and API key in app settings page and values persist
2. Connection test button validates server is reachable and API key is correct, shows success/error toast
3. User can push backup to server with progress indicator, upload completes successfully
4. Settings page shows last push timestamp and status (success/failed/never)

**Plans:** 2 plans

Plans:
- [x] 11-01-PLAN.md — Database migration (v66) and server settings page with connection test
- [x] 11-02-PLAN.md — Backup push service and push button with status display

**Status:** Complete (2026-02-15)

---

## Phase 12: Dashboard Query Layer

**Goal:** Server can open uploaded SQLite backups in read-only mode and execute SQL queries for dashboard analytics.

**Dependencies:** Phase 10 (backups must be stored on server)

**Requirements:**
- DASH-01: Overview page shows stats cards (workout count, volume, streak, training time)
- DASH-06: Personal records display per exercise
- DASH-07: Rep records table (best weight at each rep count 1-15)
- DASH-08: Workout history list with pagination
- DASH-09: Workout detail view showing all sets/reps/weights
- DASH-10: Exercise search and category filter

**Success Criteria:**
1. Server opens latest backup file in read-only mode with sqlite3 package, validates schema version (minimum v48)
2. Server runs SQL queries replicating app patterns (gym_sets.dart) to extract workout count, total volume, current streak, and training time
3. Server queries exercise PRs (1RM, best weight, volume) and rep records (best weight at each rep count 1-15)
4. Server queries workout history with pagination (20 per page) and workout detail with joined gym_sets data
5. Server filters exercises by category and handles edge cases (hidden=0 filter, workout_id NULL, epoch timestamps)

**Plans:** 2 plans

Plans:
- [x] 12-01-PLAN.md — DashboardService core: lifecycle, overview stats, workout history/detail
- [x] 12-02-PLAN.md — Exercise queries: records, rep records, search/filter

**Status:** Complete (2026-02-15)

---

## Phase 13: Dashboard Frontend

**Goal:** Users can view workout statistics, progress charts, and workout history via read-only web dashboard.

**Dependencies:** Phase 12 (query layer must provide data)

**Requirements:**
- DASH-02: Training heatmap displays workout frequency over time
- DASH-03: Muscle group volume bar chart (weight x reps by category)
- DASH-04: Muscle group set count chart (sets by category)
- DASH-05: Exercise progress charts (Best Weight, 1RM, Volume) with period selector
- DASH-14: Responsive layout (desktop sidebar, mobile hamburger menu)
- DASH-15: Dark/light theme toggle

**Success Criteria:**
1. Dashboard overview page (/) displays stats cards, training heatmap (SVG grid), and muscle group charts with Chart.js
2. Exercise detail page shows strength progress charts (Best Weight, 1RM, Volume) with period selector (Week/Month/3M/6M/Year/All)
3. Workout history page lists workouts with pagination, workout detail page shows all sets/reps/weights
4. Layout is responsive (desktop sidebar navigation, mobile hamburger menu) and theme toggle switches between dark/light
5. All pages are server-rendered HTML with vanilla CSS/JS (no build step, no framework)

**Plans:** 3 plans

Plans:
- [x] 13-01-PLAN.md — Query layer additions, routing/auth, layout shell, and overview page
- [x] 13-02-PLAN.md — Exercise list and exercise detail pages
- [x] 13-03-PLAN.md — History list and workout detail pages

**Status:** Complete (2026-02-15)

---

## Phase 14: Dashboard Differentiators

**Goal:** Dashboard provides unique features leveraging JackedLog's specialized data model (5/3/1 blocks, bodyweight tracking).

**Dependencies:** Phase 13 (frontend must be complete)

**Requirements:**
- DASH-11: 5/3/1 block history page with TM progression over time
- DASH-12: Bodyweight trend chart
- DASH-13: Workout frequency by weekday chart

**Success Criteria:**
1. 5/3/1 block history page displays all completed blocks with start/end TMs for 4 lifts, visualizes TM progression over time
2. Bodyweight trend chart shows weight entries over time with trendline
3. Workout frequency by weekday bar chart shows distribution (Monday-Sunday)
4. All differentiator features are discoverable from dashboard navigation

**Status:** Pending

---

## Progress

| Phase | Goal | Requirements | Status |
|-------|------|--------------|--------|
| 10 - Server Foundation | Server can receive, validate, and store backups in Docker | 11 | Complete |
| 11 - App Integration | App can push backups to server | 4 | Complete |
| 12 - Dashboard Query Layer | Server can query backups for analytics | 6 | Complete |
| 13 - Dashboard Frontend | Users can view stats via web dashboard | 6 | Complete |
| 14 - Dashboard Differentiators | Dashboard shows 5/3/1 and bodyweight features | 3 | Pending |

**Total:** 30/30 requirements mapped (100% coverage)

---

*Last updated: 2026-02-15 — Phase 13 complete*
