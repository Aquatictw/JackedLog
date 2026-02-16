# Phase 12: Dashboard Query Layer - Research

**Researched:** 2026-02-15
**Domain:** Server-side SQLite querying (Dart, sqlite3 package, raw SQL)
**Confidence:** HIGH

## Summary

This phase adds internal Dart query functions to the server that open uploaded SQLite backup files in read-only mode and execute SQL queries to extract dashboard analytics. The server already uses the `sqlite3` package (v3.1.5) for backup validation (`sqlite_validator.dart`), so the same library and pattern extends naturally to query execution.

The app's existing query logic lives primarily in `lib/database/gym_sets.dart` and `lib/graph/overview_page.dart`. These files contain the exact SQL patterns for all required stats: workout count, total volume, current streak, training time, personal records (1RM/weight/volume), rep records (1-15), and workout history with pagination. The server query layer must replicate these SQL queries using the raw `sqlite3` package (not Drift ORM, which is a Flutter dependency).

**Primary recommendation:** Create a `DashboardService` in `server/lib/services/` that opens a backup's SQLite file in read-only mode, validates schema version >= 48, and exposes pure Dart functions for each query category. Translate the app's Drift-based queries to raw SQL using the `Database.select()` method from the `sqlite3` package.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| sqlite3 | 3.1.5 | Open and query SQLite backup files | Already in server's pubspec.yaml, used by sqlite_validator.dart |
| shelf | 1.4.2 | HTTP server framework | Already in server's pubspec.yaml |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none needed) | - | - | All queries use raw sqlite3 package already present |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw sqlite3 | Drift ORM on server | Drift pulls in Flutter dependencies; raw SQL is simpler for read-only queries and matches the phase's needs perfectly |

**Installation:** No new dependencies required. The server already has `sqlite3: ^3.1.5` in pubspec.yaml.

## Architecture Patterns

### Recommended Project Structure
```
server/lib/
├── services/
│   ├── backup_service.dart        # (existing) File storage and management
│   ├── sqlite_validator.dart      # (existing) Schema validation
│   └── dashboard_service.dart     # (NEW) Query layer - all dashboard queries
├── api/                           # (existing) HTTP handlers
├── middleware/                    # (existing) Auth, CORS
└── config.dart                   # (existing) Environment config
```

### Pattern 1: Service Layer with Database Handle Lifecycle
**What:** A `DashboardService` class that opens a backup file read-only, validates schema, caches the handle, and provides query methods.
**When to use:** Always - this is the single entry point for all dashboard data.
**Example:**
```dart
// Source: Existing sqlite_validator.dart pattern + sqlite3 package docs
import 'package:sqlite3/sqlite3.dart';

class DashboardService {
  final String dataDir;
  Database? _db;
  String? _currentFile;

  DashboardService(this.dataDir);

  /// Open the latest (or specified) backup file in read-only mode.
  /// Returns false if no backup exists or schema version < 48.
  bool open({String? filename}) {
    close(); // Close any previously opened database
    final file = filename ?? _findLatestBackup();
    if (file == null) return false;

    final db = sqlite3.open(file, mode: OpenMode.readOnly);
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version < 48) {
      db.close();
      return false;
    }
    _db = db;
    _currentFile = file;
    return true;
  }

  void close() {
    _db?.close();
    _db = null;
    _currentFile = null;
  }

  // Query methods follow...
}
```

### Pattern 2: Raw SQL Queries Matching App Patterns
**What:** Each query function translates the app's Drift ORM queries into raw SQL using `Database.select()`.
**When to use:** For every data retrieval function.
**Example:**
```dart
// App uses Drift: db.customSelect('SELECT COUNT(DISTINCT w.id) ...')
// Server uses raw sqlite3: _db!.select('SELECT COUNT(DISTINCT w.id) ...')

Map<String, dynamic> getOverviewStats({String? period}) {
  final startEpoch = _periodToEpoch(period);
  final workoutCount = _db!.select(
    'SELECT COUNT(DISTINCT id) as c FROM workouts WHERE start_time >= ?',
    [startEpoch],
  ).first['c'] as int;
  // ...
}
```

