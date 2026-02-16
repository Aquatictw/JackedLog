# Phase 14: Dashboard Differentiators - Research

**Researched:** 2026-02-15
**Domain:** Server-rendered HTML dashboard pages with Chart.js (5/3/1 block history, bodyweight trends)
**Confidence:** HIGH

## Summary

This phase adds two specialized dashboard pages to the existing server-rendered web dashboard: a 5/3/1 block history page (DASH-11) and a bodyweight trend page (DASH-12). DASH-13 (weekday frequency) is dropped per user decision.

The existing dashboard infrastructure from Phase 13 provides everything needed: `dashboardShell()` layout function with sidebar navigation, CSS custom property theming, Chart.js v4 via CDN, and the `DashboardService` query layer using sqlite3 read-only database access. The new pages follow the exact same pattern -- Dart handler functions that query data, build HTML strings, and return `Response.ok(html)`. Two new query methods are needed in `DashboardService`: one for completed 5/3/1 blocks and one for bodyweight entries with period filtering.

The Flutter app implementations (`_CompletedBlockHistory`, `BlockSummaryPage`, `BodyweightOverviewPage`) serve as the definitive UI reference. The web versions replicate the same layout, stats, and chart styles using HTML/CSS/JS instead of Flutter widgets.

**Primary recommendation:** Add 2 new query methods to `DashboardService` (completed blocks, bodyweight entries), add 2 new page handler functions to `dashboard_pages.dart`, add 2 new nav items to the sidebar, and register 2 new routes in `server.dart`. All follow established Phase 13 patterns exactly.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shelf | 1.4.2 | HTTP server, routing | Already in server pubspec.yaml |
| shelf_router | 1.1.4 | URL routing with path params | Already in server pubspec.yaml |
| sqlite3 | 3.1.5 | Read-only backup DB queries | Already in server pubspec.yaml |
| Chart.js | 4.x (CDN) | Grouped bar chart (TM progression), line chart (bodyweight) | Already used by Phase 13 pages |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none) | - | All UI is vanilla HTML/CSS/JS | No additional dependencies |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inline expand/collapse | Separate detail page | User decided inline expand -- no separate page needed |
| Chart.js grouped bar | Separate charts per lift | Grouped bar is more compact and visually comparable |
| Server-side moving average | Client-side JS calculation | Server-side is simpler (no complex JS), data is already available; matches existing server-rendered pattern |

**Installation:** No new dependencies. Chart.js already loaded via CDN on pages that need charts.

## Architecture Patterns

### Recommended Project Structure
```
server/lib/
  api/
    dashboard_pages.dart       # (MODIFIED) add blockHistoryPageHandler, bodyweightPageHandler
  services/
    dashboard_service.dart     # (MODIFIED) add getCompletedBlocks(), getBodyweightEntries()
server/bin/
  server.dart                  # (MODIFIED) add 2 new routes
```

### Pattern 1: New Dashboard Page Handler (Established Pattern)
**What:** Each page is a Dart function that queries DashboardService, builds HTML via StringBuffer, wraps in `dashboardShell()`, returns `Response.ok()`.
**When to use:** Both new pages.
**Example:**
```dart
// Source: existing dashboard_pages.dart pattern (overviewPageHandler, exercisesPageHandler, etc.)
Response blockHistoryPageHandler(
  Request request,
  DashboardService dashboardService,
  String apiKey,
) {
  if (!dashboardService.isOpen) dashboardService.open();
  if (!dashboardService.isOpen) {
    // Return "no data" shell (same pattern as other handlers)
  }

  final blocks = dashboardService.getCompletedBlocks();
  // Build HTML content...

  final html = dashboardShell(
    title: '5/3/1 Blocks',
    activeNav: '5/3/1 Blocks',
    content: content,
    apiKey: apiKey,
    extraHead: '<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>',
    extraScripts: chartScript,
  );
  return Response.ok(html, headers: {'content-type': 'text/html'});
}
```

