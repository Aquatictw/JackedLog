# Architecture Research: Self-Hosted Web Companion Server

**Domain:** Self-hosted Dart server companion for Flutter fitness app
**Researched:** 2026-02-15
**Confidence:** HIGH (based on codebase analysis, official Dart/Drift docs, pub.dev packages)

## System Overview

```
+-------------------+        HTTPS POST        +--------------------+
|                   |  (SQLite file + API key)  |                    |
|   JackedLog App   | -----------------------> |   JackedLog Server |
|   (Flutter/Dart)  |    Manual push trigger    |   (Dart + Shelf)   |
|                   |                           |                    |
+-------------------+                           +--------+-----------+
                                                         |
                                                         | Reads SQLite
                                                         | directly
                                                         v
                                                +--------+-----------+
                                                |                    |
                                                |  Uploaded .sqlite  |
                                                |  (stored on disk)  |
                                                |                    |
                                                +--------+-----------+
                                                         |
                                                         | sqlite3 queries
                                                         v
                                                +--------+-----------+
                                                |                    |
                                                |   Web Dashboard    |
                                                |  (Server-rendered  |
                                                |   HTML + CSS/JS)   |
                                                |                    |
                                                +--------------------+
                                                         |
                                                         v
                                                    Browser (read-only)
```

**Data flows in ONE direction:** App pushes backup to server. Server never calls back to app. The app remains fully offline-first -- the server is a read-only viewer of snapshots.

---

## Critical Architectural Decision: How the Server Reads SQLite

### Recommendation: Direct SQLite Access via `sqlite3` Package (Not Drift)

**Use the raw `sqlite3` Dart package to open and query the uploaded `.sqlite` file directly.** Do not use Drift on the server. Do not import data into a separate server database.

**Rationale:**

1. **Schema coupling is the biggest risk.** The app uses Drift with schema version 65 and complex manual migrations. If the server also uses Drift with the same schema definition, every app schema change requires synchronized server changes. Direct SQLite queries with `sqlite3.open()` decouple the server from the app's migration system entirely.

2. **The server reads, never writes.** Drift's value is type-safe writes, reactive streams, and migration management. The server needs none of these -- it only runs SELECT queries against an uploaded file. Raw SQL is simpler and more appropriate.

3. **The uploaded file IS the database.** There is no data transformation needed. The app exports `jackedlog.sqlite` (the same file Drift manages). The server opens it and runs queries. No import step, no schema mapping, no data loss risk.

4. **Query reuse is straightforward.** The app's `gym_sets.dart` already contains raw SQL strings for analytics (see `getStrengthData`, `getRpms`, `getExerciseRecords`). These can be extracted and reused on the server with minimal adaptation.

**How it works:**

```dart
import 'package:sqlite3/sqlite3.dart';

class BackupDatabase {
  final Database _db;

  BackupDatabase(String filePath) : _db = sqlite3.open(filePath);

  List<Map<String, dynamic>> getRecentWorkouts({int limit = 20}) {
    final result = _db.select('''
      SELECT w.id, w.start_time, w.end_time, w.name,
             COUNT(gs.id) as set_count
      FROM workouts w
      LEFT JOIN gym_sets gs ON gs.workout_id = w.id
      WHERE w.end_time IS NOT NULL
      GROUP BY w.id
      ORDER BY w.start_time DESC
      LIMIT ?
    ''', [limit]);
    return result.map((row) => {
      'id': row['id'],
      'startTime': row['start_time'],
      'endTime': row['end_time'],
      'name': row['name'],
      'setCount': row['set_count'],
    }).toList();
  }

  void dispose() => _db.dispose();
}
```

**Confidence:** HIGH -- the `sqlite3` package (pub.dev/packages/sqlite3) is the same underlying library that Drift uses via `NativeDatabase`. It works on all native Dart platforms without Flutter dependencies. Version 2.4.0+ is already in the app's pubspec.yaml.

### Why NOT Drift on the Server

| Concern | Direct sqlite3 | Drift on Server |
|---------|----------------|-----------------|
| Schema changes in app | Server unaffected | Must sync table defs + version |
| Migration handling | None needed (read-only) | Must match app's migration or skip |
| Code generation | None | Requires build_runner |
| New dependency risk | Zero (same package) | drift + drift_dev + build_runner |
| Query complexity | Raw SQL (already exists in app) | Drift DSL (would need rewrite) |
| Read-only guarantees | Can open with `OpenMode.readOnly` | Possible but not the default |

