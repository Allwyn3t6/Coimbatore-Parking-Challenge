extends Node3D
class_name CityWorld
## Builds the playable city from data/city.json (OpenStreetMap geometry with
## all names removed). Shop signs use invented bilingual names so the streets
## feel local without identifying any real business.

const CHUNK := 260.0
const SIGNS := [
    ["NOYYAL SILKS", "நொய்யல் சில்க்ஸ்"], ["KONGU MOBILES", "கொங்கு மொபைல்ஸ்"], ["SIRUVANI TEA STALL", "சிறுவாணி டீ ஸ்டால்"],
    ["VELLIANGIRI MEDICALS", "வெள்ளியங்கிரி மெடிக்கல்ஸ்"], ["MARUDHAM SWEETS", "மருதம் ஸ்வீட்ஸ்"], ["KOVAI PUMPS & MOTORS", "கோவை பம்ப்ஸ் & மோட்டார்ஸ்"],
    ["PERUR TEXTILES", "பேரூர் டெக்ஸ்டைல்ஸ்"], ["KONGU WET GRINDERS", "கொங்கு வெட் கிரைண்டர்ஸ்"], ["VINAYAKA MESS", "விநாயகா மெஸ்"],
    ["THUDIYALUR BAKERY", "துடியலூர் பேக்கரி"], ["SINGAI HARDWARES", "சிங்கை ஹார்ட்வேர்ஸ்"], ["MALLI FLOWER STALL", "மல்லி பூக்கடை"],
    ["KOVAI JEWELLERS", "கோவை ஜுவல்லர்ஸ்"], ["THAMBI TIFFIN CENTRE", "தம்பி டிபன் சென்டர்"], ["ANBU OPTICALS", "அன்பு ஆப்டிகல்ஸ்"],
    ["SELVAM ELECTRICALS", "செல்வம் எலக்ட்ரிகல்ஸ்"], ["KAVERI READYMADES", "காவேரி ரெடிமேட்ஸ்"], ["THENDRAL BOOK HOUSE", "தென்றல் புத்தக நிலையம்"],
    ["MUTHU STORES", "முத்து ஸ்டோர்ஸ்"], ["AMMAN FANCY", "அம்மன் பேன்சி"], ["NILGIRI SPICES", "நீலகிரி மசாலா"],
    ["VANAKKAM TRAVELS", "வணக்கம் டிராவல்ஸ்"], ["PALANI FRUITS", "பழனி பழக்கடை"], ["KOVAI COFFEE WORKS", "கோவை காபி"],
]
const FACADE_TINTS := [Color("#f4efe6"), Color("#f2d6a2"), Color("#cfe3c4"), Color("#bcd6e8"), Color("#f2c2c2"), Color("#e9e3b8"), Color("#d9cce8"), Color("#f5f5f5"), Color("#e8b98f")]
const SIGN_COLOURS := [Color("#b3201c"), Color("#1f4e8c"), Color("#f2b705"), Color("#1e7b3a"), Color("#6a1b9a"), Color("#e65100"), Color("#00695c")]

var data: Dictionary = {}
var lanes: Array = []            # Array[PackedVector3Array]
var roads2d: Array = []          # [{p: PackedVector2Array, w: float, c: String}]
var half := 650.0
var level_root: Node3D
var sign_font: Font

func build(d: Dictionary) -> void:
    data = d
    half = float(d.get("meta", {}).get("half", 650.0))
    sign_font = _make_sign_font()
    _ground()
    _flat_layers()
    _kerbs()
    _markings()
    _buildings()
    _trees_and_poles()
    _boundary()
    _scenery()
    for lane in d.get("lanes", []):
        var pts := PackedVector3Array()
        var p: Array = lane.p
        for i in range(0, p.size() - 1, 2):
            pts.append(Vector3(float(p[i]), 0, float(p[i + 1])))
        if pts.size() >= 2:
            lanes.append(pts)
    for r in d.get("roads", []):
        var pts2 := PackedVector2Array()
        var rp: Array = r.p
        for i in range(0, rp.size() - 1, 2):
            pts2.append(Vector2(float(rp[i]), float(rp[i + 1])))
        roads2d.append({"p": pts2, "w": float(r.w), "c": str(r.c)})
    level_root = Node3D.new()
    level_root.name = "LevelProps"
    add_child(level_root)

