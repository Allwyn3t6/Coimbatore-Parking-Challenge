extends Node3D
## Coimbatore Parking Challenge - game flow, camera, HUD and menus.

enum State { LOADING, MENU, COUNTDOWN, PLAYING, PAUSED, RESULT }

const ACCENT := Color("#f2b705")
const MAROON := Color("#8c1c13")
const INK := Color("#14181c")
const GOOD := Color("#3ddc84")
const RIVAL_NAMES := ["Karthik", "Divya", "Selvam"]
const RIVAL_COLOURS := [Color("#d32f2f"), Color("#1565c0"), Color("#2e7d32")]

var state := State.LOADING
var world: CityWorld
var game_root: Node3D
var car: PlayerCar
var audio: AudioFx
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var levels: Array = []
var level_idx := 0
var level: Dictionary = {}
var traffic: Array = []
var rivals: Array = []
var fx_root: Node3D

var elapsed := 0.0
var hits := 0
var kerb_hits := 0
var park_hold := 0.0
var countdown := 0.0
var cam_yaw := 0.0
var shake := 0.0
var orbit := 0.0
var density := 0.5
var screen := "main"
var garage_car: PlayerCar

# Parking
var bay_c := Vector3.ZERO
var bay_yaw := 0.0
var bay_w := 2.6
var bay_l := 5.2
var bay_yaws: Array = []
var bay_mat: StandardMaterial3D
var beacon_mat: StandardMaterial3D
var arrow: MeshInstance3D

# Race
var race_path := PackedVector3Array()
var race_cum := PackedFloat32Array()
var race_total := 1.0
var gates: Array = []          # [{p: Vector3, yaw: float, node: Node3D}]
var gate_i := 0
var lap := 0
var laps := 2
var player_s := 0.0
var race_place := 1

# UI
var ui: CanvasLayer
var ui_theme: Theme
var font_ui: FontFile
var hud: Control
var menu_root: Control
var overlay: Control
var stick: VirtualStick
var brake_pad: TouchPad
var gas_pad: TouchPad
var gear_pad: TouchPad
var horn_pad: TouchPad
var cam_pad: TouchPad
var minimap: Minimap
var sensor: SensorBar
var ring: ProgressRing
var lbl_name: Label
var lbl_obj: Label
var lbl_time: Label
var lbl_hits: Label
var lbl_speed: Label
var lbl_gear: Label
var lbl_toast: Label
var lbl_center: Label
var lbl_live: Label
var lbl_fps: Label
var loading_lbl: Label
var toast_t := 0.0