### Why NOT Import Into a Separate Server Database

Some architectures import uploaded data into a normalized server-side database (Postgres, separate SQLite). This is wrong for JackedLog because:

1. **Data transformation is lossy and fragile.** The app has 9 tables with 65 schema versions of evolution. Mapping all fields correctly is a maintenance burden that grows with every app update.
2. **There is exactly one user.** This is a self-hosted single-user system. There is no need for a separate database optimized for multi-tenant queries.
3. **The SQLite file is already indexed.** The app creates indexes on `gym_sets(name, created)` and `gym_sets(workout_id)`. Dashboard queries will be fast.
4. **Backup history is the feature.** Users want to see snapshots over time. Each uploaded `.sqlite` file is a complete, self-contained snapshot. Storing them as files is the simplest and most reliable approach.

---

## Recommended Project Structure: Monorepo with Pub Workspaces

### Layout

```
/home/aquatic/Documents/JackedLog/
  pubspec.yaml                    # Root workspace (NEW: add workspace directive)
  lib/                            # Existing Flutter app (UNCHANGED)
  server/                         # NEW: Dart server package
    pubspec.yaml                  # Server dependencies (shelf, sqlite3)
    bin/
      server.dart                 # Entry point
    lib/
      server.dart                 # Server setup and configuration
      routes/
        api.dart                  # API routes (backup upload, status)
        dashboard.dart            # Dashboard page routes
      middleware/
        auth.dart                 # API key authentication
        cors.dart                 # CORS headers (for API)
      db/
        backup_database.dart      # SQLite read queries for dashboard
        backup_store.dart         # Backup file management (store, list, delete)
      templates/
        layout.dart               # HTML template wrapper
        dashboard.dart            # Dashboard page template
        workouts.dart             # Workout history template
        graphs.dart               # Graph/chart page template
    web/                          # Static assets (CSS, JS, images)
      style.css
      charts.js                   # Lightweight charting (Chart.js or similar)
    Dockerfile                    # Multi-stage build
    docker-compose.yml            # Easy deployment
    .env.example                  # Configuration template
  test/                           # Existing Flutter tests
  server_test/                    # Server tests (optional separate dir)
```

### Why Monorepo (Not Separate Repo)

1. **Single version of truth.** When the app's database schema evolves (version 66, 67...), the server's query module can be updated in the same commit. Separate repos drift apart.

2. **Shared SQL knowledge.** The raw SQL queries in `lib/database/gym_sets.dart` (strength data, cardio data, RPMs, records) can be referenced when writing server queries. Same repo means the developer sees both.

3. **Pub workspaces.** Dart 3.6+ (installed: 3.10.7) supports native monorepo workspaces. The server package gets its own `pubspec.yaml` with independent dependencies -- no Flutter dependency contamination.

4. **Single deployment concern.** Users clone one repo, build one Docker image. No coordination between repos.

### Pub Workspace Configuration

**Root `pubspec.yaml` changes (add workspace directive):**

```yaml
name: jackedlog
# ... existing content ...
workspace:
  - server
```

**`server/pubspec.yaml`:**

```yaml
name: jackedlog_server
description: Self-hosted web companion for JackedLog
publish_to: none
version: 0.1.0

environment:
  sdk: ">=3.6.0 <4.0.0"

resolution: workspace

dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  shelf_static: ^1.1.0
  sqlite3: ^2.4.0
  args: ^2.4.0
  crypto: ^3.0.0       # For API key hashing

dev_dependencies:
  test: ^1.24.0
```

**Key detail:** The server package has NO dependency on Flutter, Drift, or any Flutter-specific package. It depends only on pure Dart packages. This is critical for the `dart compile exe` step in Docker.

---

## Component Responsibilities

### New Components (Server Side)

