# Feature Research

**Domain:** Self-hosted fitness companion server + web dashboard
**Researched:** 2026-02-15
**Confidence:** HIGH

## Overview

This research covers what features a self-hosted backup server and read-only web dashboard should offer for a strength-training-focused fitness app. The analysis draws from the existing JackedLog app data model (SQLite with workouts, gym_sets, bodyweight_entries, fivethreeone_blocks, plans, metadata, notes tables), the self-hosted fitness tracker ecosystem (wger, workout-tracker, FitTrackee, Endurain), and self-hosted deployment best practices.

Key constraint: The app stays offline-first. The server is optional, single-user, and read-only. No cloud sync, no multi-user, no data entry on the web.

---

## Feature Landscape

### Table Stakes (Users Expect These)

These features are the bare minimum for a self-hosted backup + dashboard to feel worth deploying. Missing any of these makes the server feel incomplete or pointless.

#### Backup Server Features

| Feature | Why Expected | Complexity | Notes |
|---------|-------------|------------|-------|
| **Receive backup push (SQLite file)** | Core purpose of the server | Low | POST endpoint receives the .sqlite file from app. WAL checkpoint before send (app already does this in export_data.dart). |
| **Backup history list** | Users need to see what backups exist | Low | Timestamped list showing: date, file size, DB version. Sorted newest-first. |
| **Download backup** | Users must be able to retrieve their data | Low | Direct download of any historical backup file. This is the entire point of off-device backup. |
| **Delete backup** | Storage management | Low | Delete individual backups. Confirmation dialog to prevent accidents. |
| **Backup file integrity check** | Users need confidence backups are valid | Low | `PRAGMA integrity_check` on received file before accepting. Reject corrupt uploads. |
| **API key authentication** | Security for exposed endpoints | Low | Single API key via environment variable. Bearer token in Authorization header. |
| **Health check endpoint** | Docker/monitoring standard | Low | `GET /api/health` returns 200 + JSON status. Used by Docker HEALTHCHECK and monitoring tools. |
| **Storage usage display** | Users need to know disk consumption | Low | Total backup storage used, per-backup sizes. Shown on backup management page. |

#### Web Dashboard Features

| Feature | Why Expected | Complexity | Depends On |
|---------|-------------|------------|------------|
| **Workout history list** | Primary data view | Medium | Latest backup DB, workouts + gym_sets tables |
| **Workout detail view** | Users want to see individual sessions | Medium | gym_sets table joined with workouts |
| **Exercise progress charts** | Core value of a dashboard | Medium | gym_sets table, same getStrengthData() SQL logic |
| **Personal records display** | Users want to see PRs at a glance | Medium | gym_sets table, same getExerciseRecords() SQL logic |
| **Training heatmap** | Visual consistency indicator | Medium | workouts table, same as OverviewPage heatmap |
| **Overview stats** | Summary dashboard landing page | Medium | Multiple tables (workouts, gym_sets, bodyweight_entries) |
| **Muscle group volume chart** | Body part balance visualization | Medium | gym_sets.category column |
| **Period selector** | Time-scoped analysis | Low | All views (Week, Month, 3M, 6M, Year, All Time) |
| **Responsive web layout** | Must work on desktop and mobile browsers | Medium | CSS/HTML, sidebar nav on desktop, hamburger on mobile |

#### Deployment Features

| Feature | Why Expected | Complexity | Notes |
|---------|-------------|------------|-------|
| **Docker image** | Standard self-hosted deployment | Low | Single container. Dart server binary in minimal base image. |
| **docker-compose.yml example** | Users expect copy-paste deployment | Low | Working compose file with volume mounts, env vars, port mapping. |
| **Environment variable config** | Standard Docker pattern | Low | API_KEY, PORT, DATA_DIR, MAX_BACKUPS. No config files needed. |
| **Persistent volume for data** | Backups must survive container restarts | Low | Named volume or bind mount for /data directory. |

