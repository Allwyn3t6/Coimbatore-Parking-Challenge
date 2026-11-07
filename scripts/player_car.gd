extends CharacterBody3D
class_name PlayerCar

signal crash

var spec: Dictionary = {}
var throttle := 0.0
var steering := 0.0
var speed := 0.0
var collision_cooldown := 0.0

func configure(car_spec: Dictionary) -> void:
    spec = car_spec
    _build_car()

func _ready() -> void:
    if spec.is_empty():
        configure(VehicleCatalog.get_car(0))

func _build_car() -> void:
    for child in get_children():
        child.queue_free()
    var length: float = spec.get("length", 4.0) * 0.72
    var width: float = spec.get("width", 1.75) * 0.72
    var body := BoxMesh.new()
    body.size = Vector3(width, 0.62, length)
    var body_node := MeshInstance3D.new()
    body_node.mesh = body
    body_node.position.y = 0.55
    var paint := StandardMaterial3D.new()
    paint.albedo_color = spec.get("color", Color("#d7e0e7"))
    paint.metallic = 0.35
    paint.roughness = 0.28
    body_node.material_override = paint
    add_child(body_node)

    var cabin := BoxMesh.new()
    cabin.size = Vector3(width * 0.82, 0.48, length * 0.48)
    var cabin_node := MeshInstance3D.new()
    cabin_node.mesh = cabin
    cabin_node.position = Vector3(0, 1.04, -0.05)
    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color("#263d50")
    glass.metallic = 0.2
    glass.roughness = 0.18
    cabin_node.material_override = glass
    add_child(cabin_node)

    for z in [-length * 0.34, length * 0.34]:
        for x in [-width * 0.52, width * 0.52]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := CylinderMesh.new()
            wheel_mesh.top_radius = 0.24
            wheel_mesh.bottom_radius = 0.24
            wheel_mesh.height = 0.16
            wheel.mesh = wheel_mesh
            wheel.rotation.z = PI / 2.0
            wheel.position = Vector3(x, 0.28, z)
            var rubber := StandardMaterial3D.new()
            rubber.albedo_color = Color("#171b20")
            wheel.material_override = rubber
            add_child(wheel)

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(width, 1.0, length)
    collider.shape = shape
    collider.position.y = 0.55
    add_child(collider)

func _physics_process(delta: float) -> void:
    collision_cooldown = maxf(0.0, collision_cooldown - delta)
    var max_speed: float = spec.get("speed", 8.0)
    if throttle > 0.0:
        speed = move_toward(speed, max_speed, 5.0 * delta)
    elif throttle < 0.0:
        speed = move_toward(speed, -max_speed * 0.42, 7.0 * delta)
    else:
        speed = move_toward(speed, 0.0, 2.7 * delta)
    var steering_factor := clampf(absf(speed) / 3.0, 0.18, 1.0)
    var turn_rate: float = spec.get("turn", 2.2)
    rotate_y(-steering * turn_rate * steering_factor * delta * signf(speed if absf(speed) > 0.05 else 1.0))
    var forward := -global_transform.basis.z
    velocity.x = forward.x * speed
    velocity.z = forward.z * speed
    velocity.y = -9.8
    move_and_slide()
    if get_slide_collision_count() > 0 and collision_cooldown <= 0.0:
        collision_cooldown = 0.8
        crash.emit()
        speed *= -0.18