| Component | File | Responsibility |
|-----------|------|---------------|
| **Server entry point** | `server/bin/server.dart` | Parse CLI args, load config, start HTTP server |
| **Router setup** | `server/lib/server.dart` | Compose shelf Pipeline (logging, auth, routing) |
| **Auth middleware** | `server/lib/middleware/auth.dart` | Validate `X-API-Key` header against configured key |
| **API routes** | `server/lib/routes/api.dart` | `POST /api/backup` (receive file), `GET /api/backups` (list), `GET /api/backup/:id` (download) |
| **Dashboard routes** | `server/lib/routes/dashboard.dart` | `GET /` (overview), `GET /workouts` (history), `GET /graphs` (charts), `GET /backups` (management) |
| **BackupDatabase** | `server/lib/db/backup_database.dart` | Open uploaded SQLite file, run read-only queries for dashboard |
| **BackupStore** | `server/lib/db/backup_store.dart` | Store uploaded files to disk, track metadata, list/delete backups |
| **HTML templates** | `server/lib/templates/*.dart` | Server-rendered HTML pages using string interpolation |
| **Static assets** | `server/web/` | CSS, JS (Chart.js), favicon |

### Modified Components (App Side)

| Component | File | What Changes |
|-----------|------|-------------|
| **Settings table** | `lib/database/settings.dart` | Add `serverUrl` (TEXT nullable), `serverApiKey` (TEXT nullable) columns |
| **Database migration** | `lib/database/database.dart` | Version 66: ALTER TABLE settings ADD COLUMN server_url TEXT, server_api_key TEXT |
| **Data settings page** | `lib/settings/data_settings.dart` | Add "Server" section with URL + API key configuration |
| **New: Server push** | `lib/settings/server_settings.dart` (NEW) | Server configuration UI + manual "Push Backup" button |
| **New: Server service** | `lib/server/server_push_service.dart` (NEW) | HTTP POST of SQLite file to server endpoint |
| **Export data** | `lib/export_data.dart` | Reuse WAL checkpoint logic for server push |

### Unchanged Components

| Component | Why Unchanged |
|-----------|--------------|
| All workout recording code | Server is read-only viewer, does not affect recording |
| All graph/analytics code | Server has its own dashboard rendering |
| WorkoutState, PlanState, etc. | App state management is independent of server |
| Auto-backup service | Local backup continues independently of server push |
| Import data | Server push is one-way; no import from server |

---

## Data Flow

### Backup Push Flow (App to Server)

```
1. User opens Settings > Data > Server
2. Configures: Server URL (e.g., https://jacked.example.com)
                API Key (e.g., sk-abc123...)
3. User taps "Push Backup Now"
4. App: PRAGMA wal_checkpoint(TRUNCATE)      -- flush WAL
5. App: Read jackedlog.sqlite as bytes
6. App: HTTP POST to {serverUrl}/api/backup
        Headers: X-API-Key: {apiKey}
                 Content-Type: application/octet-stream
        Body: raw SQLite file bytes
7. Server: Validate API key
8. Server: Save file as backups/{timestamp}_jackedlog.sqlite
9. Server: Verify SQLite integrity (PRAGMA integrity_check)
10. Server: Return 200 OK with backup metadata
11. App: Show success toast
```

### Dashboard Rendering Flow (Server to Browser)

```
1. Browser requests GET /
2. Server: Auth middleware checks session cookie (or skips for dashboard)
3. Server: BackupStore.getLatestBackup() -> filepath
4. Server: BackupDatabase.open(filepath)
5. Server: Run queries:
   - Recent workouts (last 20)
   - Exercise PRs (1RM, volume, weight)
   - Weekly volume totals
   - Workout frequency heatmap data
   - Bodyweight trend
6. Server: Render HTML template with query results
7. Server: Return HTML response
8. Browser: Render page, Chart.js draws graphs
```

### Backup Management Flow (Server Web UI)

```
1. Browser requests GET /backups
2. Server: BackupStore.listBackups() -> [{filename, size, date, setCount}]
3. Server: Render backup list page
4. User clicks "Download" on a backup
5. Server: Stream backup file as response (Content-Disposition: attachment)
```

---

## Web Frontend Architecture: Server-Rendered HTML

### Recommendation: Server-Rendered HTML with Dart String Templates

**Do NOT build a separate SPA (React, Vue, etc.).** Do NOT compile Flutter for web. Use server-rendered HTML with minimal JavaScript for charts only.

**Rationale:**

1. **KISS.** A single Dart codebase serves both API and HTML. No build toolchain for frontend, no node_modules, no webpack. The Docker image contains one compiled binary.

2. **The dashboard is read-only.** There are no interactive forms, no real-time updates, no client-side state management. Every page is a static view of data from the last backup. Server-rendering is the natural fit.

