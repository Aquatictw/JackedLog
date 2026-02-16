# Project Research Summary

**Project:** JackedLog v1.3 - Self-Hosted Web Companion
**Domain:** Self-hosted Dart server + web dashboard for fitness tracking
**Researched:** 2026-02-15
**Confidence:** HIGH

## Executive Summary

The v1.3 self-hosted web companion should be built as a separate Dart server project (monorepo workspace) packaged as a Docker container. The server receives SQLite database backup files via manual push from the Flutter app, stores them, and serves a read-only web dashboard for viewing workout statistics and progress graphs. The recommended architecture is Shelf (official Dart HTTP server) with raw sqlite3 database access (no Drift on server) and vanilla HTML/CSS/JS with Chart.js for the dashboard frontend.

The critical architectural decision is to avoid using Drift ORM on the server. The server should open uploaded SQLite files directly with the sqlite3 package in read-only mode and run raw SQL queries. This decouples the server from the app's complex 65-version migration history and prevents accidental backup file modification. All SQL query patterns already exist in the app codebase (lib/database/gym_sets.dart) and can be replicated on the server with minimal adaptation.

The top risks are SQLite WAL corruption during backup upload, schema version mismatch handling, and Docker packaging complexity (sqlite3 v3 build hooks + scratch image). These are all mitigable with careful implementation: WAL checkpoint before upload (existing pattern), read-only database opening with version checks, and multi-stage Docker builds. The server feature is entirely optional -- if both server_url and server_api_key settings are null, no server UI appears in the app.

## Key Findings

### Recommended Stack

The stack is pure Dart end-to-end: Shelf 1.4.2 for the HTTP server, sqlite3 3.1.5 for direct database access, and vanilla web technologies for the dashboard. No JavaScript framework, no Node.js build toolchain, no separate SPA.

**Core technologies:**
- **Shelf 1.4.2** (HTTP server) — Official Dart team package with composable middleware. Mature and stable (20 months since last release). Every other Dart framework wraps Shelf anyway.
- **sqlite3 3.1.5** (database access) — Pure Dart bindings via dart:ffi. Version 3.x uses build hooks to bundle SQLite natively, eliminating Docker runtime dependency issues.
- **Vanilla HTML/CSS/JS + Chart.js 4.5.1** (dashboard) — No build step, no node_modules. For a read-only dashboard with ~5 pages, a framework is overkill. Chart.js is the most popular lightweight charting library.
- **Docker (dart:stable + scratch)** — Multi-stage build produces ~10-15MB final image. AOT-compiled Dart binary with bundled SQLite.
- **API key authentication** (custom middleware) — Single-user self-hosted app. ~20 lines of middleware. SHA-256 hashed storage with Bearer token header.

**Why NOT dart_frog:** Adds abstraction layer, custom build step, community-maintained since July 2025. Shelf is simpler for 5 endpoints.

**Why NOT Drift on server:** Would require duplicating 9 table definitions, build_runner codegen, and keeping server schema in sync with app schema v65+. Read-only queries don't need ORM.

**Why NOT React/Vue/Svelte:** Adds Node.js build pipeline, increases Docker complexity, overkill for read-only data display.

### Expected Features

The research identified clear table stakes vs. differentiators based on self-hosted fitness tracker ecosystem analysis (wger, workout-tracker, FitTrackee).

**Must have (table stakes):**
- Receive backup push (SQLite file) with integrity check
- Backup history list with download/delete
- API key authentication for endpoints
- Health check endpoint (Docker standard)
- Overview dashboard with stats cards + training heatmap
- Exercise progress charts (Best Weight, 1RM, Volume) with period selector
- Personal records display and rep records table
- Workout history with detail view
- Docker image + docker-compose.yml with env var config
- App-side: server URL/API key settings + manual push button + connection test

**Should have (competitive differentiators):**
- 5/3/1 block history (unique to JackedLog, no competitor has this)
- Rep records table (per-exercise best weight at each rep count 1-15)
- Bodyweight trend chart alongside training data
- Estimated 1RM leaderboard ranked across all exercises
- Workout frequency by weekday bar chart
- Dark/light theme toggle
- Server-side backup retention policy (GFS strategy from auto_backup_service.dart)

