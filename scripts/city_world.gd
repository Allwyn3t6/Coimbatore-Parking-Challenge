extends Node3D
class_name CityWorld
## Builds the playable city from data/city.json (OpenStreetMap geometry with
## all names removed). Shop signs use invented bilingual names so the streets
## feel local without identifying any real business.

const CHUNK := 260.0
# Invented shop names (Tamil, English, display type). No real businesses.
const SIGNS := [
    ["நொய்யல் சில்க்ஸ்", "NOYYAL SILKS", "cloth"], ["கொங்கு மொபைல்ஸ்", "KONGU MOBILES", "none"], ["சிறுவாணி டீ ஸ்டால்", "SIRUVANI TEA STALL", "tea"],
    ["வெள்ளியங்கிரி மெடிக்கல்ஸ்", "VELLIANGIRI MEDICALS", "none"], ["மருதம் ஸ்வீட்ஸ்", "MARUDHAM SWEETS", "none"], ["கோவை பம்ப்ஸ் & மோட்டார்ஸ்", "KOVAI PUMPS & MOTORS", "none"],
    ["பேரூர் டெக்ஸ்டைல்ஸ்", "PERUR TEXTILES", "cloth"], ["கொங்கு வெட் கிரைண்டர்ஸ்", "KONGU WET GRINDERS", "none"], ["விநாயகா மெஸ்", "VINAYAKA MESS", "tea"],
    ["துடியலூர் பேக்கரி", "THUDIYALUR BAKERY", "none"], ["சிங்கை ஹார்ட்வேர்ஸ்", "SINGAI HARDWARES", "crates"], ["மல்லி பூக்கடை", "MALLI FLOWER STALL", "flowers"],
    ["கோவை ஜுவல்லர்ஸ்", "KOVAI JEWELLERS", "none"], ["தம்பி டிபன் சென்டர்", "THAMBI TIFFIN CENTRE", "tea"], ["அன்பு ஆப்டிகல்ஸ்", "ANBU OPTICALS", "none"],
    ["செல்வம் எலக்ட்ரிகல்ஸ்", "SELVAM ELECTRICALS", "none"], ["காவேரி ரெடிமேட்ஸ்", "KAVERI READYMADES", "cloth"], ["தென்றல் புத்தக நிலையம்", "THENDRAL BOOK HOUSE", "none"],
    ["முத்து ஸ்டோர்ஸ்", "MUTHU STORES", "crates"], ["அம்மன் பேன்சி", "AMMAN FANCY", "cloth"], ["நீலகிரி மசாலா", "NILGIRI SPICES", "crates"],
    ["வணக்கம் டிராவல்ஸ்", "VANAKKAM TRAVELS", "none"], ["பழனி பழக்கடை", "PALANI FRUITS", "crates"], ["கோவை காபி", "KOVAI COFFEE WORKS", "tea"],
    ["ஆனைகட்டி ஹோட்டல்", "ANAIKATTI HOTEL", "tea"], ["பவானி சாரீஸ்", "BHAVANI SAREES", "cloth"], ["அமுதம் பால் பண்ணை", "AMUDHAM MILK DEPOT", "none"],
    ["சக்தி பாத்திரக் கடை", "SAKTHI VESSELS", "crates"], ["மதி கம்ப்யூட்டர்ஸ்", "MATHI COMPUTERS", "none"], ["ராஜா பூட்வேர்", "RAJA FOOTWEAR", "crates"],
    ["கண்ணன் காய்கறி", "KANNAN VEGETABLES", "crates"], ["தமிழ் பிரிண்டர்ஸ்", "THAMIZH PRINTERS", "none"], ["இளநீர் கடை", "TENDER COCONUT", "crates"],
    ["வேலன் ஜூஸ் கார்னர்", "VELAN JUICE CORNER", "tea"], ["ஜோதி லைட்டிங்ஸ்", "JOTHI LIGHTINGS", "none"], ["அருணா கிஃப்ட்ஸ்", "ARUNA GIFTS", "cloth"],
    ["சூர்யா டைலர்ஸ்", "SURYA TAILORS", "cloth"], ["மணி சைக்கிள் மார்ட்", "MANI CYCLE MART", "crates"], ["குறிஞ்சி மருந்தகம்", "KURINJI PHARMACY", "none"],
    ["வைகை பிரியாணி", "VAIGAI BIRIYANI", "tea"], ["லட்சுமி மளிகை", "LAKSHMI GROCERIES", "crates"], ["கோவை டிஜிட்டல் ஸ்டுடியோ", "KOVAI DIGITAL STUDIO", "none"],
    ["பாரதி பெயிண்ட்ஸ்", "BHARATHI PAINTS", "crates"], ["சிவா ஆட்டோ ஸ்பேர்ஸ்", "SIVA AUTO SPARES", "crates"], ["நிலா ஐஸ்கிரீம்", "NILA ICE CREAM", "none"],
    ["தாமரை கைத்தறி", "THAMARAI HANDLOOMS", "cloth"], ["முருகன் மொபைல் சர்வீஸ்", "MURUGAN MOBILE SERVICE", "none"], ["செந்தூர் பூக்கடை", "SENTHUR FLOWERS", "flowers"],
]
const OFFERS := [
    ["ஆடித் தள்ளுபடி", "AADI SALE 50% OFF"], ["தீபாவளி சலுகை", "DIWALI OFFERS"], ["பொங்கல் சிறப்பு", "PONGAL SPECIAL"],
    ["புதிய வரவு", "NEW ARRIVALS"], ["சுத்த சைவ உணவு", "PURE VEG MEALS"], ["திருமண சேலைகள்", "WEDDING SAREES"],
    ["எக்ஸ்சேஞ்ச் மேளா", "EXCHANGE MELA"], ["இன்றே வாருங்கள்!", "VISIT TODAY!"], ["மாபெரும் விற்பனை", "MEGA SALE"],
]
const FACADE_TINTS := [Color("#f7d9e3"), Color("#ffd08a"), Color("#b8e6c4"), Color("#a9d8f0"), Color("#ffb3b3"), Color("#fff2a8"), Color("#d6c2f0"),
    Color("#f5f5f5"), Color("#ffc59a"), Color("#9fe0d8"), Color("#e6f59d"), Color("#f4a9cf"), Color("#c9e3ff"), Color("#ffe0b5")]
