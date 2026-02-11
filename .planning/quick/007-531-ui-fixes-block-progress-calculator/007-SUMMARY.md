---
phase: quick-007
plan: 01
subsystem: fivethreeone-ui
tags: [flutter, ui, 531, calculator, block-progress]
dependency-graph:
  requires: [quick-005]
  provides: [polished-531-ui-block-overview-calculator]
  affects: []
tech-stack:
  added: []
  patterns: [record-tuple-iteration, labeled-grid-layout]
key-files:
  created: []
  modified:
    - lib/fivethreeone/block_overview_page.dart
    - lib/widgets/five_three_one_calculator.dart
decisions: []
metrics:
  duration: "1 min"
  completed: "2026-02-11"
---

# Quick 007: 5/3/1 UI Fixes - Block Progress & Calculator Summary

Polished 5/3/1 UI with four targeted improvements: readable completed block TMs in labeled grid, better TM card vertical spacing, tighter calculator layout with supplemental label, and cycle position display in calculator header.

## Completed Tasks

| # | Task | Commit | Key Changes |
|---|------|--------|-------------|
| 1 | Block Overview improvements | 0020abb2 | Completed blocks show 4-column labeled TM grid with "Training Max" header; TM card vertical padding increased to 16px |
| 2 | Calculator dialog improvements | 0020abb2 | TM spacing reduced 24->16px; "Supplemental Work" label added; cycle position (e.g. "Leader 1 - Week 2") in header |

## Changes Made

### Block Overview Page (`block_overview_page.dart`)

1. **Completed block TM display**: Replaced single-line abbreviated format (`S 100 B 80 D 120 P 60 kg`) with a structured 4-column Row. Each column shows lift label (bodySmall, muted) above the value + unit (bodyMedium, bold). Added "Training Max" header label above the grid.

2. **TM card padding**: Changed `EdgeInsets.all(12)` to `EdgeInsets.symmetric(horizontal: 12, vertical: 16)` for more vertical breathing room around the Training Max editor section.

### Calculator Dialog (`five_three_one_calculator.dart`)

1. **Tighter TM spacing**: Reduced SizedBox gap after TM input from 24px to 16px.

2. **Supplemental Work label**: Added `Text('Supplemental Work')` with titleMedium bold styling above the existing supplemental scheme text, with 4px gap between label and content.

3. **Cycle position in header**: When `_isBlockMode` is true, a third line appears in the header below the exercise name showing the cycle name and week (e.g., "Leader 1 - Week 2") in primary color, bodySmall, w600 weight.

## Deviations from Plan

None - plan executed exactly as written.
