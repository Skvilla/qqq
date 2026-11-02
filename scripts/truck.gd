class_name QuzuTruck
extends CharacterBody3D

signal expression_changed(expression: String)

const EXPRESSIONS := ["Neutral", "Happy", "Sad", "Surprised"]
const MAX_SPEED := 4.2
const REVERSE_SPEED := 2.4
const ACCELERATION := 5.5
const TURN_SPEED := 1.65

var expression := "Neutral"
var drive_enabled := true
var speed := 0.0
var wheel_turn := 0.0
var visual: Node3D
var faces: Dictionary = {}
var wheels: Array[Node3D] = []
var previous_position := Vector3.ZERO
var animation_time := 0.0

func _ready() -> void:
	_build_model()
	previous_position = global_position

func _physics_process(delta: float) -> void:
	if drive_enabled:
		var throttle := Input.get_axis("drive_back", "drive_forward")
		var steering := Input.get_axis("steer_left", "steer_right")
		drive(throttle, steering, delta)
	else:
		velocity = Vector3.ZERO
		speed = 0.0

func drive(throttle: float, steering: float, delta: float) -> void:
	var desired := throttle * (MAX_SPEED if throttle >= 0.0 else REVERSE_SPEED)
	speed = move_toward(speed, desired, ACCELERATION * delta)
	if Input.is_action_pressed("brake"):
		speed = move_toward(speed, 0.0, ACCELERATION * 3.0 * delta)
	# Turn in place is intentional: easier to stage a performance with a gamepad.
	rotate_y(-steering * TURN_SPEED * delta * (1.0 if speed >= -0.1 else -1.0))
	var direction := -global_basis.z
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.8 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if get_slide_collision_count() > 0 and Vector2(velocity.x, velocity.z).length() < absf(speed) * 0.3:
		speed = move_toward(speed, 0.0, ACCELERATION * delta)

func _process(delta: float) -> void:
	animation_time += delta
	var displacement := global_position - previous_position
	var distance := displacement.dot(-global_basis.z)
	wheel_turn -= distance / 0.37
	for wheel in wheels:
		wheel.rotation.x = wheel_turn
	var motion := clampf(displacement.length() / maxf(delta, 0.001) / MAX_SPEED, 0.0, 1.0)
	visual.position.y = sin(animation_time * 9.0) * 0.022 * motion
	visual.rotation.z = sin(animation_time * 4.5) * 0.015 * motion
	previous_position = global_position

func set_expression(value: String) -> void:
	if value not in EXPRESSIONS:
		return
	expression = value
	for key in faces:
		faces[key].visible = key == value
	expression_changed.emit(value)

func reset_pose() -> void:
	global_position = Vector3(0, 0.05, 0)
	rotation = Vector3(0, PI, 0)
	velocity = Vector3.ZERO
	speed = 0.0
	wheel_turn = 0.0
	previous_position = global_position
	set_expression("Neutral")

