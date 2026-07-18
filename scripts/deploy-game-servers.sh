#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DROPLET_HOST="${DROPLET_HOST:-}"
DROPLET_PATH="${DROPLET_PATH:-~/straif-game-servers}"
SKIP_BUILD=0

for arg in "$@"; do
	case "$arg" in
		--skip-build) SKIP_BUILD=1 ;;
		*) echo "unknown argument: $arg" >&2; exit 1 ;;
	esac
done

if [[ -z "$DROPLET_HOST" ]]; then
	echo "error: set DROPLET_HOST (e.g. DROPLET_HOST=root@1.2.3.4)" >&2
	exit 1
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
	echo "==> Building Linux server binary locally..."
	"$SCRIPT_DIR/export-linux.sh"
fi

if [[ ! -f "$PROJECT_DIR/build/linux/straif.x86_64" ]]; then
	echo "error: build/linux/straif.x86_64 not found. Run without --skip-build." >&2
	exit 1
fi

echo "==> Syncing artifacts to ${DROPLET_HOST}:${DROPLET_PATH}..."
ssh "$DROPLET_HOST" "mkdir -p ${DROPLET_PATH}/build/linux ${DROPLET_PATH}/docker"

rsync -az --delete "$PROJECT_DIR/build/linux/" "${DROPLET_HOST}:${DROPLET_PATH}/build/linux/"
rsync -az \
	"$PROJECT_DIR/docker/game-server.Dockerfile" \
	"$PROJECT_DIR/docker/game-server.Dockerfile.dockerignore" \
	"$PROJECT_DIR/docker/game-servers.compose.yaml" \
	"${DROPLET_HOST}:${DROPLET_PATH}/docker/"

echo "==> Rebuilding and restarting game servers on the droplet..."
ssh "$DROPLET_HOST" "cd ${DROPLET_PATH} && docker compose -f docker/game-servers.compose.yaml up -d --build"

echo "==> Done."
ssh "$DROPLET_HOST" "cd ${DROPLET_PATH} && docker compose -f docker/game-servers.compose.yaml ps"
