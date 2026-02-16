---
phase: quick-011
plan: 01
subsystem: infra
tags: [docker, sqlite3, ffi, deployment]

requires:
  - phase: 10-server-foundation
    provides: Dockerfile and server binary structure
provides:
  - Native sqlite3 library available in Docker runtime container
affects: [server deployment, backup push, dashboard queries]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - server/Dockerfile

key-decisions:
  - "Copy libsqlite3.so.0 from build stage rather than switching to debian:stable-slim runtime"

duration: 1min
completed: 2026-02-16
---

# Quick 011: Fix Server sqlite3 Missing in Docker Summary

**Install libsqlite3-dev in Docker build stage and copy libsqlite3.so to scratch runtime image**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-16T06:23:46Z
- **Completed:** 2026-02-16T06:24:10Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Fixed Dockerfile to install libsqlite3-dev in build stage
- Copy libsqlite3.so.0 from Debian build image to /app/lib/libsqlite3.so in scratch runtime
- Maintains minimal scratch-based runtime (no switch to debian:stable-slim)

## Files Created/Modified
- `server/Dockerfile` - Added libsqlite3-dev install in build stage, COPY of .so to runtime

## Decisions Made
- Kept `FROM scratch` runtime and copied only the .so file instead of switching to debian:stable-slim (smaller image, /runtime/ already provides libc dependencies)

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - rebuild Docker container with `docker compose build` and redeploy.

## Next Phase Readiness
- Server Docker container will have sqlite3 FFI available at runtime
- Backup push, backup listing, and dashboard queries should all work

---
*Quick task: 011-fix-server-sqlite3-missing-in-docker*
*Completed: 2026-02-16*
