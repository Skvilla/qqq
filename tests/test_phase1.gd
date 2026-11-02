extends SceneTree
## Run with: godot --headless --path . --fixed-fps 60 --script tests/test_phase1.gd

var failures := 0
var checks := 0
var studio: Node3D
var truck: QuzuTruck
var recorder: TakeRecorder

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func tick(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	studio = load("res://scenes/studio.tscn").instantiate()
	root.add_child(studio)
	truck = studio.truck
	recorder = studio.recorder
	await tick(15)
	check(truck.wheels.size() == 4, "Procedural truck has four wheels")
	check(truck.is_on_floor(), "Truck rests on the forest floor")
	check(studio.get_node("Forest").get_child_count() > 100, "Forest scenery is instantiated")
	check(studio.rig.camera.current, "Studio camera is active")
	check(studio.ui.timeline != null, "Studio transport UI is available")
	for i in range(4):
		await key([KEY_1, KEY_2, KEY_3, KEY_4][i])
		check(truck.expression == QuzuTruck.EXPRESSIONS[i], "Keyboard expression: " + QuzuTruck.EXPRESSIONS[i])
		var visible_faces := 0
		for face in truck.faces.values():
			if face.visible:
				visible_faces += 1
		check(visible_faces == 1, "Only the selected face is visible")
	await key(KEY_HOME)
	await tick(3)
	var start := truck.position
	await key(KEY_R)
	check(recorder.state == "recording", "R starts a real recording")
	Input.action_press("drive_forward")
	await tick(45)
	Input.action_press("steer_right", 0.55)
	await key(KEY_2)
	await tick(30)
	Input.action_release("drive_forward")
	Input.action_release("steer_right")
	await key(KEY_3)
	await tick(20)
	await key(KEY_R)
	check(recorder.state == "idle", "R stops recording")
	check(truck.position.distance_to(start) > 2.0, "Drive input moves the truck in physics")
	check(absf(angle_difference(truck.rotation.y, PI)) > 0.2, "Steering changes heading")
	check(recorder.frames.size() > 90 and recorder.duration > 1.5, "Physics samples carry elapsed timestamps")
	var expressions: Array = []
	for frame in recorder.frames:
		if frame.expression not in expressions:
			expressions.append(frame.expression)
	check("Happy" in expressions and "Sad" in expressions, "Recording captures expression changes")
	check(recorder.save_take("user://tests/roundtrip.json"), "Take writes to a real JSON file")
	check(recorder.save_take("user://tests/roundtrip.json"), "Atomic save can replace an existing take")
	var recorded_frames := recorder.frames.duplicate(true)
	var recorded_duration := recorder.duration
	await key(KEY_HOME)
	check(recorder.load_take("user://tests/roundtrip.json"), "Take loads from disk")
	check(recorder.frames.size() == recorded_frames.size(), "Round trip preserves all samples")
	check(is_equal_approx(recorder.duration, recorded_duration), "Round trip preserves duration")
	recorder.set_physics_process(false)
	studio.set_physics_process(false)
	truck.set_physics_process(false)
	check(recorder.play(), "Loaded take enters playback")
	check(not truck.drive_enabled, "Playback owns the vehicle transform")
	for sample_index in [0, 25, 65, recorded_frames.size() - 1]:
		var sample: Dictionary = recorded_frames[sample_index]
		recorder.seek(sample.t)
		check(truck.position.distance_to(Vector3(sample.p[0], sample.p[1], sample.p[2])) < 0.0001, "Replay reproduces position at sample %d" % sample_index)
		check(truck.quaternion.angle_to(Quaternion(sample.q[0], sample.q[1], sample.q[2], sample.q[3]).normalized()) < 0.001, "Replay reproduces rotation at sample %d" % sample_index)
		check(truck.expression == sample.expression, "Replay reproduces expression at sample %d" % sample_index)
	var a: Dictionary = recorded_frames[20]
	var b: Dictionary = recorded_frames[21]
	recorder.seek((a.t + b.t) * 0.5)
	var midpoint := (Vector3(a.p[0], a.p[1], a.p[2]) + Vector3(b.p[0], b.p[1], b.p[2])) * 0.5
	check(truck.position.distance_to(midpoint) < 0.0001, "Playback interpolates between samples")
	recorder.advance(recorded_duration + 1.0)
	check(recorder.state == "idle" and is_equal_approx(recorder.playhead, recorder.duration), "Playback stops exactly on the last sample")
	var original := recorder.frames.duplicate(true)
	var broken := FileAccess.open("user://tests/broken.json", FileAccess.WRITE)
	broken.store_string("{ broken")
	broken.close()
	check(not recorder.load_take("user://tests/broken.json"), "Malformed JSON is rejected")
	check(recorder.frames == original, "Failed load preserves the current take")
	check(not recorder.load_take("user://tests/missing.json"), "Missing file reports failure")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://tests/roundtrip.json"))
	for fault in ["version", "timestamp", "expression", "quaternion", "position", "duration"]:
		var invalid := data.duplicate(true)
		match fault:
			"version": invalid.version = 999
			"timestamp": invalid.frames[1].t = -1
			"expression": invalid.frames[1].expression = "Unknown"
			"quaternion": invalid.frames[1].q = [0, 0, 0, 0]
			"position": invalid.frames[1].p = [0, 0]
			"duration": invalid.duration = 99999
		check(not TakeRecorder.validate_take(invalid).is_empty(), "Schema rejects invalid " + fault)
	recorder.build_demo()
	check(recorder.frames.size() == 601 and is_equal_approx(recorder.duration, 10.0), "Demo is exactly 10 seconds at 60 Hz")
	for i in range(4):
		recorder.seek(i * 2.5 + 0.1)
		check(truck.expression == QuzuTruck.EXPRESSIONS[i], "Demo includes " + QuzuTruck.EXPRESSIONS[i])
	check(recorder.save_take("user://tests/demo.json"), "Generated demo saves as JSON")
	check(recorder.load_take("user://tests/demo.json"), "Generated demo passes schema validation")
	check(recorder.load_take("res://examples/forest_demo.json"), "Bundled example loads from the repository")
	for fps in [30, 60, 144]:
		recorder.play()
		for i in range(fps * 10 + 1):
			recorder.advance(1.0 / fps)
		check(recorder.state == "idle" and is_equal_approx(recorder.playhead, 10.0), "Demo completes at %d playback updates/sec" % fps)
	recorder.loop = true
	recorder.play()
	recorder.advance(10.25)
	check(recorder.state == "playing" and is_equal_approx(recorder.playhead, 0.25), "Loop wraps without losing leftover time")
	recorder.loop = false
	recorder.stop()
	recorder.playback_speed = 0.5
	recorder.play()
	recorder.advance(2.0)
	check(is_equal_approx(recorder.playhead, 1.0), "Playback speed controls elapsed time")
	recorder.stop()
	# Exercise UI signal wiring and the free camera without moving the actor.
	studio.set_physics_process(true)
	truck.set_physics_process(true)
	studio.ui.camera_requested.emit()
	await tick(2)
	check(studio.rig.free_mode and not truck.drive_enabled, "Free camera disables truck driving")
	var camera_start: Vector3 = studio.rig.camera.position
	var truck_start := truck.position
	Input.action_press("drive_forward")
	await tick(20)
	Input.action_release("drive_forward")
	check(studio.rig.camera.position.distance_to(camera_start) > 0.5, "WASD moves the free camera")
	check(truck.position.distance_to(truck_start) < 0.001, "Free-camera input leaves truck in place")
	await key(KEY_C)
	await tick(2)
	check(not studio.rig.free_mode and truck.drive_enabled, "C restores follow camera and driving")
	studio.ui.filename.grab_focus()
	await tick(2)
	check(not truck.drive_enabled, "Typing a filename cannot drive the truck")
	studio.ui.filename.release_focus()
	# Synthetic standardized joypad events validate bindings, not physical hardware.
	for pair in [[JOY_BUTTON_X, "Neutral"], [JOY_BUTTON_A, "Happy"], [JOY_BUTTON_B, "Sad"], [JOY_BUTTON_Y, "Surprised"]]:
		var joy := InputEventJoypadButton.new()
		joy.device = 0
		joy.button_index = pair[0]
		joy.pressed = true
		Input.parse_input_event(joy)
		await process_frame
		check(truck.expression == pair[1], "PlayStation face button selects " + pair[1])
		joy.pressed = false
		Input.parse_input_event(joy)
	await key(KEY_HOME)
	await tick(15)
	var joy_start := truck.position
	var axis_event := InputEventJoypadMotion.new()
	axis_event.device = 0
	axis_event.axis = JOY_AXIS_LEFT_Y
	axis_event.axis_value = -0.85
	Input.parse_input_event(axis_event)
	await tick(40)
	axis_event.axis_value = 0.0
	Input.parse_input_event(axis_event)
	check(truck.position.distance_to(joy_start) > 0.6, "Synthetic left-stick input drives the truck")
	# A real collision must stop the vehicle instead of driving through set props.
	await key(KEY_HOME)
	truck.position = Vector3(0, 0.05, 0)
	truck.rotation.y = 0
	var obstacle := BoxShape3D.new()
	obstacle.size = Vector3(6, 3, 0.4)
	var wall := Clay.collider(studio, Vector3(0, 1, -3), obstacle)
	Input.action_press("drive_forward")
	await tick(100)
	Input.action_release("drive_forward")
	check(truck.position.z > -1.7, "Solid scenery blocks forward motion")
	wall.queue_free()
	print("PHASE1_TEST_RESULT checks=%d failed=%d" % [checks, failures])
	studio.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
