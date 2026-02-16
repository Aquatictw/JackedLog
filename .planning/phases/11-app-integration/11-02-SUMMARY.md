---
phase: 11-app-integration
plan: 02
subsystem: ui, api
tags: [http, backup, upload, push, status]
requires:
  - phase: 11-app-integration-01
    provides: Server settings columns and settings page
  - phase: 10-server-foundation
    provides: POST /api/backup endpoint
provides:
  - BackupPushService with pushBackup() for uploading SQLite files
  - Push button and status display on backup settings page
affects: []
tech-stack:
  added: []
  patterns: [backup-push-service]
key-files:
  created: [lib/server/backup_push_service.dart]
  modified: [lib/backup/auto_backup_settings.dart]
key-decisions:
  - "Used dart:io HttpClient for file upload instead of http package for raw byte control"
patterns-established:
  - "Push service with WAL checkpoint before file read"
duration: 1min
completed: 2026-02-15
---

# Phase 11 Plan 02: Backup Push Service & Push Button Summary

**dart:io HttpClient-based backup push with WAL checkpoint, status persistence, and in-place progress/status UI on backup settings page**

## What Was Done

### Task 1: Created BackupPushService
Created `lib/server/backup_push_service.dart` with a static `pushBackup(serverUrl, apiKey)` method that:
- Runs `PRAGMA wal_checkpoint(TRUNCATE)` before reading the database file
- Reads `jackedlog.sqlite` bytes from the application documents directory
- Sends raw bytes as `application/octet-stream` via `dart:io HttpClient` POST to `/api/backup`
- Sets `Authorization: Bearer` header for API key auth
- On success: writes `lastPushTime` (DateTime.now()) and `lastPushStatus` ('success') to settings
- On failure: writes `lastPushStatus` ('failed') to settings, then rethrows

### Task 2: Added Push Button and Status Display
Modified `lib/backup/auto_backup_settings.dart` to add a "Push to Server" section:
- Added `_isPushing` state variable for loading state
- Push section placed OUTSIDE the auto-backup conditional, visible when `serverUrl` is configured
- `_buildPushStatus` method shows three states:
  - "Never pushed" (cloud_off icon, outline color) when `lastPushTime` is null
  - "Last pushed: {timeago}" (checkmark icon, primary color) on success
  - "Last push failed" (error icon, error color) on failure
- Indeterminate `LinearProgressIndicator` shown during push
- `FilledButton.icon` with cloud_upload icon, disabled during push
- `_performPush` method calls `BackupPushService.pushBackup`, refreshes `SettingsState` on completion

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

1. `lib/server/backup_push_service.dart` exists with `pushBackup` static method
2. WAL checkpoint (`wal_checkpoint(TRUNCATE)`) confirmed in service
3. POST to `/api/backup` with Bearer auth confirmed
4. `lastPushTime` and `lastPushStatus` updated on success and failure
5. Push section only visible when `serverUrl` is configured (non-null, non-empty)
6. Status shows "Never pushed" when `lastPushTime` is null
7. Status shows "Last pushed: {timeago}" with checkmark on success
8. Status shows "Last push failed" in red on failure
9. Indeterminate `LinearProgressIndicator` shows during push
