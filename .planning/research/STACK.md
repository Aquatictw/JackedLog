# Stack Research: Self-Hosted Web Companion Server

**Domain:** Self-hosted Dart web server + read-only dashboard for fitness tracking app
**Researched:** 2026-02-15
**Confidence:** HIGH

---

## Executive Summary

The v1.3 self-hosted web companion requires a separate Dart server project within the monorepo, packaged as a Docker container. The server receives SQLite database backup files from the Flutter app, stores them, and serves a read-only web dashboard with workout statistics and progress graphs.

The recommended stack is **Shelf** (official Dart team HTTP server) with **shelf_router** for routing and **shelf_static** for serving the web dashboard's static assets. The dashboard frontend uses **vanilla HTML/CSS/JS with Chart.js** for graphs -- no SPA framework. The server reads uploaded SQLite databases using the **sqlite3** package (v3.x with build hooks that bundle SQLite natively). Authentication uses a simple **API key middleware** (custom, ~20 lines) checked via Bearer token header.

Key architectural decision: the server does NOT use Drift ORM. It opens the uploaded `.sqlite` file directly with the `sqlite3` package and runs raw SQL queries. This avoids pulling Flutter-specific Drift codegen into the server project, and since the dashboard is read-only, there is no need for type-safe query builders or migrations.

---

## Recommended Stack

### Server Framework

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `shelf` | 1.4.2 | HTTP server foundation | Official Dart team package. Minimal, composable middleware architecture. Battle-tested, stable (20 months since last release = mature, not abandoned). Every other Dart server framework is built on top of Shelf anyway. |
| `shelf_router` | 1.1.4 | Request routing | Official companion to Shelf. Express.js-style route patterns (`app.get('/api/backups', handler)`). Lightweight -- just routing, nothing more. |
| `shelf_static` | 1.1.3 | Serve static files | Official companion to Shelf. Serves the HTML/CSS/JS dashboard files from a directory. Handles mime types, caching headers. |
| `shelf_cors_headers` | ~0.1.x | CORS middleware | Only needed if dashboard and API are on different origins. May not be needed since both are served from the same server. Evaluate during implementation. |

**Why Shelf over dart_frog:**

dart_frog (v1.2.6, community-maintained since July 2025) is a higher-level wrapper around Shelf that adds file-based routing, middleware, and dependency injection. It is designed for rapid API prototyping. However:

1. **Overhead for this use case.** dart_frog's file-based routing and DI system add complexity for what is a 5-endpoint API server. The CLI tooling (`dart_frog dev`, `dart_frog build`) introduces another build step that complicates Docker builds.
2. **dart_frog generates a Shelf app underneath.** Using Shelf directly removes a layer of abstraction with no loss of capability.
3. **Docker builds.** Shelf compiles with standard `dart build cli`. dart_frog requires `dart_frog build` first, then compilation -- an extra step.
4. **Maintenance trajectory.** Shelf is maintained by the Dart team (tools.dart.dev publisher). dart_frog transitioned to community-led maintenance in July 2025 -- viable but less certain long-term.

**Why NOT shelf_plus:** shelf_plus (v1.11.0) bundles shelf + shelf_router + shelf_static + shelf_web_socket + hot reload into one package. Convenient for development but adds unnecessary WebSocket support and hot-reload dependencies to the production build. Prefer explicit, minimal dependencies.

### Database / SQLite Access

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `sqlite3` | 3.1.5 | Read uploaded SQLite backup files | Pure Dart bindings via dart:ffi. Version 3.x uses build hooks to bundle SQLite natively -- no system `libsqlite3.so` needed in Docker. Eliminates the Docker runtime dependency problem entirely. |

**Why sqlite3 directly, NOT Drift:**

The server opens user-uploaded `.sqlite` files in **read-only mode** to query workout data for the dashboard. It does NOT manage its own schema, run migrations, or write data to the workout database. Using Drift would require:

1. Duplicating all 9 table definitions from the Flutter app in the server project
2. Running `build_runner` code generation in the server project
3. Keeping the server's Drift schema in sync with the app's schema (version 65+)
4. Pulling in Drift's reactive stream infrastructure that serves no purpose server-side