static func _make_sign_font() -> Font:
    var latin: FontFile = load("res://assets/fonts/BalooThambi2-Latin-Bold.woff2")
    var tamil: FontFile = load("res://assets/fonts/BalooThambi2-Tamil-Bold.woff2")
    if latin == null:
        return ThemeDB.fallback_font
    if tamil:
        latin.fallbacks = [tamil]
    return latin

func _chunk_key(x: float, z: float) -> Vector2i:
    return Vector2i(floori(x / CHUNK), floori(z / CHUNK))

func _flat(name_s: String, layer: Dictionary, y: float, mat: Material, shadows := false) -> void:
    var v: Array = layer.get("v", [])
    var idx: Array = layer.get("i", [])
    if idx.is_empty():
        return
    var verts := PackedVector3Array()
    verts.resize(v.size() / 2)
    for i in verts.size():
        verts[i] = Vector3(float(v[i * 2]), y, float(v[i * 2 + 1]))
    var indices := PackedInt32Array()
    indices.resize(idx.size())
    for i in range(0, idx.size() - 2, 3):
        var a := int(idx[i])
        var b := int(idx[i + 1])
        var c := int(idx[i + 2])
        # Godot front faces wind clockwise seen from the normal side (+Y).
        if (verts[b] - verts[a]).cross(verts[c] - verts[a]).y > 0.0:
            var t := b
            b = c
            c = t
        indices[i] = a
        indices[i + 1] = b
        indices[i + 2] = c
    var normals := PackedVector3Array()
    normals.resize(verts.size())
    normals.fill(Vector3.UP)
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    mesh.surface_set_material(0, mat)
    var mi := MeshInstance3D.new()
    mi.name = name_s
    mi.mesh = mesh
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

func _ground() -> void:
    var b := MeshBatcher.new()
    b.box(Vector3(0, -0.06, 0), Vector3(half * 2.0 + 1200.0, 0.1, half * 2.0 + 1200.0), Mats.soil())
    b.commit(self, "Ground", false)

func _flat_layers() -> void:
    _flat("Grass", data.get("grass", {}), 0.02, Mats.grass())
    _flat("Water", data.get("water", {}), 0.03, Mats.plain(Color("#4f7f8f"), 0.15, 0.2))
    _flat("Footpaths", data.get("foot", {}), 0.14, Mats.pavers())
    _flat("Roads", data.get("drive", {}), 0.0, Mats.asphalt())

func _kerbs() -> void:
    var b := MeshBatcher.new()
    var body := StaticBody3D.new()
    body.name = "Kerbs"
    body.collision_layer = 2
    body.collision_mask = 0
    body.add_to_group("kerb")
    add_child(body)
    var mat := Mats.kerb()
    for k in data.get("kerbs", []):
        var p: Array = k
        for i in range(0, p.size() - 3, 2):
            var a := Vector3(float(p[i]), 0, float(p[i + 1]))
            var c := Vector3(float(p[i + 2]), 0, float(p[i + 3]))
            var seg := c - a
            var ln := seg.length()
            if ln < 0.05:
                continue
            var yaw := atan2(seg.x, seg.z)
            var mid := (a + c) * 0.5
            var size := Vector3(0.28, 0.2, ln + 0.12)
            b.box(mid + Vector3(0, 0.08, 0), size, mat, yaw)
            var cs := CollisionShape3D.new()
            var shape := BoxShape3D.new()
            shape.size = Vector3(0.3, 1.6, ln + 0.1)
            cs.shape = shape
            cs.transform = Transform3D(Basis(Vector3.UP, yaw), mid + Vector3(0, 0.7, 0))
            body.add_child(cs)
    b.commit(self, "KerbMesh", false)