func _build_model() -> void:
	var yellow: Material = preload("res://materials/clay_yellow.tres")
	var cream: Material = preload("res://materials/clay_cream.tres")
	var ink := Clay.material(Color("343d39"))
	var pink := Clay.material(Color("eaa997"))
	var tire := Clay.material(Color("555e59"))
	var window := Clay.material(Color("91b8b1"))
	visual = Node3D.new()
	visual.name = "ClayBody"
	add_child(visual)
	Clay.rounded_box(visual, Vector3(0, 0.68, 0), Vector3(1.82, 0.55, 2.55), 0.22, yellow)
	Clay.rounded_box(visual, Vector3(0, 1.25, -0.62), Vector3(1.8, 1.35, 1.33), 0.28, yellow)
	Clay.rounded_box(visual, Vector3(0, 1.82, -0.58), Vector3(1.86, 0.2, 1.3), 0.09, cream)
	# Open cargo bed, with raised rounded sides and two soft parcels.
	Clay.rounded_box(visual, Vector3(0, 0.93, 0.68), Vector3(1.68, 0.17, 1.05), 0.08, cream)
	for x in [-0.79, 0.79]:
		Clay.rounded_box(visual, Vector3(x, 1.12, 0.65), Vector3(0.2, 0.62, 1.3), 0.09, yellow)
	Clay.rounded_box(visual, Vector3(0, 1.12, 1.22), Vector3(1.76, 0.62, 0.2), 0.09, yellow)
	Clay.ellipsoid(visual, Vector3(-0.3, 1.16, 0.65), Vector3(0.62, 0.42, 0.66), Clay.material(Color("b7caa6")))
	Clay.ellipsoid(visual, Vector3(0.3, 1.12, 0.85), Vector3(0.6, 0.36, 0.53), cream)
	for x in [-0.91, 0.91]:
		Clay.rounded_box(visual, Vector3(x, 1.47, -0.55), Vector3(0.06, 0.47, 0.67), 0.025, window)
		Clay.rounded_box(visual, Vector3(x * 1.03, 1.1, -0.45), Vector3(0.07, 0.07, 0.25), 0.03, cream)
		Clay.ellipsoid(visual, Vector3(x * 1.12, 1.34, -1.02), Vector3(0.18, 0.24, 0.18), yellow)
	Clay.rounded_box(visual, Vector3(0, 1.43, -1.28), Vector3(1.51, 0.81, 0.17), 0.08, cream)
	Clay.rounded_box(visual, Vector3(0, 0.67, -1.35), Vector3(1.78, 0.2, 0.23), 0.09, cream)
	for x in [-0.61, 0.61]:
		Clay.ellipsoid(visual, Vector3(x, 0.91, -1.29), Vector3(0.28, 0.23, 0.13), cream)
		Clay.ellipsoid(visual, Vector3(x * 0.89, 1.29, -1.385), Vector3(0.24, 0.12, 0.045), pink)
	for x in [-0.96, 0.96]:
		for z in [-0.8, 0.81]:
			var wheel := Node3D.new()
			wheel.name = "Wheel%d" % wheels.size()
			visual.add_child(wheel)
			wheel.position = Vector3(x, 0.41, z)
			wheels.append(wheel)
			Clay.ellipsoid(wheel, Vector3.ZERO, Vector3(0.38, 0.79, 0.79), tire)
			Clay.ellipsoid(wheel, Vector3(signf(x) * 0.18, 0, 0), Vector3(0.07, 0.44, 0.44), cream)
			Clay.ellipsoid(wheel, Vector3(signf(x) * 0.23, 0, 0), Vector3(0.04, 0.18, 0.18), yellow)
	for value in EXPRESSIONS:
		_build_face(value, ink)
	set_expression(expression)

func _build_face(value: String, ink: Material) -> void:
	var face := Node3D.new()
	face.name = value
	visual.add_child(face)
	faces[value] = face
	for side in [-1.0, 1.0]:
		var eye := Clay.ellipsoid(face, Vector3(side * 0.32, 1.54, -1.39), Vector3(0.14, 0.21, 0.08), ink)
		if value == "Happy":
			eye.scale.y *= 0.72
		if value == "Surprised":
			eye.scale *= 1.23
		Clay.ellipsoid(face, Vector3(side * 0.32 - 0.02, 1.58, -1.435), Vector3(0.037, 0.042, 0.015), Clay.material(Color("fff7df")))
		var brow_y := 1.76 if value == "Surprised" else 1.73
		var slope: float = -side * 0.065 if value == "Sad" else side * 0.015
		Clay.tube(face, PackedVector3Array([
			Vector3(side * 0.32 - 0.095, brow_y - slope, -1.38),
			Vector3(side * 0.32 + 0.095, brow_y + slope, -1.38)]), 0.023, ink)
	if value == "Surprised":
		Clay.ellipsoid(face, Vector3(0, 1.24, -1.4), Vector3(0.18, 0.24, 0.06), ink)
	else:
		var points := PackedVector3Array()
		for i in range(13):
			var t := float(i) / 6.0 - 1.0
			var y := 1.22
			if value == "Happy":
				y += 0.14 * t * t - 0.04
			elif value == "Sad":
				y += 0.04 - 0.1 * t * t
			else:
				y += 0.025 * t * t
			points.append(Vector3(t * 0.22, y, -1.4))
		Clay.tube(face, points, 0.026, ink)