**Defer (v2+ or never):**
- Automatic background sync (violates offline-first principle)
- Two-way sync / web editing (entirely different product)
- Multi-user support (massive scope creep)
- OAuth/SSO (overkill for single-user)
- Nutrition tracking (feature bloat)

### Architecture Approach

The architecture is a monorepo with Pub workspaces: the server is a separate Dart package (server/pubspec.yaml) with its own dependency tree, independent of Flutter. The server stores backup files as-is on disk (/data/backups/) with timestamped filenames and opens the latest backup in read-only mode for dashboard queries.

**Major components:**
1. **Shelf HTTP server** — Entry point (bin/server.dart) with middleware pipeline (logging, API key auth, routing). Serves both API endpoints and static web assets.
2. **BackupStore** — Manages backup file storage, lists backups with metadata (date, size, DB version), handles upload/download/delete.
3. **BackupDatabase** — Opens uploaded SQLite file in read-only mode (sqlite3 package), runs raw SQL queries for dashboard data. Lazy-loaded and cached per backup.
4. **Dashboard routes** — Server-rendered HTML using Dart string interpolation. No template engine for MVP (5-6 pages). Serves static CSS/JS from server/web/.
5. **API routes** — JSON endpoints for backup upload (POST /api/backup), backup list/download/delete, health check, dashboard data.
6. **App integration** — New Settings table columns (server_url, server_api_key), new ServerSettingsPage, new ServerPushService using existing http package.

**Data flow:** App -> WAL checkpoint -> read SQLite file -> POST /api/backup with Bearer token -> Server validates checksum + integrity -> Store timestamped file -> Dashboard opens latest backup read-only -> Run SQL queries -> Render HTML/JSON.

**Key pattern:** Server reads data, never writes. Opens backup files with `sqlite3.open(path, mode: OpenMode.readOnly)` to prevent accidental modification. Each upload creates a new timestamped file; "latest" determined by filename sorting.

### Critical Pitfalls

Based on codebase analysis and verified research, five critical pitfalls must be addressed in Phase 10:

1. **SQLite WAL corruption during backup upload** — The app uses WAL mode (3 files: .sqlite, .sqlite-wal, .sqlite-shm). Copying the main file without checkpointing first loses uncommitted data or creates corrupt backups. **Mitigation:** Reuse existing PRAGMA wal_checkpoint(TRUNCATE) pattern from export_data.dart:158-159 before reading DB file for upload. Validate on server with PRAGMA quick_check before accepting.

2. **Schema version mismatch** — App has 65 schema versions. Server opening a v63 backup with Drift would trigger migration (modifying the file). Opening a v66 backup would fail (unknown version). **Mitigation:** Use raw sqlite3 package, not Drift. Open read-only. Check PRAGMA user_version and handle gracefully (minimum supported version: 48).

3. **Backup file corruption during HTTP transfer** — Network interruption can produce truncated files that appear valid (have SQLite header) but are missing pages. **Mitigation:** SHA-256 checksum on client, verify on server. Never overwrite previous backup until new one passes integrity check. Reasonable timeout (5 minutes for 20MB file).

4. **API key security** — Plaintext storage or HTTP transmission exposes all backup data. **Mitigation:** Generate strong random key on first run, store as SHA-256 hash, use constant-time comparison. Support Docker secrets. Document HTTPS as strongly recommended (Caddy example).

5. **Docker image missing SQLite native library** — Dart sqlite3 package uses dart:ffi to load libsqlite3.so at runtime. FROM scratch image has no system libraries. **Mitigation:** Multi-stage build copies libsqlite3.so from build image to runtime, or rely on sqlite3 v3 build hooks to bundle SQLite. Test on both amd64 and arm64.

