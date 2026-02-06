# Quick Task 003: Fix Notes Saving Not Persisting

## Problem

Intermittent bug where note edits appeared to save but were lost after re-entering the notes page.

## Root Cause

Two interacting bugs in `lib/notes/note_editor_page.dart`:

1. **`_isModified` never reset after save** — After `_saveNote()` wrote to the DB and called `Navigator.pop()`, the `PopScope` intercepted the pop (since `canPop: false` was hardcoded) and triggered `_onWillPop()` which saw `_isModified = true` and showed a second "Save changes?" dialog. If the user hit "Discard" on this unexpected dialog, the pop returned `null` instead of the saved note, causing the calling page to miss the update.

2. **`canPop: false` was hardcoded** — Every `Navigator.pop()` was intercepted, even programmatic ones after a successful save.

## Fix

Two surgical changes:

1. `canPop: !_isModified` — Dynamic PopScope that allows pops when there are no unsaved changes
2. `setState(() { _isModified = false; })` before both `Navigator.pop()` calls in `_saveNote()` — Resets modified state after successful DB write, enabling the pop to go through

## Files Changed

- `lib/notes/note_editor_page.dart` — Lines 110, 128, 190
