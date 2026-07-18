#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "error: Godot not found. Set GODOT_BIN to your Godot executable." >&2
	exit 1
fi

"$GODOT_BIN" --headless --path "$ROOT" --import

cd "$ROOT/tests/e2e"
exec python3 -m unittest test_deathmatch -v
