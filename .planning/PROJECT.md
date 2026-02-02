# JackedLog

## What This Is

A Flutter fitness tracking app for logging workouts, tracking personal records, and visualizing progress. Cross-platform (Android, iOS, Linux, macOS, Windows) with offline-first architecture using SQLite/Drift for persistence. Includes Spotify integration for workout music. Now with full edit capability for completed workouts and customizable note ordering.

## Core Value

Users can efficiently log and track their workouts with minimal friction — every interaction should feel fast and intuitive.

## Requirements

### Validated

- ✓ Workout session management (start, log sets, end) — existing
- ✓ Exercise plans with customizable exercises — existing
- ✓ Personal record detection and celebration (1RM, volume, weight) — existing
- ✓ Rest timer with native Android integration — existing
- ✓ Workout history with search and filtering — existing
- ✓ Progress graphs (strength, cardio metrics) — existing
- ✓ Overview dashboard with stats and heatmap — existing
- ✓ Notes system for workout journaling — existing
- ✓ Bodyweight tracking with trends — existing
- ✓ 5/3/1 calculator integration — existing
- ✓ Spotify music control during workouts — existing
- ✓ Data backup/restore with auto-backup — existing
- ✓ CSV import/export (including Hevy format) — existing
- ✓ Custom theming with Material You support — existing
- ✓ Total workout time stat on overview page — v1.0
- ✓ Edit completed workout name — v1.0
- ✓ Edit workout exercises (add, remove, reorder) — v1.0
- ✓ Edit workout sets (weight, reps, type, add, delete) — v1.0
- ✓ Selfie feature in edit mode panel — v1.0
- ✓ Drag-drop notes reordering with persistence — v1.0
- ✓ History search bar cleanup (menu removed) — v1.0

### Active

(None — ready for next milestone definition)

### Out of Scope

- Cloud sync — offline-first design, backup system sufficient
- Social features — personal tracking app
- AI/ML workout recommendations — keep it simple
- PR recalculation on edit — edits to historical data shouldn't retroactively change records
- Notes grid drag-drop — requires custom implementation, list layout works well

## Context

Shipped v1.0 UI Enhancements with ~4,000 lines added across 28 files.
Tech stack: Flutter/Dart, Drift ORM (SQLite), Provider state management.
Database version: 62 (added notes sequence column).

The Edit Workout feature mirrors the active workout experience from `start_plan_page.dart` for consistency.

## Constraints

- **Flutter commands**: Do not run directly — user will run `flutter analyze` or test manually
- **Database migrations**: Always manual (no generated migrations)
- **Backward compatibility**: Exported data must remain importable after schema changes
- **KISS/YAGNI**: Simple solutions preferred, no speculative features

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Mirror start_plan_page for edit workout | Consistent UX, familiar patterns | ✓ Good |
| Notes sequence via database column | Persist order across sessions | ✓ Good |
| List layout for notes reorder | ReorderableListView compatibility | ✓ Good |
| tertiaryContainer for edit mode | Clear visual indicator | ✓ Good |
| Selfie in edit mode only | Cleaner top bar, grouped with edit actions | ✓ Good |
| Sequence stored descending | Natural ordering (highest = top) | ✓ Good |

---
*Last updated: 2026-02-02 after v1.0 milestone*