# ---------------------------------------------------------------- inner UI widgets
class SensorBar extends Control:
    var front := 99.0
    var rear := 99.0
    func _draw() -> void:
        var w := size.x
        _row(Vector2(0, 0), w, front, "FRONT")
        _row(Vector2(0, 22), w, rear, "REAR")
    func _row(o: Vector2, w: float, d: float, label: String) -> void:
        var segs := 6
        var lit := 0 if d > 2.5 else int(ceil(clampf((2.5 - d) / 2.5, 0.0, 1.0) * segs))
        draw_string(ThemeDB.fallback_font, o + Vector2(0, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
        var x0 := 52.0
        var sw := (w - x0) / segs - 3.0
        for i in segs:
            var c := Color(1, 1, 1, 0.15)
            if i < lit:
                c = Color("#3ddc84") if i < 2 else (Color("#f2b705") if i < 4 else Color("#e53935"))
            draw_rect(Rect2(o + Vector2(x0 + i * (sw + 3.0), 2), Vector2(sw, 14)), c)

class ProgressRing extends Control:
    var value := 0.0
    func _draw() -> void:
        if value <= 0.0:
            return
        var c := size * 0.5
        draw_arc(c, 46, 0, TAU, 48, Color(0, 0, 0, 0.35), 12, true)
        draw_arc(c, 46, -PI * 0.5, -PI * 0.5 + TAU * value, 48, Color("#3ddc84"), 10, true)
        draw_string(ThemeDB.fallback_font, c + Vector2(-40, 7), "HOLD", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color.WHITE)

class StarRow extends Control:
    var stars := 0
    var star_size := 16.0
    func _draw() -> void:
        for i in 3:
            var c := Vector2(star_size + i * star_size * 2.3, size.y * 0.5)
            var pts := PackedVector2Array()
            for k in 10:
                var r := star_size if k % 2 == 0 else star_size * 0.45
                var a := -PI * 0.5 + k * PI / 5.0
                pts.append(c + Vector2(cos(a), sin(a)) * r)
            draw_colored_polygon(pts, Color("#f2b705") if i < stars else Color(1, 1, 1, 0.22))

# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().set_auto_accept_quit(true)
    get_tree().set_quit_on_go_back(false)
    _setup_fonts_and_theme()
    _setup_environment()
    ui = CanvasLayer.new()
    ui.layer = 5
    add_child(ui)
    loading_lbl = _label("Building Coimbatore from OpenStreetMap...", 26, Color.WHITE)
    loading_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
    ui.add_child(loading_lbl)
    audio = AudioFx.new()
    add_child(audio)
    audio.enabled = AutoConfig.sound_on
    AutoConfig.changed.connect(_apply_quality)
    CityData.update_downloaded.connect(func(_g): _toast("New map data downloaded - it loads next time you open the game", 4.0))
    await get_tree().process_frame
    await get_tree().process_frame
    _build_world()

func _build_world() -> void:
    game_root = Node3D.new()
    game_root.name = "Game"
    game_root.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(game_root)
    world = CityWorld.new()
    world.name = "City"
    game_root.add_child(world)
    world.build(CityData.data)
    fx_root = Node3D.new()
    game_root.add_child(fx_root)
    levels = CityData.levels()
    _build_arrow()
    _build_hud()
    menu_root = Control.new()
    menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(menu_root)
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(overlay)
    loading_lbl.queue_free()
    _apply_quality()
    _show_menu("main")
    _autotest()

## Developer hook: godot -- --shot=<level|menu|levels|garage|settings>,<seconds>,<out.png>[,drive]
func _autotest() -> void:
    for a in OS.get_cmdline_user_args():
        if not a.begins_with("--shot="):
            continue
        var parts := a.substr(7).split(",")
        var what := parts[0]
        var secs := float(parts[1]) if parts.size() > 1 else 3.0
        var out := parts[2] if parts.size() > 2 else "user://shot.png"
        var drive := parts.size() > 3
        if what.is_valid_int():
            _start_level(int(what))
        elif what != "menu":
            _show_menu(what)
        if parts.size() > 3 and parts[3] == "sim":
            for k in int(secs):
                await get_tree().create_timer(1.0).timeout
                if k % 20 == 0:
                    var info := []
                    for r in rivals:
                        info.append("lap%d s%.0f v%.1f" % [r.lap, r.s, r.cur_speed])
                    print("t=", k, " state=", state, " place=", race_place, " ", info, " traffic=", traffic.size(), " fps=", Engine.get_frames_per_second())
            get_tree().quit()
            return
        if parts.size() > 3 and parts[3] == "park" and is_instance_valid(car):
            car.place(bay_c, float(bay_yaws[0]))
            await get_tree().create_timer(secs).timeout
            drive = false
            secs = 0.1
        if drive:
            await get_tree().create_timer(4.2).timeout
            for i in int(secs * 10.0):
                stick.value = Vector2(0.15 * sin(i * 0.05), -0.8)
                await get_tree().create_timer(0.1).timeout
        else:
            await get_tree().create_timer(secs).timeout
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(out)
        print("SHOT ", out, " fps=", Engine.get_frames_per_second(), " traffic=", traffic.size())
        get_tree().quit()

func _setup_fonts_and_theme() -> void:
    font_ui = load("res://assets/fonts/Rajdhani-Bold.woff2")
    var tamil: FontFile = load("res://assets/fonts/BalooThambi2-Tamil-Bold.woff2")
    if font_ui and tamil:
        font_ui.fallbacks = [tamil]
    ui_theme = Theme.new()
    if font_ui:
        ui_theme.default_font = font_ui
    ui_theme.default_font_size = 22
    var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg
        sb.set_corner_radius_all(14)
        sb.border_color = border
        sb.set_border_width_all(2)
        sb.content_margin_left = 18
        sb.content_margin_right = 18
        sb.content_margin_top = 10
        sb.content_margin_bottom = 10
        return sb
    ui_theme.set_stylebox("normal", "Button", mk.call(Color(0.08, 0.1, 0.12, 0.82), Color(1, 1, 1, 0.18)))
    ui_theme.set_stylebox("hover", "Button", mk.call(Color(0.14, 0.16, 0.19, 0.9), ACCENT))
    ui_theme.set_stylebox("pressed", "Button", mk.call(ACCENT, ACCENT))
    ui_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    ui_theme.set_stylebox("disabled", "Button", mk.call(Color(0.1, 0.1, 0.1, 0.5), Color(1, 1, 1, 0.05)))
    ui_theme.set_color("font_color", "Button", Color.WHITE)
    ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
    ui_theme.set_color("font_pressed_color", "Button", INK)
    ui_theme.set_color("font_color", "Label", Color.WHITE)
    var panel := StyleBoxFlat.new()
    panel.bg_color = Color(0.06, 0.07, 0.09, 0.8)
    panel.set_corner_radius_all(18)
    panel.content_margin_left = 22
    panel.content_margin_right = 22
    panel.content_margin_top = 16
    panel.content_margin_bottom = 16
    ui_theme.set_stylebox("panel", "PanelContainer", panel)
    ui_theme.set_constant("outline_size", "Label", 0)
    var sb_scroll := StyleBoxEmpty.new()
    ui_theme.set_stylebox("panel", "ScrollContainer", sb_scroll)
    get_tree().root.theme = ui_theme

func _setup_environment() -> void:
    var we := WorldEnvironment.new()
    env = Environment.new()
    var sky := Sky.new()
    var sm := ProceduralSkyMaterial.new()
    sky.sky_material = sm
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.5
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 0.92
    env.tonemap_white = 6.0
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
    env.fog_light_energy = 0.9
    env.fog_sky_affect = 0.0
    we.environment = env
    add_child(we)
    sun = DirectionalLight3D.new()
    sun.shadow_enabled = true
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sun.shadow_bias = 0.06
    sun.shadow_normal_bias = 1.5
    add_child(sun)
    # Lighting follows the phone's clock (dawn, day, golden hour, dusk).
    var h := Levels.hour_now()
    var dayness := clampf(sin(PI * (h - 6.0) / 12.0), 0.0, 1.0)
    var elev := lerpf(14.0, 68.0, dayness)
    var morning := h < 12.0
    sun.rotation_degrees = Vector3(-elev, -60.0 if morning else 120.0, 0)
    var warm := 1.0 - clampf((dayness - 0.15) / 0.5, 0.0, 1.0)
    sun.light_color = Color(1, 0.97, 0.92).lerp(Color(1.0, 0.68, 0.42), warm)
    sun.light_energy = lerpf(0.85, 1.1, dayness)
    sm.sky_top_color = Color("#3f86c8").lerp(Color("#3b4f8a"), warm * 0.6)
    sm.sky_horizon_color = Color("#cfe2ee").lerp(Color("#f2b38a"), warm)
    sm.ground_horizon_color = sm.sky_horizon_color
    sm.ground_bottom_color = Color("#6d6457")
    sm.sun_angle_max = 30.0
    env.fog_light_color = sm.sky_horizon_color
    cam = Camera3D.new()
    cam.near = 0.2
    cam.far = 2600.0
    cam.fov = 62.0
    cam.current = true
    add_child(cam)
    cam.position = Vector3(0, 120, 160)
    cam.look_at(Vector3.ZERO)

func _apply_quality() -> void:
    if sun:
        sun.shadow_enabled = AutoConfig.shadows_enabled()
        sun.directional_shadow_max_distance = AutoConfig.shadow_distance()
    if env:
        env.fog_density = 0.9 / AutoConfig.view_distance()
    if is_instance_valid(car):
        car.set_blob_shadow(not AutoConfig.shadows_enabled())
    if lbl_fps:
        lbl_fps.visible = AutoConfig.show_fps

# ---------------------------------------------------------------- UI helpers
func _label(t: String, sz := 22, col := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = t
    l.add_theme_font_size_override("font_size", sz)
    l.add_theme_color_override("font_color", col)
    return l

func _btn(t: String, cb: Callable, min_size := Vector2(240, 64), sz := 26) -> Button:
    var b := Button.new()
    b.text = t
    b.custom_minimum_size = min_size
    b.add_theme_font_size_override("font_size", sz)
    b.pressed.connect(_on_btn.bind(cb))
    return b

func _on_btn(cb: Callable) -> void:
    audio.play("tick", -10.0)
    cb.call()

func _pad(caption: String, sub_t: String, sz: Vector2) -> TouchPad:
    var p := TouchPad.new()
    p.caption = caption
    p.sub = sub_t
    p.font = font_ui
    p.size = sz
    p.custom_minimum_size = sz
    p.accent = ACCENT
    return p

func _place(c: Control, anchor: Vector2, offset: Vector2, sz: Vector2) -> void:
    c.anchor_left = anchor.x
    c.anchor_right = anchor.x
    c.anchor_top = anchor.y
    c.anchor_bottom = anchor.y
    c.offset_left = offset.x
    c.offset_top = offset.y
    c.offset_right = offset.x + sz.x
    c.offset_bottom = offset.y + sz.y

func _toast(t: String, dur := 2.0, col := Color.WHITE) -> void:
    if lbl_toast == null:
        return
    lbl_toast.text = t
    lbl_toast.add_theme_color_override("font_color", col)
    lbl_toast.modulate.a = 1.0
    toast_t = dur

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
    hud = Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.visible = false
    ui.add_child(hud)

    var info := PanelContainer.new()
    _place(info, Vector2(0, 0), Vector2(14, 12), Vector2(400, 0))
    info.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(info)
    var iv := VBoxContainer.new()
    iv.add_theme_constant_override("separation", 0)
    info.add_child(iv)
    lbl_name = _label("", 24, ACCENT)
    iv.add_child(lbl_name)
    lbl_obj = _label("", 17, Color(1, 1, 1, 0.9))
    lbl_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl_obj.custom_minimum_size = Vector2(356, 0)
    iv.add_child(lbl_obj)

    var top := PanelContainer.new()
    _place(top, Vector2(0.5, 0), Vector2(-120, 12), Vector2(240, 0))
    hud.add_child(top)
    var tv := VBoxContainer.new()
    tv.alignment = BoxContainer.ALIGNMENT_CENTER
    tv.add_theme_constant_override("separation", -4)
    top.add_child(tv)
    lbl_time = _label("00:00", 40, Color.WHITE)
    lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tv.add_child(lbl_time)
    lbl_hits = _label("HITS 0", 18, Color(1, 1, 1, 0.8))
    lbl_hits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tv.add_child(lbl_hits)

    minimap = Minimap.new()
    _place(minimap, Vector2(1, 0), Vector2(-226, 12), Vector2(212, 212))
    minimap.accent = ACCENT
    minimap.set_roads(world.roads2d)
    hud.add_child(minimap)
    lbl_live = _label("", 15, Color.WHITE)
    lbl_live.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _place(lbl_live, Vector2(1, 0), Vector2(-330, 226), Vector2(316, 24))
    lbl_live.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
    lbl_live.add_theme_constant_override("outline_size", 5)
    hud.add_child(lbl_live)
    var pause := _btn("II", _pause, Vector2(64, 64), 26)
    _place(pause, Vector2(1, 0), Vector2(-304, 12), Vector2(64, 64))
    hud.add_child(pause)

    var speed_box := PanelContainer.new()
    _place(speed_box, Vector2(0.5, 1), Vector2(-110, -118), Vector2(220, 104))
    hud.add_child(speed_box)
    var sv := VBoxContainer.new()
    sv.add_theme_constant_override("separation", 0)
    speed_box.add_child(sv)
    var sh := HBoxContainer.new()
    sh.alignment = BoxContainer.ALIGNMENT_CENTER
    sv.add_child(sh)
    lbl_speed = _label("0", 40, Color.WHITE)
    sh.add_child(lbl_speed)
    sh.add_child(_label(" km/h  ", 16, Color(1, 1, 1, 0.7)))
    lbl_gear = _label("D", 34, ACCENT)
    sh.add_child(lbl_gear)
    sensor = SensorBar.new()
    sensor.custom_minimum_size = Vector2(176, 40)
    sv.add_child(sensor)

    stick = VirtualStick.new()
    stick.accent = ACCENT
    hud.add_child(stick)
    brake_pad = _pad("BRAKE", "", Vector2(150, 118))
    brake_pad.base_color = Color("#7a1f1a")
    hud.add_child(brake_pad)
    gas_pad = _pad("GAS", "", Vector2(112, 180))
    gas_pad.base_color = Color("#1f5f3a")
    hud.add_child(gas_pad)
    gear_pad = _pad("D", "tap: D / R", Vector2(120, 78))
    gear_pad.tapped.connect(_toggle_gear)
    hud.add_child(gear_pad)
    horn_pad = _pad("HORN", "", Vector2(92, 64))
    horn_pad.font_size = 18
    horn_pad.tapped.connect(func(): audio.play("horn", -2.0))
    hud.add_child(horn_pad)
    cam_pad = _pad("VIEW", "", Vector2(92, 64))
    cam_pad.font_size = 18
    cam_pad.tapped.connect(_cycle_camera)
    hud.add_child(cam_pad)

    ring = ProgressRing.new()
    _place(ring, Vector2(0.5, 0.5), Vector2(-60, -60), Vector2(120, 120))
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(ring)
    lbl_toast = _label("", 30, Color.WHITE)
    lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    lbl_toast.add_theme_constant_override("outline_size", 8)
    _place(lbl_toast, Vector2(0.5, 0.3), Vector2(-420, -24), Vector2(840, 48))
    ui.add_child(lbl_toast)
    lbl_center = _label("", 120, ACCENT)
    lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl_center.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    lbl_center.add_theme_constant_override("outline_size", 14)
    _place(lbl_center, Vector2(0.5, 0.42), Vector2(-300, -80), Vector2(600, 160))
    hud.add_child(lbl_center)
    lbl_fps = _label("", 14, Color.WHITE)
    _place(lbl_fps, Vector2(0, 1), Vector2(10, -26), Vector2(300, 20))
    ui.add_child(lbl_fps)
    _layout_controls()

func _layout_controls() -> void:
    var right_side := AutoConfig.stick_side == "left"
    var pedals := AutoConfig.control_mode == "pedals"
    # Joystick zone: one side of the screen, lower 70 %.
    stick.anchor_top = 0.3
    stick.anchor_bottom = 1.0
    stick.anchor_left = 0.0 if right_side else 0.55
    stick.anchor_right = 0.45 if right_side else 1.0
    stick.offset_left = 0
    stick.offset_right = 0
    stick.offset_top = 0
    stick.offset_bottom = 0
    stick.steer_only = pedals
    gas_pad.visible = pedals
    gear_pad.visible = pedals
    var ax := 1.0 if right_side else 0.0
    var m := func(x: float, w: float) -> float: return x if right_side else -x - w
    if pedals:
        _place(gas_pad, Vector2(ax, 1), Vector2(m.call(-136, 112), -204), gas_pad.size)
        _place(brake_pad, Vector2(ax, 1), Vector2(m.call(-272, 126), -146), Vector2(126, 118))
        _place(gear_pad, Vector2(ax, 1), Vector2(m.call(-272, 126), -240), Vector2(126, 80))
    else:
        _place(brake_pad, Vector2(ax, 1), Vector2(m.call(-176, 150), -146), Vector2(150, 118))
    _place(horn_pad, Vector2(ax, 0.5), Vector2(m.call(-112, 92), -40), horn_pad.size)
    _place(cam_pad, Vector2(ax, 0.5), Vector2(m.call(-112, 92), 34), cam_pad.size)
    for c in [stick, gas_pad, brake_pad, gear_pad, horn_pad, cam_pad]:
        c.queue_redraw()

func _release_controls() -> void:
    for p in [brake_pad, gas_pad, gear_pad, horn_pad, cam_pad]:
        (p as TouchPad).release()
    stick.release()

# ---------------------------------------------------------------- menus
func _clear(node: Control) -> void:
    for c in node.get_children():
        c.queue_free()

func _show_menu(which: String) -> void:
    state = State.MENU
    screen = which
    get_tree().paused = false
    hud.visible = false
    _clear(overlay)
    _clear(menu_root)
    _clear_level()
    if which != "garage" and is_instance_valid(garage_car):
        garage_car.queue_free()
    Ads.show_banner("menu")
    match which:
        "main": _menu_main()
        "levels": _menu_levels()
        "garage": _menu_garage()
        "settings": _menu_settings()

func _side_panel(width := 460.0) -> VBoxContainer:
    var bg := PanelContainer.new()
    bg.anchor_bottom = 1.0
    bg.offset_right = width
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.05, 0.06, 0.08, 0.84)
    sb.content_margin_left = 36
    sb.content_margin_right = 30
    sb.content_margin_top = 28
    sb.content_margin_bottom = 20 + Ads.reserved_height()
    bg.add_theme_stylebox_override("panel", sb)
    menu_root.add_child(bg)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    bg.add_child(v)
    return v

func _menu_main() -> void:
    var v := _side_panel()
    v.add_child(_label("COIMBATORE", 54, ACCENT))
    var t2 := _label("PARKING CHALLENGE", 34, Color.WHITE)
    t2.add_theme_constant_override("line_spacing", -10)
    v.add_child(t2)
    v.add_child(_label("கோயம்புத்தூர் பார்க்கிங் சவால்", 20, Color(1, 1, 1, 0.75)))
    var sp := Control.new()
    sp.custom_minimum_size = Vector2(0, 8)
    v.add_child(sp)
    v.add_child(_btn("PLAY", func(): _show_menu("levels"), Vector2(380, 70), 30))
    var race_i := _find_level("race")
    if race_i >= 0:
        v.add_child(_btn("RACE: KOVAI GRAND PRIX", func(): _start_level(race_i), Vector2(380, 62), 24))
    v.add_child(_btn("GARAGE", func(): _show_menu("garage"), Vector2(380, 58), 24))
    v.add_child(_btn("SETTINGS", func(): _show_menu("settings"), Vector2(380, 58), 24))
    var fill := Control.new()
    fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(fill)
    var d := Levels.density_now()
    v.add_child(_label("LIVE  %s  -  %s" % [Levels.clock_label(), Levels.density_label(d)], 18, GOOD))
    var credit := _label("Real street layout: (c) OpenStreetMap contributors (ODbL).\nNames removed. Map data %s (%s)." % [CityData.generated().substr(0, 10), CityData.source], 14, Color(1, 1, 1, 0.55))
    v.add_child(credit)

func _find_level(id: String) -> int:
    for i in levels.size():
        if str(levels[i].get("id", "")) == id:
            return i
    return -1

func _kind_label(lv: Dictionary) -> String:
    if str(lv.get("type", "")) == "race":
        return "RACE - %d LAPS" % int(lv.get("laps", 2))
    if lv.get("live", false):
        return "LIVE TRAFFIC"
    return "CAR PARK" if str(lv.get("kind", "")) == "lot" else "PARALLEL PARKING"

func _menu_levels() -> void:
    var top := HBoxContainer.new()
    _place(top, Vector2(0, 0), Vector2(28, 22), Vector2(900, 70))
    menu_root.add_child(top)
    top.add_child(_btn("< BACK", func(): _show_menu("main"), Vector2(150, 60), 22))
    var title := _label("  CHOOSE A CHALLENGE", 38, Color.WHITE)
    top.add_child(title)
    var scroll := ScrollContainer.new()
    scroll.anchor_right = 1.0
    scroll.anchor_bottom = 1.0
    scroll.offset_top = 110
    scroll.offset_left = 28
    scroll.offset_right = -28
    scroll.offset_bottom = -30 - Ads.reserved_height()
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    menu_root.add_child(scroll)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    scroll.add_child(row)
    for i in levels.size():
        row.add_child(_level_card(i))

func _level_card(i: int) -> Control:
    var lv: Dictionary = levels[i]
    var card := Button.new()
    card.custom_minimum_size = Vector2(286, 430)
    card.pressed.connect(_on_btn.bind(_start_level.bind(i)))
    var v := VBoxContainer.new()
    v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    v.offset_left = 22
    v.offset_top = 20
    v.offset_right = -18
    v.offset_bottom = -18
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_theme_constant_override("separation", 6)
    card.add_child(v)
    var num := _label("%02d" % (i + 1), 52, ACCENT)
    v.add_child(num)
    var kind := _label(_kind_label(lv), 16, GOOD if lv.get("live", false) else Color(1, 1, 1, 0.6))
    v.add_child(kind)
    var nm := _label(str(lv.get("name", "")), 28, Color.WHITE)
    nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(nm)
    v.add_child(_label(str(lv.get("tamil", "")), 16, Color(1, 1, 1, 0.7)))
    var br := _label(str(lv.get("brief", "")), 15, Color(1, 1, 1, 0.65))
    br.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    br.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(br)
    var diff := _label("DIFFICULTY " + "|".repeat(int(lv.get("difficulty", 1))), 15, ACCENT)
    v.add_child(diff)
    var stars := StarRow.new()
    stars.stars = AutoConfig.stars_for(str(lv.get("id", "")))
    stars.custom_minimum_size = Vector2(150, 40)
    v.add_child(stars)
    for c in v.get_children():
        (c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    return card

func _menu_garage() -> void:
    var v := _side_panel(480)
    var top := HBoxContainer.new()
    v.add_child(top)
    top.add_child(_btn("< BACK", func(): _show_menu("main"), Vector2(140, 56), 22))
    top.add_child(_label("   GARAGE", 36, Color.WHITE))
    var spec := VehicleCatalog.get_car(AutoConfig.car_index)
    v.add_child(_label(str(spec.name), 32, ACCENT))
    v.add_child(_label("%s  -  %.2f m x %.2f m" % [spec["class"], spec.length, spec.width], 18, Color(1, 1, 1, 0.75)))
    var stat := func(n: String, val: float) -> void:
        var h := HBoxContainer.new()
        var l := _label(n, 18, Color(1, 1, 1, 0.8))
        l.custom_minimum_size = Vector2(110, 0)
        h.add_child(l)
        var bar := ProgressBar.new()
        bar.show_percentage = false
        bar.custom_minimum_size = Vector2(260, 16)
        bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        bar.value = val * 100.0
        var fg := StyleBoxFlat.new()
        fg.bg_color = ACCENT
        fg.set_corner_radius_all(6)
        var bgs := StyleBoxFlat.new()
        bgs.bg_color = Color(1, 1, 1, 0.12)
        bgs.set_corner_radius_all(6)
        bar.add_theme_stylebox_override("fill", fg)
        bar.add_theme_stylebox_override("background", bgs)
        h.add_child(bar)
        v.add_child(h)
    stat.call("SPEED", inverse_lerp(9.0, 12.0, float(spec.speed)))
    stat.call("TURNING", inverse_lerp(29.0, 40.0, float(spec.turn)))
    stat.call("COMPACT", 1.0 - inverse_lerp(3.5, 4.8, float(spec.length)))
    var nav := HBoxContainer.new()
    nav.add_theme_constant_override("separation", 12)
    v.add_child(nav)
    nav.add_child(_btn("< PREV", func(): _garage_step(-1), Vector2(190, 60), 22))
    nav.add_child(_btn("NEXT >", func(): _garage_step(1), Vector2(190, 60), 22))
    v.add_child(_label("PAINT", 18, Color(1, 1, 1, 0.7)))
    var grid := GridContainer.new()
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    v.add_child(grid)
    for k in range(-1, VehicleCatalog.PAINTS.size()):
        var b := Button.new()
        b.custom_minimum_size = Vector2(62, 46)
        var sb := StyleBoxFlat.new()
        sb.bg_color = spec.color if k < 0 else VehicleCatalog.PAINTS[k]
        sb.set_corner_radius_all(10)
        sb.border_color = ACCENT if k == AutoConfig.paint_index else Color(1, 1, 1, 0.3)
        sb.set_border_width_all(4 if k == AutoConfig.paint_index else 2)
        for st in ["normal", "hover", "pressed"]:
            b.add_theme_stylebox_override(st, sb)
        b.pressed.connect(_set_paint.bind(k))
        grid.add_child(b)
    v.add_child(_label("Generic vehicle classes sized like India's best-selling cars. No real brands.", 14, Color(1, 1, 1, 0.5)))
    _spawn_garage_car()

func _toggle_gear() -> void:
    if is_instance_valid(car):
        car.gear = -car.gear
        gear_pad.caption = "D" if car.gear > 0 else "R"
        gear_pad.queue_redraw()

func _set_paint(k: int) -> void:
    AutoConfig.paint_index = k
    AutoConfig.save()
    _show_menu("garage")

func _settings_back() -> void:
    _layout_controls()
    _show_menu("main")

func _set_option(cb: Callable, val: String) -> void:
    cb.call(val)
    _show_menu("settings")

func _opt_controls(x: String) -> void:
    AutoConfig.control_mode = x
    AutoConfig.save()

func _opt_side(x: String) -> void:
    AutoConfig.stick_side = x
    AutoConfig.save()

func _opt_sound(x: String) -> void:
    AutoConfig.sound_on = x == "on"
    audio.enabled = AutoConfig.sound_on
    AutoConfig.save()

func _opt_fps(x: String) -> void:
    AutoConfig.show_fps = x == "on"
    AutoConfig.save()
    _apply_quality()

func _garage_step(d: int) -> void:
    AutoConfig.car_index = posmod(AutoConfig.car_index + d, VehicleCatalog.CARS.size())
    AutoConfig.paint_index = -1
    AutoConfig.save()
    _show_menu("garage")

func _paint() -> Variant:
    if AutoConfig.paint_index < 0 or AutoConfig.paint_index >= VehicleCatalog.PAINTS.size():
        return null
    return VehicleCatalog.PAINTS[AutoConfig.paint_index]

func _garage_spot() -> Dictionary:
    if levels.is_empty():
        return {"p": Vector3.ZERO, "yaw": 0.0}
    var lv: Dictionary = levels[0]
    return {"p": Vector3(float(lv.spawn[0]), 0, float(lv.spawn[1])), "yaw": float(lv.yaw)}

func _spawn_garage_car() -> void:
    if is_instance_valid(garage_car):
        garage_car.queue_free()
    garage_car = PlayerCar.new()
    garage_car.configure(VehicleCatalog.get_car(AutoConfig.car_index), _paint())
    garage_car.frozen = true
    game_root.add_child(garage_car)
    var spot := _garage_spot()
    garage_car.place(spot.p, spot.yaw)
    garage_car.set_blob_shadow(not AutoConfig.shadows_enabled())

func _menu_settings() -> void:
    var v := _side_panel(640)
    var top := HBoxContainer.new()
    v.add_child(top)
    top.add_child(_btn("< BACK", _settings_back, Vector2(140, 56), 22))
    top.add_child(_label("   SETTINGS", 36, Color.WHITE))
    var seg := func(title: String, opts: Array, current: String, cb: Callable) -> void:
        v.add_child(_label(title, 18, Color(1, 1, 1, 0.7)))
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 8)
        v.add_child(h)
        for o in opts:
            var b := Button.new()
            b.text = str(o[1])
            b.custom_minimum_size = Vector2(130, 52)
            if str(o[0]) == current:
                var sel := StyleBoxFlat.new()
                sel.bg_color = ACCENT
                sel.set_corner_radius_all(14)
                for st in ["normal", "hover", "pressed"]:
                    b.add_theme_stylebox_override(st, sel)
                b.add_theme_color_override("font_color", INK)
                b.add_theme_color_override("font_hover_color", INK)
            b.pressed.connect(_set_option.bind(cb, str(o[0])))
            h.add_child(b)
    seg.call("GRAPHICS  (auto picks for your phone: %s)" % AutoConfig.TIER_NAMES[AutoConfig.detected_tier], [["auto", "AUTO"], ["low", "LOW"], ["medium", "MEDIUM"], ["high", "HIGH"]], AutoConfig.quality_mode, func(x): AutoConfig.set_quality(x))
    seg.call("CONTROLS", [["stick", "JOYSTICK"], ["pedals", "STICK + PEDALS"]], AutoConfig.control_mode, _opt_controls)
    seg.call("JOYSTICK SIDE", [["left", "LEFT"], ["right", "RIGHT"]], AutoConfig.stick_side, _opt_side)
    seg.call("SOUND", [["on", "ON"], ["off", "OFF"]], "on" if AutoConfig.sound_on else "off", _opt_sound)
    seg.call("SHOW FPS", [["on", "ON"], ["off", "OFF"]], "on" if AutoConfig.show_fps else "off", _opt_fps)
    var info := _label("Joystick: push up to drive, pull down to brake and reverse, left/right to steer. STICK + PEDALS: the stick only steers; use GAS, BRAKE and the D/R gear.", 15, Color(1, 1, 1, 0.55))
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(info)

# ---------------------------------------------------------------- level flow
func _clear_level() -> void:
    for t in traffic:
        if is_instance_valid(t):
            t.queue_free()
    traffic.clear()
    for r in rivals:
        if is_instance_valid(r):
            r.queue_free()
    rivals.clear()
    for c in fx_root.get_children():
        c.queue_free()
    gates.clear()
    if is_instance_valid(car):
        car.queue_free()
    car = null
    if arrow:
        arrow.visible = false

func _start_level(i: int) -> void:
    if levels.is_empty():
        return
    Ads.hide_banner()
    _clear(menu_root)
    _clear(overlay)
    _clear_level()
    if is_instance_valid(garage_car):
        garage_car.queue_free()
    level_idx = clampi(i, 0, levels.size() - 1)
    level = levels[level_idx]
    world.spawn_level_props(level)
    elapsed = 0.0
    hits = 0
    kerb_hits = 0
    park_hold = 0.0
    car = PlayerCar.new()
    car.configure(VehicleCatalog.get_car(AutoConfig.car_index), _paint())
    car.collision_mask = 1 | 2
    car.crash.connect(_on_crash)
    game_root.add_child(car)
    var sp := Vector3(float(level.spawn[0]), 0, float(level.spawn[1]))
    car.place(sp, float(level.yaw))
    car.pedal_mode = AutoConfig.control_mode == "pedals"
    car.gear = 1
    gear_pad.caption = "D"
    car.set_blob_shadow(not AutoConfig.shadows_enabled())
    cam_yaw = float(level.yaw)
    _layout_controls()
    _release_controls()
    hud.visible = true
    ring.value = 0.0
    lbl_name.text = str(level.get("name", ""))
    lbl_obj.text = str(level.get("brief", ""))
    density = Levels.density_now()
    var tr := float(level.get("traffic", 0.5))
    if level.get("live", false):
        tr = density
        lbl_live.text = "LIVE %s - %s" % [Levels.clock_label(), Levels.density_label(density)]
    else:
        tr *= 0.65 + 0.35 * density
        lbl_live.text = "%s - %s" % [Levels.clock_label(), Levels.density_label(density)]
    _spawn_traffic(int(round(30.0 * tr * AutoConfig.traffic_scale())), sp)
    var route := PackedVector2Array()
    if str(level.get("type", "")) == "race":
        _setup_race()
    else:
        _setup_bay()
        var r: Array = level.get("route", [])
        for k in range(0, r.size() - 1, 2):
            route.append(Vector2(float(r[k]), float(r[k + 1])))
        minimap.target = Vector2(bay_c.x, bay_c.z)
        minimap.route = route
    _snap_camera()
    get_tree().paused = false
    if str(level.get("type", "")) == "race":
        state = State.COUNTDOWN
        countdown = 3.99
        car.frozen = true
    else:
        state = State.PLAYING
        car.frozen = false
        _toast(str(level.get("name", "")), 2.5, ACCENT)

func _spawn_traffic(count: int, avoid: Vector3) -> void:
    var lanes: Array = world.lanes
    if lanes.is_empty() or count <= 0:
        return
    var lens: Array = []
    var total := 0.0
    for l in lanes:
        var pts: PackedVector3Array = l
        var ln := 0.0
        for k in range(1, pts.size()):
            ln += pts[k].distance_to(pts[k - 1])
        lens.append(ln)
        total += ln
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var kinds := ["car", "car", "car", "car", "bike", "bike", "bike", "auto", "auto", "auto", "bus", "lorry"]
    var placed: Array = []
    var tries := 0
    while traffic.size() < count and tries < count * 12:
        tries += 1
        var pick := rng.randf() * total
        var li := 0
        while li < lanes.size() - 1 and pick > float(lens[li]):
            pick -= float(lens[li])
            li += 1
        var s := rng.randf_range(5.0, maxf(6.0, float(lens[li]) - 10.0))
        var t := TrafficCar.new()
        var pts: PackedVector3Array = lanes[li]
        # Find position quickly to test spacing.
        var acc := 0.0
        var pos := pts[0]
        for k in range(1, pts.size()):
            var seg := pts[k].distance_to(pts[k - 1])
            if acc + seg >= s:
                pos = pts[k - 1].lerp(pts[k], (s - acc) / maxf(seg, 0.001))
                break
            acc += seg
        if pos.distance_to(avoid) < 28.0:
            t.free()
            continue
        var ok := true
        for q in placed:
            if (q as Vector3).distance_to(pos) < 14.0:
                ok = false
                break
        if not ok:
            t.free()
            continue
        placed.append(pos)
        t.setup(pts, s, kinds[rng.randi() % kinds.size()], rng)
        t.player = car
        t.player_half = car.length * 0.5
        t.honk.connect(func(_p): audio.play("horn", -14.0))
        game_root.add_child(t)
        traffic.append(t)
    for t in traffic:
        t.others = traffic

func _setup_bay() -> void:
    var b: Dictionary = level.bay
    bay_c = Vector3(float(b.c[0]), 0, float(b.c[1]))
    bay_yaw = float(b.yaw)
    bay_w = float(b.w)
    bay_l = float(b.l)
    bay_yaws = b.get("yaws", [bay_yaw])
    var root := Node3D.new()
    root.position = bay_c
    root.rotation.y = bay_yaw
    fx_root.add_child(root)
    bay_mat = StandardMaterial3D.new()
    bay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bay_mat.albedo_color = ACCENT
    var fill := StandardMaterial3D.new()
    fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    fill.albedo_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.22)
    var bt := MeshBatcher.new()
    var hw := bay_w * 0.5
    var hl := bay_l * 0.5
    bt.box(Vector3(-hw, 0.03, 0), Vector3(0.14, 0.03, bay_l), bay_mat)
    bt.box(Vector3(hw, 0.03, 0), Vector3(0.14, 0.03, bay_l), bay_mat)
    bt.box(Vector3(0, 0.03, -hl), Vector3(bay_w + 0.14, 0.03, 0.14), bay_mat)
    bt.box(Vector3(0, 0.03, hl), Vector3(bay_w + 0.14, 0.03, 0.14), bay_mat)
    bt.box(Vector3(0, 0.02, 0), Vector3(bay_w, 0.01, bay_l), fill)
    if bay_yaws.size() == 1:
        # Chevron showing which way the car must face.
        bt.add_mesh(MeshBatcher.unit_prism(), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.2, 0.02)), Vector3(0, 0.04, -hl * 0.4)), bay_mat)
    bt.commit(root, "Bay", false)
    beacon_mat = StandardMaterial3D.new()
    beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beacon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    beacon_mat.albedo_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.18)
    var beacon := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.9
    cyl.bottom_radius = 1.4
    cyl.height = 30.0
    cyl.cap_top = false
    cyl.cap_bottom = false
    beacon.mesh = cyl
    beacon.material_override = beacon_mat
    beacon.position = Vector3(0, 15, 0)
    beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(beacon)

