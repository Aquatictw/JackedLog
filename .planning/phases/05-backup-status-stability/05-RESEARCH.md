# Phase 5: Backup Status & Stability - Research

**Researched:** 2026-02-05
**Domain:** Flutter widget lifecycle, Drift stream queries, backup status UI patterns
**Confidence:** HIGH

## Summary

This research investigates requirements for Phase 5, which focuses on two areas: (1) displaying backup status information in the Settings page, and (2) fixing stability issues related to timer callbacks and settings initialization.

**Backup Status (BAK-01, BAK-02):** The codebase already has `lastAutoBackupTime` in the Settings table and displays it when auto-backups are enabled. The requirements call for showing backup status (success/failed/never) with appropriate visual indicators. Currently, backup failures are only logged to console - there's no persistent tracking of failure state. The settings page already shows "Last Backup" with `timeago.format()` when `lastAutoBackupTime` is not null.

**Stability (STB-01, STB-02):** Two issues identified:
1. The `ActiveWorkoutBar` timer callback accesses `context.read<WorkoutState>()` inside `setState()`. While it checks `mounted`, it still accesses `context` which can cause issues during hot reload or widget disposal.
2. The `SettingsState.init()` method uses `watchSingle()` which **throws a StateError** if no rows exist. Should use `watchSingleOrNull()` with null handling.

**Primary recommendation:** Add `lastBackupStatus` field to Settings table for backup status tracking, update UI to show status indicator, fix timer callbacks to check mounted before context access, and change settings stream to `watchSingleOrNull()`.

## Standard Stack

No new dependencies required. All solutions use existing Flutter/Dart patterns and Drift features.

### Core (Already Present)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material.dart | SDK | Widget lifecycle, `mounted` property | Standard Flutter pattern |
| drift | 2.28.1 | `watchSingleOrNull()` for safe streams | Built-in Drift API |
| timeago | 3.2.2 | Relative time display | Already used for backup timestamp |

### Supporting (Already Present)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| provider | 6.1.1 | State management | Already used throughout app |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Database field for status | In-memory state | In-memory loses status on app restart; DB persists |
| Separate backup_history table | Single status field | Overkill for "last backup status" requirement |
| Enum column for status | Text column | Text is simpler for nullable, matches pattern |

## Architecture Patterns

### Current Relevant Structure
```
lib/
├── backup/
│   ├── auto_backup_service.dart   # Performs backup, needs to update status
│   └── auto_backup_settings.dart  # Shows UI, needs status indicator
├── settings/
│   ├── settings_state.dart        # Uses watchSingle(), needs watchSingleOrNull()
│   └── settings_page.dart         # Entry point for backup settings
├── workouts/
│   └── active_workout_bar.dart    # Timer callback needs mounted check fix
└── database/
    └── settings.dart              # Needs lastBackupStatus column
```

### Pattern 1: Safe Timer Callbacks with Mounted Check
**What:** Check `mounted` before accessing `context` in timer callbacks, not just before `setState`
**When to use:** Any `Timer.periodic` callback that accesses BuildContext
**Example:**
```dart
// Source: Flutter docs BuildContext.mounted + codebase rest_timer_bar.dart pattern
void _startTimer() {
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!mounted) return;  // Exit early if widget disposed

    // Now safe to access context
    final workoutState = context.read<WorkoutState>();
    if (workoutState.activeWorkout != null) {
      setState(() {
        _elapsed = DateTime.now()
            .difference(workoutState.activeWorkout!.startTime);
      });
    }
  });
}
```

### Pattern 2: Safe Stream Subscription with watchSingleOrNull
**What:** Use `watchSingleOrNull()` instead of `watchSingle()` to handle empty result sets gracefully
**When to use:** Any stream subscription where the table might have zero rows
**Example:**
```dart
// Source: Drift docs stream queries
Future<void> init() async {
  subscription =
      (db.settings.select()..limit(1)).watchSingleOrNull().listen((event) {
    if (event != null) {
      value = event;
      notifyListeners();
    }
    // If event is null, keep existing value (graceful degradation)
  });
}
```

