extends SceneTree

# Music level in both levels: starts at bgm_db, ducks out while a guard is alerted, comes back to bgm_db when he calms down.


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	for path in ["res://main.tscn", "res://level2.tscn"]:
		var g = load(path).instantiate()
		root.add_child(g)
		current_scene = g
		await process_frame
		for gd in get_nodes_in_group("antagonist"):
			gd.sight_range = 0.0                  # the guard must not spot the player on his own
			gd.close_range = 0.0
		var a = g.get_node("Audio")
		await create_timer(0.5).timeout
		print(path, ": bgm_db=", a.bgm_db, "  music volume=", a.bgm.volume_db, "  playing=", a.bgm.playing, "  stream=", a.bgm.stream.resource_path.get_file())
		var guard = get_nodes_in_group("antagonist")[0]
		guard.state = guard.State.CHASE
		await create_timer(2.5).timeout
		print("   guard alerted: music=", snappedf(a.bgm.volume_db, 0.1), " alert sting=", snappedf(a.alert.volume_db, 0.1), " playing=", a.alert.playing)
		guard.state = guard.State.PATROL
		await create_timer(2.5).timeout
		print("   guard calm again: music=", snappedf(a.bgm.volume_db, 0.1), " alert sting=", snappedf(a.alert.volume_db, 0.1))
		g.queue_free()
		await process_frame
	quit()
