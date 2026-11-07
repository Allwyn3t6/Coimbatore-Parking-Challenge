extends Node3D

const CAR_SCRIPT = preload("res://scripts/player_car.gd")
const CATALOG = preload("res://scripts/vehicle_catalog.gd")

var car: PlayerCar
var selected_car := 0
var score := 0
var crashes := 0
var elapsed := 0.0
var status_label: Label
var score_label: Label
var speed_label: Label
var touch_inputs := {"accelerate": false, "brake": false, "left": false, "right": false}
var parking_center := Vector3(0, 0, -13.0)
var parking_size := Vector2(3.2, 6.0)
var finished := false

func _ready() -> void:
    _build_world()
    _spawn_car()
    _build_hud()

func _process(delta: float) -> void:
    elapsed += delta
    if car:
        car.throttle = float(touch_inputs.accelerate) - float(touch_inputs.brake)
        car.steering = float(touch_inputs.right) - float(touch_inputs.left)
        if Input.is_action_pressed("ui_up"): car.throttle = 1.0
        if Input.is_action_pressed("ui_down"): car.throttle = -1.0
        if Input.is_action_pressed("ui_left"): car.steering = -1.0
        if Input.is_action_pressed("ui_right"): car.steering = 1.0
        speed_label.text = "SPEED  %03d km/h" % int(absf(car.speed) * 5.0)
        _check_parking()
    score_label.text = "SCORE  %05d     HITS  %d" % [score, crashes]

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

    _box("Asphalt street", Vector3(0, -0.18, -4), Vector3(13, 0.3, 42), Color("#343b42"), false)
    _box("Left footpath", Vector3(-7.5, 0.0, -4), Vector3(2.0, 0.4, 42), Color("#b9b2a4"), false)
    _box("Right footpath", Vector3(7.5, 0.0, -4), Vector3(2.0, 0.4, 42), Color("#b9b2a4"), false)
    for z in range(-23, 17, 5):
        _box("Road dash", Vector3(0, 0.0, z), Vector3(0.14, 0.025, 2.2), Color("#e9e5d5"), false)
    for side in [-1, 1]:
        for i in range(5):
            var z := -20.0 + float(i) * 9.0
            var x := float(side) * 10.0
            var h := 3.0 + float((i + 2) % 3) * 1.2
            _box("Coimbatore shop block", Vector3(x, h * 0.5, z), Vector3(4.0, h, 6.5), [Color("#d7a66c"), Color("#c7c1a5"), Color("#a9b9a0")][i % 3], true)
            _shop_sign(Vector3(x - float(side) * 1.95, 1.8, z), ["TEXTILE", "COFFEE", "BAKERY", "MOBILE", "PHARMACY"][i])

    _box("Parking bay floor", parking_center + Vector3(0, -0.015, 0), Vector3(parking_size.x, 0.03, parking_size.y), Color("#687c6a"), false)
    _box("Bay left line", parking_center + Vector3(-parking_size.x / 2, 0.03, 0), Vector3(0.12, 0.05, parking_size.y), Color("#f5e9bf"), false)
    _box("Bay right line", parking_center + Vector3(parking_size.x / 2, 0.03, 0), Vector3(0.12, 0.05, parking_size.y), Color("#f5e9bf"), false)
    _box("Bay back line", parking_center + Vector3(0, 0.03, -parking_size.y / 2), Vector3(parking_size.x, 0.05, 0.12), Color("#f5e9bf"), false)
    _box("Bay front line", parking_center + Vector3(0, 0.03, parking_size.y / 2), Vector3(parking_size.x, 0.05, 0.12), Color("#f5e9bf"), false)

    _parked_car(Vector3(-4.7, 0, -5.0), Color("#647f9d"))
    _parked_car(Vector3(4.6, 0, 4.0), Color("#b55f4d"))
    _parked_car(Vector3(-4.6, 0, 9.0), Color("#d1bd69"))
    _box("Traffic bollard", Vector3(5.9, 0.55, -13), Vector3(0.45, 1.1, 0.45), Color("#e2a23c"), true)

    var camera := Camera3D.new()
    camera.position = Vector3(0, 23, 19)
    camera.rotation_degrees = Vector3(-48, 0, 0)
    camera.current = true
    add_child(camera)

