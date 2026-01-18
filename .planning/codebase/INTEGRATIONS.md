# External Integrations

**Analysis Date:** 2026-01-18

## APIs & External Services

**Spotify:**
- Spotify App Remote SDK - Music playback control during workouts
  - SDK/Client: spotify_sdk 3.0.0 (Flutter package)
  - Native SDK: spotify-app-remote-release-0.8.0.aar (Android)
  - Auth: OAuth flow with scopes
  - Client ID: Stored in `lib/spotify/spotify_config.dart`
  - Redirect URL: `jackedlog://spotify-auth-callback`
  - Scopes: app-remote-control, user-modify-playback-state, user-read-playback-state, user-read-currently-playing, user-read-recently-played
  - Implementation: `lib/spotify/spotify_service.dart` (singleton service)
  - Web API access: `lib/spotify/spotify_web_api_service.dart` (REST API calls)
  - State management: `lib/spotify/spotify_state.dart` (Provider-based)

- Spotify Web API - REST API for queue and playback information
  - Base URL: `https://api.spotify.com/v1`
  - Client: http 1.2.0 package
  - Auth: Bearer token from App Remote OAuth flow
  - Token expiry: 1 hour after acquisition
  - Endpoints used: `/me/player/queue`

**Google Play Store:**
- Deep link integration for Spotify app installation
  - URL: `https://play.google.com/store/apps/details?id=com.spotify.music`
  - Used when Spotify app not installed

## Data Storage

**Databases:**
- SQLite (local)
  - Connection: Local file via drift ORM
  - Client: drift 2.28.1 with sqlite3_flutter_libs 0.5.39
  - Database location: Platform-specific app data directory (via path_provider)
  - Tables: Plans, GymSets, Settings, PlanExercises, Metadata, Workouts, Notes, BodyweightEntries
  - Schema definition: `lib/database/database.dart`
  - Generated code: `lib/database/database.g.dart`
  - Migration strategy: stepByStep migrations defined in database.steps.dart

**File Storage:**
- Local filesystem only
  - Image storage: Workout selfies and exercise images via image_picker 1.0.7
  - Backup files: Database backups to user-selected directory
  - Document access: Via permission_handler 12.0.1 and documentfile library
  - Paths managed by: path_provider 2.1.2

**Caching:**
- None (app operates fully offline with local SQLite storage)

## Authentication & Identity

**Auth Provider:**
- Spotify OAuth (for music integration only)
  - Implementation: Custom OAuth flow via Spotify SDK
  - Token storage: In app database Settings table
  - Token fields: `spotifyAccessToken`, `spotifyTokenExpiry`
  - Token lifecycle: Restored from database on app start, expires after 1 hour
  - Reconnection: Manual via UI when token expires

## Monitoring & Observability

**Error Tracking:**
- None (no external crash reporting or analytics)

**Logs:**
- Console logging only (print statements)
  - Debug prefixes: 🎵 (Spotify), ⚠️ (warnings), ✓ (success)
  - No log aggregation service

## CI/CD & Deployment

**Hosting:**
- Not applicable (native Android app)
  - Distributed via Android APK/AAB builds
  - Self-signed or keystore-signed releases

**CI Pipeline:**
- None detected in repository
  - Manual builds via flutter build apk/appbundle
  - Reproducible builds configured (deterministic timestamps)

## Environment Configuration

**Required env vars:**
- None (configuration via files, not environment variables)

**Configuration files:**
- `android/local.properties` - Flutter SDK path
- `android/key.properties` - Release signing credentials (optional, not in repo)
- `lib/spotify/spotify_config.dart` - Spotify OAuth credentials

**Secrets location:**
- Spotify Client ID: `lib/spotify/spotify_config.dart` (gitignored, hardcoded for development)
- Signing keys: `android/key.properties` (not in repository)
- Access tokens: Stored in local SQLite database Settings table

## Webhooks & Callbacks

**Incoming:**
- Spotify OAuth callback
  - Scheme: `jackedlog://spotify-auth-callback`
  - Handler: MainActivity intent filter in `android/app/src/main/AndroidManifest.xml`
  - Processing: Captured by spotify_sdk package

**Outgoing:**
- None

## Platform Services

**Android System Services:**
- Notifications: flutter_local_notifications 19.3.0
  - Permission: POST_NOTIFICATIONS
  - Use case: Timer completion alerts

- Alarms: SCHEDULE_EXACT_ALARM permission
  - Use case: Precise timer notifications
  - Receiver: AlarmManager integration

- Foreground Service: TimerService
  - Type: FOREGROUND_SERVICE_SPECIAL_USE
  - Implementation: `android/app/src/main/kotlin/.../TimerService.kt`
  - Purpose: Rest timer during workouts

- Boot Receiver: BootReceiver
  - Implementation: `android/app/src/main/kotlin/.../BootReceiver.kt`
  - Purpose: Restore scheduled alarms/backups after device restart

- Backup Receiver: BackupReceiver
  - Implementation: `android/app/src/main/kotlin/.../BackupReceiver.kt`
  - Purpose: Scheduled automatic database backups

- Update Receiver: UpdateReceiver
  - Action: MY_PACKAGE_REPLACED
  - Purpose: Post-update initialization

**Permissions:**
- INTERNET - Spotify API and Web API calls
- POST_NOTIFICATIONS - Local notifications
- FOREGROUND_SERVICE - Timer service
- REQUEST_IGNORE_BATTERY_OPTIMIZATIONS - Background timer reliability
- VIBRATE - Haptic feedback for records/timers
- WAKE_LOCK - Keep screen on during timer
- SCHEDULE_EXACT_ALARM - Precise timer alarms
- RECEIVE_BOOT_COMPLETED - Restore on boot

**Method Channel:**
- Channel name: `com.presley.jackedlog/android`
- Implementation: `lib/main.dart` (androidChannel)
- Purpose: Dart-to-Kotlin communication for native features

## Data Export/Import

**Export Formats:**
- CSV - Via csv 6.0.0 package
  - Use case: Workout data export
  - Implementation: `lib/export_data.dart`

- Database backup - Raw SQLite file
  - Compressed: Via archive 4.0.0 package
  - Auto-backup service: `lib/backup/auto_backup_service.dart`
  - Frequency: 24-hour intervals (configurable)
  - Location: User-selected directory via file_picker

**Import Formats:**
- CSV - Generic workout import
  - Implementation: `lib/import_data.dart`

- Hevy format - Third-party app import
  - Implementation: `lib/import_hevy.dart`

**Sharing:**
- Native share integration via share_plus 11.0.0
  - Shares exported files via Android share sheet

---

*Integration audit: 2026-01-18*
