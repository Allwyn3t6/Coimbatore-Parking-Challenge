#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v godot >/dev/null 2>&1; then
  echo "Godot executable not found. Install Godot 4.4.1 and add it to PATH." >&2
  exit 1
fi
mkdir -p build
godot --headless --path . --export-debug "Android" build/CoimbatoreParkingChallenge-debug.apk
echo "APK exported to build/CoimbatoreParkingChallenge-debug.apk"