const SIGN_COLOURS := [Color("#c62828"), Color("#1565c0"), Color("#f9a825"), Color("#2e7d32"), Color("#6a1b9a"), Color("#ef6c00"), Color("#00838f"),
    Color("#ad1457"), Color("#283593"), Color("#fdd835"), Color("#00695c"), Color("#d84315")]
const AWNING_COLOURS := [Color("#1e88e5"), Color("#e53935"), Color("#43a047"), Color("#fb8c00"), Color("#8e24aa"), Color("#00acc1"), Color("#fdd835")]
const SHUTTER_COLOURS := [Color("#8fa3b8"), Color("#5b8fc7"), Color("#6fae7f"), Color("#c9a35b"), Color("#b0b0b0"), Color("#d07a6a")]
const GOODS_COLOURS := [Color("#e53935"), Color("#fdd835"), Color("#43a047"), Color("#1e88e5"), Color("#ec407a"), Color("#ff7043"), Color("#ab47bc"), Color("#26c6da"), Color("#fafafa")]

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
    _bunting()
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
    var sign_jobs: Array = []
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
                var open_shop := rng.randf() < 0.7
                var m: Material = shop_mat if open_shop else shutter_mat
                var sc: Color = Color.WHITE if open_shop else SHUTTER_COLOURS[rng.randi() % SHUTTER_COLOURS.size()]
                b.quad(a0, c0, c0 + Vector3(0, g, 0), a0 + Vector3(0, g, 0), nrm, m, sc)
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
        # Shop fronts: split the road-facing wall into shop units, each with
        # its own board, awning and goods on display.
        if bd.has("s"):
            var sg: Array = bd.s
            var units := clampi(int(round(float(sg[3]) / 6.0)), 1, 5)
            var cand: Array = sign_jobs
            cand.append({"sg": sg, "units": units, "floors": floors, "b": b, "d": Vector2(float(sg[0]), float(sg[1])).length()})
    _shop_fronts(sign_jobs, rng)
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

