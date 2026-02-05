# Phase 4: Error Handling - Research

**Researched:** 2026-02-05
**Domain:** Flutter error handling, logging, and user feedback patterns
**Confidence:** HIGH

## Summary

This research investigates error handling patterns for import and backup operations in a Flutter/Dart mobile app. The codebase already has a working `toast()` utility function using `ScaffoldMessenger` and uses `print()` statements for console logging. The current error handling catches exceptions but provides generic messages without context (e.g., "Failed to import workouts: {exception}").

The requirements call for:
1. **Import failures**: Log exception type and context to console; show actionable toast to user
2. **Backup failures**: Log specific error reasons (permission, path, disk space); show toast to user

The standard approach is to enhance existing catch blocks with structured logging that includes context (file path, format, operation type) and user-friendly messages that explain what went wrong and what to do about it.

**Primary recommendation:** Enhance existing try-catch blocks in `import_data.dart`, `import_hevy.dart`, and `backup/auto_backup_service.dart` with context-rich logging and actionable user messages.

## Standard Stack

No new dependencies are needed. The existing patterns in the codebase are sufficient.

### Core (Already Present)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:developer | Built-in | `log()` for structured console output | Better than `print()` for production apps |
| flutter/material.dart | Built-in | SnackBar via `ScaffoldMessenger` | Material Design standard |

### Supporting (Already Present)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| utils.dart `toast()` | Custom | Centralized SnackBar utility | All user notifications |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `print()` | `logger` package | Adds dependency; `print()` is fine for this scope |
| Custom exception classes | Generic Exception | Custom classes add complexity; enhanced messages in catch blocks suffice |
| Sentry/Crashlytics | print/log | Overkill for local-only app without cloud services |

**Installation:** None required - use existing patterns.

## Architecture Patterns

### Current Error Handling Structure (in codebase)
```
lib/
├── import_data.dart         # Has try-catch, needs enhanced logging
├── import_hevy.dart         # Has try-catch, needs enhanced logging
├── backup/
│   ├── auto_backup_service.dart   # Has try-catch, needs enhanced logging
│   └── auto_backup_settings.dart  # UI layer, already shows toasts
└── utils.dart               # toast() helper - keep using this
```

### Pattern 1: Context-Rich Error Logging
**What:** Log exceptions with operation context (what was being done, with what data)
**When to use:** All catch blocks in import/backup operations
**Example:**
```dart
// Source: Flutter docs pattern + codebase conventions
} catch (e, stackTrace) {
  // Log with context for developers
  print('ERROR [ImportWorkouts] Failed to import workouts');
  print('  File: ${result.files.single.path}');
  print('  Exception type: ${e.runtimeType}');
  print('  Message: $e');
  if (e is FileSystemException) {
    print('  OS Error: ${e.osError}');
    print('  Path: ${e.path}');
  }

  // User-friendly toast
  final userMessage = _getUserMessage(e);
  toast(userMessage, duration: const Duration(seconds: 10));
}
```

### Pattern 2: Exception Type Detection for User Messages
**What:** Map exception types to actionable user messages
**When to use:** When converting exceptions to user-facing messages
**Example:**
```dart
// Source: Flutter best practices
String _getImportErrorMessage(Object error, String? filePath) {
  if (error is FormatException) {
    return 'Import failed: File format is invalid. Please check it\'s a valid backup file.';
  }
  if (error is FileSystemException) {
    if (error.osError?.errorCode == 13) { // EACCES
      return 'Import failed: Permission denied. Please grant storage access.';
    }
    if (error.osError?.errorCode == 28) { // ENOSPC
      return 'Import failed: Not enough storage space.';
    }
    return 'Import failed: Could not read file. ${error.message}';
  }
  if (error.toString().contains('Invalid backup file')) {
    return 'Import failed: File is missing required data (workouts.csv or gym_sets.csv).';
  }
  return 'Import failed: ${error.toString().split('\n').first}';
}
```

