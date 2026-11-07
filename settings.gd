extends Node
## SHADOW SIPHON - Saved settings (autoload "Settings"): the Music and SFX volumes (0..1), kept in user://settings.cfg.
## Buses come from default_bus_layout.tres (Master > Music, SFX): every music player is on Music, every one-shot sound on SFX.

const FILE := "user://settings.cfg"

var _volume := {"Music": 1.0, "SFX": 1.0}
var _save_timer := Timer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # the sliders also work while the game is paused
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		for bus in _volume:
			_volume[bus] = clampf(float(cfg.get_value("audio", bus.to_lower(), 1.0)), 0.0, 1.0)
	for bus in _volume:
		_apply(bus)


func _exit_tree() -> void:
	if not _save_timer.is_stopped():
		save()                                       # a change made just before quitting


func get_volume(bus: String) -> float:
	return _volume[bus]


func set_volume(bus: String, value: float) -> void:
	_volume[bus] = clampf(value, 0.0, 1.0)
	_apply(bus)
	_save_timer.start()                              # written once the slider stops moving


func save() -> void:
	var cfg := ConfigFile.new()
	for bus in _volume:
		cfg.set_value("audio", bus.to_lower(), _volume[bus])
	cfg.save(FILE)


func _apply(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, _volume[bus] <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(_volume[bus], 0.001)))
