# Coimbatore Parking Challenge

A mobile-first 3D parking game set in fictionalised Coimbatore streets. Built with Godot 4 and GDScript.

## Gameplay in this build
- Three selectable street missions inspired by Gandhipuram, RS Puram and Race Course.
- Third-person follow camera, steering, acceleration, reverse/braking and rolling wheels.
- Ten selectable vehicle profiles based on a published Indian passenger-car sales snapshot.
- Touch controls for Android and WASD/arrow-key controls for desktop.
- Collision penalties, elapsed-time scoring, parking alignment checks, restart and pause.
- Procedurally generated buildings, shopfront blocks, kerbs, parked vehicles and parking markings.

## Vehicle roster
The initial ten are ranked using V3Cars' rolling 12-month India model-sales list (Oct 2025–Sep 2026): Dzire, Nexon, Punch, Ertiga, Wagon R, Swift, Baleno, Fronx, Creta and Scorpio-N. Rankings are a dated snapshot and will change.

All in-game vehicles use original, simplified generic meshes with different dimensions, colours and handling profiles. No manufacturer logos, official CAD/3D models, or branded liveries are included. Vehicle/model names are trademarks of their respective owners. This unofficial game is not affiliated with any manufacturer.

## Run locally
1. Install Godot 4.4.1 (or a compatible Godot 4 release).
2. Clone this repository and import `project.godot`.
3. Run the project (F6/F5).
4. Desktop: WASD or arrow keys; R restarts; Escape pauses.
5. Touchscreen: use the on-screen steering and pedal controls.

## Android export
The project targets mobile GL Compatibility rendering and landscape orientation. To export an APK:
1. Install matching Godot export templates in Godot Editor.
2. Install/configure Android SDK and JDK in Editor Settings → Export → Android.
3. Add an Android export preset in Project → Export, set a unique package ID, and export a debug APK.
4. Install on a physical Android device and test touch layout, performance and device-specific rendering before release.

A signed Play Store release additionally requires your own release keystore and store listing assets. Never commit signing keys or passwords to this repository.

## Street-data and asset policy
This build uses fictionalised procedural streets, not surveyed road geometry. It is inspired by Coimbatore's urban character; it does not claim to reproduce exact road layouts. If OpenStreetMap-derived geometry is added later, credit OpenStreetMap contributors and comply with ODbL: https://www.openstreetmap.org/copyright.

## Source references
- V3Cars, Most Selling Cars in India – Last 12 Months Oct 2025–Sep 2026: https://www.v3cars.com/popular-cars (accessed 7 Nov 2026).

## License
Source code: MIT. This license does not grant rights to third-party trademarks or vehicle designs.