func _box(label: String, pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
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
    add_child(mesh_node)
    if solid:
        var body := StaticBody3D.new()
        body.position = pos
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
        add_child(body)

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
    if car:
        car.queue_free()
    car = CAR_SCRIPT.new()
    car.configure(CATALOG.get_car(selected_car))
    car.position = Vector3(0, 0, 10)
    car.crash.connect(_on_crash)
    add_child(car)
    finished = false

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 14)
    panel.custom_minimum_size = Vector2(360, 112)
    layer.add_child(panel)
    var stack := VBoxContainer.new()
    panel.add_child(stack)
    var title := Label.new()
    title.text = "COIMBATORE PARKING CHALLENGE"
    title.add_theme_font_size_override("font_size", 20)
    stack.add_child(title)
    var location := Label.new()
    location.text = "GANDHIPURAM • MARKET STREET"
    location.add_theme_color_override("font_color", Color("#e7b65c"))
    stack.add_child(location)
    score_label = Label.new()
    stack.add_child(score_label)
    speed_label = Label.new()
    stack.add_child(speed_label)

    var picker := OptionButton.new()
    picker.position = Vector2(18, 140)
    picker.custom_minimum_size = Vector2(310, 48)
    for item in CATALOG.CARS:
        picker.add_item(item.name)
    picker.select(selected_car)
    picker.item_selected.connect(_on_car_selected)
    layer.add_child(picker)

    status_label = Label.new()
    status_label.text = "MISSION: Reverse into the marked bay"
    status_label.position = Vector2(350, 24)
    status_label.add_theme_font_size_override("font_size", 22)
    status_label.add_theme_color_override("font_color", Color("#ffffff"))
    layer.add_child(status_label)

    _add_touch_button(layer, "◀", Vector2(28, -105), "left", Vector2(88, 76))
    _add_touch_button(layer, "▶", Vector2(222, -105), "right", Vector2(88, 76))
    _add_touch_button(layer, "BRAKE", Vector2(-215, -105), "brake", Vector2(100, 76))
    _add_touch_button(layer, "ACCEL", Vector2(-105, -105), "accelerate", Vector2(100, 76))
    var hint := Label.new()
    hint.text = "Touch controls • Keyboard: WASD / Arrow keys"
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
    button.add_theme_font_size_override("font_size", 22)
    button.button_down.connect(func(): touch_inputs[action] = true)
    button.button_up.connect(func(): touch_inputs[action] = false)
    layer.add_child(button)

func _on_car_selected(index: int) -> void:
    selected_car = index
    _spawn_car()
    status_label.text = "Selected: " + CATALOG.get_car(index).name

func _on_crash() -> void:
    crashes += 1
    score = maxi(0, score - 100)
    status_label.text = "BUMP! Collision penalty -100"

func _check_parking() -> void:
    if finished or not car:
        return
    var local_pos: Vector3 = car.global_position
    var inside := absf(local_pos.x - parking_center.x) < 1.1 and absf(local_pos.z - parking_center.z) < 2.2
    var aligned := absf(wrapf(car.rotation.y, -PI, PI)) < 0.22
    if inside and aligned and absf(car.speed) < 0.45:
        finished = true
        var bonus := maxi(0, 1000 - crashes * 100 - int(elapsed * 3.0))
        score += bonus
        car.speed = 0
        status_label.text = "PARKED! +%d points" % bonus
        status_label.add_theme_color_override("font_color", Color("#8df0a9"))
    elif inside and absf(car.speed) < 0.45 and not aligned:
        status_label.text = "Straighten the car inside the bay"