### Pattern 3: Return Plain Maps/Records (Not Drift Types)
**What:** Query functions return plain Dart Maps, Lists, or Records - not Drift-generated types.
**When to use:** Always - the server doesn't use Drift, and Phase 13 will render HTML from these values.
**Example:**
```dart
typedef OverviewStats = ({
  int workoutCount,
  double totalVolume,
  int currentStreak,
  int totalTimeSeconds,
});
```

### Anti-Patterns to Avoid
- **Using Drift on the server:** Drift is a Flutter ORM. The server uses raw `sqlite3` package. Do not add Drift as a server dependency.
- **Keeping database handles open indefinitely:** Always close previous handles before opening a new backup. Use try/finally patterns.
- **Mutating the backup database:** Always open in `OpenMode.readOnly`. Never write to backup files.
- **Duplicating SQL with drift:** Copy the raw SQL strings from the app's `customSelect` calls, not the Drift query builder syntax.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQLite access | Custom FFI bindings | `sqlite3` package (already installed) | Battle-tested, handles memory management |
| Schema validation | Version parsing logic | `PRAGMA user_version` (already in sqlite_validator.dart) | Standard SQLite pragma |
| 1RM calculation | Custom formula | Brzycki formula: `weight / (1.0278 - 0.0278 * reps)` (already in gym_sets.dart) | Standard formula, must match app exactly |
| Period date math | Custom epoch calculation | Dart's DateTime arithmetic converted to Unix epoch seconds | App uses `millisecondsSinceEpoch ~/ 1000` pattern |

**Key insight:** The entire query layer is a translation exercise - take existing app SQL, paste it into raw `sqlite3.select()` calls. Do not invent new calculations.

## Common Pitfalls

### Pitfall 1: Epoch Timestamp Mismatch
**What goes wrong:** App stores `created` as Unix epoch seconds (not milliseconds). Queries that compare dates must use seconds.
**Why it happens:** Dart's `DateTime.millisecondsSinceEpoch` returns milliseconds, but the database stores seconds.
**How to avoid:** Always divide by 1000: `startDate.millisecondsSinceEpoch ~/ 1000`. The app code consistently does this (see overview_page.dart line 85, 103, 137).
**Warning signs:** Query returns zero results when data clearly exists.

### Pitfall 2: Missing hidden=0 Filter
**What goes wrong:** Queries return deleted/hidden sets, inflating counts and volume.
**Why it happens:** The `hidden` column defaults to false but can be true for soft-deleted sets.
**How to avoid:** Every query on `gym_sets` MUST include `AND hidden = 0` (or `AND gs.hidden = 0`). The app does this consistently.
**Warning signs:** Dashboard numbers are higher than app shows.

### Pitfall 3: workout_id NULL for Pre-v48 Data
**What goes wrong:** Old gym_sets entries (before workouts table existed) have `workout_id = NULL`.
**Why it happens:** The `workouts` table was added in schema v48. Sets created before the migration don't have workout associations.
**How to avoid:** Schema version >= 48 is already required. But within valid databases, some older sets may still have NULL workout_id. Workout-based queries should handle this with `WHERE workout_id IS NOT NULL`.
**Warning signs:** Workout count doesn't match set data, or joins produce fewer results than expected.

### Pitfall 4: Streak Logic - Must Check from Today Backwards
**What goes wrong:** Streak calculation skips today or counts non-consecutive days.
**Why it happens:** The streak algorithm walks backwards from today checking each day for a workout.
**How to avoid:** Replicate the exact algorithm from overview_page.dart `_calculateStreak()`: start at today, check each day, increment streak, stop at first gap. Use `DATE(w.start_time, 'unixepoch') = ?` pattern.
**Warning signs:** Streak of 0 when user worked out today, or streak > 1 with gaps.

### Pitfall 5: Volume Includes All Sets (Including Bodyweight)
**What goes wrong:** Volume numbers differ from app because the app's overview includes ALL sets in the volume sum per category (including zero-weight), not just weighted.
**Why it happens:** The context says "skip bodyweight/zero-weight sets" but the actual app SQL in overview_page.dart does `SUM(gs.weight * gs.reps)` with only `hidden = 0 AND category IS NOT NULL AND cardio = 0` filters. Zero-weight sets contribute 0 to the sum naturally.
**How to avoid:** Match the app's exact SQL. The `SUM(weight * reps)` formula handles zero-weight sets correctly (they add 0). The real filter is `cardio = 0` to exclude cardio exercises from volume.
**Warning signs:** Volume numbers slightly differ from app.