func _shop_fronts(jobs: Array, rng: RandomNumberGenerator) -> void:
    var signs_root := Node3D.new()
    signs_root.name = "Signs"
    add_child(signs_root)
    jobs.sort_custom(func(x, y): return float(x.d) < float(y.d))
    var label_budget: int = [450, 1000, 1700][clampi(AutoConfig.tier, 0, 2)]
    var name_order: Array = range(SIGNS.size())
    name_order.shuffle()
    var name_i := 0
    var board_edge := Mats.plain(Color("#f4f1e8"), 0.6)
    var pole := Mats.plain(Color("#5d6166"), 0.5, 0.4)
    for job in jobs:
        var sg: Array = job.sg
        var b: MeshBatcher = job.b
        var units: int = job.units
        var total := float(sg[3])
        var uw := total / float(units)
        var yaw := float(sg[2])
        var basis := Basis(Vector3.UP, yaw)
        var right := basis.x
        var out := basis.z
        var centre := Vector3(float(sg[0]), 0, float(sg[1]))
        for u in units:
            var off := -total * 0.5 + uw * (float(u) + 0.5)
            var c := centre + right * off
            var bw := maxf(uw - 0.35, 1.8)
            var col: Color = SIGN_COLOURS[rng.randi() % SIGN_COLOURS.size()]
            var entry: Array = SIGNS[name_order[name_i % name_order.size()]]
            name_i += 1
            # Signboard with a light frame
            b.box_basis(c + Vector3(0, 4.15, 0) + out * 0.04, Vector3(bw + 0.16, 1.32, 0.08), basis, board_edge)
            b.box_basis(c + Vector3(0, 4.15, 0) + out * 0.1, Vector3(bw, 1.16, 0.08), basis, Mats.plain(col, 0.55))
            # Tarp awning sloping out over the footpath
            var aw: Color = AWNING_COLOURS[rng.randi() % AWNING_COLOURS.size()]
            var tilt := basis * Basis(Vector3.RIGHT, deg_to_rad(18.0))
            b.box_basis(c + Vector3(0, 3.25, 0) + out * 0.55, Vector3(bw, 0.05, 1.1), tilt, Mats.plain(aw, 0.8))
            b.box_basis(c + Vector3(0, 3.06, 0) + out * 1.08, Vector3(bw, 0.16, 0.04), basis, Mats.plain(aw.darkened(0.25), 0.8))
            _display_goods(b, str(entry[2]), c, basis, bw, rng, pole)
            if label_budget > 0:
                label_budget -= 1
                var lbl := Label3D.new()
                lbl.text = "%s\n%s" % [entry[0], entry[1]]
                lbl.font = sign_font
                lbl.font_size = 64
                var chars := maxi(str(entry[1]).length(), int(str(entry[0]).length() * 0.8))
                lbl.pixel_size = minf((bw - 0.3) / (0.58 * 64.0 * float(chars)), 0.0072)
                lbl.modulate = Color("#ffffff") if col.get_luminance() < 0.62 else Color("#3a1a05")
                lbl.outline_size = 6
                lbl.outline_modulate = col.darkened(0.45)
                lbl.line_spacing = -22
                lbl.position = c + Vector3(0, 4.15, 0) + out * 0.17
                lbl.rotation.y = yaw
                lbl.double_sided = false
                lbl.visibility_range_end = 85.0
                lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
                signs_root.add_child(lbl)
        # Flex hoarding on the upper floors of some taller buildings.
        if int(job.floors) >= 3 and rng.randf() < 0.35 and label_budget > 0:
            var hw := minf(total * 0.8, 9.0)
            var hc := centre + Vector3(0, 6.6, 0) + out * 0.12
            var hcol: Color = SIGN_COLOURS[rng.randi() % SIGN_COLOURS.size()]
            b.box_basis(hc, Vector3(hw, 2.3, 0.1), basis, Mats.plain(hcol, 0.6))
            b.box_basis(hc + out * 0.02 + Vector3(0, -0.7, 0), Vector3(hw, 0.5, 0.1), basis, Mats.plain(Color("#fdd835") if hcol != Color("#fdd835") else Color("#c62828"), 0.6))
            var offer: Array = OFFERS[rng.randi() % OFFERS.size()]
            var lbl2 := Label3D.new()
            lbl2.text = "%s\n%s" % [offer[0], offer[1]]
            lbl2.font = sign_font
            lbl2.font_size = 72
            lbl2.pixel_size = minf((hw - 0.6) / (0.58 * 72.0 * float(str(offer[1]).length())), 0.012)
            lbl2.outline_size = 10
            lbl2.outline_modulate = Color(0, 0, 0, 0.6)
            lbl2.line_spacing = -20
            lbl2.position = hc + out * 0.09 + Vector3(0, 0.25, 0)
            lbl2.rotation.y = yaw
            lbl2.double_sided = false
            lbl2.visibility_range_end = 140.0
            signs_root.add_child(lbl2)
            label_budget -= 1

