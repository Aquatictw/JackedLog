# 01: Recorded cardio history and manual entry

**What to build:** Let a user create and revisit a standalone recorded cardio
activity, with distance, duration, sport, environment and notes. Put it in history
and detail navigation alongside workouts without fabricating a strength set.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

Parent: [Garmin-connected cardio and health](../PRD.md).

- [x] Create, edit and delete an independent run offline through the existing recorded activity store; unit preferences convert at the boundary while canonical values remain metres/seconds.
- [x] Show distance, duration, actual pace when supported and source on an activity detail screen. Missing distance or ambiguous time basis has an explicit state, never an invented pace.
- [x] Paginate mixed history using stable typed identities; a workout-associated activity has one intentional presentation, and selecting a standalone chart/history entry reaches its detail directly.
- [x] Preserve legacy raw units, unknown measurements, timestamp meaning and existing bout editing. Do not guess running from an old exercise name.
- [x] Keep activity count distinct from strength sets and link to the containing workout where present. A workout with several actual cardio bouts retains those separate activities.
- [x] Verify public save/read/delete, history navigation and existing workout ZIP round trips with standalone and legacy activities. Old ZIPs and upgraded databases remain usable.
- [ ] Profile a paged history with 10,000 activities on the target device; avoid full history reloads on each edit and report measured results.

**Scope limit:** This slice introduces activity navigation and entry, not cloud import, samples or the complete trend dashboard.

## Implementation — phase 1 (2026-09-13)

Delivered manual entry/edit/delete, explicit missing-pace states, mixed filtered
history, typed identities, standalone chart navigation, and workout activity
navigation. The editor and detail screens use focused routes above the home
navigation, grouped fields, and existing unit preferences. Legacy raw rows and
schema 73 remain compatible; no new migration or archive format is required.

Validation: 37 targeted tests pass, including upgrade and archive round-trip of
an opt-in schema-72 backup copy. Original set rows compare equal after upgrade.
Pixel 9a Android 15 emulator integration passes the public save/detail flow.
The original full suite has 13 failures in this Windows environment (308 pass);
this phase adds five passing tests plus an opt-in backup test, with the same 13
failures. Baseline was checked in a detached checkout at ca7ca404.

History benchmark: 10,000 synthetic activities, 100-row pages, 30 samples after
one warm-up, Android emulator debug build: median 9.029 ms, p95 17.387 ms,
maximum 32.849 ms. These are query timings, not full UI interaction timings or
physical-device release acceptance. The target-device profiling checkbox remains
open. The repeatable integration test uses a dedicated test database.

Profile follow-up: the same Pixel 9a Android 15 emulator passed the save/detail
flow in profile mode using the integration driver. On 10,000 activities,
100-row pages (30 samples after warm-up) measured median 2.060 ms, p95 3.135 ms,
maximum 3.410 ms. Physical-device and full interaction acceptance remain open.
Run with `flutter drive --profile --driver=test_driver/integration_test.dart
--target=integration_test/cardio_history_test.dart
--dart-define=JACKEDLOG_DATABASE_FILENAME=cardio-test.sqlite -d <device>`.
