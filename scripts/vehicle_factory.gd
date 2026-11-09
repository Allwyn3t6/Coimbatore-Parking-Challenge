extends RefCounted
class_name VehicleFactory
## Original low-poly vehicle meshes (no manufacturer designs or logos).
## Local frame: forward is -Z, up is +Y, origin on the ground at the centre.

const SHAPES := {
    "sedan": {"clear": 0.18, "body_h": 0.56, "cabin_h": 0.5, "cab": [0.32, 0.78], "wheel": 0.31},
    "hatch": {"clear": 0.17, "body_h": 0.58, "cabin_h": 0.56, "cab": [0.34, 0.97], "wheel": 0.30},
    "micro": {"clear": 0.22, "body_h": 0.66, "cabin_h": 0.58, "cab": [0.31, 0.96], "wheel": 0.33},
    "suv": {"clear": 0.24, "body_h": 0.74, "cabin_h": 0.58, "cab": [0.30, 0.96], "wheel": 0.37},
    "mpv": {"clear": 0.2, "body_h": 0.66, "cabin_h": 0.62, "cab": [0.25, 0.98], "wheel": 0.32},
}

const AUTO_COLOURS := [Color("#f2c200"), Color("#2e9b4f"), Color("#f2c200")]
const CAR_COLOURS := [Color("#e8ecef"), Color("#b9c2c9"), Color("#2b3138"), Color("#a6242f"), Color("#24508f"), Color("#7b8a8c"), Color("#f2f2f2"), Color("#5d4037"), Color("#1f6f5c")]
const BUS_COLOURS := [[Color("#1c5d8c"), Color("#f4e7c5")], [Color("#8a1c2b"), Color("#f2c94c")], [Color("#2f7d4a"), Color("#f0f0e6")], [Color("#5e2a84"), Color("#ffd166")]]
const LORRY_COLOURS := [Color("#e8781e"), Color("#d6322e"), Color("#2a7bbd"), Color("#f2c200")]

static func _bx(b: MeshBatcher, xf: Transform3D, local_c: Vector3, size: Vector3, mat: Material) -> void:
    b.box_basis(xf * local_c, size, xf.basis, mat)

static func _wheel(b: MeshBatcher, xf: Transform3D, local_c: Vector3, r: float, w: float) -> void:
    var basis := xf.basis * Basis(Vector3.BACK, PI * 0.5)
    b.cylinder_basis(xf * local_c, r, w, basis, Mats.plain(Color("#15181b"), 0.9), 10)
    b.cylinder_basis(xf * (local_c + Vector3(signf(local_c.x) * (w * 0.5 + 0.005), 0, 0)), r * 0.55, 0.02, basis, Mats.plain(Color("#9aa3aa"), 0.4, 0.6), 8)

