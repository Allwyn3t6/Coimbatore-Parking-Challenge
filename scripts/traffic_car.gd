extends AnimatableBody3D
class_name TrafficCar
## Follows a lane polyline, keeps distance from vehicles ahead (including the
## player) and honks when the player blocks it.

signal honk(pos: Vector3)

var points := PackedVector3Array()
var cum := PackedFloat32Array()
var total := 1.0
var s := 0.0
var cruise := 8.0
var cur_speed := 0.0
var half_len := 2.0
var others: Array = []
var player: Node3D
var player_half := 2.0
var racer := false
var loop := false
var racing := false
var lap := 0
var lateral := 0.0
var base_speed := 9.0
var rubber := 1.0
var laps_to_finish := 999
var _blocked_for := 0.0
var _ghost := 0.0
var _honk_cd := 0.0

func setup(path: PackedVector3Array, start_s: float, kind: String, rng: RandomNumberGenerator, paint: Variant = null) -> void:
    points = path
    cum.resize(points.size())
    cum[0] = 0.0
    for i in range(1, points.size()):
        cum[i] = cum[i - 1] + points[i].distance_to(points[i - 1])
    total = maxf(cum[cum.size() - 1], 1.0)
    s = fposmod(start_s, total)
    add_to_group("vehicle")
    sync_to_physics = false
    var b := MeshBatcher.new()
    var size := Vector3(1.8, 1.6, 4.0)
    match kind:
        "auto":
            size = VehicleFactory.auto_rickshaw(b, Transform3D.IDENTITY, VehicleFactory.AUTO_COLOURS[rng.randi() % VehicleFactory.AUTO_COLOURS.size()])
            cruise = rng.randf_range(6.0, 8.0)
        "bus":
            size = VehicleFactory.bus(b, Transform3D.IDENTITY, VehicleFactory.BUS_COLOURS[rng.randi() % VehicleFactory.BUS_COLOURS.size()])
            cruise = rng.randf_range(6.5, 8.0)
        "lorry":
            size = VehicleFactory.lorry(b, Transform3D.IDENTITY, VehicleFactory.LORRY_COLOURS[rng.randi() % VehicleFactory.LORRY_COLOURS.size()])
            cruise = rng.randf_range(6.0, 7.5)
        "bike":
            size = VehicleFactory.two_wheeler(b, Transform3D.IDENTITY, VehicleFactory.CAR_COLOURS[rng.randi() % VehicleFactory.CAR_COLOURS.size()])
            cruise = rng.randf_range(8.0, 10.5)
        _:
            var shapes := ["sedan", "hatch", "suv", "micro", "mpv"]
            var spec := {"shape": shapes[rng.randi() % shapes.size()], "length": rng.randf_range(3.7, 4.5), "width": rng.randf_range(1.65, 1.85), "color": VehicleFactory.CAR_COLOURS[rng.randi() % VehicleFactory.CAR_COLOURS.size()]}
            if paint != null:
                spec.color = paint
            size = VehicleFactory.car(b, Transform3D.IDENTITY, spec)
            cruise = rng.randf_range(7.5, 10.0)
    b.commit(self, "Mesh", true)
    half_len = size.z * 0.5
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    cs.shape = shape
    cs.position.y = size.y * 0.5
    add_child(cs)
    cur_speed = cruise
    _apply_transform()

func _sample(at: float) -> Vector3:
    at = fposmod(at, total) if loop else clampf(at, 0.0, total)
    var lo := 0
    var hi := cum.size() - 1
    while hi - lo > 1:
        var mid := (lo + hi) >> 1
        if cum[mid] <= at:
            lo = mid
        else:
            hi = mid
    var seg := maxf(cum[hi] - cum[lo], 0.0001)
    return points[lo].lerp(points[hi], (at - cum[lo]) / seg)

func _apply_transform() -> void:
    var p := _sample(s)
    var ahead := _sample(s + 2.5)
    var behind := _sample(s - 0.5)
    if not loop and s > total - 2.6:
        ahead = _sample(total)
        behind = _sample(total - 3.0)
    var dir := ahead - behind
    dir.y = 0
    if dir.length_squared() < 0.0001:
        dir = Vector3.FORWARD
    var yaw := atan2(-dir.x, -dir.z)
    if lateral != 0.0:
        var right := Vector3(-dir.z, 0, dir.x).normalized()
        p += right * lateral
    global_transform = Transform3D(Basis(Vector3.UP, yaw), p)

func progress() -> float:
    return float(lap) * total + s

func _racer_step(delta: float) -> void:
    var target := 0.0
    if racing and lap < laps_to_finish:
        var d1 := _sample(s + 4.0) - _sample(s)
        var d2 := _sample(s + 26.0) - _sample(s + 14.0)
        var ang := absf(Vector2(d1.x, d1.z).angle_to(Vector2(d2.x, d2.z)))
        target = base_speed * rubber * (1.0 - clampf(ang / 1.3, 0.0, 0.55))
    cur_speed = move_toward(cur_speed, target, (3.2 if target > cur_speed else 6.0) * delta)
    s += cur_speed * delta
    if s >= total:
        s -= total
        lap += 1
    _apply_transform()

func _physics_process(delta: float) -> void:
    if racer:
        _racer_step(delta)
        return
    _honk_cd = maxf(0.0, _honk_cd - delta)
    _ghost = maxf(0.0, _ghost - delta)
    var pos := global_position
    var fwd := -global_transform.basis.z
    var right := global_transform.basis.x
    var blocked := false
    var by_player := false
    if _ghost <= 0.0:
        for o in others:
            if o == self:
                continue
            var d: Vector3 = (o as Node3D).global_position - pos
            var f := d.dot(fwd)
            if f > 0.0 and f < half_len + (o as TrafficCar).half_len + 4.0 and absf(d.dot(right)) < 2.2:
                blocked = true
                break
        if is_instance_valid(player):
            var d2 := player.global_position - pos
            var f2 := d2.dot(fwd)
            if f2 > 0.0 and f2 < half_len + player_half + 4.5 and absf(d2.dot(right)) < 2.6:
                blocked = true
                by_player = true
    if blocked:
        _blocked_for += delta
        if by_player and _blocked_for > 2.0 and _honk_cd <= 0.0:
            _honk_cd = 4.0
            honk.emit(pos)
        if _blocked_for > 6.0 and not by_player:
            _ghost = 2.0
            _blocked_for = 0.0
    else:
        _blocked_for = 0.0
    var target := 0.0 if blocked else cruise
    cur_speed = move_toward(cur_speed, target, (7.0 if blocked else 2.5) * delta)
    s += cur_speed * delta
    if s >= total:
        s -= total
    _apply_transform()
