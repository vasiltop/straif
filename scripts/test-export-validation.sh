#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=export-common.sh
source "$SCRIPT_DIR/export-common.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/straif-export-validation.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
	echo "not ok - $1" >&2
	exit 1
}

expect_failure() {
	local expected="$1"
	shift
	local output
	local status

	set +e
	output="$("$@" 2>&1)"
	status=$?
	set -e

	[[ "$status" -ne 0 ]] || fail "command unexpectedly succeeded: $*"
	[[ "$output" == *"$expected"* ]] || fail "expected error containing '$expected', got: $output"
}

linux_dir="$TEST_ROOT/linux"
mkdir -p "$linux_dir"
printf 'symbols' >"$linux_dir/$SYMBOLS_FILE"

expect_failure \
	"missing required artifact: $linux_dir/straif.x86_64" \
	validate_linux_build "$linux_dir"

echo "ok - rejects a symbols-only Linux build"

touch "$linux_dir/straif.x86_64"
expect_failure \
	"empty required artifact: $linux_dir/straif.x86_64" \
	validate_linux_build "$linux_dir"

echo "ok - rejects a zero-byte Linux executable"

printf 'binary' >"$linux_dir/straif.x86_64"
expect_failure \
	"Linux executable is not executable: $linux_dir/straif.x86_64" \
	validate_linux_build "$linux_dir"

echo "ok - rejects a Linux binary without executable mode"

chmod +x "$linux_dir/straif.x86_64"
expect_failure \
	"missing required artifact: $linux_dir/libgodotsteam.linux.template_release.x86_64.so" \
	validate_linux_build "$linux_dir"

echo "ok - rejects a Linux build without the GodotSteam extension"

printf 'extension' >"$linux_dir/libgodotsteam.linux.template_release.x86_64.so"
expect_failure \
	"missing required artifact: $linux_dir/libsteam_api.so" \
	validate_linux_build "$linux_dir"

echo "ok - rejects a Linux build without the Steam API library"

printf 'steam api' >"$linux_dir/libsteam_api.so"
validate_linux_build "$linux_dir"

echo "ok - accepts a complete Linux build"

project_dir="$TEST_ROOT/project"
mkdir -p "$project_dir/scripts"
cp "$SCRIPT_DIR/export-common.sh" "$SCRIPT_DIR/export-linux.sh" "$project_dir/scripts/"

fake_godot="$TEST_ROOT/fake-godot"
cat >"$fake_godot" <<'SH'
#!/usr/bin/env bash
while [[ "$#" -gt 0 ]]; do
	if [[ "$1" == "--path" ]]; then
		project_dir="$2"
		break
	fi
	shift
done
mkdir -p "$project_dir/build/linux"
printf 'symbols' >"$project_dir/build/linux/straif_symbols.txt"
SH
chmod +x "$fake_godot"

expect_failure \
	"missing required artifact: $project_dir/build/linux/straif.x86_64" \
	env GODOT="$fake_godot" "$project_dir/scripts/export-linux.sh"

echo "ok - export script rejects an incomplete Godot export"

upload_project="$TEST_ROOT/upload-project"
mkdir -p \
	"$upload_project/scripts" \
	"$upload_project/steam" \
	"$upload_project/build/linux" \
	"$upload_project/build/windows"
cp "$SCRIPT_DIR/export-common.sh" "$SCRIPT_DIR/upload-steam.sh" "$upload_project/scripts/"
cp \
	"$PROJECT_DIR/steam/app_build.vdf" \
	"$PROJECT_DIR/steam/depot_linux.vdf" \
	"$PROJECT_DIR/steam/depot_windows.vdf" \
	"$upload_project/steam/"
printf 'symbols' >"$upload_project/build/linux/straif_symbols.txt"
printf 'windows' >"$upload_project/build/windows/straif.exe"
cat >"$upload_project/steam/steam.env" <<'ENV'
STEAM_USERNAME=dry_run
STEAM_DEPOT_WINDOWS=3850481
STEAM_DEPOT_LINUX=3850482
STEAMCMD=/usr/bin/true
ENV

expect_failure \
	"missing required artifact: $upload_project/build/linux/straif.x86_64" \
	"$upload_project/scripts/upload-steam.sh"

echo "ok - Steam upload rejects a symbols-only Linux depot"
