extends Node3D

@onready var truck: QuzuTruck = $Truck
@onready var rig: StudioCamera = $StudioCamera
var recorder: TakeRecorder
var ui: StudioUI
var _demo_cli := false
var _quit_after_demo := false

func _ready() -> void:
	StudioInput.setup()
	process_physics_priority = -10
	rig.target = truck
	recorder = TakeRecorder.new()
	recorder.name = "TakeRecorder"
	recorder.truck = truck
	add_child(recorder)
	ui = StudioUI.new()
	ui.name = "StudioUI"
	add_child(ui)
	ui.record_requested.connect(_record)
	ui.stop_requested.connect(_stop)
	ui.play_requested.connect(recorder.play)
	ui.demo_requested.connect(_demo)
	ui.save_requested.connect(_save)
	ui.load_requested.connect(_load)
	ui.expression_requested.connect(_expression)
	ui.camera_requested.connect(rig.toggle_mode)
	ui.reset_requested.connect(_reset)
	ui.seek_requested.connect(recorder.seek)
	ui.loop_changed.connect(func(value: bool): recorder.loop = value)
	ui.speed_changed.connect(func(value: float): recorder.playback_speed = value)
	recorder.notice.connect(ui.notify)
	recorder.state_changed.connect(_state_changed)
	truck.expression_changed.connect(ui.set_expression)
	rig.mode_changed.connect(ui.set_camera)
	var args := OS.get_cmdline_user_args()
	_demo_cli = "--demo" in args
	_quit_after_demo = "--quit-after-demo" in args
	if _demo_cli:
		_demo.call_deferred()

func _physics_process(_delta: float) -> void:
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	truck.drive_enabled = recorder.state != "playing" and not rig.free_mode and not typing

func _process(_delta: float) -> void:
	ui.update_transport(recorder.state, recorder.playhead, recorder.duration, recorder.frames.size() > 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	for i in range(4):
		if event.is_action_pressed(["face_neutral", "face_happy", "face_sad", "face_surprised"][i]):
			_expression(QuzuTruck.EXPRESSIONS[i])
	if event.is_action_pressed("record"):
		_record()
	elif event.is_action_pressed("replay"):
		recorder.play()
	elif event.is_action_pressed("stop"):
		_stop()
	elif event.is_action_pressed("camera_mode"):
		rig.toggle_mode()
	elif event.is_action_pressed("demo"):
		_demo()
	elif event.is_action_pressed("reset"):
		_reset()
	elif event.is_action_pressed("save_take"):
		_save(ui.filename.text)
	elif event.is_action_pressed("load_take"):
		_load(ui.filename.text)

func _record() -> void:
	if recorder.state == "recording":
		recorder.stop()
		ui.notify("Kayıt tamamlandı. P ile izle, F6 ile JSON kaydet.")
	else:
		recorder.start_recording()
		ui.notify("Kayıt başladı · Sürüşünü ve yüz ifadelerini kaydediyorum.")

func _stop() -> void:
	recorder.stop()
	rig.release_mouse()

func _demo() -> void:
	recorder.build_demo()
	recorder.save_take("user://takes/demo_10s.json")
	recorder.play()
	ui.notify("10 sn demo · Neutral → Happy → Sad → Surprised")

func _expression(value: String) -> void:
	if recorder.state != "playing":
		truck.set_expression(value)
	else:
		# A button event may already be queued when playback starts.
		ui.set_expression(truck.expression)

func _reset() -> void:
	recorder.stop()
	truck.reset_pose()
	ui.notify("Quzu başlangıç noktasında.")

func _take_path(value: String) -> String:
	var clean := value.strip_edges().get_basename()
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_çğıöşüÇĞİÖŞÜ-]")
	clean = regex.sub(clean, "_", true)
	if clean.is_empty():
		clean = "forest_take"
	return "user://takes/" + clean.left(48) + ".json"

func _save(value: String) -> void:
	ui.filename.release_focus()
	recorder.save_take(_take_path(value))

func _load(value: String) -> void:
	ui.filename.release_focus()
	recorder.load_take(_take_path(value))

func _state_changed(value: String) -> void:
	if _demo_cli and _quit_after_demo and value == "idle" and recorder.playhead >= 9.999:
		print("DEMO_COMPLETE duration=%.3f samples=%d expression=%s" % [recorder.duration, recorder.frames.size(), truck.expression])
		get_tree().quit(0)
