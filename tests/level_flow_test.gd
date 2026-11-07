extends SceneTree

# Level 1 > Level 2 hand-over, guards patrol on the NavMesh, 4 switches open the exit, reaching it wins.


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	# ---- level 1 -> level 2 hand-over --------------------------------------------------
	var l1 = load("res://main.tscn").instantiate()
	root.add_child(l1)
	current_scene = l1
	await process_frame
	await physics_frame
	print("L1: level_name='", l1.level_name, "' next_level='", l1.next_level, "' switches_needed=", l1.switches_needed)
	l1.win()
	print("L1 win -> title='", l1._end_title.text, "' next button visible=", l1._next_btn.visible, " restart visible=", l1._restart_btn.visible)
	l1.go_next_level()
	await process_frame
	await process_frame
	await physics_frame
	var g = current_scene
	print("after Next Level: current scene = ", g.name, " (", g.scene_file_path, ")")

	# ---- level 2 content ------------------------------------------------------------------
	var guards := get_nodes_in_group("antagonist")
	var lamps := get_nodes_in_group("lamps")
	var inter := get_nodes_in_group("interactable")
	print("L2 COUNTS guards=", guards.size(), " lamps=", lamps.size(), " interactables=", inter.size(), " switches_needed=", g.switches_needed, " next_level='", g.next_level, "'")
	var p = g.get_node("Player")
	var lit := false
	for l in lamps:
		lit = lit or l.illuminates(p.global_position + Vector3.UP)
	print("L2 spawn at ", p.global_position, " lit by any lamp: ", lit)
	for gd in guards:
		print("   ", gd.name, " tree active=", gd.anim_tree.active, " waypoints=", gd.waypoints_root.get_child_count(), " start=", gd.global_position, " state=", gd.state_name())
	var door: Node3D = g.exit_door
	print("L2 exit door node: ", door.name, " colliders=", door.get_children().size(), " exit_area=", g.exit_area.name)

	# ---- guards patrol with the lamps off (player stays hidden) ---------------------------------
	for l in lamps:
		l.set_on(false)
	var region: NavigationRegion3D = g.get_node("NavigationRegion3D")
	var map := region.get_navigation_map()
	Engine.time_scale = 4.0
	var walked := {}
	var last := {}
	var changes := {}
	var lastwp := {}
	var offmax := {}
	var states := {}
	for gd in guards:
		walked[gd.name] = 0.0
		last[gd.name] = gd.global_position
		changes[gd.name] = 0
		lastwp[gd.name] = gd._wp_index
		offmax[gd.name] = 0.0
		states[gd.name] = {}
	for k in 120:
		await create_timer(0.5).timeout
		for gd in guards:
			walked[gd.name] += _flat(gd.global_position, last[gd.name])
			last[gd.name] = gd.global_position
			if gd._wp_index != lastwp[gd.name]:
				changes[gd.name] += 1
				lastwp[gd.name] = gd._wp_index
			var c := NavigationServer3D.map_get_closest_point(map, gd.global_position)
			offmax[gd.name] = maxf(offmax[gd.name], _flat(c, gd.global_position))
			states[gd.name][gd.state_name()] = true
	for gd in guards:
		print("PATROL ", gd.name, " (60 s game time): walked ", snappedf(walked[gd.name], 0.1), " m, waypoint changes ", changes[gd.name], ", max off-mesh ", snappedf(offmax[gd.name], 0.01), " m, states ", states[gd.name].keys())
	Engine.time_scale = 1.0

	# ---- objective: 4 switches open the exit, reaching the exit area wins --------------------------
	for i in 4:
		var sw = g.get_node("Switch%d" % (i + 1))
		sw.interact()
		print("SWITCH ", i + 1, " -> done ", g.switches_done, "/", g.switches_needed, " exit_open=", g.exit_open)
	await create_timer(1.4).timeout
	print("door freed after opening: ", not is_instance_valid(door))
	p.global_position = Vector3(3.3, 0.2, -5.0)
	await create_timer(0.5).timeout
	print("WIN finished=", g.finished, " won=", g.won, " title='", g._end_title.text, "' next button visible=", g._next_btn.visible)
	quit()
