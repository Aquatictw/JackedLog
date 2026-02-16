---
phase: 14-dashboard-differentiators
plan: 02
subsystem: dashboard
tags: [bodyweight, chart, moving-average, server-side-rendering]
depends_on: [14-01]
provides: [bodyweight-dashboard-page]
affects: []
tech-stack:
  added: []
  patterns: [server-side-moving-average, chart-toggle-buttons]
key-files:
  created: []
  modified:
    - server/lib/services/dashboard_service.dart
    - server/lib/api/dashboard_pages.dart
    - server/bin/server.dart
decisions: []
metrics:
  duration: 3 min
  completed: 2026-02-15
---

# Phase 14 Plan 02: Bodyweight Dashboard Page Summary

Bodyweight tracking page with line chart, 3 server-computed moving averages (3/7/14-day), period filtering, and entry history list.

## What Was Done

### Task 1: Add getBodyweightData() query and bodyweightPageHandler

**DashboardService changes (`dashboard_service.dart`):**
- Added `getBodyweightData({String? period})` method that queries `bodyweight_entries` table with table existence check for backward compatibility with old backups
- Returns entries, stats (current, average, change, entry count, unit), and 3 moving average arrays
- Added `_calculateMovingAverage(entries, windowDays)` private helper ported from `lib/utils/bodyweight_calculations.dart` -- uses calendar-day trailing window, not entry-count window
- Updated `_periodToEpoch()` with URL-style period aliases: `'7d'` maps to `'week'`, `'1m'` maps to `'month'`, `'1y'` maps to `'year'`

**Dashboard page (`dashboard_pages.dart`):**
- Added `bodyweightPageHandler()` with full HTML page rendering
- Period selector: 7D/1M/3M/6M/1Y/All buttons with active accent highlighting
- Stats cards: Current weight, Average, Change (with +/- prefix), Entry count
- Moving average toggle buttons: 14-Day MA (cyan #06B6D4), 7-Day MA (green #10B981), 3-Day MA (amber #F59E0B) -- toggle show/hide of dashed overlay lines
- Line chart: Chart.js with gradient fill, bodyweight points, 3 hidden MA datasets that toggle via buttons
- Entry history list: scrollable card with most-recent-first entries showing date, weight, and optional notes
- Added "Bodyweight" nav item to `dashboardShell()` sidebar between "5/3/1 Blocks" and "Backups"

### Task 2: Register /dashboard/bodyweight route in server.dart

- Added `router.get('/dashboard/bodyweight', ...)` route wired to `bodyweightPageHandler`

## Deviations from Plan

None -- plan executed exactly as written.

## Verification Results

1. `getBodyweightData` found in dashboard_service.dart
2. `_calculateMovingAverage` found in dashboard_service.dart
3. `bodyweightPageHandler` found in dashboard_pages.dart
4. `bodyweightPageHandler` found in server.dart route
5. `Bodyweight` nav item found in dashboardShell
6. `sqlite_master.*bodyweight_entries` table existence check confirmed
7. `toggleMA` function found in dashboard_pages.dart
8. `'7d'` period alias found in dashboard_service.dart
