# 12: Reconcile live HR with the final Garmin recording

**What to build:** When a final Garmin recording arrives, let the user associate
it with an already logged run or lifting workout and review one effective HR trace
without double-counting the workout.

**Blocked by:** 05 — Link imported and manually logged cardio; 09 — Review recorded workout HR and zones.

**External gate:** Approved final recording HR evidence, including supported non-run workouts where available.

**Status:** needs-info

Review draft; becomes ready-for-agent after breakdown approval. Parent: Garmin-connected cardio and health.

- [ ] Obtain authorized final HR evidence through the established durable import path and preserve it separately from provisional live samples. This ticket owns final-HR parsing; laps support is not a prerequisite.
- [ ] Offer explicit candidate links to a recorded cardio activity or a lifting workout. Do not automatically merge ambiguous time overlaps or turn a lifting workout into a run.
- [ ] Select one effective source per recording interval using a documented coverage/quality rule, with source labels and a user-visible fallback for incomplete final data. Keep original evidence available.
- [ ] Recompute observed average and configured zone durations through the existing effort query; overlapping live and final samples cannot double duration or observed time.
- [ ] Handle provider correction, unlinking, manual overrides and deletion using the lifecycle/identity rules from 04 and 05. A later replay cannot recreate a locally deleted association.
- [ ] Extend backup and disconnect deletion semantics to final evidence and links; old archives and live-only workouts remain valid offline.
- [ ] Verify one linked run and one lifting workout end to end, including clock offsets, partial overlap, gaps, delayed final upload, revision, unlink and archive restore. Assert one effective workout contribution and truthful coverage.

**Scope limit:** Starting/stopping built-in watch activities remotely remains deferred. This completes reconciliation of the three confirmed integrations, not outbound Garmin training plans.