func _display_goods(b: MeshBatcher, kind: String, c: Vector3, basis: Basis, bw: float, rng: RandomNumberGenerator, pole: Material) -> void:
    var out := basis.z
    var right := basis.x
    var base := c + out * 0.6 + Vector3(0, 0.14, 0)
    match kind:
        "cloth":
            # Hanging sarees / clothes on a rail under the awning.
            b.box_basis(c + out * 0.7 + Vector3(0, 2.8, 0), Vector3(bw * 0.9, 0.05, 0.05), basis, pole)
            var n := int(bw / 0.6)
            for i in n:
                var x := -bw * 0.45 + (float(i) + 0.5) * (bw * 0.9 / float(n))
                var col: Color = GOODS_COLOURS[rng.randi() % GOODS_COLOURS.size()]
                b.box_basis(c + out * 0.7 + right * x + Vector3(0, 2.25, 0), Vector3(0.34, 1.1, 0.03), basis, Mats.plain(col, 0.9))
        "crates":
            var n2 := int(bw / 0.9)
            for i in n2:
                var x2 := -bw * 0.45 + (float(i) + 0.5) * (bw * 0.9 / float(n2))
                var col2: Color = GOODS_COLOURS[rng.randi() % GOODS_COLOURS.size()]
                b.box_basis(base + right * x2 + Vector3(0, 0.25, 0), Vector3(0.75, 0.5, 0.6), basis, Mats.plain(Color("#8d6e63"), 0.9))
                b.box_basis(base + right * x2 + Vector3(0, 0.56, 0), Vector3(0.66, 0.14, 0.5), basis, Mats.plain(col2, 0.8))
        "flowers":
            # Jasmine and marigold garlands
            var n3 := int(bw / 0.3)
            for i in n3:
                var x3 := -bw * 0.45 + (float(i) + 0.5) * (bw * 0.9 / float(n3))
                var col3: Color = [Color("#fafafa"), Color("#ff9800"), Color("#fdd835"), Color("#e53935")][i % 4]
                b.box_basis(c + out * 0.8 + right * x3 + Vector3(0, 2.4, 0), Vector3(0.08, 0.9, 0.08), basis, Mats.plain(col3, 0.9))
            b.box_basis(base + Vector3(0, 0.4, 0), Vector3(bw * 0.8, 0.8, 0.7), basis, Mats.plain(Color("#795548"), 0.9))
        "tea":
            # Steel counter, glass jars and a bench
            b.box_basis(base + Vector3(0, 0.5, 0), Vector3(minf(bw * 0.6, 2.4), 1.0, 0.6), basis, Mats.plain(Color("#b0bec5"), 0.3, 0.7))
            for i in 3:
                b.cylinder(base + right * (-0.5 + 0.5 * float(i)) + Vector3(0, 1.0, 0), 0.13, 0.3, Mats.plain(GOODS_COLOURS[rng.randi() % GOODS_COLOURS.size()], 0.2), 8)
            b.box_basis(base + out * 0.9 + Vector3(0, 0.25, 0), Vector3(1.6, 0.08, 0.35), basis, Mats.plain(Color("#1565c0"), 0.7))
        _:
            pass

func _bunting() -> void:
    var flags: Array = data.get("flags", [])
    if flags.is_empty():
        return
    var b := MeshBatcher.new()
    var rope := Mats.plain(Color("#3e3e3e"))
    var cols := [Color("#e53935"), Color("#fdd835"), Color("#43a047"), Color("#1e88e5"), Color("#ff9800"), Color("#ec407a"), Color("#ffffff")]
    var mats: Array = []
    for c in cols:
        var m := Mats.plain(c, 0.9).duplicate() as StandardMaterial3D
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
        mats.append(m)
    for f in flags:
        var a := Vector3(float(f[0]), 6.2, float(f[1]))
        var e := Vector3(float(f[2]), 6.2, float(f[3]))
        var span := a.distance_to(e)
        if span < 3.0:
            continue
        var dir := (e - a) / span
        var n := int(span / 0.55)
        var prev := a
        for i in range(1, n + 1):
            var t := float(i) / float(n)
            var p := a.lerp(e, t) + Vector3(0, -sin(t * PI) * 0.9, 0)
            var mid := (prev + p) * 0.5
            b.box_basis(mid, Vector3(0.02, 0.02, prev.distance_to(p)), Basis.looking_at(p - prev), rope)
            if i < n:
                var m: Material = mats[i % mats.size()]
                var side := dir.cross(Vector3.UP).normalized()
                b.tri(p - dir * 0.2, p + dir * 0.2, p + Vector3(0, -0.45, 0), side, m)
            prev = p
    b.commit(self, "Bunting", false)

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
