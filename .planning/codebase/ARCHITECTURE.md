# Architecture

**Analysis Date:** 2026-02-02

## Pattern Overview

**Overall:** Multi-layer Flutter application with state management, persistent storage, and domain-specific modules

**Key Characteristics:**
- Provider-based state management for global app state
- Drift ORM for SQLite database with schema versioning
- Feature-based directory structure with screen, state, and domain separation
- Composite application structure with tab-based navigation
- Native platform integration for timers and permissions
- Real-time database streams for reactive updates

## Layers

**Presentation Layer:**
- Purpose: UI components, screens, and user interaction handling
- Location: `lib/` (screens, widgets, pages)
- Contains: StatefulWidget, StatelessWidget, custom widgets, navigation
- Depends on: State Management, Utils, Constants, Database
- Used by: User interactions, navigation events

**State Management Layer:**
- Purpose: Manages global application state and reactive updates
- Location: `lib/*/state.dart` files
- Contains: ChangeNotifier-based state classes for Settings, Timer, Workouts, Plans, Spotify
- Depends on: Database, Services
- Used by: Presentation layer via Provider

**Domain/Feature Layer:**
- Purpose: Feature-specific business logic and data handling
- Location: `lib/{feature}/` (workouts, plan, sets, graph, music, etc.)
- Contains: Pages, widgets, utilities specific to that domain
- Depends on: Database, State Management
- Used by: Presentation layer, other domains

**Data/Persistence Layer:**
- Purpose: Database operations, schema management, and data models
- Location: `lib/database/`
- Contains: Drift table definitions, database class, migrations, schema versions
- Depends on: Drift ORM, SQLite
- Used by: State Management, Services, all domain layers

**Service Layer:**
- Purpose: Cross-cutting concerns and business logic (backup, import/export, Spotify integration)
- Location: `lib/backup/`, `lib/spotify/`, integration code
- Contains: AutoBackupService, SpotifyState, import/export utilities
- Depends on: Database, external APIs
- Used by: State Management, presentation layer

**Utilities Layer:**
- Purpose: Shared helper functions and constants
- Location: `lib/utils.dart`, `lib/constants.dart`, `lib/utils/`
- Contains: Toast notifications, date parsing, formatting, calculations
- Depends on: Minimal dependencies
- Used by: All layers

## Data Flow

**Workout Recording Flow:**

1. User starts workout via Plan selection → `WorkoutState.startWorkout()`
2. Workout entry created in `db.workouts` table
3. `WorkoutState` loads active plan and notifies listeners
4. UI updates to show `ActiveWorkoutBar` and set recording widgets
5. User logs sets → creates `GymSet` entries in `db.gymSets`
6. `HistoryPage` watches `db.gymSets` stream for real-time updates
7. User ends workout → `WorkoutState.endWorkout()` sets end time
8. Auto-backup triggered via lifecycle observer

**Settings Update Flow:**

1. User changes setting in UI
2. `SettingsState.value` updated via database write
3. Settings table subscription fires update event
4. `SettingsState` notifies all listeners
5. Affected widgets rebuild through Consumer selectors

**Timer Lifecycle:**

1. User starts rest timer → `TimerState.start()` called
2. For Android: invokes native channel method `'start'`
3. Native timer increments, calls back via method channel on each tick
4. `TimerState.updateTimer()` updates state and notifies listeners
5. UI rebuilds with updated time display
6. On timer completion: plays audio, vibrates, shows notification
7. Web/iOS: uses Dart Timer fallback

**State Management:**

- All global state accessed via Provider `context.read<StateClass>()` or `context.watch<StateClass>()`
- Specific field selection via `context.select<StateClass, FieldType>()`
- Database changes trigger stream subscriptions that update state
- State changes notify listeners causing widget rebuilds

## Key Abstractions

**WorkoutState:**
- Purpose: Manages active workout lifecycle and associated plan
- Examples: `lib/workouts/workout_state.dart`
- Pattern: Loads active (unfinished) workout on init, tracks current plan, manages tab navigation

**SettingsState:**
- Purpose: Holds and streams settings changes across the app
- Examples: `lib/settings/settings_state.dart`
- Pattern: Wraps Settings database table with stream subscription, notifies on changes

**TimerState:**
- Purpose: Manages rest timer state with native platform integration
- Examples: `lib/timer/timer_state.dart`
- Pattern: Receives updates from native Android timer via method channel, falls back to Dart Timer

**PlanState:**
- Purpose: Caches plan data, exercises, and set counts for performance
- Examples: `lib/plan/plan_state.dart`
- Pattern: Preloads plans and associated metadata, provides quick lookups for UI

**Database (Drift):**
- Purpose: Type-safe SQLite ORM with schema versioning and migrations
- Examples: `lib/database/database.dart`, table definitions
- Pattern: Lazy-loaded singleton, migration strategy handles schema evolution

## Entry Points

**main() function:**
- Location: `lib/main.dart`
- Triggers: App startup
- Responsibilities: Initialize settings from database, set up Provider state tree, configure Material theme, show splash screen

**App widget:**
- Location: `lib/main.dart`
- Triggers: After splash screen completes
- Responsibilities: Apply theme configuration, set system UI style, render HomePage

**HomePage:**
- Location: `lib/home_page.dart`
- Triggers: After initialization complete
- Responsibilities: Manage tab navigation, coordinate with WorkoutState for plans tab, handle tab visibility settings

**Feature Entry Points:**
- `HistoryPage`: `lib/sets/history_page.dart` - Uses internal Navigator
- `PlansPage`: `lib/plan/plans_page.dart` - Manages plan listing with WorkoutState
- `GraphsPage`: `lib/graph/graphs_page.dart` - Renders strength/cardio analytics
- `SettingsPage`: `lib/settings/settings_page.dart` - Settings management UI

## Error Handling

**Strategy:** Try-catch with logging, graceful degradation, error screens for critical failures

**Patterns:**
- Database migrations: Version check rejects old databases (< v31), shows FailedMigrationsPage
- Async initialization: State classes use `.catchError()` to log but continue operation
- Service failures: Auto-backup silently fails, continues operation
- Native integration: TimerState catches AudioPlayer creation failures
- UI feedback: Toast messages for user-facing errors via `rootScaffoldMessenger`

## Cross-Cutting Concerns

**Logging:** Print statements with emoji prefixes for different levels (⚠️ warnings, ✓ success)

**Validation:** Input validation in form widgets, database constraints via Drift schema

**Authentication:** None (offline-first app)

**Permissions:** Handled via `permission_handler` in `lib/permissions_page.dart`, requested at startup

**State Persistence:** All state backed by SQLite via Drift, loaded on app startup

---

*Architecture analysis: 2026-02-02*
