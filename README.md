# Coimbatore Parking Challenge

A mobile 3D parking-and-racing game on the **real street layout of central Coimbatore** (the Gandhipuram bus-stand district), built with Godot 4.4.

Streets, buildings, car parks and bus-stand yards come from **OpenStreetMap**. Every name and identifying tag is removed. Shop signs carry invented bilingual (Tamil + English) names, so the town feels local without identifying any real business.

## What's in the game
- **Auto-generated levels from real data:** real car parks with bays and parked cars, kerbside parallel parking on real streets, a cross-town **Live Rush Hour** drive, and the **Kovai Grand Prix**, a 2-lap race against three rival cars on a loop of real main roads.
- **Live traffic model:** traffic density follows the time on your phone, based on a typical Coimbatore weekday (peaks around 9:30 and 19:00, calmer on Sundays). The lighting also follows the clock, from morning sun to golden hour.
- **Neat floating joystick:** touch anywhere in the zone and the stick appears under your thumb. Push up to drive, pull down to brake and reverse. There is an optional *stick + pedals* layout (GAS, BRAKE, D/R) and the stick can go on the left or right.
- **Realistic driving:** the car pivots around its rear axle like a real car. Front wheels steer, brake and reverse lights work, and front/rear **parking sensors** beep faster as you get closer. There are chase, high and top-down cameras.
- **Local flavour:** auto-rickshaws, town buses, lorries and two-wheelers in traffic; black-and-yellow kerbs; rain trees and coconut palms; rooftop water tanks; temple towers; and the Western Ghats on the horizon.
- **Auto-configuration:** the game detects the phone (CPU cores, RAM, GPU family) and picks Low, Medium or High graphics. It then adapts render resolution to the measured frame rate, scales touch controls for phones vs tablets and rotates with the device (sensor landscape). Everything can be overridden in Settings.

## Data pipeline (GitHub as storage)
`tools/osm/build_city.py` runs in GitHub Actions (`.github/workflows/osm-data.yml`) whenever the pipeline changes, plus weekly. It:
1. downloads OSM geometry for a 1.3 km × 1.3 km box through the Overpass API;
2. strips all names and tags and keeps only geometry;
3. builds the drivable surface, footpaths, kerbs, lane markings, buildings (with heights), trees, traffic lanes, levels and a race loop;
4. commits `data/city.json` (plus the raw response in `data/raw/`).

The APK ships with a copy of `data/city.json`. At start-up the game checks the GitHub copy and caches a newer version, so **map and level updates reach players without a new APK**.

To change the area, edit `CENTER_LAT`, `CENTER_LON` and `HALF` in `tools/osm/build_city.py` and push. The data rebuilds automatically.

## Ads (planned)
`scripts/ads.gd` is a no-op placeholder. The game's rule is that only small banners may appear, and only on menu and results screens, never while driving. To monetise, add a Godot 4 AdMob Android plugin, enable it in the export preset and implement the three functions in `ads.gd`.

## Build
- Godot **4.4.1** with Android export templates, Android SDK build-tools 35 and Java 17+ (no Gradle or NDK needed).
- `./tools/export_android.sh` builds a debug-signed APK. Set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD` to build a signed release.
- CI: `.github/workflows/android-build.yml` builds a debug APK artifact on every push.
- Desktop test controls: WASD or arrows, Space to brake, C for camera, H for horn, Esc to pause, R to restart.

## Credits and licences
- Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), available under the ODbL 1.0. The game shows this attribution on the main menu.
- Fonts: Baloo Thambi 2 and Rajdhani (SIL Open Font License), via Fontsource.
- Vehicles are original generic models with no manufacturer names, logos or designs.
- Source code: MIT.
