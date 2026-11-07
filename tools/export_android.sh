#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
TEMPLATE_DIR="${GODOT_TEMPLATES_DIR:-$HOME/.local/share/godot/export_templates/4.4.1.stable}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4.1 executable not found. Install it and add it to PATH." >&2
  exit 1
fi
if [ ! -f "$TEMPLATE_DIR/android_source.zip" ]; then
  echo "Missing android_source.zip. Install matching Godot 4.4.1 export templates first." >&2
  exit 1
fi
mkdir -p android/build build
unzip -q -o "$TEMPLATE_DIR/android_source.zip" -d android/build
"$GODOT_BIN" --headless --path . --export-debug "Android" build/CoimbatoreParkingChallenge-debug.apk
test -s build/CoimbatoreParkingChallenge-debug.apk
echo "APK exported to build/CoimbatoreParkingChallenge-debug.apk"
