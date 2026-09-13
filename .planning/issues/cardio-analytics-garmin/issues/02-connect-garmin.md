# 02: Connect Garmin and report connection state

**What to build:** Connect a Garmin account from settings, see connection and
permission status on the phone, and disconnect. The optional server works without
AI coach configuration and delivers durable connection changes to the phone.

**Blocked by:** None (can start immediately).

**External gate:** Approved Garmin program credentials/contracts and an HTTPS callback deployment. Do not invent portal-only endpoints or scopes.

**Status:** ready-for-agent

Parent: [Garmin-connected cardio and health](../PRD.md).

- [ ] Deliver the approved OAuth 2.0 flow with state validation and the approved redirect/PKCE requirements. Show denied, expired, reconnect-required and unavailable-program states.
- [ ] Bind one Garmin account to an authenticated installation/owner; do not use the existing shared application key as provider identity. Reject cross-owner access to credentials, connection state and cursors.
- [ ] Keep client secrets and encrypted user tokens on the server, excluded from phone backups and ordinary logs. A restored installation reconnects explicitly.
- [ ] Run connection endpoints with Garmin configuration while coach configuration is absent; retain current coach behavior for configured installations.
- [ ] Persist verified connection/consent changes before acknowledgment and expose a bounded, versioned owner-scoped change cursor. The phone commits each batch and cursor together, showing a durable last-change/error state after restart.
- [ ] Separate public authorization/provider ingress from application authentication and verify each using the approved contract. Unverified ingress cannot change connection state.
- [ ] Disconnect revokes access where supported, cancels queued owner/account work and exposes the retention/deletion choice for imported data. Later entity slices must implement that choice for their records.
- [ ] Test authorization failure, renewal/reconsent, owner isolation, duplicate connection events, restart after acknowledgment, cursor rollback and disconnect races at the public connection/sync seam.

**Scope limit:** The durable change transport is exercised by visible connection changes here; activity and health normalization arrive in their own slices. This is not a general account-management product.