### Pattern 2: Card-Based List with Inline Expand/Collapse
**What:** Render block cards with summary info. Each card has a clickable header and a hidden detail section toggled by vanilla JS. No separate detail page.
**When to use:** 5/3/1 block history page.
**Example:**
```html
<!-- Card with expand/collapse -->
<div class="block-card" style="background:var(--surface);border:1px solid var(--border);border-radius:8px;margin-bottom:0.75rem;overflow:hidden">
  <div onclick="toggleBlock(1)" style="padding:1rem;cursor:pointer;display:flex;justify-content:space-between;align-items:center">
    <div>
      <div style="font-size:0.8rem;color:var(--text-muted)">Jan 5, 2026 - Feb 15, 2026</div>
      <div style="display:flex;gap:1rem;margin-top:0.5rem">
        <!-- 4 TM values in a row, same as app's _CompletedBlockHistory -->
        <div><span style="font-size:0.75rem;color:var(--text-muted)">Squat</span><br><b>200 kg</b></div>
        <div><span style="font-size:0.75rem;color:var(--text-muted)">Bench</span><br><b>120 kg</b></div>
        <!-- ... -->
      </div>
    </div>
    <span id="arrow-1" style="transition:transform 0.2s">&#9660;</span>
  </div>
  <div id="detail-1" style="display:none;padding:0 1rem 1rem;border-top:1px solid var(--border)">
    <!-- Expanded detail: per-lift TM progression with delta badges + cycle structure -->
  </div>
</div>

<script>
function toggleBlock(id) {
  const detail = document.getElementById('detail-' + id);
  const arrow = document.getElementById('arrow-' + id);
  const isHidden = detail.style.display === 'none';
  detail.style.display = isHidden ? 'block' : 'none';
  arrow.style.transform = isHidden ? 'rotate(180deg)' : '';
}
</script>
```

### Pattern 3: Bodyweight Line Chart with Moving Average Toggles
**What:** Chart.js line chart with main bodyweight line + 3 optional moving average datasets. Toggle buttons use `chart.setDatasetVisibility()` + `chart.update()`.
**When to use:** Bodyweight trend page.
**Example:**
```javascript
// Source: Chart.js v4 API docs (setDatasetVisibility)
const chart = new Chart(ctx, {
  type: 'line',
  data: {
    labels: dates,
    datasets: [
      { label: 'Bodyweight', data: weights, borderColor: '#7C3AED', tension: 0.35, fill: 'origin', pointRadius: 4 },
      { label: '14-Day MA', data: ma14, borderDash: [5, 5], borderColor: '#06B6D4', hidden: true, pointRadius: 0 },
      { label: '7-Day MA', data: ma7, borderDash: [5, 5], borderColor: '#10B981', hidden: true, pointRadius: 0 },
      { label: '3-Day MA', data: ma3, borderDash: [5, 5], borderColor: '#F59E0B', hidden: true, pointRadius: 0 },
    ]
  }
});

function toggleMA(index) {
  const meta = chart.getDatasetMeta(index);
  chart.setDatasetVisibility(index, meta.hidden);
  chart.update();
}
```

### Pattern 4: Period Selector via Query Parameters (Established)
**What:** Period changes are full page reloads with `?period=month` query parameter. Server re-renders with filtered data.
**When to use:** Bodyweight trend page period selector (7D/1M/3M/6M/1Y/All).
**Example:**
```dart
// Source: existing exerciseDetailHandler pattern
const periods = [
  ('7d', '7D'), ('1m', '1M'), ('3m', '3M'),
  ('6m', '6M'), ('1y', '1Y'), ('all', 'All'),
];
final periodButtons = StringBuffer();
for (final (value, label) in periods) {
  final isActive = value == currentPeriod;
  final bg = isActive ? 'background:var(--accent);color:#fff;' : 'background:var(--surface);color:var(--text);';
  periodButtons.write(
    '<a href="/dashboard/bodyweight?key=$apiKey&period=$value"'
    ' style="padding:0.4rem 0.75rem;border-radius:6px;text-decoration:none;font-size:0.8rem;border:1px solid var(--border);$bg">'
    '$label</a>');
}
```

