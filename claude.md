# JackedLog - Claude Code Context

## CRITICAL RULES - READ FIRST

### DO NOT run any Flutter commands, ask user to run `flutter analyze` or manually test
### Always do manual migration
### If database version has been changed, and previous exported data from app can't be reimported, affirm me.

## Core Development Philosophy

### KISS (Keep It Simple, Stupid)

Simplicity should be a key goal in design. Choose straightforward solutions over complex ones whenever possible. Simple solutions are easier to understand, maintain, and debug.

### YAGNI (You Aren't Gonna Need It)

Avoid building functionality on speculation. Implement features only when they are needed, not when you anticipate they might be useful in the future.

### Design Principles

- **Open/Closed Principle**: Software entities should be open for extension but closed for modification.
- **Single Responsibility**: Each function, class, and module should have one clear purpose.
- **Fail Fast**: Check for potential errors early and raise exceptions immediately when issues occur.

## Code Search & Analysis Tools
### Primary Tool: ripgrep (rg)
Use `rg` (ripgrep) as your **PRIMARY and FIRST** tool for:
- ANY code search or pattern matching
- Finding function/class definitions
- Locating method calls or usage patterns
- Refactoring preparation
- Code structure analysis
- Fast, repository-wide searches using regex or literals

### Secondary Tool: grep
Use `grep` **ONLY** when:
- `rg` is not available
- Searching plain text, comments, or documentation
- Searching non-code files (markdown, configs, etc.)
- `rg` explicitly fails or is not applicable

**NEVER** use `grep` for searches without trying `rg` first.

## Token Efficiency

### Optimize Responses By
- **Focused Context**: Only include relevant code sections
- **Avoid Repetition**: Don't restate what I've already confirmed
- **Summarize When Asked**: Always respond in a very concise and direct manner, providing only relevant information 
- Avoid **repeated or broad search commands** that may waste tokens

### Ask Before
- **Large File Changes**: "Should I show the entire file or just the diff?"
- **Multiple Approaches**: "Would you like me to explain alternatives or just go with the best option?"
- **Deep Dives**: "Do you need detailed explanation or just the solution?"

## Prohibited Actions

❌ **Never**:
- Run Flutter commands without explicit permission
- Modify database schema without impact analysis
- Suggest complex solutions when simple ones exist
- Add dependencies without discussing alternatives
- Generate large amounts of boilerplate without asking first

✅ **Always**:
- Consider backward compatibility
- Prefer Flutter/Dart built-ins over third-party packages when reasonable
- Think about edge cases and error scenarios
- Validate assumptions before implementing


## Project Overview

JackedLog is a Flutter/Dart fitness tracking mobile app (cross-platform: Android, iOS, Linux, macOS, Windows).

Comprehensive codebase documentation is organized in the sections below.

---

# Detailed Codebase Documentation

The following sections provide comprehensive analysis of the codebase architecture, conventions, and technical details.

---

## C. Architecture

**Analysis Date:** 2026-01-18

### Pattern Overview

**Overall:** State-driven Flutter application with Provider pattern for reactive UI updates

**Key Characteristics:**
- Multi-provider state management with ChangeNotifier pattern
- Local-first architecture with SQLite database using Drift ORM
- Feature-based directory structure with domain-specific state management
- Platform channel integration for Android-specific functionality

### Layers

**Presentation Layer:**
- Purpose: UI components and user interaction handling
- Location: `lib/` (page files) and `lib/widgets/`
- Contains: Stateful/Stateless Flutter widgets, page navigation, UI state
- Depends on: State layer (via Provider), Database layer (via global `db` instance)
- Used by: User interactions trigger state changes and navigation

**State Management Layer:**
- Purpose: Application state coordination and reactive updates
- Location: `lib/*/[feature]_state.dart` files
- Contains: ChangeNotifier subclasses managing feature-specific state
- Depends on: Database layer for persistence, Platform channels for native features
- Used by: Presentation layer via `context.watch<T>()` and `context.read<T>()`

