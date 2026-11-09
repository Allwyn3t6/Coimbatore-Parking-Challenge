# Android build

The project exports with Godot's prebuilt Android templates (no Gradle/NDK).

1. Install Godot 4.4.1 and its export templates (only the `android_*` files are needed).
2. Install Android SDK build-tools 35.0.1 and Java 17+.
3. In Godot: Editor Settings → Export → Android → set the Java SDK and Android SDK paths.
4. Debug APK: `./tools/export_android.sh`
5. Release APK: set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`, then run the same script.

Keep the release keystore safe and **never commit it**. Play Store updates must be signed with the same key. For Google Play, export an AAB with the Gradle build enabled.