#### App-Side Features

| Feature | Why Expected | Complexity | Depends On |
|---------|-------------|------------|------------|
| **Server URL + API key settings** | Configure where to push | Low | New fields in Settings table |
| **Manual backup push button** | User-initiated backup to server | Medium | Server URL, existing backup WAL checkpoint logic |
| **Connection test** | Verify server is reachable | Low | Ping GET /api/health with API key |
| **Last push status** | Know if last push succeeded | Low | Timestamp + status in Settings table |

### Differentiators (Competitive Advantage)

Features that go beyond what basic self-hosted fitness dashboards offer. NOT required for MVP but add significant value with relatively low effort.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Rep records table** | Per-exercise best weight at each rep count (1-15). Rare in web dashboards. | Low | App already computes this via getRepRecords(). Direct SQL on backup DB. |
| **5/3/1 block history** | View completed training blocks with TM progression over time. | Medium | Unique to JackedLog. Uses fivethreeone_blocks table. No competitor has this. |
| **Bodyweight trend chart** | Track bodyweight alongside training data on a single dashboard. | Low | bodyweight_entries table. Line chart with trend line. |
| **Exercise search/filter** | Find specific exercises across all workout history. | Low | Text search + category filter on gym_sets.name. |
| **Dark/light theme toggle** | Match app's theming philosophy. | Low | CSS custom properties toggle. |
| **Estimated 1RM leaderboard** | Rank all exercises by estimated 1RM. Quick strength overview. | Low | Brzycki formula already in gym_sets.dart (ormCol). |
| **Workout frequency by weekday** | When do you train most? Bar chart of workout distribution. | Low | Simple SQL GROUP BY on workouts.startTime weekday. |
| **Backup retention policy (server-side)** | Automatic cleanup of old backups using GFS strategy. | Medium | App already implements this in auto_backup_service.dart. Port the logic. |
| **Export from server** | Download CSV/JSON from web dashboard. | Medium | Generate from backup DB. Useful for external analysis. |
| **Backup diff summary** | Show what changed between backups (new workouts, new PRs). | High | Compare two SQLite files. Impressive but complex. Defer. |
| **Muscle set count chart** | Sets per muscle group (distinct from volume chart). | Low | App already has this in OverviewPage. |

### Anti-Features (Commonly Requested, Often Problematic)

Features to deliberately NOT build. These are scope-creep traps that violate the project's constraints (offline-first, single-user, read-only dashboard, manual push).

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| **Automatic background sync** | "Server should always be up to date" | Breaks offline-first design. Requires background services, network state management, conflict resolution. Massive complexity for a manual-push model. | Manual push button. User pushes when they want to. |
| **Two-way sync / web editing** | "I want to edit workouts on the web" | Requires conflict resolution, merge strategies, real-time sync protocol. Entirely different product. | Dashboard is read-only. Edit in the app. |
| **Multi-user support** | "My partner wants their own dashboard" | Auth system, user management, role-based access, data isolation. Massive scope creep. | Single API key. Run separate containers per user. |
| **Workout logging on web** | "I want to log from my computer" | Duplicates all app functionality, requires write API, data validation, plan state management. | Read-only dashboard. The app IS the logging tool. |
| **OAuth/SSO integration** | "Sign in with Google" | Overkill for single-user self-hosted. External dependencies, token management, redirect flows. | Single API key -- simpler and more reliable. |
| **Nutrition tracking** | "wger has it" | Entirely different domain, different data model, different UI. Feature bloat. | Out of scope. Use a dedicated nutrition tool. |
| **Push notifications from server** | "Remind me to back up" | Requires push notification infrastructure (FCM/APNs). Disproportionate complexity. | App can show "last pushed X days ago" locally. |
| **Real-time WebSocket updates** | "Dashboard should update live" | No data changes between backups. WebSockets add complexity for zero benefit. | Load data on page load. Refresh button. |
| **Custom dashboard widgets/layout** | "Drag and arrange my dashboard" | Widget system, layout persistence, drag-and-drop framework. High complexity, low value for single-user. | Opinionated fixed layout that shows the right things. |
| **Companion mobile app for server** | "I want an app to view server data" | The main app already has all data locally. Second app is redundant. | Web dashboard in mobile browser. Responsive CSS. |
| **Scheduled server-initiated backups** | "Server should pull from app" | Requires app to expose a server endpoint (reverses architecture). Unreliable on mobile. | Manual push. User controls when data leaves device. |
| **Progress photo gallery** | "Show selfies on the web" | Binary file transfer, storage, image serving, privacy concerns with photos on network server. | Selfie paths exist in DB but files stay on device. |

