extends CharacterBody3D
class_name PlayerCar
## Kinematic bicycle-model car: the rear axle follows the heading and the car
## pivots around it, so it tracks like a real car when parking.

signal crash(kind: String, impact: float)

var spec: Dictionary = {}
var paint_override: Variant = null

# Inputs (set every frame by main)
var throttle := 0.0        # -1..1 (stick mode: up = forward, down = brake then reverse)
var steer_input := 0.0     # -1 (left) .. 1 (right)
var brake_input := 0.0     # 0..1 dedicated brake
var pedal_mode := false
var gear := 1              # pedal mode: 1 = D, -1 = R
var frozen := false

var speed := 0.0           # signed m/s, + forward
var steer_angle := 0.0
var accel_now := 0.0
var is_braking := false
var reversing := false
var length := 4.0
var width := 1.75
var wheelbase := 2.5
var front_dist := 99.0
var rear_dist := 99.0
var bump_time := 0.0

var _cooldown := 0.0
var _body: Node3D
var _front_pivots: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _wheel_r := 0.31
var _brake_mat: StandardMaterial3D
var _reverse_mat: StandardMaterial3D
var _front_rays: Array[RayCast3D] = []
var _rear_rays: Array[RayCast3D] = []
var _blob: MeshInstance3D

func configure(car_spec: Dictionary, paint: Variant = null) -> void:
    spec = car_spec.duplicate()
    if paint != null:
        spec.color = paint
    _build()

func _ready() -> void:
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    wall_min_slide_angle = 0.0
    if spec.is_empty():
        configure(VehicleCatalog.get_car(0))

func _build() -> void:
    for child in get_children():
        child.queue_free()
    _front_pivots.clear()
    _spinners.clear()
    _front_rays.clear()
    _rear_rays.clear()
    length = float(spec.get("length", 4.0))
    width = float(spec.get("width", 1.75))
    wheelbase = length * 0.62
    var shape: Dictionary = VehicleFactory.SHAPES.get(str(spec.get("shape", "hatch")), VehicleFactory.SHAPES.hatch)
    _wheel_r = shape.wheel

    _body = Node3D.new()
    _body.name = "Body"
    add_child(_body)
    var b := MeshBatcher.new()
    VehicleFactory.car(b, Transform3D.IDENTITY, spec, false, false)
    b.commit(_body, "BodyMesh", true)

    var c: float = shape.clear
    var bh: float = shape.body_h
    var lamp_y := c + bh * 0.72
    var tail_b := MeshBatcher.new()
    var head_b := MeshBatcher.new()
    _brake_mat = StandardMaterial3D.new()
    _brake_mat.albedo_color = Color("#9e1b14")
    _brake_mat.emission_enabled = true
    _brake_mat.emission = Color("#ff2a1a")
    _brake_mat.emission_energy_multiplier = 0.2
    _reverse_mat = StandardMaterial3D.new()
    _reverse_mat.albedo_color = Color("#cfcfcf")
    _reverse_mat.emission_enabled = true
    _reverse_mat.emission = Color.WHITE
    _reverse_mat.emission_energy_multiplier = 0.0
    for sx in [-1.0, 1.0]:
        head_b.box(Vector3(sx * width * 0.33, lamp_y, -length * 0.5 - 0.005), Vector3(width * 0.22, 0.12, 0.04), Mats.glow(Color("#fff6de"), 1.2))
        tail_b.box(Vector3(sx * width * 0.36, lamp_y, length * 0.5 + 0.006), Vector3(width * 0.2, 0.12, 0.04), _brake_mat)
        tail_b.box(Vector3(sx * width * 0.2, lamp_y - 0.1, length * 0.5 + 0.006), Vector3(0.12, 0.07, 0.04), _reverse_mat)
    head_b.commit(_body, "HeadLamps", false)
    tail_b.commit(_body, "TailLamps", false)

    var wz := length * 0.5 - maxf(0.72, length * 0.18)
    wheelbase = wz * 2.0
    for sz in [-1.0, 1.0]:
        for sx in [-1.0, 1.0]:
            var pivot := Node3D.new()
            pivot.position = Vector3(sx * (width * 0.5 - 0.1), _wheel_r, sz * wz)
            add_child(pivot)
            var spinner := Node3D.new()
            pivot.add_child(spinner)
            var wb := MeshBatcher.new()
            wb.cylinder_basis(Vector3.ZERO, _wheel_r, 0.22, Basis(Vector3.BACK, PI * 0.5), Mats.plain(Color("#15181b"), 0.9), 12)
            wb.cylinder_basis(Vector3(sx * 0.115, 0, 0), _wheel_r * 0.58, 0.02, Basis(Vector3.BACK, PI * 0.5), Mats.plain(Color("#a7b0b7"), 0.35, 0.7), 6)
            wb.commit(spinner, "Wheel", true)
            _spinners.append(spinner)
            if sz < 0:
                _front_pivots.append(pivot)

    var collider := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(width, 1.2, length)
    collider.shape = box
    collider.position.y = 0.7
    add_child(collider)

    # Parking sensors: three rays at each bumper.
    for side in [-1.0, 1.0]:
        for lx in [-0.36, 0.0, 0.36]:
            var ray := RayCast3D.new()
            ray.position = Vector3(lx * width, 0.55, side * (length * 0.5 + 0.05))
            ray.target_position = Vector3(lx * 0.8, 0, side * 2.6)
            ray.add_exception(self)
            ray.enabled = true
            add_child(ray)
            if side < 0:
                _front_rays.append(ray)
            else:
                _rear_rays.append(ray)

    _blob = MeshInstance3D.new()
    var q := QuadMesh.new()
    q.size = Vector2(width + 0.5, length + 0.6)
    _blob.mesh = q
    _blob.rotation.x = -PI * 0.5
    _blob.position.y = 0.03
    _blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var sm := StandardMaterial3D.new()
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sm.albedo_color = Color(0, 0, 0, 0.35)
    _blob.material_override = sm
    add_child(_blob)

