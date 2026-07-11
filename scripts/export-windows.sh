#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=export-common.sh
source "$SCRIPT_DIR/export-common.sh"

BUILD_DIR="$PROJECT_DIR/build/windows"
ZIP_PATH="$PROJECT_DIR/build/straif-windows.zip"

export_preset "Windows" "$BUILD_DIR"
zip_build "$BUILD_DIR" "$ZIP_PATH"

echo "Windows export complete: $BUILD_DIR"
echo "Steam upload zip: $ZIP_PATH"
