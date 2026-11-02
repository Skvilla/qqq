class_name StudioCamera
extends Node3D

signal mode_changed(free: bool)

var target: QuzuTruck
var camera: Camera3D
var free_mode := false
var yaw := 0.5
var pitch := 0.38
var distance := 8.6
var focus := Vector3(0, 1, 0)
var dragging := false

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 48
	camera.near = 0.1
	camera.far = 120
	add_child(camera)
	camera.current = true
	_update_follow(1.0)

func toggle_mode() -> void:
	free_mode = not free_mode
	mode_changed.emit(free_mode)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if dragging else Input.MOUSE_MODE_VISIBLE
		if not free_mode and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(4.0, distance - 0.5)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(17.0, distance + 0.5)
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.004, -0.2, 1.25)
	if event.is_action_pressed("stop"):
		release_mouse()

func release_mouse() -> void:
	dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_mouse()

func _process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var joypads := Input.get_connected_joypads()
	if not joypads.is_empty():
		var stick := Vector2(Input.get_joy_axis(joypads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(joypads[0], JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.18:
			yaw -= stick.x * delta * 1.8
			pitch = clampf(pitch + stick.y * delta * 1.4, -0.2, 1.25)
	if free_mode:
		camera.rotation = Vector3(-pitch, yaw, 0)
		var movement := Vector3(Input.get_axis("steer_left", "steer_right"), Input.get_axis("camera_down", "camera_up"), Input.get_axis("drive_forward", "drive_back"))
		var rate := 12.0 if Input.is_action_pressed("camera_fast") else 5.0
		camera.position += camera.basis * movement.limit_length() * rate * delta
		camera.position.y = clampf(camera.position.y, 0.4, 25.0)
	else:
		_update_follow(delta)

func _update_follow(delta: float) -> void:
	var desired := target.global_position + Vector3(0, 0.95, 0) if is_instance_valid(target) else Vector3(0, 0.95, 0)
	focus = focus.lerp(desired, 1.0 - exp(-delta * 7.0))
	var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var destination := focus + direction * distance
	# Keep the lens in front of solid scenery while orbiting.
	if is_instance_valid(target) and is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(focus, destination)
		query.exclude = [target.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			destination = hit.position + hit.normal * 0.3
	camera.global_position = destination
	camera.look_at(focus)
