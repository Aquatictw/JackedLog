# Phase 13: Dashboard Frontend - Research

**Researched:** 2026-02-15
**Domain:** Server-rendered HTML dashboard with Chart.js, vanilla CSS/JS, Dart Shelf
**Confidence:** HIGH

## Summary

This phase builds the server-rendered web dashboard frontend. The server already has Shelf routing, API key auth (query parameter for HTML pages), and a complete DashboardService with 9 query methods from Phase 12. The manage page (`manage_page.dart`) establishes the pattern: a single handler function returns `Response.ok(html, headers: {'content-type': 'text/html'})` with inline HTML/CSS/JS. No build step, no framework.

The dashboard needs Chart.js v4.x (CDN) for bar charts and line charts, hand-built SVG for the heatmap, and vanilla CSS for responsive layout with sidebar/hamburger. The existing DashboardService covers overview stats, workout history/detail, exercise records, rep records, exercise search, and category filter. However, it is **missing** three query methods required by Phase 13: training heatmap data, muscle group volume aggregation, and muscle group set count aggregation. The exercise progress chart data (best weight / 1RM / volume over time) is also missing. These queries must be added to DashboardService before (or as part of) frontend rendering.

**Primary recommendation:** Add 4 missing query methods to DashboardService (heatmap days, muscle volumes, muscle set counts, exercise progress), then build server-rendered HTML pages following the existing `manage_page.dart` pattern. Use Chart.js 4.x via CDN for bar/line charts, inline SVG for heatmap, CSS Grid/Flexbox for responsive layout, and CSS custom properties for dark/light theme toggle.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shelf | 1.4.2 | HTTP server, routing, middleware | Already in server pubspec.yaml |
| shelf_router | 1.1.4 | URL routing with path parameters | Already in server pubspec.yaml |
| sqlite3 | 3.1.5 | Read-only backup database queries | Already in server pubspec.yaml |
| Chart.js | 4.4.7+ | Bar charts, line charts with gradient fill | CDN-loaded, no server dependency; industry standard for web charts |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none) | - | SVG heatmap, CSS theme toggle, vanilla JS | All built with zero dependencies |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Chart.js CDN | D3.js | D3 is more powerful but far more complex for simple bar/line charts; Chart.js is plug-and-play |
| Inline SVG heatmap | Chart.js heatmap plugin | No official Chart.js heatmap; plugins are third-party and add complexity. SVG is simpler and matches the app's custom heatmap rendering |
| CSS custom properties for theming | Separate CSS files | Custom properties allow runtime theme switching with JS toggle; no page reload needed |
| Inline HTML in Dart | Template engine (mustache, jinja) | Adding a template engine is unnecessary complexity for ~5 pages; Dart StringBuffer/string interpolation works fine and matches existing manage_page.dart pattern |

**Installation:** No new Dart dependencies. Chart.js loaded via CDN `<script>` tag in HTML output.

## Architecture Patterns

### Recommended Project Structure
```
server/lib/
├── api/
│   ├── backup_api.dart              # (existing)
│   ├── health_api.dart              # (existing)
│   ├── manage_page.dart             # (existing) backup management HTML
│   └── dashboard_pages.dart         # (NEW) all dashboard page handlers
├── services/
│   ├── backup_service.dart          # (existing)
│   ├── dashboard_service.dart       # (MODIFIED) add 4 new query methods
│   └── sqlite_validator.dart        # (existing)
├── middleware/
│   ├── auth.dart                    # (MODIFIED) whitelist dashboard routes
│   └── cors.dart                    # (existing)
└── config.dart                      # (existing)
```

