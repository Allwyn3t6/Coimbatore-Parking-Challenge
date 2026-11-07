#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4.1 executable not found. Install it and add it to PATH." >&2
  exit 1
fi
if [ -f "$HOME/.android/debug.keystore" ]; then
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/.android/debug.keystore"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"
fi
mkdir -p build
"$GODOT_BIN" --headless --path . --export-debug "Android" build/CoimbatoreParkingChallenge-debug.apk
test -s build/CoimbatoreParkingChallenge-debug.apk
echo "APK exported to build/CoimbatoreParkingChallenge-debug.apk"
