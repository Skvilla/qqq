class_name StudioUI
extends CanvasLayer

signal record_requested
signal stop_requested
signal play_requested
signal demo_requested
signal save_requested(name: String)
signal load_requested(name: String)
signal expression_requested(value: String)
signal camera_requested
signal reset_requested
signal seek_requested(time: float)
signal loop_changed(value: bool)
signal speed_changed(value: float)

const INK := Color("304a3d")
const MUTED := Color("768373")
const PAPER := Color("f7f4e7")
const GOLD := Color("edd596")

var timeline: HSlider
var time_label: Label
var status_label: Label
var message_label: Label
var face_buttons: Dictionary = {}
var camera_button: Button
var record_button: Button
var play_button: Button
var filename: LineEdit
var _updating := false

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	# Quiet masthead above the stage.
	var header := _panel(root, Vector2(26, 22), Vector2(1388, 78))
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_right = -26
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 22)
	header.add_child(header_row)
	var logo := _label("quzu", 35)
	header_row.add_child(logo)
	var brand := VBoxContainer.new()
	header_row.add_child(brand)
	brand.add_child(_label("S L E E P   S T U D I O", 13))
	brand.add_child(_label("Küçük bir orman, yumuşak hikâyeler.", 14, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	header_row.add_child(_label("PHASE 01  /  ORMAN SETİ", 12, MUTED))
	status_label = _label("●  HAZIR", 14)
	header_row.add_child(status_label)
	# Director's tools stay to one side, leaving the character unobstructed.
	var tools_panel := _panel(root, Vector2(26, 122), Vector2(282, 456))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	tools_panel.add_child(column)
	column.add_child(_label("SAHNE 01   ·   SABAH IŞIĞI", 11, MUTED))
	column.add_child(_label("Orman provası", 26))
	column.add_child(_label("Quzu'nun hikâyesini sen anlat.", 14, MUTED))
	column.add_child(HSeparator.new())
	column.add_child(_label("YÜZ İFADESİ", 12, MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	var titles := ["1  Neutral", "2  Happy", "3  Sad", "4  Surprised"]
	for i in range(4):
		var value: String = QuzuTruck.EXPRESSIONS[i]
		var button := _button(titles[i], func(): expression_requested.emit(value))
		button.custom_minimum_size = Vector2(112, 38)
		button.toggle_mode = true
		grid.add_child(button)
		face_buttons[value] = button
	column.add_child(HSeparator.new())
	camera_button = _button("C   Kamera: Takip", func(): camera_requested.emit())
	column.add_child(camera_button)
	column.add_child(_button("Home   Başlangıca dön", func(): reset_requested.emit()))
	column.add_child(_label("WASD / sol analog    Sürüş\nSağ fare / sağ analog    Bakış\nTekerlek    Yakınlaş / uzaklaş\nSerbest kamera: Q / E    Alçal / yüksel", 13, MUTED))
	# Transport desk, pinned to the bottom and stretched with the viewport.
	var transport := _panel(root, Vector2(26, -212), Vector2(1388, 190))
	transport.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	transport.offset_top = -212
	transport.offset_bottom = -22
	transport.offset_right = -26
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	transport.add_child(rows)
	var heading := HBoxContainer.new()
	rows.add_child(heading)
	heading.add_child(_label("PERFORMANS", 12, MUTED))
	message_label = _label("R ile kaydı başlat · F5 ile 10 saniyelik demoyu izle", 13, MUTED)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(message_label)
	var scrub := HBoxContainer.new()
	rows.add_child(scrub)
	timeline = HSlider.new()
	timeline.min_value = 0
	timeline.max_value = 10
	timeline.step = 0.001
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.focus_mode = Control.FOCUS_NONE
	timeline.value_changed.connect(func(value: float):
		if not _updating:
			seek_requested.emit(value))
	scrub.add_child(timeline)
	time_label = _label("00:00.0 / 00:00.0", 15)
	time_label.custom_minimum_size.x = 160
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scrub.add_child(time_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	rows.add_child(buttons)
	record_button = _button("●  Kayıt  [R]", func(): record_requested.emit(), GOLD)
	buttons.add_child(record_button)
	buttons.add_child(_button("■  Dur  [Esc]", func(): stop_requested.emit()))
	play_button = _button("▶  Oynat  [P]", func(): play_requested.emit())
	buttons.add_child(play_button)
	buttons.add_child(_button("10 sn demo  [F5]", func(): demo_requested.emit()))
	var loop_button := CheckButton.new()
	loop_button.text = "Döngü"
	loop_button.focus_mode = Control.FOCUS_NONE
	loop_button.toggled.connect(func(value: bool): loop_changed.emit(value))
	buttons.add_child(loop_button)
	var speed := OptionButton.new()
	for label_text in ["0.5×", "1×", "1.5×"]:
		speed.add_item(label_text)
	speed.select(1)
	speed.focus_mode = Control.FOCUS_NONE
	speed.item_selected.connect(func(index: int): speed_changed.emit([0.5, 1.0, 1.5][index]))
	buttons.add_child(speed)
	var flexible := Control.new()
	flexible.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(flexible)
	filename = LineEdit.new()
	filename.text = "forest_take"
	filename.placeholder_text = "kayıt_adı"
	filename.custom_minimum_size.x = 155
	filename.max_length = 48
	filename.text_submitted.connect(func(_text: String): filename.release_focus())
	filename.tooltip_text = "Kayıt adı. Enter ile sürüşe dön. Dosyalar user://takes/ içinde saklanır."
	buttons.add_child(filename)
	buttons.add_child(_button("Kaydet  [F6]", func(): save_requested.emit(filename.text)))
	buttons.add_child(_button("Yükle  [F7]", func(): load_requested.emit(filename.text)))
	rows.add_child(_label("PLAYSTATION   Sol analog: sürüş   ·   × Happy   ○ Sad   □ Neutral   △ Surprised   ·   L1 kayıt   R1 oynat   R3 kamera   Options demo", 12, MUTED))
	set_expression("Neutral")

func update_transport(state: String, time: float, length: float, has_take: bool) -> void:
	_updating = true
	timeline.max_value = maxf(length, 0.01)
	timeline.value = time
	timeline.editable = has_take and state != "recording"
	time_label.text = "%s / %s" % [_time(time), _time(length)]
	status_label.text = {"idle": "●  HAZIR", "recording": "●  KAYIT", "playing": "▶  OYNATILIYOR"}[state]
	status_label.modulate = Color("bb664e") if state == "recording" else Color.WHITE
	record_button.text = "■  Kaydı bitir" if state == "recording" else "●  Kayıt  [R]"
	play_button.disabled = not has_take
	for button in face_buttons.values():
		button.disabled = state == "playing"
	_updating = false

func set_expression(value: String) -> void:
	for key in face_buttons:
		face_buttons[key].set_pressed_no_signal(key == value)

func set_camera(free: bool) -> void:
	camera_button.text = "C   Kamera: Serbest" if free else "C   Kamera: Takip"

func notify(text: String) -> void:
	message_label.text = text

func _time(value: float) -> String:
	var tenths := maxi(0, roundi(value * 10.0))
	return "%02d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]

func _button(text: String, action: Callable, color: Color = Color("e6e9da")) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 40
	button.add_theme_stylebox_override("normal", _style(color, 9))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.08), 9))
	button.add_theme_stylebox_override("pressed", _style(GOLD, 9))
	button.pressed.connect(action)
	return button

func _label(text: String, size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel(parent: Control, at: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = size
	var style := _style(PAPER, 16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0.12, 0.2, 0.15, 0.12)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	for node_type in ["Button", "CheckButton", "OptionButton", "LineEdit"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, node_type, INK)
	result.set_stylebox("normal", "LineEdit", _style(Color("eeeddf"), 8))
	result.set_stylebox("normal", "OptionButton", _style(Color("e6e9da"), 8))
	return result
