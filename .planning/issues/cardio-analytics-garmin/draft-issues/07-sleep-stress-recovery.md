# 07: View sleep, stress and recovery context

**What to build:** Extend the daily health view with the latest sleep episode,
stress and available Body Battery, plus recent trends and explicit coverage.

**Blocked by:** 06 — View all-day heart rate.

**External gate:** Approved sleep/stress/Body Battery fields and any additional metric entitlements.

**Status:** needs-info

Review draft; becomes ready-for-agent after breakdown approval. Parent: Garmin-connected cardio and health.

- [ ] Normalize supported sleep intervals, stress summaries and available recovery context into source-specific daily records using the existing health sync path.
- [ ] Keep sleep start/end and provider sleep-day assignment across midnight, travel and DST. Corrected episodes replace their source revision without adding another night's sleep.
- [ ] Show source, freshness and unavailable/permission states per metric; partial permissions do not hide already available HR or manual training.
- [ ] Present recent sleep/stress/available Body Battery trends. Do not manufacture readiness scores or assume training readiness, recovery time or HRV availability without approved evidence.
- [ ] Missing measurements remain absent, not zero sleep or low stress. Keep source metric meanings and scales in the displayed labels.
- [ ] Extend disconnect deletion and versioned archive round trips to every new entity; health is not silently added to AI coach prompts.
- [ ] Test daily queries from approved payloads, late revisions, overlapping sleep intervals, unavailable metrics and timezone changes. Bound visible query ranges and chart data on the device.

**Scope limit:** This is training context, not medical advice or a recreated Garmin readiness algorithm.
