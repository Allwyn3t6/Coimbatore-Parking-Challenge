extends CharacterBody3D
class_name PlayerCar

signal crash

var spec: Dictionary = {}
var throttle := 0.0
var steering := 0.0
var speed := 0.0
var collision_cooldown := 0.0
var wheel_nodes: Array[MeshInstance3D] = []
var gravity := 18.0

func configure(car_spec: Dictionary) -> void:
    spec = car_spec
    _build_car()

func _ready() -> void:
    if spec.is_empty():
        configure(VehicleCatalog.get_car(0))

func _build_car() -> void:
    for child in get_children():
        child.queue_free()
    wheel_nodes.clear()
    var length: float = float(spec.get("length", 4.0)) * 0.72
    var width: float = float(spec.get("width", 1.75)) * 0.72
    var paint := StandardMaterial3D.new()
    paint.albedo_color = spec.get("color", Color("#d7e0e7"))
    paint.metallic = 0.28
    paint.roughness = 0.3
    _mesh_box("Lower body", Vector3(width, 0.58, length), Vector3(0, 0.57, 0), paint)
    _mesh_box("Front bumper", Vector3(width * 1.02, 0.16, 0.18), Vector3(0, 0.34, -length * 0.48), _material(Color("#20272d")))
    _mesh_box("Rear bumper", Vector3(width * 1.02, 0.16, 0.18), Vector3(0, 0.34, length * 0.48), _material(Color("#20272d")))

    var glass := _material(Color("#263d50"), 0.15, 0.2)
    _mesh_box("Cabin", Vector3(width * 0.82, 0.48, length * 0.48), Vector3(0, 1.02, -0.04), glass)
    _mesh_box("Roof", Vector3(width * 0.76, 0.09, length * 0.34), Vector3(0, 1.29, -0.02), paint)
    var lamp := _material(Color("#fff0c2"), 0.0, 0.2)
    for x in [-width * 0.31, width * 0.31]:
        _mesh_box("Headlamp", Vector3(0.2, 0.12, 0.06), Vector3(x, 0.62, -length * 0.505), lamp)
        _mesh_box("Tail lamp", Vector3(0.2, 0.12, 0.06), Vector3(x, 0.62, length * 0.505), _material(Color("#d64b43")))

    for z in [-length * 0.34, length * 0.34]:
        for x in [-width * 0.53, width * 0.53]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := CylinderMesh.new()
            wheel_mesh.top_radius = 0.24
            wheel_mesh.bottom_radius = 0.24
            wheel_mesh.height = 0.17
            wheel.mesh = wheel_mesh
            wheel.rotation.z = PI / 2.0
            wheel.position = Vector3(x, 0.28, z)
            wheel.material_override = _material(Color("#171b20"))
            add_child(wheel)
            wheel_nodes.append(wheel)

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(width, 1.0, length)
    collider.shape = shape
    collider.position.y = 0.55
    add_child(collider)

func _mesh_box(label: String, size: Vector3, pos: Vector3, material: Material) -> void:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    mesh_node.material_override = material
    add_child(mesh_node)

func _material(color: Color, metallic := 0.0, roughness := 0.75) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    return material

func _physics_process(delta: float) -> void:
    collision_cooldown = maxf(0.0, collision_cooldown - delta)
    var max_speed: float = float(spec.get("speed", 8.0))
    var reverse_speed := max_speed * 0.38
    if throttle > 0.0:
        speed = move_toward(speed, max_speed, 4.8 * delta)
    elif throttle < 0.0:
        speed = move_toward(speed, -reverse_speed, 6.5 * delta)
    else:
        speed = move_toward(speed, 0.0, 2.3 * delta)

    var steering_factor := clampf(absf(speed) / 2.5, 0.12, 1.0)
    var turn_rate: float = float(spec.get("turn", 2.2))
    rotate_y(-steering * turn_rate * steering_factor * delta * signf(speed if absf(speed) > 0.05 else 1.0))
    var forward := -global_transform.basis.z
    velocity.x = forward.x * speed
    velocity.z = forward.z * speed
    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= gravity * delta
    move_and_slide()

    for wheel in wheel_nodes:
        wheel.rotate_object_local(Vector3.RIGHT, speed * delta / 0.24)

    if get_slide_collision_count() > 0 and collision_cooldown <= 0.0:
        collision_cooldown = 0.9
        crash.emit()
        speed *= -0.12
