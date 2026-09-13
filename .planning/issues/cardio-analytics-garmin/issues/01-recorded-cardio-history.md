# 01: Recorded cardio history and manual entry

**What to build:** Let a user create and revisit a standalone recorded cardio
activity, with distance, duration, sport, environment and notes. Put it in history
and detail navigation alongside workouts without fabricating a strength set.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

Parent: [Garmin-connected cardio and health](../PRD.md).

- [ ] Create, edit and delete an independent run offline through the existing recorded activity store; unit preferences convert at the boundary while canonical values remain metres/seconds.
- [ ] Show distance, duration, actual pace when supported and source on an activity detail screen. Missing distance or ambiguous time basis has an explicit state, never an invented pace.
- [ ] Paginate mixed history using stable typed identities; a workout-associated activity has one intentional presentation, and selecting a standalone chart/history entry reaches its detail directly.
- [ ] Preserve legacy raw units, unknown measurements, timestamp meaning and existing bout editing. Do not guess running from an old exercise name.
- [ ] Keep activity count distinct from strength sets and link to the containing workout where present. A workout with several actual cardio bouts retains those separate activities.
- [ ] Verify public save/read/delete, history navigation and existing workout ZIP round trips with standalone and legacy activities. Old ZIPs and upgraded databases remain usable.
- [ ] Profile a paged history with 10,000 activities on the target device; avoid full history reloads on each edit and report measured results.

**Scope limit:** This slice introduces activity navigation and entry, not cloud import, samples or the complete trend dashboard.
