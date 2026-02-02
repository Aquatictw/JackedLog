---
phase: quick
plan: 002
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/workouts/workout_detail_page.dart
autonomous: true

must_haves:
  truths:
    - "Exercise icons in workout detail page show barbell icon"
    - "Barbell icon matches active workout page style"
  artifacts:
    - path: "lib/workouts/workout_detail_page.dart"
      provides: "Exercise icon rendering"
      contains: "Icons.fitness_center"
  key_links: []
---

<objective>
Replace exercise first-character icon with barbell icon in workout detail page.

Purpose: Consistent iconography between workout detail page and active workout page.
Output: Updated `_buildInitialBadge` method using `Icons.fitness_center` instead of first letter.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/workouts/workout_detail_page.dart (lines 1840-1858: _buildInitialBadge method)
@lib/widgets/workout/exercise_header.dart (reference: uses Icons.fitness_center)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace first-letter badge with barbell icon</name>
  <files>lib/workouts/workout_detail_page.dart</files>
  <action>
Modify the `_buildInitialBadge` method (around line 1840) to show `Icons.fitness_center` instead of the exercise name's first character.

Current implementation shows:
```dart
Text(
  name.isNotEmpty ? name[0].toUpperCase() : '?',
  style: const TextStyle(...)
)
```

Change to match the style used in `exercise_header.dart`:
```dart
Icon(
  Icons.fitness_center,
  color: Colors.white,
  size: 20,
)
```

Keep the container decoration (circular badge with primary color background) unchanged.
  </action>
  <verify>Visual inspection - exercise cards in workout detail page show barbell icon instead of first letter</verify>
  <done>All exercises in workout detail page display barbell icon matching active workout page style</done>
</task>

</tasks>

<verification>
- Open a completed workout's detail page
- Each exercise should show barbell icon (dumbbell shape) instead of first letter
- Icon style matches active workout bar and exercise header components
</verification>

<success_criteria>
- Exercise icons in workout detail page use `Icons.fitness_center`
- Visual consistency with active workout page
- No regressions in exercise card layout
</success_criteria>

<output>
After completion, create `.planning/quick/002-exercise-icon-barbell-workout-detail/002-SUMMARY.md`
</output>
