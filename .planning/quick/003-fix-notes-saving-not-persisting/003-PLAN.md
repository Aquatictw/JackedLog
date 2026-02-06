---
phase: quick-003
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/notes/note_editor_page.dart
autonomous: true

must_haves:
  truths:
    - "Tapping the save checkmark persists the note and returns to the notes list without a second dialog"
    - "Pressing back on a modified note shows the save dialog exactly once"
    - "Pressing back on an unmodified note exits immediately without dialog"
    - "Choosing Discard in the dialog exits without saving"
  artifacts:
    - path: "lib/notes/note_editor_page.dart"
      provides: "Fixed PopScope and save flow"
      contains: "_isModified = false"
  key_links:
    - from: "_saveNote()"
      to: "PopScope canPop"
      via: "_isModified reset enables pop-through"
      pattern: "_isModified = false"
---

<objective>
Fix intermittent note save failures caused by PopScope intercepting programmatic Navigator.pop() after a successful save.

Purpose: Two bugs interact — `_isModified` is never reset after save, and `canPop: false` is hardcoded, so every `Navigator.pop()` is intercepted and triggers a second "Save changes?" dialog. This causes lost saves when users hit Discard on the unexpected second dialog.

Output: A corrected `note_editor_page.dart` where saves persist reliably and navigation behaves correctly.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/notes/note_editor_page.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix PopScope save/navigation interaction</name>
  <files>lib/notes/note_editor_page.dart</files>
  <action>
  Two changes in `_NoteEditorPageState`:

  1. **Make `canPop` dynamic** (line 188): Change `canPop: false` to `canPop: !_isModified`. This allows `Navigator.pop()` to go through unintercepted when there are no unsaved changes.

  2. **Reset `_isModified` after successful save** in `_saveNote()`: Add `setState(() { _isModified = false; });` immediately BEFORE both `Navigator.pop(context, note)` calls (lines 110 and 127). This must be inside the `if (mounted)` check but before the pop. The setState triggers a rebuild that updates `canPop` to `true`, so the subsequent `Navigator.pop()` passes through without PopScope intercepting it.

  The resulting flow:
  - User taps save checkmark -> `_saveNote()` writes to DB -> `_isModified = false` -> `canPop` becomes `true` -> `Navigator.pop(context, note)` succeeds without interception
  - User taps back with changes -> `canPop` is `false` -> PopScope intercepts -> `_onWillPop()` shows dialog once -> Save or Discard handled correctly
  - User taps back without changes -> `canPop` is `true` -> normal pop, no dialog

  Do NOT add an `_isSaving` flag — the simpler approach of resetting `_isModified` is sufficient.
  Do NOT change `_onWillPop()` logic — it already works correctly when `_isModified` has the right value.
  Do NOT change the back button's `onPressed` handler — it already calls `_onWillPop()` correctly.
  </action>
  <verify>
  Read the modified file and confirm:
  1. `canPop: !_isModified` is set on PopScope
  2. `_isModified = false` appears before both `Navigator.pop(context, note)` calls in `_saveNote()`
  3. No other behavioral changes were introduced
  </verify>
  <done>
  - PopScope uses dynamic `canPop: !_isModified`
  - `_isModified` is reset to `false` after successful DB write, before Navigator.pop
  - Save checkmark navigates back without showing "Save changes?" dialog
  - Back button on modified note shows dialog exactly once
  </done>
</task>

</tasks>

<verification>
- Static analysis: Code has no syntax errors (user runs `flutter analyze`)
- Manual test: Edit an existing note, tap save checkmark — should return to notes list immediately without dialog
- Manual test: Edit a note, press back — should show "Save changes?" dialog exactly once
- Manual test: Open a note without editing, press back — should exit immediately
</verification>

<success_criteria>
- The save checkmark always persists the note and returns to notes list without a second dialog
- The back button shows save dialog at most once when there are unsaved changes
- No regression in new note creation, color changes, or discard behavior
</success_criteria>

<output>
After completion, create `.planning/quick/003-fix-notes-saving-not-persisting/003-SUMMARY.md`
</output>
