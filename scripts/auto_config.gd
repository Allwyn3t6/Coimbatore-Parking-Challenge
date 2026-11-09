extends Node
## Autoload "AutoConfig".
## Detects the device, picks a graphics tier, adapts render resolution to the
## measured frame rate, scales the UI for the physical screen size and keeps
## player settings and best scores in user://settings.cfg.

signal changed

const SAVE_PATH := "user://settings.cfg"
const TIER_NAMES := ["Low", "Medium", "High"]

var quality_mode := "auto"      # auto | low | medium | high
var detected_tier := 2
var tier := 2
var control_mode := "stick"     # stick (one analog stick) | pedals (stick steers, pedals drive)
var stick_side := "left"        # left | right
var sound_on := true
var show_fps := false
var camera_mode := 0
var car_index := 0
var paint_index := -1
var best := {}                  # level id -> {"stars": int, "time": float, "score": int}

var render_scale := 1.0
var _fps_acc := 0.0
var _fps_frames := 0
var _adapt_enabled := false
var _settle := 3.0

func _ready() -> void:
    _load()
    _detect()
    _apply_ui_scale()
    get_tree().root.size_changed.connect(_apply_ui_scale)
    apply()

func _detect() -> void:
    var mobile := OS.has_feature("mobile") or OS.get_name() == "Android"
    var cores := OS.get_processor_count()
    var mem_gb := 8.0
    var info := OS.get_memory_info()
    if info.has("physical") and int(info.physical) > 0:
        mem_gb = float(info.physical) / 1073741824.0
    var adapter := RenderingServer.get_video_adapter_name().to_lower()
    if not mobile:
        detected_tier = 2
    else:
        var t := 1
        if cores >= 8 and mem_gb >= 5.5:
            t = 2
        if cores <= 4 or mem_gb < 3.0:
            t = 0
        # Older GPU families get the light preset regardless of core count.
        for weak in ["mali-t", "mali-g31", "mali-g51", "mali-g52", "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "powervr ge", "powervr rogue ge"]:
            if adapter.find(weak) >= 0:
                t = 0
        detected_tier = t
    _resolve_tier()

func _resolve_tier() -> void:
    match quality_mode:
        "low": tier = 0
        "medium": tier = 1
        "high": tier = 2
        _: tier = detected_tier
    render_scale = [0.7, 0.85, 1.0][tier]
    _adapt_enabled = quality_mode == "auto"
    _settle = 3.0

func set_quality(mode: String) -> void:
    quality_mode = mode
    _resolve_tier()
    apply()
    save()

func apply() -> void:
    var vp := get_viewport()
    if vp:
        vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
        vp.scaling_3d_scale = render_scale
        vp.msaa_3d = Viewport.MSAA_4X if tier == 2 else (Viewport.MSAA_2X if tier == 1 else Viewport.MSAA_DISABLED)
    Engine.max_fps = 60
    changed.emit()

func tier_label() -> String:
    if quality_mode == "auto":
        return "Auto (%s)" % TIER_NAMES[tier]
    return TIER_NAMES[tier]

func shadows_enabled() -> bool:
    return tier >= 1

func shadow_distance() -> float:
    return 70.0 if tier == 2 else 40.0

func view_distance() -> float:
    return [140.0, 220.0, 320.0][tier]

func traffic_scale() -> float:
    return [0.6, 0.85, 1.0][tier]

func detail_props() -> bool:
    return tier >= 1

func _apply_ui_scale() -> void:
    # Keep touch controls a comfortable physical size: phones get the full
    # canvas scale, big tablets are scaled down slightly so controls are not huge.
    var root := get_tree().root
    var screen := DisplayServer.screen_get_size()
    var dpi := maxf(float(DisplayServer.screen_get_dpi()), 96.0)
    var diag_in := sqrt(float(screen.x * screen.x + screen.y * screen.y)) / dpi
    var factor := 1.0
    if OS.has_feature("mobile"):
        if diag_in > 9.0:
            factor = 0.8
        elif diag_in > 7.0:
            factor = 0.9
    root.content_scale_factor = factor

func _process(delta: float) -> void:
    if not _adapt_enabled:
        return
    if _settle > 0.0:
        _settle -= delta
        return
    _fps_acc += delta
    _fps_frames += 1
    if _fps_acc < 2.5:
        return
    var fps := float(_fps_frames) / _fps_acc
    _fps_acc = 0.0
    _fps_frames = 0
    if fps < 27.0:
        if render_scale > 0.56:
            render_scale = maxf(0.55, render_scale - 0.1)
            apply()
        elif tier > 0:
            tier -= 1
            render_scale = 0.75
            apply()
        _settle = 1.5
    elif fps > 56.0 and render_scale < [0.8, 0.92, 1.0][tier]:
        render_scale = minf(1.0, render_scale + 0.05)
        apply()
        _settle = 1.5

func record_result(level_id: String, stars: int, time_s: float, score: int) -> bool:
    var prev: Dictionary = best.get(level_id, {})
    var improved := prev.is_empty() or score > int(prev.get("score", 0))
    if improved:
        best[level_id] = {"stars": maxi(stars, int(prev.get("stars", 0))), "time": time_s, "score": score}
        save()
    elif stars > int(prev.get("stars", 0)):
        prev.stars = stars
        best[level_id] = prev
        save()
    return improved

func stars_for(level_id: String) -> int:
    return int(best.get(level_id, {}).get("stars", 0))

func save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("settings", "quality_mode", quality_mode)
    cfg.set_value("settings", "control_mode", control_mode)
    cfg.set_value("settings", "stick_side", stick_side)
    cfg.set_value("settings", "sound_on", sound_on)
    cfg.set_value("settings", "show_fps", show_fps)
    cfg.set_value("settings", "camera_mode", camera_mode)
    cfg.set_value("settings", "car_index", car_index)
    cfg.set_value("settings", "paint_index", paint_index)
    cfg.set_value("progress", "best", best)
    cfg.save(SAVE_PATH)

func _load() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    quality_mode = str(cfg.get_value("settings", "quality_mode", quality_mode))
    control_mode = str(cfg.get_value("settings", "control_mode", control_mode))
    stick_side = str(cfg.get_value("settings", "stick_side", stick_side))
    sound_on = bool(cfg.get_value("settings", "sound_on", sound_on))
    show_fps = bool(cfg.get_value("settings", "show_fps", show_fps))
    camera_mode = int(cfg.get_value("settings", "camera_mode", camera_mode))
    car_index = int(cfg.get_value("settings", "car_index", car_index))
    paint_index = int(cfg.get_value("settings", "paint_index", paint_index))
    var b = cfg.get_value("progress", "best", {})
    if b is Dictionary:
        best = b
