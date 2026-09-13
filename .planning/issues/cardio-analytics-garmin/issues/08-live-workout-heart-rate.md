# 08: Show live HR during an active workout

**What to build:** Connect the user's Garmin wearable through one validated local
transport and display current HR with truthful connection/freshness state during
strength or cardio workouts.

**Blocked by:** None (can start immediately).

**External gate:** Actual watch model/firmware and physical Android testing; Companion SDK licensing if that becomes the selected transport.

**Status:** ready-for-agent

Parent: [Garmin-connected cardio and health](../PRD.md).

- [ ] First verify compatible Bluetooth HR broadcast on the actual watch, including simultaneous watch activity recording. If unsuitable, evaluate licensed Companion SDK compatibility; choose and document one production adapter and supported device configuration.
- [ ] Pair/select a source, handle required permissions and attach it to the active workout. The local workflow does not depend on cloud account connection unless the selected transport requires it.
- [ ] Show paired, connecting, connected, stale, disconnected and unavailable states. Validate the proposed five-second stale threshold against real cadence; an old BPM cannot remain visually live.
- [ ] Reconnect after a short interruption without creating a second workout or blocking manual save/finish. Update only the HR display at most once per second.
- [ ] Document and implement supported screen-lock/background behavior. Return to the app with an accurate connection/gap state after lifecycle changes or process restart.
- [ ] Verify deterministic replay events through the active-workout interface, plus real-device simultaneous recording, permissions, screen lock and reconnection. Record hardware/firmware and measured results; mock success alone cannot establish support.
- [ ] Keep pairing/session configuration safe to restore without putting credentials in workout archives. Preserve existing workout behavior when no sensor is configured.

**Scope limit:** Live cloud polling cannot satisfy this ticket. Recording and post-workout analysis of samples is 09; remote start/stop of built-in Garmin activities is deferred.
