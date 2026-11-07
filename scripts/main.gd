extends Node3D

const CAR_SCRIPT = preload("res://scripts/player_car.gd")
const CATALOG = preload("res://scripts/vehicle_catalog.gd")

const MISSIONS := [
    {"name":"GANDHIPURAM MARKET", "bay_x":0.0, "bay_z":-13.0, "description":"Thread the market traffic and reverse into the bay."},
    {"name":"RS PURAM BOULEVARD", "bay_x":-3.0, "bay_z":-13.0, "description":"A tight kerbside space on a busy shopping street."},
    {"name":"RACE COURSE AVENUE", "bay_x":3.0, "bay_z":-13.0, "description":"Park neatly beside the avenue footpath."}
]

var car: PlayerCar
var selected_car := 0
var selected_mission := 0
var score := 0
var crashes := 0
var elapsed := 0.0
var status_label: Label
var score_label: Label
var speed_label: Label
var mission_label: Label
var camera_rig: Camera3D
var bay_root: Node3D
var touch_inputs := {"accelerate": false, "brake": false, "left": false, "right": false}
var parking_center := Vector3(0, 0, -13.0)
var parking_size := Vector2(3.2, 6.0)
var finished := false
var paused := false

func _ready() -> void:
    _build_world()
    _build_parking_bay()
    _spawn_car()
    _build_hud()

func _process(delta: float) -> void:
    if paused:
        return
    elapsed += delta
    if is_instance_valid(car):
        car.throttle = float(touch_inputs.accelerate) - float(touch_inputs.brake)
        car.steering = float(touch_inputs.right) - float(touch_inputs.left)
        if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): car.throttle = 1.0
        if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): car.throttle = -1.0
        if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): car.steering = -1.0
        if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): car.steering = 1.0
        speed_label.text = "SPEED  %03d km/h" % int(absf(car.speed) * 5.0)
        _check_parking()
        _update_camera(delta)
    score_label.text = "SCORE  %05d     HITS  %d     TIME  %04.1fs" % [score, crashes, elapsed]

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#9dc6d1")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#d8e6eb")
    environment.ambient_light_energy = 0.8
    env.environment = environment
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.35
    add_child(sun)

    _box("Asphalt street", Vector3(0, -0.18, -4), Vector3(13, 0.3, 46), Color("#343b42"), true)
    _box("Left footpath", Vector3(-7.5, 0.0, -4), Vector3(2.0, 0.4, 46), Color("#b9b2a4"), true)
    _box("Right footpath", Vector3(7.5, 0.0, -4), Vector3(2.0, 0.4, 46), Color("#b9b2a4"), true)
    for z in range(-25, 20, 5):
        _box("Road dash", Vector3(0, 0.0, z), Vector3(0.14, 0.025, 2.2), Color("#e9e5d5"), false)
    for side in [-1, 1]:
        for i in range(6):
            var z := -22.0 + float(i) * 8.5
            var x := float(side) * 10.0
            var h := 3.0 + float((i + 2) % 3) * 1.2
            var palette := [Color("#d7a66c"), Color("#c7c1a5"), Color("#a9b9a0"), Color("#b77c70")]
            _box("Coimbatore shop block", Vector3(x, h * 0.5, z), Vector3(4.0, h, 6.5), palette[i % palette.size()], true)
            _shop_sign(Vector3(x - float(side) * 1.95, 1.8, z), ["TEXTILES", "COFFEE", "BAKERY", "MOBILE", "PHARMACY", "ELECTRICALS"][i])

    _parked_car(Vector3(-4.7, 0, -5.0), Color("#647f9d"))
    _parked_car(Vector3(4.6, 0, 4.0), Color("#b55f4d"))
    _parked_car(Vector3(-4.6, 0, 9.0), Color("#d1bd69"))
    _parked_car(Vector3(4.7, 0, -21.0), Color("#5b8c77"))
    _box("Traffic bollard", Vector3(5.9, 0.55, -13), Vector3(0.45, 1.1, 0.45), Color("#e2a23c"), true)

    camera_rig = Camera3D.new()
    camera_rig.position = Vector3(0, 12, 14)
    camera_rig.rotation_degrees = Vector3(-38, 0, 0)
    camera_rig.current = true
    add_child(camera_rig)

