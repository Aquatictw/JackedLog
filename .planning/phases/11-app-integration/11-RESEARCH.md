# Phase 11: App Integration - Research

**Researched:** 2026-02-15
**Domain:** Flutter HTTP client, Settings UI, database migration, file upload
**Confidence:** HIGH

## Summary

This phase adds client-side server integration to the existing Flutter app: a server settings page for URL/API key configuration, a connection test, a manual push-backup button with progress, and last-push status display. The app already has all needed infrastructure: the `http` package (^1.2.0) is in `pubspec.yaml`, the Settings table uses Drift with SettingsCompanion for updates, and the backup system (`auto_backup_service.dart`, `export_data.dart`) provides proven patterns for reading and sending the SQLite database file.

The server (Phase 10) accepts backup uploads via `POST /api/backup` with `Authorization: Bearer <token>` and supports both `multipart/form-data` and raw `application/octet-stream` content types. The health check endpoint (`GET /api/health`) is public and returns `{"status": "ok", "version": "...", "uptime": ...}`. These two endpoints are the only ones this phase needs to call.

The Dart `http` package does not support upload progress callbacks natively. However, since backup files are small SQLite databases (typically 1-10 MB), a simpler approach is recommended: use `dart:io` `HttpClient` to send the raw file bytes as `application/octet-stream` (which the server already supports), and track progress by chunking the file read and monitoring bytes sent. Alternatively, use an indeterminate `LinearProgressIndicator` during upload since the files are small enough that progress tracking adds complexity without meaningful user benefit.

**Primary recommendation:** Use `dart:io` `HttpClient` for both connection test and file upload. Send backup as raw `application/octet-stream` (server supports it). Use `LinearProgressIndicator` in indeterminate mode during upload. Store server URL, API key, last push timestamp, and last push status as new columns in the Settings table (database version 66).

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| http | 1.2.0 | HTTP client for connection test (GET) | Already in pubspec.yaml, used by Spotify integration |
| dart:io HttpClient | SDK | Raw file upload with octet-stream | Available on all non-web platforms, supports streaming body |
| drift | 2.28.1 | Settings table schema + migration | Already the project ORM, handles all persistence |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| path_provider | 2.1.2 | Locate database file for upload | Already in project, used by backup service |
| path | 1.8.3 | Join paths to database file | Already in project |
| timeago | 3.2.2 | Format "last pushed" timestamp | Already in project, used by auto-backup settings |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| dart:io HttpClient | http MultipartRequest | MultipartRequest doesn't support progress; octet-stream is simpler and server already supports it |
| dart:io HttpClient | dio package | Adds a new dependency for one upload endpoint; overkill when files are small |
| Indeterminate progress bar | Custom stream progress tracking | Adds complexity for files that upload in <2 seconds on most connections |

**Installation:** No new dependencies needed. All libraries already in pubspec.yaml.

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── server/                        # NEW: Server integration feature
│   ├── server_settings_page.dart  # Server URL + API key settings page
│   └── backup_push_service.dart   # Connection test + file upload logic
├── settings/
│   ├── settings_page.dart         # ADD: "Backup Server" list tile entry
│   └── data_settings.dart         # Existing (no changes needed)
├── backup/
│   └── auto_backup_settings.dart  # ADD: Push button + status display
└── database/
    ├── settings.dart              # ADD: 4 new columns
    └── database.dart              # ADD: migration v65→v66
```

### Pattern 1: Settings Sub-Page Navigation (Existing Pattern)
**What:** Dedicated settings page accessible via ListTile in main SettingsPage
**When to use:** This is the established pattern — every settings category (Appearance, Data, Spotify, etc.) uses it
**Example:**
```dart
// Source: lib/settings/settings_page.dart (existing pattern)
// In SettingsPage's ListView:
ListTile(
  leading: const Icon(Icons.cloud_upload),
  title: const Text('Backup Server'),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const ServerSettingsPage(),
    ),
  ),
),
```

### Pattern 2: Database Settings Update (Existing Pattern)
**What:** Write to settings via SettingsCompanion, stream subscription auto-notifies
**When to use:** Any setting change — the reactive pipeline is already wired
**Example:**
```dart
// Source: lib/settings/settings_state.dart + lib/settings/spotify_settings.dart
// Write new values:
await db.settings.update().write(
  SettingsCompanion(
    serverUrl: Value(url),
    serverApiKey: Value(apiKey),
  ),
);
// SettingsState auto-notifies listeners via stream subscription
```

### Pattern 3: HTTP Connection Test via Health Endpoint
**What:** GET /api/health to validate server reachability and API key
**When to use:** Connection test button on server settings page
**Example:**
```dart
// Connection test: call health endpoint then an authenticated endpoint
import 'package:http/http.dart' as http;