### Anti-Patterns to Avoid
- **Separate detail page for block history:** User decided inline expand/collapse is sufficient. Do not create `/dashboard/block/<id>` route.
- **Client-side data fetching for moving averages:** Compute all moving average data server-side, embed as JSON. Do not add AJAX endpoints.
- **Computing moving averages in JavaScript:** The Dart server should compute the moving averages (same algorithm as `bodyweight_calculations.dart`) and send pre-computed arrays. Keep JS minimal.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Grouped bar chart | Custom SVG/canvas bars | Chart.js grouped bar (multiple datasets, same labels) | Tooltips, legends, responsive, animation built-in |
| Line chart with area fill | Custom SVG path generation | Chart.js line with `fill: 'origin'`, `tension: 0.35` | Gradient fill, touch tooltips, responsive built-in |
| Moving average calculation | New Dart algorithm from scratch | Port `calculateMovingAverage()` from `bodyweight_calculations.dart` | Calendar-day trailing window, already tested and correct |
| Dataset visibility toggle | Custom show/hide logic | `chart.setDatasetVisibility(index, visible)` + `chart.update()` | Chart.js built-in, handles animation |
| Period filtering | Custom date arithmetic | Reuse `DashboardService._periodToEpoch()` pattern | Already handles week/month/3m/6m/year/all |
| Delta badge coloring | Custom color logic | Same pattern as `BlockSummaryPage._LiftCard` (green/neutral/red) | Consistent with app |

**Key insight:** Both pages are web replications of existing Flutter pages. The logic, calculations, and layout decisions are already defined in the app code. Translate Flutter widgets to HTML/CSS, Dart widget state to server-side data, and fl_chart to Chart.js.

## Common Pitfalls

### Pitfall 1: Missing `five_three_one_blocks` Table in Old Backups
**What goes wrong:** Query fails with "no such table: five_three_one_blocks" on older backup files.
**Why it happens:** The table was added in a migration. Old exported backups from before the table existed won't have it.
**How to avoid:** Check if the table exists before querying: `SELECT name FROM sqlite_master WHERE type='table' AND name='five_three_one_blocks'`. If missing, show "No 5/3/1 data" message instead of crashing.
**Warning signs:** Server crash or 500 error when opening block history page.

### Pitfall 2: Null `start_*_tm` Values
**What goes wrong:** TM delta calculation produces NaN or wrong values.
**Why it happens:** The `start_squat_tm`, `start_bench_tm`, etc. columns are nullable. Blocks created before the start_tm columns were added have NULL values.
**How to avoid:** Use `COALESCE(start_squat_tm, squat_tm)` in SQL queries (or fallback in Dart), matching the app's pattern: `block.startSquatTm ?? block.squatTm`.
**Warning signs:** "NaN" displayed in delta badges.

### Pitfall 3: Bodyweight Entries Table May Not Exist
**What goes wrong:** Same as pitfall 1 but for `bodyweight_entries` table.
**Why it happens:** Table was added in a later migration.
**How to avoid:** Same table existence check pattern.
**Warning signs:** 500 error on bodyweight page.

### Pitfall 4: Moving Average with Insufficient Data Points
**What goes wrong:** 14-day moving average shows identical values to raw data when only a few entries exist.
**Why it happens:** With fewer entries than the window size, the moving average is computed over all available points, making it meaningless.
**How to avoid:** The app's `calculateMovingAverage()` handles this gracefully (computes average of whatever entries fall in the window). Replicate the same behavior. Optionally disable MA toggle buttons when entry count < window size.
**Warning signs:** MA line perfectly overlaps raw data line.

### Pitfall 5: Chart.js Gradient Requires chartArea
**What goes wrong:** Bodyweight chart gradient fill renders as solid color.
**Why it happens:** `chartArea` dimensions aren't available at initial render.
**How to avoid:** Use callback function for `backgroundColor`, same pattern as Phase 13 exercise detail chart.
**Warning signs:** Solid purple rectangle instead of gradient fade.

