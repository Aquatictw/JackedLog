---
phase: quick-011
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - server/Dockerfile
autonomous: true

must_haves:
  truths:
    - "Push backup from app succeeds (no 400 error about sqlite3_initialize)"
    - "Dashboard queries work (DashboardService also uses sqlite3 FFI)"
    - "List backups endpoint validates existing files without error"
  artifacts:
    - path: "server/Dockerfile"
      provides: "Docker build with native libsqlite3.so available at runtime"
      contains: "libsqlite3"
  key_links:
    - from: "server/Dockerfile"
      to: "server/lib/services/sqlite_validator.dart"
      via: "native sqlite3 library available at /app/lib/libsqlite3.so"
      pattern: "libsqlite3"
---

<objective>
Fix the server Docker container so the native sqlite3 library is available at runtime.

Purpose: The backup push endpoint returns 400 because the sqlite3 Dart FFI package
cannot find libsqlite3.so in the scratch-based runtime container. The compiled Dart
binary looks for the library at `/app/lib/libsqlite3.so` (relative to `/app/bin/server`).
Both `sqlite_validator.dart` and `dashboard_service.dart` use `package:sqlite3/sqlite3.dart`
which requires the native library.

Output: Updated Dockerfile that includes libsqlite3.so in the runtime image.
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@server/Dockerfile
@server/lib/services/sqlite_validator.dart
@server/lib/services/dashboard_service.dart
@server/pubspec.yaml
@server/docker-compose.yml
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix Dockerfile to include native libsqlite3.so</name>
  <files>server/Dockerfile</files>
  <action>
Update the Dockerfile to install sqlite3 native library in the build stage and copy it
to the runtime image.

The current Dockerfile:
- Build stage: `FROM dart:stable` - compiles Dart binary
- Runtime stage: `FROM scratch` - empty image, no system libraries

The Dart `sqlite3` FFI package resolves the native library relative to the executable.
The error shows it looks for `/app/lib/libsqlite3.so` (one directory up from
`/app/bin/server`, then into `lib/`). This is the default resolution path for
`package:sqlite3/src/ffi/libsqlite3.g.dart`.

Fix approach - install libsqlite3 in the build stage and copy it to runtime:

1. In the build stage, add `RUN apt-get update && apt-get install -y libsqlite3-dev && rm -rf /var/lib/apt/lists/*`
   Place this BEFORE `dart pub get` so Docker layer caching works well.

2. In the runtime stage, copy the shared library from the build image:
   `COPY --from=build /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /app/lib/libsqlite3.so`

   Note: The dart:stable image is Debian-based, so libsqlite3 installs to
   `/usr/lib/x86_64-linux-gnu/libsqlite3.so.0`. We copy it as `/app/lib/libsqlite3.so`
   which is the exact path the FFI loader expects (relative to `/app/bin/server`).

3. Also need to copy the dynamic linker and libc from the build stage since `FROM scratch`
   has nothing. However, `dart build cli` produces a self-contained executable that
   bundles the Dart runtime - the only external dependency is the sqlite3 shared library.
   BUT libsqlite3.so itself depends on libc, libm, libpthread, libdl, and ld-linux.

   The simplest reliable fix: Switch runtime from `FROM scratch` to `FROM debian:stable-slim`
   and install only the libsqlite3-0 runtime package. This adds ~80MB but is rock-solid.

   Actually, looking more carefully at the existing Dockerfile - `FROM scratch` with
   `COPY --from=build /runtime/ /` already copies the Dart runtime dependencies
   (libc, ld-linux, etc. - this is a Dart convention for AOT builds). So we just need
   the sqlite3 library itself.

Final Dockerfile should be:

```dockerfile
# Stage 1: Build
FROM dart:stable AS build
WORKDIR /app
RUN apt-get update && apt-get install -y libsqlite3-dev && rm -rf /var/lib/apt/lists/*
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart build cli bin/server.dart

# Stage 2: Runtime
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/build/cli/linux_x64/bundle/bin/server /app/bin/server
COPY --from=build /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /app/lib/libsqlite3.so

EXPOSE 8080
CMD ["/app/bin/server"]
```

Key details:
- `libsqlite3-dev` installs the library (could use `libsqlite3-0` for runtime-only,
  but `-dev` is fine in the build stage since it gets discarded)
- The .so.0 is the actual shared library (not a symlink in this context)
- Copy destination `/app/lib/libsqlite3.so` matches what the FFI loader expects
- The `/runtime/` copy from Dart's build already provides libc and other base libraries
  that libsqlite3.so depends on
  </action>
  <verify>
User rebuilds and deploys Docker container, then tests:
1. `docker compose build` completes without errors
2. Push backup from app succeeds (no 400 error)
3. Dashboard page loads and shows data

If the `/usr/lib/x86_64-linux-gnu/libsqlite3.so.0` path doesn't exist in the dart:stable
image, check with: `docker run --rm dart:stable find / -name "libsqlite3*" 2>/dev/null`
and adjust the COPY source path accordingly.
  </verify>
  <done>
Dockerfile includes libsqlite3.so in runtime image. The backup push endpoint
no longer returns 400 with "Couldn't resolve native function 'sqlite3_initialize'" error.
  </done>
</task>

</tasks>

<verification>
After deploying the updated container:
1. POST /api/backup with a valid .db file returns 200 (not 400)
2. GET /api/backups returns list with validation info (uses sqlite3 to read version)
3. Dashboard endpoints return data (DashboardService uses sqlite3 to query backups)
</verification>

<success_criteria>
- Docker build completes successfully
- Backup push from app works without sqlite3 native library errors
- All sqlite3-dependent server features (validation, dashboard queries) function correctly
</success_criteria>

<output>
After completion, create `.planning/quick/011-fix-server-sqlite3-missing-in-docker/011-SUMMARY.md`
</output>
