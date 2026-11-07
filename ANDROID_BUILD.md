# Android build and installation

This repository includes an Android export preset for a 64-bit ARM Android build.

## One-time setup
1. Install Godot **4.4.1 stable**. The editor and export templates must match.
2. In Godot, open **Editor → Manage Export Templates… → Download and Install**.
3. Install Android Studio or the Android command-line SDK. For the Godot 4.4.1 / Android API 35 setup, install Platform Tools 35+, Build Tools 35.0.1, Android Platform 35, Command-line Tools (latest), NDK r28b (28.1.13356709) and CMake 3.10.2.4988404. If Godot reports a different required NDK/CMake version, follow the version shown by that editor.
4. Install OpenJDK 17.
5. In Godot, open **Editor → Editor Settings → Export → Android** and set the Java SDK Path and Android SDK Path.
6. Configure the Android debug keystore in the same Android export settings. Do not commit keystores or passwords.

## Export the APK
From the repository root, run:

```sh
mkdir -p build
godot --headless --path . --export-debug "Android" build/CoimbatoreParkingChallenge-debug.apk
```

Or open **Project → Export**, select **Android**, and click **Export Project**. The preset uses the package ID `com.allwyn3t6.coimbatoreparkingchallenge` and ARM64 architecture.

Install on a connected Android device with:

```sh
adb install -r build/CoimbatoreParkingChallenge-debug.apk
```

## Before release
- Test on multiple screen sizes and Android versions.
- Verify touch controls, thermal behaviour, frame rate and memory use on a physical device.
- Create and securely store your own release keystore for Play Store distribution.
- Do not upload a debug-signed APK to Google Play.
