# 10: Replace cardio maxima with pace and volume trends

**What to build:** Let users judge cardio by actual pace, weekly distance,
cardio minutes and consistency using standalone and legacy recorded activities.

**Blocked by:** 01 — Recorded cardio history and manual entry.

**Status:** implemented; physical-device interaction profiling pending

Parent: [Garmin-connected cardio and health](../PRD.md).

- [x] Show running pace in minutes/km or minutes/mile and cycling speed with explicit sport/environment/time-basis filters. Rename the legacy speed-valued pace selection so its meaning is unambiguous.
- [x] Aggregate pace as total paired duration divided by total paired distance within the selected compatible group: 1 km/5 min plus 4 km/24 min displays 5:48 min/km, not the arithmetic average of activity paces.
- [x] Show weekly distance, cardio minutes and session count using source-local start date when known, otherwise labelled recording date. Include warmup/recovery cardio in volume and exclude strength rest.
- [x] Count each effective activity once; use the activity query boundary so links delivered later by 05 cannot double aggregates. Time-only entries contribute minutes but no invented distance/pace.
- [x] Treat migrated unknown sport/time basis explicitly and let users classify entries without overwriting raw historical evidence. Do not infer run records from arbitrary exercise names.
- [x] Replace highest-incline/longest-duration emphasis on the default progress view with meaningful volume and pace trends; do not present the old adjusted-speed formula as validated grade-adjusted pace. Retain legacy badge behavior until its replacement is demonstrably covered.
- [x] Test actual SQLite query results for mixed units, absent/invalid values, paired data, multiple bouts, timezone boundaries and effective identity. Verify chart selection cannot display an older response after a newer request.
- [ ] Use paged/bounded summaries and roughly 500–1,000 visible chart points; measure the proposed p95 cached interaction target below 200 ms on 10,000 activities in release/profile mode.

**Scope limit:** This works with local data without Garmin access. Rolling best efforts and detailed splits require evidence delivered in 11.

## Implementation — phase 2 (2026-09-13)

Delivered a default cardio progress screen with weekly distance, minutes,
sessions and active weeks; running/walking weighted pace and cycling speed
require explicit comparison filters. The existing legacy speed selection is
labelled Speed, and legacy badges remain unchanged. At most 52 weekly summaries
are returned. Time-only and warm-up activities contribute to volume; each legacy
bout contributes exactly once through the recorded activity store.

Manual schema 74 adds an optional source UTC offset. New manual activities retain
their source-local calendar day after travel; older activities use an explicitly
labelled recording day in UTC. Archive metadata is additive and backwards
compatible. Classification preserves raw historical rows.

Validation: 58 focused tests pass, including the supplied schema-72 backup,
schema-73 upgrade, archive round trips, paired weighted pace, mixed-unit bouts,
missing measurements, week boundaries, identity and filter changes. The broader
suite before the final additional mixed-bout test had 320 passing tests and the
same 13 pre-existing failures confirmed at ca7ca404 (one opt-in backup test was
skipped without its environment variable).

Pixel 9a Android 15 emulator profile integration passes. With 10,000 activities,
30 samples after warm-up: weekly query median 7.701 ms, p95 9.016 ms, max 9.020 ms;
100-row history query median 2.766 ms, p95 3.697 ms, max 4.800 ms. These are database
query timings, not end-to-end interaction or physical-device acceptance. The last
checkbox remains open. The emulator's installed review build uses a separate,
locally sanitized copy of the supplied backup; the original file is unchanged
and excluded from commits. Visual review confirmed the entry and progress screens.