### Pitfall 6: Database Handle Leak
**What goes wrong:** Opening multiple databases without closing previous ones leaks file descriptors.
**Why it happens:** Each `sqlite3.open()` creates a native handle that must be explicitly closed.
**How to avoid:** Always call `close()` on the previous handle before opening a new one. Use try/finally in the open method.
**Warning signs:** Server crashes after many backup switches, or "too many open files" error.

### Pitfall 7: Training Time Uses Epoch Seconds Difference
**What goes wrong:** Training time calculation produces enormous numbers.
**Why it happens:** The `start_time` and `end_time` in the workouts table are stored as Unix epoch seconds. The app's SQL does `SUM(end_time - start_time)` which gives seconds directly.
**How to avoid:** Use the exact SQL from overview_page.dart: `COALESCE(SUM(end_time - start_time), 0) as total_seconds FROM workouts WHERE start_time >= ? AND end_time IS NOT NULL`.
**Warning signs:** Training time shows years instead of hours.

## Code Examples

Verified patterns from the existing codebase (all HIGH confidence - direct code reading):

### Opening a Backup Read-Only (from sqlite_validator.dart)
```dart
// Source: server/lib/services/sqlite_validator.dart
import 'package:sqlite3/sqlite3.dart';

final db = sqlite3.open(filePath, mode: OpenMode.readOnly);
final version = db.select('PRAGMA user_version').first.values.first as int;
// ... use db.select() for queries ...
db.close();
```

### Workout Count (from overview_page.dart)
```dart
// Source: lib/graph/overview_page.dart lines 149-158
// App SQL:
//   SELECT COUNT(DISTINCT w.id) as workout_count
//   FROM workouts w
//   WHERE w.start_time >= ?
// Parameter: startDate.millisecondsSinceEpoch ~/ 1000

// Server equivalent:
final result = db.select(
  'SELECT COUNT(DISTINCT id) as workout_count FROM workouts WHERE start_time >= ?',
  [startEpochSeconds],
);
final workoutCount = result.first['workout_count'] as int;
```

### Total Volume (from overview_page.dart)
```dart
// Source: lib/graph/overview_page.dart lines 71-87
// App SQL:
//   SELECT gs.category as muscle, SUM(gs.weight * gs.reps) as total_volume
//   FROM gym_sets gs
//   WHERE gs.created >= ? AND gs.hidden = 0
//     AND gs.category IS NOT NULL AND gs.cardio = 0
//   GROUP BY gs.category ORDER BY total_volume DESC
// Total volume = sum of all category volumes

// For dashboard overview, simplified total (no grouping needed):
final result = db.select('''
  SELECT COALESCE(SUM(weight * reps), 0) as total_volume
  FROM gym_sets
  WHERE created >= ? AND hidden = 0 AND cardio = 0
''', [startEpochSeconds]);
final totalVolume = (result.first['total_volume'] as num).toDouble();
```

### Current Streak (from overview_page.dart)
```dart
// Source: lib/graph/overview_page.dart lines 250-278
// Algorithm: Walk backwards from today, check each day for any workout

int calculateStreak(Database db) {
  int streak = 0;
  final now = DateTime.now();
  var checkDate = DateTime(now.year, now.month, now.day);

  while (true) {
    final dateStr = '${checkDate.year.toString().padLeft(4, '0')}-'
        '${checkDate.month.toString().padLeft(2, '0')}-'
        '${checkDate.day.toString().padLeft(2, '0')}';

    final result = db.select(
      "SELECT COUNT(*) as count FROM workouts WHERE DATE(start_time, 'unixepoch') = ?",
      [dateStr],
    );

    if ((result.first['count'] as int) > 0) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  return streak;
}
```

