extends SceneTree

# Lamp, wall switch, exit door and hit effect each start their one-shot sound, and the player node frees itself afterwards.


func _players(g: Node) -> Array:
	var out := []
	for c in g.get_children():
		if c is AudioStreamPlayer:
			out.append(c)
	return out


func _report(g: Node, label: String) -> void:
	var parts := []
	for p in _players(g):
		parts.append("%s vol %+.0f dB playing=%s pos=%.2f" % [p.stream.resource_path.get_file(), p.volume_db, p.playing, p.get_playback_position()])
	print("  ", label, " -> ", parts)


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	for path in ["res://main.tscn", "res://level2.tscn"]:
		print("== ", path)
		var g = load(path).instantiate()
		root.add_child(g)
		current_scene = g
		await process_frame
		await physics_frame
		var lamps := get_nodes_in_group("lamps")
		var switches := []
		for n in get_nodes_in_group("interactable"):
			if "activated" in n:
				switches.append(n)
		print("  lamps=", lamps.size(), " switches=", switches.size(), " players at start=", _players(g).size())

		lamps[0].interact()
		await process_frame
		_report(g, "lamp E")
		await create_timer(0.4).timeout
		print("  0.4 s later players=", _players(g).size(), " (the 0.13 s light-switch clip should be gone)")

		switches[0].interact()
		await process_frame
		await create_timer(0.1).timeout
		_report(g, "switch 1 E (exit_open=%s)" % g.exit_open)
		switches[0].interact()
		await process_frame
		print("  same switch again -> players=", _players(g).size(), " (no second click)")

		for i in range(1, switches.size()):
			switches[i].interact()
		await process_frame
		await create_timer(0.1).timeout
		_report(g, "all switches done (exit_open=%s, %d/%d)" % [g.exit_open, g.switches_done, g.switches_needed])

		g.hit_effect(Vector3.ZERO)
		await process_frame
		_report(g, "hit effect")
		await create_timer(3.3).timeout
		print("  3.3 s later players=", _players(g).size(), " (all clips finished and freed)")
		g.queue_free()
		await process_frame
	quit()
