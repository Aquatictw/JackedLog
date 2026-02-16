---
phase: quick-009
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/backup/auto_backup_settings.dart
  - lib/server/backup_push_service.dart
autonomous: true

must_haves:
  truths:
    - "When push backup fails, user sees an error toast with the failure reason"
    - "Push status shows 'Last push failed' even on first-ever failed push (lastPushTime null)"
    - "Push errors are logged to Flutter console for debugging"
  artifacts:
    - path: "lib/backup/auto_backup_settings.dart"
      provides: "Error toast in _performPush catch block, fixed status priority logic"
    - path: "lib/server/backup_push_service.dart"
      provides: "Sets lastPushTime on failure so status widget can show timing"
  key_links:
    - from: "_performPush() catch block"
      to: "toast()"
      via: "error message display"
      pattern: "toast\\("
    - from: "_buildPushStatus()"
      to: "lastPushStatus == 'failed'"
      via: "priority check before lastPushTime null check"
      pattern: "lastPushStatus.*failed"
---

<objective>
Fix push backup silent failure - two bugs where (1) _performPush() swallows errors with no user feedback, and (2) push status shows "Never pushed" instead of "Last push failed" when the first-ever push fails because lastPushTime is null and gets checked before lastPushStatus.

Purpose: Users currently have no idea when push backup fails. They see "Never pushed" and press the button again with no feedback. This fix surfaces errors via toast and shows correct failure status.
Output: Both files patched, push failures visible to user.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/backup/auto_backup_settings.dart
@lib/server/backup_push_service.dart
@lib/utils.dart (toast function)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix _performPush error handling and _buildPushStatus priority logic</name>
  <files>lib/backup/auto_backup_settings.dart</files>
  <action>
Two changes in this file:

**Change 1: Add error toast to _performPush() catch block (line 584-587)**

Replace the empty catch block:
```dart
} catch (e) {
  if (mounted) {
    await settings.init();
  }
}
```

With error feedback:
```dart
} catch (e) {
  print('Push backup failed: $e');
  if (mounted) {
    await settings.init();
    toast('Push failed: ${e.toString().replaceFirst('Exception: ', '')}');
  }
}
```

The `replaceFirst('Exception: ', '')` strips the Dart "Exception: " prefix so toasts read cleanly (e.g., "Push failed: Authentication failed. Check your API key." instead of "Push failed: Exception: Authentication failed. Check your API key.").

**Change 2: Fix _buildPushStatus() condition ordering (lines 508-520)**

The current logic checks `lastPushTime == null` first, which means a failed push where lastPushTime is still null shows "Never pushed" instead of the error state.

Replace the if/else chain:
```dart
if (lastPushTime == null) {
  icon = Icons.cloud_off_rounded;
  statusText = 'Never pushed';
  color = colorScheme.outline;
} else if (lastPushStatus == 'failed') {
```

With failure-first priority:
```dart
if (lastPushStatus == 'failed') {
  icon = Icons.error_outline_rounded;
  statusText = lastPushTime != null
      ? 'Push failed ${timeago.format(lastPushTime)}'
      : 'Push failed';
  color = colorScheme.error;
} else if (lastPushTime == null) {
  icon = Icons.cloud_off_rounded;
  statusText = 'Never pushed';
  color = colorScheme.outline;
} else {
  icon = Icons.check_circle_outline_rounded;
  statusText = 'Last pushed: ${timeago.format(lastPushTime)}';
  color = colorScheme.primary;
}
```

This checks failure status FIRST regardless of whether lastPushTime is set. When there IS a lastPushTime on failure, it shows relative time ("Push failed 5 minutes ago"). When there is no lastPushTime (first-ever push failed), it shows just "Push failed".
  </action>
  <verify>Read the modified file and confirm: (1) catch block in _performPush has print and toast calls, (2) _buildPushStatus checks lastPushStatus == 'failed' before lastPushTime == null.</verify>
  <done>Push failures show error toast to user. Status widget correctly prioritizes failure state over "Never pushed" state.</done>
</task>

<task type="auto">
  <name>Task 2: Set lastPushTime on failure in BackupPushService</name>
  <files>lib/server/backup_push_service.dart</files>
  <action>
In the catch block (lines 52-59), add `lastPushTime` so the status widget can show WHEN the push failed:

Replace:
```dart
catch (e) {
  // Failure: update settings with failed status, then rethrow
  await db.settings.update().write(
        const SettingsCompanion(
          lastPushStatus: Value('failed'),
        ),
      );
  rethrow;
}
```

With:
```dart
catch (e) {
  // Failure: update settings with failed status and time, then rethrow
  await db.settings.update().write(
        SettingsCompanion(
          lastPushStatus: const Value('failed'),
          lastPushTime: Value(DateTime.now()),
        ),
      );
  rethrow;
}
```

Note: Remove the `const` from `SettingsCompanion(` since `Value(DateTime.now())` is not const. Keep `const Value('failed')` on the string literal.

This ensures lastPushTime is always set on failure, so the status widget in Task 1 can show "Push failed 5 minutes ago" instead of just "Push failed".
  </action>
  <verify>Read the modified file and confirm the catch block writes both lastPushStatus and lastPushTime, and the const keyword is removed from SettingsCompanion constructor but kept on the Value('failed') literal.</verify>
  <done>BackupPushService records both failure status AND timestamp on push failure.</done>
</task>

</tasks>

<verification>
- Read both modified files to confirm changes are correct
- Confirm no syntax issues (matching parens, correct const usage)
- The toast() function is already imported via utils.dart (line 14)
- The timeago import is already present (line 9)
</verification>

<success_criteria>
- _performPush() catch block prints error and shows toast with failure reason
- _buildPushStatus() checks lastPushStatus == 'failed' BEFORE lastPushTime == null
- BackupPushService failure path sets both lastPushStatus and lastPushTime
- No new imports needed (toast from utils.dart and timeago already imported)
</success_criteria>

<output>
After completion, create `.planning/quick/009-fix-push-backup-silent-failure/009-SUMMARY.md`
</output>
