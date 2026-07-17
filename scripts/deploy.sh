#!/usr/bin/env bash
#
# Deploy the whole Straif backend + game servers to a remote host in one command.
#
# The Godot Linux server binary is built locally (a 2 GB droplet can't run a Godot
# export), then the source + binary are shipped over SSH and the remote runs
# `docker compose up -d --build` for the full stack (Postgres + API + game servers).
#
# The backend image is small enough to build on the droplet, so we ship source and
# build remotely rather than pushing large images. The remote's own server/.env
# (secrets) is never overwritten.
#
# Usage:
#   DROPLET_HOST=root@1.2.3.4 ./scripts/deploy.sh [--skip-build]
#
# Config (env):
#   DROPLET_HOST   ssh target, e.g. root@1.2.3.4            (required)
#   DROPLET_PATH   remote dir to sync into (default: ~/straif)
#   --skip-build   reuse an existing build/linux/ instead of re-exporting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DROPLET_HOST="${DROPLET_HOST:-}"
DROPLET_PATH="${DROPLET_PATH:-~/straif}"
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

echo "==> Preparing remote ${DROPLET_HOST}:${DROPLET_PATH}..."
ssh "$DROPLET_HOST" "mkdir -p ${DROPLET_PATH}"

# Ship the files needed to build/run the full stack on the remote.
#   - compose.yaml + server/ + maps.json  -> backend image build
#   - docker/                             -> game-server image + compose
#   - build/linux/                        -> prebuilt Godot server binary
# Excludes keep secrets and local build junk on the remote intact.
echo "==> Syncing project files..."
rsync -az --relative \
	--exclude 'server/node_modules' \
	--exclude 'server/dist' \
	--exclude 'server/.env' \
	--exclude 'server/.env.production' \
	"$PROJECT_DIR/./compose.yaml" \
	"$PROJECT_DIR/./maps.json" \
	"$PROJECT_DIR/./server" \
	"$PROJECT_DIR/./docker" \
	"${DROPLET_HOST}:${DROPLET_PATH}/"

echo "==> Syncing prebuilt game-server binary..."
rsync -az --delete "$PROJECT_DIR/build/linux/" "${DROPLET_HOST}:${DROPLET_PATH}/build/linux/"

echo "==> Building and (re)starting the full stack on the remote..."
ssh "$DROPLET_HOST" "cd ${DROPLET_PATH} && docker compose up -d --build"

echo "==> Done. Current status:"
ssh "$DROPLET_HOST" "cd ${DROPLET_PATH} && docker compose ps"