3. **Minimal JavaScript.** The only JS needed is Chart.js (or similar) for rendering strength/volume graphs. Everything else is plain HTML + CSS.

4. **Docker image stays tiny.** AOT-compiled Dart server + static CSS/JS. No Node.js runtime, no Flutter web build artifacts.

### Template Approach: Dart String Interpolation

Rather than adding a template engine dependency (mustache, jinja), use Dart's native multi-line string interpolation. For a single-developer project with a handful of pages, this is simpler.

```dart
// server/lib/templates/layout.dart
String layoutTemplate({
  required String title,
  required String content,
  String activeNav = '',
}) => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title - JackedLog</title>
  <link rel="stylesheet" href="/static/style.css">
</head>
<body>
  <nav>
    <a href="/" class="${activeNav == 'dashboard' ? 'active' : ''}">Dashboard</a>
    <a href="/workouts" class="${activeNav == 'workouts' ? 'active' : ''}">Workouts</a>
    <a href="/graphs" class="${activeNav == 'graphs' ? 'active' : ''}">Graphs</a>
    <a href="/backups" class="${activeNav == 'backups' ? 'active' : ''}">Backups</a>
  </nav>
  <main>$content</main>
</body>
</html>
''';
```

**When to upgrade to a template engine:** If the dashboard grows beyond 5-6 pages or needs loops/conditionals that become awkward in string interpolation, switch to the `mustache_template` package. But for MVP, string interpolation is sufficient.

---

## Authentication Architecture

### API Endpoint Auth: API Key in Header

```
App -> Server:  X-API-Key: {configured_key}
Server:         Compare against stored key (env var or config file)
                Return 401 if mismatch
```

**Implementation:**

```dart
// server/lib/middleware/auth.dart
Middleware apiKeyAuth(String expectedKey) {
  return (Handler innerHandler) {
    return (Request request) {
      final apiKey = request.headers['x-api-key'];
      if (apiKey == null || apiKey != expectedKey) {
        return Response(401, body: 'Unauthorized');
      }
      return innerHandler(request);
    };
  };
}
```

### Dashboard Auth: Optional Basic Auth or None

For the web dashboard, two options:

**Option A (recommended for MVP): No dashboard auth.** The server runs on a private network (home LAN, VPN, Tailscale). Docker is bound to localhost or internal IP. The dashboard is read-only -- no destructive actions. Security through network isolation.

**Option B (post-MVP): Basic auth or session cookie.** Add a `DASHBOARD_PASSWORD` env var. First visit prompts for password, sets session cookie. This adds complexity but is needed if the server is exposed to the internet.

### API Key Storage

- **Server side:** Environment variable `JACKEDLOG_API_KEY`. Read at startup.
- **App side:** Stored in Settings table (`server_api_key` column). Encrypted at rest is out of scope for v1.3 (the API key authenticates read-only backup push, not a bank account).

---

## Docker Architecture

### Multi-Stage Build (Recommended by Official Dart Image)

```dockerfile
# Stage 1: Build
FROM dart:stable AS build
WORKDIR /app
COPY server/ ./
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Runtime
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/web/ /app/web/
EXPOSE 8080
ENV JACKEDLOG_API_KEY=""
ENV JACKEDLOG_DATA_DIR="/data"
VOLUME ["/data"]
CMD ["/app/bin/server"]
```

**Image size:** ~10-20 MB (AOT-compiled binary + static assets). The `FROM scratch` approach uses the Dart runtime from `/runtime/` in the build image.

**Volume:** `/data` stores uploaded backup files. This persists across container restarts.

**Configuration via environment variables:**

| Variable | Purpose | Default |
|----------|---------|---------|
| `JACKEDLOG_API_KEY` | Required. API key for backup uploads | (none -- must be set) |
| `JACKEDLOG_DATA_DIR` | Directory for backup file storage | `/data` |
| `JACKEDLOG_PORT` | Server listen port | `8080` |
| `JACKEDLOG_HOST` | Server bind address | `0.0.0.0` |

### docker-compose.yml

```yaml
version: '3.8'
services:
  jackedlog:
    build:
      context: .
      dockerfile: server/Dockerfile
    ports:
      - "8080:8080"
    environment:
      - JACKEDLOG_API_KEY=your-secret-key-here
    volumes:
      - jackedlog_data:/data
    restart: unless-stopped

volumes:
  jackedlog_data:
```

---

## Integration Points with Existing App