### Pattern 1: Server-Rendered HTML with Shelf (Existing Pattern)
**What:** Each page is a Dart function that queries data, builds HTML string, returns `Response.ok(html)`.
**When to use:** All dashboard pages.
**Example:**
```dart
// Source: existing server/lib/api/manage_page.dart
Response overviewPageHandler(
    Request request, DashboardService dashboard, BackupService backupService, String apiKey) {
  if (!dashboard.isOpen) dashboard.open();

  final stats = dashboard.getOverviewStats();
  final heatmapDays = dashboard.getTrainingDays(period: 'all');
  final muscleVolumes = dashboard.getMuscleGroupVolumes();
  final muscleSetCounts = dashboard.getMuscleGroupSetCounts();

  final html = _buildOverviewHtml(stats, heatmapDays, muscleVolumes, muscleSetCounts, apiKey);
  return Response.ok(html, headers: {'content-type': 'text/html'});
}
```

### Pattern 2: Chart.js via CDN with Inline Data
**What:** Embed chart data as JSON in a `<script>` tag, initialize Chart.js on DOMContentLoaded.
**When to use:** All chart pages (overview, exercise detail).
**Example:**
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>
<script>
  const volumeData = JSON.parse(document.getElementById('volume-data').textContent);
  new Chart(document.getElementById('volume-chart'), {
    type: 'bar',
    data: {
      labels: volumeData.map(d => d.muscle),
      datasets: [{
        data: volumeData.map(d => d.volume),
        backgroundColor: '#7C3AED',
        borderRadius: 4,
      }]
    },
    options: {
      responsive: true,
      plugins: { legend: { display: false } }
    }
  });
