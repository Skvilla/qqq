extends Node3D
## A seeded miniature woodland set, built entirely from soft geometric forms.

var rng := RandomNumberGenerator.new()
var moss := Clay.material(Color("9fae7b"))
var bark := Clay.material(Color("a08464"))
var path_mat := Clay.material(Color("ddc9a0"))
var foliage: Array[Material] = [preload("res://materials/clay_leaf.tres"), Clay.material(Color("8ea96f")), Clay.material(Color("668b76")), Clay.material(Color("b1bc80"))]

func _ready() -> void:
	rng.seed = 12851
	_lighting()
	Clay.cylinder(self, Vector3(0, -0.28, 0), 28.0, 0.5, moss)
	var ground := BoxShape3D.new()
	ground.size = Vector3(56, 0.5, 56)
	Clay.collider(self, Vector3(0, -0.28, 0), ground)
	_path()
	# A generous clearing keeps driving and the ten-second demo unobstructed.
	for i in range(58):
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(8.0, 25.0)
		var at := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		if absf(at.x - sin(at.z * 0.22) * 2.8) < 3.2:
			continue
		_tree(at, rng.randf_range(0.75, 1.4), i % 3 == 0)
	for i in range(45):
		var angle := rng.randf() * TAU
		var at := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(5.8, 23.5)
		if absf(at.x - sin(at.z * 0.22) * 2.8) < 2.5:
			continue
		_bush(at, rng.randf_range(0.45, 0.9))
		if i % 3 == 0:
			_mushrooms(at + Vector3(0.8, 0, 0.5))
	for i in range(55):
		var z := rng.randf_range(-23.0, 23.0)
		var x := sin(z * 0.22) * 2.8 + (2.1 if i % 2 == 0 else -2.1)
		var at := Vector3(x, 0.025, z)
		if at.length() > 4.0:
			_grass(at)
	# A small rock arrangement and carved woodland sign frame the opening shot.
	for i in range(4):
		var at := Vector3(-5.6 + i * 0.7, 0.2, -2.5 + sin(i * 1.9) * 0.5)
		Clay.ellipsoid(self, at, Vector3(1.1, 0.65, 0.9), Clay.material(Color("b5b7a2")))
		var stone := SphereShape3D.new()
		stone.radius = 0.5
		Clay.collider(self, at, stone)
	_sign(Vector3(4.7, 0, -3.4))
	# Contain the play area within the visible forest; these walls are out of shot.
	for side in [-1, 1]:
		var wall := BoxShape3D.new()
		wall.size = Vector3(1, 5, 50)
		Clay.collider(self, Vector3(side * 24.5, 2, 0), wall)
		var end := BoxShape3D.new()
		end.size = Vector3(50, 5, 1)
		Clay.collider(self, Vector3(0, 2, side * 24.5), end)

func _lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cbd6ba")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e2ead9")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("cbd6ba")
	env.fog_density = 0.008
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color("fff0cc")
	sun.light_energy = 0.28
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	sun.shadow_blur = 2.5
	sun.shadow_opacity = 0.65
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_color = Color("cbdde4")
	fill.light_energy = 0.08
	add_child(fill)

func _path() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(100):
		var z0 := -27.0 + float(i) * 0.54
		var z1 := z0 + 0.54
		var a := Vector3(sin(z0 * 0.22) * 2.8, -0.015, z0)
		var b := Vector3(sin(z1 * 0.22) * 2.8, -0.015, z1)
		var w := Vector3(1.8, 0, 0)
		for p in [a - w, a + w, b - w, a + w, b + w, b - w]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(p)
	Clay.mesh_node(self, surface.commit(), Vector3.ZERO, path_mat)
	# A round rehearsal clearing subtly blends into the winding trail.
	Clay.cylinder(self, Vector3(0, -0.022, 0), 4.7, 0.02, path_mat)