func set_blob_shadow(on: bool) -> void:
    if _blob:
        _blob.visible = on

func forward() -> Vector3:
    return -global_transform.basis.z

func _physics_process(delta: float) -> void:
    _cooldown = maxf(0.0, _cooldown - delta)
    var max_fwd: float = float(spec.get("speed", 10.0))
    var max_rev := 4.2
    var accel: float = float(spec.get("accel", 3.4))
    var brake_decel := 9.0
    var drive := 0.0
    var brake := brake_input
    if frozen:
        brake = 1.0
    elif pedal_mode:
        var gas := maxf(throttle, 0.0)
        if gas > 0.0:
            if signf(speed) == -float(gear) and absf(speed) > 0.25:
                brake = maxf(brake, gas)
            else:
                drive = gas * float(gear)
    else:
        if throttle > 0.0:
            if speed < -0.25:
                brake = maxf(brake, throttle)
            else:
                drive = throttle
        elif throttle < 0.0:
            if speed > 0.25:
                brake = maxf(brake, -throttle)
            else:
                drive = throttle

    var prev := speed
    if brake > 0.02:
        speed = move_toward(speed, 0.0, brake_decel * brake * delta)
    if absf(drive) > 0.0 and brake <= 0.02:
        var limit := max_fwd if drive > 0.0 else max_rev
        var a := accel * absf(drive) * (1.0 - clampf(absf(speed) / limit, 0.0, 1.0) * 0.6)
        speed += signf(drive) * a * delta
        if drive > 0.0:
            speed = minf(speed, max_fwd)
        else:
            speed = maxf(speed, -max_rev)
    elif brake <= 0.02:
        speed = move_toward(speed, 0.0, (0.9 + 0.015 * speed * speed) * delta)
    accel_now = (speed - prev) / maxf(delta, 0.0001)
    is_braking = (brake > 0.05 and absf(speed) > 0.05) or frozen
    reversing = speed < -0.05 or drive < 0.0 or (pedal_mode and gear < 0)

    var max_steer := deg_to_rad(float(spec.get("turn", 36.0)))
    var speed_factor := 1.0 - clampf((absf(speed) - 4.0) / 10.0, 0.0, 0.55)
    var target := steer_input * max_steer * speed_factor
    steer_angle = move_toward(steer_angle, target, 2.2 * delta)

    # Bicycle model around the rear axle.
    var fwd := forward()
    var yaw_rate := speed * tan(steer_angle) / wheelbase
    var rear := global_position - fwd * (wheelbase * 0.5)
    rear += fwd * speed * delta
    var new_yaw := rotation.y - yaw_rate * delta
    var new_fwd := Vector3(-sin(new_yaw), 0, -cos(new_yaw))
    var target_pos := rear + new_fwd * (wheelbase * 0.5)
    rotation.y = new_yaw
    var pre_velocity := (target_pos - global_position) / maxf(delta, 0.0001)
    pre_velocity.y = 0.0
    velocity = pre_velocity
    move_and_slide()
    global_position.y = 0.0

    if get_slide_collision_count() > 0:
        var hit := get_slide_collision(0)
        var n := hit.get_normal()
        var impact := absf(pre_velocity.dot(n))
        var real := get_real_velocity()
        var along := real.dot(new_fwd)
        if signf(along) != signf(speed) or absf(along) < 0.05:
            speed = -speed * 0.15 if impact > 1.5 else 0.0
        else:
            speed = signf(speed) * minf(absf(speed), absf(along))
        if impact > 0.45 and _cooldown <= 0.0:
            _cooldown = 0.8
            var kind := "object"
            var col := hit.get_collider()
            if col is Node:
                if (col as Node).is_in_group("kerb"):
                    kind = "kerb"
                elif (col as Node).is_in_group("vehicle"):
                    kind = "vehicle"
            crash.emit(kind, impact)

    for p in _front_pivots:
        p.rotation.y = -steer_angle
    for s in _spinners:
        s.rotate_object_local(Vector3.RIGHT, -speed * delta / _wheel_r)

    front_dist = _nearest(_front_rays)
    rear_dist = _nearest(_rear_rays)

    _brake_mat.emission_energy_multiplier = 3.2 if is_braking else 0.25
    _reverse_mat.emission_energy_multiplier = 2.5 if speed < -0.05 else 0.0
    bump_time = maxf(0.0, bump_time - delta)
    var pitch := clampf(accel_now * 0.004, -0.035, 0.035)
    _body.rotation.x = lerpf(_body.rotation.x, pitch, clampf(delta * 6.0, 0.0, 1.0))
    _body.rotation.z = lerpf(_body.rotation.z, clampf(-yaw_rate * absf(speed) * 0.004, -0.03, 0.03), clampf(delta * 5.0, 0.0, 1.0))
    _body.position.y = sin(bump_time * 18.0) * 0.06 * bump_time

func _nearest(rays: Array[RayCast3D]) -> float:
    var d := 99.0
    for r in rays:
        if r.is_colliding():
            d = minf(d, r.global_position.distance_to(r.get_collision_point()))
    return d

func corners() -> Array[Vector3]:
    var xf := global_transform
    var hx := width * 0.5
    var hz := length * 0.5
    return [xf * Vector3(-hx, 0, -hz), xf * Vector3(hx, 0, -hz), xf * Vector3(hx, 0, hz), xf * Vector3(-hx, 0, hz)]

func place(pos: Vector3, yaw: float) -> void:
    global_position = Vector3(pos.x, 0, pos.z)
    rotation = Vector3(0, yaw, 0)
    speed = 0.0
    steer_angle = 0.0
    velocity = Vector3.ZERO