</script>
```

### Pattern 3: SVG Heatmap (No Library)
**What:** Generate SVG `<rect>` elements server-side for heatmap grid. Color intensity computed in Dart.
**When to use:** Training heatmap on overview page.
**Example:**
```dart
// Heatmap cell: 14x14px with 3px border-radius, intensity by set count
String _heatmapCell(int x, int y, int count) {
  final color = count == 0 ? 'var(--surface-elevated)'
    : count < 5 ? 'rgba(124, 58, 237, 0.2)'
    : count < 10 ? 'rgba(124, 58, 237, 0.4)'
    : count < 15 ? 'rgba(124, 58, 237, 0.6)'
    : 'rgba(124, 58, 237, 0.8)';
  return '<rect x="$x" y="$y" width="14" height="14" rx="3" fill="$color" />';
}
```

### Pattern 4: CSS Custom Properties for Theme Toggle
**What:** Define all colors as CSS variables on `:root`, toggle by adding/removing a `.light` class on `<html>`.
**When to use:** Dark/light theme switching.
**Example:**
```css
:root {
  --bg: #0f0f0f;
  --surface: #1a1a1a;
  --surface-elevated: #242424;
  --text: #e0e0e0;
  --text-muted: #888;
  --accent: #7C3AED;
  --accent-dim: rgba(124, 58, 237, 0.2);
}
html.light {
  --bg: #f5f5f5;
  --surface: #ffffff;
  --surface-elevated: #f0f0f0;
  --text: #1a1a1a;
  --text-muted: #666;
  --accent: #7C3AED;
  --accent-dim: rgba(124, 58, 237, 0.1);
}
```

### Pattern 5: Responsive Sidebar/Hamburger
**What:** CSS media query hides sidebar below breakpoint, JS toggles mobile menu overlay.
**When to use:** All dashboard pages share the same layout shell.
**Example:**
```css
.sidebar { width: 240px; position: fixed; left: 0; top: 0; height: 100vh; }
.main { margin-left: 240px; }
@media (max-width: 768px) {
  .sidebar { transform: translateX(-100%); transition: transform 0.2s; position: fixed; z-index: 100; }
  .sidebar.open { transform: translateX(0); }
  .main { margin-left: 0; }
  .hamburger { display: block; }
}
```

### Pattern 6: Chart.js Line Chart Matching App's FlexLine Style
**What:** Curved line (tension ~0.35), gradient fill below (primary to transparent), no dots, optional dashed trend line.
**When to use:** Exercise progress charts.
**Example:**
```javascript
// Replicate app's FlexLine: curved, gradient fill, no dots, dashed trend
function createProgressChart(ctx, labels, values, trendValues) {
  const gradient = ctx.createLinearGradient(0, 0, 0, ctx.canvas.height);
  gradient.addColorStop(0, 'rgba(124, 58, 237, 0.3)');
  gradient.addColorStop(1, 'rgba(124, 58, 237, 0.02)');

  const datasets = [{
    data: values,
    borderColor: '#7C3AED',
    backgroundColor: gradient,
    fill: 'origin',
    tension: 0.35,
    pointRadius: 0,
    borderWidth: 3,
  }];

  if (trendValues && trendValues.length >= 2) {
    datasets.push({
      data: trendValues,
      borderColor: 'rgba(124, 58, 237, 0.5)',
      borderDash: [5, 5],
      pointRadius: 0,
      fill: false,
    });
  }

  new Chart(ctx, {
    type: 'line',
    data: { labels, datasets },
    options: {
      responsive: true,
      plugins: { legend: { display: false } },
      scales: { x: { grid: { display: false } } }
    }
  });
}
```

### Anti-Patterns to Avoid
- **Separate CSS/JS files served statically:** The server has no static file serving middleware. All assets must be inline or CDN-loaded. Don't try to add static file serving -- it adds complexity for no benefit when CSS/JS is page-specific.
- **Client-side data fetching (SPA pattern):** Don't fetch data via AJAX from API endpoints. Pages are server-rendered with data already embedded. This keeps things simple and avoids needing JSON API endpoints for dashboard data.
- **Over-componentizing HTML generation:** Don't create a template engine. Use Dart StringBuffer and helper functions (like manage_page.dart does). Keep it simple.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bar/line charts | Canvas drawing code | Chart.js 4.x CDN | Responsive, tooltips, animations, gradient fills all built-in |
| Number formatting | Manual comma insertion | `Intl.NumberFormat` in JS | Handles locale, compaction, edge cases |
| Date formatting | Manual string building | `Date.toLocaleDateString()` in JS, or server-side Dart formatting | Locale-aware, timezone-safe |
| Responsive grid | Custom JS layout | CSS Grid + Flexbox + media queries | Native browser support, no JS needed |
| Theme persistence | Cookie parsing | `localStorage.getItem('theme')` | Simple, client-only, no server round-trip |

**Key insight:** Server-rendered HTML with Chart.js CDN is the simplest possible architecture. Resist the temptation to add build tools, template engines, or client-side frameworks.

## Common Pitfalls

### Pitfall 1: Chart.js Canvas Not Ready
**What goes wrong:** Chart.js `new Chart(ctx, ...)` fails because canvas element doesn't exist yet when script runs.
**Why it happens:** Script executes before DOM is fully parsed.
**How to avoid:** Wrap all Chart.js initialization in `document.addEventListener('DOMContentLoaded', () => { ... })` or place `<script>` at the end of `<body>`.
**Warning signs:** "Cannot read property 'getContext' of null" in browser console.

### Pitfall 2: Chart.js Gradient Requires chartArea
**What goes wrong:** Background gradient renders as solid color or undefined.
**Why it happens:** Chart.js gradients need `chartArea` dimensions, which aren't available until after first render.
**How to avoid:** Use a callback function for `backgroundColor` that creates the gradient lazily:
```javascript
backgroundColor: function(context) {
  const chart = context.chart;
  const {ctx, chartArea} = chart;
  if (!chartArea) return 'rgba(124, 58, 237, 0.1)'; // fallback
  const gradient = ctx.createLinearGradient(0, chartArea.bottom, 0, chartArea.top);
  gradient.addColorStop(0, 'rgba(124, 58, 237, 0.02)');
  gradient.addColorStop(1, 'rgba(124, 58, 237, 0.3)');
  return gradient;
}
```

### Pitfall 3: Heatmap Date Alignment Off by One
**What goes wrong:** Heatmap cells appear on wrong days, month labels shifted.
**Why it happens:** JavaScript Date and Dart DateTime handle day-of-week differently (JS: 0=Sunday, Dart: 1=Monday). Also, epoch timestamps from SQLite are in seconds, not milliseconds.
**How to avoid:** Generate heatmap SVG entirely server-side in Dart (where DateTime weekday is consistent with app logic). Pass epoch seconds * 1000 when converting to JS Date.
**Warning signs:** Monday column shows Sunday data.

### Pitfall 4: Auth Key Not Propagated in Navigation
**What goes wrong:** User clicks a link from overview to exercise detail, gets 403 Forbidden.
**Why it happens:** The `?key=...` query parameter is lost when navigating between pages.
**How to avoid:** Include `?key=${apiKey}` in all internal links. Pass the key through every page handler and embed it in href attributes. The existing manage page passes the key via JavaScript `const KEY = new URLSearchParams(window.location.search).get('key')`.
**Warning signs:** First page loads fine but all links return 403.

### Pitfall 5: Large HTML Strings Causing Memory Issues
**What goes wrong:** Building a page with 100+ workout history rows or large heatmap creates huge string allocations.
**Why it happens:** Dart string concatenation in loops is O(n^2). StringBuffer is O(n).
**How to avoid:** Always use `StringBuffer` for building HTML in loops. The existing manage_page.dart already uses this pattern.
**Warning signs:** Slow page loads, high memory usage.

### Pitfall 6: Missing DashboardService Queries
**What goes wrong:** Phase 13 implementation discovers that needed data isn't available from Phase 12's query layer.
**Why it happens:** Phase 12 focused on the requirements marked as DONE. Phase 13's chart requirements (DASH-02 through DASH-05) need additional queries not in DashboardService.
**How to avoid:** Add these 4 methods to DashboardService as part of Phase 13:
1. `getTrainingDays({String? period})` - Date-to-set-count map for heatmap (replicates app's overview_page.dart daysQuery)
2. `getMuscleGroupVolumes({String? period})` - Category-to-volume map (replicates app's volumeQuery)
3. `getMuscleGroupSetCounts({String? period})` - Category-to-set-count map (replicates app's setCountQuery)
4. `getExerciseProgress(String name, {String metric, String? period})` - Time series data for line charts (replicates app's getStrengthData from gym_sets.dart)

## Code Examples

### Example 1: Dashboard Route Registration (server.dart)
```dart
// Source: existing server/bin/server.dart pattern
final dashboardService = DashboardService(config.dataDir);