### Pattern 3: Backup Status Tracking
**What:** Persist backup status alongside timestamp to show success/failure state
**When to use:** When backup operations complete (success or failure)
**Example:**
```dart
// Update status on successful backup
await db.settings.update().write(
  SettingsCompanion(
    lastAutoBackupTime: Value(DateTime.now()),
    lastBackupStatus: const Value('success'),
  ),
);

// Update status on failed backup
await db.settings.update().write(
  SettingsCompanion(
    lastBackupStatus: const Value('failed'),
  ),
);
```

### Pattern 4: Status Indicator UI
**What:** Visual indicator showing backup health at a glance
**When to use:** Settings page backup section
**Example:**
```dart
// Source: Material Design status patterns
Widget _buildStatusIndicator(String? status, DateTime? lastBackup) {
  if (lastBackup == null) {
    return _StatusChip(
      icon: Icons.warning_amber_rounded,
      label: 'Never',
      color: colorScheme.outline,
    );
  }

  if (status == 'failed') {
    return _StatusChip(
      icon: Icons.error_outline_rounded,
      label: 'Failed',
      color: colorScheme.error,
    );
  }

  return _StatusChip(
    icon: Icons.check_circle_outline_rounded,
    label: 'Success',
    color: colorScheme.primary,
  );
}
```

### Anti-Patterns to Avoid
- **Accessing context after mounted check in wrong scope:** The `mounted` check must be BEFORE context access, not just wrapping `setState`
- **Using `watchSingle()` for potentially empty tables:** Always use `watchSingleOrNull()` when zero rows is possible
- **Storing status only in memory:** Backup status should persist to database for cross-session visibility

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stream error handling | Try-catch around watchSingle | `watchSingleOrNull()` | Built-in Drift API handles empty results |
| Timer lifecycle | Complex cancellation logic | Early `mounted` return | Simple Flutter pattern |
| Status persistence | Shared preferences | Database column | Settings already in DB, keeps data together |

**Key insight:** Drift's `watchSingleOrNull()` and Flutter's `mounted` property are designed exactly for these use cases. The solutions are built into the frameworks.

## Common Pitfalls

### Pitfall 1: Context Access After Widget Disposal
**What goes wrong:** `context.read<T>()` called in timer callback after widget is disposed
**Why it happens:** Timer fires, mounted is checked inside setState, but context is accessed first
**How to avoid:** Check `mounted` BEFORE any context access, not just before setState
**Warning signs:** "Looking up a deactivated widget's ancestor is unsafe" error during hot reload
**Current code issue (active_workout_bar.dart lines 36-46):**
```dart
// PROBLEMATIC: context.read is INSIDE setState, mounted check doesn't protect it
_timer = Timer.periodic(const Duration(seconds: 1), (timer) {
  if (mounted) {
    setState(() {
      final workoutState = context.read<WorkoutState>();  // <- This can fail!
      // ...
    });
  }
});
```

### Pitfall 2: watchSingle on Empty Table
**What goes wrong:** `StateError: Bad state: No element` thrown when settings table is empty
**Why it happens:** `watchSingle()` asserts exactly one row exists; fails on empty result
**How to avoid:** Use `watchSingleOrNull()` which returns null for empty results
**Warning signs:** App crash during first launch or after database reset
**Current code issue (settings_state.dart line 26):**
```dart
// PROBLEMATIC: watchSingle throws on empty table
(db.settings.select()..limit(1)).watchSingle().listen((event) { ... });
```

### Pitfall 3: Backup Status Not Persisted
**What goes wrong:** User sees backup as successful but last backup actually failed
**Why it happens:** Only timestamp is stored, not success/failure status
**How to avoid:** Store status alongside timestamp, update on both success and failure
**Warning signs:** User confusion about backup state after app restart

### Pitfall 4: Timer Not Cancelled on Dispose
**What goes wrong:** Timer continues firing after widget is removed from tree
**Why it happens:** Missing or incorrect dispose() implementation
**How to avoid:** Always cancel timer in dispose(), verify with `_timer?.cancel()`
**Note:** Current code handles this correctly - `dispose()` cancels timer

## Code Examples

### Fix 1: Safe Timer Callback (STB-01)
```dart
// Source: Flutter BuildContext docs + codebase rest_timer_bar.dart pattern
void _startTimer() {
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    // Check mounted FIRST, before any context access
    if (!mounted) return;

    final workoutState = context.read<WorkoutState>();
    if (workoutState.activeWorkout != null) {
      setState(() {
        _elapsed = DateTime.now()
            .difference(workoutState.activeWorkout!.startTime);
      });
    }
  });
}
```