### Pitfall 6: Auth Key Not in New Nav Links
**What goes wrong:** Clicking "5/3/1 Blocks" or "Bodyweight" in sidebar returns 403.
**Why it happens:** New nav items in `dashboardShell()` don't include `?key=` parameter.
**How to avoid:** Add new nav items using the existing `navItem()` helper function inside `dashboardShell()`, which already handles key propagation.
**Warning signs:** Navigation to new pages fails immediately.

### Pitfall 7: Grouped Bar Chart Label Overlap
**What goes wrong:** Block labels (date ranges) overlap on x-axis when many blocks exist.
**Why it happens:** Long date strings like "Jan 5, 2026 - Feb 15, 2026" are too wide for bar chart labels.
**How to avoid:** Use short labels like "Block 1", "Block 2" or abbreviated dates like "Jan 5 - Feb 15". Rotate labels 45 degrees if needed. Or use block index numbers and show details in tooltip.
**Warning signs:** Unreadable x-axis.

## Code Examples

### DashboardService: getCompletedBlocks()
```dart
// Query completed 5/3/1 blocks from backup database
// Matches app's FiveThreeOneState.getCompletedBlocks() query
List<Map<String, dynamic>> getCompletedBlocks() {
  if (_db == null) return [];

  // Check table exists (may be missing in old backups)
  final tableCheck = _db!.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='five_three_one_blocks'",
  );
  if (tableCheck.isEmpty) return [];

  final result = _db!.select('''
    SELECT id, created, completed,
      squat_tm, bench_tm, deadlift_tm, press_tm,
      COALESCE(start_squat_tm, squat_tm) as start_squat_tm,
      COALESCE(start_bench_tm, bench_tm) as start_bench_tm,
      COALESCE(start_deadlift_tm, deadlift_tm) as start_deadlift_tm,
      COALESCE(start_press_tm, press_tm) as start_press_tm,
      unit, current_cycle
    FROM five_three_one_blocks
    WHERE is_active = 0 AND completed IS NOT NULL
    ORDER BY completed DESC
  ''');

  return result.map((row) => <String, dynamic>{
    'id': row['id'],
    'created': row['created'],
    'completed': row['completed'],
    'squatTm': (row['squat_tm'] as num).toDouble(),
    'benchTm': (row['bench_tm'] as num).toDouble(),
    'deadliftTm': (row['deadlift_tm'] as num).toDouble(),
    'pressTm': (row['press_tm'] as num).toDouble(),
    'startSquatTm': (row['start_squat_tm'] as num).toDouble(),
    'startBenchTm': (row['start_bench_tm'] as num).toDouble(),
    'startDeadliftTm': (row['start_deadlift_tm'] as num).toDouble(),
    'startPressTm': (row['start_press_tm'] as num).toDouble(),
    'unit': row['unit'],
    'currentCycle': row['current_cycle'],
  }).toList();
}
```

### DashboardService: getBodyweightEntries()
```dart
// Query bodyweight entries with period filtering
// Matches app's BodyweightOverviewPage data loading
Map<String, dynamic> getBodyweightEntries({String? period}) {
  if (_db == null) return {'entries': <Map<String, dynamic>>[], 'stats': {}};

  // Check table exists
  final tableCheck = _db!.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='bodyweight_entries'",
  );
  if (tableCheck.isEmpty) return {'entries': <Map<String, dynamic>>[], 'stats': {}};

  final startEpoch = _periodToEpochMs(period); // Note: bodyweight dates are stored differently

  final result = _db!.select('''
    SELECT id, weight, unit, date, notes
    FROM bodyweight_entries
    WHERE date >= ?
    ORDER BY date ASC
  ''', [startEpoch]);

  final entries = result.map((row) => <String, dynamic>{
    'id': row['id'],
    'weight': (row['weight'] as num).toDouble(),
    'unit': row['unit'],
    'date': row['date'],
    'notes': row['notes'],
  }).toList();

  // Calculate stats server-side (matching app's calculations)
  final weights = entries.map((e) => e['weight'] as double).toList();
  final stats = <String, dynamic>{};
  if (weights.isNotEmpty) {
    stats['current'] = weights.last;
    stats['average'] = weights.reduce((a, b) => a + b) / weights.length;
    stats['change'] = weights.length >= 2 ? weights.last - weights.first : null;
    stats['entries'] = weights.length;
  }

  return {'entries': entries, 'stats': stats};
}
```