Future<(bool, String)> testConnection(String serverUrl, String apiKey) async {
  try {
    // Test server reachability (health is public)
    final healthResponse = await http.get(
      Uri.parse('$serverUrl/api/health'),
    ).timeout(const Duration(seconds: 10));

    if (healthResponse.statusCode != 200) {
      return (false, 'Server unreachable (${healthResponse.statusCode})');
    }

    // Test API key by calling authenticated endpoint
    final authResponse = await http.get(
      Uri.parse('$serverUrl/api/backups'),
      headers: {'Authorization': 'Bearer $apiKey'},
    ).timeout(const Duration(seconds: 10));

    if (authResponse.statusCode == 401 || authResponse.statusCode == 403) {
      return (false, 'Invalid API key');
    }
    if (authResponse.statusCode != 200) {
      return (false, 'Server error (${authResponse.statusCode})');
    }

    return (true, 'Connected successfully');
  } on TimeoutException {
    return (false, 'Connection timed out');
  } on SocketException catch (e) {
    return (false, 'Connection refused: ${e.message}');
  } catch (e) {
    return (false, 'Error: $e');
  }
}
```

### Pattern 4: File Upload as Octet-Stream
**What:** Read SQLite file, POST raw bytes with Bearer auth
**When to use:** Push backup button on the backup page
**Example:**
```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<(bool, String, int?)> pushBackup(String serverUrl, String apiKey) async {
  try {
    // Checkpoint WAL first (same as existing backup code)
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    // Read database file
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'jackedlog.sqlite'));
    final bytes = await dbFile.readAsBytes();

    // POST as raw octet-stream
    final uri = Uri.parse('$serverUrl/api/backup');
    final request = await HttpClient().postUrl(uri);
    request.headers.set('Authorization', 'Bearer $apiKey');
    request.headers.set('Content-Type', 'application/octet-stream');
    request.contentLength = bytes.length;
    request.add(bytes);

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      return (true, 'Backup pushed successfully', bytes.length);
    } else {
      return (false, 'Upload failed (${response.statusCode})', null);
    }
  } on SocketException catch (e) {
    return (false, 'Connection refused: ${e.message}', null);
  } on TimeoutException {
    return (false, 'Upload timed out', null);
  } catch (e) {
    return (false, 'Error: $e', null);
  }
}
```

### Anti-Patterns to Avoid
- **Don't add dio as a dependency:** The app already has `http` and `dart:io`. Adding dio for one upload endpoint is unnecessary bloat.
- **Don't create a new Provider/ChangeNotifier for server state:** The server URL, API key, and push status all belong in Settings — the existing SettingsState + SettingsCompanion pipeline handles this.
- **Don't use multipart upload:** The server supports octet-stream, which is simpler. Multipart adds overhead for no benefit when sending a single file.
- **Don't store the API key in plaintext in SharedPreferences:** It already goes in the Settings table (SQLite), which is the app's established secret storage pattern (Spotify tokens are stored the same way).

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Last pushed: 5 min ago" display | Custom time formatting | `timeago` package (already in project) | Handles all edge cases (just now, minutes, hours, days) |
| Database file location | Custom path construction | `getApplicationDocumentsDirectory()` + `path.join` | Already used in `auto_backup_service.dart` and `export_data.dart` |
| WAL checkpoint before upload | Skip it or do it differently | `PRAGMA wal_checkpoint(TRUNCATE)` | Exact same call used in `auto_backup_service.dart:110` and `export_data.dart:159` |
| URL validation | Custom regex | `Uri.tryParse()` + scheme check | Dart's built-in URL parsing handles all edge cases |
| Settings persistence | New storage mechanism | Drift Settings table + SettingsCompanion | Established pattern, auto-notifies UI via stream |

**Key insight:** Nearly every infrastructure piece needed for this phase already exists in the codebase. The patterns for reading the database file, checkpointing WAL, making HTTP requests with Bearer tokens, persisting settings, and displaying "time ago" text are all proven. This phase is primarily wiring existing patterns to new UI, not building new infrastructure.

## Common Pitfalls

### Pitfall 1: Forgetting WAL Checkpoint Before Upload
**What goes wrong:** Uploaded database file is missing recent changes because they're still in the WAL file.
**Why it happens:** SQLite WAL mode stores recent writes in a separate file. Reading the main `.sqlite` file without checkpointing gives stale data.
**How to avoid:** Call `await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)')` before reading the file, exactly as `auto_backup_service.dart:110` and `export_data.dart:159` already do.
**Warning signs:** Backup on server is missing the user's most recent workout.

