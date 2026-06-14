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
# Baked at build time (CI passes the git SHA) so the server knows its commit
# and the update checker can compare it against main.
ARG JACKED_COMMIT=unknown
ENV JACKED_COMMIT=$JACKED_COMMIT
COPY --from=build /runtime/ /
COPY --from=build /app/build/cli/linux_x64/bundle/bin/server /app/bin/server
COPY --from=build /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /app/lib/libsqlite3.so

EXPOSE 9091
CMD ["/app/bin/server"]
