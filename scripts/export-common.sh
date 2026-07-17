#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GODOT="${GODOT:-godot}"
SYMBOLS_FILE="straif_symbols.txt"

require_godot() {
	if ! command -v "$GODOT" >/dev/null 2>&1; then
		echo "error: Godot not found. Set GODOT to your Godot executable." >&2
		exit 1
	fi
}

export_preset() {
	local preset="$1"
	local build_dir="$2"

	require_godot

	mkdir -p "$build_dir"
	rm -rf "${build_dir:?}/"*

	echo "Exporting ${preset} to ${build_dir}..."
	"$GODOT" --headless --path "$PROJECT_DIR" --export-release "$preset"
}

require_nonempty_artifact() {
	local artifact="$1"

	if [[ ! -f "$artifact" ]]; then
		echo "error: missing required artifact: ${artifact}" >&2
		return 1
	fi
	if [[ ! -s "$artifact" ]]; then
		echo "error: empty required artifact: ${artifact}" >&2
		return 1
	fi
}

validate_linux_build() {
	local build_dir="$1"
	local binary="$build_dir/straif.x86_64"

	require_nonempty_artifact "$binary"
	if [[ ! -x "$binary" ]]; then
		echo "error: Linux executable is not executable: ${binary}" >&2
		return 1
	fi
	require_nonempty_artifact "$build_dir/libgodotsteam.linux.template_release.x86_64.so"
	require_nonempty_artifact "$build_dir/libsteam_api.so"
}

zip_build() {
	local build_dir="$1"
	local zip_path="$2"

	if [[ ! -d "$build_dir" ]] || [[ -z "$(ls -A "$build_dir" 2>/dev/null)" ]]; then
		echo "error: build directory is empty: ${build_dir}" >&2
		exit 1
	fi

	rm -f "$zip_path"
	echo "Creating ${zip_path} (excluding ${SYMBOLS_FILE})..."
	python3 - "$build_dir" "$zip_path" "$SYMBOLS_FILE" <<'PY'
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

build_dir = Path(sys.argv[1])
zip_path = Path(sys.argv[2])
exclude = sys.argv[3]

with ZipFile(zip_path, "w", compression=ZIP_DEFLATED) as archive:
    for path in sorted(build_dir.rglob("*")):
        if not path.is_file() or path.name == exclude:
            continue
        archive.write(path, path.relative_to(build_dir).as_posix())
PY
}
