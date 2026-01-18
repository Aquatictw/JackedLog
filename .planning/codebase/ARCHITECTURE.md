# Architecture

**Analysis Date:** 2026-01-18

## Pattern Overview

**Overall:** State-driven Flutter application with Provider pattern for reactive UI updates

**Key Characteristics:**
- Multi-provider state management with ChangeNotifier pattern
- Local-first architecture with SQLite database using Drift ORM
- Feature-based directory structure with domain-specific state management
- Platform channel integration for Android-specific functionality

## Layers

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

## Data Flow

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

## Key Abstractions

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

## Entry Points

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

## Error Handling

**Strategy:** Defensive initialization with graceful degradation

**Patterns:**
- Try-catch blocks in async initialization methods (e.g., PlanState constructor, WorkoutState._loadActiveWorkout)
- Print warnings for non-critical errors, continue execution
- Fatal errors (database migration failures) show dedicated error page via `FailedMigrationsPage`
- State classes initialize with safe defaults, load data asynchronously
- Database queries use `getSingleOrNull()` instead of `getSingle()` to avoid crashes on missing data

## Cross-Cutting Concerns

**Logging:** Print statements with emoji prefixes (⚠️, ✓, 🎵) for visual categorization

**Validation:** Implicit via Drift type system and non-null safety; form validation in UI layer

**Authentication:** Spotify OAuth via SpotifyService, tokens stored in Settings table

---

*Architecture analysis: 2026-01-18*