### Training Time (from overview_page.dart)
```dart
// Source: lib/graph/overview_page.dart lines 163-175
// App SQL:
//   SELECT COALESCE(SUM(end_time - start_time), 0) as total_seconds
//   FROM workouts
//   WHERE start_time >= ? AND end_time IS NOT NULL

final result = db.select('''
  SELECT COALESCE(SUM(end_time - start_time), 0) as total_seconds
  FROM workouts
  WHERE start_time >= ? AND end_time IS NOT NULL
''', [startEpochSeconds]);
final totalSeconds = result.first['total_seconds'] as int;
```

### Exercise Records - 3 PRs (from gym_sets.dart)
```dart
// Source: lib/database/gym_sets.dart lines 574-659
// App SQL for best values:
//   SELECT MAX(weight) as best_weight,
//     MAX(CASE WHEN weight >= 0 THEN weight / (1.0278 - 0.0278 * reps)
//         ELSE weight * (1.0278 - 0.0278 * reps) END) as best_1rm,
//     MAX(weight * reps) as best_volume
//   FROM gym_sets WHERE name = ? AND hidden = 0
// Then separate queries for dates/workout_ids of each record

final result = db.select('''
  SELECT
    MAX(weight) as best_weight,
    MAX(CASE WHEN weight >= 0 THEN weight / (1.0278 - 0.0278 * reps)
        ELSE weight * (1.0278 - 0.0278 * reps) END) as best_1rm,
    MAX(weight * reps) as best_volume
  FROM gym_sets WHERE name = ? AND hidden = 0
''', [exerciseName]);
```

### Rep Records 1-15 (from gym_sets.dart)
```dart
// Source: lib/database/gym_sets.dart lines 511-553
// App SQL:
//   SELECT CAST(reps AS INTEGER) as rep_count, MAX(weight) as max_weight,
//     created, unit, workout_id
//   FROM gym_sets
//   WHERE name = ? AND hidden = 0 AND reps BETWEEN 1 AND 15
//     AND reps = CAST(reps AS INTEGER)
//   GROUP BY CAST(reps AS INTEGER)
//   ORDER BY rep_count ASC

final results = db.select('''
  SELECT CAST(reps AS INTEGER) as rep_count,
    MAX(weight) as max_weight, created, unit, workout_id
  FROM gym_sets
  WHERE name = ? AND hidden = 0
    AND reps BETWEEN 1 AND 15
    AND reps = CAST(reps AS INTEGER)
  GROUP BY CAST(reps AS INTEGER)
  ORDER BY rep_count ASC
''', [exerciseName]);
```

### Workout History with Pagination (from workouts_list.dart)
```dart
// Source: lib/workouts/workouts_list.dart lines 79-158
// App loads workouts ordered by start_time DESC with limit
// Then for each workout, loads gym_sets to get exercise names, set count, volume

// Server simplified SQL (join approach for efficiency):
final workouts = db.select('''
  SELECT w.id, w.start_time, w.end_time, w.name, w.notes,
    COUNT(DISTINCT gs.name) as exercise_count,
    COUNT(gs.id) as set_count,
    COALESCE(SUM(gs.weight * gs.reps), 0) as total_volume
  FROM workouts w
  LEFT JOIN gym_sets gs ON w.id = gs.workout_id AND gs.hidden = 0 AND gs.sequence >= 0
  GROUP BY w.id
  ORDER BY w.start_time DESC
  LIMIT ? OFFSET ?
''', [pageSize, offset]);
```

### Workout Detail (from workout_detail_page.dart)
```dart
// Source: lib/workouts/workout_detail_page.dart lines 55-69
// App loads all gym_sets for a workout_id, ordered by sequence then setOrder

final sets = db.select('''
  SELECT * FROM gym_sets
  WHERE workout_id = ? AND hidden = 0 AND sequence >= 0
  ORDER BY sequence, COALESCE(set_order, created)
''', [workoutId]);
```

