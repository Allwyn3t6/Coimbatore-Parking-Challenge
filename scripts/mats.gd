extends RefCounted
class_name Mats
## Shared materials and procedurally generated textures (no external image
## assets needed). Everything is cached so batching can group by material.

static var _cache := {}

static func _img_tex(img: Image) -> ImageTexture:
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

static func _noise(seed_v: int, freq: float) -> FastNoiseLite:
    var n := FastNoiseLite.new()
    n.seed = seed_v
    n.frequency = freq
    n.fractal_octaves = 3
    return n

static func _tri(mat: StandardMaterial3D, tex: Texture2D, metres: float, offset := Vector3.ZERO) -> StandardMaterial3D:
    mat.albedo_texture = tex
    mat.uv1_triplanar = true
    mat.uv1_world_triplanar = true
    mat.uv1_scale = Vector3.ONE / metres
    mat.uv1_offset = offset
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return mat

static func plain(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
    var key := "plain_%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
    if _cache.has(key):
        return _cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    _cache[key] = m
    return m

static func glow(color: Color, energy := 1.5) -> StandardMaterial3D:
    var key := "glow_%s_%.2f" % [color.to_html(), energy]
    if _cache.has(key):
        return _cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = energy
    _cache[key] = m
    return m

static func unshaded(color: Color, transparent := false) -> StandardMaterial3D:
    var key := "unshaded_%s_%s" % [color.to_html(), transparent]
    if _cache.has(key):
        return _cache[key]
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = color
    if transparent:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
        m.no_depth_test = false
    _cache[key] = m
    return m

static func far_scenery(color: Color) -> StandardMaterial3D:
    var key := "far_%s" % color.to_html()
    if _cache.has(key):
        return _cache[key]
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = color
    m.disable_fog = true
    _cache[key] = m
    return m

static func asphalt() -> StandardMaterial3D:
    if _cache.has("asphalt"):
        return _cache["asphalt"]
    var size := 256
    var img := Image.create(size, size, false, Image.FORMAT_RGB8)
    var n := _noise(11, 0.035)
    var fine := _noise(29, 0.4)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    for y in size:
        for x in size:
            var v := 0.24 + n.get_noise_2d(x, y) * 0.035 + fine.get_noise_2d(x, y) * 0.03
            if rng.randf() < 0.015:
                v += 0.07
            img.set_pixel(x, y, Color(v, v * 1.02, v * 1.06))
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 9.0)
    m.roughness = 0.92
    _cache["asphalt"] = m
    return m

static func pavers() -> StandardMaterial3D:
    if _cache.has("pavers"):
        return _cache["pavers"]
    var size := 128
    var img := Image.create(size, size, false, Image.FORMAT_RGB8)
    var n := _noise(5, 0.2)
    for y in size:
        for x in size:
            var tx := x / 32
            var ty := y / 16
            var off := 16 if ty % 2 == 1 else 0
            var lx := (x + off) % 32
            var ly := y % 16
            var grout := lx < 2 or ly < 2
            var red := (((x + off) / 32) + ty) % 3 == 0
            var c := Color(0.62, 0.60, 0.56) if not red else Color(0.62, 0.38, 0.32)
            if grout:
                c = Color(0.42, 0.41, 0.39)
            var k := 1.0 + n.get_noise_2d(x, y) * 0.08 + float((tx * 7 + ty * 3) % 5) * 0.012
            img.set_pixel(x, y, c * k)
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 2.0)
    m.roughness = 0.9
    _cache["pavers"] = m
    return m

static func kerb() -> StandardMaterial3D:
    if _cache.has("kerb"):
        return _cache["kerb"]
    var img := Image.create(64, 8, false, Image.FORMAT_RGB8)
    for y in 8:
        for x in 64:
            img.set_pixel(x, y, Color(0.95, 0.78, 0.12) if x < 32 else Color(0.08, 0.08, 0.08))
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 1.6)
    m.roughness = 0.7
    _cache["kerb"] = m
    return m

static func grass() -> StandardMaterial3D:
    if _cache.has("grass"):
        return _cache["grass"]
    var size := 128
    var img := Image.create(size, size, false, Image.FORMAT_RGB8)
    var n := _noise(3, 0.06)
    var fine := _noise(9, 0.5)
    for y in size:
        for x in size:
            var v := n.get_noise_2d(x, y) * 0.08 + fine.get_noise_2d(x, y) * 0.05
            img.set_pixel(x, y, Color(0.33 + v, 0.47 + v, 0.20 + v * 0.5))
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 6.0)
    m.roughness = 1.0
    _cache["grass"] = m
    return m

static func soil() -> StandardMaterial3D:
    if _cache.has("soil"):
        return _cache["soil"]
    var size := 128
    var img := Image.create(size, size, false, Image.FORMAT_RGB8)
    var n := _noise(13, 0.05)
    for y in size:
        for x in size:
            var v := n.get_noise_2d(x, y) * 0.07
            img.set_pixel(x, y, Color(0.55 + v, 0.45 + v, 0.33 + v))
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 10.0)
    m.roughness = 1.0
    _cache["soil"] = m
    return m

