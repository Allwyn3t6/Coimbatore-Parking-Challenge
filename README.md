# Coimbatore Parking Challenge

A mobile-first 3D parking game prototype set in fictionalised streets inspired by Coimbatore, Tamil Nadu. Built with Godot 4 and GDScript.

## Current prototype
- 3D market-street environment inspired by Gandhipuram.
- Drive, reverse, steer and park in a marked bay.
- Touch controls plus keyboard controls for desktop testing.
- Collision penalties, parking alignment check and score bonus.
- Ten selectable vehicle profiles based on India's high-volume models.

## Vehicle roster
Based on the V3Cars India model-sales list for Oct 2025–Sep 2026:
1. Maruti Suzuki Dzire
2. Tata Nexon
3. Tata Punch
4. Maruti Suzuki Ertiga
5. Maruti Suzuki Wagon R
6. Maruti Suzuki Swift
7. Maruti Suzuki Baleno
8. Maruti Suzuki Fronx
9. Hyundai Creta
10. Mahindra Scorpio-N

The game uses original, simplified generic 3D vehicle meshes with different dimensions, colours and handling profiles. Manufacturer logos, official CAD/3D models and brand liveries are not included. Vehicle and model names are trademarks of their respective owners; this is an unofficial fan-made game and is not affiliated with any manufacturer.

## Run locally
1. Install Godot 4.3 or later.
2. Import this repository's project.godot.
3. Open scenes/main.tscn and run the project (F6/F5).
4. Desktop controls: arrow keys or WASD. On touchscreen, use the on-screen buttons.

## Android
The project is configured for mobile-friendly GL Compatibility rendering and landscape orientation. Android export requires matching Godot export templates and Android SDK/JDK configured in Godot Editor (Editor → Manage Export Templates; Editor → Editor Settings → Export → Android). Add an Android export preset after configuring the local SDK, then export an APK for device testing.

## Road inspiration and attribution
Street layouts are fictionalised and inspired by Coimbatore's urban character (Gandhipuram market streets, RS Puram commercial streets and Race Course avenues). No OpenStreetMap geometry is bundled in this first prototype. If OSM-derived map data is added in a later release, it will be attributed to OpenStreetMap contributors and distributed under ODbL: https://www.openstreetmap.org/copyright.

## Sales data reference
V3Cars, Most Selling Cars in India – Last 12 Months Oct 2025–Sep 2026: https://www.v3cars.com/popular-cars (accessed 7 Nov 2026). Sales rankings change over time; the roster is a snapshot, not a permanent ranking.

## License
Source code: MIT. This license does not grant rights to third-party trademarks or vehicle designs.
