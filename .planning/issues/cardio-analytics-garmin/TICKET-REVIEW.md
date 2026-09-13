# Garmin and cardio ticket review

Status: needs-info

The architecture prerequisite is complete and pushed in `e4ca838b`. These are
review drafts, not published implementation tickets. After approval, move the
individual drafts into `issues/` and mark them `ready-for-agent`. Keep numbering
and genuine blocking edges; do not repeat the architecture migration.

## Proposed breakdown

1. **Recorded cardio history and manual entry** — Blocked by: none. Delivers creating, finding, editing and backing up a standalone run without a strength set.
2. **Connect Garmin and report connection state** — Blocked by: none. Delivers an authorized owner-bound account, visible connection state and disconnect without coach setup.
3. **Automatically import new Garmin runs** — Blocked by: 01, 02. Delivers one imported run after upload, including after server restart or phone reconnection.
4. **Keep imports current and recover older runs** — Blocked by: 03. Delivers corrections, deletions and bounded backfill without undoing local edits.
5. **Link imported and manually logged cardio** — Blocked by: 04. Delivers confirmed matching that preserves both sources and counts a session once.
6. **View all-day heart rate** — Blocked by: 02. Delivers a synced daily HR timeline with coverage, freshness and available resting HR.
7. **View sleep, stress and recovery context** — Blocked by: 06. Delivers source-labelled daily summaries and recent trends, including missing or revised data.
8. **Show live HR during an active workout** — Blocked by: none. Delivers one validated sensor transport and fresh/stale/disconnected HR while training.
9. **Review recorded workout HR and zones** — Blocked by: 08. Delivers saved observed HR, gaps and configured zones for offline workout review.
10. **Replace cardio maxima with pace and volume trends** — Blocked by: 01. Delivers real pace, weekly volume and consistency for comparable activities.
11. **Review Garmin laps, splits and best efforts** — Blocked by: 03, 10. Delivers evidence-backed pacing and elapsed-time best efforts without rewarding pauses.
12. **Reconcile live HR with the final Garmin recording** — Blocked by: 05, 09. Delivers linked final watch evidence for a run or lifting workout without doubled duration or HR.

Each draft is a complete user-facing slice with persistence, backup compatibility,
failure states and tests. There is no separate final testing or privacy ticket;
each owning slice includes those requirements before it ships.

The initial code frontier is **01, 02 and 08**. Cloud approval/credentials gate
real Garmin acceptance for 02; the actual watch/firmware and any required license
gate real-device acceptance for 08. These are external prerequisites, not hidden
dependencies between live HR and cloud import. Ticket 02 delivers the shared
durable connection-change inbox and phone cursor, which both 03 and 06 reuse.

## Proposed test boundaries

Exercise public activity save/read/delete and the real backup archive; exercise
authenticated provider ingestion through durable storage and the phone's visible
queries; replay sensor events through the active-workout interface and verify the
chosen transport on real hardware. Use real SQLite and approved Garmin fixtures.
Avoid separate tests of every internal helper or claims based only on mocks.

## Review requested

Confirm the public test boundaries and whether the twelve slices have the right
size and blocking edges. Identify any tickets to merge or split before publishing
them as ready for implementation. Drafts are in `draft-issues/`; the parent spec
is `PRD.md`.

The invoked to-tickets skill explicitly requires: “Iterate until the user approves
the breakdown.” The invoked to-spec skill also asks to check the test seams with
the user. This review satisfies those workflow requirements; it does not gate the
already completed and pushed architecture work.