### Exercise Search and Category Filter (from gym_sets.dart)
```dart
// Source: lib/database/gym_sets.dart lines 354-361 (getCategories)
// and watchGraphs (lines 187-244)

// Get all categories:
final categories = db.select('''
  SELECT DISTINCT category FROM gym_sets
  WHERE category IS NOT NULL AND hidden = 0
  ORDER BY category
''');

// Search exercises by name with optional category filter:
final exercises = db.select('''
  SELECT name, category, MAX(created) as last_used,
    COUNT(*) as set_count, COUNT(DISTINCT workout_id) as workout_count
  FROM gym_sets
  WHERE hidden = 0
    AND name LIKE ?
    ${category != null ? 'AND category = ?' : ''}
  GROUP BY name
  ORDER BY workout_count DESC
''', [
  '%$search%',
  if (category != null) category,
]);
```

### Period Start Epoch Calculation
```dart
// Source: lib/graph/overview_page.dart lines 546-561

int? periodToEpoch(String? period) {
  if (period == null || period == 'all') return 0;
  final now = DateTime.now();
  DateTime start;
  switch (period) {
    case 'week':
      start = now.subtract(const Duration(days: 7));
    case 'month':
      start = DateTime(now.year, now.month - 1, now.day);
    case 'year':
      start = DateTime(now.year - 1, now.month, now.day);
    default:
      return 0; // all-time
  }
  return start.millisecondsSinceEpoch ~/ 1000;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No workouts table | workouts table with start_time/end_time | Schema v48 | Workout-based queries require v48+ |
| No workout_id on sets | workout_id FK on gym_sets | Schema v48 | Can now join workouts to sets |
| Sets ordered by created | sequence + set_order columns | Schema v48/v57/v61 | Proper exercise grouping within workouts |
| No exercise metadata | category, exerciseType, brandName columns | Schema v52 | Category filtering now possible |

**Deprecated/outdated:**
- Schema < 48 cannot be queried for workouts (no workouts table). This is why minimum v48 was chosen.

## Open Questions

1. **Unit conversion on server**
   - What we know: App queries include unit conversion logic (lb/kg). The gym_sets `unit` column stores the unit per set.
   - What's unclear: Should the server convert units to a target unit, or return raw values with the unit field and let the frontend handle it?
   - Recommendation: Return raw values with unit field. Phase 13 (frontend) can format. Keep query layer simple.

2. **Backup file caching**
   - What we know: The server is single-user. Opening a new sqlite3 handle per request is cheap (milliseconds).
   - What's unclear: Should we keep the database handle open between requests, or open/close per request?
   - Recommendation: Open once per backup selection, keep handle cached until a new backup is selected or server restarts. Close on `DashboardService.close()`. This avoids repeated file I/O.

3. **Volume definition - "skip bodyweight/zero-weight"**
   - What we know: The context says "skip bodyweight/zero-weight sets" but the app SQL does `SUM(weight * reps)` which naturally gives 0 for zero-weight sets. The filter is `cardio = 0`.
   - What's unclear: Should we explicitly exclude `weight = 0` sets or let `SUM(weight * reps)` handle it?
   - Recommendation: Match app exactly - use `SUM(weight * reps)` with `cardio = 0` filter. Zero-weight sets contribute 0 naturally.

## Sources

### Primary (HIGH confidence)
- `server/lib/services/sqlite_validator.dart` - Existing pattern for opening SQLite in read-only mode
- `server/pubspec.yaml` - sqlite3 ^3.1.5 already installed
- `lib/database/gym_sets.dart` - All exercise query SQL patterns (1RM formula, rep records, exercise records, strength data)
- `lib/graph/overview_page.dart` - Overview stats SQL (workout count, volume, streak, training time)
- `lib/workouts/workouts_list.dart` - Workout history list with pagination pattern
- `lib/workouts/workout_detail_page.dart` - Workout detail query pattern
- `lib/records/records_service.dart` - PR detection logic (Brzycki formula, record types)
- `lib/database/database.dart` - Schema version 66, migration history, table definitions
- `lib/database/workouts.dart` - Workouts table schema
- `lib/database/settings.dart` - Settings table schema (strengthUnit, cardioUnit)

### Secondary (MEDIUM confidence)
- pub.dev/packages/sqlite3 v3.1.5 - `Database.select()` method, `OpenMode.readOnly` enum

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - sqlite3 already installed and proven in validator
- Architecture: HIGH - Follows existing server patterns, clear translation from app SQL
- Pitfalls: HIGH - All identified from direct codebase reading, verified against actual SQL

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (stable - no external dependencies changing)
