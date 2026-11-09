extends Control
class_name TouchPad
## Multi-touch button used for pedals, brake, horn and camera. Works alongside
## the joystick because it tracks its own finger index.

signal pressed_changed(down: bool)
signal tapped

var caption := ""
var sub := ""
var base_color := Color("#2b3138")
var accent := Color("#f2b705")
var font: Font
var font_size := 22
var down := false
var corner := 18
var _touch := -1

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        var st := event as InputEventScreenTouch
        var local := get_global_transform_with_canvas().affine_inverse() * st.position
        if st.pressed and _touch == -1 and Rect2(Vector2.ZERO, size).grow(8).has_point(local):
            _touch = st.index
            _set_down(true)
            get_viewport().set_input_as_handled()
        elif not st.pressed and st.index == _touch:
            _touch = -1
            _set_down(false)
            tapped.emit()
            get_viewport().set_input_as_handled()

func release() -> void:
    _touch = -1
    _set_down(false)

func _set_down(v: bool) -> void:
    if down == v:
        return
    down = v
    pressed_changed.emit(v)
    queue_redraw()

func _draw() -> void:
    var r := Rect2(Vector2.ZERO, size)
    var sb := StyleBoxFlat.new()
    sb.bg_color = accent if down else Color(base_color.r, base_color.g, base_color.b, 0.62)
    sb.set_corner_radius_all(corner)
    sb.border_color = Color(1, 1, 1, 0.38) if not down else accent.lightened(0.3)
    sb.set_border_width_all(2)
    sb.shadow_color = Color(0, 0, 0, 0.25)
    sb.shadow_size = 6
    sb.shadow_offset = Vector2(0, 3)
    draw_style_box(sb, r.grow(-1.0 if down else 0.0))
    var f := font if font else ThemeDB.fallback_font
    var col := Color("#1b1b1b") if down else Color.WHITE
    var y := size.y * 0.5 + font_size * 0.35
    if sub != "":
        y -= 8
        draw_string(f, Vector2(0, y + 22), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(col.r, col.g, col.b, 0.7))
    draw_string(f, Vector2(0, y), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, col)
