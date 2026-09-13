# 10: Replace cardio maxima with pace and volume trends

**What to build:** Let users judge cardio by actual pace, weekly distance,
cardio minutes and consistency using standalone and legacy recorded activities.

**Blocked by:** 01 — Recorded cardio history and manual entry.

**Status:** ready-for-agent

Parent: [Garmin-connected cardio and health](../PRD.md).

- [ ] Show running pace in minutes/km or minutes/mile and cycling speed with explicit sport/environment/time-basis filters. Rename the legacy speed-valued pace selection so its meaning is unambiguous.
- [ ] Aggregate pace as total paired duration divided by total paired distance within the selected compatible group: 1 km/5 min plus 4 km/24 min displays 5:48 min/km, not the arithmetic average of activity paces.
- [ ] Show weekly distance, cardio minutes and session count using source-local start date when known, otherwise labelled recording date. Include warmup/recovery cardio in volume and exclude strength rest.
- [ ] Count each effective activity once; use the activity query boundary so links delivered later by 05 cannot double aggregates. Time-only entries contribute minutes but no invented distance/pace.
- [ ] Treat migrated unknown sport/time basis explicitly and let users classify entries without overwriting raw historical evidence. Do not infer run records from arbitrary exercise names.
- [ ] Replace highest-incline/longest-duration emphasis on the default progress view with meaningful volume and pace trends; do not present the old adjusted-speed formula as validated grade-adjusted pace. Retain legacy badge behavior until its replacement is demonstrably covered.
- [ ] Test actual SQLite query results for mixed units, absent/invalid values, paired data, multiple bouts, timezone boundaries and effective identity. Verify chart selection cannot display an older response after a newer request.
- [ ] Use paged/bounded summaries and roughly 500–1,000 visible chart points; measure the proposed p95 cached interaction target below 200 ms on 10,000 activities in release/profile mode.

**Scope limit:** This works with local data without Garmin access. Rolling best efforts and detailed splits require evidence delivered in 11.
