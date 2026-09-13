# 05: Link imported and manually logged cardio

**What to build:** Suggest plausible existing cardio matches for an imported run,
let the user confirm or reject a link, and retain one effective session for history
and totals without losing either source.

**Blocked by:** 04 — Keep imports current and recover older runs.

**Status:** needs-info

Review draft; becomes ready-for-agent after breakdown approval. Parent: Garmin-connected cardio and health.

- [ ] Suggest candidates using compatible sport, source time overlap and measurements; timestamp proximity alone never merges activities. Ambiguous or unknown legacy times remain explicit.
- [ ] Confirm a link with a preview of effective distance/time and preserved manual notes/overrides. Keep stable local identities and original provider evidence with a single counting relationship.
- [ ] Support unlinking with understandable totals and no evidence loss. Reject cycles, cross-owner links and conflicting use of the same provider activity.
- [ ] Preserve imported association and metadata across a legacy bout's temporary undo-completion/recompletion before exposing linking to that bout. Do not silently recreate deleted records or discard provider identity through a trigger rebuild.
- [ ] Existing legacy editing, raw units, standalone activities, migration and old archive restore stay valid through an expand–contract change; do not retire legacy consumers in this ticket.
- [ ] Distinguish explicit deletion from temporary recording state and specify which data the user retains on unlink/delete. Provider refresh cannot remove explicit user overrides.
- [ ] Verify link, undo/recomplete, unlink, delete, replay and backup/restore through actual store/import/archive interfaces. History and aggregate queries count the effective session once throughout.

**Scope limit:** This links cardio activities. Linking a final watch recording to a lifting workout and choosing an effective HR trace is 12.