Instead, raw SQL via `sqlite3.open(filePath, mode: OpenMode.readOnly)` is simpler and decoupled. The server queries the same tables (`gym_sets`, `workouts`, `bodyweight_entries`, `five_three_one_blocks`, `notes`) using the same SQL the app already uses (see `lib/database/gym_sets.dart` for query patterns). If the app's schema changes, the server's SQL queries may need updating, but this is a small surface area vs. maintaining a parallel Drift schema.

**Server-own metadata:** The server needs a tiny amount of its own state (backup history, API key hash). This uses a separate small SQLite database (`server_meta.db`) managed via raw `sqlite3` -- no Drift needed for a 2-table config database.

### Web Dashboard Frontend

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| HTML/CSS (vanilla) | -- | Dashboard structure and styling | No build step, no node_modules, no bundler. Served directly by shelf_static. |
| Chart.js | 4.5.1 | Progress graphs, strength trends, volume charts | Most popular lightweight JS charting library. CDN-loadable via single script tag. Matches the visual style of FL Chart in the app (line charts, bar charts). |
| Vanilla JS (ES6) | -- | Fetch API data, render chart updates | For a read-only dashboard with ~5 pages, a framework is overkill. fetch() + DOM manipulation covers it. |

**Why NOT a JS framework (React/Vue/Svelte):**

1. **Build complexity.** Any JS framework requires Node.js, npm, a bundler (Vite/webpack), and a build step. This adds a Node.js stage to the Docker build and increases image size.
2. **This is a read-only dashboard, not an app.** There are no forms, no interactive state management, no client-side routing needs. The server renders the data; JS just draws charts.
3. **Self-hosted users.** The target audience runs Docker on a home server. Simpler = fewer things to break. A 200KB HTML/CSS/JS bundle is more maintainable than a Node.js build pipeline.

**Why NOT Jaspr (Dart SSR framework):**

Jaspr is a Dart web framework with SSR support, which would keep the entire stack in Dart. However:

1. It adds significant complexity (component model, hydration, routing)
2. It is relatively young with limited community adoption
3. The dashboard has ~5 pages of static data display -- Jaspr's SSR capabilities are overkill

**Why NOT server-side rendered HTML templates (Mustache/Liquid):**

Template engines in Dart are viable but poorly maintained. `mustache_template` and `liquid_engine` have low adoption. For a small dashboard, building HTML strings in Dart handlers or serving static HTML that fetches JSON via API endpoints is simpler and more maintainable.

**Recommended approach:** Static HTML files served by shelf_static, with JS that calls the server's JSON API endpoints and renders data using Chart.js. This gives a clean separation: the Dart server only serves JSON + static files, and the browser handles rendering.

### Docker

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `dart:stable` | 3.11.x | Build stage base image | Official Dart Docker image. AOT compiles to native executable. |
| `scratch` | -- | Runtime stage base image | Minimal image (~10-15MB total). Contains only the compiled binary + bundled SQLite (from build hooks). |

**Multi-stage build strategy:**

```dockerfile
# Stage 1: Build
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline
RUN dart build cli --target bin/server.dart -o output

# Stage 2: Runtime
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/output/bundle/ /app/
COPY --from=build /app/web/ /app/web/
EXPOSE 8080
VOLUME /app/data
CMD ["/app/bin/server"]
```

**Critical note on `dart build cli` vs `dart compile exe`:** The sqlite3 v3 package uses Dart build hooks to bundle SQLite. Build hooks are NOT supported by `dart compile exe` -- you MUST use `dart build cli` instead. This is the modern Dart AOT compilation approach and is what the official Docker documentation recommends.

**Why NOT `dart:stable` as runtime (without scratch):** The full Dart SDK image is ~800MB. The scratch-based approach produces a ~10-15MB image. For a self-hosted server that sits on a home NAS, image size matters.

**Volume mount:** `/app/data` stores uploaded backups and the server metadata database. This must be a Docker volume so data persists across container restarts.

### Authentication

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Custom Shelf middleware | -- | API key authentication | Single-user self-hosted app. API key stored as SHA-256 hash in server config. ~20 lines of middleware code. |
| `crypto` (dart:convert) | built-in | SHA-256 hashing | Part of Dart SDK. No external package needed for hashing the API key. |

**Why NOT JWT:**

JWT is designed for stateless authentication in multi-server, multi-user systems. This is a single-user, single-server application. An API key is:

1. Simpler to implement (string comparison vs. token signing/verification)
2. Simpler for users to configure (copy-paste a key, not manage token expiration)
3. Equally secure for the threat model (self-hosted, local network, single user)

