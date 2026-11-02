class_name TakeRecorder
extends Node
## Versioned JSON takes. Recording runs after the vehicle's fixed physics tick.
## Playback interpolates position + quaternion; expression events use step sampling.

signal state_changed(state: String)
signal take_changed
signal notice(text: String)

const FORMAT_VERSION := 1
const SAMPLE_RATE := 60
const MAX_DURATION := 600.0
const MAX_FILE_BYTES := 16 * 1024 * 1024
const DEFAULT_PATH := "user://takes/forest_take.json"

var truck: QuzuTruck
var state := "idle"
var frames: Array = []
var duration := 0.0
var playhead := 0.0
var loop := false
var playback_speed := 1.0
var last_error := ""
var _sample_index := 0

func _ready() -> void:
	process_physics_priority = 10

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_instance_valid(truck):
		return
	if state == "recording":
		playhead = minf(playhead + delta, MAX_DURATION)
		duration = playhead
		frames.append(_capture(playhead))
		if playhead >= MAX_DURATION:
			stop()
			notice.emit("10 dakikalık kayıt sınırına ulaşıldı.")
	elif state == "playing":
		playhead += delta * playback_speed
		if playhead >= duration:
			if loop and duration > 0.0:
				playhead = fmod(playhead, duration)
				_sample_index = 0
			else:
				playhead = duration
				apply_at(playhead)
				_set_state("idle")
				return
		apply_at(playhead)

func start_recording() -> void:
	stop()
	frames = [_capture(0.0)]
	duration = 0.0
	playhead = 0.0
	_sample_index = 0
	_set_state("recording")
	take_changed.emit()

func stop() -> void:
	if state == "recording":
		# Capture expression/pose changes made between the last two physics ticks.
		frames[-1] = _capture(playhead)
	_set_state("idle")
	take_changed.emit()

func play() -> bool:
	if state == "recording":
		stop()
	if frames.size() < 2 or duration <= 0.0:
		return _fail("Önce bir hareket kaydet veya 10 sn demo oluştur.")
	playhead = 0.0
	_sample_index = 0
	_set_state("playing")
	apply_at(0.0)
	return true

func seek(time: float) -> void:
	if frames.is_empty() or state == "recording":
		return
	playhead = clampf(time, 0.0, duration)
	_sample_index = 0
	apply_at(playhead)

func apply_at(time: float) -> void:
	if frames.is_empty() or not is_instance_valid(truck):
		return
	var t := clampf(time, 0.0, duration)
	if _sample_index >= frames.size() or float(frames[_sample_index]["t"]) > t:
		_sample_index = 0
	while _sample_index < frames.size() - 1 and float(frames[_sample_index + 1]["t"]) <= t:
		_sample_index += 1
	var a: Dictionary = frames[_sample_index]
	var b: Dictionary = frames[mini(_sample_index + 1, frames.size() - 1)]
	var span := float(b["t"]) - float(a["t"])
	var blend := clampf((t - float(a["t"])) / span, 0.0, 1.0) if span > 0.0 else 0.0
	truck.global_position = _vector(a["p"]).lerp(_vector(b["p"]), blend)
	truck.quaternion = _quaternion(a["q"]).slerp(_quaternion(b["q"]), blend)
	if truck.expression != a["expression"]:
		truck.set_expression(a["expression"])