func _markings() -> void:
    var b := MeshBatcher.new()
    var white := Mats.plain(Color("#e9e6da"), 0.7)
    for m in data.get("marks", []):
        var p: Array = m
        var carry := 0.0
        for i in range(0, p.size() - 3, 2):
            var a := Vector3(float(p[i]), 0.02, float(p[i + 1]))
            var c := Vector3(float(p[i + 2]), 0.02, float(p[i + 3]))
            var seg := c - a
            var ln := seg.length()
            if ln < 0.1:
                continue
            var dir := seg / ln
            var yaw := atan2(dir.x, dir.z)
            var t := carry
            while t < ln:
                var dash := minf(3.0, ln - t)
                if dash > 0.4:
                    b.box(a + dir * (t + dash * 0.5), Vector3(0.14, 0.02, dash), white, yaw)
                t += 7.0
            carry = t - ln
    if not b.is_empty():
        b.commit(self, "Markings", false)

func _buildings() -> void:
    var chunks := {}
    var colliders := {}
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    var roof_mat := Mats.plain(Color("#8e8a82"), 0.95)
    var roof_red := Mats.roof_tiles()
    var tank_mat := Mats.plain(Color("#202326"), 0.6)
    var shop_mat := Mats.shopfront()
    var shutter_mat := Mats.shutter()
    var sign_count := 0
    var signs_root := Node3D.new()
    signs_root.name = "Signs"
    add_child(signs_root)
    for bd in data.get("buildings", []):
        var p: Array = bd.p
        var n := p.size() / 2
        if n < 3:
            continue
        var poly := PackedVector2Array()
        poly.resize(n)
        var cen := Vector2.ZERO
        for i in n:
            poly[i] = Vector2(float(p[i * 2]), float(p[i * 2 + 1]))
            cen += poly[i]
        cen /= float(n)
        var key := _chunk_key(cen.x, cen.y)
        if not chunks.has(key):
            chunks[key] = MeshBatcher.new()
            colliders[key] = PackedVector3Array()
        var b: MeshBatcher = chunks[key]
        var faces: PackedVector3Array = colliders[key]
        var floors := int(bd.get("f", 2))
        var kind := str(bd.get("k", "generic"))
        var h := 3.2 * float(floors) + 0.4
        var tint: Color = FACADE_TINTS[rng.randi() % FACADE_TINTS.size()]
        if kind == "civic":
            tint = Color("#f7f7f2")
        var wall := Mats.facade(Color.WHITE)
        var area := 0.0
        for i in n:
            var q := poly[(i + 1) % n]
            area += poly[i].x * q.y - q.x * poly[i].y
        var orient := 1.0 if area > 0.0 else -1.0
        var shop := kind == "shop"
        for i in n:
            var a2 := poly[i]
            var c2 := poly[(i + 1) % n]
            var e := c2 - a2
            if e.length() < 0.05:
                continue
            var nrm := Vector3(e.y, 0, -e.x).normalized() * orient
            var a0 := Vector3(a2.x, 0, a2.y)
            var c0 := Vector3(c2.x, 0, c2.y)
            var g := 3.4 if shop else 0.0
            if shop:
                var m: Material = shop_mat if rng.randf() < 0.65 else shutter_mat
                b.quad(a0, c0, c0 + Vector3(0, g, 0), a0 + Vector3(0, g, 0), nrm, m)
            b.quad(a0 + Vector3(0, g, 0), c0 + Vector3(0, g, 0), c0 + Vector3(0, h, 0), a0 + Vector3(0, h, 0), nrm, wall, tint)
            if shop:
                # Concrete sunshade (chajja) over the shop fronts.
                var mid := (a0 + c0) * 0.5 + nrm * 0.45
                b.box(mid + Vector3(0, g + 0.05, 0), Vector3(0.9, 0.12, e.length()), roof_mat, atan2(e.x, e.y))
            faces.append_array([a0, c0, c0 + Vector3(0, h, 0), a0, c0 + Vector3(0, h, 0), a0 + Vector3(0, h, 0)])
        # Roof
        var tri_idx := Geometry2D.triangulate_polygon(poly)
        var sloped := kind == "house" and floors <= 2 and rng.randf() < 0.5
        var rmat: Material = roof_red if sloped else roof_mat
        for t in range(0, tri_idx.size() - 2, 3):
            var ra := Vector3(poly[tri_idx[t]].x, h, poly[tri_idx[t]].y)
            var rb := Vector3(poly[tri_idx[t + 1]].x, h, poly[tri_idx[t + 1]].y)
            var rc := Vector3(poly[tri_idx[t + 2]].x, h, poly[tri_idx[t + 2]].y)
            b.tri(ra, rb, rc, Vector3.UP, rmat)
        var c3 := Vector3(cen.x, h, cen.y)
        if Geometry2D.is_point_in_polygon(cen, poly):
            if sloped:
                var ext := Rect2(poly[0], Vector2.ZERO)
                for v in poly:
                    ext = ext.expand(v)
                var s := minf(ext.size.x, ext.size.y)
                b.prism(c3 + Vector3(0, s * 0.18, 0), Vector3(ext.size.x * 0.8, s * 0.36, ext.size.y * 0.8), roof_red)
            elif kind == "temple":
                _gopuram(b, c3 - Vector3(0, h, 0), poly)
            elif kind == "mosque" or kind == "church":
                b.sphere(c3 + Vector3(0, 2.0, 0), Vector3(5, 5, 5), Mats.plain(Color("#eaeaea")))
            elif floors >= 2 and rng.randf() < 0.75:
                b.cylinder(c3 + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), 0.7, 1.4, tank_mat, 10)
                if rng.randf() < 0.4:
                    b.box(c3 + Vector3(1.8, 1.2, 0.5), Vector3(2.4, 2.4, 2.6), roof_mat)
        # Shop sign with an invented bilingual name.
        if bd.has("s") and sign_count < 260:
            var sg: Array = bd.s
            var sp := Vector3(float(sg[0]), 0, float(sg[1]))
            var syaw := float(sg[2])
            var sw := clampf(float(sg[3]), 2.5, 8.0)
            var col: Color = SIGN_COLOURS[rng.randi() % SIGN_COLOURS.size()]
            var basis := Basis(Vector3.UP, syaw)
            b.box_basis(sp + Vector3(0, 4.15, 0) + basis.z * 0.05, Vector3(sw, 1.1, 0.12), basis, Mats.plain(col, 0.6))
            var names: Array = SIGNS[rng.randi() % SIGNS.size()]
            var lbl := Label3D.new()
            lbl.text = "%s\n%s" % [names[1], names[0]]
            lbl.font = sign_font
            lbl.font_size = 64
            lbl.pixel_size = clampf(sw / 14.0, 0.18, 0.5) * 0.01 * 1.6
            lbl.outline_size = 0
            lbl.modulate = Color("#ffffff") if col.get_luminance() < 0.6 else Color("#2a1a0a")
            lbl.line_spacing = -18
            lbl.position = sp + Vector3(0, 4.15, 0) + basis.z * 0.13
            lbl.rotation.y = syaw
            lbl.double_sided = false
            lbl.visibility_range_end = 90.0
            lbl.width = 900
            lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
            signs_root.add_child(lbl)
            sign_count += 1
    var body := StaticBody3D.new()
    body.name = "BuildingColliders"
    add_child(body)
    for key in chunks:
        var mi: MeshInstance3D = (chunks[key] as MeshBatcher).commit(self, "Buildings_%d_%d" % [key.x, key.y], true)
        var faces: PackedVector3Array = colliders[key]
        if faces.size() > 0:
            var shape := ConcavePolygonShape3D.new()
            shape.backface_collision = true
            shape.set_faces(faces)
            var cs := CollisionShape3D.new()
            cs.shape = shape
            body.add_child(cs)

