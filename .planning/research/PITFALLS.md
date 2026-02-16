# Domain Pitfalls: Self-Hosted Web Companion Server

**Domain:** Self-hosted Dart server for fitness app backup + web dashboard
**Researched:** 2026-02-15
**Codebase:** JackedLog (Flutter + Drift v65 + Provider)
**Mode:** Subsequent milestone -- adding server component to existing mobile app
**Confidence:** HIGH (most pitfalls derived from direct codebase analysis + verified research)

---

## Critical Pitfalls

Mistakes that cause data loss, corrupted backups, security breaches, or require architectural rewrites.

---

### Pitfall 1: SQLite WAL Mode Corruption During Backup Upload

**What goes wrong:** The mobile app exports its SQLite database while WAL (Write-Ahead Logging) mode is active. The exported file is missing uncommitted WAL data, or worse, the WAL file contents are interleaved with the main database file during transfer, resulting in a corrupt backup on the server.

**Why it happens:**
- SQLite databases in WAL mode consist of THREE files: `database.sqlite`, `database.sqlite-wal`, and `database.sqlite-shm`
- The WAL file contains recent transactions not yet checkpointed to the main DB file
- If you copy the main `.sqlite` file without checkpointing first, you lose uncommitted data
- If a checkpoint occurs mid-copy, the database file can be in an inconsistent state at the b-tree level
- The existing export code in `export_data.dart:158-159` already does `PRAGMA wal_checkpoint(TRUNCATE)` before copying -- but a server upload path might skip this step
- The auto-backup service in `auto_backup_service.dart:110` also checkpoints -- but a new "push to server" feature could bypass this

**Consequences:**
- Backup arrives on server with missing recent workouts
- Server tries to open a corrupt database file, crashes or returns garbage data
- User believes data is backed up safely but the backup is incomplete
- Worst case: checkpointing mid-transfer creates a structurally corrupt file that cannot be recovered

**Warning signs:**
- Backup file size is noticeably smaller than expected (WAL data missing)
- Server dashboard shows fewer recent workouts than the app
- `PRAGMA integrity_check` on server-side copy returns errors
- User's last few sets/workouts are missing from dashboard

**Prevention:**
1. **Checkpoint before reading the database for upload** -- reuse the existing pattern:
   ```dart
   await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
   ```
   This must happen on the mobile app side BEFORE reading the file bytes.

2. **Read the database file atomically** -- after checkpoint, read the entire file into memory (or a temp copy) before starting the HTTP upload. Do not stream directly from the live database file.

3. **Delete WAL/SHM before upload** -- the existing import code in `import_data.dart:101-104` already deletes WAL/SHM files. Apply the same discipline to export: after checkpoint, the WAL should be empty, but verify.

4. **Validate on the server side** -- after receiving the upload, run `PRAGMA quick_check` on the received file before accepting it:
   ```dart
   final db = sqlite3.open(uploadedFilePath);
   final result = db.select('PRAGMA quick_check');
   if (result.first['quick_check'] != 'ok') {
     // Reject the upload, return error to client
   }
   ```

5. **Use the SQLite Backup API** instead of file copy if available in the Dart sqlite3 package. The backup API handles WAL correctly without manual checkpointing. However, as of the current `sqlite3` Dart package, the backup API may not be exposed -- verify before relying on it.

**Phase to address:** Phase 1 (backup upload endpoint) -- this is day-one critical.