func _tree(at: Vector3, size: float, conifer: bool) -> void:
	var tree := Node3D.new()
	add_child(tree)
	tree.position = at
	Clay.cylinder(tree, Vector3(0, size * 1.25, 0), 0.25 * size, size * 2.5, bark, 0.17 * size)
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.3 * size
	trunk.height = 2.7 * size
	Clay.collider(tree, Vector3(0, size * 1.35, 0), trunk)
	var mat: Material = foliage[rng.randi_range(0, foliage.size() - 1)]
	if conifer:
		for i in range(3):
			# Overlapping rounded cones, capped by clay-like ovoid tips.
			var radius := (1.25 - i * 0.27) * size
			Clay.cylinder(tree, Vector3(0, (2.0 + i * 0.75) * size, 0), radius, 1.8 * size, mat, 0.12 * size)
			Clay.ellipsoid(tree, Vector3(0, (2.85 + i * 0.75) * size, 0), Vector3.ONE * 0.28 * size, mat)
	else:
		Clay.ellipsoid(tree, Vector3(0, 3.1, 0) * size, Vector3(2.65, 2.8, 2.5) * size, mat)
		Clay.ellipsoid(tree, Vector3(-0.65, 2.65, 0.2) * size, Vector3(1.8, 1.9, 1.85) * size, mat)
		Clay.ellipsoid(tree, Vector3(0.6, 2.9, 0.3) * size, Vector3(1.9, 2.2, 1.85) * size, mat)
	Clay.ellipsoid(tree, Vector3(0, 0.08, 0), Vector3(1.3, 0.22, 1.2) * size, foliage[1])

func _bush(at: Vector3, size: float) -> void:
	for i in range(3):
		Clay.ellipsoid(self, at + Vector3((i - 1) * size * 0.4, size * 0.35, 0), Vector3(0.95, 0.85, 0.9) * size, foliage[(i + 1) % foliage.size()])

func _mushrooms(at: Vector3) -> void:
	var cream := Clay.material(Color("f2e3be"))
	var cap := Clay.material(Color("c88f78"))
	for i in range(3):
		var p := at + Vector3(i * 0.24, 0, sin(i * 2.0) * 0.25)
		var s := 0.6 + i * 0.17
		Clay.cylinder(self, p + Vector3(0, 0.18, 0) * s, 0.055 * s, 0.36 * s, cream)
		Clay.ellipsoid(self, p + Vector3(0, 0.34, 0) * s, Vector3(0.48, 0.24, 0.48) * s, cap)
		Clay.ellipsoid(self, p + Vector3(0.06, 0.445, 0.03) * s, Vector3(0.09, 0.02, 0.08) * s, cream)

func _grass(at: Vector3) -> void:
	for i in range(3):
		var leaf := Clay.ellipsoid(self, at + Vector3(i * 0.09, 0.12, 0), Vector3(0.08, 0.35, 0.1), foliage[1])
		leaf.rotation.z = (i - 1) * 0.35
	if rng.randf() < 0.3:
		Clay.ellipsoid(self, at + Vector3(0.1, 0.29, 0), Vector3(0.16, 0.1, 0.16), Clay.material(Color("f4e1a0")))

func _sign(at: Vector3) -> void:
	var sign_node := Node3D.new()
	add_child(sign_node)
	sign_node.position = at
	sign_node.rotation.y = -0.25
	Clay.cylinder(sign_node, Vector3(0, 0.7, 0), 0.09, 1.4, bark)
	Clay.rounded_box(sign_node, Vector3(0, 1.35, 0), Vector3(1.6, 0.66, 0.16), 0.07, Clay.material(Color("eee1b9")))
	var label := Label3D.new()
	label.text = "QUZU\nORMANI"
	label.font_size = 44
	label.pixel_size = 0.004
	label.modulate = Color("536951")
	label.outline_size = 0
	label.position = Vector3(0, 1.35, 0.09)
	sign_node.add_child(label)
