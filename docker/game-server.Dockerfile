# syntax=docker/dockerfile:1
#
# Lightweight runtime image for a Straif dedicated game server.
#
# The Godot Linux binary is built on a dev machine (scripts/export-linux.sh) and
# only COPIED in here, so this image is cheap to (re)build even on a small droplet.
# There is nothing to compile, so a single stage is correct.
#
# Build context is the repository root (see game-servers.compose.yaml) so that the
# exported `build/linux/` artifacts are available.

FROM alpine:3.20

# Godot ships glibc binaries; gcompat + libstdc++/libgcc let them run under musl.
RUN apk add --no-cache gcompat libstdc++ libgcc

WORKDIR /app

# Prebuilt Linux export: straif.x86_64 + straif.pck (+ any addon .so files).
COPY build/linux/ ./
RUN chmod +x ./straif.x86_64

# Dedicated-server parameters (override per instance).
ENV SERVER_NAME="Straif" \
    PORT="3005" \
    MAX_PLAYERS="8" \
    MODE="deathmatch"

# `straif.x86_64 server <name> <port> <max_players> <mode> --headless`
ENTRYPOINT ["sh", "-c", "exec ./straif.x86_64 server \"$SERVER_NAME\" \"$PORT\" \"$MAX_PLAYERS\" \"$MODE\" --headless"]
