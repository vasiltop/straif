#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=export-common.sh
source "$SCRIPT_DIR/export-common.sh"

BUILD_DIR="$PROJECT_DIR/build/macos"
APP_PATH="$BUILD_DIR/Straif.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/straif"
APP_PCK="$APP_PATH/Contents/Resources/straif.pck"
ZIP_PATH="$PROJECT_DIR/build/straif-macos.zip"

export_preset "macOS" "$BUILD_DIR"

if [[ ! -x "$APP_EXECUTABLE" ]]; then
	echo "error: macOS app executable is missing: $APP_EXECUTABLE" >&2
	exit 1
fi

if [[ ! -s "$APP_PCK" ]]; then
	echo "error: macOS app PCK is missing or empty: $APP_PCK" >&2
	exit 1
fi

for library in libgodotsteam.macos.template_release.dylib libsteam_api.dylib; do
	if ! find "$APP_PATH" -type f -name "$library" -print -quit | grep -q .; then
		echo "error: macOS app is missing GodotSteam library: $library" >&2
		exit 1
	fi
done

zip_build "$BUILD_DIR" "$ZIP_PATH"

echo "macOS export complete: $APP_PATH"
echo "Steam upload zip: $ZIP_PATH"
