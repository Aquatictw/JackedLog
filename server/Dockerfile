# Stage 1: Build
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart build cli bin/server.dart

# Stage 2: Runtime
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/build/cli/linux_x64/bundle/bin/server /app/bin/server

EXPOSE 8080
CMD ["/app/bin/server"]
