extends RefCounted
class_name Levels
## Levels are generated from OpenStreetMap by tools/osm/build_city.py and
## shipped in data/city.json. This class holds the live-traffic model.

## Typical Coimbatore weekday congestion (0..1) by local hour: school/office
## peak around 9:30, a softer midday bump and the evening peak around 19:00.
static func density_at(h: float) -> float:
    var d := 0.12
    d += 0.95 * exp(-pow((h - 9.5) / 1.1, 2.0))
    d += 0.5 * exp(-pow((h - 13.3) / 1.8, 2.0))
    d += 1.0 * exp(-pow((h - 19.0) / 1.4, 2.0))
    if h < 5.5 or h > 23.0:
        d = 0.08
    return clampf(d, 0.05, 1.0)

static func hour_now() -> float:
    var t := Time.get_datetime_dict_from_system()
    return float(t.hour) + float(t.minute) / 60.0

static func density_now() -> float:
    var d := density_at(hour_now())
    var wd := int(Time.get_datetime_dict_from_system().weekday)
    if wd == 0:
        d *= 0.7   # Sundays are calmer
    return d

static func density_label(d: float) -> String:
    if d > 0.75:
        return "Heavy traffic"
    if d > 0.45:
        return "Busy"
    if d > 0.2:
        return "Moderate traffic"
    return "Light traffic"

static func clock_label() -> String:
    var t := Time.get_datetime_dict_from_system()
    var h := int(t.hour)
    var ampm := "AM" if h < 12 else "PM"
    var h12 := h % 12
    if h12 == 0:
        h12 = 12
    return "%d:%02d %s" % [h12, int(t.minute), ampm]