### Pitfall 2: URL Trailing Slash Inconsistency
**What goes wrong:** User enters `https://server.com/` (with trailing slash) and the app constructs `https://server.com//api/health` (double slash).
**Why it happens:** Naive string concatenation of URL + path.
**How to avoid:** Strip trailing slashes from the server URL before storing. Use `url.endsWith('/') ? url.substring(0, url.length - 1) : url` during validation/save.
**Warning signs:** Connection test fails even though the URL is correct.

### Pitfall 3: Missing Internet Permission on Android
**What goes wrong:** App crashes or throws `SocketException` when trying to reach the server.
**Why it happens:** Android requires `INTERNET` permission in `AndroidManifest.xml`.
**How to avoid:** Already verified: `<uses-permission android:name="android.permission.INTERNET" />` is present in `android/app/src/main/AndroidManifest.xml` (line 4), debug, and profile manifests. No action needed.
**Warning signs:** N/A -- already handled.

### Pitfall 4: Not Handling Self-Signed Certificates
**What goes wrong:** Users with self-signed HTTPS certificates get connection errors.
**Why it happens:** Dart's HTTP client rejects self-signed certificates by default.
**How to avoid:** For now, don't handle this — keep it as a known limitation. If needed later, `dart:io` HttpClient supports custom `badCertificateCallback`. Document this as a future enhancement rather than adding complexity now (YAGNI).
**Warning signs:** User reports "certificate not valid" errors with their self-hosted server.

### Pitfall 5: Blocking UI During Upload
**What goes wrong:** UI freezes during file read or upload.
**Why it happens:** Reading a multi-MB file synchronously on the main isolate.
**How to avoid:** Use async `await dbFile.readAsBytes()` (which is already async) and ensure the upload is in an async function. The file read is already non-blocking because it's an `async` method.
**Warning signs:** Jank or ANR during push.

### Pitfall 6: Database Migration Breaking Re-import
**What goes wrong:** User exports backup from new version (v66) and can't import it on old version (v65).
**Why it happens:** New columns added to settings table; old app doesn't know about them.
**How to avoid:** The new columns must use `.nullable()` or `.withDefault()` so that older databases (which lack these columns) still work with the new code, and newer databases degrade gracefully if columns are ignored by older code. Drift's import logic already handles extra columns by ignoring them.
**Warning signs:** Import crashes or settings table corruption after upgrade/downgrade.

## Code Examples

Verified patterns from the existing codebase:

### Database Migration: Add Settings Columns (v65 to v66)
```dart
// Source: lib/database/database.dart (follow existing migration pattern)
// In settings.dart, add new columns:
TextColumn get serverUrl => text().nullable()();
TextColumn get serverApiKey => text().nullable()();
DateTimeColumn get lastPushTime => dateTime().nullable()();
TextColumn get lastPushStatus => text().nullable()();
// Values: null (never pushed), 'success', 'failed'

// In database.dart onUpgrade:
if (from < 66 && to >= 66) {
  await m.database.customStatement(
    'ALTER TABLE settings ADD COLUMN server_url TEXT',
  ).catchError((e) {});
  await m.database.customStatement(
    'ALTER TABLE settings ADD COLUMN server_api_key TEXT',
  ).catchError((e) {});
  await m.database.customStatement(
    'ALTER TABLE settings ADD COLUMN last_push_time INTEGER',
  ).catchError((e) {});
  await m.database.customStatement(
    'ALTER TABLE settings ADD COLUMN last_push_status TEXT',
  ).catchError((e) {});
}

// Update schemaVersion to 66
```

### Masked API Key Field with Reveal Toggle
```dart
// Pattern consistent with password fields in Material Design
TextFormField(
  controller: apiKeyController,
  obscureText: !_showApiKey,
  decoration: InputDecoration(
    labelText: 'API Key',
    suffixIcon: IconButton(
      icon: Icon(_showApiKey ? Icons.visibility : Icons.visibility_off),
      onPressed: () => setState(() => _showApiKey = !_showApiKey),
    ),
  ),
)
```