func save_take(path: String = DEFAULT_PATH) -> bool:
	if frames.size() < 2:
		return _fail("Kaydedilecek performans yok.")
	if state == "recording":
		stop()
	var payload := {"format": "quzu-take", "version": FORMAT_VERSION, "sample_rate": SAMPLE_RATE, "duration": duration, "frames": frames}
	var folder := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return _fail("Kayıt klasörü oluşturulamadı.")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _fail("JSON dosyası yazılamadı: %s" % error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(payload, "\t", false, true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _fail("JSON yazma işlemi tamamlanamadı.")
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if result != OK:
		return _fail("JSON dosyası taşınamadı: %s" % error_string(result))
	notice.emit("JSON kaydedildi · " + path.get_file())
	return true

func load_take(path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Kayıt bulunamadı: " + path.get_file())
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return _fail("Kayıt dosyası 16 MB sınırını aşıyor.")
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return _fail("Geçersiz JSON · satır %d" % json.get_error_line())
	var problem := validate_take(json.data)
	if not problem.is_empty():
		return _fail(problem)
	# Commit only after every sample passes validation; a bad file keeps the take.
	stop()
	frames = json.data["frames"]
	duration = float(json.data["duration"])
	playhead = 0.0
	_sample_index = 0
	apply_at(0.0)
	take_changed.emit()
	notice.emit("JSON yüklendi · " + path.get_file())
	return true

static func validate_take(data: Variant) -> String:
	if not data is Dictionary:
		return "Kayıt kökü bir JSON nesnesi olmalı."
	if data.get("format") != "quzu-take" or data.get("version") != FORMAT_VERSION:
		return "Desteklenmeyen kayıt biçimi veya sürümü."
	if data.get("sample_rate") != SAMPLE_RATE:
		return "Desteklenmeyen örnekleme hızı."
	if not _number(data.get("duration")) or float(data["duration"]) <= 0 or float(data["duration"]) > MAX_DURATION:
		return "Geçersiz kayıt süresi."
	var samples: Variant = data.get("frames")
	if not samples is Array or samples.size() < 2 or samples.size() > SAMPLE_RATE * MAX_DURATION + 2:
		return "Geçersiz örnek sayısı."
	var previous := -1.0
	for sample in samples:
		if not sample is Dictionary or not _number(sample.get("t")):
			return "Geçersiz zaman damgası."
		var time := float(sample["t"])
		if time <= previous or time < 0 or time > float(data["duration"]) + 0.0001:
			return "Zaman damgaları artan sırada olmalı."
		previous = time
		for key in ["p", "q"]:
			var values: Variant = sample.get(key)
			var expected := 3 if key == "p" else 4
			if not values is Array or values.size() != expected:
				return "Geçersiz konum veya dönüş verisi."
			for value in values:
				if not _number(value) or absf(float(value)) > 10000.0:
					return "Sonlu bir konum/dönüş değeri gerekli."
		var q: Array = sample["q"]
		var length := Quaternion(q[0], q[1], q[2], q[3]).length()
		if absf(length - 1.0) > 0.02:
			return "Dönüş quaternion'u normalize olmalı."
		if sample.get("expression") not in QuzuTruck.EXPRESSIONS:
			return "Bilinmeyen yüz ifadesi."
	if absf(float(samples[0]["t"])) > 0.00001 or absf(previous - float(data["duration"])) > 0.0001:
		return "Kayıt sıfırdan başlamalı ve süreyle bitmeli."
	return ""

func build_demo() -> void:
	stop()
	frames = []
	duration = 10.0
	for i in range(601):
		var t := float(i) / SAMPLE_RATE
		# Eased start and finish, with a 3/4 circle entirely inside the clearing.
		var u := t / duration
		var eased := u * u * (3.0 - 2.0 * u)
		var angle := eased * TAU * 0.75
		var p := Vector3(sin(angle) * 2.2, -0.03, cos(angle) * 2.2 - 0.4)
		var q := Quaternion(Vector3.UP, angle - PI * 0.5)
		var face: String = QuzuTruck.EXPRESSIONS[mini(int(t / 2.5), 3)]
		frames.append({"t": t, "p": [p.x, p.y, p.z], "q": [q.x, q.y, q.z, q.w], "expression": face})
	playhead = 0.0
	_sample_index = 0
	take_changed.emit()
	notice.emit("10 saniyelik orman performansı hazır.")

func _capture(time: float) -> Dictionary:
	var p := truck.global_position
	var q := truck.quaternion.normalized()
	return {"t": time, "p": [p.x, p.y, p.z], "q": [q.x, q.y, q.z, q.w], "expression": truck.expression}

func _set_state(value: String) -> void:
	state = value
	if is_instance_valid(truck):
		truck.drive_enabled = state != "playing"
	state_changed.emit(state)

func _fail(message: String) -> bool:
	last_error = message
	notice.emit(message)
	return false

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func _quaternion(value: Array) -> Quaternion:
	return Quaternion(value[0], value[1], value[2], value[3]).normalized()
