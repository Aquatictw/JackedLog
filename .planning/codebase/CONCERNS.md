# Codebase Concerns

**Analysis Date:** 2026-01-18

## Tech Debt

**Timer Service Missing Core Features:**
- Issue: Alarm sound and vibration are not implemented in native timer service
- Files: `native/flexify_native/timer_service.h` (line 74)
- Impact: Users cannot configure audible alerts or haptic feedback when rest timers complete, reducing timer utility during workouts
- Fix approach: Implement alarm sound playback and vibration pattern using platform-specific APIs (Android MediaPlayer/Vibrator, iOS AVAudioPlayer/UINotificationFeedbackGenerator)

**Silent Error Handling in Critical Paths:**
- Issue: Multiple services use silent failure with empty catch blocks or minimal logging
- Files:
  - `lib/backup/auto_backup_service.dart` (lines 54-57, 198-205, 240-242)
  - `lib/spotify/spotify_state.dart` (lines 239-247, 267-269, 320-324)
  - `lib/spotify/spotify_service.dart` (lines 136-141)
  - `lib/database/database.dart` (lines 360-363)
- Impact: Failures occur invisibly to users, making debugging difficult and potentially causing data loss without notification
- Fix approach: Implement proper error logging service, show user-facing error messages for critical operations (backup failures), add telemetry for debugging production issues

**Auto-Backup Lacks User Feedback:**
- Issue: Auto-backup service fails silently on error (catch block returns false with no user notification)
- Files: `lib/backup/auto_backup_service.dart` (lines 54-57)
- Impact: Users may believe backups are working when they're actually failing (permissions, disk space, path issues), leading to data loss risk
- Fix approach: Add notification when backup fails, store last backup status in Settings table, show warning badge in settings UI when backups are failing

**Generated Migration File Size:**
- Issue: Migration steps file is 9241 lines, contains 60 schema versions with full table definitions for each version
- Files: `lib/database/database.steps.dart` (9241 lines)
- Impact: Increases app size, slows build times, difficult to review in version control
- Fix approach: Consider drift's schema versioning alternatives, evaluate if old migrations (v1-v50) can be consolidated since active users likely on recent versions

**No Token Refresh for Spotify:**
- Issue: Spotify access tokens expire after 1 hour with no refresh mechanism
- Files: `lib/spotify/spotify_service.dart` (lines 91-92), `lib/spotify/spotify_state.dart` (lines 275-278)
- Impact: Users must manually reconnect every hour during long workout sessions, disrupting music playback
- Fix approach: Implement OAuth refresh token flow, store refresh token in Settings table, auto-refresh when token expires

**Deprecated Navigation Implementation Still Present:**
- Issue: Old bottom navigation file exists alongside new segmented pill navigation
- Files: `lib/bottom_nav.dart` (deprecated per `claude.md` line 237)
- Impact: Code confusion, maintenance burden, potential for accidentally using wrong navigation
- Fix approach: Remove deprecated file after confirming no references remain, update feature flag removal plan

## Known Bugs

**Critical Auto-Backup Crash (Recently Fixed):**
- Symptoms: App crashed during automatic backup operations
- Files: Recent commit 24391964 "BREAKING CHANGE: fix critical crash bug cause by auto backup"
- Trigger: Auto-backup triggered at app startup or during workout sessions
- Workaround: Fixed in latest version, but indicates backup system is fragile

**Spotify Connection Timeouts:**
- Issue: Connection attempts timeout after 30 seconds with no retry mechanism
- Files: `lib/spotify/spotify_service.dart` (lines 84-90, 110-116)
- Trigger: Slow network, Spotify app not running, first-time OAuth flow
- Workaround: Users must manually retry connection
- Impact: Poor UX during initial setup or connection issues

## Security Considerations

**Spotify Credentials in Settings Table:**
- Risk: OAuth tokens stored in plaintext SQLite database
- Files: `lib/database/settings.dart` (spotifyAccessToken, spotifyTokenExpiry fields)
- Current mitigation: Local device storage only, not transmitted
- Recommendations:
  - Use platform secure storage (Android Keystore, iOS Keychain) for tokens
  - Encrypt tokens before storing in database
  - Clear tokens on app uninstall or logout

**Backup Files Contain Sensitive Data:**
- Risk: Backup files (.db) exported to user-selected directories may contain workout notes, bodyweight data, personal records
- Files: `lib/backup/auto_backup_service.dart` (lines 86-102)
- Current mitigation: User controls backup location
- Recommendations:
  - Warn users about sensitive data in backups
  - Consider optional backup encryption
  - Validate backup directory permissions before creating files