## Adds a car. spec needs length, width, shape, color. Returns the collision size.
static func car(b: MeshBatcher, xf: Transform3D, spec: Dictionary, with_wheels := true, with_lights := true) -> Vector3:
    var L: float = float(spec.get("length", 4.0))
    var W: float = float(spec.get("width", 1.75))
    var shape: Dictionary = SHAPES.get(str(spec.get("shape", "hatch")), SHAPES.hatch)
    var paint := Mats.paint(spec.get("color", Color.WHITE))
    var dark := Mats.plain(Color("#1d2226"), 0.8)
    var c: float = shape.clear
    var bh: float = shape.body_h
    var ch: float = shape.cabin_h
    var z0: float = -L * 0.5 + float(shape.cab[0]) * L
    var z1: float = -L * 0.5 + float(shape.cab[1]) * L
    # Lower body with a slightly narrower shoulder for a softer silhouette.
    _bx(b, xf, Vector3(0, c + bh * 0.42, 0), Vector3(W, bh * 0.84, L), paint)
    _bx(b, xf, Vector3(0, c + bh * 0.9, 0.02), Vector3(W * 0.94, bh * 0.2, L * 0.97), paint)
    # Glasshouse + roof (roof is inset so pillars read as raked).
    var cab_len := z1 - z0
    var cz := (z0 + z1) * 0.5
    _bx(b, xf, Vector3(0, c + bh + ch * 0.5, cz), Vector3(W * 0.84, ch, cab_len), Mats.glass())
    _bx(b, xf, Vector3(0, c + bh + ch * 0.5, cz + cab_len * 0.04), Vector3(W * 0.86, ch * 0.62, cab_len * 0.7), paint)
    _bx(b, xf, Vector3(0, c + bh + ch + 0.035, cz + cab_len * 0.06), Vector3(W * 0.8, 0.07, cab_len * 0.82), paint)
    if str(spec.get("shape", "")) in ["suv", "micro"]:
        for sx in [-1.0, 1.0]:
            _bx(b, xf, Vector3(sx * W * 0.36, c + bh + ch + 0.1, cz), Vector3(0.05, 0.06, cab_len * 0.78), dark)
    # Bumpers, grille, plates, mirrors.
    _bx(b, xf, Vector3(0, c + 0.12, -L * 0.5 - 0.02), Vector3(W * 0.98, 0.2, 0.12), dark)
    _bx(b, xf, Vector3(0, c + 0.12, L * 0.5 + 0.02), Vector3(W * 0.98, 0.2, 0.12), dark)
    _bx(b, xf, Vector3(0, c + bh * 0.62, -L * 0.5 - 0.01), Vector3(W * 0.46, bh * 0.22, 0.05), dark)
    _bx(b, xf, Vector3(0, c + 0.2, -L * 0.5 - 0.09), Vector3(0.5, 0.12, 0.02), Mats.plain(Color("#f5f5f0")))
    _bx(b, xf, Vector3(0, c + bh * 0.55, L * 0.5 + 0.01), Vector3(0.5, 0.12, 0.03), Mats.plain(Color("#f5f5f0")))
    for sx in [-1.0, 1.0]:
        _bx(b, xf, Vector3(sx * (W * 0.5 + 0.07), c + bh + 0.08, z0 + 0.15), Vector3(0.14, 0.1, 0.18), paint)
    if with_lights:
        for sx in [-1.0, 1.0]:
            _bx(b, xf, Vector3(sx * W * 0.33, c + bh * 0.72, -L * 0.5 - 0.005), Vector3(W * 0.22, 0.12, 0.04), Mats.glow(Color("#fff3d6"), 0.6))
            _bx(b, xf, Vector3(sx * W * 0.36, c + bh * 0.72, L * 0.5 + 0.005), Vector3(W * 0.2, 0.12, 0.04), Mats.plain(Color("#b3261e"), 0.4))
    if with_wheels:
        var r: float = shape.wheel
        var wz := L * 0.5 - maxf(0.72, L * 0.18)
        for sz in [-1.0, 1.0]:
            for sx in [-1.0, 1.0]:
                _wheel(b, xf, Vector3(sx * (W * 0.5 - 0.1), r, sz * wz), r, 0.22)
    return Vector3(W, c + bh + ch + 0.1, L + 0.1)

static func auto_rickshaw(b: MeshBatcher, xf: Transform3D, colour: Color) -> Vector3:
    var L := 2.7
    var W := 1.35
    var paint := Mats.paint(colour)
    var black := Mats.plain(Color("#1b1b1b"), 0.8)
    _bx(b, xf, Vector3(0, 0.55, 0.25), Vector3(W, 0.5, 1.9), paint)
    _bx(b, xf, Vector3(0, 0.55, -0.95), Vector3(0.7, 0.5, 0.6), paint)
    _bx(b, xf, Vector3(0, 1.15, -0.98), Vector3(W * 0.95, 0.7, 0.05), Mats.glass())
    _bx(b, xf, Vector3(0, 1.82, 0.15), Vector3(W * 1.02, 0.1, 2.3), black)
    _bx(b, xf, Vector3(0, 1.3, 1.2), Vector3(W, 1.0, 0.06), black)
    for sx in [-1.0, 1.0]:
        _bx(b, xf, Vector3(sx * W * 0.5, 1.45, 0.7), Vector3(0.05, 0.7, 1.0), black)
        _bx(b, xf, Vector3(sx * W * 0.48, 1.3, -0.9), Vector3(0.04, 1.0, 0.05), black)
    _bx(b, xf, Vector3(0, 0.75, -1.28), Vector3(0.16, 0.12, 0.04), Mats.glow(Color("#fff3d6"), 0.6))
    _wheel(b, xf, Vector3(0.001, 0.22, -1.0), 0.22, 0.14)
    for sx in [-1.0, 1.0]:
        _wheel(b, xf, Vector3(sx * 0.62, 0.22, 0.75), 0.22, 0.14)
    return Vector3(W, 1.9, L)