### Push Status Display (Near Push Button)
```dart
// Source: lib/backup/auto_backup_settings.dart (existing status pattern)
// Adapt the _buildBackupStatusIndicator pattern:
Widget _buildPushStatus(Setting settings) {
  if (settings.lastPushTime == null) {
    return Text('Never pushed',
      style: TextStyle(color: colorScheme.onSurfaceVariant));
  }

  final isSuccess = settings.lastPushStatus == 'success';
  return Row(
    children: [
      Icon(
        isSuccess ? Icons.check_circle : Icons.error,
        size: 16,
        color: isSuccess ? colorScheme.primary : colorScheme.error,
      ),
      const SizedBox(width: 6),
      Text(
        'Last pushed: ${timeago.format(settings.lastPushTime!)}',
        style: TextStyle(
          color: isSuccess ? colorScheme.onSurfaceVariant : colorScheme.error,
        ),
      ),
    ],
  );
}
```

### Server URL Validation
```dart
// Use Dart's built-in Uri parser
bool isValidServerUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  return true;
}

// Strip trailing slash before saving
String normalizeUrl(String url) {
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| dio for HTTP uploads | dart:io HttpClient or http package | Stable | No dependency needed for simple uploads |
| SharedPreferences for credentials | Drift settings table | App convention | Single source of truth, reactive updates |
| Custom progress tracking | Indeterminate progress bar for small files | Pragmatic choice | Simpler code, files are <10 MB |

**Deprecated/outdated:**
- `dart:html` HttpRequest progress events: Only available on web, not relevant to this mobile-first app
- `http` package progress tracking: Not supported, filed as open issue (dart-lang/http#153, #465)

## Open Questions

1. **File size for typical user database**
   - What we know: SQLite databases for workout tracking are typically 1-10 MB. The app stores workouts, sets, plans, notes, and bodyweight entries.
   - What's unclear: Whether any user has a database large enough (>50 MB) where progress tracking would matter.
   - Recommendation: Start with indeterminate progress. If users report slow uploads, add chunked progress tracking later. YAGNI.

2. **HTTPS enforcement**
   - What we know: The server URL field accepts any http/https URL. Self-hosted servers may use HTTP (no TLS).
   - What's unclear: Whether to warn users about HTTP (insecure) connections.
   - Recommendation: Accept both, but show a subtle warning icon for HTTP URLs. Keep it simple -- don't block HTTP.

## Sources

### Primary (HIGH confidence)
- Codebase: `lib/settings/settings_page.dart` - Settings sub-page navigation pattern (ListTile → Navigator.push)
- Codebase: `lib/settings/spotify_settings.dart` - Connection status UI, token storage in Settings table
- Codebase: `lib/settings/settings_state.dart` - Reactive settings via stream subscription
- Codebase: `lib/database/settings.dart` - Settings table column definitions (nullable columns with defaults)
- Codebase: `lib/database/database.dart` - Migration pattern (`if (from < N && to >= N)`, `.catchError((e) {})`)
- Codebase: `lib/backup/auto_backup_service.dart` - WAL checkpoint, file read, status tracking in Settings
- Codebase: `lib/backup/auto_backup_settings.dart` - Backup status UI, manual backup button pattern
- Codebase: `lib/export_data.dart` - Database file read + WAL checkpoint pattern
- Codebase: `lib/spotify/spotify_web_api_service.dart` - HTTP GET with Bearer token pattern
- Server: `server/lib/api/backup_api.dart` - POST /api/backup accepts octet-stream and multipart
- Server: `server/lib/middleware/auth.dart` - Bearer token authentication format
- Server: `server/lib/api/health_api.dart` - GET /api/health returns JSON status
- Context7 `/websites/pub_dev_http` - MultipartRequest, StreamedRequest, Client API

### Secondary (MEDIUM confidence)
- [dart-lang/http#153](https://github.com/dart-lang/http/issues/153) - Confirmed no progress tracking in http package
- [dart-lang/http#465](https://github.com/dart-lang/http/issues/465) - Open feature request for progress support

### Tertiary (LOW confidence)
- None - all findings verified against codebase or official sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project, no new dependencies needed
- Architecture: HIGH - All patterns derived from existing codebase (settings, backup, HTTP)
- Pitfalls: HIGH - Most pitfalls identified from existing codebase patterns and known Dart/Flutter behavior

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (30 days - stable ecosystem, app-side changes only)
