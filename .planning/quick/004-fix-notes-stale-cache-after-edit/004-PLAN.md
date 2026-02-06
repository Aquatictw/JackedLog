---
phase: quick-004
plan: 01
type: execute
wave: 1
depends_on: []
files_modified: [lib/notes/notes_page.dart]
autonomous: true

must_haves:
  truths:
    - "After editing a note and returning to the list, the updated title/content appears immediately"
    - "After creating a note and returning to the list, the new note appears immediately"
    - "No snackbar-related crash or 'deactivated widget' error in console after edit/create"
    - "Drag-to-reorder still works correctly (reorder mode and grid mode)"
    - "Search still forces re-sync with stream data"
  artifacts:
    - path: "lib/notes/notes_page.dart"
      provides: "Fixed _localNotes cache invalidation and safe snackbar"
  key_links:
    - from: "_editNote() / _createNote()"
      to: "StreamBuilder rebuild"
      via: "_localNotes = null triggers fresh sync from stream on next build"
      pattern: "_localNotes = null"
---

<objective>
Fix two bugs in notes_page.dart: (1) stale _localNotes cache not refreshing after edit/create navigation returns, and (2) deactivated widget error when showing snackbar after navigation.

Purpose: Notes list currently shows stale data after editing because _localNotes cache is never invalidated on navigation return. The snackbar after navigation sometimes crashes on a deactivated scaffold.
Output: A single file fix in notes_page.dart that invalidates the cache and guards the snackbar.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/notes/notes_page.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Invalidate _localNotes cache after navigation and guard snackbar calls</name>
  <files>lib/notes/notes_page.dart</files>
  <action>
In `_createNote()` (lines 57-72):
- After `await Navigator.push` returns (line 58), add `setState(() { _localNotes = null; });` BEFORE the snackbar check. This forces the StreamBuilder to re-sync _localNotes from the stream on the next build, regardless of whether a note was actually created.
- Wrap the `ScaffoldMessenger.of(context).showSnackBar(...)` call (lines 68-70) in a try-catch that silently catches FlutterError (the deactivated widget error). This is simpler and safer than addPostFrameCallback.

In `_editNote()` (lines 74-90):
- Same pattern: after `await Navigator.push` returns (line 75), add `setState(() { _localNotes = null; });` BEFORE the snackbar check.
- Wrap the `ScaffoldMessenger.of(context).showSnackBar(...)` call (lines 86-88) in a try-catch that silently catches FlutterError.

The setState with _localNotes = null should happen unconditionally (not inside the `if (result != null)` block) because the user may have edited content even if the result is null (e.g., if the editor pops without returning a result but the DB was already updated via auto-save).

The resulting _createNote should look like:
```dart
Future<void> _createNote() async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          colorIndex: _getRandomColorIndex(),
        ),
      ),
    );

    if (!mounted) return;
    setState(() { _localNotes = null; });

    if (result != null) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note created')),
        );
      } on FlutterError catch (_) {
        // Scaffold may be deactivated during frame transition
      }
    }
  }
```

And _editNote should follow the same pattern with 'Note updated' message.

Do NOT touch _deleteNote - it doesn't navigate away so it doesn't have this stale cache problem, and its snackbar works fine because the widget tree is stable.

Do NOT change the StreamBuilder sync logic at line 296-299. The fix is purely in the navigation return path.
  </action>
  <verify>
Read the modified file and confirm:
1. Both _createNote and _editNote set `_localNotes = null` via setState after navigation returns
2. Both snackbar calls are wrapped in try-catch for FlutterError
3. The setState happens BEFORE the snackbar conditional
4. _deleteNote is unchanged
5. The StreamBuilder sync logic at line ~296-299 is unchanged
6. No other changes were made
  </verify>
  <done>
- _createNote() invalidates _localNotes cache after navigation returns
- _editNote() invalidates _localNotes cache after navigation returns
- Snackbar calls are guarded against deactivated widget errors
- Reorder functionality is unaffected (still reads from _localNotes which gets re-populated by StreamBuilder)
- Search cache invalidation is unaffected
  </done>
</task>

</tasks>

<verification>
1. Read the final file and verify only _createNote and _editNote methods changed
2. Verify the pattern: setState(() { _localNotes = null; }) appears after each Navigator.push await
3. Verify try-catch wraps each ScaffoldMessenger.showSnackBar call
4. Verify _deleteNote is untouched
5. Verify StreamBuilder sync logic (line ~296-299) is untouched
</verification>

<success_criteria>
- After editing a note's title/content and pressing back, the notes list shows the updated data immediately
- After creating a new note, it appears in the list immediately
- No "Looking up a deactivated widget's ancestor" error in console
- Drag reorder in both grid and list mode still works
- Search still works (forces _localNotes re-sync)
</success_criteria>

<output>
After completion, create `.planning/quick/004-fix-notes-stale-cache-after-edit/004-SUMMARY.md`
</output>
