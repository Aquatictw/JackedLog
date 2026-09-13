# Garmin-connected cardio and health

Status: ready-for-agent

Date: 2026-09-13
Architecture baseline: commit e4ca838b, schema 73; 321 tests passing.

## Problem Statement

JackedLog records gym workouts, but runs saved on a Garmin watch do not arrive
automatically. The user has to enter them again and cannot see the day's heart
rate, sleep, stress or recovery context beside their training. During a workout,
JackedLog also cannot show current heart rate from their Garmin wearable.

The legacy cardio experience still emphasizes independent maxima such as longest
time and highest incline. Running progress instead needs reliable distance, pace,
weekly volume, and effort context, with one activity counted once even when the
watch and JackedLog both recorded parts of the session.

## Solution

Deliver three independently useful capabilities: automatic completed-run import
from Garmin Connect; a daily health view for heart rate, sleep, stress and available
recovery context; and a live heart-rate display inside an active JackedLog workout.

After account connection and consent, a run uploaded by the watch to Garmin Connect
appears in JackedLog without a manual file import. This is the requested
Strava-like experience. It is eventual synchronization after Garmin upload, not
an assertion of instant delivery while the watch is recording. The phone catches
up automatically when it can connect and retains imported data for offline use.

Recorded cardio already has its own identity and canonical measurements in schema
73. Build on that model and its migration adapter. Add a visible activity list
and detail experience, source-aware synchronization, daily health records, and
recording evidence only as the corresponding user-facing slice needs them.

## User Stories

1. As a Garmin runner, I want to connect my Garmin account once, so that saved runs arrive automatically.
2. As a user, I want to understand and choose activity and health permissions, so that I know what data JackedLog will receive.
3. As a runner, I want a run to appear after my watch uploads it, so that I do not log it twice.
4. As an offline user, I want missed imports to catch up when I reconnect, so that I can train without connectivity.
5. As a runner, I want imported runs visible in history, so that all my training is in one place.
6. As a runner, I want distance, time and pace on the activity detail screen, so that the summary matches how I judge a run.
7. As a treadmill user, I want indoor/outdoor context and machine information preserved, so that unlike sessions are not misleadingly compared.
8. As a runner, I want kilometres/miles and pace units to follow my preference, so that I can read familiar measurements.
9. As a runner, I want weekly distance, cardio minutes and activity count, so that I can see consistency and volume.
10. As a runner, I want weighted pace trends for comparable activities, so that short and long runs do not distort an average.
11. As a runner, I want laps and distance splits when the recording supports them, so that I can inspect pacing.
12. As a runner, I want pauses and elapsed time kept distinct, so that a pause does not produce a misleading best effort.
13. As a manual logger, I want to keep entering cardio without Garmin, so that account availability never blocks logging.
14. As a user, I want automatic import retries to update one activity, so that my weekly totals are not doubled.
15. As a user, I want to link a Garmin run to an existing manual activity, so that both describe the same training session.
16. As a user, I want ambiguous matches offered for review, so that two nearby runs are not silently merged.
17. As a user, I want my explicit corrections to survive later Garmin updates, so that synchronization does not undo my edits.
18. As a user, I want deleted activities to stay deleted through replay and backfill, so that cleanup is respected.
19. As a user, I want a clear last-sync time and actionable failure state, so that missing data is understandable.
20. As a user, I want a bounded history import with progress, so that I can bring in earlier runs without freezing the app.
21. As a user, I want an all-day heart-rate timeline and available resting-heart-rate summary, so that I can see daily context.
22. As a user, I want the latest sleep episode and recent sleep trend, so that I can relate sleep to training.
23. As a user, I want daily stress information, so that I can see the broader day's demands.
24. As a user, I want available Body Battery and other approved recovery indicators shown with their source, so that I can review recovery context.
25. As a user, I want unavailable or stale health measurements labelled clearly, so that missing data is not mistaken for zero or a fresh reading.
26. As a traveller, I want health days and sleep episodes assigned consistently across time zones, so that travel does not duplicate or shift my history unpredictably.
27. As a lifter, I want current heart rate on my active workout, so that I can see my effort without switching apps.
28. As a runner, I want the same live-heart-rate connection available during cardio, so that I have one sensor workflow.
29. As a user, I want connected, stale and disconnected sensor states, so that an old value never looks live.
30. As a user, I want brief sensor interruptions to reconnect automatically, so that I can continue training.
31. As a user, I want live heart-rate capture to survive supported screen-lock/background conditions, so that putting my phone away does not silently stop the record.
32. As a user, I want recorded workout HR and time in configured zones, so that I can review effort after finishing.
33. As a user, I want data gaps excluded from HR averages and zone duration, so that poor sensor coverage does not create invented training evidence.
34. As a user, I want final watch data reconciled with provisional live samples, so that one workout does not contain doubled time or samples.
35. As a user, I want to finish a workout even if Garmin is unavailable, so that network or sensor problems cannot lose my log.
36. As a user, I want to disconnect and choose what imported data to retain, so that I remain in control of the integration.
37. As a user, I want new activities and health evidence included in backups, so that changing phones does not lose context.
38. As a self-hosting user, I want Garmin synchronization to work without configuring the AI coach, so that unrelated setup does not block it.
39. As a user, I want raw health and route data kept out of normal logs and coach prompts, so that integration does not silently broaden data sharing.
40. As a user with an unsupported watch or missing Garmin entitlement, I want a precise explanation and functioning manual logging, so that the app remains useful.

