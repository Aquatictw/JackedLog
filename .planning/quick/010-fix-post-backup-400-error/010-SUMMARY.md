# Quick Task 010: Fix POST Backup 400 Error

**One-liner:** Remove strict content-type gate on server backup upload and surface server error bodies in client

## Changes Made

### Task 1: Fix server upload handler to be resilient to content-type variations
- Removed `application/octet-stream` content-type check that was gating raw body reads
- Non-multipart requests now always attempt `request.read()` regardless of content-type header
- Added diagnostic logging: prints content-type on every upload attempt and filename/version on success
- **File:** `server/lib/api/backup_api.dart`

### Task 2: Client reads server error response body for diagnostic messages
- Replaced `response.drain<void>()` with `response.transform(utf8.decoder).join()` to capture response body
- Error messages now include server response body text (e.g., "Server returned status 400: {"error":"No file uploaded"}")
- Added `dart:convert` import for `utf8.decoder`
- **File:** `lib/server/backup_push_service.dart`

## Root Cause

The server had a strict `application/octet-stream` content-type check. Dart's `HttpClient` may send a slightly different content-type header value (or the header casing/format may not match the `.contains()` check), causing the server to skip reading the body entirely and return 400. The ~2ms response time confirmed the body was never processed.

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- `dart analyze server/lib/api/backup_api.dart` -- no errors (only pre-existing trailing comma info lints)
- Server handler no longer gates on content-type for raw body reads
- Client error messages include server response body text

## Files Modified

| File | Change |
|------|--------|
| `server/lib/api/backup_api.dart` | Removed content-type gate, added diagnostic logging |
| `lib/server/backup_push_service.dart` | Read response body instead of draining, include in error messages |
