# Codebase Structure

**Analysis Date:** 2026-01-18

## Directory Layout

```
jackedlog/
├── lib/                    # Main Dart source code
│   ├── backup/            # Auto-backup functionality
│   ├── database/          # Drift ORM tables and migrations
│   ├── graph/             # Progress visualization pages
│   ├── models/            # Data models
│   ├── music/             # Spotify integration UI
│   ├── notes/             # Workout notes feature
│   ├── plan/              # Workout plan management
│   ├── records/           # Personal record tracking
│   ├── sets/              # Exercise set editing and history
│   ├── settings/          # App settings and preferences
│   ├── spotify/           # Spotify SDK integration services
│   ├── timer/             # Rest timer functionality
│   ├── utils/             # Shared utility functions
│   ├── widgets/           # Reusable UI components
│   ├── workouts/          # Workout session management
│   └── main.dart          # Application entry point
├── android/               # Android platform code
├── test/                  # Unit and integration tests
├── assets/                # Static assets (animations, fonts)
├── drift_schemas/         # Database schema snapshots for testing
├── scripts/               # Build and development scripts
└── pubspec.yaml           # Package dependencies
```

## Directory Purposes

**lib/database/**
- Purpose: Database schema definitions and data access layer
- Contains: Drift table classes, migration logic, query helpers, connection setup
- Key files: `database.dart` (main DB class with 60 migration steps), `gym_sets.dart` (exercise set table), `plans.dart`, `workouts.dart`, `settings.dart`, `query_helpers.dart` (optimized batch queries)

**lib/plan/**
- Purpose: Workout plan creation, editing, and execution
- Contains: Plan list UI, plan editor, exercise selection, plan state management
- Key files: `plan_state.dart` (reactive plan state), `plans_page.dart` (main UI), `edit_plan_page.dart`, `start_plan_page.dart` (active workout interface)

**lib/workouts/**
- Purpose: Workout session lifecycle management
- Contains: Active workout tracking, workout history, workout detail views
- Key files: `workout_state.dart` (session state), `active_workout_bar.dart` (persistent bottom bar), `workout_detail_page.dart`, `workouts_list.dart`

**lib/sets/**
- Purpose: Exercise set editing and history viewing
- Contains: Set editing forms, exercise history views
- Key files: `edit_set_page.dart`, `history_page.dart`, `history_list.dart`

**lib/graph/**
- Purpose: Progress tracking and data visualization
- Contains: Chart pages for strength/cardio metrics, graph customization
- Key files: `graphs_page.dart` (main nav), `strength_page.dart`, `cardio_page.dart`, `overview_page.dart`, `flex_line.dart` (custom chart component)

**lib/settings/**
- Purpose: Application configuration and user preferences
- Contains: Settings pages organized by category, settings state management
- Key files: `settings_state.dart` (reactive settings), `settings_page.dart`, `data_settings.dart`, `workout_settings.dart`, `spotify_settings.dart`

**lib/spotify/**
- Purpose: Spotify SDK integration services
- Contains: Spotify authentication, playback control, API communication
- Key files: `spotify_state.dart` (playback state), `spotify_service.dart` (SDK wrapper), `spotify_web_api_service.dart` (REST API client)

**lib/music/**
- Purpose: Music player UI for Spotify integration
- Contains: Player controls, queue management, recently played tracks
- Key files: `music_page.dart`, `widgets/player_controls.dart`, `widgets/queue_bottom_sheet.dart`

**lib/timer/**
- Purpose: Rest timer between sets
- Contains: Timer state management, timer UI, platform channel integration
- Key files: `timer_state.dart` (timer logic), `rest_timer_bar.dart` (UI overlay), `timer_page.dart`

**lib/backup/**
- Purpose: Automatic database backup functionality
- Contains: GFS retention policy implementation, backup scheduling
- Key files: `auto_backup_service.dart` (core backup logic), `auto_backup_settings.dart` (UI)

**lib/records/**
- Purpose: Personal record detection and notification
- Contains: Record calculation logic, notification service
- Key files: `records_service.dart` (detection algorithms), `record_notification.dart` (UI feedback)

**lib/widgets/**
- Purpose: Reusable UI components shared across features
- Contains: Custom widgets for navigation, forms, calculations
- Key files: `segmented_pill_nav.dart` (bottom nav), `plate_calculator.dart`, `five_three_one_calculator.dart`, `bodyweight_entry_dialog.dart`

**lib/utils/**
- Purpose: Shared utility functions
- Contains: Helper functions for calculations and transformations
- Key files: `bodyweight_calculations.dart`

**test/**
- Purpose: Automated tests
- Contains: Database tests, business logic tests, service tests
- Key files: `test_helpers.dart` (test utilities), `database/`, `workouts/`, `spotify/`

**android/**
- Purpose: Android-specific platform code
- Contains: Kotlin implementations for timers, Spotify SDK integration
- Key files: `app/src/main/kotlin/com/aquatic/jackedlog/MainActivity.kt`

**drift_schemas/**
- Purpose: Database schema version snapshots
- Contains: Generated schema files for Drift migration testing
- Key files: `db/drift_schema_v*.json`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Application initialization, provider setup, global database instance
- `lib/home_page.dart`: Main tab controller and navigation hub

**Configuration:**
- `pubspec.yaml`: Package dependencies and app metadata
- `analysis_options.yaml`: Linter configuration
- `build.yaml`: Code generation configuration for Drift

**Core Logic:**
- `lib/database/database.dart`: Central database class with 60 migration steps
- `lib/plan/plan_state.dart`: Workout plan state management
- `lib/workouts/workout_state.dart`: Active workout session management
- `lib/settings/settings_state.dart`: Application settings state

**Testing:**
- `test/test_helpers.dart`: Shared test utilities and mocks
- `test/database/`: Database layer tests
- `test/workouts/`: Workout logic tests

## Naming Conventions

**Files:**
- Snake_case: `workout_detail_page.dart`, `auto_backup_service.dart`
- Suffix patterns: `*_page.dart` (full screen), `*_state.dart` (ChangeNotifier), `*_service.dart` (stateless logic), `*_dialog.dart` (modals)

**Directories:**
- Lowercase: `lib/workouts/`, `lib/spotify/`
- Plural for collections: `widgets/`, `settings/`, `records/`
- Singular for concepts: `plan/`, `timer/`, `backup/`

**Classes:**
- PascalCase: `WorkoutState`, `AutoBackupService`, `HomePage`
- State suffix for ChangeNotifiers: `PlanState`, `SpotifyState`, `TimerState`

**Variables:**
- camelCase: `activeWorkout`, `planCounts`, `connectionStatus`
- Private fields with underscore: `_activeWorkout`, `_pollingTimer`

## Where to Add New Code

**New Feature:**
- Primary code: `lib/[feature_name]/` directory with `[feature]_page.dart` and optional `[feature]_state.dart`
- Tests: `test/[feature_name]/` matching the lib structure

**New Database Table:**
- Implementation: `lib/database/[table_name].dart` for table definition
- Register in: `lib/database/database.dart` `@DriftDatabase` annotation
- Migration: Add step in `database.dart` migration strategy (increment `schemaVersion`)

**New State Provider:**
- Implementation: `lib/[feature]/[feature]_state.dart` extending ChangeNotifier
- Register in: `lib/main.dart` `appProviders()` MultiProvider list

**New Settings:**
- Add column to: `lib/database/settings.dart` Settings table
- Add migration: `lib/database/database.dart` with new `fromXToY` step
- UI controls: `lib/settings/[category]_settings.dart`
- Update defaults: `lib/constants.dart` `defaultSettings` constant

**New Widget:**
- Shared helpers: `lib/widgets/[widget_name].dart`
- Feature-specific: `lib/[feature]/widgets/[widget_name].dart` (e.g., `lib/music/widgets/player_controls.dart`)

**New Service:**
- Stateless logic: `lib/[feature]/[service_name]_service.dart` with static methods
- Example: `lib/backup/auto_backup_service.dart`, `lib/records/records_service.dart`

**New Page/Screen:**
- Implementation: `lib/[feature]/[page_name]_page.dart`
- Navigation: Add route in appropriate parent page or tab controller

## Special Directories

**drift_schemas/**
- Purpose: Database schema version snapshots for Drift
- Generated: Yes (by `drift_dev` during build)
- Committed: Yes (required for schema verification tests)

**build/**
- Purpose: Compiled Flutter application output
- Generated: Yes (by Flutter build system)
- Committed: No (gitignored)

**.dart_tool/**
- Purpose: Dart/Flutter tooling cache
- Generated: Yes (by Dart tooling)
- Committed: No (gitignored)

**android/build/**
- Purpose: Android Gradle build output
- Generated: Yes (by Gradle)
- Committed: No (gitignored)

**assets/**
- Purpose: Static assets bundled with app
- Generated: No (manually maintained)
- Committed: Yes
- Contains: Animations (`assets/animations/`), fonts, images

**lib/database/*.g.dart**
- Purpose: Generated database query builders
- Generated: Yes (by `build_runner` via Drift)
- Committed: Yes (required for builds without code generation)

---

*Structure analysis: 2026-01-18*