func _setup_race() -> void:
    race_path = PackedVector3Array()
    var p: Array = level.path
    for k in range(0, p.size() - 1, 2):
        race_path.append(Vector3(float(p[k]), 0, float(p[k + 1])))
    race_path.append(race_path[0])
    race_cum = PackedFloat32Array()
    race_cum.resize(race_path.size())
    race_cum[0] = 0.0
    for k in range(1, race_path.size()):
        race_cum[k] = race_cum[k - 1] + race_path[k].distance_to(race_path[k - 1])
    race_total = race_cum[race_cum.size() - 1]
    laps = int(level.get("laps", 2))
    lap = 0
    gate_i = 0
    player_s = 0.0
    for cp in level.get("checkpoints", []):
        gates.append({"p": Vector3(float(cp[0]), 0, float(cp[1])), "yaw": float(cp[2]), "finish": false})
    var y0 := float(level.yaw)
    gates.append({"p": race_path[0] + Vector3(-sin(y0), 0, -cos(y0)) * 2.0, "yaw": y0, "finish": true})
    for g in gates:
        g.node = _make_gate(g.p, g.yaw, g.finish)
    var route := PackedVector2Array()
    for q in race_path:
        route.append(Vector2(q.x, q.z))
    minimap.route = route
    var rng := RandomNumberGenerator.new()
    rng.seed = 77
    # Race tune: open-road speeds for everyone.
    car.spec.speed = float(car.spec.speed) * 1.6
    car.spec.accel = float(car.spec.accel) * 1.45
    var top: float = float(car.spec.speed)
    for k in int(level.get("rivals", 3)):
        var r := TrafficCar.new()
        r.racer = true
        r.loop = true
        r.setup(race_path, race_total - 9.0 * float(k + 1), "car", rng, RIVAL_COLOURS[k % RIVAL_COLOURS.size()])
        r.lap = -1
        r.lateral = 1.8 if k % 2 == 0 else -1.8
        r.base_speed = top * (0.8 + 0.05 * float(k))
        r.laps_to_finish = laps
        r.cur_speed = 0.0
        r._apply_transform()
        var tag := Label3D.new()
        tag.text = RIVAL_NAMES[k % RIVAL_NAMES.size()]
        tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        tag.font = world.sign_font
        tag.font_size = 48
        tag.pixel_size = 0.012
        tag.outline_size = 10
        tag.modulate = RIVAL_COLOURS[k % RIVAL_COLOURS.size()].lightened(0.4)
        tag.position = Vector3(0, 2.6, 0)
        tag.no_depth_test = true
        r.add_child(tag)
        game_root.add_child(r)
        rivals.append(r)
    for t in traffic:
        t.others = traffic + rivals
    _update_gate_visibility()