func _build_parking_bay() -> void:
    if is_instance_valid(bay_root):
        bay_root.queue_free()
    bay_root = Node3D.new()
    bay_root.name = "ActiveParkingBay"
    add_child(bay_root)
    var mission: Dictionary = MISSIONS[selected_mission]
    parking_center = Vector3(mission.bay_x, 0, mission.bay_z)
    _box_in(bay_root, "Bay floor", parking_center + Vector3(0, -0.015, 0), Vector3(parking_size.x, 0.03, parking_size.y), Color("#687c6a"), false)
    _box_in(bay_root, "Bay left line", parking_center + Vector3(-parking_size.x / 2, 0.03, 0), Vector3(0.12, 0.05, parking_size.y), Color("#f5e9bf"), false)
    _box_in(bay_root, "Bay right line", parking_center + Vector3(parking_size.x / 2, 0.03, 0), Vector3(0.12, 0.05, parking_size.y), Color("#f5e9bf"), false)
    _box_in(bay_root, "Bay back line", parking_center + Vector3(0, 0.03, -parking_size.y / 2), Vector3(parking_size.x, 0.05, 0.12), Color("#f5e9bf"), false)
    _box_in(bay_root, "Bay front line", parking_center + Vector3(0, 0.03, parking_size.y / 2), Vector3(parking_size.x, 0.05, 0.12), Color("#f5e9bf"), false)