### Fix 2: Safe Settings Stream (STB-02)
```dart
// Source: Drift docs watchSingleOrNull
Future<void> init() async {
  subscription =
      (db.settings.select()..limit(1)).watchSingleOrNull().listen((event) {
    if (event != null) {
      value = event;
      notifyListeners();
    }
    // Note: If event is null, we keep the existing value
    // This handles edge case of settings being deleted mid-session
  });
}
```

### Schema Addition: lastBackupStatus Column (BAK-02)
```dart
// Source: Codebase settings.dart pattern
// In lib/database/settings.dart
TextColumn get lastBackupStatus => text().nullable()();
// Values: null (never attempted), 'success', 'failed'
```

### Backup Status Update (BAK-01, BAK-02)
```dart
// In auto_backup_service.dart performAutoBackup()
// On success:
await db.settings.update().write(
  SettingsCompanion(
    lastAutoBackupTime: Value(DateTime.now()),
    lastBackupStatus: const Value('success'),
  ),
);

// On failure:
await db.settings.update().write(
  SettingsCompanion(
    lastBackupStatus: const Value('failed'),
  ),
);
```

### Status Indicator Widget (BAK-02)
```dart
// In auto_backup_settings.dart
Widget _buildBackupStatusIndicator(
  BuildContext context,
  String? status,
  DateTime? lastBackupTime,
) {
  final colorScheme = Theme.of(context).colorScheme;

  // Determine display values
  IconData icon;
  String label;
  Color color;

  if (lastBackupTime == null) {
    icon = Icons.backup_outlined;
    label = 'Never';
    color = colorScheme.outline;
  } else if (status == 'failed') {
    icon = Icons.error_outline_rounded;
    label = 'Failed';
    color = colorScheme.error;
  } else {
    icon = Icons.check_circle_outline_rounded;
    label = 'Success';
    color = colorScheme.primary;
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ],
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `watchSingle()` | `watchSingleOrNull()` | Drift 2.x | Safer stream handling for empty tables |
| Check mounted in setState | Check mounted before context access | Flutter 3.7+ | Prevents "deactivated widget" errors |

**Deprecated/outdated:**
- None - all patterns use current Flutter/Drift best practices

## Open Questions

1. **Should auto-backup failure trigger user notification?**
   - What we know: Currently auto-backup failures are silent (logged only)
   - What's unclear: Should failed auto-backups show a toast/notification?
   - Recommendation: Keep silent for auto-backup (background operation). The status indicator in Settings is sufficient visibility. Only manual backup shows toast (already implemented in Phase 4).

2. **What happens to status on backup path change?**
   - What we know: User can change backup folder
   - What's unclear: Should status reset when path changes?
   - Recommendation: Reset status to null when backup path changes, forcing "Never" display until first backup to new location succeeds.

3. **Database migration strategy for new column**
   - What we know: Need to add `lastBackupStatus` column
   - What's unclear: Column defaults
   - Recommendation: Add as nullable text column with no default. Existing users see "Success" if they have `lastAutoBackupTime` (assume past backups succeeded).

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `lib/workouts/active_workout_bar.dart`, `lib/settings/settings_state.dart`, `lib/backup/auto_backup_service.dart`, `lib/backup/auto_backup_settings.dart`
- [Drift docs - Stream queries](https://github.com/simolus3/drift/blob/develop/docs/content/dart_api/streams.md) - `watchSingleOrNull()` behavior
- [Flutter BuildContext class](https://api.flutter.dev/flutter/widgets/BuildContext-class.html) - `mounted` property usage

### Secondary (MEDIUM confidence)
- [Flutter State lifecycle](https://docs.flutter.dev/get-started/flutter-for/react-native-devs) - Timer and setState patterns

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies, uses existing Flutter/Drift APIs
- Architecture: HIGH - Clear patterns from codebase analysis
- Pitfalls: HIGH - Identified from actual code issues in current implementation

**Research date:** 2026-02-05
**Valid until:** 2026-03-05 (stable Flutter/Drift patterns)