### Moving Average Calculation (Server-Side Dart)
```dart
// Port of bodyweight_calculations.dart calculateMovingAverage
// Uses calendar-day trailing window, not entry-count window
List<double?> calculateMovingAverage(
  List<Map<String, dynamic>> entries,
  int windowDays,
) {
  if (entries.isEmpty) return [];

  final result = <double?>[];
  for (int i = 0; i < entries.length; i++) {
    final currentDate = DateTime.fromMillisecondsSinceEpoch(
      entries[i]['date'] as int,
    );
    final windowStart = currentDate.subtract(Duration(days: windowDays - 1));

    final windowEntries = entries.where((e) {
      final d = DateTime.fromMillisecondsSinceEpoch(e['date'] as int);
      return !d.isBefore(windowStart) && !d.isAfter(currentDate);
    }).toList();

    if (windowEntries.isNotEmpty) {
      final sum = windowEntries.fold<double>(
        0, (s, e) => s + (e['weight'] as double),
      );
      result.add(sum / windowEntries.length);
    } else {
      result.add(null);
    }
  }
  return result;
}
```

### Chart.js: Grouped Bar Chart for TM Progression
```javascript
// TM progression across blocks: grouped bars (start vs end) for each lift
// Source: Chart.js v4 docs - bar chart with multiple datasets
const blocks = JSON.parse(document.getElementById('blocks-data').textContent);
const labels = blocks.map((b, i) => 'Block ' + (blocks.length - i));

new Chart(document.getElementById('tmChart'), {
  type: 'bar',
  data: {
    labels: labels,
    datasets: [
      { label: 'Squat', data: blocks.map(b => b.squatTm), backgroundColor: 'rgba(239,68,68,0.7)', borderRadius: 4 },
      { label: 'Bench', data: blocks.map(b => b.benchTm), backgroundColor: 'rgba(59,130,246,0.7)', borderRadius: 4 },
      { label: 'Deadlift', data: blocks.map(b => b.deadliftTm), backgroundColor: 'rgba(34,197,94,0.7)', borderRadius: 4 },
      { label: 'OHP', data: blocks.map(b => b.pressTm), backgroundColor: 'rgba(249,115,22,0.7)', borderRadius: 4 },
    ]
  },
  options: {
    responsive: true,
    plugins: { legend: { labels: { color: textColor } } },
    scales: {
      x: { ticks: { color: textColor }, grid: { display: false } },
      y: { ticks: { color: textColor }, grid: { color: gridColor }, beginAtZero: false }
    }
  }
});
```