**Database Layer:**
- Purpose: Data persistence and query operations
- Location: `lib/database/`
- Contains: Drift table definitions, migration logic, query helpers
- Depends on: SQLite native libraries via Drift
- Used by: State layer and presentation layer directly

**Service Layer:**
- Purpose: Isolated business logic and external integrations
- Location: `lib/backup/`, `lib/spotify/`, `lib/records/`
- Contains: Static utility classes and stateless service objects
- Depends on: Database layer, External APIs
- Used by: State layer and lifecycle hooks

**Platform Integration Layer:**
- Purpose: Native Android functionality access
- Location: `android/` (Kotlin), accessed via `MethodChannel` in `lib/main.dart`
- Contains: Timer notifications, Spotify SDK integration
- Depends on: Android platform APIs
- Used by: TimerState, SpotifyState

### Data Flow

**Workout Recording Flow:**

1. User taps "Start Workout" on PlansPage → Calls `WorkoutState.startWorkout(plan)`
2. WorkoutState creates Workout record in database, sets `_activeWorkout` field
3. `notifyListeners()` triggers UI rebuild across app
4. ActiveWorkoutBar appears at bottom of screen (watches WorkoutState)
5. User navigates to StartPlanPage to record sets
6. Each set saved via `db.gymSets.insertOne()` with `workoutId` foreign key
7. User taps "Finish" → Calls `WorkoutState.stopWorkout()`
8. WorkoutState updates Workout with `endTime`, clears `_activeWorkout`
9. RecordsService checks for personal records in background
10. UI updates automatically via Provider reactivity

**State Management:**
- Global state providers initialized in `main.dart` via `MultiProvider`
- Each feature has dedicated state class (PlanState, WorkoutState, TimerState, etc.)
- State classes use `StreamSubscription` to watch database changes (e.g., SettingsState)
- UI components use `context.watch<T>()` for reactive updates, `context.read<T>()` for actions

### Key Abstractions

**ChangeNotifier State Classes:**
- Purpose: Domain-specific reactive state containers
- Examples: `lib/plan/plan_state.dart`, `lib/workouts/workout_state.dart`, `lib/settings/settings_state.dart`, `lib/timer/timer_state.dart`, `lib/spotify/spotify_state.dart`
- Pattern: Extend ChangeNotifier, expose state via getters, mutate via methods that call `notifyListeners()`

**Drift Tables:**
- Purpose: Type-safe database schema definitions
- Examples: `lib/database/gym_sets.dart`, `lib/database/plans.dart`, `lib/database/workouts.dart`, `lib/database/settings.dart`
- Pattern: Define table structure as Dart classes, Drift generates query builders

**Global Database Instance:**
- Purpose: Singleton database access point
- Examples: `db` variable in `lib/main.dart`
- Pattern: `final db = AppDatabase()` accessed globally, initialized before `runApp()`

**Query Helpers:**
- Purpose: Optimize complex multi-query operations
- Examples: `lib/database/query_helpers.dart`
- Pattern: Static methods that batch database queries to reduce N+1 problems

### Entry Points

**main() Function:**
- Location: `lib/main.dart`
- Triggers: Application launch
- Responsibilities: Initialize database, load settings, setup providers, run app

**HomePage Widget:**
- Location: `lib/home_page.dart`
- Triggers: Mounted after successful initialization
- Responsibilities: Tab navigation controller, hosts main app sections (Plans, History, Graphs, Music, Notes, Settings)

**Platform Channel Handler:**
- Location: `lib/main.dart` line 47, `lib/timer/timer_state.dart` line 23
- Triggers: Native Android events (timer tick, notifications)
- Responsibilities: Bridge native timer events to TimerState

### Error Handling

**Strategy:** Defensive initialization with graceful degradation

**Patterns:**
- Try-catch blocks in async initialization methods (e.g., PlanState constructor, WorkoutState._loadActiveWorkout)
- Print warnings for non-critical errors, continue execution
- Fatal errors (database migration failures) show dedicated error page via `FailedMigrationsPage`
- State classes initialize with safe defaults, load data asynchronously
- Database queries use `getSingleOrNull()` instead of `getSingle()` to avoid crashes on missing data

