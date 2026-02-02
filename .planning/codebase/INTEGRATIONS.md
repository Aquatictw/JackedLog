# External Integrations

**Analysis Date:** 2026-02-02

## APIs & External Services

**Spotify Web API:**
- Spotify Remote Control - Playback control (play/pause/skip/shuffle/repeat)
  - SDK: `spotify_sdk` 3.0.0
  - Auth: OAuth 2.0 via App Remote authentication
  - Client ID: `863114deabcd4efca171f381b6f8d459` (in `lib/spotify/spotify_config.dart`)
  - Scopes: `app-remote-control`, `user-modify-playback-state`, `user-read-playback-state`, `user-read-currently-playing`, `user-read-recently-played`
  - Redirect URL: `jackedlog://spotify-auth-callback`
  - Base URL: `https://api.spotify.com/v1`
  - Rate limiting: Handles 429 responses with retry logic
  - Token expiry: 1 hour from acquisition, stored in Settings table

**Spotify Web API Endpoints:**
- `GET /me/player/queue` - Fetch current playback queue
- `GET /me/player/recently-played?limit=10` - Fetch recently played tracks (limited to 10)
- `GET /v1/me/player/currently-playing` - Fetch current playback context
- Image CDN: `https://i.scdn.co/image/{imageId}` - Album artwork

## Data Storage

**Databases:**
- SQLite 3.x (local only)
  - File: `jackedlog.sqlite` in app documents directory
  - Client: Drift ORM via `sqlite3_flutter_libs`
  - Connection: Native SQLite connection via `lib/database/database_connection_native.dart`
  - WAL Mode: Write-Ahead Logging enabled for concurrent access
  - Checkpoint: PRAGMA wal_checkpoint(TRUNCATE) performed before backups

**Tables:**
- `plans` - Workout plans (references, exercises)
- `gym_sets` - Individual exercise sets with metrics (weight, reps, cardio data)
- `settings` - User preferences, Spotify tokens, backup configuration
- `plan_exercises` - Exercise definitions and library
- `metadata` - Application metadata
- `workouts` - Workout session records
- `notes` - Workout notes
- `bodyweight_entries` - Body weight tracking history

**File Storage:**
- Local filesystem only via `path_provider`
- Backup directory: User-selected via SAF (Storage Access Framework) on Android 10+
- Path: `getApplicationDocumentsDirectory()` for primary database

**Caching:**
- Spotify Web API service cache: Cleared on disconnect (`SpotifyWebApiService.clearCache()`)
- In-memory: Provider state caches (SpotifyState, WorkoutState, SettingsState)

## Authentication & Identity

**Auth Provider:**
- Spotify OAuth 2.0 (custom implementation)
  - Implementation: `SpotifyService` singleton with token lifecycle management (`lib/spotify/spotify_service.dart`)
  - Token acquisition: `SpotifySdk.getAccessToken()` via Spotify SDK
  - Token storage: Encrypted in Settings table (`spotifyAccessToken`, `spotifyTokenExpiry`)
  - Token validation: `hasValidToken` check before API calls
  - Reconnection: Automatic if token expires during polling

**No other authentication providers:**
- App-local only, no user accounts or cloud sync

## Monitoring & Observability

**Error Tracking:**
- Print statements with emojis (e.g., `🎵 Connection error: $e`)
- Spotify errors logged: Connection timeouts (30s), token expiry (401), rate limiting (429)
- Database migration failures: Custom error page (`lib/database/failed_migrations_page.dart`)

**Logs:**
- Console logging via Dart `print()` statements
- Captured in Android Logcat
- No persistent log storage

## CI/CD & Deployment

**Hosting:**
- Android app distribution (primary target)
- Source distribution only, no cloud backend

**CI Pipeline:**
- Not detected - manual build process
- Flutter build commands: `flutter build apk`, `flutter build appbundle`

**Build Configuration:**
- App ID: `com.presley.jackedlog`
- Method Channel: `com.presley.jackedlog/android` for native backup/restore
- Signing: Android key store (`android/key.properties`)

## Environment Configuration

**Required env vars:**
- None at runtime
- Spotify credentials hardcoded in `lib/spotify/spotify_config.dart`

**Secrets location:**
- Spotify Client ID: `lib/spotify/spotify_config.dart` (note: hardcoded in source, not Git-ignored)
- Database encryption: None - SQLite database stored plaintext
- Backup encryption: None - backups stored plaintext

**Sensitive files:**
- `android/key.properties` - Android signing keystore (Git-ignored)
- `android/local.properties` - Build configuration (Git-ignored)

## Webhooks & Callbacks

**Incoming:**
- Deep link callback: `jackedlog://spotify-auth-callback` - Spotify OAuth redirect
- Android intent filters configured for Spotify redirect handling

**Outgoing:**
- File sharing via system share sheet (Share Plus)
- No server-side webhooks

## Platform-Specific Integrations

**Android Native Channels:**
- `com.presley.jackedlog/android` method channel for:
  - `performBackup` - SAF backup using native Android APIs
  - `cleanupOldBackups` - Cleanup GFS-policy backups in SAF directories
  - Screenshot functionality (method: `takeScreenshot`)

**Permissions (Android Manifest):**
- `READ_EXTERNAL_STORAGE` - Import database/CSV files
- `WRITE_EXTERNAL_STORAGE` - Export backups to user-selected directories
- `POST_NOTIFICATIONS` - Timer completion notifications (Android 13+)
- `READ_CALENDAR` - Plan integration with calendar (if available)
- `SCHEDULE_EXACT_ALARM` - Timer notifications

## Data Synchronization

**Backup & Restore:**
- Manual export: Full database via `ExportData` widget
- Manual import: Full database via `ImportData` widget
- Auto-backup: `AutoBackupService` - 24-hour interval, GFS retention policy
- Export formats: `.db` (binary SQLite), `.csv` (workouts/sets)
- Backup trigger: App pause/detach lifecycle event

**Third-Party Sync:**
- Hevy.co import: CSV parsing from `import_hevy.dart` (no live sync)
- No cloud sync or real-time collaboration

---

*Integration audit: 2026-02-02*