## Implementation Decisions

### Recorded cardio and compatibility

- Keep the existing recorded cardio module, canonical metres/seconds, stable
  identities and legacy bout adapter. The architecture phase is complete; do not
  reimplement it as a prerequisite ticket.
- A standalone run is a recorded cardio activity, with no fabricated weight/reps
  row. Add activity list/detail navigation and combine workout/activity history
  with explicit identities and types. Strength sets and cardio counts remain
  separate; an activity linked to a workout is not displayed or counted twice.
- Preserve legacy raw measurements and ambiguous duration basis. Do not infer a
  sport from an exercise name or interpret a completion timestamp as a start.
- The legacy adapter is the expansion stage. Existing undo-completion removes a
  recorded legacy projection. Before linking imported evidence to that editable
  bout, make the association/evidence survive temporary recording-state changes;
  only explicit deletion may discard it. Keep old editors and imports functional
  until their consumers have migrated.
- Workout ZIP and full-database backup are real compatibility seams. Extend the
  versioned archive for every new persisted entity in its owning ticket; old
  archives remain importable. Never ship new persisted data that only exists
  outside supported backups. Credentials are excluded and restored connections
  require reauthorization.

### Automatic Garmin run import

- Use the approved Garmin Connect Activity API for uploaded run activities and
  detailed recordings. It supplies activity data after device upload and consent;
  the app must distinguish Waiting for Garmin upload, Importing, Synced, and
  actionable failure states. [Garmin Activity API](https://developer.garmin.com/gc-developer-program/activity-api/)
- Reuse the optional self-hosted server as the durable inbound receiver. Decouple
  its Garmin configuration/startup from required coach credentials and knowledge.
  Garmin stays opt-in; the local app does not need a server for manual logging.
- Store provider credentials only on the server; encrypt user tokens at rest.
  The current shared app key is not a Garmin account identity. Bind callbacks,
  tokens, jobs and device cursors to an authenticated installation/owner and
  provider account, and reject cross-owner access. Initial scope is one Garmin
  account per owner; do not build a general multi-tenant account product.
- Garmin's program currently uses OAuth 2.0 and requires business/enterprise
  approval. Exact scopes, token handling, webhook verification, retry and backfill
  contracts come from the approved portal. Do not invent endpoints, signatures,
  entitlements or polling quotas. [Garmin Program FAQ](https://developer.garmin.com/gc-developer-program/program-faq/)
- A browser authorization callback validates state and the approved redirect/PKCE
  requirements. Public provider callback/notification ingress is narrowly
  separated from application bearer-authenticated endpoints and verified using
  Garmin's actual contract. Invalid deliveries never enter the owner's inbox.
- Persist each valid delivery before acknowledging it. A retryable worker obtains
  authorized recording data and emits versioned normalized activity changes. The
  phone applies a cursor batch transactionally; advance its cursor only with the
  successful local commit. No whole-database upload/download is used for sync.
- Uniqueness is owner + Garmin account + external activity identity, not a name,
  timestamp or local integer ID. Keep stable local activity identity plus source
  revision/hash and tombstones. Duplicate or out-of-order delivery converges to
  one activity. Restarting either side does not lose acknowledged work.
- Import run/walk subtypes using verified Garmin sport mappings. Preserve unknown
  types in the inbox with an unsupported-type state; do not misclassify cycling
  as running. Garmin-imported runs preserve actual source timestamps, distance,
  time bases, and provenance, including summary-only availability.
- Explicit user links win. Automatic matching may suggest candidates using sport,
  time overlap, duration and distance, but proximity alone never merges entries.
  Preserve the manual record until a link is confirmed. One effective activity
  owns totals. Separate source evidence and user overrides, with explicit edits
  taking precedence over subsequent provider refreshes.
- Import correction, provider deletion, local deletion and consent revocation have
  different semantics. A locally deleted provider activity has a tombstone that
  prevents accidental resurrection. Intentional restore clears it explicitly.
  Disconnect cancels future work and offers retention or deletion of local data.

### All-day health and recovery context

- Use Garmin Connect Health API feeds for all-day HR, sleep and stress. Show
  available Body Battery as recovery context. Resting HR, sleep details and any
  further recovery metrics must be confirmed in the approved contract; training
  readiness, recovery time, HRV or proprietary scores are not assumed available.
  [Garmin Health API](https://developer.garmin.com/gc-developer-program/health-api/)
- Daily health is its own module, not cardio activity samples. Keep account/source,
  provider day and offset/time zone, receipt/revision times, metric availability,
  and nullable normalized values. Sleep episodes retain their interval and
  provider sleep-day assignment across midnight. Late corrected sleep updates
  replace the source revision without creating another episode.
- A shared durable import inbox/cursor mechanism can carry health changes, while
  health normalization and query rules remain independent from activity totals.
  Permit granular activity/health consent and show unavailable permissions.
- Daily views show source, last update, coverage and missing data. Never turn
  absent samples into zero HR, zero sleep or low stress. Keep all-day samples
  separate from the higher-resolution recording used for workout effort.
- Recovery context is a display of available source measurements and their recent
  trends. Do not invent a medical readiness verdict or reproduce an unavailable
  Garmin score. Health data is not automatically added to AI coach context.

### Live workout heart rate

- Live HR is a local device path; cloud Health API synchronization cannot satisfy
  it. Evaluate a compatible Bluetooth HR broadcast on the actual watch first.
  If unsuitable, evaluate the licensed Garmin Companion SDK, which supports live
  streams alongside Garmin Connect. The Standard SDK does not preserve that
  Garmin Connect model. [Garmin Health SDKs](https://developer.garmin.com/health-sdk/overview/)
- Choose one production adapter only after model/firmware validation. Record
  transport, required permissions/licensing, supported simultaneous watch activity,
  Android background behavior and reconnect behavior. Do not install a speculative
  watch SDK or promise support for every Garmin model.
- Show BPM, source and freshness in an active workout without needing cloud
  authorization if the chosen local transport does not require it. Define paired,
  connecting, connected, stale, disconnected and unavailable states. Proposed
  default: a reading becomes stale after five seconds without a fresh sample;
  validate transport cadence and never silently carry it through a gap.
- Starting the phone workout attaches the selected sensor; finishing remains a
  local action. A sensor failure cannot prevent save/finish or start a second
  recording. Clock alignment uses source timestamps where available and a
  documented receive-time fallback.
- Buffer samples and write in transactions; flush on supported lifecycle events.
  Update the HR label at most once per second and only rebuild that display.
  A process restart recovers the active session and marks any unobserved gap.
- Preserve provisional live evidence and final watch evidence as distinct sources.
  Select one effective trace for each recording interval; do not concatenate or
  sum both. Linking to a lifting workout must not manufacture a run activity.

### Cardio analytics

- Running uses minutes/km or minutes/mile; cycling uses speed. Rename the legacy
  speed-valued “pace” selection explicitly when adding real pace. Display the
  selected time basis; preserve elapsed, timer and moving duration separately.
- A period pace is total paired duration divided by total paired distance for the
  same sport/environment and time basis. Time-only activities contribute to
  cardio minutes, not pace. For 1 km/5 min and 4 km/24 min, show 5:48 min/km.
- Weekly distance/minutes/session counts use the activity's source-local start
  date where known, otherwise its labelled recording date. Count each effective
  activity once, including warmup/recovery in volume, excluding strength rest.
- Laps and automatic distance splits require timeline evidence. Preserve device
  laps separately from kilometre/mile splits and label partial final splits.
  Fixed-distance best efforts use elapsed time; do not reward paused timers.
  Manual exact-distance efforts remain labelled separately from verified rolling
  efforts. Summary-only runs cannot claim a rolling 1 km or 5 km best.
- HR averages are time-weighted across valid observed intervals. Zone duration
  uses configured thresholds/version and a defined gap policy, with uncovered
  time shown separately. Imported and manually entered summary HR remain distinct.
- Remove highest-incline and the existing exponential “adjusted speed” from the
  default progress story; preserve legacy record badges until their replacement
  view ships. Do not present the existing formula as validated grade-adjusted pace.

## Testing Decisions

- Prefer public user-flow seams: recorded-activity save/read/delete, the actual
  workout archive, and authenticated sync ingestion through local persistence to
  activity/health queries. Assert outcomes, idempotence and retained data, not
  private helper calls or a mock that repeats the implementation.
- Use the existing real SQLite and versioned-backup test patterns. The architecture
  baseline already covers old-database migration, independent activity persistence,
  original-unit edits, invalid data, rollback and archive round trips.
- Use approved anonymized Garmin payload/FIT fixtures at the import seam. Tests
  must cover duplicate and reordered deliveries, corrections, tombstones, partial
  data, unknown sport, mixed units, pauses, invalid timestamps and malformed files.
- Verify owner/account isolation, forged callback state, unauthorized ingress,
  renewal/reconsent, server restart after acknowledgment, offline phone catch-up,
  cursor rollback, bounded backfill, and disconnect with queued work.
- Verify daily HR missingness, sleep across midnight/DST, provider-day offsets,
  revised sleep/stress summaries, account switching and unavailable recovery fields.
- Use a deterministic replay sensor behind the same live interface for stale,
  disconnect, duplicate/out-of-order samples, lifecycle and zone coverage tests.
  A fake sensor is not evidence of Garmin hardware support: require the selected
  real device for simultaneous recording, lock-screen, permission and reconnect
  acceptance before declaring live support shipped.
- Test final-watch versus provisional-live reconciliation using one linked
  activity and one lifting workout; counts, duration and zones cannot double.
- Protect responsiveness with bounded chart points, paged summaries and batched
  writes. Proposed release/profile targets on the actual Android device: current
  HR UI refresh at most 1 Hz, roughly 500–1,000 visible chart points, and p95 cached
  summary interaction below 200 ms on 10,000 activities. Measure before claiming
  a speedup; debug-mode animation is not an acceptance signal.

## Out of Scope

- Implementing Garmin cloud/live connectivity during the completed architecture
  commit; this spec and its tickets define the next work.
- Reverse-engineered Garmin Connect login/scraping or collecting Garmin passwords.
- A new subscription service, general provider marketplace, or new app-wide state
  management framework.
- Automatic start/stop of built-in watch activities and outbound Garmin training
  plan export. Earlier workout-start ideas remain a separate later investigation;
  they are not prerequisites for the user's three confirmed integrations.
- Medical recommendations, invented readiness/VO2Max scores, or sending health data
  to the coach by default.
- Removing the legacy bout adapter before all affected consumers and backups can
  remain correct through an expand–contract migration.

## Further Notes

Garmin approval/credentials, the watch model/firmware and the production live-HR
transport are not yet supplied. This is a complete implementation direction with
explicit external gates, not proof that access has been granted. Existing manual
tracking remains usable through all phases.

Architecture work is already committed; it should not appear as a fresh blocker
in the implementation ticket graph. Ticket review should focus on the public test
seams above, slice sizes and genuine dependency edges. Each delivered slice must
include its user-facing state, data persistence, compatibility and tests.
