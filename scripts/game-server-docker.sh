#!/usr/bin/env bash
#
# Launch a single ad-hoc Straif dedicated game server in Docker.
#
# Builds the game-server image (from the prebuilt build/linux/ binary) if needed,
# then runs one named, UDP-port-mapped container. Use the compose file
# (docker/game-servers.compose.yaml) instead when you want a managed fleet.
#
# Usage:
#   ./scripts/game-server-docker.sh <name> <port> <max_players> <mode>
#
# Example:
#   ./scripts/game-server-docker.sh DM-1 3005 8 deathmatch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -ne 4 ]]; then
	echo "usage: $0 <name> <port> <max_players> <mode>" >&2
	exit 1
fi

NAME="$1"
PORT="$2"
MAX_PLAYERS="$3"
MODE="$4"
IMAGE="straif-game-server"

if [[ ! -f "$PROJECT_DIR/build/linux/straif.x86_64" ]]; then
	echo "error: build/linux/straif.x86_64 not found. Run scripts/export-linux.sh first." >&2
	exit 1
fi

echo "==> Building ${IMAGE} image..."
docker build \
	-f "$PROJECT_DIR/docker/game-server.Dockerfile" \
	-t "$IMAGE" \
	"$PROJECT_DIR"

CONTAINER="straif-gs-$(echo "$NAME" | tr '[:upper:] ' '[:lower:]-')"

echo "==> Starting ${CONTAINER} (${MODE}) on udp/${PORT}..."
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d \
	--name "$CONTAINER" \
	--restart unless-stopped \
	-e SERVER_NAME="$NAME" \
	-e PORT="$PORT" \
	-e MAX_PLAYERS="$MAX_PLAYERS" \
	-e MODE="$MODE" \
	-p "${PORT}:${PORT}/udp" \
	"$IMAGE"

echo "==> ${CONTAINER} started."