### Cross-Cutting Concerns

**Logging:** Print statements with emoji prefixes (⚠️, ✓, 🎵) for visual categorization

**Validation:** Implicit via Drift type system and non-null safety; form validation in UI layer

**Authentication:** Spotify OAuth via SpotifyService, tokens stored in Settings table

---

## D. Coding Conventions

**Analysis Date:** 2026-01-18

### Naming Patterns

**Files:**
- snake_case for all Dart files: `workout_state.dart`, `settings_page.dart`, `database_test.dart`
- Test files suffix: `_test.dart` (e.g., `database_test.dart`, `pr_detection_test.dart`)
- Helper/shared code suffix: `_helpers.dart` or `_state.dart` for state management classes
- Generated files suffix: `.g.dart` (e.g., `database.g.dart`) or `.steps.dart` (e.g., `database.steps.dart`)

**Classes:**
- PascalCase for class names: `WorkoutState`, `AppDatabase`, `StrengthPage`, `RecordAchievement`
- Widget classes use descriptive names ending in widget type: `StrengthPage`, `EditSetPage`, `WorkoutDetailPage`
- State classes end in `State`: `SettingsState`, `PlanState`, `TimerState`, `WorkoutState`
- Companion classes for database inserts: `GymSetsCompanion`, `WorkoutsCompanion`, `PlansCompanion`

**Functions:**
- camelCase for function names: `startWorkout()`, `checkForRecords()`, `createTestDatabase()`
- Helper/utility functions use descriptive verbs: `calculate1RM()`, `parseDate()`, `isSameDay()`
- Async functions prefixed with action verb: `_loadActiveWorkout()`, `_fetchWebApiData()`, `updatePlans()`
- Private methods prefixed with underscore: `_loadRecords()`, `_onTabChanged()`, `_pollPlayerState()`

**Variables:**
- camelCase for local variables and parameters: `workoutId`, `exerciseName`, `bestWeight`
- Private fields prefixed with underscore: `_activeWorkout`, `_activePlan`, `_connectionStatus`
- Boolean variables use `is`, `has`, or `should` prefix: `isPaused`, `hasActiveWorkout`, `isShuffling`
- Constants use lowerCamelCase: `weekdays`, `positiveReinforcement`, `defaultSettings`

**Types:**
- Enum types use PascalCase: `RecordType`, `StrengthMetric`, `Period`, `CardioMetric`
- Enum values use camelCase: `RecordType.best1RM`, `Period.months3`, `StrengthMetric.bestWeight`
- Type aliases use PascalCase: `GymCount` (typedef for record type)

### Code Style

**Formatting:**
- Tool: Included in Flutter SDK (dart format)
- Trailing commas required on all function calls and parameter lists (enforced by `require_trailing_commas` lint rule)
- Single quotes preferred for strings (`prefer_single_quotes` lint rule)
- End of file newline required (`eol_at_end_of_file`)

**Linting:**
- Tool: `flutter_lints` package version 6.0.0
- Config file: `analysis_options.yaml` with 150+ enabled lint rules
- Strict mode disabled: `strict-casts: false`, `strict-inference: false`, `strict-raw-types: false`
- Key enforced rules:
  - `prefer_single_quotes`: Use single quotes for strings
  - `always_declare_return_types`: All functions must declare return types
  - `prefer_const_constructors`: Use const constructors where possible
  - `prefer_final_locals`: Use final for variables that aren't reassigned
  - `require_trailing_commas`: Required on multi-line function calls
  - `type_annotate_public_apis`: All public APIs must have type annotations
  - `prefer_relative_imports`: Use relative imports within the package
- Errors promoted to build failures:
  - `unused_local_variable: error`
  - `unused_element: error`
  - `unused_field: error`
  - `dead_code: error`
- Disabled rules:
  - `curly_braces_in_flow_control_structures: false` (optional braces allowed)
  - `avoid_print: false` (print statements allowed)
  - `cascade_invocations: false` (cascades not enforced)

