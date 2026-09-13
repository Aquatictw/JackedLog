# 09: Review recorded workout HR and zones

**What to build:** Record live HR against the active workout, then review a saved
timeline, observed average and configured zone durations with gaps shown explicitly.

**Blocked by:** 08 — Show live HR during an active workout.

**Status:** ready-for-agent

Parent: [Garmin-connected cardio and health](../PRD.md).

- [ ] Persist source-labelled provisional samples tied to the active workout and, where applicable, its recorded cardio activity. A lifting workout does not acquire a fabricated run.
- [ ] Buffer and commit samples in batches with lifecycle flush/recovery. Store source time when available and document receive-time fallback; process interruption leaves an explicit unobserved gap.
- [ ] Finish normally during sensor failure and review saved evidence offline, with bounded chart points, source and coverage.
- [ ] Calculate time-weighted average and time in user-configured/versioned zones across valid observed intervals; duplicates, reordered samples and gaps cannot inflate observed duration.
- [ ] Show uncovered duration separately and distinguish typed summary HR from observed trace evidence. Avoid summing overlapping sources.
- [ ] Include samples, source metadata, zone configuration/version and relationships in versioned workout archives. Deleting a workout follows a documented evidence-retention rule without orphans.
- [ ] Test capture-to-finish-to-query and real archive restore using replayed gaps/lifecycle interruptions. Validate sustained capture and UI responsiveness on the device selected in 08.

**Scope limit:** Garmin's final recording remains a separate source until explicit reconciliation in 12.
