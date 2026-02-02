# Codebase Structure

**Analysis Date:** 2026-02-02

## Directory Layout

```
lib/
├── database/          # Drift ORM schema, migrations, database class
├── workouts/          # Workout recording, history, active workout tracking
├── plan/              # Plans management, exercise selection, plan execution
├── sets/              # Set history view, set editing, analytics
├── graph/             # Strength, cardio, bodyweight graphs and analytics
├── timer/             # Rest timer state and UI components
├── settings/          # Settings page and global settings state
├── music/             # Spotify integration and music player UI
├── notes/             # Workout notes management
├── widgets/           # Shared UI components (calculators, indicators, pickers)
├── utils/             # Utility functions (bodyweight calculations)
├── records/           # Record notifications and achievements
├── backup/            # Auto-backup service and backup management
├── spotify/           # Spotify authentication and state
├── models/            # Data models (SetData)
├── main.dart          # Entry point, Provider setup, theme configuration
├── home_page.dart     # Tab navigation, main layout
├── bottom_nav.dart    # Bottom navigation widget with animation
├── constants.dart     # Enums, default settings, constants
├── utils.dart         # Shared helper functions (toast, date parsing, etc.)
└── [feature files]    # Import/export, filters, dialogs, search
```

## Directory Purposes

**lib/database/:**
- Purpose: SQLite schema definitions and database operations
- Contains: Drift table definitions, database.dart class, migrations, schema versions
- Key files: `database.dart`, `gym_sets.dart`, `workouts.dart`, `plans.dart`, `settings.dart`, `plan_exercises.dart`, `notes.dart`, `bodyweight_entries.dart`, `metadata.dart`

**lib/workouts/:**
- Purpose: Workout lifecycle management and UI
- Contains: Workout recording, active workout tracking, workout details, state management
- Key files: `workout_state.dart`, `workout_detail_page.dart`, `active_workout_bar.dart`, `workouts_list.dart`

**lib/plan/:**
- Purpose: Training plans and exercise management
- Contains: Plan CRUD, exercise selection, plan execution flow, state management
- Key files: `plan_state.dart`, `plans_page.dart`, `start_plan_page.dart`, `edit_plan_page.dart`, `exercise_sets_card.dart`

**lib/sets/:**
- Purpose: Set history viewing and editing
- Contains: History list/detail views, set editing forms, collapsed views
- Key files: `history_page.dart`, `edit_set_page.dart`, `history_list.dart`, `history_collapsed.dart`

**lib/graph/:**
- Purpose: Analytics and progress visualization
- Contains: Strength graphs, cardio analytics, bodyweight tracking, graph editing
- Key files: `graphs_page.dart`, `strength_page.dart`, `cardio_page.dart`, `overview_page.dart`, `bodyweight_overview_page.dart`, `edit_graph_page.dart`

**lib/timer/:**
- Purpose: Rest timer functionality
- Contains: Timer state management, UI components, native platform integration
- Key files: `timer_state.dart`, `rest_timer_bar.dart`, `timer_quick_access.dart`

**lib/settings/:**
- Purpose: User preferences and settings management
- Contains: Settings page UI, settings state management, theme/preference handling
- Key files: `settings_page.dart`, `settings_state.dart`

**lib/music/:**
- Purpose: Spotify integration and music playback
- Contains: Music player UI, Spotify auth, track selection
- Key files: `music_page.dart`, `spotify_state.dart`, music widgets

**lib/widgets/:**
- Purpose: Reusable UI components across features
- Contains: Custom widgets (calculators, pickers, indicators, animations)
- Key files: `plate_calculator.dart`, `five_three_one_calculator.dart`, `artistic_color_picker.dart`, `bodypart_tag.dart`, `segmented_pill_nav.dart`

**lib/notes/:**
- Purpose: Workout notes attachment and viewing
- Contains: Notes CRUD, notes display
- Key files: `notes_page.dart`

**lib/records/:**
- Purpose: Personal records and achievement notifications
- Contains: Record detection, notification display
- Key files: `record_notification.dart`

**lib/backup/:**
- Purpose: Data backup and restore functionality
- Contains: Auto-backup service, backup file management, cleanup
- Key files: `auto_backup_service.dart`

**lib/spotify/:**
- Purpose: Spotify integration
- Contains: Spotify authentication, session management, state
- Key files: `spotify_state.dart`

**lib/models/:**
- Purpose: Domain data models
- Contains: SetData and other custom models
- Key files: `set_data.dart`

**lib/utils/:**
- Purpose: Utility modules
- Contains: Calculation helpers
- Key files: `bodyweight_calculations.dart`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App entry point, Provider setup, theme, splash screen
- `lib/home_page.dart`: Main navigation after initialization
- `lib/screens/splash_screen.dart`: Startup splash screen with animations

