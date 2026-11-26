# syntax=docker/dockerfile:1
# Browser assets are architecture-independent; build with the native host SDK.
FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS build

# Match the SDK used for development; override with --build-arg if needed.
ARG FLUTTER_VERSION=3.50.0
ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_ROOT=/opt/flutter \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH \
    CI=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 --branch "$FLUTTER_VERSION" \
       https://github.com/flutter/flutter.git "$FLUTTER_ROOT" \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
COPY packages/ ./packages/
RUN flutter pub get

COPY lib/ ./lib/
COPY assets/ ./assets/
COPY web/ ./web/
ARG MUSLIM_API_URL=https://api-muslim.bplusplus.uk/
RUN flutter build web --release --no-pub --no-web-resources-cdn \
    --dart-define=MUSLIM_API_URL="$MUSLIM_API_URL"

# Non-root Nginx keeps its PID and temporary files under the writable /tmp mount.
FROM nginx/nginx-unprivileged:stable-alpine AS runtime
COPY deploy/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web/ /usr/share/nginx/html/
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
