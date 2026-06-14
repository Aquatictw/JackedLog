# File Map

A hand-maintained guide to the files most likely involved in each feature slice. Read the relevant slice **before** broad code search to choose starting files.

This is a routing aid, not proof of behavior — source code and tests still win. Keep it short; update it when a slice's layout changes materially.

App entry: `lib/main.dart` · Home shell: `lib/home_page.dart`, `lib/bottom_nav.dart`, `lib/tab_settings`-driven tabs.

---

## Workouts (logging a session)

- Screens/widgets: `lib/workouts/workout_detail_page.dart`, `lib/workouts/workouts_list.dart`, `lib/workouts/active_workout_bar.dart`
- State: `lib/workouts/workout_state.dart`
- Sets entry/edit: `lib/sets/edit_set_page.dart`, `lib/sets/edit_sets_page.dart`, `lib/sets/history_page.dart`, `lib/sets/history_list.dart`
- Models: `lib/models/set_data.dart`, `lib/database/gym_sets.dart`
- Tests: `test/workouts/workout_state_test.dart`, `test/workouts/workout_state_integration_test.dart`

## Plans (templates / routines)

- Screens: `lib/plan/plans_page.dart`, `lib/plan/plans_list.dart`, `lib/plan/edit_plan_page.dart`, `lib/plan/start_plan_page.dart`, `lib/plan/swap_workout.dart`
- Widgets: `lib/plan/exercise_modal.dart`, `lib/plan/exercise_sets_card.dart`, `lib/plan/exercise_tile.dart`, `lib/plan/plan_tile.dart`
- State: `lib/plan/plan_state.dart`
- DB: `lib/database/plans.dart`, `lib/database/plan_exercises.dart`

## 5/3/1 blocks

- Screens: `lib/fivethreeone/block_overview_page.dart`, `lib/fivethreeone/block_summary_page.dart`, `lib/fivethreeone/block_creation_dialog.dart`
- State/logic: `lib/fivethreeone/fivethreeone_state.dart`, `lib/fivethreeone/schemes.dart`
- DB: `lib/database/fivethreeone_blocks.dart`

## Graphs / progress overview

- Screens: `lib/graph/graphs_page.dart`, `lib/graph/overview_page.dart`, `lib/graph/strength_page.dart`, `lib/graph/cardio_page.dart`, `lib/graph/bodyweight_overview_page.dart`, `lib/graph/graph_history_page.dart`, `lib/graph/edit_graph_page.dart`
- Data: `lib/graph/strength_data.dart`, `lib/graph/cardio_data.dart`, `lib/graph/flex_line.dart`
- Filters: `lib/graphs_filters.dart`, `lib/filters.dart`

## Personal records (PRs)

- Logic: `lib/records/records_service.dart`, `lib/records/record_notification.dart`
- Tests: `test/records/pr_calculation_test.dart`, `test/records/pr_detection_test.dart`

## Database / persistence (Drift)

- Core: `lib/database/database.dart` (+ generated `database.g.dart`), `lib/database/database_connection_native.dart`
- Schema & migrations: `lib/database/schema.dart`, versioned snapshots `lib/database/schema_v*.dart`, `lib/database/failed_migrations_page.dart`
- Tables: `lib/database/gym_sets.dart`, `lib/database/plans.dart`, `lib/database/plan_exercises.dart`, `lib/database/fivethreeone_blocks.dart`, `lib/database/bodyweight_entries.dart`, `lib/database/notes.dart`, `lib/database/settings.dart`, `lib/database/metadata.dart`, `lib/database/defaults.dart`, `lib/database/query_helpers.dart`
- Tests: `test/database/database_test.dart`, `test/database/database_migration_test.dart`, `test/database/database_export_test.dart`, `test/database/database_import_test.dart`

## Import / export / backup

- Export/import: `lib/export_data.dart`, `lib/import_data.dart`, `lib/import_hevy.dart`
- Local auto-backup: `lib/backup/auto_backup_service.dart`, `lib/backup/auto_backup_settings.dart`
- Remote/server backup: `lib/server/backup_push_service.dart`, `lib/server/server_settings_page.dart`

## Notes

- Screens: `lib/notes/notes_page.dart`, `lib/notes/note_editor_page.dart`
- DB: `lib/database/notes.dart`

## Rest timer

- UI: `lib/timer/timer_page.dart`, `lib/timer/rest_timer_bar.dart`, `lib/timer/timer_progress_widgets.dart`
- State: `lib/timer/timer_state.dart`
- Native bridge: `lib/native_timer_wrapper.dart`

## Music (Spotify)

- Service/state: `lib/spotify/spotify_service.dart`, `lib/spotify/spotify_state.dart`, `lib/spotify/spotify_web_api_service.dart`
- Settings: `lib/settings/spotify_settings.dart`, `lib/music/`
- Tests: `test/spotify/spotify_state_test.dart`, `test/spotify/spotify_token_test.dart`

## Settings

- Hub: `lib/settings/settings_page.dart`, state `lib/settings/settings_state.dart`
- Sections: `lib/settings/appearance_settings.dart`, `data_settings.dart`, `format_settings.dart`, `plan_settings.dart`, `workout_settings.dart`, `timer_settings.dart`, `tab_settings.dart`, `spotify_settings.dart`
- DB: `lib/database/settings.dart`