func _make_gate(p: Vector3, yaw: float, finish: bool) -> Node3D:
    var n := Node3D.new()
    n.position = p
    n.rotation.y = yaw
    fx_root.add_child(n)
    var b := MeshBatcher.new()
    var col := Color("#e53935") if finish else ACCENT
    var m := Mats.glow(col, 0.6)
    var white := Mats.plain(Color.WHITE)
    for sx in [-6.5, 6.5]:
        b.box(Vector3(sx, 2.6, 0), Vector3(0.35, 5.2, 0.35), white)
    b.box(Vector3(0, 5.1, 0), Vector3(13.4, 0.9, 0.25), m)
    b.commit(n, "Gate", false)
    var lbl := Label3D.new()
    lbl.text = "FINISH" if finish else "CHECKPOINT"
    lbl.font = world.sign_font
    lbl.font_size = 72
    lbl.pixel_size = 0.012
    lbl.modulate = Color.WHITE if finish else INK
    lbl.position = Vector3(0, 5.1, 0.14)
    lbl.double_sided = true
    n.add_child(lbl)
    return n

func _update_gate_visibility() -> void:
    for k in gates.size():
        var node: Node3D = gates[k].node
        node.visible = k == gate_i or k == (gate_i + 1) % gates.size()

# ---------------------------------------------------------------- per-frame
func _process(delta: float) -> void:
    if lbl_fps and lbl_fps.visible:
        lbl_fps.text = "%d FPS  %s  scale %.2f" % [Engine.get_frames_per_second(), AutoConfig.tier_label(), AutoConfig.render_scale]
    if toast_t > 0.0 and lbl_toast:
        toast_t -= delta
        lbl_toast.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
    match state:
        State.MENU:
            _menu_camera(delta)
        State.COUNTDOWN:
            _countdown(delta)
            _drive_inputs()
            _update_camera(delta)
            _update_hud()
        State.PLAYING:
            elapsed += delta
            _drive_inputs()
            if str(level.get("type", "")) == "race":
                _race_logic(delta)
            else:
                _check_parking(delta)
            _update_camera(delta)
            _update_hud()
            _update_arrow(delta)
            audio.update_engine(car.speed, car.throttle)
            audio.update_sensor(car.rear_dist if car.reversing else car.front_dist, absf(car.speed) > 0.02 or absf(car.throttle) > 0.05, delta)
        _:
            if is_instance_valid(car):
                audio.update_engine(0.0, 0.0)

