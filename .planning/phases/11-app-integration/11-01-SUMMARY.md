---
phase: 11-app-integration
plan: 01
subsystem: database, ui
tags: [sqlite, migration, settings, server-config]
requires:
  - phase: 10-server-foundation
    provides: Server that accepts backup uploads
provides:
  - Database migration v65 to v66 with server columns
  - Server settings page with URL/API key configuration
  - Connection test functionality
affects: [11-02-backup-push]
tech-stack:
  added: []
  patterns: [server-settings-page]
key-files:
  created: [lib/server/server_settings_page.dart]
  modified: [lib/database/settings.dart, lib/database/database.dart, lib/settings/settings_page.dart]
key-decisions:
  - "Used nullable columns for backward compatibility with existing exports"
  - "Placed Backup Server entry after Data management in settings list for logical grouping"
patterns-established:
  - "Server settings page pattern with URL/API key fields and connection test"
duration: 2min
completed: 2026-02-15
---

# Phase 11 Plan 01: Database Migration & Server Settings Summary

**Added 4 nullable server columns (v65->v66 migration) and ServerSettingsPage with URL field, masked API key with reveal toggle, and connection test button that validates health endpoint then API key auth.**

## What Was Done

### Task 1: Database Schema & Migration

Added 4 nullable columns to the Settings table in `lib/database/settings.dart`:

- `serverUrl` (TextColumn, nullable) - server base URL
- `serverApiKey` (TextColumn, nullable) - API key for authentication
- `lastPushTime` (DateTimeColumn, nullable) - timestamp of last push
- `lastPushStatus` (TextColumn, nullable) - result of last push attempt

Updated `schemaVersion` from 65 to 66 in `lib/database/database.dart` and added migration block `from65To66` with 4 ALTER TABLE statements using the `catchError` pattern for idempotency.

All columns are nullable so existing exported data can still be re-imported without these fields present.

### Task 2: Server Settings Page & Navigation

Created `lib/server/server_settings_page.dart` - a StatefulWidget with:

- **Server URL field**: TextFormField with `TextInputType.url`, hint text "https://myserver.com", format validation (must start with http:// or https://), auto-strips trailing slashes on blur, persists via `SettingsCompanion`
- **API Key field**: TextFormField with `obscureText: true` default, eye icon toggle (visibility/visibility_off) to reveal/mask, persists on blur
- **Test Connection button**: FilledButton.tonal with `Icons.wifi_find`, disabled when URL or API key empty. Two-step validation: (1) GET /api/health for reachability, (2) GET /api/backups with Bearer auth for key validation. Shows green success or red error with descriptive messages. Handles SocketException, TimeoutException (10s), and generic errors.

Added "Backup Server" ListTile with `Icons.cloud_upload` icon in `lib/settings/settings_page.dart`, positioned after "Data management" for logical data/backup grouping.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- [x] `lib/database/settings.dart` contains `serverUrl`, `serverApiKey`, `lastPushTime`, `lastPushStatus` columns
- [x] `lib/database/database.dart` has `schemaVersion => 66` and migration block `from < 66 && to >= 66`
- [x] `lib/server/server_settings_page.dart` exists with URL field, API key field, connection test
- [x] `lib/settings/settings_page.dart` has "Backup Server" ListTile navigating to ServerSettingsPage
- [x] Migration uses only nullable columns (backward compatible with existing exports)
- [x] All 4 ALTER TABLE statements use `catchError` pattern