### Chart.js: Bodyweight Line with Moving Average Toggles
```javascript
// Source: Chart.js v4 API docs (setDatasetVisibility, hide/show)
const bwData = JSON.parse(document.getElementById('bw-data').textContent);
const labels = bwData.dates;
const weights = bwData.weights;
const ma3 = bwData.ma3;
const ma7 = bwData.ma7;
const ma14 = bwData.ma14;

const bwChart = new Chart(document.getElementById('bwChart'), {
  type: 'line',
  data: {
    labels: labels,
    datasets: [
      {
        label: 'Bodyweight',
        data: weights,
        borderColor: '#7C3AED',
        borderWidth: 3,
        tension: 0.35,
        pointRadius: 4,
        pointBackgroundColor: '#7C3AED',
        fill: 'origin',
        backgroundColor: function(context) {
          const chart = context.chart;
          const {ctx, chartArea} = chart;
          if (!chartArea) return 'rgba(124,58,237,0.1)';
          const gradient = ctx.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
          gradient.addColorStop(0, 'rgba(124,58,237,0.3)');
          gradient.addColorStop(1, 'rgba(124,58,237,0.02)');
          return gradient;
        }
      },
      {
        label: '14-Day MA',
        data: ma14,
        borderColor: '#06B6D4',
        borderDash: [5, 5],
        borderWidth: 2,
        pointRadius: 0,
        fill: false,
        hidden: true
      },
      {
        label: '7-Day MA',
        data: ma7,
        borderColor: '#10B981',
        borderDash: [5, 5],
        borderWidth: 2,
        pointRadius: 0,
        fill: false,
        hidden: true
      },
      {
        label: '3-Day MA',
        data: ma3,
        borderColor: '#F59E0B',
        borderDash: [5, 5],
        borderWidth: 2,
        pointRadius: 0,
        fill: false,
        hidden: true
      }
    ]
  },
  options: {
    responsive: true,
    plugins: { legend: { display: false } },
    scales: {
      x: { ticks: { color: textColor, maxTicksLimit: 8 }, grid: { display: false } },
      y: { ticks: { color: textColor }, grid: { color: gridColor } }
    }
  }
});

// Toggle moving average visibility from custom buttons
function toggleMA(datasetIndex) {
  const meta = bwChart.getDatasetMeta(datasetIndex);
  bwChart.setDatasetVisibility(datasetIndex, meta.hidden);
  bwChart.update();
  // Update button visual state
  const btn = document.getElementById('ma-btn-' + datasetIndex);
  btn.classList.toggle('active');
}
```

### Block Card Expanded Detail (Matching BlockSummaryPage)
```html
<!-- Expanded detail section per block, matching app's BlockSummaryPage layout -->
<div id="detail-1" style="display:none;padding:1rem;border-top:1px solid var(--border)">
  <!-- Per-lift TM progression with delta badges -->
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:0.75rem">
    <div style="background:var(--surface-elevated);border-radius:8px;padding:0.75rem;display:flex;justify-content:space-between;align-items:center">
      <div>
        <div style="font-weight:600;font-size:0.9rem">Squat</div>
        <div style="font-size:0.85rem;color:var(--text-muted)">180 &rarr; 189 kg</div>
      </div>
      <!-- Delta badge: green for positive, red for negative, muted for zero -->
      <span style="padding:0.15rem 0.5rem;background:rgba(34,197,94,0.15);color:#22C55E;border-radius:12px;font-size:0.8rem;font-weight:600">+9</span>
    </div>
    <!-- ... repeat for Bench, Deadlift, OHP ... -->
  </div>
  <!-- Cycle structure labels -->
  <div style="margin-top:0.75rem;font-size:0.8rem;color:var(--text-muted)">
    <span style="display:inline-block;padding:0.15rem 0.4rem;background:var(--surface-elevated);border-radius:4px;margin:0.15rem">Leader 1</span>
    <span>&rarr;</span>
    <span style="display:inline-block;padding:0.15rem 0.4rem;background:var(--surface-elevated);border-radius:4px;margin:0.15rem">Leader 2</span>
    <span>&rarr;</span>
    <span style="display:inline-block;padding:0.15rem 0.4rem;background:var(--surface-elevated);border-radius:4px;margin:0.15rem">7th Week</span>
    <span>&rarr;</span>
    <span style="display:inline-block;padding:0.15rem 0.4rem;background:var(--surface-elevated);border-radius:4px;margin:0.15rem">Anchor</span>
    <span>&rarr;</span>
    <span style="display:inline-block;padding:0.15rem 0.4rem;background:var(--surface-elevated);border-radius:4px;margin:0.15rem">7th Week</span>
  </div>
</div>
```