**Additional gotchas:** Always filter `WHERE hidden = 0` on gym_sets queries (template rows). Handle workout_id = NULL (pre-v48 data). Timestamps are epoch seconds, not milliseconds. Timezone handling (app uses 'localtime', server likely runs UTC). The notes table is standalone notes, not workout notes.

## Implications for Roadmap

Based on research, the roadmap should have 5 phases starting from Phase 10 (previous milestone ended at Phase 9). The critical path is: server infrastructure -> app integration -> dashboard API -> dashboard frontend. Docker packaging can parallelize with Phase 10-11.

### Phase 10: Server Foundation
**Rationale:** Validate the entire Docker + Shelf + sqlite3 stack before building anything on top. This phase proves the critical dependencies work (build hooks, scratch image, SQLite bundling) and establishes authentication.

**Delivers:**
- Shelf server binary with API key auth middleware
- Backup upload endpoint (POST /api/backup) with checksum validation + PRAGMA quick_check
- Backup storage (timestamped files in /data/backups/)
- Health check endpoint (GET /api/health)
- Dockerfile + docker-compose.yml (multi-stage, <50MB image)
- Backup list/download/delete endpoints (GET/DELETE /api/backups)

**Addresses:** Pitfalls 1, 3, 4, 5 (WAL corruption, transfer corruption, API key security, Docker SQLite). All table stakes backup management features. File-based storage pattern.

**Avoids:** Building dashboard code before proving the server can receive and store backups correctly. Avoids using Drift on server (Pitfall 2).

**Research flag:** Standard patterns. Shelf + Docker docs are excellent. No deep research needed.

### Phase 11: App Integration
**Rationale:** Server is functional and testable. App changes are minimal (2 Settings columns, 1 new page, HTTP service). This completes the data flow: app can now push backups to the deployed server.

**Delivers:**
- Database migration v65 -> v66 (add server_url, server_api_key to Settings)
- ServerSettingsPage (URL/API key fields, connection test, push button)
- ServerPushService (WAL checkpoint + HTTP POST with multipart file + Bearer token)
- Last push status display (timestamp + success/error)
- Link from Data Settings to Server settings

**Addresses:** Uses existing http package 1.2.0 (already in pubspec). Reuses WAL checkpoint pattern from export_data.dart and auto_backup_service.dart.

**Avoids:** Changing backup file format (sends raw SQLite file, same as existing export). Auto-sync (manual push only).

**Research flag:** Standard patterns. Existing codebase has all the patterns needed (WAL checkpoint, HTTP multipart upload, Settings migration).

### Phase 12: Dashboard Query Layer
**Rationale:** With backups on the server, the server needs to read and query them for the dashboard. This phase builds the BackupDatabase abstraction and replicates the app's SQL analytics queries.

**Delivers:**
- BackupDatabase class (opens latest backup read-only with sqlite3)
- SQL queries for dashboard data (replicates gym_sets.dart patterns):
  - Overview stats (workout count, total volume, streak, training time)
  - Exercise list (grouped by category, with last-trained date)
  - Exercise detail (strength data, 1RM, volume, PRs, rep records)
  - Workout history (with set count, duration)
  - Workout detail (joined gym_sets with exercise grouping)
- Schema version checking (PRAGMA user_version, minimum v48)
- Cached read-only database connection (lazy-loaded)

**Addresses:** Pitfall 2 (schema version mismatch) with version checking. Gotchas 1-4 (epoch seconds, hidden filter, workout_id NULL handling, notes table). Debt 1 (query logic reuse) by extracting SQL patterns. Debt 2 (timezone) by setting TZ env var in docker-compose.

**Avoids:** Running PRAGMA integrity_check on every request (Trap 1). Opening/closing DB per request (Trap 2).

**Research flag:** Requires careful mapping of app SQL queries to server. Medium complexity. Use gym_sets.dart as canonical reference.

### Phase 13: Dashboard Frontend
**Rationale:** Query layer is functional. Now build the HTML pages and Chart.js visualizations that consume the API data.

