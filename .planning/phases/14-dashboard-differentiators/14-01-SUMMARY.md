---
phase: 14-dashboard-differentiators
plan: 01
subsystem: dashboard
tags: [531, blocks, chart, server-rendered]
completed: 2026-02-15
duration: 3 min
requires: [13-dashboard-frontend]
provides: [531-blocks-page, tm-progression-chart]
affects: [14-02]
tech-stack:
  added: []
  patterns: [expandable-cards, grouped-bar-chart]
key-files:
  created: []
  modified:
    - server/lib/services/dashboard_service.dart
    - server/lib/api/dashboard_pages.dart
    - server/bin/server.dart
decisions: []
---

# Phase 14 Plan 01: 5/3/1 Blocks Page Summary

Server-rendered 5/3/1 blocks history page with expandable block cards, per-lift TM progression deltas, cycle structure labels, and a Chart.js grouped bar chart showing TM progression across completed blocks.

## Tasks Completed

| # | Task | Files |
|---|------|-------|
| 1 | Add getCompletedBlocks() query and blockHistoryPageHandler | dashboard_service.dart, dashboard_pages.dart |
| 2 | Register /dashboard/blocks route in server.dart | server.dart |

## What Was Built

### DashboardService.getCompletedBlocks()
- Table existence check (`sqlite_master`) for backward compatibility with old backups
- COALESCE fallback for nullable `start_*_tm` columns
- Returns camelCase-keyed maps with all TM values cast to double

### blockHistoryPageHandler
- Full page with expandable block cards showing date range and end TM values
- Inline expand/collapse with toggle JavaScript and arrow rotation
- Detail section: 2x2 lift grid with start->end TM and colored delta badges (green/red/muted)
- Cycle structure label badges (Leader 1 -> Leader 2 -> 7th Week Protocol -> Anchor -> 7th Week Protocol)
- TM Progression grouped bar chart (Chart.js) with 4 datasets (Squat/Bench/Deadlift/OHP)
- Chart limited to last 10 blocks when more exist, oldest-left ordering
- Empty state: "No 5/3/1 data" message
- No backup state: link to backup management

### Navigation
- "5/3/1 Blocks" nav item added to sidebar between History and Backups
- Stacked-bars SVG icon

### Route
- `/dashboard/blocks` registered in server.dart

## Deviations from Plan

None - plan executed exactly as written.
