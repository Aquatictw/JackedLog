# 04: Keep imports current and recover older runs

**What to build:** Keep imported runs correct through provider updates, local
corrections and deletions, and let the user request a bounded historical import
with visible progress and retry/cancel behavior.

**Blocked by:** 03 — Automatically import new Garmin runs.

**External gate:** Approved revision, deletion and historical-delivery contracts and limits.

**Status:** ready-for-agent

Parent: [Garmin-connected cardio and health](../PRD.md).

- [ ] Apply supported provider corrections using revision ordering; duplicate, reordered and overlapping live/backfill deliveries converge on one effective activity.
- [ ] Store explicit user overrides separately from provider evidence. Editing distance, duration or notes remains effective after later provider refreshes, with a visible option to reset an override.
- [ ] Distinguish provider deletion, local deletion and revocation. A local tombstone prevents replay/backfill resurrection; an intentional restore clears it. Define how a provider-deleted record with user edits is retained or removed and expose the result.
- [ ] Offer only contract-supported bounded date ranges and show requested, importing, completed, partial-failure and cancelled progress. Respect provider quotas and keep manual logging responsive.
- [ ] Survive worker/phone restart mid-backfill, account disconnect and interrupted cursor batches without losing acknowledged work or crossing account boundaries.
- [ ] Round-trip overrides, provider identities and tombstones in versioned archives. Restoring an older archive and reconnecting must have a documented reconciliation rule that cannot silently duplicate records.
- [ ] Test corrections, deletions, replay, local edits and interrupted backfill through the same public import-to-query seam; assert effective totals and original evidence, not worker internals.

**Scope limit:** Manual/imported record linking is a separate user decision in 05; this slice establishes the source/override lifecycle it needs.