**Delivers:**
- Server-rendered HTML templates (Dart string interpolation)
- Dashboard routes: overview (/), workouts (/workouts), workout detail (/workouts/:id), exercises (/exercises), exercise detail (/exercises/:name), backups (/backups)
- Static assets (CSS, Chart.js from CDN)
- Charts: training heatmap (SVG grid), muscle group volume (bar), strength progress (line), bodyweight trend (line)
- Responsive layout (desktop sidebar, mobile hamburger)
- Dark/light theme toggle (CSS custom properties)
- Period selector (Week, Month, 3M, 6M, Year, All Time)

**Addresses:** All table stakes dashboard features. Visual parity with app's OverviewPage and StrengthPage.

**Avoids:** Building a SPA (Anti-Pattern 3). Using a JS framework (overkill for read-only pages). Using a Dart template engine (string interpolation sufficient for 5-6 pages).

**Research flag:** Standard web dev. Chart.js docs are excellent. No deep research needed.

### Phase 14: Dashboard Differentiators (Optional/Post-MVP)
**Rationale:** Core loop works (push backup -> view dashboard). This phase adds competitive features that leverage JackedLog's unique data model.

**Delivers:**
- 5/3/1 block history page (fivethreeone_blocks table, TM progression over time)
- Bodyweight trend page (bodyweight_entries table)
- Estimated 1RM leaderboard (ranked across all exercises)
- Workout frequency by weekday chart
- Server-side backup retention policy (port GFS logic from auto_backup_service.dart)
- Export from web dashboard (CSV download)

**Addresses:** Differentiator features from FEATURES.md. These are "should have" not "must have."

**Research flag:** Low complexity. All SQL patterns exist in app or are straightforward aggregations.

### Phase Ordering Rationale

- **Phase 10 first:** Validate the riskiest unknowns (Docker + SQLite build hooks, scratch image, Shelf + sqlite3 integration) before building anything on top. If this fails, nothing else matters.
- **Phase 11 before 12-13:** Server must be able to receive backups before it can display them. App integration is independent of dashboard work and can be done early.
- **Phase 12 before 13:** Dashboard frontend needs API endpoints and query layer. Building HTML before queries exist means working with mock data.
- **Phase 14 last:** Differentiators are additive. MVP is functional without them.
- **Docker in Phase 10:** Docker packaging is part of the foundation. The server is deployed via Docker from day one, not added later.

**Parallelizable work:**
- Phase 11 (app) can overlap with Phase 12 (server queries) — different codebases, no conflicts
- Phase 13 (frontend) can start before Phase 12 completes if using mock API data
- Phase 14 features can be built independently of each other

### Research Flags

Phases with standard patterns (skip research-phase):
- **Phase 10:** Shelf, Docker, and sqlite3 docs are excellent. Patterns are well-established.
- **Phase 11:** Existing codebase has all the patterns (Settings migration, HTTP multipart, WAL checkpoint).
- **Phase 13:** Chart.js docs are excellent. Server-rendered HTML is standard web dev.
- **Phase 14:** Straightforward extensions of Phase 12-13 patterns.

**Phase 12 needs careful execution** (not deep research, but attention to detail):
- Replicating SQL queries exactly from gym_sets.dart (1RM formula, volume calculation, date grouping)
- Timezone handling (avoid 'localtime' on server, set TZ env var)
- Schema version edge cases (handling v48-v65 range)
- Hidden filter on every gym_sets query

No phase needs `/gsd:research-phase` — all patterns are known. Execution requires care, not research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Shelf, sqlite3, Chart.js all well-documented official packages. Docker multi-stage builds are standard. |
| Features | HIGH | Table stakes derived from self-hosted tracker ecosystem analysis. Differentiators from app's unique data model. |
| Architecture | HIGH | Direct sqlite3 access proven by existing app dependencies. Monorepo workspace supported in Dart 3.6+. Server-rendered HTML is straightforward. |
| Pitfalls | HIGH | All critical pitfalls derived from codebase analysis (WAL checkpoint pattern exists, 65 schema versions documented, timestamp handling visible in code). |

**Overall confidence:** HIGH

### Gaps to Address

**Low confidence areas requiring validation during Phase 10:**