func _gopuram(b: MeshBatcher, base: Vector3, poly: PackedVector2Array) -> void:
    var ext := Rect2(poly[0], Vector2.ZERO)
    for v in poly:
        ext = ext.expand(v)
    var w := clampf(minf(ext.size.x, ext.size.y) * 0.7, 5.0, 14.0)
    var d := w * 0.62
    var y := base.y + 3.4
    var cols := [Color("#e9a23b"), Color("#d4553d"), Color("#3e8e7e"), Color("#efd27a"), Color("#c64f8a"), Color("#5e86c1")]
    b.box(base + Vector3(0, 1.8, 0), Vector3(w, 3.6, d), Mats.temple_wall())
    for i in 7:
        var th := 2.1
        b.box(base + Vector3(0, y - base.y + th * 0.5, 0) + Vector3(0, 0, 0), Vector3(w, th, d), Mats.plain(cols[i % cols.size()]))
        b.box(base + Vector3(0, y - base.y + th - 0.1, 0), Vector3(w + 0.3, 0.25, d + 0.3), Mats.plain(Color("#f3e6c8")))
        y += th
        w *= 0.86
        d *= 0.9
    b.cylinder_basis(base + Vector3(0, y - base.y + 0.9, 0), d * 0.45, w, Basis(Vector3.BACK, PI * 0.5), Mats.plain(Color("#e9a23b")), 10)
    for x in [-w * 0.3, 0.0, w * 0.3]:
        b.cone(base + Vector3(x, y - base.y + 1.6, 0), 0.25, 1.2, Mats.plain(Color("#d4af37"), 0.3, 0.8))