**Authentication flow:**

1. User generates an API key during server setup (displayed once, stored as SHA-256 hash)
2. App stores the API key in Settings table (new columns: `server_url`, `server_api_key`)
3. App sends API key as `Authorization: Bearer <key>` header on every request
4. Server middleware hashes incoming key and compares to stored hash
5. Dashboard web UI: either no auth (local network assumption) or session cookie from a login page

### App-Side (Client Changes)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `http` | 1.2.0 (already in pubspec) | HTTP client for backup push | Already a dependency. Supports `MultipartRequest` for file uploads. No new package needed. |

**App-side changes needed (Settings table additions):**

| Column | Type | Purpose |
|--------|------|---------|
| `server_url` | TEXT NULLABLE | URL of the self-hosted server |
| `server_api_key` | TEXT NULLABLE | API key for server authentication |

**Backup push flow:**

1. User configures server URL + API key in app settings
2. User taps "Push to Server" button (manual, not automatic)
3. App calls `PRAGMA wal_checkpoint(TRUNCATE)` (existing pattern from auto_backup_service.dart)
4. App reads `jackedlog.sqlite` file bytes
5. App sends `POST /api/backup` with multipart file upload + Bearer token header
6. Server stores file in `/app/data/backups/` with timestamped filename
7. Server updates its metadata database with backup record

---

## Server Project Structure

```
server/
  bin/
    server.dart          # Entry point
  lib/
    middleware/
      auth.dart          # API key middleware
      logging.dart       # Request logging
    routes/
      api.dart           # JSON API routes (backup, stats, exercises, graphs)
      dashboard.dart     # Dashboard page routes (serve HTML)
    services/
      backup_service.dart    # Backup storage and management
      stats_service.dart     # Query workout database for dashboard data
    config.dart          # Server configuration (port, data dir, API key hash)
  web/
    index.html           # Dashboard entry point
    css/
      style.css          # Dashboard styles
    js/
      app.js             # Chart rendering, API calls
      charts.js          # Chart.js configuration
  test/
    server_test.dart     # API endpoint tests
  pubspec.yaml           # Server-only dependencies
  Dockerfile
```

This is a **separate Dart project** within the monorepo, NOT part of the Flutter app's pubspec.yaml. The server has its own dependency tree and does not import Flutter.

---

## Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `args` | ^2.6.0 | CLI argument parsing | Parse `--port`, `--data-dir`, `--config` flags on server startup |
| `path` | ^1.8.3 | File path manipulation | Already used in main app. Needed for backup file path handling. |
| `archive` | ^4.0.0 | ZIP compression (optional) | Only if server needs to serve zipped backup downloads. Evaluate later. |
| `crypto` | built-in | SHA-256 for API key hashing | Part of `dart:convert`. No separate package. |

---

## Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `dart run bin/server.dart` | Local development server | Run from `server/` directory |
| `dart test` | Server unit/integration tests | Test API endpoints with mock requests |
| `dart build cli` | AOT compile for Docker | Produces native executable with bundled SQLite |
| Docker Compose | Local dev with volume mounts | Simplifies development setup |

---

## Installation

Server project `pubspec.yaml`:

```yaml
name: jackedlog_server
description: Self-hosted companion server for JackedLog
environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  shelf: ^1.4.2
  shelf_router: ^1.1.4
  shelf_static: ^1.1.3
  sqlite3: ^3.1.5
  args: ^2.6.0
  path: ^1.8.3

dev_dependencies:
  test: ^1.25.0
  http: ^1.2.0  # For integration testing API endpoints
```

```bash
# From server/ directory
dart pub get
```

