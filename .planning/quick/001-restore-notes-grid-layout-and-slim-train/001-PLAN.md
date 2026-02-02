---
phase: quick-001
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/notes/notes_page.dart
autonomous: true

must_haves:
  truths:
    - "Notes display in 2-column grid layout by default"
    - "Long-press on note enables reorder mode with list layout"
    - "5/3/1 Training Max button is visually slimmer"
  artifacts:
    - path: "lib/notes/notes_page.dart"
      provides: "Grid layout with reorder toggle, slim Training Max banner"
  key_links:
    - from: "_NotesPageState"
      to: "GridView.builder / ReorderableListView.builder"
      via: "_isReorderMode toggle"
---

<objective>
Restore 2-column grid layout for notes (was changed to list for reorder feature) and reduce height of 5/3/1 Training Max button.

Purpose: Notes looked better in grid format; reorder feature forced list layout. User wants grid back as default with option to reorder. Training Max banner is too tall.

Output: Notes display in grid by default, long-press enables reorder mode (switches to list), Training Max banner is slimmer.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@lib/notes/notes_page.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add reorder mode toggle and restore grid layout</name>
  <files>lib/notes/notes_page.dart</files>
  <action>
Add `_isReorderMode` boolean state to `_NotesPageState` (default: false).

Modify the notes display logic:
1. When `_isReorderMode == false`: Use `GridView.builder` with original grid delegate:
   ```dart
   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
     crossAxisCount: 2,
     childAspectRatio: 0.85,
     crossAxisSpacing: 12,
     mainAxisSpacing: 12,
   ),
   ```
2. When `_isReorderMode == true`: Keep existing `ReorderableListView.builder`

Add toggle button in app bar (next to add button):
- When in grid mode: `Icons.reorder` button to enter reorder mode
- When in reorder mode: `Icons.grid_view` button to exit reorder mode
- Or use `Icons.done` when in reorder mode to confirm and exit

Update `_NoteCard`:
- In grid mode: Use `Expanded` for content text (original behavior with `maxLines: 6`)
- In list mode: Use `mainAxisSize: MainAxisSize.min` (current behavior with `maxLines: 3`)

Handle search + reorder conflict:
- If `_searchQuery.isNotEmpty`, force grid mode (no reorder during search, same as current)
- When entering reorder mode, clear search if active
  </action>
  <verify>
Notes display in 2-column grid by default. Tapping reorder icon switches to list view with drag handles. Tapping done/grid icon returns to grid view. Order persists after exiting reorder mode.
  </verify>
  <done>
Grid layout is default view, reorder mode accessible via app bar toggle, layout correctly switches between grid and list.
  </done>
</task>

<task type="auto">
  <name>Task 2: Slim down Training Max banner</name>
  <files>lib/notes/notes_page.dart</files>
  <action>
In `_TrainingMaxBanner` widget, reduce vertical padding and icon size:

1. Change container padding from `EdgeInsets.symmetric(horizontal: 20, vertical: 16)` to `EdgeInsets.symmetric(horizontal: 16, vertical: 10)`

2. Reduce icon container padding from `EdgeInsets.all(12)` to `EdgeInsets.all(8)`

3. Reduce icon size from `32` to `24`

4. Reduce title font size from `17` to `15`

5. Remove subtitle text entirely ("Calculate weights for your program") to further slim the banner

6. Reduce chevron icon size from `28` to `24`

Result: Banner should be approximately 50-60% of its current height.
  </action>
  <verify>
Training Max banner is noticeably slimmer while remaining tappable and readable.
  </verify>
  <done>
Training Max banner has reduced height with smaller padding, icon, and no subtitle.
  </done>
</task>

</tasks>

<verification>
- [ ] App launches without errors
- [ ] Notes page shows grid layout (2 columns) by default
- [ ] Tapping reorder icon in app bar switches to list layout
- [ ] Notes can be reordered via drag-drop in list mode
- [ ] Exiting reorder mode returns to grid, order is preserved
- [ ] Search still works (forces grid mode, no reorder)
- [ ] Training Max banner is visibly slimmer
- [ ] Training Max banner is still tappable and opens editor dialog
</verification>

<success_criteria>
- Grid layout restored as default view
- Reorder functionality preserved via mode toggle
- Training Max banner height reduced significantly
- No regressions in existing functionality
</success_criteria>

<output>
After completion, create `.planning/quick/001-restore-notes-grid-layout-and-slim-train/001-SUMMARY.md`
</output>