func _trees_and_poles() -> void:
    var chunks := {}
    var rng := RandomNumberGenerator.new()
    rng.seed = 99
    var trunk := Mats.plain(Color("#6b4f3a"))
    var leaf := [Mats.plain(Color("#3f6b2a")), Mats.plain(Color("#4f7d33")), Mats.plain(Color("#35602c"))]
    var palm_leaf := Mats.plain(Color("#5a8a35"))
    var t: Array = data.get("trees", [])
    for i in range(0, t.size() - 1, 2):
        var x := float(t[i])
        var z := float(t[i + 1])
        var key := _chunk_key(x, z)
        if not chunks.has(key):
            chunks[key] = MeshBatcher.new()
        var b: MeshBatcher = chunks[key]
        var p := Vector3(x, 0, z)
        var r := rng.randf()
        if r < 0.22:
            # Coconut palm
            var hgt := rng.randf_range(7.0, 10.0)
            var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.03, 0.12))
            b.cylinder_basis(p + lean * Vector3(0, hgt * 0.5, 0), 0.16, hgt, lean, trunk, 6)
            var top := p + lean * Vector3(0, hgt, 0)
            for k in 8:
                var a := float(k) / 8.0 * TAU
                var lb := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, deg_to_rad(-62.0))
                b.box_basis(top + lb * Vector3(0, 1.4, 0), Vector3(0.5, 2.8, 0.06), lb, palm_leaf)
        else:
            # Rain tree / neem: trunk + clustered canopy
            var hgt2 := rng.randf_range(3.0, 5.0)
            var s := rng.randf_range(3.5, 6.5)
            var m: Material = leaf[rng.randi() % leaf.size()]
            b.cylinder(p, 0.22, hgt2, trunk, 6)
            b.sphere(p + Vector3(0, hgt2 + s * 0.3, 0), Vector3(s * 1.5, s * 0.75, s * 1.4), m)
            b.sphere(p + Vector3(s * 0.4, hgt2 + s * 0.55, s * 0.2), Vector3(s, s * 0.6, s), m)
            b.sphere(p + Vector3(-s * 0.35, hgt2 + s * 0.5, -s * 0.3), Vector3(s, s * 0.6, s), m)
    # Street lights along main roads.
    var pole := Mats.plain(Color("#8d9399"), 0.5, 0.5)
    var lamp := Mats.glow(Color("#fff1c4"), 0.8)
    for r in data.get("roads", []):
        if str(r.c) != "major":
            continue
        var rp: Array = r.p
        var w := float(r.w)
        var acc := 0.0
        var side := 1.0
        for i in range(0, rp.size() - 3, 2):
            var a := Vector3(float(rp[i]), 0, float(rp[i + 1]))
            var c := Vector3(float(rp[i + 2]), 0, float(rp[i + 3]))
            var seg := c - a
            var ln := seg.length()
            if ln < 0.1:
                continue
            var dir := seg / ln
            var left := Vector3(dir.z, 0, -dir.x)
            var tt := 30.0 - acc
            while tt < ln:
                var p2 := a + dir * tt + left * side * (w * 0.5 + 0.9)
                var key2 := _chunk_key(p2.x, p2.z)
                if not chunks.has(key2):
                    chunks[key2] = MeshBatcher.new()
                var b2: MeshBatcher = chunks[key2]
                b2.cylinder(p2, 0.09, 8.0, pole, 6)
                var arm := p2 + Vector3(0, 7.9, 0) - left * side * 0.9
                b2.box(arm, Vector3(0.08, 0.08, 1.9), pole, atan2(left.x, left.z))
                b2.box(arm - left * side * 0.9 + Vector3(0, -0.08, 0), Vector3(0.35, 0.12, 0.6), lamp, atan2(left.x, left.z))
                side = -side
                tt += 35.0
            acc = fposmod(acc + ln, 35.0)
    for key in chunks:
        var mi: MeshInstance3D = (chunks[key] as MeshBatcher).commit(self, "Trees_%d_%d" % [key.x, key.y], true)