### Pattern 3: Backup Error Classification
**What:** Categorize backup failures by root cause
**When to use:** Auto backup and manual backup error handling
**Example:**
```dart
// Source: Codebase patterns + Android SAF error handling
String _getBackupErrorMessage(Object error) {
  final msg = error.toString().toLowerCase();

  // Permission errors (SAF or file system)
  if (msg.contains('permission') || msg.contains('denied') ||
      msg.contains('eacces') || msg.contains('errno = 13')) {
    return 'Backup failed: Permission denied. Please re-select the backup folder.';
  }

  // Storage errors
  if (msg.contains('no space') || msg.contains('disk full') ||
      msg.contains('enospc') || msg.contains('errno = 28')) {
    return 'Backup failed: Not enough storage space.';
  }

  // Path errors
  if (msg.contains('not found') || msg.contains('no such file') ||
      msg.contains('enoent')) {
    return 'Backup failed: Backup folder no longer exists. Please select a new folder.';
  }

  // Generic
  return 'Backup failed: ${error.toString().split('\n').first}';
}
```

### Anti-Patterns to Avoid
- **Swallowing exceptions silently:** Current `auto_backup_service.dart` line 55-58 catches and returns false without any logging. This must add logging.
- **Generic "Operation failed" messages:** Always include what operation and ideally why it failed.
- **Exposing raw exception text to users:** `e.toString()` often contains technical jargon. Transform it.
- **Logging sensitive data:** Don't log file contents, only paths and metadata.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Toast notifications | Custom snackbar logic | Existing `toast()` in utils.dart | Already handles floating, rounded, root scaffold |
| Exception classification | Giant if-else chains | Simple pattern matching on exception type | Keep it readable |
| Logging framework | Custom logger class | `print()` with consistent prefix | KISS - app is offline-only |

**Key insight:** The codebase already has the building blocks. The task is enhancing existing catch blocks with context, not building new infrastructure.

## Common Pitfalls

### Pitfall 1: Silent Failures in Auto-Backup
**What goes wrong:** `AutoBackupService.performAutoBackup()` catches all exceptions and returns false without logging.
**Why it happens:** Original implementation prioritized "don't crash" over "be debuggable."
**How to avoid:** Add print statements before returning false.
**Warning signs:** User reports "backup didn't work" but no logs to investigate.

### Pitfall 2: Unhelpful Error Messages
**What goes wrong:** Showing `e.toString()` which might say "Exception: Backup failed: File not found" - confusing for users.
**Why it happens:** Developer-friendly exceptions aren't user-friendly.
**How to avoid:** Map exception types to plain-language messages with actionable steps.
**Warning signs:** User confusion about what to do when they see an error.

### Pitfall 3: Missing Context in Logs
**What goes wrong:** Seeing "Failed to import" in logs without knowing which file or what format.
**Why it happens:** Generic catch blocks without context variables.
**How to avoid:** Always log the operation, the inputs (file path, format detected), and the exception details.
**Warning signs:** Debugging requires reproducing the issue because logs don't provide enough info.

### Pitfall 4: PlatformException Message Extraction
**What goes wrong:** PlatformException from MethodChannel has message in `e.message` not `e.toString()`.
**Why it happens:** PlatformException wraps native errors differently than Dart exceptions.
**How to avoid:** Check for PlatformException specifically: `if (e is PlatformException) { ... e.message ... }`.
**Warning signs:** Toast shows "PlatformException(error_code, null, null)" instead of actual message.

## Code Examples

### Import Error Logging (Enhanced Pattern)
```dart
// Source: Codebase import_data.dart pattern, enhanced per requirements
Future<void> importWorkouts(BuildContext context) async {
  Navigator.pop(context);
  String? filePath;

  try {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null) return;

    filePath = result.files.single.path;

    // ... existing import logic ...

    toast('Workout data imported successfully!');
  } catch (e, stackTrace) {
    // ERR-01: Log exception type and context
    print('ERROR [ImportWorkouts] Import failed');
    print('  File path: $filePath');
    print('  Exception type: ${e.runtimeType}');
    print('  Message: $e');

    if (!ctx.mounted) return;

    // ERR-02: Actionable user message
    final userMessage = _getImportErrorMessage(e, filePath);
    toast(userMessage, duration: const Duration(seconds: 10));
  }
}
```