**Confidence:** HIGH -- Based on direct analysis of existing checkpoint code in `export_data.dart:158-159` and `auto_backup_service.dart:110`, plus [SQLite WAL documentation](https://sqlite.org/wal.html) and [SQLite forum discussion on WAL backup corruption](https://sqlite.org/forum/forumpost/905eb5e564d4df44).

---

### Pitfall 2: Schema Version Mismatch Between App and Server

**What goes wrong:** The server opens a backup database with schema version 65 (current), but a future app update bumps the schema to v66+. Older backups may be at v62, v63, etc. The server does not know how to handle any version other than what it was built against, and either crashes or reads data incorrectly.

**Why it happens:**
- The app has 65 schema versions with complex migration paths (see `database.dart` lines 60-455)
- Drift stores the schema version in SQLite's `PRAGMA user_version`
- The server needs to READ (not write) backup databases -- but Drift's `NativeDatabase` triggers migration on open if `user_version` does not match `schemaVersion`
- If the server uses Drift with `schemaVersion: 65`, opening a v63 database would trigger migration (modifying the user's backup!)
- If the server opens a v66 database (from a newer app), migration fails because the server does not know about v66

**Consequences:**
- Server accidentally modifies backup files by running migrations on them
- Server crashes when opening databases from newer app versions
- Dashboard shows wrong column names or missing data for older schema versions
- User's backup file is permanently altered by server-side migration

**Warning signs:**
- Server logs show migration errors on database open
- Dashboard works with current backups but crashes on old ones
- Backup file size changes after server reads it (migration ran)
- Different app versions produce incompatible backups

**Prevention:**
1. **Do NOT use Drift on the server.** Use the raw `sqlite3` Dart package to open backup databases in read-only mode. This bypasses Drift's migration system entirely and prevents accidental modification.

2. **Open backup databases as read-only:**
   ```dart
   final db = sqlite3.open(backupPath, mode: OpenMode.readOnly);
   ```
   Read-only mode makes accidental writes impossible.

3. **Check schema version before reading:**
   ```dart
   final version = db.select('PRAGMA user_version').first['user_version'] as int;
   if (version < MINIMUM_SUPPORTED_VERSION) {
     // Return error: backup too old
   }
   // For newer versions, read only columns that existed at our known version
   ```

4. **Query by column existence, not assumption:**
   ```dart
   // Check what columns exist before querying
   final columns = db.select("PRAGMA table_info('gym_sets')");
   final columnNames = columns.map((c) => c['name'] as String).toSet();
   // Build query using only columns that exist
   ```

5. **Never modify the backup file.** The server stores backup files as-is and opens read-only copies for the dashboard. Keep the original bytes untouched.

6. **Define a minimum supported version** (e.g., v48 -- when the `workouts` table was introduced). Reject older backups with a clear error message.

**Phase to address:** Phase 1 (server database reading layer) -- foundational decision.

**Confidence:** HIGH -- Based on direct analysis of `database.dart` migration system (65 versions, `schemaVersion => 65` at line 482) and Drift's documented behavior of running migrations on database open.

---

### Pitfall 3: Backup File Corruption During HTTP Transfer

**What goes wrong:** The SQLite database file is corrupted during HTTP upload due to network interruption, timeout, or incomplete multipart transfer. The server stores a truncated file that appears to be a valid SQLite file (has the header) but is missing pages.

**Why it happens:**
- SQLite files can be several megabytes (a year of workout data could be 5-20MB)
- Mobile networks are unreliable (switching from WiFi to cellular, tunnels, poor signal)
- HTTP multipart upload can partially complete without error if not checked
- Server accepts the file based on HTTP status 200 without verifying content integrity
- No checksum verification between what the app sent and what the server received

**Consequences:**
- Server stores a corrupt backup as the "latest" backup
- Previous good backup may be overwritten
- User discovers corruption only when trying to restore (worst time)
- Dashboard shows partial data or crashes when querying corrupt pages

**Warning signs:**
- Backup file size is significantly less than expected
- `PRAGMA integrity_check` fails on received file
- Upload succeeds (HTTP 200) but subsequent dashboard queries fail
- File size does not match Content-Length header

**Prevention:**
1. **Client-side checksum:** Calculate SHA-256 of the database file before upload. Send as a header or request parameter:
   ```dart
   // App side
   final bytes = await dbFile.readAsBytes();
   final hash = sha256.convert(bytes).toString();
   // Send hash as X-Checksum header
   ```

2. **Server-side verification:** After receiving the upload, calculate SHA-256 and compare:
   ```dart
   // Server side
   final receivedHash = sha256.convert(receivedBytes).toString();
   if (receivedHash != request.headers['X-Checksum']) {
     return Response(400, body: 'Checksum mismatch - upload corrupted');
   }
   ```

3. **Run `PRAGMA quick_check`** on the received file after checksum passes. This catches structural corruption that would not be caught by checksum alone (e.g., file was corrupt before upload).

4. **Never overwrite the previous backup** until the new one is verified. Store new backups alongside old ones, then promote:
   ```
   backups/
     pending/   <- new upload lands here
     verified/  <- promoted after integrity check
   ```

5. **Set reasonable upload timeout** on both client and server. A 20MB file on a slow connection could take minutes. Set timeout to 5 minutes, not the default 30 seconds.

6. **Return the received file size and hash in the response** so the app can verify the server got what it sent.

**Phase to address:** Phase 1 (upload endpoint) -- implement alongside the upload handler.

**Confidence:** HIGH -- Based on [documented multipart upload corruption issues](https://github.com/OneDrive/onedrive-api-docs/issues/1577) and the inherent unreliability of mobile networks.

---

### Pitfall 4: API Key Stored in Plaintext or Transmitted Over HTTP

**What goes wrong:** The API key for authenticating the app-to-server connection is stored as plaintext in the Docker environment variables AND transmitted over unencrypted HTTP. Anyone on the network can intercept the key and access/modify all backup data.

**Why it happens:**
- Self-hosted means the user controls the deployment environment
- Many self-hosted guides show `API_KEY=mysecretkey` in `docker-compose.yml`
- Users deploy on local networks and assume they are safe
- HTTPS requires certificates, which adds setup complexity (Let's Encrypt, reverse proxy)
- Single-user setup creates a false sense of "who would bother attacking this?"

**Consequences:**
- Anyone on the same network can sniff the API key from HTTP traffic
- Attacker can download all workout history (privacy violation)
- Attacker can upload malicious database files (data destruction)
- API key visible in docker-compose.yml if committed to a public repo

**Warning signs:**
- Server accessible via `http://` (not `https://`)
- API key visible in `docker-compose.yml` without being marked as a secret
- API key appears in server access logs
- Same API key used across multiple installations

**Prevention:**
1. **Generate a strong random API key on first run:**
   ```dart
   // During container first start
   if (!File('.api_key').existsSync()) {
     final key = base64Url.encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
     File('.api_key').writeAsStringSync(key);
     print('Generated API key: $key');
     print('Add this key to your JackedLog app settings.');
   }
   ```

2. **Support environment variable OR file-based key** (Docker secrets pattern):
   ```yaml
   # docker-compose.yml
   environment:
     - API_KEY_FILE=/run/secrets/api_key
   secrets:
     api_key:
       file: ./api_key.txt
   ```

3. **Hash the stored key** -- do not store the raw key on the server. Store a SHA-256 hash and compare on each request:
   ```dart
   final storedHash = sha256.convert(utf8.encode(configuredKey)).toString();
   // On request:
   final providedHash = sha256.convert(utf8.encode(request.headers['X-API-Key']!)).toString();
   if (providedHash != storedHash) return Response.forbidden('Invalid API key');
   ```

4. **Document HTTPS as strongly recommended.** Provide a docker-compose example with a reverse proxy (Caddy is simplest -- automatic HTTPS with 3 lines of config). Do NOT require HTTPS (some users run on localhost only), but warn loudly when running on HTTP.

5. **Rate-limit authentication failures** -- 5 failed attempts per minute, then block for 15 minutes. Prevents brute-force attacks.

6. **Use constant-time comparison** for API key validation to prevent timing attacks:
   ```dart
   bool secureCompare(String a, String b) {
     if (a.length != b.length) return false;
     var result = 0;
     for (var i = 0; i < a.length; i++) {
       result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
     }
     return result == 0;
   }
   ```

**Phase to address:** Phase 1 (auth layer) -- before any endpoint is accessible.

**Confidence:** HIGH -- Based on [API key security best practices](https://docs.google.com/docs/authentication/api-keys-best-practices) and [Stack Overflow security guidelines](https://stackoverflow.blog/2021/10/06/best-practices-for-authentication-and-authorization-for-rest-apis/).

---

### Pitfall 5: Docker Image Missing SQLite Native Library

**What goes wrong:** The Dart AOT-compiled server binary runs fine locally but crashes inside Docker with `Failed to load dynamic library 'libsqlite3.so.0'`. The minimal Docker runtime image does not include SQLite's shared library.

**Why it happens:**
- Dart Docker images use multi-stage builds: compile in the SDK image, run in a `scratch` or minimal runtime image
- The Dart `sqlite3` package uses `dart:ffi` to load `libsqlite3.so` at runtime
- The `FROM scratch` runtime image contains literally nothing -- no system libraries
- The `sqlite3` Dart package (v3+) uses build hooks to compile SQLite from source, but the compiled `.so` file may not be automatically included in the runtime image
- Alpine-based images use `musl` libc instead of `glibc`, which can cause binary incompatibility

**Consequences:**
- Container starts but crashes immediately on first database operation
- Works in development (local system has SQLite) but fails in production (Docker)
- Debugging is difficult because the error appears at runtime, not build time
- Users report "server won't start" with no clear fix

**Warning signs:**
- Error message: `Invalid argument(s): Failed to load dynamic library`
- Works with `dart run` locally but not in Docker
- Docker build succeeds but container exits immediately
- Different behavior on amd64 vs arm64 Docker hosts

**Prevention:**
1. **Copy SQLite library to runtime image** in the Dockerfile:
   ```dockerfile
   # Build stage
   FROM dart:stable AS build
   RUN apt-get update && apt-get install -y libsqlite3-dev
   WORKDIR /app
   COPY pubspec.* ./
   RUN dart pub get
   COPY . .
   RUN dart compile exe bin/server.dart -o bin/server

   # Copy SQLite and its dependencies to runtime directory
   RUN mkdir -p /runtime/lib
   RUN cp /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /runtime/lib/ || \
       cp /usr/lib/aarch64-linux-gnu/libsqlite3.so.0 /runtime/lib/

   # Runtime stage
   FROM scratch
   COPY --from=build /runtime/ /
   COPY --from=build /app/bin/server /app/bin/server
   ENV LD_LIBRARY_PATH=/lib
   ENTRYPOINT ["/app/bin/server"]
   ```

2. **Alternatively, use the `sqlite3` package's built-in bundling.** Version 3+ of the `sqlite3` Dart package compiles SQLite from source via build hooks. Verify the compiled `.so` is included in your AOT binary or copied to the runtime image.

3. **Test the Docker image on both amd64 and arm64** -- many self-hosted users run on Raspberry Pi (arm64). The library path differs:
   - amd64: `/usr/lib/x86_64-linux-gnu/libsqlite3.so.0`
   - arm64: `/usr/lib/aarch64-linux-gnu/libsqlite3.so.0`

4. **Do NOT use Alpine-based images** for the runtime unless you specifically compile against musl. The `dart:stable` image is Debian-based. Stick with Debian-based runtime or use `FROM scratch` with explicitly copied libraries.

5. **Test the full Docker build in CI** before release. A green build is not enough -- the container must start and serve a request.

**Phase to address:** Phase 1 (Docker setup) -- validate before writing any server code.

**Confidence:** HIGH -- Based on [Dart Docker SQLite3 issue #171](https://github.com/dart-lang/dart-docker/issues/171) and [multi-stage Dart Docker builds documentation](https://hub.docker.com/_/dart).

---

## Technical Debt Patterns

Shortcuts that accumulate cost over time.

---

### Debt 1: Duplicating Query Logic Between App and Server

**What goes wrong:** The app has complex SQL queries for strength data, cardio data, rep records, exercise records (see `gym_sets.dart` lines 35-659). The server needs the same queries for the dashboard. Developers copy-paste them, and the two diverge over time.

**Why it happens:**
- App uses Drift ORM with typed queries and CustomExpressions
- Server should use raw `sqlite3` (to avoid Drift migration issues -- see Pitfall 2)
- Different Dart packages, different query styles
- "Just copy the SQL" is fastest approach

**Consequences:**
- Dashboard shows different numbers than the app for the same exercise
- Bug fixed in app's query is not fixed in server's copy
- Maintenance burden doubles for every query change
- Users report "server shows wrong PR" -- trust erodes

**Prevention:**
- Extract pure SQL strings into a shared constants file that both app and server can import (or at minimum, document in a shared location)
- Keep the server query logic minimal -- focus on raw SQL that mirrors the app's CustomExpressions
- Document the canonical SQL for each dashboard metric:
  - 1RM: `MAX(CASE WHEN weight >= 0 THEN weight / (1.0278 - 0.0278 * reps) ELSE weight * (1.0278 - 0.0278 * reps) END)` (from `gym_sets.dart:16`)
  - Volume: `ROUND(SUM(weight * reps), 2)` (from `gym_sets.dart:13`)
  - Best set grouping: `STRFTIME('%Y-%m-%d', DATE(created, 'unixepoch', 'localtime'))` (from `gym_sets.dart:108`)

**Phase to address:** Phase 2 (dashboard queries) -- when building the query layer.

---

### Debt 2: Timestamp Handling Divergence

**What goes wrong:** The app stores timestamps as Unix epoch SECONDS in SQLite (Drift's `dateTime()` column type), converts to Dart `DateTime` by multiplying by 1000 (`DateTime.fromMillisecondsSinceEpoch(value * 1000)`), and uses SQLite's `DATE(created, 'unixepoch', 'localtime')` for grouping. The server runs in a different timezone than the user's phone, causing date-based groupings to shift.

**Why it happens:**
- Drift stores `DateTime` as Unix seconds via `dateTime()` column type
- The app's SQL queries use `'localtime'` modifier which depends on the DEVICE's timezone
- The server's Docker container has its own timezone (usually UTC)
- `DATE(created, 'unixepoch', 'localtime')` on the server groups by server timezone, not user timezone
- A workout logged at 11pm in New York (UTC-5) would appear as the next day on a UTC server

**Consequences:**
- Dashboard shows workouts on different dates than the app
- Weekly/monthly aggregations are off by one day at timezone boundaries
- Heatmap shows activity on wrong days
- User sees "I worked out on Monday" in app but "Tuesday" on dashboard

**Warning signs:**
- Workout dates differ between app and dashboard by exactly the timezone offset
- Users in timezones far from UTC see the most discrepancy
- Heatmap has gaps that do not match the app's history
- Monthly workout counts differ between app and dashboard

**Prevention:**
1. **Store user timezone in settings or as metadata in the backup:**
   ```sql
   -- Add to settings or metadata table
   INSERT INTO metadata (key, value) VALUES ('timezone', 'America/New_York');
   ```

2. **Use UTC consistently on the server** and convert to user timezone for display:
   ```dart
   // Server reads timezone from backup metadata
   final tz = db.select("SELECT value FROM metadata WHERE key = 'timezone'");
   // Apply offset when grouping by date
   ```

3. **Or: set the Docker container timezone to match the user's timezone:**
   ```yaml
   environment:
     - TZ=America/New_York
   ```
   This is the simplest approach for a single-user server. Document it clearly.

4. **Do NOT use `'localtime'` in server-side queries.** Use explicit timezone offsets or UTC grouping.

**Phase to address:** Phase 2 (dashboard queries) -- must be decided before writing date-based queries.

**Confidence:** HIGH -- Based on direct analysis of `gym_sets.dart:108` (`'localtime'` modifier) and `gym_sets.dart:334-335` (epoch seconds * 1000 conversion). This WILL bite you.

---

## Integration Gotchas

Specific to integrating a server component with this existing codebase.

---

### Gotcha 1: The `created` Column Stores Epoch Seconds, Not Milliseconds

**What goes wrong:** A developer reads `DateTimeColumn get created => dateTime()()` in the Drift schema and assumes standard millisecond timestamps. They multiply by 1 instead of 1000 when converting to Dart DateTime, or they divide by 1000 unnecessarily.

**Why it happens:**
- Drift's `dateTime()` stores values as Unix epoch SECONDS (integer)
- But Dart's `DateTime.fromMillisecondsSinceEpoch()` expects MILLISECONDS
- The app code multiplies by 1000 everywhere: `DateTime.fromMillisecondsSinceEpoch(result.read<int>('created') * 1000)` (gym_sets.dart:335)
- SQLite's `DATE(created, 'unixepoch')` expects seconds -- this works correctly
- A developer new to the codebase will get confused

**Prevention:**
- Document the convention clearly in the server code: "All timestamps in the backup database are Unix epoch SECONDS"
- Create a helper function:
  ```dart
  DateTime fromDbTimestamp(int epochSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true);
  ```
- Unit test with known timestamps from the database

**Phase to address:** Phase 2 (server query layer) -- document on day one of dashboard work.

---

### Gotcha 2: The `hidden` Column Is a Filter, Not a Deletion

**What goes wrong:** Server dashboard queries `gym_sets` without filtering `WHERE hidden = 0`, showing template/default exercises that should be invisible.

**Why it happens:**
- The app inserts "template" gym sets for each exercise with `hidden = true` (these define the exercise's default settings)
- All app queries filter `WHERE hidden = 0` (or `.where(db.gymSets.hidden.equals(false))`)
- The server developer querying raw SQL forgets this filter
- Default exercises like "Bench Press" with 0 reps appear in the dashboard

**Prevention:**
- ALWAYS include `WHERE hidden = 0` (or `WHERE hidden = false`) in server-side gym_sets queries
- Create a server-side view or wrapper:
  ```sql
  CREATE VIEW visible_sets AS SELECT * FROM gym_sets WHERE hidden = 0;
  ```
- Test with a real backup database that contains hidden template rows

**Phase to address:** Phase 2 (every dashboard query) -- add to code review checklist.

**Confidence:** HIGH -- Based on `gym_sets.dart:55` (`.where(db.gymSets.hidden.equals(false))`), `gym_sets.dart:219`, and `export_data.dart` which exports ALL rows including hidden ones.

---

### Gotcha 3: Workout Data is Split Across Two Tables

**What goes wrong:** Dashboard shows exercises but no workout grouping, or shows workouts but no exercises. The relationship between `workouts` and `gym_sets` is not a foreign key constraint but a nullable `workout_id` column on `gym_sets`.

**Why it happens:**
- `workouts` table was added in schema v48 (see `database.dart:159-171`)
- Historical `gym_sets` rows from before v48 have `workout_id = NULL`
- `gym_sets.workout_id` is not a foreign key -- it is just an integer column with no constraint
- Some gym_sets may have workout_ids that reference deleted workouts
- The app handles this gracefully; a naive server implementation may not

**Prevention:**
- Handle `workout_id = NULL` gracefully (pre-v48 data or orphaned sets)
- Group by workout_id when available, fall back to date-based grouping when not
- Do NOT assume every gym_set has a workout_id
- Verify workout exists before joining: use LEFT JOIN, not INNER JOIN

**Phase to address:** Phase 2 (dashboard queries).

---

### Gotcha 4: The `notes` Table Has Nothing to Do With Workout Notes

**What goes wrong:** Developer assumes the `notes` table contains workout session notes. It actually contains freeform user notes (like a notepad feature). Workout-specific notes are stored in `gym_sets.notes` and `workouts.notes` columns.

**Why it happens:**
- Three different "notes" concepts in the schema:
  1. `notes` table -- standalone notes feature (title, content, color)
  2. `gym_sets.notes` -- per-set notes (e.g., "felt heavy today")
  3. `workouts.notes` -- per-workout notes
- A developer building a dashboard might query the wrong "notes"

**Prevention:**
- Document the three notes locations clearly
- Dashboard "workout notes" should read from `workouts.notes` and `gym_sets.notes`, NOT from the `notes` table
- The `notes` table content is likely NOT needed on the dashboard at all

**Phase to address:** Phase 2 (dashboard planning).

---

## Performance Traps

---

### Trap 1: Running `PRAGMA integrity_check` on Every Request

**What goes wrong:** Server validates the backup database on every dashboard page load using `PRAGMA integrity_check`. This is a full table scan of the entire database and takes seconds on large databases.

**Why it happens:**
- Developers know integrity checking is important (see Pitfall 3)
- Natural inclination to "verify before every read"
- `integrity_check` examines every page in the database

**Consequences:**
- Dashboard takes 5-30 seconds to load
- Server CPU spikes on every request
- Multiple concurrent page loads bring the server to its knees

**Prevention:**
- Run `PRAGMA integrity_check` ONCE when the backup is received (upload endpoint)
- Use `PRAGMA quick_check` if you must re-verify (faster, skips index/unique checks)
- Cache the validation result alongside the backup
- Dashboard queries assume the database is valid (it was checked on upload)

**Phase to address:** Phase 1 (upload endpoint) -- validate once, read forever.

---

### Trap 2: Opening and Closing the Backup Database on Every Request

**What goes wrong:** Each dashboard API request opens the SQLite database file, runs a query, and closes it. Opening a SQLite database involves reading the header, loading the schema, and initializing internal structures -- significant overhead multiplied by every request.

**Why it happens:**
- "Stateless" request handling pattern from web development background
- Fear of keeping database connections open ("what if the file changes?")
- The backup file DOES change when a new backup is uploaded

**Prevention:**
- **Keep a single read-only connection open** for the "current" backup
- When a new backup is uploaded, close the old connection and open a new one
- Use a simple pattern:
  ```dart
  class BackupReader {
    Database? _db;
    String? _currentPath;

    Database get db {
      if (_db == null) throw StateError('No backup loaded');
      return _db!;
    }

    void loadBackup(String path) {
      _db?.dispose();
      _db = sqlite3.open(path, mode: OpenMode.readOnly);
      _currentPath = path;
    }
  }
  ```
- This is safe because the backup file only changes on explicit upload, not continuously

**Phase to address:** Phase 2 (server architecture).

---

### Trap 3: Docker Image Bloat From Dart SDK

**What goes wrong:** The Docker image includes the full Dart SDK (~800MB) instead of just the AOT-compiled binary (~10-25MB). Self-hosted users on limited hardware (Raspberry Pi, small VPS) waste storage and RAM.

**Why it happens:**
- Using a single-stage Dockerfile: `FROM dart:stable` without a second stage
- Including dev dependencies in the runtime image
- Not using AOT compilation (`dart compile exe`)

**Consequences:**
- Docker image is 800MB+ instead of 25-50MB
- Slow to pull on limited bandwidth connections
- Wastes storage on small devices
- JIT mode uses more RAM at runtime than AOT

**Prevention:**
- **Always use multi-stage builds:**
  ```dockerfile
  # Build stage: full SDK
  FROM dart:stable AS build
  WORKDIR /app
  COPY pubspec.* ./
  RUN dart pub get --no-dev-dependencies
  COPY . .
  RUN dart compile exe bin/server.dart -o /app/server

  # Runtime stage: minimal
  FROM scratch
  COPY --from=build /runtime/ /
  COPY --from=build /app/server /app/server
  EXPOSE 8080
  ENTRYPOINT ["/app/server"]
  ```
- Target image size: under 50MB including SQLite library
- Test on arm64 (Raspberry Pi) in addition to amd64

**Phase to address:** Phase 1 (Dockerfile creation) -- set up correctly from the start.

**Confidence:** HIGH -- Based on [Dart Docker documentation](https://hub.docker.com/_/dart) and [multi-stage build best practices](https://medium.com/google-cloud/build-slim-docker-images-for-dart-apps-ee98ea1d1cf7).

---

## Security Mistakes

---

### Mistake 1: No Request Size Limit on Upload Endpoint

**What goes wrong:** An attacker (or a bug) sends a multi-gigabyte file to the upload endpoint, filling the server's disk and crashing the container.

**Prevention:**
- Set a maximum upload size (e.g., 100MB -- generous for a fitness app database):
  ```dart
  if (request.contentLength != null && request.contentLength! > 100 * 1024 * 1024) {
    return Response(413, body: 'File too large');
  }
  ```
- Also enforce on the server framework level (Shelf middleware)
- Store backups in a directory with a disk quota or monitor available space

**Phase to address:** Phase 1 (upload endpoint).

---

### Mistake 2: Path Traversal in Backup File Handling

**What goes wrong:** The server constructs file paths using user-supplied data (filename, backup ID), allowing an attacker to write outside the backups directory: `../../etc/passwd`.

**Prevention:**
- Never use user-supplied values in file paths
- Generate server-side filenames:
  ```dart
  final filename = 'backup_${DateTime.now().millisecondsSinceEpoch}.sqlite';
  final path = p.join(backupsDir, filename);
  // Verify path is within backups directory
  assert(p.isWithin(backupsDir, path));
  ```
- Use `package:path`'s `isWithin()` to validate paths before any file operation

**Phase to address:** Phase 1 (file storage).

---

### Mistake 3: Backup Files Accessible Without Authentication

**What goes wrong:** The backup download endpoint is not behind the API key check, or static file serving exposes the backups directory directly.

**Prevention:**
- Apply API key middleware to ALL endpoints (upload, download, dashboard API, backup list)
- Never serve the backups directory as static files
- All backup access goes through authenticated API endpoints
- Audit middleware ordering: auth check MUST run before route handler

**Phase to address:** Phase 1 (middleware setup).

---

### Mistake 4: Sensitive Data in Server Logs

**What goes wrong:** API keys, database content, or user workout data appears in server logs. Logs are often stored in plaintext and may be accessible via Docker log aggregation.

**Prevention:**
- Never log the API key value (log "auth succeeded" or "auth failed", not the key)
- Never log query results or database content
- Log request metadata only: method, path, status code, duration
- Set log level to INFO in production, DEBUG only in development

**Phase to address:** Phase 1 (logging setup).

---

## "Looks Done But Isn't" Checklist

Things that appear complete but have hidden gaps.

| Looks Done | Actually Missing | How to Verify |
|------------|-----------------|---------------|
| Upload endpoint returns 200 | File integrity not verified | Upload a truncated file, check if server accepts it |
| Dashboard shows workouts | Hidden template sets included | Check if exercises with 0 reps/weight appear |
| Docker image builds | Container crashes on start (missing libsqlite3) | Run `docker run --rm image_name` and check for FFI errors |
| Backup list shows files | File sizes/dates are wrong (filesystem metadata) | Compare displayed metadata against actual file properties |
| API key auth works | Timing attack possible on key comparison | Use constant-time comparison function |
| Date grouping works | Wrong timezone shows workouts on wrong day | Compare dashboard dates with app dates for a user in UTC+12 |
| One-command Docker setup | User still needs to configure API key and HTTPS | Follow setup from scratch on a clean machine |
| Graphs render correctly | Unit conversion not applied (kg user sees lb) | Check dashboard with backup from a user who uses kg |
| Restore endpoint works | WAL/SHM files from previous restore not cleaned up | Restore twice in a row, check for leftover files |
| Backup history shows 10 backups | No cleanup policy, disk fills up | Upload 100 backups, check disk usage |

---

## Pitfall-to-Phase Mapping

| Phase | Pitfall | Severity | Mitigation Summary |
|-------|---------|----------|-------------------|
| Phase 1: Server Foundation | WAL corruption on upload (#1) | CRITICAL | Checkpoint before read, validate with quick_check |
| Phase 1: Server Foundation | Schema version mismatch (#2) | CRITICAL | Use raw sqlite3, open read-only, check user_version |
| Phase 1: Server Foundation | Transfer corruption (#3) | CRITICAL | SHA-256 checksum, never overwrite until verified |
| Phase 1: Server Foundation | API key security (#4) | CRITICAL | Random generation, hashed storage, constant-time compare |
| Phase 1: Server Foundation | Missing SQLite in Docker (#5) | CRITICAL | Multi-stage build, copy libsqlite3.so, test on arm64 |
| Phase 1: Server Foundation | Docker image bloat (Trap 3) | MODERATE | Multi-stage build, AOT compile, target <50MB |
| Phase 1: Server Foundation | No upload size limit (Security 1) | MODERATE | 100MB max, enforce in middleware |
| Phase 1: Server Foundation | Path traversal (Security 2) | MODERATE | Server-generated filenames, isWithin() check |
| Phase 1: Server Foundation | Unauthenticated access (Security 3) | MODERATE | Auth middleware on ALL endpoints |
| Phase 2: Dashboard | Duplicate query logic (Debt 1) | MODERATE | Extract SQL to shared constants |
| Phase 2: Dashboard | Timezone divergence (Debt 2) | MODERATE | Set TZ env var, avoid 'localtime' in server queries |
| Phase 2: Dashboard | Epoch seconds confusion (Gotcha 1) | LOW | Helper function, document convention |
| Phase 2: Dashboard | Missing hidden filter (Gotcha 2) | LOW | Always WHERE hidden = 0 |
| Phase 2: Dashboard | Workout/set table split (Gotcha 3) | LOW | LEFT JOIN, handle null workout_id |
| Phase 2: Dashboard | Notes table confusion (Gotcha 4) | LOW | Document three notes locations |
| Phase 2: Dashboard | Integrity check on every request (Trap 1) | LOW | Validate once on upload, cache result |
| Phase 2: Dashboard | DB open/close per request (Trap 2) | LOW | Keep single read-only connection |

---

## Sources

**Codebase Analysis (HIGH confidence):**
- `/home/aquatic/Documents/JackedLog/lib/export_data.dart` -- WAL checkpoint pattern (line 158-159), database export flow
- `/home/aquatic/Documents/JackedLog/lib/import_data.dart` -- WAL/SHM file deletion (lines 101-104), import parsing
- `/home/aquatic/Documents/JackedLog/lib/database/database.dart` -- 65 schema versions, migration system, schemaVersion getter (line 482)
- `/home/aquatic/Documents/JackedLog/lib/database/database_connection_native.dart` -- NativeDatabase setup, file paths
- `/home/aquatic/Documents/JackedLog/lib/database/gym_sets.dart` -- Timestamp handling (lines 108, 334-335), query patterns, hidden filter, SQL formulas
- `/home/aquatic/Documents/JackedLog/lib/database/workouts.dart` -- Workout table schema
- `/home/aquatic/Documents/JackedLog/lib/database/settings.dart` -- Settings schema with 59 columns
- `/home/aquatic/Documents/JackedLog/lib/database/notes.dart` -- Notes table (standalone notes, not workout notes)
- `/home/aquatic/Documents/JackedLog/lib/backup/auto_backup_service.dart` -- Backup file creation, retention policy

**SQLite and WAL (HIGH confidence):**
- [SQLite WAL Documentation](https://sqlite.org/wal.html)
- [SQLite Forum: Hot backup in WAL mode](https://sqlite.org/forum/forumpost/905eb5e564d4df44)
- [SQLite Corruption: How it happens](https://sqlite.org/howtocorrupt.html)
- [SQLite PRAGMA integrity_check](https://www.sqlite.org/pragma.html)
- [SQLite WAL Backup Strategies](https://sqlite.work/ensuring-consistent-backups-in-sqlite-wal-mode-without-disrupting-writers/)

**Dart Docker Deployment (HIGH confidence):**
- [Official Dart Docker Image](https://hub.docker.com/_/dart)
- [Dart Docker SQLite3 Issue #171](https://github.com/dart-lang/dart-docker/issues/171)
- [Slim Dart Docker Images](https://medium.com/google-cloud/build-slim-docker-images-for-dart-apps-ee98ea1d1cf7)

**Drift and sqlite3 (HIGH confidence):**
- [Drift Platform Support](https://drift.simonbinder.eu/platforms/)
- [sqlite3 Dart Package](https://pub.dev/packages/sqlite3)
- [Drift Migrations Documentation](https://drift.simonbinder.eu/docs/advanced-features/migrations/)

**Security (MEDIUM confidence):**
- [API Key Best Practices - Google Cloud](https://docs.google.com/docs/authentication/api-keys-best-practices)
- [REST API Security Best Practices - Stack Overflow Blog](https://stackoverflow.blog/2021/10/06/best-practices-for-authentication-and-authorization-for-rest-apis/)
- [API Key Weaknesses - TechTarget](https://www.techtarget.com/searchsecurity/tip/API-keys-Weaknesses-and-security-best-practices)

**Self-Hosting UX (MEDIUM confidence):**
- [Self-Hosting Pros and Cons](https://www.androidauthority.com/self-hosting-pros-and-cons-3590831/)
- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
- [Langfuse Docker Compose Self-Hosting](https://langfuse.com/self-hosting/deployment/docker-compose)
