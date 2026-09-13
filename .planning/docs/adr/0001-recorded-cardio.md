# ADR 0001: Recorded cardio with a legacy bout adapter

Status: accepted
Date: 2026-09-13

## Context

Cardio used the strength-oriented `gym_sets` model for both templates and recorded
bouts. Runs need a persistent identity and canonical measurements without a
weight/reps row. Existing editors, imports, history, and coach tools still write
legacy bouts through many paths. Replacing every writer at once would put existing
records and backup compatibility at risk.

## Decision

Schema 73 adds `cardio_activities`. Its measurements use metres and seconds;
missing evidence is null. Sport, environment, duration basis, recording timestamps,
and source are explicit. A legacy completion timestamp is only `recordedAt`;
migration does not invent a start time or infer running from an exercise name.

Each completed, non-tombstone legacy cardio bout is projected into exactly one
activity with stable identity `legacy-bout:<set id>`. No same-day or same-workout
grouping is inferred. Original legacy rows, units and fractional minutes remain
unchanged. Unknown units and invalid/overflowing measurements remain available in
the raw row while their normalized values are null.

This is the expand stage of an expand–contract migration. For a linked activity,
the original bout owns shared editable measurements; SQLite triggers project
changes atomically into the cardio model. Independent activity metadata lives in
the new row and survives ordinary legacy edits. A store-level edit routes shared
measurements back through the bout, retaining the original unit. Standalone
activities have no legacy row and own their measurements directly. There are not
two independently writable copies of linked measurements.

Undoing completion removes the recorded activity; completing the bout again
reconstructs the same legacy identity from the original row. Deleting a bout
removes its activity. Deleting a workout unlinks its activities. Stale edits
cannot recreate an activity for a hidden or deleted bout. Drift update propagation
explicitly accounts for trigger writes so subscriptions remain current.

Cardio chart and exercise-record reads now use the recorded model. Existing
set/history badges continue to use the legacy set identity during expansion.
The record module owns shared batch evaluation; the exercise-loading helper no
longer duplicates its calculation. No generic provider framework is introduced.

Workout ZIP backup has one encoding/restoration module and an optional version-1
cardio JSON sidecar. UTF-8 CSV remains compatible with existing archives. Sidecar
metadata and standalone activities roundtrip; linked measurements come from the
imported CSV. Parse and validate before a single transactional replacement.
Unknown versions and invalid links fail without deleting current data. Full
database backups retain the new table automatically.

## Consequences and follow-up

Every legacy write has a small trigger cost, in exchange for atomic consistency
across all current writers. Triggers install once on creation/upgrade; startup
does not rescan history. Indexes support exercise/date and workout lookups.

The later contract stage must migrate logging/history/coach consumers and preserve
external identity, metadata during recording-state changes, export semantics, and
deletion behavior before retiring legacy rows or triggers. The new model is a
foundation for imports, not a Garmin connection or a complete standalone-activity
navigation experience. Garmin credentials, samples, laps and health context are
separate integration work.

Validation exercises the actual store, SQL queries and archive interface using
SQLite. Migration tests open a version-72 file, upgrade and reopen it, and compare
the original rows. A pre-existing bodyweight `beforeOpen` schema mismatch is
excluded only from strict whole-schema comparison, not from file-migration tests.
