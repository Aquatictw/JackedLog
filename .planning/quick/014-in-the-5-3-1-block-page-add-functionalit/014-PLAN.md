---
phase: quick-014
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/fivethreeone/fivethreeone_state.dart
  - lib/fivethreeone/block_overview_page.dart
autonomous: true
must_haves:
  truths:
    - "User can move back a week after accidentally completing one"
    - "User must confirm before completing a week to prevent misclicks"
    - "Going back from week 1 of a cycle moves to the last week of the previous cycle"
    - "Cannot go back before the very first week of the block"
  artifacts:
    - path: "lib/fivethreeone/fivethreeone_state.dart"
      provides: "goBackWeek() method for reversing week advancement"
    - path: "lib/fivethreeone/block_overview_page.dart"
      provides: "Confirmation dialog on Complete Week, Go Back button"
  key_links:
    - from: "lib/fivethreeone/block_overview_page.dart"
      to: "lib/fivethreeone/fivethreeone_state.dart"
      via: "goBackWeek() method call"
      pattern: "goBackWeek"
---

<objective>
Add "go back a week" functionality and a confirmation dialog on "Complete Week" to the 5/3/1 block overview page. This prevents accidental week completion and lets users undo if they press Complete Week by mistake.

Purpose: Prevent misclicks on the irreversible "Complete Week" button and allow users to correct mistakes.
Output: Updated block_overview_page.dart with confirmation dialog and go-back button; updated fivethreeone_state.dart with goBackWeek() method.
</objective>

<context>
@lib/fivethreeone/block_overview_page.dart
@lib/fivethreeone/fivethreeone_state.dart
@lib/fivethreeone/schemes.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add goBackWeek() to state and confirmation + go-back UI to block overview</name>
  <files>lib/fivethreeone/fivethreeone_state.dart, lib/fivethreeone/block_overview_page.dart</files>
  <action>
**In fivethreeone_state.dart:**

Add a `goBackWeek()` method that is the inverse of `advanceWeek()`. Logic:
- If `currentWeek > 1`: decrement `currentWeek` by 1 within the same cycle.
- If `currentWeek == 1` and `currentCycle > 0`: move to previous cycle (`currentCycle - 1`) and set `currentWeek` to `cycleWeeks[currentCycle - 1]` (last week of previous cycle).
- If `currentWeek == 1` and `currentCycle == 0`: do nothing (already at the start of the block).
- Write the update to DB and call `refresh()`.

Add a getter `bool get canGoBack` that returns `true` if not at cycle 0, week 1 (i.e., there is a previous position to go back to).

**In block_overview_page.dart (_CompleteWeekButton):**

1. **Confirmation dialog on Complete Week:** Wrap the existing `onPressed` logic. Before doing anything (before the TM bump check), show a confirmation AlertDialog:
   - Title: the current `label` value (either "Complete Week" or "Complete Block")
   - Content: "Are you sure you want to complete this week?" (or "...complete this block?" if isComplete)
   - Actions: "Cancel" (returns false) and "Confirm" (returns true)
   - If cancelled, return early without advancing.
   - The existing TM bump dialog flow remains unchanged after confirmation.

2. **Go Back button:** Below the Complete Week button (or in a Row alongside it), add an OutlinedButton or TextButton with icon `Icons.undo` and label "Go Back".
   - Only show this button when `state.canGoBack` is true.
   - On press, show a simple confirmation dialog: "Go back to the previous week?" with Cancel/Confirm.
   - If confirmed, call `state.goBackWeek()`.
   - Place the Go Back button ABOVE the Complete Week button, left-aligned or centered, with subtle styling (TextButton.icon) so it doesn't compete visually with the primary action.
  </action>
  <verify>Run `dart analyze lib/fivethreeone/fivethreeone_state.dart lib/fivethreeone/block_overview_page.dart` and confirm no errors. Visually confirm: Complete Week shows confirmation dialog; Go Back button appears when not at week 1 cycle 0; Go Back moves position backward correctly.</verify>
  <done>
  - Complete Week / Complete Block button shows confirmation dialog before advancing
  - Go Back button visible when not at the start of the block
  - Go Back moves to previous week, or last week of previous cycle when at week 1
  - Go Back hidden when at cycle 0, week 1
  - No regressions in existing advance/TM-bump flow
  </done>
</task>

</tasks>

<verification>
- `dart analyze lib/fivethreeone/fivethreeone_state.dart lib/fivethreeone/block_overview_page.dart` passes with no errors
- Manual test: start at Leader 1 Week 2, press Go Back, confirm position moves to Leader 1 Week 1
- Manual test: at Leader 1 Week 1, Go Back button is hidden
- Manual test: at Leader 2 Week 1, press Go Back, confirm moves to Leader 1 Week 3
- Manual test: press Complete Week, confirm dialog appears, cancel does not advance
- Manual test: press Complete Week, confirm dialog appears, confirm advances normally
</verification>

<success_criteria>
Users can undo accidental week completions and must confirm before advancing, preventing misclicks.
</success_criteria>

<output>
After completion, create `.planning/quick/014-in-the-5-3-1-block-page-add-functionalit/014-SUMMARY.md`
</output>
