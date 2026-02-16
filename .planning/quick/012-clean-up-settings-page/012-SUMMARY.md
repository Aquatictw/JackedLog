# Quick Task 012: Clean Up Settings Page Summary

**One-liner:** Merged Plans+Formats into single settings page, removed Workouts button (10 -> 8 entries)

**Duration:** 2 min
**Completed:** 2026-02-16

## What Was Done

### Task 1: Remove WorkoutSettings and PlanSettings classes
- Deleted `WorkoutSettings` StatefulWidget class from `workout_settings.dart` (kept `getWorkoutSettings` function)
- Deleted `PlanSettings` StatefulWidget class from `plan_settings.dart` (kept `getPlanSettings` function)
- Removed unused imports (`provider`, `settings_state`) from both files

### Task 2: Create combined PlansAndFormatsSettings page and update settings_page.dart
- Replaced `FormatSettings` StatelessWidget with `PlansAndFormatsSettings` StatefulWidget in `format_settings.dart`
- Combined page shows format dropdowns, a divider, then plan settings (warmup sets, sets per exercise, plan trailing display)
- Added `plan_settings.dart` import to `format_settings.dart` for `getPlanSettings`
- Replaced separate "Formats" and "Plans" ListTiles with single "Plans & Formats" ListTile in `settings_page.dart`
- Removed "Workouts" ListTile from `settings_page.dart`

## Final Settings Page Order (8 entries)
1. Appearance
2. Data management
3. Backup Server
4. Plans & Formats (merged)
5. Tabs
6. Timers
7. 5/3/1 Block
8. Spotify

## Files Modified
- `lib/settings/workout_settings.dart` - Removed WorkoutSettings class, cleaned imports
- `lib/settings/plan_settings.dart` - Removed PlanSettings class, cleaned imports
- `lib/settings/format_settings.dart` - Replaced FormatSettings with PlansAndFormatsSettings
- `lib/settings/settings_page.dart` - Merged tiles, removed Workouts entry

## Deviations from Plan
### Auto-fixed Issues
**1. [Rule 2 - Missing Critical] Removed unused imports from workout_settings.dart and plan_settings.dart**
- **Found during:** Task 1
- **Issue:** After removing widget classes, `provider` and `settings_state` imports were unused
- **Fix:** Removed the unused imports to prevent analyzer warnings

## Verification
- Settings page: 8 ListTile entries (down from 10)
- No standalone "Workouts", "Formats", or "Plans" buttons
- "Plans & Formats" navigates to combined PlansAndFormatsSettings page
- Search still uses getFormatSettings, getPlanSettings, getWorkoutSettings
- No dangling imports or unused class references
