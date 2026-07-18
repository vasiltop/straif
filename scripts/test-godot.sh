#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GODOT_BIN="${GODOT_BIN:-godot}"

TEST_SCRIPTS=(
	"res://tests/unit/runtime_options_test.gd"
	"res://tests/unit/bootstrap_test.gd"
	"res://tests/world_record_announcement_test.gd"
	"res://tests/offline_playtest_smoke.gd"
	"res://tests/aim_menu_smoke.gd"
	"res://tests/aim_trainer_smoke.gd"
	"res://tests/death_camera_test.gd"
	"res://tests/elimination_round_state_test.gd"
)

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "error: Godot not found. Set GODOT_BIN to your Godot executable." >&2
	exit 1
fi

"$GODOT_BIN" --headless --path "$ROOT" --import

for test_script in "${TEST_SCRIPTS[@]}"; do
	echo "Running ${test_script}..."
	"$GODOT_BIN" --headless --path "$ROOT" --script "$test_script" -- --offline-playtest
done

echo "All Godot tests passed."
