# Phase 10: Server Foundation - Research

**Researched:** 2026-02-15
**Domain:** Dart web server, Docker deployment, SQLite backup management
**Confidence:** HIGH

## Summary

This phase creates a standalone Dart web server packaged in Docker that receives, validates, and stores SQLite backup files from the JackedLog app. The server provides a REST API for backup CRUD operations, a server-rendered HTML management page, and a tiered retention policy for automatic cleanup.

The standard approach is shelf + shelf_router (Dart team's HTTP framework) with the sqlite3 package for server-side SQLite validation. The server lives as a separate Dart project (`server/`) in the same repository, compiled to a native executable via `dart compile exe`, and deployed in a multi-stage Docker image using `FROM scratch` for minimal size (~10-25MB).

The app already has a GFS retention policy implementation in `auto_backup_service.dart` that can serve as a direct reference for the server-side retention logic. The backup file naming convention (`jackedlog_backup_YYYY-MM-DD.db`) is established and must be matched. The database schema version (currently 65) is stored via SQLite's `PRAGMA user_version` and can be read server-side with the sqlite3 package.

**Primary recommendation:** Use shelf + shelf_router for the HTTP server, sqlite3 package for backup validation, and a multi-stage Docker build with `FROM scratch` for deployment.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shelf | 1.4.2 | HTTP request/response handling | Dart team's official web server framework (tools.dart.dev), 1020 likes, 4.5M downloads |
| shelf_router | 1.1.4 | URL routing with path parameters | Official companion to shelf, supports URL params and nested routers |
| sqlite3 | 3.1.5 | SQLite FFI bindings (no Flutter dependency) | Same author as drift (simolus3), works in pure Dart, bundles SQLite via build hooks |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shelf_multipart | 2.0.1 | Parse multipart/form-data file uploads | Handling backup file uploads via POST |
| shelf_static | 1.1.3 | Serve static files from directory | Not needed if using server-rendered HTML responses |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| shelf + shelf_router | dart_frog 1.2.6 | dart_frog adds file-based routing, CLI tooling, and code gen, but requires dart_frog_cli in Docker build stage, adds complexity for only ~6 endpoints. shelf is simpler and more direct for this use case |
| shelf_multipart | Raw multipart parsing | shelf_multipart handles edge cases (boundaries, streaming) that are error-prone to hand-roll |
| sqlite3 (FFI) | drift (ORM) | drift is overkill for read-only validation; sqlite3 is sufficient for `PRAGMA quick_check` and `PRAGMA user_version` |

**Installation (pubspec.yaml for server/):**
```yaml
dependencies:
  shelf: ^1.4.2
  shelf_router: ^1.1.4
  sqlite3: ^3.1.5
  shelf_multipart: ^2.0.1
```

## Architecture Patterns

### Recommended Project Structure
```
server/
├── bin/
│   └── server.dart           # Entry point: parse env vars, start server
├── lib/
│   ├── api/
│   │   ├── backup_api.dart   # POST/GET/DELETE backup endpoints
│   │   ├── health_api.dart   # GET /api/health endpoint
│   │   └── manage_page.dart  # Server-rendered HTML management page
│   ├── middleware/
│   │   ├── auth.dart         # Bearer token authentication middleware
│   │   ├── cors.dart         # CORS middleware (allow all origins)
│   │   └── logging.dart      # Request logging middleware
│   ├── services/
│   │   ├── backup_service.dart   # Backup storage, validation, retention logic
│   │   └── sqlite_validator.dart # PRAGMA quick_check, user_version extraction
│   └── config.dart           # Environment variable parsing
├── pubspec.yaml
├── Dockerfile
├── docker-compose.yml
└── .dockerignore
```

### Pattern 1: Shelf Pipeline with Router
**What:** Compose middleware and route handlers using shelf's Pipeline
**When to use:** All requests flow through auth middleware before reaching route handlers
**Example:**
```dart
// Source: Context7 /dart-lang/shelf
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final router = Router();

  // Health check (no auth)
  router.get('/api/health', healthHandler);

  // Authenticated API routes
  router.post('/api/backup', uploadBackupHandler);
  router.get('/api/backups', listBackupsHandler);
  router.get('/api/backup/<filename>', downloadBackupHandler);
  router.delete('/api/backup/<filename>', deleteBackupHandler);

  // Management page (auth via query param)
  router.get('/manage', managePageHandler);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware(authMiddleware(apiKey))
      .addHandler(router.call);

  final server = await io.serve(handler, '0.0.0.0', port);
  print('Server listening on port $port');
}
```

### Pattern 2: Bearer Token Auth Middleware
**What:** Custom shelf middleware that validates Authorization: Bearer <token> header
**When to use:** All API endpoints except health check
**Example:**
```dart
Middleware authMiddleware(String apiKey) {
  return (Handler innerHandler) {
    return (Request request) {
      // Skip auth for health check
      if (request.url.path == 'api/health') {
        return innerHandler(request);
      }

      // Skip auth for manage page (uses query param)
      if (request.url.path == 'manage') {
        final key = request.url.queryParameters['key'];
        if (key != apiKey) {
          return Response.forbidden('Invalid API key');
        }
        return innerHandler(request);
      }

      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(401, body: '{"error": "Missing authorization"}');
      }

      final token = authHeader.substring(7);
      if (token != apiKey) {
        return Response.forbidden('{"error": "Invalid API key"}');
      }

      return innerHandler(request);
    };
  };
}
```

### Pattern 3: SQLite Backup Validation
**What:** Open uploaded .db file with sqlite3, run PRAGMA quick_check and read user_version
**When to use:** On every backup upload (SERVER-01)
**Example:**
```dart
import 'package:sqlite3/sqlite3.dart';

class ValidationResult {
  final bool isValid;
  final int? dbVersion;
  final String? error;
  ValidationResult({required this.isValid, this.dbVersion, this.error});
}

ValidationResult validateBackup(String filePath) {
  try {
    final db = sqlite3.open(filePath, mode: OpenMode.readOnly);
    try {
      // Run integrity check
      final result = db.select('PRAGMA quick_check');
      final status = result.first.values.first as String;
      if (status != 'ok') {
        return ValidationResult(isValid: false, error: 'Integrity check failed: $status');
      }

      // Read database version
      final versionResult = db.select('PRAGMA user_version');
      final version = versionResult.first.values.first as int;

      return ValidationResult(isValid: true, dbVersion: version);
    } finally {
      db.dispose();
    }
  } catch (e) {
    return ValidationResult(isValid: false, error: 'Not a valid SQLite database: $e');
  }
}
```

### Pattern 4: Server-Rendered HTML Response
**What:** Return HTML string directly from handler as Response body
**When to use:** Management page (SERVER-07)
**Example:**
```dart
Response managePageHandler(Request request) {
  final backups = backupService.listBackups();
  final totalSize = backupService.totalStorageBytes();

  final html = '''
  <!DOCTYPE html>
  <html>
  <head>
    <title>JackedLog Backups</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>/* inline styles */</style>
  </head>
  <body>
    <h1>Backup Management</h1>
    <p>Total storage: ${_formatBytes(totalSize)}</p>
    <table>
      <tr><th>Date</th><th>Size</th><th>DB Version</th><th>Status</th><th>Actions</th></tr>
      ${backups.map((b) => '<tr>...</tr>').join()}
    </table>
  </body>
  </html>
  ''';

  return Response.ok(html, headers: {'content-type': 'text/html'});
}
```

### Anti-Patterns to Avoid
- **Don't use dart_frog CLI in Dockerfile:** Adds build complexity and image size. Use `dart compile exe` directly on the shelf server binary.
- **Don't use drift on the server:** Drift is an ORM with code generation and Flutter dependencies. The server only needs sqlite3 for PRAGMA commands; no ORM layer needed.
- **Don't store backup metadata in a separate database:** The filesystem IS the database of record. Each `.db` file contains its own metadata (user_version). File modification time and size come from the filesystem. No need for a metadata database.
- **Don't accept arbitrary filenames from uploads:** Always name files server-side using the `jackedlog_backup_YYYY-MM-DD.db` pattern to prevent path traversal and ensure consistency.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multipart form parsing | Custom boundary parsing | shelf_multipart 2.0.1 | Multipart boundaries, streaming, and edge cases are error-prone; the package handles them correctly |
| SQLite validation | File header byte checking | sqlite3 package + PRAGMA quick_check | PRAGMA quick_check validates B-tree structure, not just magic bytes |
| HTTP request logging | Custom print statements | shelf's built-in `logRequests()` middleware | Already formats method, path, status code, and duration |
| CORS headers | Manual header injection | Simple custom middleware (see below) | Only ~10 lines, but must handle preflight OPTIONS requests |

**Key insight:** The server's scope is intentionally small (6 API endpoints + 1 HTML page). The temptation is to over-engineer with frameworks, ORMs, or template engines. shelf + sqlite3 + filesystem is the right level of abstraction.

## Common Pitfalls

### Pitfall 1: SQLite File Locking on Concurrent Access
**What goes wrong:** Two requests try to validate/read the same .db file simultaneously, causing SQLITE_BUSY errors.
**Why it happens:** sqlite3 uses file-level locking; opening a file for validation while another process reads it can conflict.
**How to avoid:** Open backup files in `OpenMode.readOnly` mode for validation. For uploads, write to a temp file first, validate, then atomically rename to final path.
**Warning signs:** Intermittent 500 errors on backup upload or list endpoints.

### Pitfall 2: Large File Upload Memory Exhaustion
**What goes wrong:** Reading the entire uploaded file into memory before writing to disk causes OOM for large backups.
**Why it happens:** Naive implementation reads `request.read()` into a single byte list.
**How to avoid:** Stream the upload directly to a temporary file, then validate. Use `IOSink` and pipe the request body stream.
**Warning signs:** Server crashes or slows dramatically with backups >100MB.

### Pitfall 3: Docker Image Missing Native Libraries for sqlite3
**What goes wrong:** AOT-compiled binary works in build stage but crashes in `FROM scratch` stage with "libsqlite3.so not found."
**Why it happens:** The sqlite3 Dart package bundles SQLite via build hooks, but the resulting shared library must be copied to the scratch image.
**How to avoid:** The sqlite3 package (3.1.5) bundles SQLite natively via Dart build hooks. When using `dart compile exe`, SQLite is statically linked into the executable. Verify by running the compiled binary in a minimal container.
**Warning signs:** "Failed to load dynamic library" errors at runtime.

### Pitfall 4: Same-Day Backup Overwrite Without Warning
**What goes wrong:** User pushes two backups on the same day; second silently overwrites the first.
**Why it happens:** File naming is date-based (`jackedlog_backup_2026-02-15.db`), so same-day uploads produce the same filename.
**How to avoid:** This is actually the desired behavior (matches the app's auto-backup which also overwrites same-day files). Document this as expected behavior. If needed in the future, add a timestamp suffix, but for now keep consistent with the app.
**Warning signs:** N/A -- this is by design.

### Pitfall 5: Retention Policy Deleting the Only Backup
**What goes wrong:** Retention cleanup runs and deletes backups the user expects to keep.
**Why it happens:** Edge cases in the GFS algorithm (e.g., only 1 backup exists, or all backups are from the same week).
**How to avoid:** Always keep the most recent backup regardless of retention rules. The app's existing implementation in `auto_backup_service.dart` (lines 149-258) handles this correctly and should serve as the reference implementation.
**Warning signs:** User complains that backups disappeared.

### Pitfall 6: Missing /runtime/ Copy in Dockerfile
**What goes wrong:** Docker image builds but container crashes immediately with missing library errors.
**Why it happens:** The `FROM scratch` image needs specific runtime files from the build stage (`/runtime/` contains glibc, ca-certificates, etc.).
**How to avoid:** Always copy `/runtime/` from the build stage. The official Dart Docker documentation specifies this pattern explicitly.
**Warning signs:** Container exits immediately with signal 127 or library-not-found errors.

## Code Examples

Verified patterns from official sources:

### File Upload Handler with Streaming to Disk
```dart
// Streams uploaded bytes to a temp file, then validates and renames
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

Future<Response> uploadBackupHandler(Request request) async {
  if (request.multipart() case var multipart?) {
    await for (final part in multipart.parts) {
      // Write to temp file
      final tempFile = File('$dataDir/.upload_temp');
      final sink = tempFile.openWrite();
      await sink.addStream(part);
      await sink.close();

      // Validate the uploaded database
      final validation = validateBackup(tempFile.path);
      if (!validation.isValid) {
        await tempFile.delete();
        return Response(400,
          body: '{"error": "${validation.error}"}',
          headers: {'content-type': 'application/json'});
      }

      // Rename to final path
      final today = DateTime.now();
      final filename = 'jackedlog_backup_${today.toIso8601String().substring(0, 10)}.db';
      await tempFile.rename('$dataDir/$filename');

      // Run retention cleanup
      await cleanupOldBackups(dataDir);

      return Response.ok(
        '{"filename": "$filename", "dbVersion": ${validation.dbVersion}}',
        headers: {'content-type': 'application/json'});
    }
  }

  return Response(400,
    body: '{"error": "No file uploaded"}',
    headers: {'content-type': 'application/json'});
}
```

### Health Check Endpoint
```dart
Response healthHandler(Request request) {
  return Response.ok(
    '{"status": "ok", "version": "1.0.0", "uptime": ${_uptimeSeconds()}}',
    headers: {'content-type': 'application/json'},
  );
}
```

### Reading DB Version from Backup File
```dart
// Source: sqlite3 package API
import 'package:sqlite3/sqlite3.dart';

int? getDbVersion(String filePath) {
  try {
    final db = sqlite3.open(filePath, mode: OpenMode.readOnly);
    try {
      final result = db.select('PRAGMA user_version');
      return result.first.values.first as int;
    } finally {
      db.dispose();
    }
  } catch (e) {
    return null;
  }
}
```

### CORS Middleware (Allow All Origins)
```dart
Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};
```

### Multi-Stage Dockerfile
```dockerfile
# Source: Official Dart Docker Hub + Context7 dart_frog custom Dockerfile pattern
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec first for dependency caching
COPY server/pubspec.* ./
RUN dart pub get

# Copy source and compile
COPY server/ .
RUN dart compile exe bin/server.dart -o bin/server

# Minimal runtime image
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

# Create data directory mount point
VOLUME ["/data"]

EXPOSE 8080

CMD ["/app/bin/server"]
```

### docker-compose.yml
```yaml
version: '3.8'
services:
  jackedlog-server:
    build: .
    ports:
      - "${PORT:-8080}:8080"
    environment:
      - JACKED_API_KEY=${JACKED_API_KEY}
      - PORT=8080
      - DATA_DIR=/data
    volumes:
      - backup_data:/data
    restart: unless-stopped

volumes:
  backup_data:
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| dart:io HttpServer directly | shelf + shelf_router | Shelf stable since 2020+ | Middleware composition, simpler request handling |
| sqlite3 requires manual .so bundling | sqlite3 3.x with Dart build hooks | sqlite3 3.0+ | SQLite bundled automatically, no manual library management |
| Dockerfile with dart2native | dart compile exe | Dart 2.14+ (2021) | Official AOT compilation command |
| FROM alpine for minimal images | FROM scratch with /runtime/ | Official Dart Docker docs | Even smaller images (~10-25MB vs ~50MB+) |

**Deprecated/outdated:**
- `dart2native`: Replaced by `dart compile exe`
- `package:shelf_io` serve API is stable and unchanged
- `package:aqueduct`: Abandoned framework, do not use

## Open Questions

1. **sqlite3 static linking in scratch image**
   - What we know: sqlite3 3.1.5 uses Dart build hooks to bundle SQLite. `dart compile exe` should statically link everything.
   - What's unclear: Whether `/runtime/` from the official Dart Docker image includes all needed native libraries or if sqlite3's bundled .so needs explicit copying.
   - Recommendation: Test early in implementation. Build the Docker image and verify the binary runs in scratch. If sqlite3 .so is missing, copy it explicitly from the build stage.

2. **Multipart vs raw body for file upload**
   - What we know: shelf_multipart handles multipart/form-data. Alternatively, the app could POST the raw .db file bytes directly with `Content-Type: application/octet-stream`.
   - What's unclear: Which approach the app (Phase 11) will use to upload.
   - Recommendation: Support both. Check Content-Type: if multipart, use shelf_multipart; if octet-stream, read body directly. This keeps the API flexible for curl/testing and for the app.

3. **Default port**
   - What we know: Context decisions leave this to Claude's discretion.
   - Recommendation: Use port 8080. It's the standard non-privileged HTTP port, doesn't conflict with common services, and matches Dart/Docker conventions.

## Sources

### Primary (HIGH confidence)
- Context7 `/dart-lang/shelf` - Routing, middleware, Pipeline pattern, static file serving (13 code snippets)
- Context7 `/verygoodopensource/dart_frog` - File upload, auth middleware, Docker deployment, project structure (503 code snippets)
- [pub.dev shelf 1.4.2](https://pub.dev/packages/shelf) - Version, publisher (tools.dart.dev), API overview
- [pub.dev shelf_router 1.1.4](https://pub.dev/packages/shelf_router) - Version, publisher (tools.dart.dev)
- [pub.dev sqlite3 3.1.5](https://pub.dev/packages/sqlite3) - Version, pure Dart support, FFI bindings, build hooks
- [pub.dev shelf_multipart 2.0.1](https://pub.dev/packages/shelf_multipart) - Version, multipart parsing API
- [dart.dev/tools/dart-compile](https://dart.dev/tools/dart-compile) - AOT exe compilation, flags, output format
- Existing codebase: `lib/backup/auto_backup_service.dart` - GFS retention implementation, file naming convention
- Existing codebase: `lib/database/database.dart` - Schema version 65, `PRAGMA user_version` usage

### Secondary (MEDIUM confidence)
- [Dart for Server Apps: Shelf & Dart Frog](https://medium.com/@flutter-app/dart-for-server-apps-using-shelf-dart-frog-for-apis-8387d3b0067b) - shelf vs dart_frog comparison
- [Build slim Docker images for Dart](https://medium.com/google-cloud/build-slim-docker-images-for-dart-apps-ee98ea1d1cf7) - Multi-stage build with scratch pattern
- [Dart Docker Hub](https://hub.docker.com/_/dart) - Official image tags and recommended Dockerfile
- [dart.dev server tutorial](https://dart.dev/tutorials/server/httpserver) - Official server recommendations (shelf, dart_frog)
- [SQLite PRAGMA reference](https://www.sqlite.org/pragma.html) - quick_check and user_version documentation

### Tertiary (LOW confidence)
- [Exploring Best Dart Frameworks 2025](https://dartcodelabs.com/exploring-the-best-dart-frameworks-for-backend-development-in-2025/) - Framework landscape overview
- [Choosing Backend for Flutter](https://www.victorcarreras.dev/2024/06/choosing-best-backend-framework-for.html) - Framework comparison

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages verified via pub.dev with current versions, publishers confirmed (tools.dart.dev for shelf, simolus3 for sqlite3)
- Architecture: HIGH - shelf Pipeline pattern verified via Context7 with code examples, Docker pattern from official Dart docs
- Pitfalls: MEDIUM - Most pitfalls derived from general SQLite/Docker knowledge and existing app code patterns. sqlite3 static linking in scratch needs validation during implementation

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (30 days - stable ecosystem, no fast-moving changes expected)