### Database Schema Changes (Version 66)

Two new nullable columns in Settings for server configuration:

```sql
ALTER TABLE settings ADD COLUMN server_url TEXT;
ALTER TABLE settings ADD COLUMN server_api_key TEXT;
```

**Migration in `database.dart`:**

```dart
if (from < 66 && to >= 66) {
  await m.database.customStatement(
    'ALTER TABLE settings ADD COLUMN server_url TEXT',
  ).catchError((e) {});
  await m.database.customStatement(
    'ALTER TABLE settings ADD COLUMN server_api_key TEXT',
  ).catchError((e) {});
}
```

**Settings table definition update:**

```dart
// In lib/database/settings.dart, add:
TextColumn get serverUrl => text().nullable()();
TextColumn get serverApiKey => text().nullable()();
```

**Import/export impact:** The CSV export only covers workouts + gym_sets, so no change needed. Database export (.sqlite) automatically includes the new columns. Importing an older database (without these columns) triggers migration to add them -- existing pattern handles this.

### Server Push Service (New App Component)

```dart
// lib/server/server_push_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;

class ServerPushService {
  static Future<bool> pushBackup({
    required String serverUrl,
    required String apiKey,
    required List<int> sqliteBytes,
  }) async {
    final uri = Uri.parse('$serverUrl/api/backup');
    final response = await http.post(
      uri,
      headers: {
        'X-API-Key': apiKey,
        'Content-Type': 'application/octet-stream',
      },
      body: sqliteBytes,
    );
    return response.statusCode == 200;
  }
}
```

**This reuses the existing `http` package** (already in pubspec.yaml at version 1.2.0) and the WAL checkpoint pattern from `export_data.dart` and `auto_backup_service.dart`.

### Server Settings UI (New App Page)

A new settings page accessible from Data Settings:

```
Data Management
  [Automatic Backups]     <-- existing
  [Export Data]            <-- existing
  [Import Data]           <-- existing
  [Import Hevy]           <-- existing
  [Server]                <-- NEW: tapping opens ServerSettingsPage
  [Delete Database]       <-- existing
```

**ServerSettingsPage contents:**
- Server URL text field (e.g., `https://jacked.example.com`)
- API Key text field (obscured)
- "Test Connection" button (GET /api/status)
- "Push Backup Now" button (POST /api/backup)
- Last push timestamp display

---

## Shared Code Strategy

### What IS Shared: SQL Query Patterns

The app's raw SQL queries (in `lib/database/gym_sets.dart`) contain valuable analytics logic:
- One-rep max calculation: `weight / (1.0278 - 0.0278 * reps)` (Brzycki formula)
- Volume calculation: `SUM(weight * reps)`
- Pace calculation: `SUM(distance) / SUM(duration)`
- Period grouping: `STRFTIME('%Y-%m-%d', DATE(created, 'unixepoch', 'localtime'))`

These SQL patterns should be replicated in the server's `BackupDatabase` class. They are plain SQL strings -- no Dart abstraction needed, just copy and adapt.

### What Is NOT Shared: Drift Table Definitions

Do NOT create a shared Dart package for "common models." The app uses Drift-generated classes (`GymSet`, `Workout`, `Plan`). The server uses raw `sqlite3` `Row` objects mapped to plain Dart maps or simple classes. These are fundamentally different representations of the same data, and that is intentional -- it keeps the server decoupled from Drift's code generation.

### Why No Shared Package

A shared package sounds appealing ("share models between app and server!") but creates problems:

1. **Drift dependency contamination.** If the shared package defines Drift tables, the server must depend on Drift + build_runner. If it defines plain classes, the app must map Drift objects to/from shared objects -- extra boilerplate with no benefit.

2. **Coupling.** Any change to the shared package requires updating both app and server. For a single-developer project, the "shared package" is just a coordination tax.

3. **YAGNI.** The server reads raw SQLite rows. The app uses Drift objects. They never need to pass typed objects between each other -- the interface is an HTTP file upload. There is nothing to share.

---

## Patterns to Follow

### Pattern 1: Shelf Pipeline Composition