### Import Organization

**Order:**
1. Dart SDK imports: `import 'dart:async';`, `import 'dart:io';`
2. External package imports: `import 'package:drift/drift.dart';`, `import 'package:flutter/material.dart';`
3. Local package imports: `import 'database/database.dart';`, `import '../main.dart';`, `import '../utils.dart';`

**Path Aliases:**
- Not used (relative imports preferred per lint rule)
- Parent directory imports: `import '../database/database.dart';`
- Sibling imports: `import 'workout_state.dart';`

**Import Modifiers:**
- `hide` used to avoid naming conflicts: `import 'package:drift/drift.dart' hide Column;`
- `as` used for aliasing: `import 'package:drift/drift.dart' as drift;`

### Error Handling

**Patterns:**
- Try-catch with specific error handling for critical operations
- Silent failure for non-critical errors with print statements
- Async errors caught with `.catchError()` on initialization

### Logging

**Framework:** Built-in `print()` statements (allowed by lint rules)

**Patterns:**
- Use emoji prefixes for visibility: `print('⚠️ Error loading active workout: $error');`
- Success messages: `print('✓ Default settings created successfully');`
- Warning messages: `print('⚠️ Settings table is empty, creating default settings...');`
- Debug info: `print('🎵 Web API fetch error: $e');`

### Comments

**When to Comment:**
- Document complex SQL expressions
- Explain formula calculations
- Clarify non-obvious business logic
- Describe error handling behavior

### Function Design

**Size:**
- No strict limit enforced
- State classes tend to have small, focused methods (20-50 lines)
- UI widgets can be larger (100+ lines for complex build methods)

**Parameters:**
- Use named parameters for optional parameters
- Use required keyword for mandatory named parameters
- Positional parameters for simple cases (1-3 params)

**Return Values:**
- Always declare return types explicitly (`always_declare_return_types` lint rule)
- Use `Future<T>` for async operations
- Use `T?` for nullable returns
- Avoid return types on setters (`avoid_return_types_on_setters`)

### Module Design

**Exports:**
- No barrel files (each file imports what it needs)
- Database table classes exported via `part` directive in `database.dart`

**Barrel Files:**
- Not used (prefer explicit imports)

### State Management

**Pattern:** Provider pattern (ChangeNotifier)

**State classes location:** Feature folders with `_state.dart` suffix
- `lib/settings/settings_state.dart`
- `lib/plan/plan_state.dart`
- `lib/timer/timer_state.dart`
- `lib/workouts/workout_state.dart`
- `lib/spotify/spotify_state.dart`

**Global state access:** Global `db` instance in `main.dart`

### Database Conventions

**ORM:** Drift (version 2.28.1)

**Patterns:**
- Table classes define schema: `GymSets`, `Workouts`, `Plans`, `Settings`
- Companion classes for inserts: `GymSetsCompanion`, `WorkoutsCompanion`
- Use `Value()` wrapper for optional fields in companions
- Custom SQL expressions for complex queries: `CustomExpression<T>`

---

## E. External Integrations

**Analysis Date:** 2026-01-18

### APIs & External Services

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

### Data Storage

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

### Authentication & Identity

**Auth Provider:**
- Spotify OAuth (for music integration only)
  - Implementation: Custom OAuth flow via Spotify SDK
  - Token storage: In app database Settings table
  - Token fields: `spotifyAccessToken`, `spotifyTokenExpiry`
  - Token lifecycle: Restored from database on app start, expires after 1 hour
  - Reconnection: Manual via UI when token expires

### Monitoring & Observability

**Error Tracking:**
- None (no external crash reporting or analytics)

**Logs:**
- Console logging only (print statements)
  - Debug prefixes: 🎵 (Spotify), ⚠️ (warnings), ✓ (success)
  - No log aggregation service

### CI/CD & Deployment

**Hosting:**
- Not applicable (native Android app)
  - Distributed via Android APK/AAB builds
  - Self-signed or keystore-signed releases

