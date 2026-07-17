#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STEAM_DIR="$PROJECT_DIR/steam"
OUTPUT_DIR="$STEAM_DIR/output"

BUILD_LINUX="$PROJECT_DIR/build/linux"
BUILD_WINDOWS="$PROJECT_DIR/build/windows"
BUILD_MACOS="$PROJECT_DIR/build/macos"

DO_BUILD=false
for arg in "$@"; do
	if [[ "$arg" == "--build" ]]; then
		DO_BUILD=true
	fi
done

if [[ ! -f "$STEAM_DIR/steam.env" ]]; then
	echo "error: missing $STEAM_DIR/steam.env (copy from steam.env.example)" >&2
	exit 1
fi

# shellcheck source=/dev/null
source "$STEAM_DIR/steam.env"

: "${STEAM_USERNAME:?STEAM_USERNAME must be set in steam/steam.env}"
: "${STEAM_DEPOT_LINUX:?STEAM_DEPOT_LINUX must be set in steam/steam.env}"
: "${STEAM_DEPOT_WINDOWS:?STEAM_DEPOT_WINDOWS must be set in steam/steam.env}"
: "${STEAM_DEPOT_MACOS:?STEAM_DEPOT_MACOS must be set in steam/steam.env}"

STEAMCMD="${STEAMCMD:-$HOME/.local/steamcmd/steamcmd.sh}"

if [[ "$DO_BUILD" == true ]]; then
	"$SCRIPT_DIR/export-all.sh"
fi

check_build_dir() {
	local dir="$1"
	local name="$2"
	if [[ ! -d "$dir" ]] || [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
		echo "error: ${name} build is empty: ${dir} (run export-all.sh or use --build)" >&2
		exit 1
	fi
}

check_build_dir "$BUILD_LINUX" "Linux"
check_build_dir "$BUILD_WINDOWS" "Windows"
check_build_dir "$BUILD_MACOS" "macOS"

if [[ ! -f "$STEAMCMD" ]]; then
	echo "error: SteamCMD not found at $STEAMCMD" >&2
	exit 1
fi

mkdir -p "$OUTPUT_DIR"

BUILD_DESC="Straif $(date -u +%Y-%m-%dT%H:%MZ)"

render_vdf() {
	local template="$1"
	local output="$2"
	sed \
		-e "s|__STEAM_DEPOT_LINUX__|${STEAM_DEPOT_LINUX}|g" \
		-e "s|__STEAM_DEPOT_WINDOWS__|${STEAM_DEPOT_WINDOWS}|g" \
		-e "s|__STEAM_DEPOT_MACOS__|${STEAM_DEPOT_MACOS}|g" \
		-e "s|__BUILD_LINUX_DIR__|${BUILD_LINUX}|g" \
		-e "s|__BUILD_WINDOWS_DIR__|${BUILD_WINDOWS}|g" \
		-e "s|__BUILD_MACOS_DIR__|${BUILD_MACOS}|g" \
		-e "s|__BUILD_OUTPUT_DIR__|${OUTPUT_DIR}|g" \
		-e "s|__BUILD_DESC__|${BUILD_DESC}|g" \
		"$template" >"$output"
}

render_vdf "$STEAM_DIR/depot_linux.vdf" "$OUTPUT_DIR/depot_linux.vdf"
render_vdf "$STEAM_DIR/depot_windows.vdf" "$OUTPUT_DIR/depot_windows.vdf"
render_vdf "$STEAM_DIR/depot_macos.vdf" "$OUTPUT_DIR/depot_macos.vdf"
render_vdf "$STEAM_DIR/app_build.vdf" "$OUTPUT_DIR/app_build.vdf"

echo "Uploading to Steam (App ID 3850480)..."
"$STEAMCMD" +login "$STEAM_USERNAME" \
	+run_app_build "$OUTPUT_DIR/app_build.vdf" \
	+quit

echo "Upload complete. Set the build live at:"
echo "https://partner.steamgames.com/apps/builds/3850480"