func _drive_inputs() -> void:
    if not is_instance_valid(car):
        return
    var v := stick.value
    var steer := signf(v.x) * pow(absf(v.x), 1.25)
    var thr := -v.y
    var brake := 1.0 if brake_pad.down else 0.0
    if car.pedal_mode:
        thr = 1.0 if gas_pad.down else 0.0
    # Keyboard (desktop / testing)
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        thr = 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        thr = -1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        steer = -1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        steer = 1.0
    if Input.is_key_pressed(KEY_SPACE):
        brake = 1.0
    car.throttle = thr
    car.steer_input = steer
    car.brake_input = brake

func _countdown(delta: float) -> void:
    var prev := int(ceil(countdown))
    countdown -= delta
    var now := int(ceil(countdown))
    if now != prev and now > 0:
        audio.play("tick")
    if countdown > 0.0:
        lbl_center.text = str(now)
    else:
        lbl_center.text = "GO!"
        audio.play("go")
        state = State.PLAYING
        car.frozen = false
        for r in rivals:
            r.racing = true
        var tw := create_tween()
        tw.tween_interval(0.8)
        tw.tween_callback(func(): lbl_center.text = "")

func _update_hud() -> void:
    if not is_instance_valid(car):
        return
    var t := elapsed
    lbl_time.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]
    lbl_speed.text = str(int(absf(car.speed) * 3.6))
    if car.pedal_mode:
        lbl_gear.text = "D" if car.gear > 0 else "R"
    else:
        lbl_gear.text = "R" if car.speed < -0.05 else ("N" if absf(car.speed) < 0.05 and absf(car.throttle) < 0.05 else "D")
    sensor.front = car.front_dist
    sensor.rear = car.rear_dist
    sensor.queue_redraw()
    if str(level.get("type", "")) == "race":
        lbl_hits.text = "LAP %d/%d   POS %d/%d" % [mini(lap + 1, laps), laps, race_place, rivals.size() + 1]
    else:
        lbl_hits.text = "HITS %d   KERB %d   %dm" % [hits, kerb_hits, int(car.global_position.distance_to(bay_c))]
    minimap.car_pos = Vector2(car.global_position.x, car.global_position.z)
    minimap.car_yaw = car.rotation.y
    var marks: Array = []
    for tc in traffic:
        if is_instance_valid(tc) and tc.global_position.distance_to(car.global_position) < 160.0:
            marks.append({"p": Vector2(tc.global_position.x, tc.global_position.z), "c": Color(0.25, 0.25, 0.3, 0.8), "r": 3.0})
    for k in rivals.size():
        var r: TrafficCar = rivals[k]
        marks.append({"p": Vector2(r.global_position.x, r.global_position.z), "c": RIVAL_COLOURS[k % RIVAL_COLOURS.size()], "r": 5.0})
    minimap.markers = marks