**Configuration:**
- `lib/constants.dart`: Enums, default settings, weekdays, positive reinforcement messages
- `pubspec.yaml`: Dependencies, version, Flutter configuration

**Core Logic:**
- `lib/database/database.dart`: Drift database class, migration strategy, schema
- `lib/workouts/workout_state.dart`: Active workout management
- `lib/plan/plan_state.dart`: Plan caching and exercise tracking
- `lib/settings/settings_state.dart`: Global settings stream
- `lib/timer/timer_state.dart`: Timer lifecycle with native integration

**Utilities:**
- `lib/utils.dart`: Helper functions (toast, date parsing, selection, formatting)
- `lib/backup/auto_backup_service.dart`: Automatic backup logic
- `lib/import_data.dart`: CSV/archive import functionality
- `lib/export_data.dart`: CSV/archive export functionality
- `lib/import_hevy.dart`: Hevy app data import

**Testing:**
- `test/`: Test files (integration and unit tests)

## Naming Conventions

**Files:**
- `*_page.dart`: Full-page screens/views (e.g., `history_page.dart`, `settings_page.dart`)
- `*_state.dart`: Provider ChangeNotifier state classes (e.g., `workout_state.dart`, `timer_state.dart`)
- `*_bar.dart`: Bar widgets (e.g., `active_workout_bar.dart`, `rest_timer_bar.dart`)
- `*_dialog.dart`: Dialog/modal components (e.g., `bodyweight_entry_dialog.dart`)
- `*_list.dart`: List components (e.g., `history_list.dart`, `plans_list.dart`)
- `*_tile.dart`: Single item tiles (e.g., `exercise_tile.dart`, `plan_tile.dart`)
- `*_widget.dart`: Generic reusable widgets
- `database.dart` + `table.dart`: Database class and table definitions
- schema_v{N}.dart: Historical database schemas for migrations

**Directories:**
- Lowercase, plural for collections: `widgets/`, `screens/`, `utils/`
- Feature name singular: `workouts/`, `plan/`, `sets/`, `graph/`
- Sub-domain grouping: `widgets/sets/`, `widgets/stats/`, `widgets/superset/`

## Where to Add New Code

**New Feature:**
- Create directory: `lib/{feature}/`
- Primary page: `lib/{feature}/{feature}_page.dart`
- State management (if needed): `lib/{feature}/{feature}_state.dart`
- Domain logic: `lib/{feature}/{feature}_logic.dart` or service classes
- Tests: `test/{feature}/` with same structure

**New Component/Widget:**
- Reusable across app: `lib/widgets/{component}.dart`
- Feature-specific: `lib/{feature}/widgets/{component}.dart`
- Set-specific: `lib/widgets/sets/{component}.dart`
- Workout-specific: `lib/widgets/workout/{component}.dart`

**Utilities:**
- Shared helpers: `lib/utils.dart` (keep small)
- Domain-specific: `lib/utils/{domain}.dart`
- Calculation helpers: `lib/utils/bodyweight_calculations.dart`

**Database:**
- New table: `lib/database/{table_name}.dart` (use Drift table annotation)
- Register in: `lib/database/database.dart` @DriftDatabase tables list
- Add migration: Update `onUpgrade` in `database.dart` with new schema version
- Save schema: Create `lib/database/schema_v{N}.dart` snapshot

## Special Directories

**lib/database/schema_v*.dart:**
- Purpose: Historical database schema snapshots for migration testing
- Generated: By developer during schema changes
- Committed: Yes, kept for historical reference and migration validation

**lib/drift_schemas/:**
- Purpose: Generated Drift schema definition files (root level)
- Generated: Yes, by build_runner
- Committed: Yes

**lib/screens/:**
- Purpose: App initialization screens (minimal)
- Key files: `splash_screen.dart`, `failed_migrations_page.dart`

**lib/models/:**
- Purpose: Custom data models not managed by Drift
- Currently: `set_data.dart` for set display data

**build/, .dart_tool/:**
- Purpose: Build artifacts and generated code
- Generated: Yes
- Committed: No

## Navigation Pattern

**Tab-based primary navigation:**
- HomePage manages TabController
- Tab configuration in Settings (stored as comma-separated string)
- Each tab is a full StatefulWidget with Navigator for internal routing
- Example: `HistoryPage` has internal navigator for drilldown

**Feature-internal navigation:**
- Features create child Navigators for deep navigation (e.g., `HistoryPage`, `PlansPage`)
- Uses GlobalKey<NavigatorState> for programmatic navigation
- Pattern: Navigator with onGenerateRoute MaterialPageRoute builders

**Navigation coordination:**
- WorkoutState holds TabController reference for cross-tab navigation
- PlansPage can trigger workout start which navigates to workouts tab
- PlanNavigatorKey allows external navigation triggers

---

*Structure analysis: 2026-02-02*