**CI Pipeline:**
- None detected in repository
  - Manual builds via flutter build apk/appbundle
  - Reproducible builds configured (deterministic timestamps)

### Environment Configuration

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

### Webhooks & Callbacks

**Incoming:**
- Spotify OAuth callback
  - Scheme: `jackedlog://spotify-auth-callback`
  - Handler: MainActivity intent filter in `android/app/src/main/AndroidManifest.xml`
  - Processing: Captured by spotify_sdk package

**Outgoing:**
- None

### Platform Services

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

### Data Export/Import

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

## H. Database Schema Reference

**Current Schema Version:** v60

### Tables

**1. Workouts** (workout sessions - groups sets together)
- `id`, `startTime`, `endTime` (nullable - null means active), `planId`, `name`, `notes`

**2. GymSets** (individual exercise sets)
- Core: `id`, `name`, `reps`, `weight`, `unit`, `created`
- Cardio: `cardio`, `duration`, `distance`, `incline`
- Metadata: `restMs`, `hidden`, `planId`, `workoutId` (links to Workouts.id)
- Organization: `sequence` (exercise position), `setOrder` (set position, nullable), `image`, `category`, `notes`
- Training: `warmup` (bool), `dropSet` (bool), `exerciseType`, `brandName`

**3. Plans**
- `id`, `days`, `sequence`, `title`

**4. PlanExercises**
- `id`, `planId`, `exercise`, `enabled`, `maxSets`, `warmupSets`, `timers`, `sequence`

**5. Settings** (30+ fields)
- Theme: `themeMode`, `systemColors`, `customColorSeed` (default: 0xFF673AB7)
- 5/3/1: `fivethreeoneWeek`, `fivethreeoneSquatTm`, `fivethreeoneBenchTm`, `fivethreeoneDeadliftTm`, `fivethreeonePressTm`
- Default tabs: `"HistoryPage,PlansPage,GraphsPage,NotesPage,SettingsPage"`
- Spotify: `spotifyClientId`, `spotifyRedirectUri` (both TEXT, nullable)

**6. Notes**
- `id`, `title`, `content`, `created`, `updated`, `color`

**7. BodyweightEntries**
- `id`, `weight`, `unit`, `date`, `notes`

**8. Metadata**
- Version tracking

### Data Hierarchy

```
Workout Session → Exercises → Sets
  workoutId links sets to workout session
  sequence = exercise position (0, 1, 2...)
  setOrder = set position within exercise (0, 1, 2...), nullable
```

---

## I. Core Features

### Workout Sessions

- **WorkoutState**: Manages single active workout (`startWorkout()`, `stopWorkout()`, `resumeWorkout()`)
- **Active workout**: `endTime` is NULL in Workouts table
- **Single workout limit**: Toast message if trying to start another workout
- **ActiveWorkoutBar**: Floating bar above navigation with workout name, elapsed time, "End" button
- **History views**: Toggle between Workouts (sessions) and Sets (legacy)
- **Multi-select deletion**: Long press → checkbox mode → batch delete workouts + sets

### Personal Records (PR)

Tracks 3 types per exercise: Best 1RM (Brzycki formula), Best Volume (weight × reps), Best Weight

- Auto-detects PRs on set completion (non-warmup, non-cardio only)
- Celebration notification with confetti animation
- Record badges on sets in workout history
- Uses `.clamp(0.0, 1.0)` for opacity (Curves.easeOutBack overshoots 1.0)

### Rest Timers

- Custom per exercise: `GymSet.restMs` (nullable)
- Global default: `Settings.timerDuration`
- Timer starts in `_completeSet()` after marking set as not hidden
- Quick access timer dialog: 30s, 1m, 2m, 3m, 5m, 10m presets

### Exercise Data Loading

Loads last set for defaults (weight, reps, brandName, exerciseType, restMs) → loads existing sets from current workout by `workoutId` and `sequence`

### Bodyweight Tracking

