# Phase 1: Quick Wins - Research

**Researched:** 2026-02-02
**Domain:** Flutter/Dart - UI modifications and SQL aggregation
**Confidence:** HIGH

## Summary

This phase involves two independent UI modifications: adding a "Total Time" stat card to the overview page and removing the three-dots menu from the history search bar.

The overview page (`lib/graph/overview_page.dart`) already has a well-established pattern for stat cards with period selection. Duration calculation uses `endTime?.difference(startTime)` on workout records, with the format `Xh Ym` for hours or `Xm` for minutes only. The existing `StatCard` widget and `PeriodSelector` are already built and integrated.

The history search bar uses `AppSearch` widget (`lib/app_search.dart`) which contains a three-dots menu icon button with popup menu items. This widget is used in two places within `HistoryPage` (lines 103 and 172), one for workouts view and one for sets view.

**Primary recommendation:** Add total time calculation to `_loadData()` method and add a new StatCard to the stats grid. For history cleanup, pass a new optional parameter to AppSearch or conditionally hide the three-dots menu based on context.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | 3.x | UI framework | Already in project |
| Drift | 2.28.1 | Type-safe SQL queries | Already used for all DB operations |
| Provider | 6.1.1 | State management | Already in project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| intl | 0.20.2 | Date/time formatting | Already imported in overview_page |

No new dependencies required.

## Architecture Patterns

### Recommended Approach for STATS-01

The overview page follows a pattern of:
1. State variables declared at widget level
2. `_loadData()` async method that runs SQL queries and updates state
3. `setState()` to trigger rebuild with new data
4. Widget builder methods for each section

**Total time query pattern:**
```dart
// Add to _loadData() method - sum of (endTime - startTime) for completed workouts
final totalTimeQuery = await db.customSelect(
  '''
  SELECT SUM(end_time - start_time) as total_seconds
  FROM workouts
  WHERE start_time >= ?
    AND end_time IS NOT NULL
  ''',
  variables: [
    drift.Variable.withInt(startDate.millisecondsSinceEpoch ~/ 1000),
  ],
).getSingleOrNull();

final totalTimeSeconds = totalTimeQuery?.read<int?>('total_seconds') ?? 0;
```

**Duration formatting pattern (existing in codebase):**
```dart
String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  return '${duration.inMinutes}m';
}
```

Note: For zero values, context specifies "0h 0m" format.

### Recommended Approach for HIST-01

Two options for removing the three-dots menu:

**Option A (Recommended): Add optional parameter to hide menu**
```dart
class AppSearch extends StatefulWidget {
  // ... existing parameters
  final bool showMenu; // Default: true

  const AppSearch({
    // ...
    this.showMenu = true,
  });
```

Then conditionally render the menu icon.

**Option B: Create separate widget**
Less preferred - would duplicate code.

### Anti-Patterns to Avoid
- **Hand-rolling duration math:** Use Duration class methods, not manual division
- **Multiple setState calls:** Batch all state updates in single setState
- **Hardcoded time zone handling:** SQLite stores Unix timestamps, Drift handles conversion

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Duration formatting | Custom math | Duration.inHours, Duration.inMinutes % 60 | Already implemented in 4 places |
| SQL timestamp math | Custom functions | SQLite built-in SUM(end_time - start_time) | DB-level aggregation is efficient |
| Period date calculation | Custom logic | `_getStartDate()` already exists | Reuse existing method |

**Key insight:** All necessary patterns exist in the codebase. No new utilities needed.

## Common Pitfalls

### Pitfall 1: Null endTime values
**What goes wrong:** Active workouts have `endTime = null`, which breaks duration calculation
**Why it happens:** Workouts are created with only startTime, endTime set when completed
**How to avoid:** Filter with `AND end_time IS NOT NULL` in SQL query
**Warning signs:** Division errors or unexpectedly high totals

### Pitfall 2: Timestamp format mismatch
**What goes wrong:** SQLite stores timestamps as Unix seconds, but Drift DateTime may expect milliseconds
**Why it happens:** Different parts of the codebase handle this differently
**How to avoid:** Use `millisecondsSinceEpoch ~/ 1000` when passing to SQL, as existing code does
**Warning signs:** Dates far in the future or past

### Pitfall 3: Period selector callback
**What goes wrong:** Total time not updating when period changes
**Why it happens:** `_loadData()` must be called on period change
**How to avoid:** Period selector already calls `_loadData()` on change - no special handling needed
**Warning signs:** Stats stuck on old values

### Pitfall 4: AppSearch widget shared across features
**What goes wrong:** Removing menu breaks other usages
**Why it happens:** AppSearch is reused in multiple places
**How to avoid:** Add optional parameter instead of removing code; check all usages
**Warning signs:** Runtime errors in unmodified pages

## Code Examples

### Total Time Stat Card (match existing pattern)
```dart
// Source: lib/graph/overview_page.dart lines 613-622 (existing StatCard usage)
Expanded(
  child: StatCard(
    icon: Icons.schedule,  // or Icons.timer
    label: 'Total Time',
    value: _formatTotalTime(totalTimeSeconds),
    color: colorScheme.primary,  // Match existing card colors
  ),
),
```

### Duration Formatting for Total Time
```dart
// Matches context decision: "0h 0m" for zero, "Xh Ym" for hours
String _formatTotalTime(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return '${hours}h ${minutes}m';
}
```

### Hide Three-Dots Menu in AppSearch
```dart
// Source: lib/app_search.dart lines 125-231 (menu section)
// Add parameter: showMenu = true
// Wrap menu IconButton in conditional:
if (widget.showMenu)
  Badge.count(
    count: widget.selected.length,
    isLabelVisible: widget.selected.isNotEmpty,
    // ... existing menu code
  ),
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| N/A | StatCard widget | Already exists | Use existing pattern |
| N/A | Period selector + _loadData | Already exists | Reuse existing flow |

**Deprecated/outdated:**
- None - all patterns in this codebase are current

## Open Questions

1. **Stat card placement**
   - What we know: 4 existing stat cards in 2x2 grid (lines 596-654)
   - What's unclear: Add as 5th card (new row) or replace existing?
   - Recommendation: Add new row with Total Time card; context says "alongside existing"

2. **Menu usage verification**
   - What we know: AppSearch used in history_page.dart (lines 103 and 172)
   - What's unclear: Are there other usages not found in search?
   - Recommendation: Grep for `AppSearch(` to verify all usages before modifying

## Sources

### Primary (HIGH confidence)
- `/home/aquatic/Documents/JackedLog/lib/graph/overview_page.dart` - Overview page with stat cards and period selector
- `/home/aquatic/Documents/JackedLog/lib/widgets/stats/stat_card.dart` - StatCard widget implementation
- `/home/aquatic/Documents/JackedLog/lib/widgets/stats/period_selector.dart` - Period selector implementation
- `/home/aquatic/Documents/JackedLog/lib/app_search.dart` - AppSearch widget with three-dots menu
- `/home/aquatic/Documents/JackedLog/lib/sets/history_page.dart` - HistoryPage using AppSearch
- `/home/aquatic/Documents/JackedLog/lib/database/workouts.dart` - Workout table schema (startTime, endTime)

### Secondary (MEDIUM confidence)
- Duration formatting pattern verified across 4 files: `workouts_list.dart`, `workout_detail_page.dart`, `active_workout_bar.dart`, `rest_timer_bar.dart`

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH - Already exists in project
- Architecture: HIGH - Exact patterns exist in overview_page.dart
- Pitfalls: HIGH - Verified by reading actual implementation

**Research date:** 2026-02-02
**Valid until:** 2026-03-04 (stable patterns, 30 days)
