# Technology Stack

**Analysis Date:** 2026-01-18

## Languages

**Primary:**
- Dart 3.10.7 - Application logic and UI (Flutter framework)
- Kotlin 2.1.0 - Android platform integration and native services

**Secondary:**
- Groovy - Gradle build configuration scripts

## Runtime

**Environment:**
- Flutter 3.38.7 (stable channel)
- Dart SDK 3.10.7
- Android NDK 28.2.13676358

**Package Manager:**
- pub (Flutter's package manager)
- Lockfile: pubspec.lock (present)
- Gradle 8.11.1 for Android dependencies

## Frameworks

**Core:**
- Flutter 3.38.7 - Cross-platform UI framework
- Material Design - UI component library

**Testing:**
- flutter_test (SDK) - Unit and widget testing
- integration_test (SDK) - Integration testing
- mockito 5.4.4 - Mock generation for testing

**Build/Dev:**
- build_runner 2.6.0 - Code generation orchestration
- drift_dev 2.28.1 - Database schema code generation
- flutter_lints 6.0.0 - Static analysis and linting
- flutter_launcher_icons 0.14.2 - Icon generation

## Key Dependencies

**Critical:**
- drift 2.28.1 - SQL database ORM and query builder for local data persistence
- sqlite3_flutter_libs 0.5.39 - Native SQLite3 bindings for Flutter
- sqlite3 2.4.0 - SQLite database engine
- provider 6.1.1 - State management solution (used for SettingsState, TimerState, PlanState, WorkoutState, SpotifyState)

**Infrastructure:**
- path_provider 2.1.2 - Platform-specific directory paths
- path 1.8.3 - Cross-platform path manipulation
- permission_handler 12.0.1 - Runtime permission requests (storage, notifications, alarms)
- package_info_plus 8.0.0 - App version and metadata access

**UI & Visualization:**
- fl_chart 1.0.0 - Chart and graph rendering for workout visualizations
- dynamic_color 1.7.0 - Material You dynamic color theming
- badges 3.1.2 - Badge widgets for UI notifications
- rive 0.13.18 - Rive animation playback
- palette_generator 0.3.3 - Color palette extraction from images

**Media & Integration:**
- spotify_sdk 3.0.0 - Spotify App Remote SDK integration
- audioplayers 6.5.0 - Audio playback functionality
- image_picker 1.0.7 - Camera and gallery image selection
- file_picker 10.2.0 - Document and file selection

**Utilities:**
- intl 0.20.2 - Internationalization and date formatting
- csv 6.0.0 - CSV file parsing and generation
- share_plus 11.0.0 - Native share sheet integration
- url_launcher 6.2.6 - URL and deep link handling
- http 1.2.0 - HTTP client for REST API calls
- archive 4.0.0 - Archive/compression utilities
- timeago 3.2.2 - Relative time formatting
- flutter_local_notifications 19.3.0 - Local notification scheduling

**Android-Specific:**
- androidx.appcompat:appcompat 1.6.1 - Android backward compatibility
- androidx.constraintlayout:constraintlayout 2.1.4 - Layout framework
- androidx.documentfile:documentfile 1.0.1 - Document provider access
- androidx.multidex:multidex 2.0.1 - 64K method limit support
- desugar_jdk_libs 2.1.4 - Java 8+ API backporting for older Android
- kotlin-bom 1.8.22 - Kotlin dependency management

## Configuration

**Environment:**
- Flutter SDK path configured in `android/local.properties`
- Spotify credentials in `lib/spotify/spotify_config.dart` (gitignored)
- Signing keys in `android/key.properties` (if present, for release builds)
- Environment: `sdk: ">=3.2.6 <4.0.0"` in `pubspec.yaml`

**Build:**
- `pubspec.yaml` - Flutter dependencies and app metadata
- `android/build.gradle` - Project-level Gradle configuration
- `android/app/build.gradle` - App-level Android build settings
- `android/settings.gradle` - Gradle plugin management
- `android/gradle.properties` - Gradle JVM and AndroidX settings
- Kotlin version: 2.1.0
- Android Gradle Plugin: 8.1.1
- Flutter Gradle Plugin: 1.0.0
- NDK version: 28.2.13676358

## Platform Requirements

**Development:**
- Flutter SDK 3.38.7+
- Dart SDK 3.10.7+
- Android SDK with compileSdk determined by Flutter
- Java 8+ for Android builds (coreLibraryDesugaring enabled)
- Kotlin 2.1.0

**Production:**
- Android minSdkVersion: Determined by Flutter defaults
- Android targetSdkVersion: Determined by Flutter defaults
- Android compileSdkVersion: Determined by Flutter defaults
- Target platforms: Android (primary)
- Package: com.aquatic.jackedlog
- Reproducible builds configured (BUILD_TIME set to 0L)

---

*Stack analysis: 2026-01-18*
