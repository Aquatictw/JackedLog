# JackedLog

## What This Is

A Flutter fitness tracking app for logging workouts, tracking personal records, and visualizing progress. Cross-platform (Android, iOS, Linux, macOS, Windows) with offline-first architecture using SQLite/Drift for persistence. Includes Spotify integration for workout music, full edit capability for completed workouts, customizable note ordering, and 5/3/1 Forever block programming with cycle-aware calculator.

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

- ✓ Import error logging and user toast notifications — v1.1
- ✓ Backup failure logging with status indicator in settings — v1.1
- ✓ Active workout bar timer stability fix (mounted check) — v1.1
- ✓ Settings initialization null safety (getSingleOrNull) — v1.1

- ✓ 5/3/1 block creation with starting TMs for 4 lifts — v1.2
- ✓ Block overview page with 5-cycle timeline and position tracking — v1.2
- ✓ Manual week advancement with TM auto-bump at cycle boundaries — v1.2
- ✓ Notes page banner with block position and navigation — v1.2
- ✓ Context-aware calculator (5's PRO, PR Sets, Deload, TM Test) — v1.2
- ✓ Supplemental work display (BBB 5x10@60% Leader, FSL 5x5 Anchor) — v1.2
- ✓ Block completion summary with TM progression and history — v1.2
- ✓ fivethreeone_blocks table, FiveThreeOneState, schemes module — v1.2

### Active

None — planning next milestone.

### Out of Scope

- Cloud sync — offline-first design, backup system sufficient
- Social features — personal tracking app
- AI/ML workout recommendations — keep it simple
- PR recalculation on edit — edits to historical data shouldn't retroactively change records
- Notes grid drag-drop — requires custom implementation, list layout works well
- Auto-generated workout plans — logging tool, not a plan generator
- Assistance work tracking in block system — accessories tracked as regular exercises
- Multiple concurrent blocks — single active block design
- Automatic week detection from logged workouts — unreliable, manual advancement preferred

## Context

Shipped v1.0 UI Enhancements, v1.1 Error Handling & Stability, and v1.2 5/3/1 Forever Block Programming.
Tech stack: Flutter/Dart, Drift ORM (SQLite), Provider state management.
Database version: 65 (added start TM columns to fivethreeone_blocks).

5/3/1 implementation: Dedicated `fivethreeone_blocks` table with block lifecycle (create → advance → complete). Pure `schemes.dart` module for all percentage/rep data. `FiveThreeOneState` ChangeNotifier in Provider tree. Context-aware calculator shows correct scheme per cycle/week with supplemental work. Block overview page with vertical timeline. Notes page banner shows block position.

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
| Dedicated fivethreeone_blocks table | Proper lifecycle management, not extending Settings | ✓ Good |
| Single current_cycle integer (0-4) | Simple encoding for 5 cycle types | ✓ Good |
| Pure schemes.dart module | No UI/DB dependencies, easily testable | ✓ Good |
| Manual week advancement only | No unreliable auto-detection | ✓ Good |
| Single widget with _isBlockMode flag | Avoids calculator widget duplication | ✓ Good |
| Compact supplemental display | Single-line format cleaner than repeating identical rows | ✓ Good |
| Nullable start TM columns with fallback | Graceful pre-migration block compatibility | ✓ Good |
| pushReplacement for block completion | Prevents back-nav to stale overview | ✓ Good |
| Pre-fill new block TMs from last completed | Smoother block-to-block workflow | ✓ Good |

---
*Last updated: 2026-02-15 after v1.2 milestone completion*
