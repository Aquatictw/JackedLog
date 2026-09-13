# Garmin and cardio ticket review

Status: ready-for-agent
Approval: The user approved the breakdown, dependencies and test boundaries in this task.

The architecture prerequisite is complete and pushed in `e4ca838b`. All twelve
approved tickets are published individually in `issues/` as `ready-for-agent`.
The accepted scope and blocking edges are preserved.

## Approved breakdown

1. **[Recorded cardio history and manual entry](issues/01-recorded-cardio-history.md)** — Blocked by: none. Delivers creating, finding, editing and backing up a standalone run without a strength set.
2. **[Connect Garmin and report connection state](issues/02-connect-garmin.md)** — Blocked by: none. Delivers an authorized owner-bound account, visible connection state and disconnect without coach setup.
3. **[Automatically import new Garmin runs](issues/03-automatic-run-import.md)** — Blocked by: 01, 02. Delivers one imported run after upload, including after server restart or phone reconnection.
4. **[Keep imports current and recover older runs](issues/04-import-lifecycle.md)** — Blocked by: 03. Delivers corrections, deletions and bounded backfill without undoing local edits.
5. **[Link imported and manually logged cardio](issues/05-link-cardio.md)** — Blocked by: 04. Delivers confirmed matching that preserves both sources and counts a session once.
6. **[View all-day heart rate](issues/06-all-day-heart-rate.md)** — Blocked by: 02. Delivers a synced daily HR timeline with coverage, freshness and available resting HR.
7. **[View sleep, stress and recovery context](issues/07-sleep-stress-recovery.md)** — Blocked by: 06. Delivers source-labelled daily summaries and recent trends, including missing or revised data.
8. **[Show live HR during an active workout](issues/08-live-workout-heart-rate.md)** — Blocked by: none. Delivers one validated sensor transport and fresh/stale/disconnected HR while training.
9. **[Review recorded workout HR and zones](issues/09-recorded-workout-heart-rate.md)** — Blocked by: 08. Delivers saved observed HR, gaps and configured zones for offline workout review.
10. **[Replace cardio maxima with pace and volume trends](issues/10-pace-volume-analytics.md)** — Blocked by: 01. Delivers real pace, weekly volume and consistency for comparable activities.
11. **[Review Garmin laps, splits and best efforts](issues/11-laps-splits-best-efforts.md)** — Blocked by: 03, 10. Delivers evidence-backed pacing and elapsed-time best efforts without rewarding pauses.
12. **[Reconcile live HR with the final Garmin recording](issues/12-reconcile-workout-evidence.md)** — Blocked by: 05, 09. Delivers linked final watch evidence for a run or lifting workout without doubled duration or HR.

Each ticket is a complete user-facing slice with persistence, backup compatibility,
failure states and tests. There is no separate final testing or privacy ticket;
each owning slice includes those requirements before it ships.

The initial code frontier is **01, 02 and 08**. Cloud approval/credentials gate
real Garmin acceptance for 02; the actual watch/firmware and any required license
gate real-device acceptance for 08. These are external prerequisites, not hidden
dependencies between live HR and cloud import. Ticket 02 delivers the shared
durable connection-change inbox and phone cursor, which both 03 and 06 reuse.

## Approved test boundaries

Exercise public activity save/read/delete and the real backup archive; exercise
authenticated provider ingestion through durable storage and the phone's visible
queries; replay sensor events through the active-workout interface and verify the
chosen transport on real hardware. Use real SQLite and approved Garmin fixtures.
Avoid separate tests of every internal helper or claims based only on mocks.

## Approval record

The user approved the proposed twelve-ticket breakdown and public test boundaries
with “I approve”. The individual tickets are ready for implementation subject to
their listed blockers and external gates. The parent specification is unchanged.
