---
phase: quick-010
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - server/lib/api/backup_api.dart
  - lib/server/backup_push_service.dart
autonomous: true

must_haves:
  truths:
    - "POST /api/backup with application/octet-stream body returns 200 with filename and dbVersion"
    - "Server logs content-type and body size on upload attempts for diagnostics"
    - "Client error messages include server response body for debugging"
  artifacts:
    - path: "server/lib/api/backup_api.dart"
      provides: "Resilient backup upload handler"
      contains: "request.read()"
    - path: "lib/server/backup_push_service.dart"
      provides: "Diagnostic error reporting on push failure"
      contains: "responseBody"
  key_links:
    - from: "lib/server/backup_push_service.dart"
      to: "server/lib/api/backup_api.dart"
      via: "POST /api/backup with raw bytes"
      pattern: "application/octet-stream"
---

<objective>
Fix POST /api/backup returning HTTP 400 when the app pushes a backup.

Purpose: Backup push from the app currently silently fails with 400. The ~2ms server response time indicates the body is never processed. The server's strict content-type gating and the client's failure to read error response bodies make this hard to diagnose.

Output: Working backup push flow with diagnostic logging on both sides.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@server/lib/api/backup_api.dart
@lib/server/backup_push_service.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix server upload handler to be resilient to content-type variations</name>
  <files>server/lib/api/backup_api.dart</files>
  <action>
Rewrite the `uploadBackupHandler` body-reading logic in `server/lib/api/backup_api.dart`:

1. Keep the multipart/form-data path as-is (lines 21-28).

2. Replace the strict `application/octet-stream` content-type check (lines 30-34) with a fallback that ALWAYS tries to read the raw body for any non-multipart request. The logic should be:
   - If `formData` is null (not multipart), set `fileStream = request.read()` unconditionally.
   - Remove the `contentType.contains('application/octet-stream')` gate entirely.

3. Add diagnostic logging BEFORE the fileStream null check (line 37):
   - Print the content-type header value: `print('Upload attempt: content-type=${request.headers['content-type']}');`

4. After `storeBackup` succeeds, add a print with the filename and size: `print('Backup stored: ${info.filename} (v${info.dbVersion})');`

5. The `fileStream == null` check at line 37 now only triggers if it was a multipart request but had no file field. For non-multipart, fileStream is always set.

The resulting flow:
```
formData = request.formData()
if formData != null:
  // multipart path (unchanged)
else:
  fileStream = request.read()  // always try raw body

if fileStream == null:
  return 400 'No file uploaded'  // only for broken multipart

// proceed to storeBackup (validates SQLite header, catches FormatException)
```
  </action>
  <verify>Read the modified file and confirm: (1) no content-type gate for raw body path, (2) diagnostic prints present, (3) multipart path unchanged.</verify>
  <done>Non-multipart POST requests always attempt to read the body regardless of content-type header value. Diagnostic logging shows content-type and stored filename on server stdout.</done>
</task>

<task type="auto">
  <name>Task 2: Client reads server error response body for diagnostic messages</name>
  <files>lib/server/backup_push_service.dart</files>
  <action>
In `lib/server/backup_push_service.dart`, modify the error handling after `request.close()`:

1. Replace the `await response.drain<void>();` (line 34) with reading the response body into a string:
   ```dart
   final responseBody = await response.transform(utf8.decoder).join();
   ```
   Import `dart:convert` at the top (it may already be imported -- check first, do not duplicate).

2. Update the 401/403 error throw (line 36) to stay as-is (auth error message is clear enough).

3. Update the generic status code error (line 39) to include the response body:
   ```dart
   throw Exception('Server returned status $statusCode: $responseBody');
   ```
   This way the user sees the actual server error message (e.g., "No file uploaded" or the FormatException message) in the app's error display.
  </action>
  <verify>Read the modified file and confirm: (1) response body is read as string instead of drained, (2) error message includes responseBody, (3) no duplicate imports.</verify>
  <done>Push failures include the server's error message in the exception, making future debugging straightforward.</done>
</task>

</tasks>

<verification>
- `dart analyze server/` passes with no errors on modified server file
- `dart analyze lib/server/backup_push_service.dart` passes with no errors
- Server handler no longer gates on content-type for raw body reads
- Client error messages include server response body text
</verification>

<success_criteria>
- POST /api/backup with any content-type and raw SQLite bytes will attempt to process the body
- Server logs content-type and stored filename for diagnostics
- Client surfaces server error messages on push failure
</success_criteria>

<output>
After completion, create `.planning/quick/010-fix-post-backup-400-error/010-SUMMARY.md`
</output>