---

## Backup Management UX

Based on analysis of backup management UIs (Proxmox, Veeam, Backblaze, ManageWP) and self-hosted patterns (Sentry, Healthchecks.io), here is what the backup management experience should look like.

### Backup List View

The primary backup management view is a simple table:

```
+------------------------------------------------------------------+
| Backups                                     Storage: 45 MB used  |
|------------------------------------------------------------------|
| Date               | Size     | DB Ver | Status |   Actions      |
|--------------------|----------|--------|--------|----------------|
| 2026-02-15 14:30   | 2.4 MB   | v65    | Valid  | Download | Del |
| 2026-02-13 09:15   | 2.3 MB   | v65    | Valid  | Download | Del |
| 2026-02-10 18:45   | 2.1 MB   | v65    | Valid  | Download | Del |
| 2026-02-05 11:00   | 1.9 MB   | v63    | Valid  | Download | Del |
+------------------------------------------------------------------+
| Active backup: 2026-02-15 14:30 (dashboard reads from this)     |
+------------------------------------------------------------------+
```

Key UX patterns:
- **Newest first** -- most relevant backup at top
- **File size visible** -- users monitor storage consumption
- **DB version shown** -- important for compatibility awareness
- **Integrity status** -- green for valid, red warning for corrupt
- **One-click download** -- direct file download, no intermediate steps
- **Delete with confirmation** -- "Are you sure? This cannot be undone."
- **Active backup indicator** -- which backup the dashboard currently reads from (always latest valid)
- **Total storage display** -- how much disk space backups consume

### Backup Upload Flow (from app)

```
[App Settings > Server] -> [Push Backup] -> Progress bar -> Success/Error toast
```

1. User taps "Push Backup" in app settings
2. App runs WAL checkpoint (already in backup service)
3. App reads DB file, shows upload progress
4. Server validates file integrity (`PRAGMA integrity_check`)
5. Server stores file with timestamp, returns success
6. App shows "Last pushed: just now" with green status
7. On failure: app shows error toast with reason

### What NOT to include in backup management:
- No "restore to app" from web (download the file, import in app instead)
- No backup scheduling on server side (app pushes, server receives)
- No backup comparison/diff in v1 (defer to differentiator)

---

## Web Dashboard Visualization Design

### What to prioritize on web vs mobile

The web dashboard's advantage over the mobile app is screen real estate. Prioritize visualizations that benefit from wider display:

1. **Overview page (landing)** -- Stats cards (workouts, volume, streak, time) + training heatmap + muscle group charts. Mirrors app's OverviewPage. Wide heatmap looks better than the cramped mobile version.

2. **Exercise detail page** -- Progress chart (Best Weight / 1RM / Volume) + period selector + personal records + rep records table. Mirrors app's StrengthPage. Wider line charts with more data points visible.

3. **Workout history** -- Paginated list with search. Click to expand full set/rep/weight details. Table format benefits from wide screen.

4. **Bodyweight page** -- Line chart with trend. Low complexity, high value.

### Visualization features mapped to existing app queries

Every dashboard visualization maps to SQL queries that already exist in the app codebase:

| Visualization | App Source | Reuse SQL? | Web Complexity |
|---------------|-----------|------------|----------------|
| Stats cards | OverviewPage._loadData() (4 queries) | Yes, identical | Low |
| Training heatmap | OverviewPage (DATE + COUNT GROUP BY) | Yes, identical | Medium (SVG grid) |
| Muscle group volume bar chart | OverviewPage (SUM weight*reps GROUP BY category) | Yes, identical | Low |
| Muscle group set count bar chart | OverviewPage (COUNT GROUP BY category) | Yes, identical | Low |
| Exercise progress line chart | getStrengthData() in gym_sets.dart | Yes, identical | Low |
| Personal records cards | getExerciseRecords() in gym_sets.dart | Yes, identical | Low |
| Rep records table | getRepRecords() in gym_sets.dart | Yes, identical | Low (HTML table) |
| Workout detail | JOIN workouts + gym_sets | Yes | Medium (nested list) |
| Bodyweight chart | SELECT from bodyweight_entries | Yes | Low |
| Exercise list | watchGraphs() aggregate query | Yes | Low |

The critical insight: **all dashboard data is read from the same SQLite DB the app uses.** The server opens the latest backup file read-only and runs the same SQL. No new data model needed. This is the simplest possible architecture.

---

## Self-Hosted Deployment Features

### What self-hosters expect

Based on analysis of popular self-hosted projects (wger, Healthchecks.io, workout-tracker, FitTrackee):

**Must have:**
1. **Single `docker-compose.yml`** -- Copy, edit 2-3 env vars, `docker compose up -d`. Done in under 5 minutes.
2. **Environment variable configuration** -- No config files. Everything via env vars.
3. **Persistent volume** -- Backup data survives container restarts/updates.
4. **Health check** -- `HEALTHCHECK` in Dockerfile pointing to `/api/health`.
5. **README with deployment instructions** -- Quick start guide.

**Nice to have (post-MVP):**
1. **ARM64 Docker image** -- For Raspberry Pi (common in self-hosting community).
2. **Reverse proxy examples** -- Nginx/Caddy snippets for HTTPS termination.

### Standard docker-compose pattern

```yaml
services:
  jackedlog-server:
    image: jackedlog/server:latest
    ports:
      - "8080:8080"
    environment:
      - API_KEY=your-secret-key-here
      - PORT=8080
      - MAX_BACKUPS=50
    volumes:
      - jackedlog-data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    restart: unless-stopped

volumes:
  jackedlog-data:
```

### Environment variables

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `API_KEY` | Yes | None (server refuses to start without it) | Authentication for all API requests |
| `PORT` | No | 8080 | Server listen port |
| `DATA_DIR` | No | /data | Backup storage directory |
| `MAX_BACKUPS` | No | 50 | Maximum retained backups (oldest deleted first) |
| `LOG_LEVEL` | No | info | Logging verbosity |

---

## Feature Dependencies

```
Server infrastructure (must come first):
  Dart server binary (Shelf/dart_frog)
  -> API key auth middleware
  -> Health check endpoint (GET /api/health)
  -> Backup endpoints:
     POST /api/backups (receive)
     GET /api/backups (list)
     GET /api/backups/:id/download
     DELETE /api/backups/:id
  -> Static file serving (web dashboard assets)
  -> Dockerfile + docker-compose.yml

Dashboard API (requires backup on disk):
  Open latest backup DB read-only
  -> GET /api/dashboard/overview (stats, heatmap data, muscle charts)
  -> GET /api/dashboard/exercises (exercise list)
  -> GET /api/dashboard/exercises/:name (progress data, PRs, rep records)
  -> GET /api/dashboard/workouts (paginated history)
  -> GET /api/dashboard/workouts/:id (detail with sets)

Web frontend (can develop with mock data):
  HTML/CSS/JS served as static files
  -> Overview page (stats cards, heatmap, muscle charts)
  -> Exercise list + detail pages (charts, PRs, rep records)
  -> Workout history + detail pages
  -> Backup management page

App-side (parallel with server):
  New Settings fields (serverUrl, serverApiKey)
  -> Connection test button (GET /api/health)
  -> Manual push button (POST /api/backups)
  -> Last push status display
```

