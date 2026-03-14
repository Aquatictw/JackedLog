---
phase: quick-015
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/fivethreeone/block_overview_page.dart
autonomous: true
requirements: [QUICK-015]
must_haves:
  truths:
    - "Go Back and Complete Week buttons appear side-by-side on the same row"
    - "Go Back button occupies 1/3 of the row width"
    - "Complete Week button occupies 2/3 of the row width"
    - "Both buttons still function correctly (confirmations, navigation)"
  artifacts:
    - path: "lib/fivethreeone/block_overview_page.dart"
      provides: "Updated _CompleteWeekButton with Row layout"
      contains: "flex: 1"
  key_links:
    - from: "_CompleteWeekButton"
      to: "FiveThreeOneState"
      via: "advanceWeek, goBackWeek"
      pattern: "state\\.(advanceWeek|goBackWeek)"
---

<objective>
Place the "Go Back" and "Complete Week" buttons on the same row in the 5/3/1 block overview page, with Go Back taking 1/3 width and Complete Week taking 2/3 width.

Purpose: Better use of horizontal space and clearer visual hierarchy for the primary action (Complete Week).
Output: Updated block_overview_page.dart with side-by-side button layout.
</objective>

<context>
@lib/fivethreeone/block_overview_page.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Rearrange Go Back and Complete Week into a single Row with 1:2 flex ratio</name>
  <files>lib/fivethreeone/block_overview_page.dart</files>
  <action>
In the `_CompleteWeekButton.build` method (around line 440), replace the current vertical Column layout with a Row-based layout:

1. When `state.canGoBack` is true, wrap both buttons in a `Row` with `crossAxisAlignment: CrossAxisAlignment.center` and a small gap between them (SizedBox width: 8).

2. The "Go Back" `TextButton.icon` goes inside `Expanded(flex: 1, ...)` — this gives it 1/3 of the row.

3. The "Complete Week" `FilledButton.icon` goes inside `Expanded(flex: 2, ...)` — this gives it 2/3 of the row.

4. Remove the `minimumSize: Size.fromHeight(48)` constraint from the FilledButton style (or keep height but remove width since Expanded handles width). Actually, keep a `minimumSize` of `Size(0, 48)` so the button stays tall but doesn't force full width.

5. When `state.canGoBack` is false, render only the `FilledButton.icon` at full width as it currently does (with `Size.fromHeight(48)`).

6. Remove the `Padding(padding: EdgeInsets.only(bottom: 8))` wrapper from the Go Back button since they're now side-by-side, not stacked.

7. Ensure the Go Back TextButton also has a height that matches — add `style: TextButton.styleFrom(minimumSize: Size(0, 48))` so both buttons are the same height.

The resulting build method structure when canGoBack is true:
```dart
Row(
  children: [
    Expanded(
      flex: 1,
      child: TextButton.icon(
        // ... go back logic unchanged
        style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      flex: 2,
      child: FilledButton.icon(
        // ... complete week logic unchanged
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
    ),
  ],
)
```

When canGoBack is false, just the FilledButton with `Size.fromHeight(48)` as before.
  </action>
  <verify>
    <automated>rg "flex: 1|flex: 2" lib/fivethreeone/block_overview_page.dart</automated>
  </verify>
  <done>Go Back button takes 1/3 width and Complete Week takes 2/3 width on the same row. When Go Back is not available, Complete Week remains full-width. Both button tap handlers (confirmation dialogs, state updates) work identically to before.</done>
</task>

</tasks>

<verification>
- `rg "flex: 1" lib/fivethreeone/block_overview_page.dart` returns the Go Back Expanded
- `rg "flex: 2" lib/fivethreeone/block_overview_page.dart` returns the Complete Week Expanded
- Both buttons are inside a Row widget when canGoBack is true
- No compile errors (user runs `flutter analyze`)
</verification>

<success_criteria>
- Go Back and Complete Week buttons render side-by-side on the same row
- Go Back occupies 1/3, Complete Week occupies 2/3 of available width
- When canGoBack is false, Complete Week is full-width
- All existing confirmation dialogs and navigation logic preserved
</success_criteria>

<output>
After completion, update .planning/STATE.md with quick task 015 entry.
</output>
