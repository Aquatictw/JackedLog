# 03: Automatically import new Garmin runs

**What to build:** After a watch uploads a completed run to Garmin Connect, show
that run automatically in JackedLog history and detail, including offline catch-up.

**Blocked by:** 01 — Recorded cardio history and manual entry; 02 — Connect Garmin and report connection state.

**External gate:** Approved Activity API deliveries and anonymized example recordings.

**Status:** needs-info

Review draft; becomes ready-for-agent after breakdown approval. Parent: Garmin-connected cardio and health.

- [ ] Receive verified activity notifications into the durable owner/account inbox, acknowledge only persisted work and retry authorized downloads after transient failures or server restart.
- [ ] Normalize approved run/walk sport mappings, timestamps, canonical measurements and distinct available time bases into standalone recorded activities. Preserve unavailable values and unsupported sports explicitly.
- [ ] Enforce owner/account/external-activity uniqueness on both server changes and phone application; duplicate delivery or phone retry produces one activity and one contribution to totals.
- [ ] Carry source revision/hash and stable local identity from the first import. Refuse an older known revision from overwriting newer evidence; later corrections extend this path in 04.
- [ ] Show source, time basis, last successful sync and clear import/retry states. Explain that a run must first upload to Garmin; do not claim visibility into a watch upload that the service cannot observe.
- [ ] A disconnected phone automatically consumes bounded cursor batches on reconnection, atomically applying each batch. A failed local transaction cannot advance the cursor.
- [ ] Include new provenance/time-basis entities in versioned workout archives with old archive compatibility; full database backups restore offline viewing. Exclude credentials.
- [ ] Verify an approved payload through authenticated ingress, worker, local SQLite and visible history queries, including duplicate delivery, restart, missing fields, malformed recordings and offline catch-up.
- [ ] Disconnect stops future imports; deleting retained provider data removes this slice's records and prevents pending jobs from recreating them.

**Scope limit:** Summary/detail import is useful without laps, historical backfill or automatic matching. Do not silently merge nearby manual records.
