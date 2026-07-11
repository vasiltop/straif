#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/export-linux.sh"
"$SCRIPT_DIR/export-windows.sh"

echo "All exports complete."