func _snap_camera() -> void:
    if not is_instance_valid(car):
        return
    var fwd := car.forward()
    cam.global_position = car.global_position - fwd * 7.0 + Vector3.UP * 3.2
    cam.look_at(car.global_position + fwd * 3.0, Vector3.UP)

func _cycle_camera() -> void:
    AutoConfig.camera_mode = (AutoConfig.camera_mode + 1) % 3
    AutoConfig.save()
    _toast(["CHASE VIEW", "HIGH VIEW", "TOP-DOWN VIEW"][AutoConfig.camera_mode], 1.0)

func _update_camera(delta: float) -> void:
    if not is_instance_valid(car):
        return
    cam_yaw = lerp_angle(cam_yaw, car.rotation.y, clampf(delta * 3.5, 0.0, 1.0))
    var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
    var p := car.global_position
    var desired: Vector3
    var look: Vector3
    var up := Vector3.UP
    match AutoConfig.camera_mode:
        1:
            desired = p - fwd * 11.0 + Vector3.UP * 7.5
            look = p + fwd * 3.0
        2:
            desired = p + Vector3.UP * 21.0
            look = p
            up = fwd
        _:
            desired = p - fwd * 6.8 + Vector3.UP * 3.0
            look = p + fwd * 3.0 + Vector3.UP * 0.6
    if AutoConfig.camera_mode != 2:
        var from := p + Vector3.UP * 2.0
        var q := PhysicsRayQueryParameters3D.create(from, desired, 1)
        q.exclude = [car.get_rid()]
        var hit := get_world_3d().direct_space_state.intersect_ray(q)
        if not hit.is_empty():
            desired = (hit.position as Vector3) + (from - (hit.position as Vector3)).normalized() * 0.5
    cam.global_position = cam.global_position.lerp(desired, 1.0 - exp(-delta * 7.0))
    if shake > 0.0:
        shake = maxf(0.0, shake - delta * 2.5)
        cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.25
    if cam.global_position.distance_to(look) > 0.1:
        cam.look_at(look, up)

