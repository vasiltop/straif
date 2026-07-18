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

FROM debian:bookworm-slim

# Godot ships glibc binaries; musl+gcompat (e.g. Alpine) doesn't implement enough
# of glibc's surface for them to run (missing symbols like fcntl64, __res_init),
# so a real glibc base is required here.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libstdc++6 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

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
