---
phase: 04-error-handling
plan: 01
subsystem: error-handling
tags: [error-handling, import, backup, user-feedback]

dependency-graph:
  requires: []
  provides:
    - context-rich-error-logging
    - user-friendly-error-messages
    - import-error-handling
    - backup-error-handling
  affects:
    - future-debugging
    - user-experience

tech-stack:
  added: []
  patterns:
    - error-classification-helper-functions
    - contextual-console-logging

file-tracking:
  key-files:
    created: []
    modified:
      - lib/import_data.dart
      - lib/import_hevy.dart
      - lib/backup/auto_backup_service.dart
      - lib/backup/auto_backup_settings.dart

decisions:
  - id: DEC-04-01-01
    decision: Use helper functions for error message classification
    rationale: Centralizes error-to-message mapping, easy to extend for new error types

metrics:
  duration: 2 min
  completed: 2026-02-05
---

# Phase 04 Plan 01: Import and Backup Error Handling Summary

**One-liner:** Enhanced error handling with context-rich logging and user-friendly messages for import/backup failures

## What Was Built

### ERR-01/ERR-02: Import Error Handling
- Added `_getImportErrorMessage()` helper in `import_data.dart` that maps:
  - `FormatException` -> "Invalid file format"
  - `FileSystemException` with OS error codes -> permission/not-found messages
  - Exception messages containing "csv is empty", "missing required csv", "insufficient columns" -> specific guidance
- Added `_getHevyImportErrorMessage()` helper in `import_hevy.dart` for Hevy-specific errors
- All import catch blocks now log: file path, exception type, message, and OS error if applicable

### ERR-03/ERR-04: Backup Error Handling
- Added context logging to `auto_backup_service.dart` `performAutoBackup()` catch block:
  - Exception type, message, FileSystemException OS error/path, PlatformException code/message
- Added `_getBackupErrorMessage()` helper in `auto_backup_settings.dart` that maps:
  - `PlatformException` with permission/space keywords -> actionable messages
  - `FileSystemException` OS error codes (13=permission, 28=space, 2=not found) -> specific guidance
  - Generic error string patterns -> appropriate fallback messages

## Commits

| Hash | Task | Description |
|------|------|-------------|
| 4122e4be | 1 | Enhanced import error handling (ERR-01, ERR-02) |
| eccf2f10 | 2 | Enhanced backup error handling (ERR-03, ERR-04) |

## Decisions Made

| ID | Decision | Rationale |
|----|----------|-----------|
| DEC-04-01-01 | Use helper functions for error classification | Centralizes mapping logic, easy to extend for new error types |

## Deviations from Plan

None - plan executed exactly as written.

## Testing Notes

User should run `flutter analyze` to verify no syntax errors.

Manual testing scenarios:
1. Import a non-ZIP file for workout import -> should show "Invalid file format"
2. Import a ZIP without workouts.csv -> should show "missing workouts or sets data"
3. Try backup when folder access is revoked -> should show permission message

## Files Modified

| File | Changes |
|------|---------|
| lib/import_data.dart | +59 lines: context logging, _getImportErrorMessage() helper, capture file path |
| lib/import_hevy.dart | +22 lines: context logging, _getHevyImportErrorMessage() helper, capture file path |
| lib/backup/auto_backup_service.dart | +10 lines: context logging with FileSystemException and PlatformException details |
| lib/backup/auto_backup_settings.dart | +45 lines: context logging, _getBackupErrorMessage() helper |

## Next Phase Readiness

**Ready for:** Plan 02 (Timer/Plan Operation Error Handling)

**No blockers identified.**