static func bus(b: MeshBatcher, xf: Transform3D, scheme: Array) -> Vector3:
    var L := 10.5
    var W := 2.5
    var lower := Mats.paint(scheme[0])
    var upper := Mats.paint(scheme[1])
    _bx(b, xf, Vector3(0, 0.95, 0), Vector3(W, 1.2, L), lower)
    _bx(b, xf, Vector3(0, 2.25, 0), Vector3(W, 1.4, L), upper)
    _bx(b, xf, Vector3(0, 2.2, 0.2), Vector3(W + 0.03, 0.8, L * 0.86), Mats.glass())
    _bx(b, xf, Vector3(0, 2.0, -L * 0.5 - 0.01), Vector3(W * 0.92, 1.1, 0.05), Mats.glass())
    _bx(b, xf, Vector3(0, 3.0, -L * 0.5 - 0.02), Vector3(W * 0.8, 0.3, 0.05), Mats.glow(Color("#ff9f1c"), 1.2))
    _bx(b, xf, Vector3(0, 3.0, 0), Vector3(W * 0.96, 0.08, L * 0.98), Mats.plain(Color("#d9d9d9")))
    for sx in [-1.0, 1.0]:
        _bx(b, xf, Vector3(sx * W * 0.34, 0.8, -L * 0.5 - 0.02), Vector3(0.35, 0.18, 0.04), Mats.glow(Color("#fff3d6"), 0.6))
        for z in [-L * 0.5 + 2.0, L * 0.5 - 2.2, L * 0.5 - 3.3]:
            _wheel(b, xf, Vector3(sx * (W * 0.5 - 0.2), 0.5, z), 0.5, 0.32)
    return Vector3(W, 3.1, L)

static func lorry(b: MeshBatcher, xf: Transform3D, colour: Color) -> Vector3:
    var paint := Mats.paint(colour)
    _bx(b, xf, Vector3(0, 1.45, -2.6), Vector3(2.4, 1.9, 1.9), paint)
    _bx(b, xf, Vector3(0, 1.85, -3.56), Vector3(2.2, 0.8, 0.05), Mats.glass())
    _bx(b, xf, Vector3(0, 1.75, 1.0), Vector3(2.5, 2.3, 5.2), Mats.paint(Color("#2b6aa6")))
    _bx(b, xf, Vector3(0, 0.9, 1.0), Vector3(2.52, 0.35, 5.22), Mats.paint(Color("#f2c200")))
    _bx(b, xf, Vector3(0, 2.95, 1.0), Vector3(2.52, 0.12, 5.22), paint)
    for sx in [-1.0, 1.0]:
        for z in [-2.6, 1.6, 2.8]:
            _wheel(b, xf, Vector3(sx * 1.05, 0.5, z), 0.5, 0.3)
    return Vector3(2.5, 3.0, 7.2)

static func two_wheeler(b: MeshBatcher, xf: Transform3D, colour: Color, rider := true) -> Vector3:
    _bx(b, xf, Vector3(0, 0.55, 0), Vector3(0.3, 0.35, 1.2), Mats.paint(colour))
    _bx(b, xf, Vector3(0, 0.8, 0.2), Vector3(0.28, 0.1, 0.6), Mats.plain(Color("#1b1b1b")))
    _bx(b, xf, Vector3(0, 0.95, -0.55), Vector3(0.6, 0.04, 0.04), Mats.plain(Color("#555555")))
    for z in [-0.65, 0.65]:
        b.cylinder_basis(xf * Vector3(0, 0.3, z), 0.3, 0.1, xf.basis * Basis(Vector3.BACK, PI * 0.5), Mats.plain(Color("#15181b")), 10)
    if rider:
        var shirt: Color = [Color("#e8e8e8"), Color("#3f6fb5"), Color("#d94f3d"), Color("#2e8b57")][int(abs(colour.r * 10.0)) % 4]
        _bx(b, xf, Vector3(0, 1.25, 0.15), Vector3(0.42, 0.6, 0.28), Mats.plain(shirt))
        _bx(b, xf, Vector3(0, 0.95, -0.05), Vector3(0.4, 0.18, 0.5), Mats.plain(Color("#2b2f3a")))
        b.sphere(xf * Vector3(0, 1.7, 0.1), Vector3(0.3, 0.3, 0.3), Mats.plain(Color("#202020"), 0.4))
    return Vector3(0.7, 1.8, 1.9)

static func cow(b: MeshBatcher, xf: Transform3D) -> Vector3:
    var white := Mats.plain(Color("#ece7dc"))
    _bx(b, xf, Vector3(0, 1.05, 0), Vector3(0.75, 0.7, 1.7), white)
    _bx(b, xf, Vector3(0, 1.45, 0.45), Vector3(0.35, 0.25, 0.45), white)
    _bx(b, xf, Vector3(0, 1.3, -1.0), Vector3(0.35, 0.4, 0.55), white)
    for sx in [-1.0, 1.0]:
        for z in [-0.6, 0.6]:
            _bx(b, xf, Vector3(sx * 0.25, 0.37, z), Vector3(0.14, 0.75, 0.14), white)
        _bx(b, xf, Vector3(sx * 0.15, 1.62, -1.08), Vector3(0.05, 0.3, 0.05), Mats.plain(Color("#a0522d")))
    return Vector3(0.8, 1.6, 2.4)