static func track() -> StandardMaterial3D:
    if _cache.has("track"):
        return _cache["track"]
    var m := plain(Color("#a5533f"), 0.95).duplicate() as StandardMaterial3D
    _cache["track"] = m
    return m

## White facade with a window + sunshade (chajja) per 3.2 m bay. Tinted per colour.
static func facade(tint: Color) -> StandardMaterial3D:
    var key := "facade_%s" % tint.to_html()
    if _cache.has(key):
        return _cache[key]
    var tex: ImageTexture = _cache.get("facade_tex")
    if tex == null:
        var s := 128
        var img := Image.create(s, s, false, Image.FORMAT_RGB8)
        for y in s:
            for x in s:
                var c := Color(0.95, 0.94, 0.92)
                if y >= 34 and y <= 96 and x >= 30 and x <= 98:
                    c = Color(0.86, 0.86, 0.86)
                    if y >= 38 and y <= 92 and x >= 34 and x <= 94:
                        var lit := ((x / 20) + (y / 18)) % 4 == 0
                        c = Color(0.17, 0.21, 0.26) if not lit else Color(0.36, 0.42, 0.48)
                        if x == 64 or y == 64:
                            c = Color(0.75, 0.75, 0.75)
                if y >= 24 and y < 32 and x >= 22 and x <= 106:
                    c = Color(0.62, 0.62, 0.62)
                if y > 120:
                    c = c * 0.9
                img.set_pixel(x, y, c)
        tex = _img_tex(img)
        _cache["facade_tex"] = tex
    var m := _tri(StandardMaterial3D.new(), tex, 3.2, Vector3(0, -0.15 / 3.2, 0))
    m.albedo_color = tint
    m.vertex_color_use_as_albedo = true
    m.roughness = 0.88
    _cache[key] = m
    return m

static func shutter() -> StandardMaterial3D:
    if _cache.has("shutter"):
        return _cache["shutter"]
    var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
    for y in 32:
        for x in 32:
            var v := 0.58 + (0.12 if y % 4 < 2 else -0.04)
            img.set_pixel(x, y, Color(v * 0.92, v * 0.96, v))
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 1.2)
    m.roughness = 0.5
    m.metallic = 0.4
    _cache["shutter"] = m
    return m

static func shopfront() -> StandardMaterial3D:
    if _cache.has("shopfront"):
        return _cache["shopfront"]
    var w := 128
    var h := 64
    var img := Image.create(w, h, false, Image.FORMAT_RGB8)
    var palette := [Color("#d94f3d"), Color("#f2b705"), Color("#2e8b57"), Color("#3f6fb5"), Color("#e07bb0"), Color("#f28c28"), Color("#ffffff")]
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    for y in h:
        for x in w:
            var c := Color(0.95, 0.83, 0.55)
            var shelf := y % 16
            if shelf < 2:
                c = Color(0.45, 0.30, 0.2)
            elif shelf > 4:
                var item := ((x / 7) + (y / 16) * 3) % palette.size()
                if x % 7 != 0:
                    c = palette[item] * (0.85 + float((x * 13 + y) % 5) * 0.04)
            img.set_pixel(x, y, c)
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 3.0)
    m.emission_enabled = true
    m.emission = Color(0.25, 0.2, 0.12)
    m.roughness = 0.8
    _cache["shopfront"] = m
    return m

static func temple_wall() -> StandardMaterial3D:
    if _cache.has("temple_wall"):
        return _cache["temple_wall"]
    var img := Image.create(32, 8, false, Image.FORMAT_RGB8)
    for y in 8:
        for x in 32:
            img.set_pixel(x, y, Color(0.72, 0.18, 0.12) if x < 16 else Color(0.97, 0.95, 0.9))
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 1.0)
    _cache["temple_wall"] = m
    return m

static func roof_tiles() -> StandardMaterial3D:
    if _cache.has("roof_tiles"):
        return _cache["roof_tiles"]
    var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
    for y in 32:
        for x in 32:
            var v := 1.0 - float(y % 8) * 0.04 - (0.08 if (x + (y / 8) * 4) % 8 == 0 else 0.0)
            img.set_pixel(x, y, Color(0.70, 0.30, 0.20) * v)
    var m := _tri(StandardMaterial3D.new(), _img_tex(img), 1.4)
    _cache["roof_tiles"] = m
    return m

static func glass() -> StandardMaterial3D:
    if _cache.has("glass"):
        return _cache["glass"]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.13, 0.19, 0.25)
    m.metallic = 0.6
    m.roughness = 0.12
    _cache["glass"] = m
    return m

static func paint(color: Color) -> StandardMaterial3D:
    var key := "paint_%s" % color.to_html()
    if _cache.has(key):
        return _cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = 0.35
    m.roughness = 0.32
    _cache[key] = m
    return m
