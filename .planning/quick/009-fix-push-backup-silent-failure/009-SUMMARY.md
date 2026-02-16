# Quick Task 009: Fix Push Backup Silent Failure

## Changes

### lib/backup/auto_backup_settings.dart
- **`_performPush()` catch block**: Added `print()` for debug logging and `toast()` to show error message to user
- **`_buildPushStatus()`**: Reordered if/else chain to check `lastPushStatus == 'failed'` BEFORE `lastPushTime == null`, so failure state is shown even on first-ever failed push

### lib/server/backup_push_service.dart
- **Failure path**: Now sets both `lastPushStatus` and `lastPushTime` on failure, so the status widget can show when the push failed

## Root Cause
Two bugs combined to create a completely silent failure:
1. `_performPush()` caught exceptions but never showed any feedback to the user
2. `_buildPushStatus()` checked `lastPushTime == null` first, so even when `lastPushStatus` was 'failed', the UI showed "Never pushed" because `lastPushTime` was only set on success
