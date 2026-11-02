class_name StudioInput
extends RefCounted
## Godot's standardized joypad indices: Xbox A/B/X/Y = PS Cross/Circle/Square/Triangle.

static func setup() -> void:
	key_action("drive_forward", [KEY_W, KEY_UP])
	key_action("drive_back", [KEY_S, KEY_DOWN])
	key_action("steer_left", [KEY_A, KEY_LEFT])
	key_action("steer_right", [KEY_D, KEY_RIGHT])
	key_action("brake", [KEY_SPACE])
	key_action("face_neutral", [KEY_1])
	key_action("face_happy", [KEY_2])
	key_action("face_sad", [KEY_3])
	key_action("face_surprised", [KEY_4])
	key_action("record", [KEY_R])
	key_action("replay", [KEY_P])
	key_action("stop", [KEY_ESCAPE])
	key_action("camera_mode", [KEY_C])
	key_action("demo", [KEY_F5])
	key_action("reset", [KEY_HOME])
	key_action("camera_up", [KEY_E])
	key_action("camera_down", [KEY_Q])
	key_action("camera_fast", [KEY_SHIFT])
	key_action("save_take", [KEY_F6])
	key_action("load_take", [KEY_F7])
	axis("drive_forward", JOY_AXIS_LEFT_Y, -1.0)
	axis("drive_back", JOY_AXIS_LEFT_Y, 1.0)
	axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	for pair in [["face_happy", JOY_BUTTON_A], ["face_sad", JOY_BUTTON_B], ["face_neutral", JOY_BUTTON_X], ["face_surprised", JOY_BUTTON_Y], ["record", JOY_BUTTON_LEFT_SHOULDER], ["replay", JOY_BUTTON_RIGHT_SHOULDER], ["camera_mode", JOY_BUTTON_RIGHT_STICK], ["demo", JOY_BUTTON_START], ["stop", JOY_BUTTON_BACK], ["brake", JOY_BUTTON_LEFT_STICK], ["camera_up", JOY_BUTTON_DPAD_UP], ["camera_down", JOY_BUTTON_DPAD_DOWN]]:
		var event := InputEventJoypadButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)

static func key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.2)
	for code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event(action, event)

static func axis(action: String, index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	InputMap.action_add_event(action, event)