App-side additions (to existing `pubspec.yaml`): **None**. The `http` package (v1.2.0) is already a dependency and provides `MultipartRequest` for file uploads.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| Server framework | Shelf 1.4.2 | dart_frog 1.2.6 | Extra abstraction layer, custom build step, community-maintained since Jul 2025. Shelf is simpler for 5 endpoints. |
| Server framework | Shelf 1.4.2 | Serverpod | Full-stack framework with ORM, auth, real-time -- massive overkill for a read-only backup receiver. |
| Server framework | Shelf 1.4.2 | shelf_plus 1.11.0 | Bundles WebSocket/hot-reload deps we don't need. Prefer explicit minimal deps. |
| SQLite access | sqlite3 3.1.5 (raw) | Drift 2.31.0 | Would require duplicating 9 table definitions, build_runner codegen, schema sync. Read-only queries don't need ORM. |
| Dashboard frontend | Vanilla HTML/JS + Chart.js | React/Vue/Svelte SPA | Adds Node.js build pipeline, increases Docker complexity, overkill for 5 read-only pages. |
| Dashboard frontend | Vanilla HTML/JS + Chart.js | Jaspr (Dart SSR) | Young framework, steep learning curve for simple pages, overkill for the use case. |
| Dashboard frontend | Vanilla HTML/JS + Chart.js | Flutter Web | Massive bundle size (~2MB+), poor SEO, slow initial load, overkill for static data display. |
| Charting | Chart.js 4.5.1 (CDN) | D3.js | D3 is lower-level, requires more code for standard charts. Chart.js is batteries-included for line/bar/doughnut. |
| Authentication | API key + Bearer header | JWT tokens | JWT adds token expiration, refresh flow, signing keys -- unnecessary for single-user self-hosted. |
| Authentication | API key + Bearer header | OAuth2 | Designed for third-party authorization. No third parties in self-hosted single-user. |
| Docker runtime | scratch | alpine | Alpine adds ~5MB but includes shell for debugging. Consider if troubleshooting in production is needed. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Drift ORM on server | Forces schema duplication, codegen, sync burden. Server only reads data. | Raw sqlite3 queries |
| Flutter Web for dashboard | 2MB+ bundle, slow load, poor SEO, overkill for read-only data display | Vanilla HTML/JS + Chart.js |
| dart_frog | Extra build step (`dart_frog build`), file-based routing overhead for 5 routes | Shelf directly |
| JWT authentication | Over-engineered for single-user self-hosted | API key with Bearer header |
| WebSocket / real-time sync | App is offline-first with manual push. No real-time requirement. | REST API with manual push |
| Node.js in Docker | Any JS framework adds Node to the build, doubling image size | Static HTML/JS served by Dart |
| sqlite3 v2.x | Requires system libsqlite3.so in Docker runtime image | sqlite3 v3.x (bundles SQLite via build hooks) |
| `dart compile exe` | Does not support build hooks (needed by sqlite3 v3.x) | `dart build cli` |
| Background sync / auto-push | Violates offline-first design, adds complexity (retry logic, conflict detection) | Manual backup push |
| Multi-user auth / user accounts | Out of scope. Self-hosted = single user. | Single API key |

---

## Integration Points with Existing App

### Backup Format Compatibility

The app already produces `.sqlite` backup files via:

1. **Manual export:** `ExportData` widget (lib/export_data.dart) -- calls `PRAGMA wal_checkpoint(TRUNCATE)` then copies `jackedlog.sqlite`
2. **Auto-backup:** `AutoBackupService` (lib/backup/auto_backup_service.dart) -- same WAL checkpoint, copies to configured path

The server receives the same `.sqlite` file. No format conversion needed. The server opens it read-only with `sqlite3.open(path, mode: OpenMode.readOnly)`.

### Database Schema Awareness

The server needs to handle multiple database versions (users may push backups from different app versions). The server should:

1. Read the `PRAGMA user_version` to determine schema version
2. Require minimum version 48 (when `workouts` table was added -- needed for dashboard)
3. Gracefully handle missing columns/tables from newer versions (use `SELECT * FROM sqlite_master` to check table existence)

### HTTP Client (App-Side)

The app already depends on `http: ^1.2.0` (currently used only by Spotify integration). The backup push uses `MultipartRequest`:

```dart
final request = http.MultipartRequest('POST', Uri.parse('$serverUrl/api/backup'));
request.headers['Authorization'] = 'Bearer $apiKey';
request.files.add(await http.MultipartFile.fromPath('backup', dbFilePath));
final response = await request.send();
```

No new dependencies needed.

### Settings Table Changes (App-Side)

New columns needed in the app's Settings table (migration v65 -> v66):

```sql
ALTER TABLE settings ADD COLUMN server_url TEXT;
ALTER TABLE settings ADD COLUMN server_api_key TEXT;
```

These are nullable -- the server feature is entirely optional. If both are null, no server UI is shown.

---

## Sources

**HIGH Confidence (official documentation, verified):**

