extends Control
class_name Minimap
## Heading-up minimap drawn from the OSM road centre-lines.

var roads: Array = []        # [{p: PackedVector2Array, w, c, bb: Rect2}]
var route := PackedVector2Array()
var target := Vector2.INF
var markers: Array = []      # [{p: Vector2, c: Color, r: float}]
var car_pos := Vector2.ZERO
var car_yaw := 0.0
var view_radius := 120.0
var accent := Color("#f2b705")
var _t := 0.0

func set_roads(src: Array) -> void:
    roads.clear()
    for r in src:
        var pts: PackedVector2Array = r.p
        if pts.size() < 2:
            continue
        var bb := Rect2(pts[0], Vector2.ZERO)
        for p in pts:
            bb = bb.expand(p)
        roads.append({"p": pts, "w": r.w, "c": r.c, "bb": bb.grow(r.w)})

func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    _t += delta
    if _t > 0.05:
        _t = 0.0
        queue_redraw()

func _draw() -> void:
    var sz := size
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.86, 0.83, 0.76, 0.92)
    sb.set_corner_radius_all(16)
    sb.border_color = Color(1, 1, 1, 0.8)
    sb.set_border_width_all(3)
    draw_style_box(sb, Rect2(Vector2.ZERO, sz))
    var scale_px := (minf(sz.x, sz.y) * 0.5) / view_radius
    var view := Rect2(car_pos - Vector2.ONE * view_radius * 1.5, Vector2.ONE * view_radius * 3.0)
    draw_set_transform(sz * 0.5, car_yaw, Vector2(scale_px, scale_px))
    for r in roads:
        if not (r.bb as Rect2).intersects(view):
            continue
        var pts: PackedVector2Array = r.p
        var local := PackedVector2Array()
        local.resize(pts.size())
        for i in pts.size():
            local[i] = pts[i] - car_pos
        var col := Color("#ffffff") if r.c == "major" else Color("#f7f4ec")
        draw_polyline(local, Color(0.55, 0.52, 0.46), float(r.w) + 2.5 / scale_px)
        draw_polyline(local, col, float(r.w))
    if route.size() >= 2:
        var lr := PackedVector2Array()
        for p in route:
            lr.append(p - car_pos)
        draw_polyline(lr, Color(0.1, 0.55, 0.95, 0.9), 3.5 / scale_px)
    for m in markers:
        draw_circle((m.p as Vector2) - car_pos, float(m.r) / scale_px, m.c)
    if target != Vector2.INF:
        var tp := target - car_pos
        var dist := tp.length()
        var lim := view_radius * 0.92
        if dist > lim:
            tp = tp / dist * lim
        draw_circle(tp, 9.0 / scale_px, Color(0.1, 0.1, 0.1, 0.6))
        draw_circle(tp, 7.0 / scale_px, accent)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var c := sz * 0.5
    var tri := PackedVector2Array([c + Vector2(0, -12), c + Vector2(9, 9), c + Vector2(0, 5), c + Vector2(-9, 9)])
    draw_colored_polygon(tri, Color("#d32f2f"))
    draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Color.WHITE, 2.0, true)
    # North indicator
    var n := Vector2(0, -1).rotated(car_yaw) * (minf(sz.x, sz.y) * 0.5 - 14.0) + c
    draw_circle(n, 10, Color(0.1, 0.1, 0.1, 0.75))
    draw_string(ThemeDB.fallback_font, n + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