1. **sqlite3 v3 build hooks + dart build cli + scratch Docker image:** The mechanism should work (build hooks produce native assets that dart build cli bundles), but this specific combination needs first-run validation. The Dart SDK version in dart:stable (3.11.x) should fully support build hooks (stabilized in 3.10), but verify the compiled .so is correctly included in the scratch runtime image.

   **Mitigation:** Validate in Phase 10 first task. If build hooks don't work as expected, fall back to explicitly copying libsqlite3.so from build stage (pattern documented in PITFALLS.md).

2. **ARM64 Docker compatibility:** sqlite3 native library paths differ between amd64 and arm64. Many self-hosted users run Raspberry Pi.

   **Mitigation:** Test both architectures in Phase 10. Add to CI pipeline. Multi-arch Docker builds are standard (Docker buildx).

3. **Schema version compatibility:** Server needs to handle backups from v48-v65+ gracefully. Edge cases may exist.

   **Mitigation:** Test with actual backup files from different app versions during Phase 12. The app's export_data.dart creates perfect test fixtures.

**Medium confidence:**
- Whether dashboard queries will be fast enough on large databases (years of data) without additional indexes. The app already has indexes on gym_sets(name, created) and gym_sets(workout_id), which should suffice.

   **Mitigation:** Test with real user backup (1+ year of data) in Phase 12. Add indexes if queries are slow (unlikely).

## Sources

### Primary (HIGH confidence)

**Codebase analysis:**
- lib/export_data.dart — WAL checkpoint pattern (line 158-159), database export flow
- lib/import_data.dart — WAL/SHM file deletion (lines 101-104)
- lib/database/database.dart — 65 schema versions, migration system
- lib/database/gym_sets.dart — Query patterns, SQL formulas, timestamp handling, hidden filter
- lib/backup/auto_backup_service.dart — Backup file creation, GFS retention policy
- pubspec.yaml — Existing dependencies (http 1.2.0, sqlite3 2.4.0)

**Official documentation:**
- [shelf 1.4.2 on pub.dev](https://pub.dev/packages/shelf) — Dart team maintained
- [shelf_router 1.1.4 on pub.dev](https://pub.dev/packages/shelf_router)
- [shelf_static 1.1.3 on pub.dev](https://pub.dev/packages/shelf_static)
- [sqlite3 3.1.5 on pub.dev](https://pub.dev/packages/sqlite3) — Build hooks for bundling
- [Official Dart Docker image](https://hub.docker.com/_/dart) — Multi-stage builds
- [Dart build hooks documentation](https://dart.dev/tools/hooks)
- [Chart.js 4.5.1](https://www.chartjs.org/)
- [SQLite WAL Documentation](https://sqlite.org/wal.html)
- [SQLite PRAGMA Documentation](https://www.sqlite.org/pragma.html)

**Self-hosted ecosystem:**
- [wger - Self-hosted FLOSS fitness tracker](https://github.com/wger-project/wger) — Feature benchmarking
- [workout-tracker](https://github.com/jovandeginste/workout-tracker) — API key auth pattern
- [FitTrackee](https://github.com/SamR1/FitTrackee) — Self-hosted UX patterns

### Secondary (MEDIUM confidence)
- [dart_frog 1.2.6 community transition](https://www.verygood.ventures/blog/dart-frog-has-found-a-new-pond) — July 2025
- [Dart Docker SQLite3 issue #171](https://github.com/dart-lang/dart-docker/issues/171) — Solved by v3 build hooks
- [SQLite forum: WAL backup corruption](https://sqlite.org/forum/forumpost/905eb5e564d4df44)
- [API Key Best Practices - Google Cloud](https://docs.google.com/docs/authentication/api-keys-best-practices)

### Tertiary (LOW confidence - needs Phase 10 validation)
- Whether dart build cli properly bundles sqlite3 v3 native assets into scratch Docker image
- Whether Dart SDK 3.11.x in dart:stable fully supports build hooks for AOT compilation

---
*Research completed: 2026-02-15*
*Ready for roadmap: yes*
