# Codebase Concerns

**Analysis Date:** 2026-02-02

## Tech Debt

**Silent Error Handling in Database Migrations:**
- Issue: 25+ instances of `.catchError((e) {})` in `lib/database/database.dart` that silently swallow migration errors
- Files: `lib/database/database.dart` (lines 83-317)
- Impact: Failed column additions, renames, or constraint changes go undetected during app upgrades. Users may experience missing fields or corrupted data integrity without warnings.
- Fix approach: Log all caught exceptions with context about which migration failed. Use proper error propagation with user-facing error pages for critical failures. Include database version rollback safeguards.

**Global Database Instance Without Lifecycle Management:**
- Issue: `final db = AppDatabase()` in `lib/main.dart` creates singleton without proper disposal
- Files: `lib/main.dart` line 46
- Impact: Database connections not guaranteed to close cleanly on app exit. WAL files may not be checkpointed properly, risking data loss on forced app termination. Potential memory leaks from unclosed cursors.
- Fix approach: Wrap AppDatabase initialization with async teardown. Ensure `db.close()` called in app lifecycle (SystemChannels.lifecycle listening). Checkpoint WAL on app pause.

**Bare Catch Statements Hiding Errors:**
- Issue: Multiple `catch (_) {}` patterns across import/parsing code swallow exceptions without logging
- Files: `lib/import_hevy.dart` (lines 757, 788, 820), `lib/utils.dart` line 38
- Impact: Silent failures during data import make debugging impossible. Users lose data without notification.
- Fix approach: Replace all `catch (_)` with proper exception logging. Include exception type and context in logs. User-facing toast messages for import failures.

**Silent Backup Failures:**
- Issue: `performAutoBackup()` returns false on all errors without logging the cause
- Files: `lib/backup/auto_backup_service.dart` line 55-58
- Impact: Auto-backups fail silently without user awareness. Users believe data is backed up when it isn't.
- Fix approach: Log specific error reasons (permission denied, path invalid, disk full). Add backup status indicator in settings. Notify user of backup failures.

## Fragile Areas

**Active Workout State Race Condition:**
- Files: `lib/workouts/workout_state.dart`, `lib/plan/start_plan_page.dart`
- Why fragile: `_loadActiveWorkout()` called in constructor with `catchError` that swallows load failures. If workout exists in DB but plan lookup returns null, `_activePlan` becomes null while `_activeWorkout` has value. UI code assumes both are synchronized.
- Safe modification: Add invariant assertion: if `_activeWorkout != null`, then `_activePlan` must not be null. Create placeholder plan before returning from constructor. Add null checks in all places that use `_activePlan` with `_activeWorkout`.
- Test coverage: No test for race between activeWorkout and activePlan nullability.

**Active Workout Bar Timer Polling Loop:**
- Files: `lib/workouts/active_workout_bar.dart` (lines 36-46)
- Why fragile: Timer calls `context.read<WorkoutState>()` on every tick (1-second intervals). If WorkoutState is disposed while timer is running, crashes on next tick. `mounted` check happens but state could be stale.
- Safe modification: Check `mounted` before calling `context.read()`. Store WorkoutState reference in initState. Cancel timer in dispose before super.dispose(). Add try-catch around state access.
- Test coverage: No test for rapid widget disposal.

**Spotify Token Expiry Not Enforced:**
- Files: `lib/spotify/spotify_state.dart` (lines 382-388, 275-280)
- Why fragile: Tokens saved with expiry but expiry time not validated before use. Token may expire mid-request. `hasValidToken` getter checks expiry but is only called during initialization (`_initialize()` line 173), not during polling.
- Safe modification: Check token expiry before every API call in `_fetchWebApiData()`. Refresh token proactively 5 minutes before expiry. Add token validation in `_pollPlayerState()` before making requests.
- Test coverage: No test for expired token recovery.

**Database Query Assumptions on Non-Null Results:**
- Files: Multiple files using `.getSingle()` instead of `.getSingleOrNull()`
- Why fragile: `db.settings.select()..limit(1)).getSingle()` in `lib/main.dart` line 33 assumes settings always exists. If table is empty and `insertOne()` fails, `getSingle()` throws exception.
- Safe modification: Always use `.getSingleOrNull()` and provide safe defaults. Add validation layer that ensures required records exist. Add database schema integrity checks in `FailedMigrationsPage`.
- Test coverage: No test for missing settings table.

**Backup Path Validation Missing:**
- Files: `lib/backup/auto_backup_service.dart` (lines 32, 42, 129-149)
- Why fragile: `settings.backupPath` checked for empty string but not for accessibility, disk space, or permission errors. On Android 10+, SAF URIs can become invalid. Fallback file backup uses hardcoded path assumption.
- Safe modification: Add pre-backup path validation check. Verify directory exists and is writable. Check available disk space before creating backup. Handle permission revocation gracefully on SAF URIs.
- Test coverage: No test for permission denied or disk full scenarios.

## Scaling Limits

**Polling Architecture at Scale:**
- Issue: Spotify polling runs every 1 second, Web API calls every 5 seconds continuously while music tab visible
- Files: `lib/spotify/spotify_state.dart` (lines 194-206, 224-225)
- Limit: On devices with 4+ active timers, simultaneous polling may exceed platform limits. No batching or rate limiting implemented.
- Scaling path: Implement exponential backoff for failed requests. Batch API calls to combine queue + recently played in single request. Add polling interval configuration based on device performance tier.

