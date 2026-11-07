extends SceneTree

# Pause menu, How to Play screen, volume sliders, audio buses and saved settings: both levels and the main menu.

var _fails := 0
var st: Node        # the Settings autoload


func _check(label: String, ok: bool, extra := "") -> void:
	print("  ", "ok   " if ok else "FAIL ", label, ("   (" + extra + ")") if extra != "" else "")
	if not ok:
		_fails += 1


func _esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _btn(node: Node, text: String) -> Button:
	for b in node.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(text):
			return b
	return null


# Physics ticks counted by a probe node inside the level during `seconds` (0 while the tree is paused).
func _ticks(probe, seconds: float) -> int:
	var n0: int = probe.n
	await create_timer(seconds).timeout
	return probe.n - n0


func _init() -> void:
	var cfg_path := ProjectSettings.globalize_path("user://settings.cfg")
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)                  # start from a clean slate, before Settings loads
	await process_frame
	st = root.get_node_or_null("Settings")
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")

	print("== audio buses and saved settings")
	_check("Settings autoload is loaded", st != null)
	_check("Music and SFX buses exist and send to Master", mi > 0 and si > 0 and AudioServer.get_bus_send(mi) == &"Master" and AudioServer.get_bus_send(si) == &"Master")
	_check("default volume is full (0 dB, not muted)", is_zero_approx(AudioServer.get_bus_volume_db(mi)) and not AudioServer.is_bus_mute(si))
	st.set_volume("Music", 0.5)
	st.set_volume("SFX", 0.0)
	_check("Music 50% = -6 dB", absf(AudioServer.get_bus_volume_db(mi) + 6.0206) < 0.01)
	_check("SFX 0% = muted", AudioServer.is_bus_mute(si))
	await create_timer(0.8).timeout
	var cfg := ConfigFile.new()
	_check("settings.cfg written once the slider stops", cfg.load("user://settings.cfg") == OK and is_equal_approx(float(cfg.get_value("audio", "music", -1.0)), 0.5) and is_zero_approx(float(cfg.get_value("audio", "sfx", -1.0))))
	AudioServer.set_bus_volume_db(mi, 0.0)
	AudioServer.set_bus_mute(si, false)
	var s2 = load("res://settings.gd").new()
	root.add_child(s2)
	_check("a new start restores the saved volumes", absf(AudioServer.get_bus_volume_db(mi) + 6.0206) < 0.01 and AudioServer.is_bus_mute(si))
	s2.free()
	var bad := ConfigFile.new()
	bad.set_value("audio", "music", 5.0)
	bad.set_value("audio", "sfx", -3.0)
	bad.save("user://settings.cfg")
	var s3 = load("res://settings.gd").new()
	root.add_child(s3)
	_check("a hand-edited file is clamped to 0..1", is_equal_approx(s3.get_volume("Music"), 1.0) and is_zero_approx(s3.get_volume("SFX")))
	s3.free()
	st.set_volume("Music", 1.0)
	st.set_volume("SFX", 1.0)

	for path in ["res://main.tscn", "res://level2.tscn"]:
		print("== ", path)
		var g = load(path).instantiate()
		root.add_child(g)
		current_scene = g
		await process_frame
		await physics_frame
		var guards := get_nodes_in_group("antagonist")
		for gd in guards:
			gd.sight_range = 0.0                             # nobody chases, nobody hits
			gd.close_range = 0.0
		var a = g.get_node("Audio")
		var pm = g.get_node("PauseMenu")
		_check("music, alert and victory players are on the Music bus", a.bgm.bus == &"Music" and a.alert.bus == &"Music" and a.victory.bus == &"Music")
		g.play_sfx(g.HIT_SOUND)
		var sfx_ok := false
		for c in g.get_children():
			if c is AudioStreamPlayer and c.stream == g.HIT_SOUND:
				sfx_ok = c.bus == &"SFX"
		_check("one-shot sounds are on the SFX bus", sfx_ok)
		_check("pause menu starts hidden, game not paused", not pm._root.visible and not paused)

		var probe = Node.new()
		var src := GDScript.new()
		src.source_code = "extends Node\nvar n := 0\nfunc _physics_process(_d: float) -> void:\n\tn += 1\n"
		src.reload()
		probe.set_script(src)
		g.add_child(probe)
		_check("physics runs before the pause", await _ticks(probe, 0.5) > 10)
		await _esc()
		_check("Esc pauses and shows the menu", paused and pm._root.visible)
		_check("Resume has keyboard focus", pm._resume_btn.has_focus())
		_check("physics is frozen while paused", await _ticks(probe, 0.6) == 0)
		_check("music keeps playing while paused", a.bgm.playing and not a.bgm.stream_paused)
		pm._howto_btn.pressed.emit()
		_check("How to Play opens from the pause menu", pm._help.visible and pm._help._back.has_focus())
		await process_frame
		await process_frame
		_check("it covers the whole window", pm._help.get_global_rect().size.is_equal_approx(root.get_visible_rect().size), str(pm._help.get_global_rect()) + " vs canvas " + str(root.get_visible_rect().size))
		await _esc()
		_check("Esc closes it, the game stays paused, focus returns", not pm._help.visible and paused and pm._root.visible and pm._howto_btn.has_focus())
		await _esc()
		_check("Esc resumes", not paused and not pm._root.visible)
		_check("physics runs again after Esc", await _ticks(probe, 0.5) > 10)

		g.finished = true
		await _esc()
		_check("Esc is ignored on the Win / Game Over screen", not paused and not pm._root.visible)
		g.finished = false

		await _esc()
		_btn(pm, "Resume").pressed.emit()
		_check("Resume button resumes", not paused and not pm._root.visible)

		if path == "res://main.tscn":
			await _esc()
			_btn(pm, "Restart").pressed.emit()
			_check("Restart un-pauses before reloading", not paused)
			await process_frame
			await process_frame
			await process_frame
			var g2 = current_scene
			_check("the level was reloaded and is not paused", g2 != g and g2.scene_file_path == path and not paused and g2.get_node("PauseMenu") != null)
			await _esc()
			_btn(g2.get_node("PauseMenu"), "Main Menu").pressed.emit()
			_check("Main Menu un-pauses", not paused)
			await process_frame
			await process_frame
			await process_frame
			_check("back on the start menu", current_scene.scene_file_path == "res://main_menu.tscn")
		else:
			g.queue_free()
			await process_frame

	print("== main menu")
	var mm = load("res://main_menu.tscn").instantiate()
	root.add_child(mm)
	current_scene = mm
	await process_frame
	var howto: Button = mm.get_node("%HowTo")
	var help = mm.get_child(mm.get_child_count() - 1)
	_check("main menu has a How to Play button (Play, How to Play, Quit)", howto != null and howto.text == "How to Play" and mm.get_node("%Play") != null and mm.get_node("%Quit") != null)
	_check("the panel starts hidden", not help.visible)
	howto.pressed.emit()
	_check("How to Play opens", help.visible and help._back.has_focus())
	await process_frame
	await process_frame
	var panel: Control = help.find_children("*", "PanelContainer", true, false)[0]
	_check("the panel covers the whole window", help.get_global_rect().size.is_equal_approx(mm.get_global_rect().size) and help.get_global_rect().size.x > 1000.0, str(help.get_global_rect()))
	_check("and the box is centered on it", panel.get_global_rect().get_center().distance_to(help.get_global_rect().get_center()) < 2.0, str(panel.get_global_rect()))
	var texts := []
	for l in help.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	_check("controls and tips are listed", texts.has("W A S D") and texts.has("Esc") and texts.has("Space") and texts.has("Use a lamp or a wall switch") and texts.has("Pause"))
	var sliders: Array = help.find_children("*", "HSlider", true, false)
	_check("two volume sliders at 100%", sliders.size() == 2 and is_equal_approx(sliders[0].value, 1.0) and is_equal_approx(sliders[1].value, 1.0))
	sliders[0].value = 0.25
	sliders[1].value = 0.0
	_check("sliders drive Settings and the buses", is_equal_approx(st.get_volume("Music"), 0.25) and absf(AudioServer.get_bus_volume_db(mi) - linear_to_db(0.25)) < 0.01 and AudioServer.is_bus_mute(si))
	var pct := []
	for l in help.find_children("*", "Label", true, false):
		pct.append((l as Label).text)
	_check("percent labels follow", pct.has("25%") and pct.has("0%"))
	await create_timer(0.8).timeout
	_check("and the file is saved", cfg.load("user://settings.cfg") == OK and is_equal_approx(float(cfg.get_value("audio", "music", -1.0)), 0.25))
	await _esc()
	_check("Esc closes the panel and focus returns to the button", not help.visible and howto.has_focus())
	howto.pressed.emit()
	(help._back as Button).pressed.emit()
	_check("Back closes the panel", not help.visible)

	st.set_volume("Music", 1.0)
	st.set_volume("SFX", 1.0)
	await create_timer(0.8).timeout
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)                  # leave no test settings behind
	print("== ", "ALL OK" if _fails == 0 else "%d FAILED" % _fails)
	quit(_fails)
