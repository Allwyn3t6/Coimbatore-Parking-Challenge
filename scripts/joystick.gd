extends Control
class_name VirtualStick
## Floating analog joystick. Touch anywhere inside the zone: the base appears
## under your thumb and the knob follows it. Multi-touch safe (tracks its own
## finger index). value: x = steer (-1..1), y = forward(-1)..back(+1).

var value := Vector2.ZERO
var radius := 96.0
var knob_r := 44.0
var steer_only := false
var accent := Color("#f2b705")

var _touch := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _home := Vector2.ZERO
var _fade := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(_reset_home)
    _reset_home()

func _reset_home() -> void:
    _home = Vector2(radius + 70.0, size.y - radius - 60.0)
    if _touch == -1:
        _center = _home
        _knob = _home

func release() -> void:
    _touch = -1
    value = Vector2.ZERO
    _center = _home
    _knob = _home
    queue_redraw()

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        var st := event as InputEventScreenTouch
        if st.pressed and _touch == -1:
            var local := _to_local(st.position)
            if Rect2(Vector2.ZERO, size).has_point(local):
                _touch = st.index
                _center = Vector2(clampf(local.x, radius * 0.6, size.x - radius * 0.6), clampf(local.y, radius * 0.6, size.y - radius * 0.6))
                _update(local)
                get_viewport().set_input_as_handled()
        elif not st.pressed and st.index == _touch:
            release()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var sd := event as InputEventScreenDrag
        if sd.index == _touch:
            _update(_to_local(sd.position))
            get_viewport().set_input_as_handled()

func _to_local(p: Vector2) -> Vector2:
    return get_global_transform_with_canvas().affine_inverse() * p

func _update(local: Vector2) -> void:
    var d := local - _center
    if steer_only:
        d.y = 0.0
    if d.length() > radius:
        d = d.normalized() * radius
    _knob = _center + d
    var v := d / radius
    var mag := v.length()
    var dead := 0.1
    if mag < dead:
        value = Vector2.ZERO
    else:
        value = v.normalized() * ((mag - dead) / (1.0 - dead))
    queue_redraw()

func _process(delta: float) -> void:
    var target := 1.0 if _touch != -1 else 0.0
    if absf(_fade - target) > 0.01:
        _fade = move_toward(_fade, target, delta * 6.0)
        queue_redraw()

func _draw() -> void:
    var a := lerpf(0.55, 1.0, _fade)
    # Base
    draw_circle(_center + Vector2(0, 4), radius + 6.0, Color(0, 0, 0, 0.18 * a))
    draw_circle(_center, radius + 4.0, Color(0.06, 0.08, 0.1, 0.42 * a))
    draw_arc(_center, radius + 4.0, 0, TAU, 64, Color(1, 1, 1, 0.35 * a), 3.0, true)
    draw_arc(_center, radius * 0.55, 0, TAU, 48, Color(1, 1, 1, 0.1 * a), 2.0, true)
    # Direction chevrons
    var dirs := [Vector2.LEFT, Vector2.RIGHT] if steer_only else [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
    for dv in dirs:
        var tip: Vector2 = _center + dv * (radius - 10.0)
        var side := Vector2(-dv.y, dv.x) * 9.0
        var back: Vector2 = tip - dv * 12.0
        var lit := value.dot(dv) > 0.3
        var col := accent if lit else Color(1, 1, 1, 0.55 * a)
        draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), col)
    if not steer_only:
        var f := ThemeDB.fallback_font
        draw_string(f, _center + Vector2(-30, -radius - 14), "DRIVE", HORIZONTAL_ALIGNMENT_CENTER, 60, 15, Color(1, 1, 1, 0.6 * a))
        draw_string(f, _center + Vector2(-35, radius + 26), "REVERSE", HORIZONTAL_ALIGNMENT_CENTER, 70, 15, Color(1, 1, 1, 0.6 * a))
    # Knob
    draw_circle(_knob + Vector2(0, 5), knob_r, Color(0, 0, 0, 0.3 * a))
    draw_circle(_knob, knob_r, Color(0.96, 0.96, 0.94, 0.94 * a))
    draw_circle(_knob, knob_r - 7.0, Color(0.88, 0.89, 0.9, a))
    draw_circle(_knob, knob_r * 0.42, Color(accent.r, accent.g, accent.b, 0.95 * a))
    draw_arc(_knob, knob_r, 0, TAU, 40, Color(0, 0, 0, 0.25 * a), 2.0, true)
