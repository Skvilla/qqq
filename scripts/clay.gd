class_name Clay
extends RefCounted
## Shared smooth procedural primitives. No external models or textures required.

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	result.metallic_specular = 0.22
	return result

static func mesh_node(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

static func ellipsoid(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := mesh_node(parent, mesh, at, mat)
	node.scale = size
	return node

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return mesh_node(parent, mesh, at, mat)

static func rounded_box(parent: Node3D, at: Vector3, size: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	# Project a subdivided box onto the rounded Minkowski surface. Real curved
	# corners and smooth normals preserve the clay silhouette from every angle.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)))
	var core := half - Vector3.ONE * r
	var faces := [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	]
	var divisions := 10
	for face in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		for y in range(divisions):
			for x in range(divisions):
				for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
					var uv: Vector2 = (Vector2(x, y) + corner) / divisions
					var p := (n + u * (uv.x * 2 - 1) + v * (uv.y * 2 - 1)) * half
					var inner := p.clamp(-core, core)
					var normal := (p - inner).normalized()
					surface.set_normal(normal)
					surface.add_vertex(inner + normal * r)
	return mesh_node(parent, surface.commit(), at, mat)

static func tube(parent: Node3D, points: PackedVector3Array, radius: float, mat: Material) -> void:
	for i in range(points.size() - 1):
		var offset := points[i + 1] - points[i]
		var piece := cylinder(parent, (points[i + 1] + points[i]) * 0.5, radius, offset.length(), mat)
		var axis := Vector3.UP.cross(offset.normalized())
		if axis.length_squared() > 0.0001:
			piece.quaternion = Quaternion(axis.normalized(), Vector3.UP.angle_to(offset))
		ellipsoid(parent, points[i], Vector3.ONE * radius * 2, mat)
	ellipsoid(parent, points[-1], Vector3.ONE * radius * 2, mat)

static func collider(parent: Node3D, at: Vector3, shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body