func _menu_camera(delta: float) -> void:
    orbit += delta * 0.06
    if screen == "garage" and is_instance_valid(garage_car):
        var c := garage_car.global_position
        orbit += delta * 0.25
        var tp := c + Vector3(cos(orbit) * 7.5, 2.6, sin(orbit) * 7.5)
        cam.global_position = cam.global_position.lerp(tp, 1.0 - exp(-delta * 3.0))
        cam.look_at(c + Vector3(0, 0.8, 0) + cam.global_transform.basis.x * 1.6, Vector3.UP)
        return
    var tp2 := Vector3(cos(orbit) * 170.0 - 60.0, 62.0, sin(orbit) * 170.0 + 20.0)
    cam.global_position = cam.global_position.lerp(tp2, 1.0 - exp(-delta * 1.5))
    cam.look_at(Vector3(-60.0, 0, 20.0), Vector3.UP)

func _build_arrow() -> void:
    arrow = MeshInstance3D.new()
    var b := MeshBatcher.new()
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = ACCENT
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    var edge := StandardMaterial3D.new()
    edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    edge.albedo_color = Color(0.1, 0.08, 0.02)
    edge.cull_mode = BaseMaterial3D.CULL_DISABLED
    var up := Vector3.UP
    # Outline (slightly larger, below) then the arrow face.
    var s := 1.18
    b.tri(Vector3(0, -0.02, -1.15 * s), Vector3(0.82 * s, -0.02, -0.15 * s), Vector3(-0.82 * s, -0.02, -0.15 * s), up, edge)
    b.quad(Vector3(-0.34 * s, -0.02, -0.2 * s), Vector3(0.34 * s, -0.02, -0.2 * s), Vector3(0.34 * s, -0.02, 0.8 * s), Vector3(-0.34 * s, -0.02, 0.8 * s), up, edge)
    b.tri(Vector3(0, 0, -1.15), Vector3(0.82, 0, -0.15), Vector3(-0.82, 0, -0.15), up, m)
    b.quad(Vector3(-0.3, 0, -0.2), Vector3(0.3, 0, -0.2), Vector3(0.3, 0, 0.75), Vector3(-0.3, 0, 0.75), up, m)
    arrow.mesh = b.commit_mesh()
    arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    arrow.visible = false
    add_child(arrow)

func _target_point() -> Vector3:
    if str(level.get("type", "")) == "race" and gates.size() > 0:
        return gates[gate_i].p
    return bay_c

func _update_arrow(delta: float) -> void:
    if not is_instance_valid(car):
        return
    var tp := _target_point()
    var d := tp - car.global_position
    d.y = 0
    var show := d.length() > 14.0
    arrow.visible = show
    if not show:
        return
    var yaw := atan2(-d.x, -d.z)
    arrow.global_position = car.global_position + Vector3.UP * 2.9
    arrow.rotation = Vector3(-0.35, lerp_angle(arrow.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0)), 0)
    if beacon_mat:
        beacon_mat.albedo_color.a = 0.14 + 0.08 * sin(Time.get_ticks_msec() * 0.005)

# ---------------------------------------------------------------- rules
func _on_crash(kind: String, impact: float) -> void:
    if state != State.PLAYING:
        return
    shake = clampf(impact * 0.25, 0.15, 1.0)
    if kind == "kerb":
        kerb_hits += 1
        audio.play("crash", -14.0)
        _toast("KERB!", 0.8, ACCENT)
    else:
        hits += 1
        audio.play("crash", linear_to_db(clampf(impact / 5.0, 0.3, 1.0)))
        _toast("BUMP!  -80" if str(level.get("type", "")) != "race" else "CONTACT!", 1.0, Color("#ff6b5e"))

func _check_parking(delta: float) -> void:
    var inv := Transform3D(Basis(Vector3.UP, bay_yaw), bay_c).affine_inverse()
    var inside := true
    for c in car.corners():
        var l := inv * c
        if absf(l.x) > bay_w * 0.5 + 0.05 or absf(l.z) > bay_l * 0.5 + 0.05:
            inside = false
            break
    var aligned := false
    for y in bay_yaws:
        if absf(angle_difference(car.rotation.y, float(y))) < deg_to_rad(11.0):
            aligned = true
    var near := car.global_position.distance_to(bay_c) < 3.5
    if inside and aligned:
        bay_mat.albedo_color = GOOD
        if absf(car.speed) < 0.3:
            park_hold += delta
        else:
            park_hold = 0.0
    else:
        bay_mat.albedo_color = ACCENT
        park_hold = 0.0
        if near and absf(car.speed) < 0.4 and toast_t <= 0.0:
            if not aligned and bay_yaws.size() == 1 and inside == false and _aligned_reverse():
                _toast("Wrong way round - follow the arrow in the bay", 1.6, ACCENT)
            elif not aligned:
                _toast("Straighten up", 1.0, ACCENT)
            else:
                _toast("Get fully inside the lines", 1.0, ACCENT)
    ring.value = clampf(park_hold / 1.2, 0.0, 1.0)
    ring.queue_redraw()
    if park_hold >= 1.2:
        _finish_park()

func _aligned_reverse() -> bool:
    for y in bay_yaws:
        if absf(angle_difference(car.rotation.y, float(y) + PI)) < deg_to_rad(15.0):
            return true
    return false

func _finish_park() -> void:
    state = State.RESULT
    car.frozen = true
    ring.value = 0.0
    audio.play("win")
    var par := float(level.get("par", 60.0))
    var score := maxi(0, 1000 + int(maxf(0.0, par - elapsed) * 10.0) - hits * 80 - kerb_hits * 30)
    var stars := 1
    if hits == 0 and elapsed <= par:
        stars = 3
    elif hits <= 2 and elapsed <= par * 1.6:
        stars = 2
    var best := AutoConfig.record_result(str(level.id), stars, elapsed, score)
    _show_result("PARKED!", stars, [
        "Time  %s   (par %s)" % [_fmt(elapsed), _fmt(par)],
        "Hits  %d     Kerb touches  %d" % [hits, kerb_hits],
        "Score  %d%s" % [score, "   NEW BEST!" if best else ""],
    ])

func _race_logic(_delta: float) -> void:
    var p := car.global_position
    var g: Dictionary = gates[gate_i]
    if Vector2(p.x - g.p.x, p.z - g.p.z).length() < 11.0:
        if g.finish:
            lap += 1
            if lap >= laps:
                _finish_race()
                return
            audio.play("check")
            _toast("LAP %d / %d" % [lap + 1, laps], 1.5, ACCENT)
        else:
            audio.play("check", -6.0)
        gate_i = (gate_i + 1) % gates.size()
        _update_gate_visibility()
    # Player progress along the loop.
    var best_d := 1e9
    var best_s := 0.0
    for k in range(race_path.size() - 1):
        var a := race_path[k]
        var b := race_path[k + 1]
        var ab := b - a
        var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
        var q := a + ab * t
        var dd := q.distance_squared_to(p)
        if dd < best_d:
            best_d = dd
            best_s = race_cum[k] + ab.length() * t
    if gate_i <= 1 and best_s > race_total * 0.7:
        best_s -= race_total
    player_s = float(lap) * race_total + best_s
    var place := 1
    for r in rivals:
        var rp: float = (r as TrafficCar).progress()
        if rp > player_s:
            place += 1
        r.rubber = 1.1 if rp < player_s - 90.0 else (0.92 if rp > player_s + 160.0 else 1.0)
    race_place = place

func _finish_race() -> void:
    state = State.RESULT
    car.frozen = true
    audio.play("win")
    var place := 1
    for r in rivals:
        if (r as TrafficCar).lap >= laps:
            place += 1
    var stars := 3 if place == 1 else (2 if place == 2 else 1)
    var score := maxi(0, 3000 - (place - 1) * 700 - hits * 50 + int(maxf(0.0, float(level.get("par", 200.0)) - elapsed) * 5.0))
    var best := AutoConfig.record_result(str(level.id), stars, elapsed, score)
    var suffix: String = ["st", "nd", "rd", "th"][mini(place - 1, 3)]
    _show_result("%d%s PLACE!" % [place, suffix], stars, [
        "Race time  %s" % _fmt(elapsed),
        "Contacts  %d" % hits,
        "Score  %d%s" % [score, "   NEW BEST!" if best else ""],
    ])

func _fmt(t: float) -> String:
    return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]

# ---------------------------------------------------------------- overlays
func _dim() -> Control:
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.5)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(dim)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    panel.custom_minimum_size = Vector2(520, 0)
    overlay.add_child(panel)
    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 12)
    panel.add_child(v)
    return v

func _show_result(title: String, stars: int, lines: Array) -> void:
    _release_controls()
    hud.visible = false
    arrow.visible = false
    _clear(overlay)
    var v := _dim()
    var t := _label(title, 52, ACCENT)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(t)
    var sr := StarRow.new()
    sr.stars = stars
    sr.star_size = 26
    sr.custom_minimum_size = Vector2(160, 60)
    sr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    v.add_child(sr)
    for ln in lines:
        var l := _label(str(ln), 24, Color.WHITE)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(l)
    var h := HBoxContainer.new()
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    h.add_theme_constant_override("separation", 12)
    v.add_child(h)
    h.add_child(_btn("RETRY", func(): _start_level(level_idx), Vector2(150, 62), 24))
    if level_idx + 1 < levels.size():
        h.add_child(_btn("NEXT", func(): _start_level(level_idx + 1), Vector2(150, 62), 24))
    h.add_child(_btn("LEVELS", func(): _show_menu("levels"), Vector2(150, 62), 24))
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, Ads.reserved_height())
    v.add_child(gap)
    Ads.show_banner("result")

func _pause() -> void:
    if state != State.PLAYING and state != State.COUNTDOWN:
        return
    state = State.PAUSED
    get_tree().paused = true
    _release_controls()
    _clear(overlay)
    var v := _dim()
    var t := _label("PAUSED", 48, ACCENT)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(t)
    v.add_child(_btn("RESUME", _resume, Vector2(360, 64), 26))
    v.add_child(_btn("RESTART", func(): _start_level(level_idx), Vector2(360, 60), 24))
    v.add_child(_btn("CHANGE VIEW", _cycle_camera, Vector2(360, 56), 22))
    v.add_child(_btn("QUIT TO MENU", func(): _show_menu("main"), Vector2(360, 56), 22))

func _resume() -> void:
    _clear(overlay)
    get_tree().paused = false
    state = State.COUNTDOWN if countdown > 0.0 and str(level.get("type", "")) == "race" else State.PLAYING

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE, KEY_P:
                if state == State.PAUSED:
                    _resume()
                else:
                    _pause()
            KEY_C:
                if state == State.PLAYING:
                    _cycle_camera()
            KEY_H:
                audio.play("horn", -2.0)
            KEY_R:
                if state == State.PLAYING or state == State.RESULT:
                    _start_level(level_idx)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        _pause()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        match state:
            State.PLAYING, State.COUNTDOWN:
                _pause()
            State.PAUSED:
                _resume()
            State.RESULT:
                _show_menu("levels")
            State.MENU:
                if screen == "main":
                    get_tree().quit()
                else:
                    _show_menu("main")