func _box(label: String, pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
    _box_in(self, label, pos, size, color, solid)

func _box_in(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    mesh_node.material_override = mat
    parent.add_child(mesh_node)
    if solid:
        var body := StaticBody3D.new()
        body.position = pos
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
        parent.add_child(body)

func _shop_sign(pos: Vector3, _text_value: String) -> void:
    var sign_mesh := MeshInstance3D.new()
    var plane := BoxMesh.new()
    plane.size = Vector3(0.12, 0.55, 2.3)
    sign_mesh.mesh = plane
    sign_mesh.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#294d55")
    sign_mesh.material_override = mat
    add_child(sign_mesh)

func _parked_car(pos: Vector3, color: Color) -> void:
    _box("Parked vehicle", pos + Vector3(0, 0.55, 0), Vector3(1.55, 0.65, 3.1), color, true)
    _box("Parked vehicle cabin", pos + Vector3(0, 1.05, 0), Vector3(1.3, 0.42, 1.55), Color("#283d4b"), false)

func _spawn_car() -> void:
    if is_instance_valid(car):
        car.queue_free()
    car = CAR_SCRIPT.new()
    car.configure(CATALOG.get_car(selected_car))
    car.position = Vector3(0, 0, 10)
    car.crash.connect(_on_crash)
    add_child(car)
    finished = false
    paused = false
    touch_inputs = {"accelerate": false, "brake": false, "left": false, "right": false}

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 14)
    panel.custom_minimum_size = Vector2(390, 132)
    layer.add_child(panel)
    var stack := VBoxContainer.new()
    panel.add_child(stack)
    var title := Label.new()
    title.text = "COIMBATORE PARKING CHALLENGE"
    title.add_theme_font_size_override("font_size", 20)
    stack.add_child(title)
    mission_label = Label.new()
    mission_label.text = MISSIONS[selected_mission].name
    mission_label.add_theme_color_override("font_color", Color("#e7b65c"))
    stack.add_child(mission_label)
    score_label = Label.new()
    stack.add_child(score_label)
    speed_label = Label.new()
    stack.add_child(speed_label)

    var car_picker := OptionButton.new()
    car_picker.position = Vector2(18, 158)
    car_picker.custom_minimum_size = Vector2(300, 46)
    for item in CATALOG.CARS:
        car_picker.add_item(item.name)
    car_picker.select(selected_car)
    car_picker.item_selected.connect(_on_car_selected)
    layer.add_child(car_picker)

    var mission_picker := OptionButton.new()
    mission_picker.position = Vector2(18, 210)
    mission_picker.custom_minimum_size = Vector2(300, 46)
    for mission in MISSIONS:
        mission_picker.add_item(mission.name)
    mission_picker.select(selected_mission)
    mission_picker.item_selected.connect(_on_mission_selected)
    layer.add_child(mission_picker)

    status_label = Label.new()
    status_label.text = "MISSION: " + MISSIONS[selected_mission].description
    status_label.position = Vector2(420, 22)
    status_label.size = Vector2(600, 50)
    status_label.add_theme_font_size_override("font_size", 20)
    status_label.add_theme_color_override("font_color", Color("#ffffff"))
    layer.add_child(status_label)

    _add_touch_button(layer, "◀", Vector2(28, -112), "left", Vector2(86, 76))
    _add_touch_button(layer, "▶", Vector2(220, -112), "right", Vector2(86, 76))
    _add_touch_button(layer, "REVERSE", Vector2(-220, -112), "brake", Vector2(104, 76))
    _add_touch_button(layer, "ACCEL", Vector2(-108, -112), "accelerate", Vector2(100, 76))

    var reset_button := Button.new()
    reset_button.text = "RESTART"
    reset_button.position = Vector2(18, 270)
    reset_button.custom_minimum_size = Vector2(140, 44)
    reset_button.pressed.connect(_reset_mission)
    layer.add_child(reset_button)

    var pause_button := Button.new()
    pause_button.text = "PAUSE"
    pause_button.position = Vector2(166, 270)
    pause_button.custom_minimum_size = Vector2(140, 44)
    pause_button.pressed.connect(_toggle_pause)
    layer.add_child(pause_button)

    var hint := Label.new()
    hint.text = "TOUCH: steer + pedals     KEYBOARD: WASD / ARROWS     R: restart"
    hint.position = Vector2(20, 680)
    hint.add_theme_color_override("font_color", Color("#ffffff"))
    layer.add_child(hint)

func _add_touch_button(layer: CanvasLayer, caption: String, offset: Vector2, action: String, size: Vector2) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = size
    button.anchor_left = 1.0 if offset.x < 0 else 0.0
    button.anchor_right = 1.0 if offset.x < 0 else 0.0
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.position = offset
    button.add_theme_font_size_override("font_size", 20)
    button.button_down.connect(func(): touch_inputs[action] = true)
    button.button_up.connect(func(): touch_inputs[action] = false)
    layer.add_child(button)

func _update_camera(delta: float) -> void:
    var target := car.global_position + Vector3(0, 11.5, 13.0)
    camera_rig.global_position = camera_rig.global_position.lerp(target, clampf(delta * 3.2, 0.0, 1.0))
    camera_rig.look_at(car.global_position + Vector3(0, 0.4, 0), Vector3.UP)

func _on_car_selected(index: int) -> void:
    selected_car = index
    _spawn_car()
    status_label.text = "Selected vehicle: " + CATALOG.get_car(index).name

func _on_mission_selected(index: int) -> void:
    selected_mission = index
    _build_parking_bay()
    _reset_mission()
    mission_label.text = MISSIONS[index].name
    status_label.text = MISSIONS[index].description

func _on_crash() -> void:
    crashes += 1
    score = maxi(0, score - 100)
    status_label.text = "COLLISION! -100 points. Slow down near obstacles."

func _reset_mission() -> void:
    elapsed = 0.0
    finished = false
    paused = false
    _spawn_car()
    status_label.text = MISSIONS[selected_mission].description
    status_label.add_theme_color_override("font_color", Color("#ffffff"))

func _toggle_pause() -> void:
    paused = not paused
    if is_instance_valid(car):
        car.throttle = 0.0
        car.speed = 0.0
        car.set_physics_process(not paused)
    status_label.text = "PAUSED — tap PAUSE to resume" if paused else MISSIONS[selected_mission].description

func _check_parking() -> void:
    if finished or not is_instance_valid(car):
        return
    var local_pos: Vector3 = car.global_position
    var inside := absf(local_pos.x - parking_center.x) < 1.05 and absf(local_pos.z - parking_center.z) < 2.25
    var aligned := absf(wrapf(car.rotation.y, -PI, PI)) < 0.22
    if inside and aligned and absf(car.speed) < 0.35:
        finished = true
        var bonus := maxi(0, 1200 - crashes * 100 - int(elapsed * 4.0))
        score += bonus
        car.speed = 0
        status_label.text = "PERFECT PARKING! +%d points — choose another street." % bonus
        status_label.add_theme_color_override("font_color", Color("#8df0a9"))
    elif inside and absf(car.speed) < 0.45 and not aligned:
        status_label.text = "Straighten the car inside the marked bay."

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            _reset_mission()
        elif event.keycode == KEY_ESCAPE:
            _toggle_pause()