### Critical path:
1. Server binary with API auth + backup receive endpoint
2. App settings + push button (data gets to server)
3. Dashboard API endpoints reading from backup DB
4. Web frontend rendering dashboard pages

### Parallelizable:
- Docker packaging alongside server development
- Web frontend with mock JSON while API endpoints are built
- App-side settings independently of server code

---

## MVP Definition

### MVP (v1.3.0)

**Server:**
1. Dart server binary (Shelf or dart_frog)
2. API key auth via env var (Bearer token in Authorization header)
3. `POST /api/backups` -- receive SQLite file, validate integrity, store with timestamp
4. `GET /api/backups` -- list backups (date, size, DB version)
5. `GET /api/backups/:id/download` -- download backup file
6. `DELETE /api/backups/:id` -- delete backup with confirmation
7. `GET /api/health` -- health check endpoint
8. Dashboard API endpoints (overview stats, exercises, workouts, exercise detail)
9. Static file serving for web frontend
10. Dockerfile + docker-compose.yml + env var configuration

**Dashboard:**
1. Overview page: stats cards + training heatmap + muscle group volume/set charts
2. Exercise list with search
3. Exercise detail: progress chart (Best Weight, 1RM, Volume) + period selector + PRs + rep records
4. Workout history (paginated) with expandable detail
5. Backup management page (list, download, delete, storage usage)
6. Responsive layout (desktop sidebar + mobile hamburger)
7. Dark/light theme toggle

**App:**
1. Server URL + API key fields in Data Settings
2. Test connection button (green/red status)
3. Manual push backup button with progress indicator + success/error feedback
4. Last push timestamp + status display

### Post-MVP (v1.3.x or v1.4)

- Bodyweight trend page on dashboard
- 5/3/1 block history page on dashboard
- Server-side backup retention policy (GFS cleanup, port from auto_backup_service.dart)
- Export from web dashboard (CSV download)
- Estimated 1RM leaderboard page
- Workout frequency by weekday chart
- ARM64 Docker image
- Reverse proxy documentation (Nginx, Caddy)

### Out of Scope (Never)

- Auto sync, two-way sync, multi-user, workout logging on web
- OAuth/SSO, push notifications, WebSocket updates
- Nutrition tracking, progress photos on web
- Companion mobile app for server data

---

## Feature Prioritization Matrix

| Feature | Impact | Complexity | MVP? | Rationale |
|---------|--------|------------|------|-----------|
| Backup receive endpoint | Critical | Low | Yes | Core purpose of the server |
| API key auth | Critical | Low | Yes | Security baseline |
| Backup list/download/delete | Critical | Low | Yes | Backup management essentials |
| Health check endpoint | High | Low | Yes | Docker standard, monitoring |
| Docker packaging | Critical | Low | Yes | Deployment method |
| Overview stats page | High | Medium | Yes | Landing page value |
| Training heatmap | High | Medium | Yes | Visual impact, biggest web advantage |
| Exercise progress charts | High | Medium | Yes | Core dashboard value |
| Personal records display | High | Low | Yes | Quick glance, low effort |
| Rep records table | Medium | Low | Yes | Low effort, unique value |
| Workout history + detail | High | Medium | Yes | Data exploration |
| Muscle group charts | Medium | Medium | Yes | App parity, training balance insight |
| App server settings | Critical | Low | Yes | Required for push |
| Manual push button | Critical | Medium | Yes | Data gets to server |
| Connection test | High | Low | Yes | UX validation |
| Responsive layout | Medium | Medium | Yes | Usability on all screens |
| Dark/light theme | Low | Low | Yes | Quick win, polish |
| Backup integrity check | Medium | Low | Yes | Data safety |
| Bodyweight trends | Medium | Low | No | Post-MVP, low effort when ready |
| 5/3/1 block history | Medium | Medium | No | Post-MVP differentiator |
| Server-side retention | Medium | Medium | No | Port existing logic later |
| Export from web | Low | Medium | No | Nice-to-have |
| Backup diff summary | Low | High | No | Cool but complex, defer |

