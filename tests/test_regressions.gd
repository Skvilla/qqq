extends SceneTree
## Boundary and user-flow regressions found during the Phase 1 audit.

var checks := 0
var failures := 0
var studio: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func write_invalid(data: Variant) -> void:
	var file := FileAccess.open("user://tests/invalid-type.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func expect_rejected(data: Variant, description: String) -> void:
	var recorder: TakeRecorder = studio.recorder
	recorder.build_demo()
	recorder.play()
	var original := recorder.frames.duplicate(true)
	write_invalid(data)
	var rejected := not recorder.load_take("user://tests/invalid-type.json")
	check(rejected and recorder.state == "playing" and recorder.frames == original, description)

func _run() -> void:
	studio = load("res://scenes/studio.tscn").instantiate()
	root.add_child(studio)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var recorder: TakeRecorder = studio.recorder
	recorder.set_physics_process(false)
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://examples/forest_demo.json"))
	# These must be rejected by the disk-loading path, without aborting validation
	# with a GDScript type error or stopping/replacing the current performance.
	for field in ["format", "version", "sample_rate"]:
		for value in [null, true, [], {}, "invalid", 1e308]:
			var invalid := valid.duplicate(true)
			invalid[field] = value
			expect_rejected(invalid,
				"Invalid %s type %d is rejected without changing playback" % [field, typeof(value)])
	for field in ["format", "version", "sample_rate", "duration", "frames"]:
		var invalid := valid.duplicate(true)
		invalid.erase(field)
		expect_rejected(invalid,
			"Missing field is rejected: " + field)
	for root_value in [null, true, [], "invalid", 42]:
		expect_rejected(root_value,
			"Wrong JSON root type is rejected: %d" % typeof(root_value))
	for field in ["t", "p", "q", "expression"]:
		for value in [null, true, {}, "invalid"]:
			var invalid := valid.duplicate(true)
			invalid.frames[1][field] = value
			expect_rejected(invalid,
				"Wrong sample.%s type %d is rejected" % [field, typeof(value)])
	# Click ordering: a toggle button changes state before emitting `pressed`.
	recorder.build_demo()
	recorder.play()
	await process_frame
	await process_frame
	check(studio.ui.face_buttons.values().all(func(button): return button.disabled),
		"Expression buttons are disabled while playback owns the face")
	var happy: Button = studio.ui.face_buttons["Happy"]
	happy.button_pressed = true
	happy.pressed.emit()
	await process_frame
	var selected: Array = []
	for value in studio.ui.face_buttons:
		if studio.ui.face_buttons[value].button_pressed:
			selected.append(value)
	check(selected == [studio.truck.expression], "Ignored face change cannot leave two UI expressions selected")
	recorder.stop()
	await process_frame
	await process_frame
	check(studio.ui.face_buttons.values().all(func(button): return not button.disabled),
		"Expression controls return after playback stops")
	happy.button_pressed = true
	happy.pressed.emit()
	check(studio.truck.expression == "Happy", "Expression button still changes the face when idle")
	check(studio.ui._time(59.96) == "01:00.0", "Time display carries rounded seconds into minutes")
	check(studio.ui._time(119.96) == "02:00.0", "Time display carries at later minute boundaries")
	check(studio.ui._time(9.94) == "00:09.9", "Time display preserves ordinary tenths")
	print("REGRESSION_TEST_RESULT checks=%d failed=%d" % [checks, failures])
	studio.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
