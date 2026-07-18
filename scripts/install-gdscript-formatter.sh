#!/usr/bin/env bash
set -euo pipefail

VERSION="0.21.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT/.tools"
BIN_PATH="$TOOLS_DIR/gdscript-formatter"

if [ -x "$BIN_PATH" ] && "$BIN_PATH" --version 2>/dev/null | grep -q "$VERSION"; then
	echo "gdscript-formatter $VERSION already installed at $BIN_PATH"
	exit 0
fi

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
	Darwin) platform_os="macos" ;;
	Linux) platform_os="linux" ;;
	*)
		echo "error: unsupported operating system '$os'. Supported: Darwin, Linux." >&2
		exit 1
		;;
esac

case "$arch" in
	arm64 | aarch64) platform_arch="aarch64" ;;
	x86_64 | amd64) platform_arch="x86_64" ;;
	*)
		echo "error: unsupported architecture '$arch'. Supported: arm64/aarch64, x86_64/amd64." >&2
		exit 1
		;;
esac

case "${platform_os}-${platform_arch}" in
	macos-aarch64) expected_sha256="441bbf3de76ed8e74e7dd57515557300aa7f426ef1d1be7a7f6db25b2235edc1" ;;
	macos-x86_64) expected_sha256="e663f789c6077d128386abb5c167d08824da9a95b65af267c0d931e280622137" ;;
	linux-aarch64) expected_sha256="9252daf30c0687a448cd0b8c78ded618ba7af4e12c3d62d9cae3b174990e7b0b" ;;
	linux-x86_64) expected_sha256="dcf4aa93e3a20abdbfebb673b7d2fbdc3320f6a0e6e651ab46c85f326cb653d1" ;;
	*)
		echo "error: unsupported platform '${platform_os}-${platform_arch}'." >&2
		exit 1
		;;
esac

for tool in curl unzip; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "error: required tool '$tool' not found on PATH." >&2
		exit 1
	fi
done

if command -v sha256sum >/dev/null 2>&1; then
	sha256_cmd=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
	sha256_cmd=(shasum -a 256)
else
	echo "error: no SHA-256 tool found. Install either 'sha256sum' or 'shasum'." >&2
	exit 1
fi

asset="gdscript-formatter-${VERSION}-${platform_os}-${platform_arch}"
url="https://github.com/GDQuest/GDScript-formatter/releases/download/${VERSION}/${asset}.zip"

staging="$TOOLS_DIR/.staging"
rm -rf "$staging"
mkdir -p "$staging"
trap 'rm -rf "$staging"' EXIT

archive="$staging/${asset}.zip"

echo "Downloading gdscript-formatter $VERSION for ${platform_os}-${platform_arch}..."
if ! curl --fail --location --silent --show-error --output "$archive" "$url"; then
	echo "error: failed to download $url" >&2
	exit 1
fi

actual_sha256="$("${sha256_cmd[@]}" "$archive" | awk '{print $1}')"
if [ "$actual_sha256" != "$expected_sha256" ]; then
	echo "error: checksum mismatch for ${asset}.zip" >&2
	echo "  expected: $expected_sha256" >&2
	echo "  actual:   $actual_sha256" >&2
	exit 1
fi

unzip -o -q "$archive" -d "$staging"

if [ ! -f "$staging/$asset" ]; then
	echo "error: expected '$asset' inside ${asset}.zip but it was not found." >&2
	exit 1
fi

mkdir -p "$TOOLS_DIR"
mv -f "$staging/$asset" "$BIN_PATH"
chmod +x "$BIN_PATH"

echo "Installed gdscript-formatter $VERSION to $BIN_PATH"