- [shelf 1.4.2 on pub.dev](https://pub.dev/packages/shelf) -- latest version, Dart team maintained
- [shelf_router 1.1.4 on pub.dev](https://pub.dev/packages/shelf_router) -- latest version
- [shelf_static 1.1.3 on pub.dev](https://pub.dev/packages/shelf_static) -- latest version
- [sqlite3 3.1.5 on pub.dev](https://pub.dev/packages/sqlite3) -- latest version (published 3 days ago), build hooks for bundling
- [Drift setup documentation](https://drift.simonbinder.eu/setup/) -- NativeDatabase for pure Dart, version 2.31.0
- [Drift platform support](https://drift.simonbinder.eu/platforms/) -- confirms pure Dart server support
- [Official Dart Docker image](https://hub.docker.com/_/dart) -- dart:stable 3.11.x, multi-stage build with scratch
- [Dart Docker issue #171](https://github.com/dart-lang/dart-docker/issues/171) -- SQLite in scratch images (solved by sqlite3 v3 build hooks)
- [Dart build hooks documentation](https://dart.dev/tools/hooks) -- build hooks run during `dart build`, not `dart compile exe`
- [dart_frog 1.2.6 on pub.dev](https://pub.dev/packages/dart_frog) -- latest version, community-maintained
- [Chart.js 4.5.1](https://www.chartjs.org/) -- current stable version
- [http 1.2.0 MultipartRequest](https://pub.dev/documentation/http/latest/http/MultipartRequest-class.html) -- file upload API
- Codebase: `lib/export_data.dart` -- existing backup file format (raw SQLite with WAL checkpoint)
- Codebase: `lib/backup/auto_backup_service.dart` -- existing backup workflow
- Codebase: `lib/database/database.dart` -- schema version 65, migration patterns
- Codebase: `lib/database/gym_sets.dart` -- SQL query patterns for strength/cardio data
- Codebase: `pubspec.yaml` -- existing http dependency at 1.2.0

**MEDIUM Confidence (multiple sources agree):**

- [sqlite3 v3 build hooks bundle SQLite](https://github.com/simolus3/sqlite3.dart/tree/master/sqlite3) -- bundles prebuilt SQLite for Linux x64/arm64
- [dart_frog community transition](https://www.verygood.ventures/blog/dart-frog-has-found-a-new-pond) -- moved to dart-frog-dev org July 2025
- [shelf_plus 1.11.0 on pub.dev](https://pub.dev/packages/shelf_plus) -- evaluated and rejected

**LOW Confidence (needs validation during implementation):**

- Whether `dart build cli` properly bundles sqlite3's native assets into the `scratch` Docker image -- the mechanism should work (build hooks produce code assets), but this specific combination needs testing in the first implementation phase
- Whether the Dart SDK version in `dart:stable` Docker image (3.11.x) fully supports build hooks for AOT compilation -- build hooks were stabilized in Dart 3.10, so 3.11 should work, but verify

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Server framework (Shelf) | HIGH | Official Dart team package, stable API, well-documented, simple for this use case |
| SQLite access (sqlite3 raw) | HIGH | Well-established package, v3.1.5 published days ago, build hooks eliminate Docker dependency issues |
| Dashboard frontend (vanilla + Chart.js) | HIGH | Standard web technologies, zero build step, Chart.js is the most popular lightweight charting lib |
| Docker packaging | MEDIUM | Standard multi-stage pattern works, but sqlite3 v3 build hooks + `dart build cli` + scratch combo needs first-run validation |
| Authentication (API key) | HIGH | Trivially simple to implement, appropriate for single-user self-hosted |
| App-side HTTP client | HIGH | `http` package already in deps, MultipartRequest is well-documented |
| Schema compatibility | MEDIUM | Server reading arbitrary app database versions has edge cases -- needs careful `PRAGMA user_version` checking |

---

## Summary for Roadmap

**Phase ordering implication:** The first phase should focus on the server skeleton (Shelf + Docker + API key auth + backup receive endpoint) without any dashboard. This validates the Docker build pipeline and sqlite3 v3 build hooks in a container before building UI on top.

The dashboard should come in a later phase after the API layer is proven, since Chart.js rendering is straightforward once the JSON API endpoints exist.

App-side changes (Settings columns + server config UI + backup push button) can be developed in parallel with the server, since the interface contract (POST /api/backup with multipart file + Bearer token) is simple and stable.