// Dashboard pages (query parameter auth like /manage)
router.get('/dashboard', (req) => overviewPageHandler(req, dashboardService, backupService, config.apiKey));
router.get('/dashboard/exercises', (req) => exercisesPageHandler(req, dashboardService, config.apiKey));
router.get('/dashboard/exercise/<name>', (req, String name) => exerciseDetailHandler(req, name, dashboardService, config.apiKey));
router.get('/dashboard/history', (req) => historyPageHandler(req, dashboardService, config.apiKey));
router.get('/dashboard/workout/<id>', (req, String id) => workoutDetailHandler(req, id, dashboardService, config.apiKey));
```

### Example 2: Auth Middleware Update for Dashboard Routes
```dart
// Source: existing server/lib/middleware/auth.dart pattern
// Add dashboard routes to query parameter auth (like 'manage')
if (request.url.path.startsWith('dashboard')) {
  final key = request.url.queryParameters['key'];
  if (key != apiKey) {
    return Response.forbidden('{"error": "Invalid API key"}',
      headers: {'content-type': 'application/json'});
  }
  return innerHandler(request);
}
```

### Example 3: Shared Layout Shell Function
```dart
// Build shared HTML shell with sidebar, header, and content area
String dashboardShell({
  required String title,
  required String activeNav,
  required String content,
  required String apiKey,
  String extraHead = '',
  String extraScripts = '',
}) {
  return '''<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title - JackedLog</title>
  <style>${_sharedCss()}</style>
  $extraHead
</head>
<body>
  <nav class="sidebar" id="sidebar">
    <div class="sidebar-header">
      <span class="logo">JackedLog</span>
    </div>
    ${_navItems(activeNav, apiKey)}
  </nav>
  <div class="main">
    <header class="header">
      <button class="hamburger" onclick="toggleSidebar()">&#9776;</button>
      <h1>$title</h1>
      <button class="theme-toggle" onclick="toggleTheme()" title="Toggle theme">&#9788;</button>
    </header>
    <div class="content">
      $content
    </div>
  </div>
  <div class="overlay" id="overlay" onclick="toggleSidebar()"></div>
  <script>${_sharedJs(apiKey)}</script>
  $extraScripts
</body>
</html>''';
}
```

### Example 4: Training Heatmap Query (New DashboardService Method)
```dart
// Replicates app's overview_page.dart daysQuery pattern
Map<String, int> getTrainingDays({String? period}) {
  if (_db == null) return {};
  final startEpoch = _periodToEpoch(period);

  final result = _db!.select("""
    SELECT DISTINCT
      DATE(w.start_time, 'unixepoch') as workout_date,
      COUNT(DISTINCT gs.id) as set_count
    FROM workouts w
    INNER JOIN gym_sets gs ON w.id = gs.workout_id
    WHERE w.start_time >= ?
      AND gs.hidden = 0
    GROUP BY workout_date
    ORDER BY workout_date DESC
  """, [startEpoch]);

  final days = <String, int>{};
  for (final row in result) {
    days[row['workout_date'] as String] = row['set_count'] as int;
  }
  return days;
}
```

### Example 5: Muscle Group Volume Query (New DashboardService Method)
```dart
// Replicates app's overview_page.dart volumeQuery pattern
List<Map<String, dynamic>> getMuscleGroupVolumes({String? period}) {
  if (_db == null) return [];
  final startEpoch = _periodToEpoch(period);

  final result = _db!.select('''
    SELECT gs.category as muscle,
      SUM(gs.weight * gs.reps) as total_volume
    FROM gym_sets gs
    WHERE gs.created >= ?
      AND gs.hidden = 0
      AND gs.category IS NOT NULL
      AND gs.cardio = 0
    GROUP BY gs.category
    ORDER BY total_volume DESC
  ''', [startEpoch]);

  return result.map((row) => {
    'muscle': row['muscle'],
    'volume': (row['total_volume'] as num).toDouble(),
  }).toList();
}
```

### Example 6: Exercise Progress Query (New DashboardService Method)
```dart
// Replicates app's gym_sets.dart getStrengthData pattern
List<Map<String, dynamic>> getExerciseProgress(
  String exerciseName, {
  String metric = 'bestWeight',
  String? period,
}) {
  if (_db == null) return [];
  final startEpoch = _periodToEpoch(period);

  String metricExpr;
  switch (metric) {
    case 'oneRepMax':
      metricExpr = "CASE WHEN weight >= 0 THEN weight / (1.0278 - 0.0278 * reps) "
          "ELSE weight * (1.0278 - 0.0278 * reps) END";
    case 'volume':
      metricExpr = 'weight * reps';
    default: // bestWeight
      metricExpr = 'weight';
  }

  final startClause = startEpoch > 0 ? 'AND created >= $startEpoch' : '';

  final result = _db!.select('''
    SELECT created, weight, reps, unit,
      $metricExpr as metric_value
    FROM gym_sets
    WHERE name = ? AND hidden = 0 AND reps > 0
      $startClause
    GROUP BY STRFTIME('%Y-%m-%d', DATE(created, 'unixepoch', 'localtime'))
    HAVING $metricExpr = MAX($metricExpr)
    ORDER BY created ASC
  ''', [exerciseName]);

  return result.map((row) => {
    'created': row['created'],
    'weight': row['weight'],
    'reps': row['reps'],
    'unit': row['unit'],
    'value': row['metric_value'],
  }).toList();
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Chart.js v2 (global namespace) | Chart.js v4 (tree-shakeable, ESM) | 2023 (v4.0) | UMD build still available via CDN for non-bundled use; auto-registers all chart types |
| Manual responsive CSS | CSS Container Queries | 2023 | Not needed here; media queries sufficient for sidebar/mobile layout |
| JavaScript fetch for interactivity | Server-rendered HTML | N/A | Deliberate choice: simpler architecture, no client-side state management |

**Deprecated/outdated:**
- Chart.js v2 syntax (`new Chart(ctx, {type: ...})`) still works in v4 UMD but some options have moved (e.g., `legend` is now under `plugins.legend`)
- `Chart.defaults.global` is replaced by `Chart.defaults` in v4

## Open Questions

1. **Period selector for overview page: server-side or client-side?**
   - What we know: The app has Week, Month, 3M, 6M, Year, All Time. The dashboard queries support period filtering.
   - What's unclear: Should period changes be full page reloads (server-rendered with query parameter `?period=month`) or client-side (fetch new data via AJAX)?
   - Recommendation: Use full page reload with query parameter. Keeps the server-rendered-only architecture. Simple, no AJAX needed. URL is shareable. Example: `/dashboard?key=xxx&period=month`

2. **Exercise progress chart: period selector scope**
   - What we know: App has 30D, 3M, 6M, 1Y, All. Dashboard context says "Week, Month, 3M, 6M, Year, All Time".
   - What's unclear: Whether exercise progress charts should match the overview period selector (6 options) or the app's exercise-specific period selector (5 options).
   - Recommendation: Use the 6-option set from the overview period selector for consistency across the dashboard: Week, Month, 3M, 6M, Year, All Time.

3. **Trend line calculation: server or client?**
   - What we know: App calculates linear regression trend line in FlexLine widget (Dart). Chart.js has no built-in trend line.
   - What's unclear: Where to compute it.
   - Recommendation: Compute server-side in Dart (same linear regression formula as app's `_calculateTrendLine`), pass trend start/end points as data, render as a second Chart.js dataset with `borderDash: [5, 5]`.

## Sources

### Primary (HIGH confidence)
- `/websites/chartjs` (Context7) - Line chart gradient fill, bar chart configuration, tension/fill options, CDN setup
- Existing codebase: `server/lib/api/manage_page.dart` - Server-rendered HTML pattern
- Existing codebase: `server/lib/services/dashboard_service.dart` - All Phase 12 query methods
- Existing codebase: `server/lib/middleware/auth.dart` - Query parameter auth for HTML pages
- Existing codebase: `lib/graph/overview_page.dart` - App heatmap, muscle charts, stats cards SQL queries
- Existing codebase: `lib/graph/flex_line.dart` - App chart styling (curved, gradient fill, trend line)
- Existing codebase: `lib/graph/strength_page.dart` - Exercise progress chart with period/metric selectors
- Existing codebase: `lib/database/gym_sets.dart` - getStrengthData SQL for exercise progress

### Secondary (MEDIUM confidence)
- [Chart.js CDN](https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js) - v4.4.7+ UMD build, verified via jsdelivr
- [Chart.js installation docs](https://www.chartjs.org/docs/latest/getting-started/installation.html) - CDN availability confirmed

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Chart.js verified via Context7, all Dart dependencies already in pubspec
- Architecture: HIGH - Extending proven patterns from manage_page.dart and Phase 12
- Pitfalls: HIGH - Based on direct codebase analysis (auth propagation, missing queries, DOM readiness)
- Missing queries: HIGH - Verified by comparing DashboardService methods against app SQL in overview_page.dart and gym_sets.dart

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (stable - Chart.js CDN, Shelf framework, vanilla CSS/JS are all mature)
