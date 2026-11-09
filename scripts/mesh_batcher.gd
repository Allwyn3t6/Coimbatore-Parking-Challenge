extends RefCounted
class_name MeshBatcher
## Merges many static primitives into one multi-surface mesh (one surface per
## material) so the whole city draws in a few dozen calls on mobile GPUs.

static var _unit_box: BoxMesh
static var _unit_cyl: CylinderMesh
static var _unit_cyl6: CylinderMesh
static var _unit_cone: CylinderMesh
static var _unit_sphere: SphereMesh
static var _unit_prism: PrismMesh

var _tools := {}
var _order: Array = []
var _raw := {}
var _raw_order: Array = []

static func unit_box() -> BoxMesh:
    if _unit_box == null:
        _unit_box = BoxMesh.new()
        _unit_box.size = Vector3.ONE
    return _unit_box

static func unit_cylinder(segments := 12) -> CylinderMesh:
    if segments <= 6:
        if _unit_cyl6 == null:
            _unit_cyl6 = CylinderMesh.new()
            _unit_cyl6.top_radius = 0.5
            _unit_cyl6.bottom_radius = 0.5
            _unit_cyl6.height = 1.0
            _unit_cyl6.radial_segments = 6
            _unit_cyl6.rings = 1
        return _unit_cyl6
    if _unit_cyl == null:
        _unit_cyl = CylinderMesh.new()
        _unit_cyl.top_radius = 0.5
        _unit_cyl.bottom_radius = 0.5
        _unit_cyl.height = 1.0
        _unit_cyl.radial_segments = 14
        _unit_cyl.rings = 1
    return _unit_cyl

static func unit_cone() -> CylinderMesh:
    if _unit_cone == null:
        _unit_cone = CylinderMesh.new()
        _unit_cone.top_radius = 0.0
        _unit_cone.bottom_radius = 0.5
        _unit_cone.height = 1.0
        _unit_cone.radial_segments = 9
        _unit_cone.rings = 1
    return _unit_cone

static func unit_sphere() -> SphereMesh:
    if _unit_sphere == null:
        _unit_sphere = SphereMesh.new()
        _unit_sphere.radius = 0.5
        _unit_sphere.height = 1.0
        _unit_sphere.radial_segments = 9
        _unit_sphere.rings = 5
    return _unit_sphere

static func unit_prism() -> PrismMesh:
    if _unit_prism == null:
        _unit_prism = PrismMesh.new()
        _unit_prism.size = Vector3.ONE
    return _unit_prism

func _tool(mat: Material) -> SurfaceTool:
    var st: SurfaceTool = _tools.get(mat)
    if st == null:
        st = SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        _tools[mat] = st
        _order.append(mat)
    return st

func add_mesh(mesh: Mesh, xf: Transform3D, mat: Material) -> void:
    _tool(mat).append_from(mesh, 0, xf)

## Axis-aligned (optionally yawed) box given its centre and full size.
func box(center: Vector3, size: Vector3, mat: Material, yaw := 0.0) -> void:
    var b := Basis(Vector3.UP, yaw) * Basis.from_scale(size)
    add_mesh(unit_box(), Transform3D(b, center), mat)

func box_basis(center: Vector3, size: Vector3, basis: Basis, mat: Material) -> void:
    add_mesh(unit_box(), Transform3D(basis * Basis.from_scale(size), center), mat)

func cylinder(base_center: Vector3, radius: float, height: float, mat: Material, segments := 12) -> void:
    var b := Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0))
    add_mesh(unit_cylinder(segments), Transform3D(b, base_center + Vector3(0, height * 0.5, 0)), mat)

func cylinder_basis(center: Vector3, radius: float, height: float, basis: Basis, mat: Material, segments := 12) -> void:
    add_mesh(unit_cylinder(segments), Transform3D(basis * Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0)), center), mat)

func cone(base_center: Vector3, radius: float, height: float, mat: Material) -> void:
    var b := Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0))
    add_mesh(unit_cone(), Transform3D(b, base_center + Vector3(0, height * 0.5, 0)), mat)

func sphere(center: Vector3, size: Vector3, mat: Material) -> void:
    add_mesh(unit_sphere(), Transform3D(Basis.from_scale(size), center), mat)

func prism(center: Vector3, size: Vector3, mat: Material, yaw := 0.0) -> void:
    var b := Basis(Vector3.UP, yaw) * Basis.from_scale(size)
    add_mesh(unit_prism(), Transform3D(b, center), mat)

## Raw triangle with a fixed normal; winding is corrected to face along n.
func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, mat: Material, col := Color.WHITE) -> void:
    var st: SurfaceTool = _raw.get(mat)
    if st == null:
        st = SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        _raw[mat] = st
        _raw_order.append(mat)
    if (b - a).cross(c - a).dot(n) > 0.0:
        var t := b
        b = c
        c = t
    st.set_color(col)
    st.set_normal(n)
    st.add_vertex(a)
    st.set_normal(n)
    st.add_vertex(b)
    st.set_normal(n)
    st.add_vertex(c)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, mat: Material, col := Color.WHITE) -> void:
    tri(a, b, c, n, mat, col)
    tri(a, c, d, n, mat, col)

func is_empty() -> bool:
    return _order.is_empty() and _raw_order.is_empty()

func commit_mesh() -> ArrayMesh:
    var mesh := ArrayMesh.new()
    for mat in _order:
        var st: SurfaceTool = _tools[mat]
        st.commit(mesh)
        mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
    for mat in _raw_order:
        var st: SurfaceTool = _raw[mat]
        st.commit(mesh)
        mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
    _tools.clear()
    _order.clear()
    _raw.clear()
    _raw_order.clear()
    return mesh

func commit(parent: Node, label: String, shadows := true) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = label
    mi.mesh = commit_mesh()
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi
