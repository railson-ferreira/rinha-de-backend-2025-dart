# Use latest stable channel SDK.
FROM dart:3.8-sdk AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
COPY shared_kernel shared_kernel
RUN dart pub get

# Copy app source code (except anything in .dockerignore) and AOT compile app.
COPY . .
RUN dart compile exe bin/main.dart -o bin/bootstrap

# Build minimal serving image from AOT-compiled `/server`
# and the pre-built AOT-runtime in the `/runtime/` directory of the base image.
FROM alpine:latest
RUN apk add --no-cache sqlite sqlite-dev
COPY --from=build /runtime/ /
COPY --from=build /app/bin/bootstrap /app/bin/

# Start server.
EXPOSE 8080
CMD ["/app/bin/bootstrap"]