func _boundary() -> void:
    var body := StaticBody3D.new()
    body.name = "MapEdge"
    add_child(body)
    for i in 4:
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        var horiz := i < 2
        shape.size = Vector3(half * 2.0 + 20.0, 6.0, 2.0) if horiz else Vector3(2.0, 6.0, half * 2.0 + 20.0)
        cs.shape = shape
        var sgn := -1.0 if i % 2 == 0 else 1.0
        cs.position = Vector3(0, 3, sgn * (half - 3.0)) if horiz else Vector3(sgn * (half - 3.0), 3, 0)
        body.add_child(cs)

func _scenery() -> void:
    # Western Ghats silhouette on the western and northern horizon.
    var b := MeshBatcher.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    var cols := [Color("#9fb3c4"), Color("#a9bccb"), Color("#93a9bc")]
    for i in 26:
        var a := deg_to_rad(lerpf(150.0, 285.0, float(i) / 25.0) + rng.randf_range(-3, 3))
        var dist := rng.randf_range(1900.0, 2300.0)
        var p := Vector3(cos(a) * dist, -5.0, sin(a) * dist)
        var r := rng.randf_range(300.0, 560.0)
        var hh := rng.randf_range(90.0, 230.0)
        b.cone(p, r, hh, Mats.far_scenery(cols[i % cols.size()]))
    b.commit(self, "Hills", false)

## Per-level parked vehicles (decor + level neighbours), rebuilt each level.
func spawn_level_props(level: Dictionary) -> void:
    for c in level_root.get_children():
        c.queue_free()
    var b := MeshBatcher.new()
    var body := StaticBody3D.new()
    body.add_to_group("vehicle")
    level_root.add_child(body)
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(level.get("id", "x")))
    var bay_c := Vector2.INF
    if level.has("bay"):
        bay_c = Vector2(float(level.bay.c[0]), float(level.bay.c[1]))
    var spawn := Vector2(float(level.spawn[0]), float(level.spawn[1]))
    var items: Array = []
    for pc in level.get("parked", []):
        items.append([float(pc[0]), float(pc[1]), float(pc[2]), "car"])
    for dc in data.get("decor", []):
        var dp := Vector2(float(dc[0]), float(dc[1]))
        if bay_c != Vector2.INF and dp.distance_to(bay_c) < 12.0:
            continue
        if dp.distance_to(spawn) < 10.0:
            continue
        items.append([float(dc[0]), float(dc[1]), float(dc[2]), str(dc[3])])
    if str(level.get("type", "")) == "race":
        items = items.filter(func(it): return rng.randf() < 0.5)
    for it in items:
        var xf := Transform3D(Basis(Vector3.UP, float(it[2])), Vector3(float(it[0]), 0, float(it[1])))
        var size := Vector3.ONE
        match str(it[3]):
            "bike":
                size = VehicleFactory.two_wheeler(b, xf, VehicleFactory.CAR_COLOURS[rng.randi() % VehicleFactory.CAR_COLOURS.size()], false)
            "auto":
                size = VehicleFactory.auto_rickshaw(b, xf, VehicleFactory.AUTO_COLOURS[rng.randi() % VehicleFactory.AUTO_COLOURS.size()])
            _:
                var shapes := ["sedan", "hatch", "suv", "micro", "mpv"]
                var spec := {"shape": shapes[rng.randi() % shapes.size()], "length": rng.randf_range(3.7, 4.4), "width": rng.randf_range(1.66, 1.82), "color": VehicleFactory.CAR_COLOURS[rng.randi() % VehicleFactory.CAR_COLOURS.size()]}
                size = VehicleFactory.car(b, xf, spec)
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        cs.shape = shape
        cs.transform = Transform3D(xf.basis, xf.origin + Vector3(0, size.y * 0.5, 0))
        body.add_child(cs)
    if not b.is_empty():
        b.commit(level_root, "ParkedVehicles", true)
