# 06: View all-day heart rate

**What to build:** Show an offline-capable daily HR timeline, available resting HR,
coverage and last update after consenting to Garmin health access.

**Blocked by:** 02 — Connect Garmin and report connection state.

**External gate:** Approved Health API HR entitlement and payload contract.

**Status:** needs-info

Review draft; becomes ready-for-agent after breakdown approval. Parent: Garmin-connected cardio and health.

- [ ] Reuse the durable owner/account inbox and phone cursor for verified health changes while keeping daily health normalization independent from cardio activities and workout samples.
- [ ] Retain provider day, offset/time zone, sample timestamps, revision, provenance and availability. Apply late/replayed changes idempotently without creating a second day.
- [ ] Show daily HR and available resting HR with gaps, source, last successful update and permission/unavailable states; absent data is not zero or a live reading.
- [ ] Cache daily views for offline use, bound chart points and fetch only the requested range. Travelling or DST changes cannot silently reassign a stored provider day.
- [ ] Disconnect retention/deletion choices apply to all daily HR records and queued changes. Keep raw health data out of logs and coach context.
- [ ] Extend versioned archives for daily HR/provenance without credentials and retain old archive support; restored health remains readable offline.
- [ ] Test approved deliveries through real ingestion/local persistence and daily queries, covering missingness, out-of-order revisions, timezone boundaries, cursor rollback, owner isolation and disconnect.

**Scope limit:** Cloud all-day HR is post-sync context; this screen is not the live workout sensor display. Running imports do not block this slice.
