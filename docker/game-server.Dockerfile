# syntax=docker/dockerfile:1
#
# Lightweight runtime image for a Straif dedicated game server.
#
# The Godot Linux binary is built on a dev machine (scripts/export-linux.sh) and
# only COPIED in here, so this image is cheap to (re)build even on a small droplet.
# There is nothing to compile, so a single stage is correct.
#
# Godot ships glibc binaries (and the GodotSteam .so links libsteam_api.so), so we
# use a glibc base -- musl/Alpine fails with res_init/fcntl64 relocation errors.
#
# Build context is the repository root (see game-servers.compose.yaml) so that the
# exported build/linux/ artifacts are available.

FROM debian:bookworm-slim

# ca-certificates is needed for the server's HTTPS heartbeat to the API.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Prebuilt Linux export: straif.x86_64 (pck embedded) + GodotSteam .so files.
COPY build/linux/ ./
RUN chmod +x ./straif.x86_64

# Let the GodotSteam extension find libsteam_api.so next to the binary.
ENV LD_LIBRARY_PATH=/app \
	SERVER_NAME="Straif" \
	PORT="3005" \
	MAX_PLAYERS="8" \
	MODE="deathmatch"

# straif.x86_64 server <name> <port> <max_players> <mode> --headless
ENTRYPOINT ["sh", "-c", "exec ./straif.x86_64 server \"$SERVER_NAME\" \"$PORT\" \"$MAX_PLAYERS\" \"$MODE\" --headless"]