```dart
// server/lib/server.dart
Handler createServer(String apiKey, String dataDir) {
  final apiRouter = Router()
    ..post('/api/backup', handleBackupUpload(dataDir))
    ..get('/api/backups', handleListBackups(dataDir))
    ..get('/api/backup/<id>', handleDownloadBackup(dataDir))
    ..get('/api/status', handleStatus);

  final dashboardRouter = Router()
    ..get('/', handleDashboard(dataDir))
    ..get('/workouts', handleWorkouts(dataDir))
    ..get('/workouts/<id>', handleWorkoutDetail(dataDir))
    ..get('/graphs', handleGraphs(dataDir))
    ..get('/backups', handleBackupManagement(dataDir));

  final staticHandler = createStaticHandler(
    'web',
    defaultDocument: 'index.html',
  );

  final cascade = Cascade()
    .add(Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(apiKeyAuth(apiKey))
      .addHandler(apiRouter.call))
    .add(Pipeline()
      .addMiddleware(logRequests())
      .addHandler(dashboardRouter.call))
    .add(staticHandler);

  return cascade.handler;
}
```

**Key:** API routes get auth middleware. Dashboard routes do not (MVP). Static file handler is the fallback.

### Pattern 2: Lazy Database Opening

The server should NOT keep a database connection open permanently. Open the latest backup's SQLite file per-request (or cache briefly).

```dart
class BackupDatabase {
  static BackupDatabase? _cached;
  static String? _cachedPath;

  static BackupDatabase forLatest(String dataDir) {
    final latestPath = BackupStore(dataDir).getLatestBackupPath();
    if (latestPath == _cachedPath && _cached != null) {
      return _cached!;
    }
    _cached?.dispose();
    _cached = BackupDatabase._(latestPath);
    _cachedPath = latestPath;
    return _cached!;
  }

  final Database _db;
  BackupDatabase._(String path) : _db = sqlite3.open(path, mode: OpenMode.readOnly);
  void dispose() => _db.dispose();
}
```

**Why read-only mode:** `sqlite3.open(path, mode: OpenMode.readOnly)` prevents any accidental writes to the backup file. This is a safety guarantee.

### Pattern 3: File-Based Backup Storage

```
/data/
  backups/
    2026-02-15T10-30-00_jackedlog.sqlite    # Timestamped uploads
    2026-02-14T18-45-00_jackedlog.sqlite
    2026-02-12T09-00-00_jackedlog.sqlite
  metadata.json                              # Optional: backup index
```

Each upload creates a new timestamped file. The "latest" is determined by filename sorting or a simple metadata index. Old backups can be cleaned up by a configurable retention policy.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Using Drift on the Server

**What:** Importing the app's Drift table definitions into the server, running migrations, using Drift queries.
**Why bad:** Creates tight coupling between app and server schema versions. Every `ALTER TABLE` in the app requires a matching server update. The server would need `build_runner` and code generation for what amounts to read-only SELECT queries.
**Instead:** Use raw `sqlite3` package with SQL strings.

### Anti-Pattern 2: Importing Data Into a Server Database

**What:** Parsing the uploaded SQLite file and inserting rows into a server-side PostgreSQL or separate SQLite database.
**Why bad:** Data transformation is lossy, fragile, and maintenance-heavy. For a single-user system, there is zero benefit to a separate database. The uploaded file IS the database.
**Instead:** Open the uploaded file directly with `sqlite3.open()`.

### Anti-Pattern 3: Building a SPA Frontend

**What:** Using React/Vue/Angular or Flutter Web for the dashboard.
**Why bad:** Adds an entire frontend build toolchain (Node.js, npm, webpack/vite) to what should be a simple read-only dashboard. Increases Docker image size. Requires API endpoint design for every dashboard view.
**Instead:** Server-rendered HTML with Dart string templates. Only use JS for Chart.js graphs.

### Anti-Pattern 4: Auto-Sync / Background Push

**What:** Having the app automatically push backups to the server on every workout completion or on a timer.
**Why bad:** Violates the "offline-first, user controls when data leaves device" principle. Adds background service complexity, battery drain concerns, failure retry logic, and connectivity state management.
**Instead:** Manual push via explicit user action in settings. Simple, predictable, no surprises.

### Anti-Pattern 5: Shared Dart Package for Models

**What:** Creating a `packages/shared/` package with common data classes used by both app and server.
**Why bad:** Forces either Drift dependency in server (bad) or mapping layer in app (useless overhead). The interface between app and server is HTTP file upload -- there are no shared typed objects to pass.
**Instead:** Server defines its own simple query result types. SQL patterns are documented, not shared via code.