---

## Sources

### Self-Hosted Fitness Trackers
- [wger - Self-hosted FLOSS fitness tracker](https://github.com/wger-project/wger) -- Full-featured, multi-user, Django-based. Reference for dashboard feature set.
- [workout-tracker - Self-hosted single binary](https://github.com/jovandeginste/workout-tracker) -- Go-based, GPX focus, API key auth pattern. Reference for simple deployment.
- [FitTrackee - Self-hosted outdoor activity tracker](https://github.com/SamR1/FitTrackee) -- Python/Flask, Docker deployment. Reference for self-hosted UX.
- [Endurain - Self-hosted fitness tracking](https://github.com/endurain-project/endurain) -- Docker-first, env var config. Reference for deployment pattern.
- [awesome-selfhosted Health and Fitness](https://awesome-selfhosted.net/tags/health-and-fitness.html) -- Ecosystem overview.

### Fitness Dashboard Visualization
- [Fito - Best Workout Data Insights](https://getfitoapp.com/en/best-workout-data-insight-and-charts-design-app/) -- Chart types for fitness dashboards.
- [Fito - Best Fitness Data Analysis](https://getfitoapp.com/en/best-fitness-data-analysis/) -- Heatmap and multi-scale view patterns.
- [Strength Journeys PR Analyzer](https://www.strengthjourneys.xyz/articles/getting-the-most-out-of-the-strength-journeys-pr-analyzer) -- PR visualization patterns.
- [FitNotes Progress Tracking](http://www.fitnotesapp.com/progress_tracking/) -- 1RM/rep record display patterns.
- [Hevy Gym Performance Tracking](https://www.hevyapp.com/features/gym-performance/) -- Strength dashboard feature set.
- [Exercise Data Visualization](https://www.numberanalytics.com/blog/exercise-data-visualization) -- Best practices for fitness charts.

### Self-Hosted Deployment Patterns
- [Docker Health Check Best Practices](https://oneuptime.com/blog/post/2026-01-30-docker-health-check-best-practices/view)
- [Docker Compose Healthchecks](https://www.furkanbaytekin.dev/blogs/software/writing-reliable-docker-healthchecks-that-actually-work)
- [Docker Secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker Environment Variables](https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables)
- [Self-hosted apps Docker guide](https://github.com/DoTheEvo/selfhosted-apps-docker)

### Backup Management UX
- [Backblaze Web UI Restore](https://www.backblaze.com/computer-backup/docs/create-a-restore-web-ui)
- [Proxmox Backup and Restore](https://pve.proxmox.com/wiki/Backup_and_Restore)
- [Sentry Self-Hosted Backup](https://develop.sentry.dev/self-hosted/backup/)

### Primary Sources (Existing JackedLog Codebase)
- `lib/graph/overview_page.dart` -- Overview stats, heatmap, muscle charts (all SQL queries reusable)
- `lib/graph/strength_page.dart` -- Exercise progress charts, PRs, rep records
- `lib/database/gym_sets.dart` -- Data model, all metric SQL queries (1RM, volume, best weight)
- `lib/backup/auto_backup_service.dart` -- Backup creation, GFS retention policy logic
- `lib/export_data.dart` -- WAL checkpoint + DB file export flow
- `lib/database/workouts.dart` -- Workout table schema
- `lib/database/bodyweight_entries.dart` -- Bodyweight table schema
- `lib/database/fivethreeone_blocks.dart` -- 5/3/1 block schema (unique data for dashboard)
