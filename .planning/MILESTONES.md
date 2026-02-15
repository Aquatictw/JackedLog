# Project Milestones: JackedLog

## v1.2 5/3/1 Forever Block Programming (Shipped: 2026-02-11)

**Delivered:** In-app 5/3/1 Forever block programming with 11-week cycle management, context-aware calculator, and TM progression tracking.

**Phases completed:** 6-9 (5 plans total)

**Key accomplishments:**

- Data foundation: `fivethreeone_blocks` table, pure `schemes.dart` module, `FiveThreeOneState` ChangeNotifier
- Block creation dialog with 4 TM fields and overview page with 5-cycle vertical timeline
- TM auto-bump with confirmation at cycle boundaries (+2.2kg upper, +4.5kg lower)
- Context-aware calculator: 5's PRO / PR Sets / Deload / TM Test scheme switching with supplemental display
- Block completion summary with start→end TM progression and block history
- Notes page banner with dynamic block position and navigation

**Stats:**

- 52 files modified
- ~10,344 lines added, ~1,958 removed
- 4 phases, 5 plans, 4 quick tasks (005-008)
- 13 min total execution time
- 13/13 requirements shipped

**Git range:** `4b5839d3` (feat: 06) → `c79141ef` (docs: quick-008)

**What's next:** Planning next milestone

---

## v1.0 UI Enhancements (Shipped: 2026-02-02)

**Delivered:** Three user-facing improvements: total workout time stat, full edit workout capability, and drag-drop notes reordering.

**Phases completed:** 1-3 (4 plans total)

**Key accomplishments:**

- Added Total Workout Time stat card to overview page with period filtering
- Implemented full edit mode for completed workouts (rename, exercise management, inline set editing)
- Enabled drag-drop reordering for notes with database-backed persistence
- Relocated selfie feature from top bar to edit mode panel
- Removed unused three-dots menu from history search bar
- Added database v62 migration for notes sequence column

**Stats:**

- 28 files modified
- ~3,988 lines added
- 3 phases, 4 plans, ~12 tasks
- ~3 hours from init to ship (53 min execution time)

**Git range:** `908f6066` (docs: initialize GSD) → `dd920260` (feat: quick-001)

**What's next:** v1.1 Error Handling & Stability

---

## v1.1 Error Handling & Stability (Shipped: 2026-02-06)

**Delivered:** Error visibility improvements and stability fixes for import, backup, and async operations.

**Phases completed:** 4-5 (2 plans total)

**Key accomplishments:**

- Import failures now log exception type/context and show user toast with actionable description
- Backup failures log specific error reason and show toast notification
- Settings page shows last backup timestamp and status indicator (success/failed/never)
- Active workout bar timer checks mounted before context access
- Settings initialization uses getSingleOrNull with safe defaults

**Stats:**

- 2 phases, 2 plans
- 5 min total execution time

**Git range:** v1.1 phases

**What's next:** v1.2 5/3/1 Forever Block Programming

---
