---
phase: quick-012
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/settings/settings_page.dart
  - lib/settings/workout_settings.dart
  - lib/settings/format_settings.dart
  - lib/settings/plan_settings.dart
autonomous: true

must_haves:
  truths:
    - "Settings page shows 'Plans & Formats' as a single button instead of separate 'Formats' and 'Plans' buttons"
    - "Settings page no longer shows a 'Workouts' button"
    - "Tapping 'Plans & Formats' opens a combined page showing both format dropdowns and plan settings"
    - "Search still finds settings from formats, plans, and workouts (getFormatSettings, getPlanSettings, getWorkoutSettings still work)"
  artifacts:
    - path: "lib/settings/format_settings.dart"
      provides: "Combined PlansAndFormatsSettings StatefulWidget + getFormatSettings function"
      contains: "PlansAndFormatsSettings"
    - path: "lib/settings/plan_settings.dart"
      provides: "getPlanSettings function only (PlanSettings class removed)"
    - path: "lib/settings/workout_settings.dart"
      provides: "getWorkoutSettings function only (WorkoutSettings class removed)"
    - path: "lib/settings/settings_page.dart"
      provides: "Settings page with Workouts tile removed, Formats+Plans tiles replaced by one Plans & Formats tile"
  key_links:
    - from: "lib/settings/settings_page.dart"
      to: "lib/settings/format_settings.dart"
      via: "Navigator push to PlansAndFormatsSettings"
      pattern: "PlansAndFormatsSettings"
---

<objective>
Clean up the settings page by removing the Workouts button/page and merging the Plans and Formats buttons into a single "Plans & Formats" page.

Purpose: Simplify settings navigation — Workouts page is redundant (its settings appear in search), and Plans/Formats are related enough to share one page.
Output: Cleaner settings page with 8 buttons instead of 10.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/settings/settings_page.dart
@lib/settings/workout_settings.dart
@lib/settings/format_settings.dart
@lib/settings/plan_settings.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Remove WorkoutSettings class and PlanSettings class</name>
  <files>
    lib/settings/workout_settings.dart
    lib/settings/plan_settings.dart
  </files>
  <action>
    In `workout_settings.dart`:
    - Delete lines 156-192 (the `WorkoutSettings` StatefulWidget class and its State class). Keep the `getWorkoutSettings` function (lines 10-153) and all imports intact.

    In `plan_settings.dart`:
    - Delete lines 133-165 (the `PlanSettings` StatefulWidget class and its State class). Keep the `getPlanSettings` function (lines 11-131) and all imports intact.
  </action>
  <verify>Confirm both files contain only their get*Settings functions and imports, no class definitions remain.</verify>
  <done>workout_settings.dart has only getWorkoutSettings function. plan_settings.dart has only getPlanSettings function. No widget classes in either file.</done>
</task>

<task type="auto">
  <name>Task 2: Create combined PlansAndFormatsSettings page and update settings_page.dart</name>
  <files>
    lib/settings/format_settings.dart
    lib/settings/settings_page.dart
  </files>
  <action>
    In `format_settings.dart`:
    - Remove the existing `FormatSettings` StatelessWidget class (lines 172-189).
    - Add the necessary imports at the top: `import '../constants.dart';`, `import '../utils.dart';`, `import 'plan_settings.dart';`
    - Add a new `PlansAndFormatsSettings` StatefulWidget (needs StatefulWidget because getPlanSettings requires TextEditingControllers for maxSets and warmupSets):

    ```dart
    class PlansAndFormatsSettings extends StatefulWidget {
      const PlansAndFormatsSettings({super.key});

      @override
      State<PlansAndFormatsSettings> createState() =>
          _PlansAndFormatsSettingsState();
    }

    class _PlansAndFormatsSettingsState extends State<PlansAndFormatsSettings> {
      late Setting settings = context.read<SettingsState>().value;

      late final max = TextEditingController(text: settings.maxSets.toString());
      late final warmup =
          TextEditingController(text: settings.warmupSets?.toString());

      @override
      Widget build(BuildContext context) {
        settings = context.watch<SettingsState>().value;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('Plans & Formats'),
          ),
          body: ListView(
            children: [
              ...getFormatSettings('', settings),
              const Divider(),
              ...getPlanSettings('', settings, max, warmup),
            ],
          ),
        );
      }

      @override
      void dispose() {
        max.dispose();
        warmup.dispose();
        super.dispose();
      }
    }
    ```

    In `settings_page.dart`:
    - Remove the `import 'plan_settings.dart';` line (line 11) — no longer needed since settings_page.dart no longer navigates to PlanSettings directly. The getPlanSettings call in the search filter still works because format_settings.dart re-exports it... Actually NO. The search filter in settings_page.dart calls getPlanSettings directly. So we MUST keep the `import 'plan_settings.dart';` import.
    - Keep all existing imports as-is.
    - Replace the two ListTile entries for Formats (lines 150-157) and Plans (lines 158-166) with a SINGLE ListTile:
      ```dart
      ListTile(
        leading: const Icon(Icons.format_bold),
        title: const Text('Plans & Formats'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PlansAndFormatsSettings(),
          ),
        ),
      ),
      ```
    - Remove the Workouts ListTile (lines 186-194, the one with Icons.fitness_center that navigates to WorkoutSettings).
    - The `import 'workout_settings.dart';` stays because getWorkoutSettings is used in search.

    Final settings list order should be:
    1. Appearance
    2. Data management
    3. Backup Server
    4. Plans & Formats (merged, with Icons.format_bold)
    5. Tabs
    6. Timers
    7. 5/3/1 Block
    8. Spotify
  </action>
  <verify>
    Run `rg "WorkoutSettings\(\)" lib/settings/settings_page.dart` — should return no results.
    Run `rg "FormatSettings\(\)" lib/settings/settings_page.dart` — should return no results.
    Run `rg "PlanSettings\(\)" lib/settings/settings_page.dart` — should return no results.
    Run `rg "PlansAndFormatsSettings" lib/settings/settings_page.dart` — should return 1 result.
    Run `rg "getWorkoutSettings" lib/settings/settings_page.dart` — should return 1 result (search filter).
    Run `rg "getPlanSettings" lib/settings/settings_page.dart` — should return 1 result (search filter).
    Run `rg "getFormatSettings" lib/settings/settings_page.dart` — should return 1 result (search filter).
  </verify>
  <done>
    Settings page has 8 entries (Appearance, Data management, Backup Server, Plans & Formats, Tabs, Timers, 5/3/1 Block, Spotify). No Workouts entry. No separate Formats or Plans entries. Combined page shows format dropdowns then a divider then plan settings. Search still works for all three setting groups.
  </done>
</task>

</tasks>

<verification>
- Settings page shows exactly 8 ListTile entries (down from 10)
- No "Workouts", "Formats", or "Plans" standalone buttons exist
- "Plans & Formats" button navigates to combined page
- Combined page shows: strength unit, cardio unit, long date format, short date format, divider, warmup sets, sets per exercise, plan trailing display
- Search filter still returns results from getFormatSettings, getPlanSettings, and getWorkoutSettings
- No dangling imports or unused class references
</verification>

<success_criteria>
- Settings page reduced from 10 to 8 buttons
- WorkoutSettings class removed from workout_settings.dart
- PlanSettings class removed from plan_settings.dart
- FormatSettings class removed from format_settings.dart, replaced by PlansAndFormatsSettings
- All get*Settings search functions preserved and functional
- `flutter analyze` passes (user runs manually)
</success_criteria>

<output>
After completion, create `.planning/quick/012-clean-up-settings-page/012-SUMMARY.md`
</output>
