# 11: Review Garmin laps, splits and best efforts

**What to build:** Open an imported run and inspect device laps, kilometre/mile
splits and evidence-backed fixed-distance best efforts with accurate pause handling.

**Blocked by:** 03 — Automatically import new Garmin runs; 10 — Replace cardio maxima with pace and volume trends.

**External gate:** Authorized detailed Garmin recordings and anonymized FIT fixtures covering pauses/laps.

**Status:** needs-info

Review draft; becomes ready-for-agent after breakdown approval. Parent: Garmin-connected cardio and health.

- [ ] Import the authorized timeline/lap evidence needed for distance and elapsed time; preserve device laps separately from derived distance splits and source revision.
- [ ] Show kilometre/mile splits with a labelled partial final split. Keep elapsed, timer and moving time distinct; indicate summary-only or insufficient evidence rather than fabricating splits.
- [ ] Derive supported fixed-distance best efforts from chronological distance evidence using elapsed time across pauses. Handle discontinuities, non-monotonic distance and sparse recordings with an explicit eligibility rule.
- [ ] Keep manual exact-distance efforts labelled separately from verified rolling efforts; a summary-only 5 km entry cannot claim a rolling 1 km best.
- [ ] Scope comparisons to compatible sport/environment and expose the recording/time basis behind a record. Changes to source evidence recompute affected derived results without duplicating rows.
- [ ] Include detailed evidence in versioned archives with bounded processing and transactional failure behavior. Avoid collecting or displaying route coordinates if they are unnecessary for this slice.
- [ ] Test approved detailed recordings through import and visible lap/effort queries, including pauses, partial final splits, mixed units, insufficient evidence, repeated delivery and revised source data.

**Scope limit:** A route map and grade-adjusted pace model are not required. This slice can use revision replacement already supported by 03; comprehensive lifecycle behavior from 04 integrates through the same import boundary.