### Backup Error Logging (Enhanced Pattern)
```dart
// Source: Codebase auto_backup_service.dart pattern, enhanced per requirements
static Future<bool> performAutoBackup() async {
  try {
    // ... existing logic ...

    await _createBackup(settings.backupPath!);

    // ... update timestamp, cleanup ...

    return true;
  } catch (e, stackTrace) {
    // ERR-03: Log specific error reason
    print('ERROR [AutoBackup] Backup failed');
    print('  Backup path: ${settings?.backupPath ?? 'null'}');
    print('  Exception type: ${e.runtimeType}');
    print('  Message: $e');
    if (e is FileSystemException) {
      print('  OS Error: ${e.osError}');
    }
    if (e is PlatformException) {
      print('  Platform error code: ${e.code}');
      print('  Platform message: ${e.message}');
    }

    // Note: Auto-backup is background, no toast here
    // Toast only from manual backup in auto_backup_settings.dart
    return false;
  }
}
```

### User Message Helper Function
```dart
// Source: Pattern derived from Flutter error handling docs
String _getImportErrorMessage(Object error, String? filePath) {
  // Check specific exception types first
  if (error is FormatException) {
    return 'Import failed: Invalid file format. Ensure this is a JackedLog backup file.';
  }

  if (error is FileSystemException) {
    final osError = error.osError;
    if (osError != null) {
      if (osError.errorCode == 13) { // Permission denied
        return 'Import failed: Storage permission denied.';
      }
      if (osError.errorCode == 2) { // File not found
        return 'Import failed: File not found.';
      }
    }
    return 'Import failed: Could not read file.';
  }

  // Check message content for custom exceptions
  final msg = error.toString().toLowerCase();
  if (msg.contains('missing required csv')) {
    return 'Import failed: Invalid backup file (missing workouts or sets data).';
  }
  if (msg.contains('insufficient columns')) {
    return 'Import failed: Backup file format is outdated or corrupted.';
  }
  if (msg.contains('csv is empty')) {
    return 'Import failed: Backup file contains no data.';
  }

  // Fallback: first line of error, truncated
  final firstLine = error.toString().split('\n').first;
  return 'Import failed: ${firstLine.length > 100 ? '${firstLine.substring(0, 100)}...' : firstLine}';
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `print()` only | `dart:developer log()` for structured output | Dart 2.x | Cleaner console output, metadata support |
| `e.toString()` to user | Exception type mapping | Flutter 2.0+ | Better UX |

**Deprecated/outdated:**
- None relevant - `print()` is still valid and used extensively in the codebase. The `log()` function from `dart:developer` is available but not required for this scope.

## Open Questions

1. **Toast duration for errors**
   - What we know: Current code uses 10 seconds for error toasts
   - What's unclear: Is 10 seconds optimal for reading error messages?
   - Recommendation: Keep 10 seconds, it's adequate for longer messages

2. **Auto-backup silent vs. notified failure**
   - What we know: ERR-04 requires toast for backup failures
   - What's unclear: Should auto-backup (background) trigger toast, or only manual backup?
   - Recommendation: Only manual backup shows toast (auto-backup is background, user didn't initiate). ERR-04 applies to manual backup context.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `lib/import_data.dart`, `lib/import_hevy.dart`, `lib/backup/auto_backup_service.dart`, `lib/backup/auto_backup_settings.dart`, `lib/utils.dart`
- [Flutter official docs: Handling errors](https://docs.flutter.dev/testing/errors) - Error handler patterns

### Secondary (MEDIUM confidence)
- [Flutter cookbook: Display a snackbar](https://docs.flutter.dev/cookbook/design/snackbars) - SnackBar best practices
- [Flutter logging best practices](https://blog.logrocket.com/flutter-logging-best-practices/) - Logging approaches

### Tertiary (LOW confidence)
- GitHub issues on FileSystemException patterns (permission denied, disk space errors) - errno codes

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Codebase already has all needed patterns
- Architecture: HIGH - Clear patterns from existing code, minimal changes needed
- Pitfalls: HIGH - Identified from actual codebase gaps (e.g., silent auto-backup failure)

**Research date:** 2026-02-05
**Valid until:** 2026-03-05 (stable patterns, no external dependencies changing)