### Sidebar Navigation Update
```dart
// Add new nav items to dashboardShell() navItem list
// Must use existing navItem() helper which handles ?key= propagation
${navItem('5/3/1 Blocks', '/dashboard/blocks', '<svg ...>')}
${navItem('Bodyweight', '/dashboard/bodyweight', '<svg ...>')}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Chart.js v2 legend click to toggle | `setDatasetVisibility()` + `update()` | Chart.js v3+ | More predictable programmatic control |
| Chart.js `hidden: true` on dataset | Same, but also `setDatasetVisibility()` API | Chart.js v3+ | Both work; `hidden: true` for initial state, API for runtime toggle |

**Deprecated/outdated:**
- Chart.js v2 `chart.getDatasetMeta(i).hidden = true` still works but `setDatasetVisibility()` is the recommended v4 API

## Open Questions

1. **Bodyweight date storage format**
   - What we know: The Drift table uses `DateTimeColumn`, which stores as integer (milliseconds since epoch in Drift's default). The app queries with `isBiggerOrEqualValue(startDate)`.
   - What's unclear: Whether the backup DB stores dates as milliseconds (Drift default) or seconds (like `gym_sets.created`). The `bodyweight_entries` table was created through Drift, so it likely uses milliseconds.
   - Recommendation: Check the actual data format in the first implementation task. The query needs to use the correct epoch unit. If milliseconds, use `_periodToEpoch(period) * 1000` for the WHERE clause. If seconds (like workouts), use `_periodToEpoch(period)`.

2. **Number of blocks to show in TM progression chart**
   - What we know: The app shows all completed blocks in a scrollable list. The web chart has limited horizontal space.
   - What's unclear: If a user has 20+ completed blocks, the grouped bar chart may become unreadable.
   - Recommendation: Show all blocks in the card list (scrollable), but limit the TM progression chart to the most recent 10 blocks. Add a note "Showing last 10 blocks" if truncated.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `server/lib/api/dashboard_pages.dart` - Established page handler pattern, `dashboardShell()` function, `navItem()` helper, Chart.js integration
- Existing codebase: `server/lib/services/dashboard_service.dart` - Query layer pattern, `_periodToEpoch()`, table existence checks
- Existing codebase: `lib/fivethreeone/block_overview_page.dart` - `_CompletedBlockHistory` widget (card layout reference)
- Existing codebase: `lib/fivethreeone/block_summary_page.dart` - `_LiftCard` widget (delta badge pattern, TM progression display)
- Existing codebase: `lib/fivethreeone/schemes.dart` - `cycleNames` list, cycle constants (0-4)
- Existing codebase: `lib/graph/bodyweight_overview_page.dart` - Period selector, stats grid, chart config, MA toggles
- Existing codebase: `lib/utils/bodyweight_calculations.dart` - `calculateMovingAverage()` algorithm (calendar-day trailing window)
- Existing codebase: `lib/database/fivethreeone_blocks.dart` - Table schema with nullable start_*_tm columns
- Existing codebase: `lib/database/bodyweight_entries.dart` - Table schema (id, weight, unit, date, notes)

### Secondary (MEDIUM confidence)
- [Chart.js API docs](https://www.chartjs.org/docs/latest/developers/api.html) - `setDatasetVisibility()`, `show()`, `hide()`, `update()` methods verified
- [Chart.js Bar Chart docs](https://www.chartjs.org/docs/latest/charts/bar.html) - Grouped bar chart with multiple datasets, `grouped: true` default confirmed
- [Chart.js Line Chart docs](https://www.chartjs.org/docs/latest/charts/line.html) - `tension`, `borderDash`, `fill`, `pointRadius` properties confirmed

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies; extending existing Phase 13 infrastructure
- Architecture: HIGH - All patterns directly copied from existing dashboard_pages.dart handlers
- Pitfalls: HIGH - Based on direct codebase analysis (nullable columns, missing tables, auth propagation)
- Code examples: HIGH - Based on existing app code and verified Chart.js API

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (stable - extending existing patterns, no new libraries)
