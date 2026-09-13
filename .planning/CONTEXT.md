# JackedLog Context

This file records the project's domain language, product context, and current architectural assumptions for engineering skills.

## Glossary

- **Cardio exercise** — an exercise with `gym_sets.cardio = true`. Logged by
  Time/Distance/Speed/Incline instead of weight×reps. Backend, graph
  (`cardio_page.dart`), and `cardioUnit` setting predate JackedLog (Flexify
  fork); custom bout input, history, pace formatting, and records are wired up.
  See `issues/cardio-exercises/`.
- **Primary measurement** (`cardio_metric` column) — the *featured input* field
  of a cardio exercise in the active-workout card (e.g. treadmill = Time). It
  only controls visual prominence; all metrics still drive records and can be
  graphed.
- **Bout** — one cardio entry (a `gym_sets` row). A cardio exercise may hold
  multiple bouts, each rendered as a full block, not a compact set row.
- **Recorded cardio activity** — a `cardio_activities` row with its own identity,
  source, sport/environment, and nullable canonical metres/seconds. It may be
  standalone or linked to one completed legacy bout. An old completion time is
  `recordedAt`, not evidence of an actual activity start time.
- **Legacy bout adapter** — transactional SQLite projection from completed cardio
  bouts into recorded activities. Shared measurements remain owned by the legacy
  bout until its writers migrate; standalone activities own their measurements.
- **`duration`** — stored as fractional minutes (5m30s = `5.5`).
- **Exercise type** — `exercise_type` string on `gym_sets`: `free_weight` /
  `machine` / `cable` (+ Cardio as a 4th add-form button). `brand_name` applies
  to machines and cardio machines.

## Current Status

- Cardio chart aggregation normalizes each bout's distance before daily totals;
  the legacy `CardioMetric.pace` name still means speed, not minutes per distance.
- Schema 73 introduces recorded cardio, migrates completed bouts without altering
  their raw rows, and preserves old ZIP imports plus new activity metadata in
  versioned backups. See [ADR 0001](docs/adr/0001-recorded-cardio.md).
- Schema 74 adds optional source UTC offset metadata without changing legacy raw
  rows or breaking old archives. Default cardio progress uses weekly volume and
  paired weighted pace with explicit sport/environment/time-basis filters.
  Source-local start days are retained when known; otherwise recording UTC days
  are labelled explicitly. Manual standalone activities appear in mixed history.
- Lap/sample storage, heart-rate analytics and Garmin integration remain proposed.
  Cloud activity import, all-day health context and live workout sensors are
  separate capabilities; no Garmin connection is implemented yet.

## Notes

Use ADRs under `.planning/docs/adr/` for decisions that should be preserved over time.
