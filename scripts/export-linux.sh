#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=export-common.sh
source "$SCRIPT_DIR/export-common.sh"

BUILD_DIR="$PROJECT_DIR/build/linux"
ZIP_PATH="$PROJECT_DIR/build/straif-linux.zip"

export_preset "Linux" "$BUILD_DIR"
zip_build "$BUILD_DIR" "$ZIP_PATH"

echo "Linux export complete: $BUILD_DIR"
echo "Steam upload zip: $ZIP_PATH"
