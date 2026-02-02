# JackedLog

## What This Is

A Flutter fitness tracking app for logging workouts, tracking personal records, and visualizing progress. Cross-platform (Android, iOS, Linux, macOS, Windows) with offline-first architecture using SQLite/Drift for persistence. Includes Spotify integration for workout music.

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

### Active

- [ ] **NOTES-01**: Drag-and-drop reordering of notes with persistent sequence
- [ ] **OVERVIEW-01**: Total workout time statistic card showing accumulated duration for selected period
- [ ] **HISTORY-01**: Remove three-dots menu button from history search bar
- [ ] **WORKOUT-01**: Edit completed workout name
- [ ] **WORKOUT-02**: Edit workout exercises (add, remove, reorder)
- [ ] **WORKOUT-03**: Edit workout sets (weight, reps, type, add, delete)
- [ ] **WORKOUT-04**: Move workout selfie feature into edit workout panel

### Out of Scope

- Cloud sync — offline-first design, backup system sufficient
- Social features — personal tracking app
- AI/ML workout recommendations — keep it simple

## Context

Brownfield project with established architecture:
- Provider-based state management (ChangeNotifier pattern)
- Drift ORM for SQLite with stepByStep migrations (currently v60)
- Feature-based directory structure (`lib/{feature}/`)
- Native Android integration via MethodChannel for timers

The Edit Workout feature should mirror the active workout experience from `start_plan_page.dart` for consistency.

## Constraints

- **Flutter commands**: Do not run directly — user will run `flutter analyze` or test manually
- **Database migrations**: Always manual (no generated migrations)
- **Backward compatibility**: Exported data must remain importable after schema changes
- **KISS/YAGNI**: Simple solutions preferred, no speculative features

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Mirror start_plan_page for edit workout | Consistent UX, familiar patterns | — Pending |
| Notes sequence via database column | Persist order across sessions | — Pending |

---
*Last updated: 2026-02-02 after initialization*