- Log via FloatingActionButton in overview page
- Dialog: weight input, unit selector, date picker, optional notes
- Overview cards: Current Bodyweight, Bodyweight Trend (% change over period)
- Respects period selector (7D, 1M, 3M, 6M, 1Y, All)

### 5/3/1 Calculator

- Appears when exercise name matches: Squat, Bench Press, Deadlift, Overhead Press
- Week selector (1, 2, 3), training max input, calculated percentages as tappable chips
- Auto-fills weight into current set, auto-saves TM to settings
- Uses `useRootNavigator: true` to appear above active workout bar

### Custom Color Theming

- System colors (Android 12+ dynamic colors) or custom seed color
- Color picker: 6 palette collections, HSL sliders, 360+ color grid
- Material Design 3 generates full ColorScheme from seed
- Uses `useRootNavigator: true` for dialog

### Workout Overview

- Period selector: 7D, 1M, 3M, 6M, 1Y, All
- Stats cards: Workouts, Volume, Streak, Top Muscle, Bodyweight, Bodyweight Trend
- GitHub-style heatmap: Monday-Sunday weeks, clickable days
- Muscle charts: Volume (weight × reps) and Set Count (top 10)

### Spotify Integration

Real-time music playback control during workouts. Three-layer architecture: `SpotifyService` (OAuth + SDK) → `SpotifyState` (polling + state) → UI components.

**Core Files:**
- `lib/spotify/spotify_service.dart` - OAuth flow, token capture (_accessToken, _tokenExpiry), SDK connection
- `lib/spotify/spotify_state.dart` - ChangeNotifier with 500ms polling, player state management
- `lib/spotify/spotify_web_api_service.dart` - REST API for queue/recently played
- `lib/music/music_page.dart` - Main UI with dynamic album artwork background
- `lib/music/widgets/` - PlayerControls, SeekBar, QueueBottomSheet, RecentlyPlayedSection, AnimatedEqualizer, AuthPrompt, NoPlaybackState
- `lib/settings/spotify_settings.dart` - Client ID/Redirect URI config

**Key Patterns:**
- Token validation: `hasValidToken` getter checks existence + expiry before API calls
- Polling: All Web API calls wrapped in try-catch, preserve state on error to prevent timer crashes
- Album artwork: Convert Spotify URI (`spotify:image:`) → CDN URL (`https://i.scdn.co/image/`)
- UI sizing: Album art 65% width (max 300px), buttons 48x48dp touch targets, track title uses `titleLarge`
- Error handling: Check token validity first, gracefully degrade on 429 rate limit, keep last known state

**Setup:**
- Spotify Developer app with redirect URI (e.g., `jackedlog://callback`)
- Settings → Spotify → enter Client ID/Redirect URI → connect
- Android: SDK in `android/spotify-app-remote/libs/`, ProGuard rules, AndroidManifest intent filter
- Requires: Spotify Premium, Spotify app installed, Android/iOS only

**Limitations:** No token refresh (reconnect after expiry), no offline mode, no queue modification in some regions

---

## J. UI/UX Patterns

### Navigation

The app uses a **Segmented Pill Navigation Bar** (as of 2026-01-11):

- Single unified pill container with sliding background indicator
- Morphing navigation icons using Rive animations (fallback to Material icons)
- 5 tabs: History, Plans, Graphs, Notes, Settings
- Smooth 300ms transitions with easeInOutCubic curve
- Long-press to hide tabs (stored in Settings.tabs)
- Swipe gesture support (controlled by Settings.scrollableTabs)
- Integrates with ActiveWorkoutBar and RestTimerBar overlays

**Implementation:**
- `lib/widgets/segmented_pill_nav.dart` - Main navigation widget
- `lib/widgets/morphing_nav_icon.dart` - Rive animation wrapper
- `assets/animations/` - Navigation icon animations (.riv files)
- Configured in `lib/home_page.dart` with TabController

**Previous Implementation:** `lib/bottom_nav.dart` (deprecated, individual pill buttons)

### Modal Dialogs Over Overlays

Use `useRootNavigator: true` for dialogs/bottom sheets that need to appear above ActiveWorkoutBar:

```dart
showModalBottomSheet(
  context: context,
  useRootNavigator: true,
  builder: (context) => ...
);
```

### TextEditingController in Dialogs

DO NOT manually dispose controllers in dialog callbacks - Flutter manages lifecycle automatically.

### Exercise Reordering

- Toggle mode via AppBar button
- `ReorderableListView` only in reorder mode
- Save with `sequence: index` to preserve order

### Freeform Workouts

Time-based titles: Morning/Noon/Afternoon/Evening Workout
Create with temporary Plan object (id: -1, no exercises)

---

## K. Migration Guide

### Manual Steps for Schema Changes

1. Create new `drift_schema_vN.json` (copy previous, add columns)
2. Add column definition in `database.steps.dart`: `_column_XX()`
3. Add new Shape class (copy previous, add column getter)
4. Add new Schema class (use new Shape for modified table)
5. Update `migrationSteps()` and `stepByStep()` functions
6. Run `dart run build_runner build --delete-conflicting-outputs`

### Type Usage

- `SettingsCompanion.insert()`: required fields plain values, optional use `Value()`
- Migrations with `RawValuesInsertable()`: ALL fields use `Variable()`
- Table schema `withDefault()`: use `const Constant(value)`

### Import Conflicts

```dart
import 'package:drift/drift.dart' hide Column;
```

---

## L. Common Gotchas

1. **Plan class**: No `exercises` field - use separate PlanExercises table
2. **Set ordering**: Order by `sequence` (exercise), then `setOrder` with COALESCE fallback: `COALESCE(set_order, CAST((julianday(created) - 2440587.5) * 86400000 AS INTEGER))`
3. **Active workouts**: `endTime` is NULL
4. **Drop sets & warmup sets**: Both are boolean flags
5. **Exercise metadata**: `category`, `exerciseType`, `brandName` stored per set - update all sets for an exercise to change globally
6. **Popup menu context**: Capture parent context before opening bottom sheets
7. **5/3/1 calculator**: Only appears for hardcoded exercise names

---

## M. Export/Import Backward Compatibility

**v59→v60**: Added `spotifyClientId` and `spotifyRedirectUri` to Settings (nullable, no impact on import).

**v57→v58**: Added `setOrder` column to gym_sets.csv. Import auto-detects by checking header for `setorder`.

**v54→v55**: Removed `bodyWeight` column. Import auto-detects by checking header for `bodyweight`.

---

## N. Key Files Reference

| File                                         | Purpose                                               |
| -------------------------------------------- | ----------------------------------------------------- |
| `lib/database/database.dart`                 | Drift DB definition, all migrations                   |
| `lib/database/database.steps.dart`           | **Generated** migration steps                         |
| `lib/workouts/workout_state.dart`            | WorkoutState provider - manages single active workout |
| `lib/workouts/active_workout_bar.dart`       | Floating bar showing ongoing workout                  |
| `lib/plan/start_plan_page.dart`              | Workout execution UI                                  |
| `lib/plan/exercise_sets_card.dart`           | Exercise card with sets                               |
| `lib/records/records_service.dart`           | PR detection and calculation                          |
| `lib/records/record_notification.dart`       | PR celebration UI                                     |
| `lib/graph/overview_page.dart`               | Stats, heatmap, muscle charts, bodyweight             |
| `lib/widgets/five_three_one_calculator.dart` | 5/3/1 calculator                                      |
| `lib/widgets/artistic_color_picker.dart`     | Custom color picker                                   |
| `lib/spotify/spotify_service.dart`           | Spotify OAuth and SDK integration                     |
| `lib/spotify/spotify_state.dart`             | Spotify state provider with 500ms polling             |
| `lib/spotify/spotify_web_api_service.dart`   | Spotify REST API client                               |
| `lib/music/music_page.dart`                  | Music player UI with dynamic backgrounds              |
| `lib/settings/spotify_settings.dart`         | Spotify configuration page                            |

---

*Documentation generated from .planning/codebase/ - 2026-01-18*