**Database File Accessible:**
- Risk: SQLite database file stored in application documents directory is readable by backup tools, file explorers with root access
- Files: `lib/database/database_connection_native.dart` (line 94)
- Current mitigation: Android app sandbox, requires root for direct access
- Recommendations:
  - Enable SQLite encryption (SQLCipher) for sensitive user data
  - Document that backups are unencrypted in privacy policy

## Performance Bottlenecks

**Spotify Polling Every 1 Second:**
- Problem: Timer polls Spotify player state every 1 second when music page is active
- Files: `lib/spotify/spotify_state.dart` (lines 202-206)
- Cause: No push-based event system, must poll for playback position updates
- Improvement path:
  - Increase interval to 2 seconds for position updates (still smooth for UI)
  - Use Spotify SDK event streams if available instead of polling
  - Stop polling when app is backgrounded

**Web API Calls Every 5 Seconds:**
- Problem: Queue, recently played, and context fetched every 5 polling ticks (every 5 seconds)
- Files: `lib/spotify/spotify_state.dart` (lines 224-226)
- Cause: REST API has no push mechanism for queue changes
- Improvement path:
  - Reduce to every 10-15 seconds (queue doesn't change that often)
  - Only fetch when user opens queue/recently played bottom sheets
  - Implement exponential backoff on API errors

**Database Query Ordering Performance:**
- Problem: Set ordering uses complex COALESCE with julianday calculation on every query
- Files: `claude.md` line 284 mentions ordering pattern
- Cause: Fallback for null setOrder values using creation timestamp
- Improvement path:
  - Migrate all existing null setOrder values to actual integers during upgrade
  - Create index on (workoutId, sequence, setOrder) for faster queries
  - Remove COALESCE fallback after migration

**Large Sets Queries Without Pagination:**
- Problem: History views load all sets/workouts without pagination
- Files: Based on architecture, likely `lib/sets/history_list.dart`, `lib/workouts/workout_detail_page.dart`
- Cause: No pagination implementation for long workout histories
- Improvement path:
  - Implement lazy loading with limit/offset
  - Use drift's built-in pagination support
  - Add "Load more" button or infinite scroll

## Fragile Areas

**Database Migration Chain:**
- Files: `lib/database/database.dart` (migrations from v1 to v60)
- Why fragile: 60 sequential migrations must all succeed or database is unrecoverable, no rollback mechanism
- Safe modification:
  - Always test migration path from previous version
  - Never modify existing migration code once released
  - Test with real user databases from multiple versions
  - Maintain test database files for each schema version
- Test coverage: Migration tests exist in `test/database/database_migration_test.dart` but may not cover all edge cases

**Workout State Management:**
- Files: `lib/workouts/workout_state.dart`
- Why fragile:
  - Single active workout enforced in application layer, not database constraints
  - Error in `_loadActiveWorkout()` is silently caught (line 13-16)
  - Resume logic modifies startTime to maintain elapsed timer (lines 163-164)
- Safe modification:
  - Always use WorkoutState methods, never modify workouts table directly
  - Test resume/stop/discard operations thoroughly
  - Verify endTime=NULL queries return at most one result
- Test coverage: Tests exist in `test/workouts/workout_state_test.dart`, `test/workouts/workout_state_integration_test.dart`

**Spotify Integration State:**
- Files: `lib/spotify/spotify_state.dart`, `lib/spotify/spotify_service.dart`
- Why fragile:
  - Token expiry not enforced at API layer, relies on hasValidToken checks
  - Polling timer must be manually started/stopped (memory leak potential)
  - Connection state can desync between SpotifyService and SpotifyState
- Safe modification:
  - Always check `hasValidToken` before API calls
  - Ensure `stopPolling()` called in dispose methods
  - Test token expiry scenarios
  - Verify connection state matches SDK state
- Test coverage: Basic tests in `test/spotify/spotify_state_test.dart`, `test/spotify/spotify_token_test.dart`

**Native Timer Threading:**
- Files: `native/flexify_native/timer_service.h` (C++ template with threads)
- Why fragile:
  - Manual thread lifecycle management (lines 46, 61, 70, 79)
  - Timer expiration checked with polling loop (lines 121-127)
  - Platform-specific calls could crash if not implemented
- Safe modification:
  - Always join threads before destruction
  - Test on all supported platforms
  - Verify platform-specific notification implementations exist
- Test coverage: Unknown (likely requires integration testing on device)

## Scaling Limits

**Single Active Workout Constraint:**
- Current capacity: 1 active workout at a time
- Limit: Cannot track multiple simultaneous workouts (e.g., training with partner, circuit training)
- Scaling path: Remove single workout constraint, add UI to switch between active workouts, update ActiveWorkoutBar to show multiple workouts

**Backup File Naming:**
- Current capacity: One backup per day (filename based on date)
- Limit: Multiple backups on same day overwrite each other (jackedlog_backup_YYYY-MM-DD.db)
- Scaling path: Add timestamp to filename (jackedlog_backup_YYYY-MM-DD_HH-MM-SS.db), update cleanup logic to handle multiple daily backups

**Spotify Polling Concurrency:**
- Current capacity: Single-threaded polling with 1-second intervals
- Limit: Cannot handle multiple music sources or offline playback state
- Scaling path: Abstract music provider interface, support multiple providers (Spotify, local files, YouTube Music), implement proper state machine for connection lifecycle

**Database File Size:**
- Current capacity: SQLite file grows unbounded with workout history
- Limit: Large databases (>100MB) may cause performance degradation on older devices
- Scaling path: Implement data archiving (move old workouts to separate archive table), add database vacuum operations, provide export/delete old data tools

## Dependencies at Risk

**drift_dev and build_runner:**
- Risk: Code generation dependency mismatch can break builds
- Impact: Cannot compile app until version conflicts resolved
- Migration plan: Pin exact versions in pubspec.yaml, test upgrades in separate branch, maintain compatibility with drift 2.28.1 runtime

**spotify_sdk:**
- Risk: Third-party package with limited maintenance, Android/iOS platform-specific code
- Impact: Spotify integration breaks on OS updates, package may be abandoned
- Migration plan:
  - Consider direct Spotify Web API implementation without SDK
  - Implement adapter pattern to isolate SDK dependencies
  - Have fallback music controls ready

**Flutter SDK 3.2.6:**
- Risk: Pinned to older SDK version may miss security fixes and performance improvements
- Impact: Cannot use newer Flutter features, potential compatibility issues with newer Android/iOS versions
- Migration plan: Test on Flutter 3.x stable releases, update analysis_options.yaml for new lints, verify drift compatibility with newer SDK

## Missing Critical Features

**No Error Reporting/Telemetry:**
- Problem: Production crashes and errors are invisible without user reports
- Blocks: Proactive bug fixing, understanding user issues, measuring stability
- Priority: High - essential for production app quality

**No Data Corruption Recovery:**
- Problem: If database becomes corrupted, user has no recovery tools
- Blocks: Data recovery from backup, partial data salvage, user trust
- Priority: High - data loss is catastrophic for fitness tracking app

**No Offline Queue for Spotify:**
- Problem: Cannot queue music changes when Spotify connection drops
- Blocks: Seamless music experience during workouts with poor connectivity
- Priority: Medium - degraded UX but not blocking

**No Export to Standard Formats:**
- Problem: Export is CSV only, cannot export to other fitness platforms (Strong, Google Fit, etc.)
- Blocks: Platform migration, data portability, integration with other tools
- Priority: Medium - reduces lock-in but CSV export exists

## Test Coverage Gaps

**UI Widget Tests:**
- What's not tested: Most UI components lack widget tests (only 12 test files for 125 lib files)
- Files: `lib/music/`, `lib/plan/`, `lib/sets/`, `lib/widgets/` directories
- Risk: UI regressions go unnoticed, refactoring breaks layouts
- Priority: Medium - manual testing currently used

**Spotify Integration Edge Cases:**
- What's not tested: Network failures, token expiry during polling, SDK connection drops
- Files: `lib/spotify/` directory
- Risk: Music integration breaks in production scenarios not covered by basic tests
- Priority: High - Spotify is complex integration with many failure modes

**Backup System:**
- What's not tested: Backup file corruption, disk space exhaustion, permission errors, cleanup edge cases
- Files: `lib/backup/auto_backup_service.dart`, `lib/backup/auto_backup_settings.dart`
- Risk: Backups fail silently, users lose data when restore is needed
- Priority: High - backup is critical safety feature

**Database Migration Rollback:**
- What's not tested: Failed migration recovery, partial migration states
- Files: `lib/database/database.dart` (migration chain)
- Risk: Users stuck on broken database version with no recovery path
- Priority: High - migration failures can brick app

**Native Timer Service:**
- What's not tested: Timer service lifecycle, threading behavior, platform-specific notifications
- Files: `native/flexify_native/timer_service.h`
- Risk: Timer crashes or misbehaves on certain devices/OS versions
- Priority: Medium - timer is well-used feature but hard to unit test

**Performance Under Load:**
- What's not tested: Large database performance (1000+ workouts), heavy concurrent operations
- Files: All database query code
- Risk: App becomes unusable for long-time users with extensive history
- Priority: Low - can be addressed when users report issues

---

*Concerns audit: 2026-01-18*
