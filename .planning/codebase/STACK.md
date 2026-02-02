# Technology Stack

**Analysis Date:** 2026-02-02

## Languages

**Primary:**
- Dart 3.2.6+ - All application logic, UI, and database code

**Secondary:**
- Kotlin - Android native integration (Android custom method channels)
- Java - Android platform code

## Runtime

**Environment:**
- Flutter SDK (version specified by project constraints)
- Dart VM for development
- Android Runtime (ARM64, ARM32, x86_64) for production

**Package Manager:**
- Pub - Dart package manager
- Lockfile: `pubspec.lock` (present, at `pubspec.lock`)

## Frameworks

**Core:**
- Flutter 3.x - UI framework, cross-platform mobile development
- Drift 2.28.1 - Type-safe database ORM with code generation

**State Management:**
- Provider 6.1.1 - ChangeNotifier-based state management pattern

**UI & Visualization:**
- Material Design 3 - Design system via `flutter:` SDK
- FL Chart 1.0.0 - Strength/cardio graphs and statistics
- Dynamic Color 1.7.0 - Material You color extraction
- Rive 0.13.18 - Animated vectors (splash screen, animations)
- Palette Generator 0.3.3 - Album artwork color analysis

**Audio & Media:**
- Spotify SDK 3.0.0 - Spotify playback control and authentication
- Audio Players 6.5.0 - Timer sound playback
- Package Info Plus 8.0.0 - App version retrieval

**File & Data Operations:**
- CSV 6.0.0 - Workout/set export and import
- Archive 4.0.0 - Database backup/restore compression
- File Picker 10.2.0 - User file selection (import/export)
- Path Provider 2.1.2 - Platform-specific directory access
- Path 1.8.3 - Cross-platform path utilities

**Notifications & System:**
- Flutter Local Notifications 19.3.0 - Timer completion notifications
- Permission Handler 12.0.1 - Runtime permission requests (storage, notifications, calendar)
- Image Picker 1.0.7 - Exercise image capture/selection
- Share Plus 11.0.0 - Share data via system share sheet
- URL Launcher 6.2.6 - Deep linking and external URL opening

**Localization & Formatting:**
- Intl 0.20.2 - Date/time formatting and localization
- TimeAgo 3.2.2 - Relative time display

**UI Components:**
- Cupertino Icons 1.0.2 - iOS-style icon set
- Badges 3.1.2 - Notification/count badges

**Testing:**
- Flutter Test 6.0.0 - Unit and widget testing
- Mockito 5.4.4 - Mocking for tests
- Build Runner 2.6.0 - Code generation runner
- Drift Dev 2.28.1 - Database schema code generation
- Integration Test - Flutter integration testing framework

## Key Dependencies

**Critical:**
- `drift` 2.28.1 - Database persistence layer, manages all user data (workouts, exercises, settings, notes, plans)
- `sqlite3_flutter_libs` 0.5.39 - Native SQLite3 bindings for Flutter
- `sqlite3` 2.4.0 - SQLite database access
- `provider` 6.1.1 - Enables reactive state management across entire app (settings, workouts, timers, music)
- `spotify_sdk` 3.0.0 - OAuth authentication and remote control for Spotify integration

**Infrastructure:**
- `path_provider` - Locates app-specific directories for database and backups
- `flutter_local_notifications` - Manages system notifications for timer completion
- `permission_handler` - Handles Android runtime permissions (READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE, POST_NOTIFICATIONS)

## Configuration

**Environment:**
- SDK constraint: `>=3.2.6 <4.0.0`
- Compile target: Android 10+, Material 3 enabled by default
- Spotify OAuth: Client ID and redirect URL in `lib/spotify/spotify_config.dart`

**Build:**
- Build Runner: Code generation for Drift ORM
- Flutter Launcher Icons: Icon generation (`flutter_launcher_icons` 0.14.2) configured in `pubspec.yaml`
- Custom build.yaml: Drift schema generation

**Critical Files:**
- `pubspec.yaml` - Package manifest with version 1.1.2+2
- `analysis_options.yaml` - Strict linting with 150+ rules enforced

## Platform Requirements

**Development:**
- Flutter SDK (Dart 3.2.6+)
- Android NDK for native SQLite compilation
- Gradle for Android build system
- Cocoa Pods for iOS dependencies (if building for iOS)

**Production:**
- Target: Android 10+ (API level 29+)
- Minimum: Android 10 with SQLite 3.x native support
- Storage: Requires WRITE_EXTERNAL_STORAGE for backups, READ_EXTERNAL_STORAGE for imports
- Notifications: POST_NOTIFICATIONS permission (Android 13+)
- Database: SQLite WAL (Write-Ahead Logging) mode enabled

---

*Stack analysis: 2026-02-02*