---

## Suggested Build Order

### Phase 1: Server Foundation

**Build:** Shelf server skeleton, API key auth, backup upload endpoint, backup file storage
**Why first:** This is the core server infrastructure. Everything else depends on receiving and storing backup files.
**Integration:** None with app yet -- test with `curl`
**Deliverable:** `curl -X POST -H "X-API-Key: test" --data-binary @jackedlog.sqlite http://localhost:8080/api/backup` stores the file

### Phase 2: Dashboard Core

**Build:** BackupDatabase query layer, HTML templates, dashboard overview page, workout history page
**Why second:** Once backups are stored, the server needs to read and display them.
**Integration:** Opens uploaded SQLite files, runs queries
**Deliverable:** Browser shows workout history and basic stats from latest backup

### Phase 3: App Integration

**Build:** Settings schema migration (v66), server settings UI, push backup service
**Why third:** Server is functional and testable before app changes begin. App changes are minimal (2 columns + 1 new page + 1 HTTP service).
**Integration:** `database.dart` migration, `data_settings.dart` link, new `server_settings.dart` page
**Deliverable:** User can configure server URL in app and push backup with one tap

### Phase 4: Dashboard Features

**Build:** Charts/graphs page (Chart.js), PR display, heatmap, backup management page (list/download/delete)
**Why last:** Rich dashboard features are additive. The core loop (push backup, view data) works before this phase.
**Integration:** More queries in BackupDatabase, more HTML templates
**Deliverable:** Full-featured dashboard matching the app's graph capabilities

### Phase 5: Docker + Deployment

**Build:** Dockerfile, docker-compose.yml, deployment documentation
**Why last-ish:** Can be done in parallel with Phase 4. The server runs locally during development.
**Integration:** None -- packaging only
**Deliverable:** `docker compose up` runs the complete server

---

## Scalability Considerations

| Concern | At 1 backup | At 100 backups | At 1000 backups |
|---------|-------------|----------------|-----------------|
| Disk space | ~500 KB | ~50 MB | ~500 MB |
| Query speed | Instant | Instant (only queries latest) | Instant (only queries latest) |
| Backup list load | Instant | ~10ms (directory listing) | ~100ms (may need index) |
| Docker image size | ~15 MB | Same | Same |
| Memory usage | ~20 MB | ~25 MB (cached DB connection) | Same |

The backup retention policy controls disk growth. Recommended: keep last 30 daily backups (configurable). At ~500 KB per backup, 30 backups = ~15 MB total. Even 1000 backups at 500 MB is trivial for any modern server.

---

## Sources

**HIGH confidence (codebase analysis):**
- `lib/database/database.dart` -- schema version 65, migration patterns, 9 Drift tables
- `lib/database/gym_sets.dart` -- raw SQL analytics queries (strength, cardio, records, RPMs)
- `lib/database/settings.dart` -- 59 columns in Settings table
- `lib/export_data.dart` -- WAL checkpoint + file export pattern
- `lib/backup/auto_backup_service.dart` -- backup file naming, retention policy
- `lib/import_data.dart` -- database file import pattern (close, copy, reopen)
- `lib/main.dart` -- Provider registration, global `db` singleton
- `pubspec.yaml` -- existing dependencies (http 1.2.0, sqlite3 2.4.0, drift 2.28.1)

**HIGH confidence (official documentation):**
- [sqlite3 Dart package](https://pub.dev/packages/sqlite3) -- server-side SQLite access without Flutter
- [shelf package](https://pub.dev/packages/shelf) -- Dart HTTP server framework (dart-lang maintained)
- [shelf_router](https://pub.dev/packages/shelf_router) -- request routing (v1.1.4)
- [shelf_static](https://pub.dev/packages/shelf_static) -- static file serving
- [Dart pub workspaces](https://dart.dev/tools/pub/workspaces) -- monorepo support (Dart 3.6+)
- [Drift setup](https://drift.simonbinder.eu/setup/) -- confirms drift core is pure Dart, NativeDatabase.createInBackground for server

**MEDIUM confidence (community/verified):**
- [Official Dart Docker image](https://hub.docker.com/_/dart) -- multi-stage build with `FROM scratch`, AOT compilation
- [shelf_cors_headers](https://pub.dev/packages/shelf_cors_headers) -- CORS middleware for shelf

---

*Architecture analysis: 2026-02-15*
