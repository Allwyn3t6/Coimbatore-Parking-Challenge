#!/usr/bin/env bash
# Export a signed release APK (no Gradle / NDK needed).
# Needs: Godot 4.4.1 + Android export templates, Android SDK build-tools 35, Java 17+.
# Release signing: set GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD.
# Never commit the keystore or its password.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p build
if [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
  "$GODOT_BIN" --headless --path . --export-release "Android" build/CoimbatoreParkingChallenge.apk
else
  "$GODOT_BIN" --headless --path . --export-debug "Android" build/CoimbatoreParkingChallenge-debug.apk
fi
ls -la build/