**Workout History Unbounded Query:**
- Issue: History pages load all workouts without pagination
- Files: `lib/sets/history_page.dart` (likely, not fully examined)
- Limit: Users with 1000+ workouts experience UI lag and memory bloat
- Scaling path: Implement cursor-based pagination. Cache recent queries. Add lazy-loading infinite scroll.

**Graph Calculations on Full Dataset:**
- Issue: Strength/Cardio graphs likely compute across all historical data without date range optimization
- Files: `lib/graph/strength_data.dart`, `lib/graph/cardio_data.dart` (not fully examined)
- Limit: Graphs freeze on datasets >5000 entries
- Scaling path: Add date range filtering to queries. Implement data aggregation for old entries. Cache computed graph data.

## Dependencies at Risk

**Drift Version Tight Coupling:**
- Package: `drift: ^2.28.1`
- Risk: Major API changes between Drift v3.x and v2.x planned. Current `.catchError()` patterns rely on Drift exception behavior that may change.
- Impact: Upgrading to Drift 3.x will require rewriting all migration logic
- Migration plan: Pin to `^2.28` until migration tests complete. Create separate test suite for Drift 3 compatibility. Plan 2-3 week refactor sprint.

**Spotify SDK Third-Party Dependency:**
- Package: `spotify_sdk: ^3.0.0`
- Risk: Unmaintained package (last update 2023). Spotify API deprecations not tracked. No queue API support acknowledged (line 257-258 in spotify_service.dart).
- Impact: Features relying on Spotify API may break without warning. No alternative queue implementation available.
- Migration plan: Monitor Spotify API changelog. Create abstraction layer around SpotifyService to allow alternative implementations. Consider replacing with http client for direct API calls.

**Permission Handler Version Gap:**
- Package: `permission_handler: ^12.0.1`
- Risk: Battery optimization permission handling inconsistent across Android versions 10-15
- Impact: Battery timer notifications may be blocked silently on new devices
- Migration plan: Test on Android 14/15 devices. Add fallback notification strategies if permissions denied.

## Security Considerations

**Spotify Access Token Storage:**
- Risk: OAuth access tokens stored in plaintext SQLite database
- Files: `lib/database/settings.dart` (spotifyAccessToken column), `lib/spotify/spotify_state.dart` (line 383-388)
- Current mitigation: Tokens expire after 1 hour. App not cloud-connected.
- Recommendations: Encrypt tokens using platform keystore (Android Keystore / iOS Keychain). Use refresh tokens instead of storing access tokens. Add token rotation mechanism. Add device-lock requirement before accessing stored credentials.

**Import Database Vulnerability:**
- Risk: Users can replace entire database with untrusted files via import without validation
- Files: `lib/import_data.dart` (lines 77-96)
- Current mitigation: No validation of imported file structure or data integrity
- Recommendations: Add database schema validation before import. Warn user about data replacement. Add import preview showing what will be replaced. Implement atomic rollback on import failure.

**File Picker Security:**
- Risk: File picker on Android can access any file if user selects it
- Files: `lib/backup/auto_backup_settings.dart`, `lib/import_data.dart`
- Current mitigation: Uses file_picker package (no additional checks)
- Recommendations: Restrict file picker to appropriate directories. Add file size limits. Validate file headers match expected database format.

## Missing Critical Features

**Database Backup Verification:**
- Issue: No integrity check after backup completes. Backup file could be corrupted or incomplete.
- Impact: Users discover backup unusable only during restore
- Fix: Calculate checksum of backup file. Verify backup file size reasonable. Add backup verification option.

**Workout Resume Logic Flaw:**
- Issue: `resumeWorkout()` adjusts startTime to preserve duration, but doesn't account for overlapping time periods in statistics
- Files: `lib/workouts/workout_state.dart` (lines 157-170)
- Impact: Personal records may be incorrectly calculated for paused/resumed workouts
- Fix: Track pause/resume history separately. Recalculate PR detection after resume.

**Error Recovery Dashboard:**
- Issue: `FailedMigrationsPage` shows error but provides no recovery path
- Files: `lib/database/failed_migrations_page.dart`
- Impact: Users stuck with app showing error, no way to proceed
- Fix: Provide migration rollback option. Allow export of current data before attempting migration recovery.

## Test Coverage Gaps

**Database Migration Testing:**
- What's not tested: Migrations from v31-v61 with actual user data. Edge cases like missing columns, corrupted WAL files.
- Files: `lib/database/database.dart` (migration logic lines 60-320)
- Risk: Silent failures in migrations discovered only in production after users upgrade
- Priority: **High** - Database integrity is critical

**Spotify Connection Recovery:**
- What's not tested: Token expiry during active session, network reconnection, permission revocation
- Files: `lib/spotify/spotify_service.dart`, `lib/spotify/spotify_state.dart`
- Risk: Music feature becomes unusable without clear error messages
- Priority: **High** - User-facing feature with no error recovery

**Backup Restore Scenarios:**
- What's not tested: Restore on fresh install, restore with schema version mismatch, restore with missing data
- Files: `lib/import_data.dart`, `lib/backup/auto_backup_service.dart`
- Risk: Data loss during restore operations
- Priority: **High** - Data-destructive operation

**Active Workout State Consistency:**
- What's not tested: Simultaneous operations on activeWorkout and activePlan, rapid state transitions
- Files: `lib/workouts/workout_state.dart`, `lib/plan/start_plan_page.dart`
- Risk: Race conditions causing crashes or inconsistent UI
- Priority: **Medium** - Core feature but rare edge case

---

*Concerns audit: 2026-02-02*
