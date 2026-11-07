extends SceneTree

# 1) a guard standing at an investigation spot in the west corridor must not block the guard that patrols through it
# 2) three guards chasing a player they can and cannot reach: no pile-up, no endless stand-off while the player is reachable
# 3) level 1 still works with one guard (patrol, chase, attack)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _min_pair(guards: Array) -> float:
	var m := 999.0
	for i in guards.size():
		for j in range(i + 1, guards.size()):
			m = minf(m, _flat(guards[i].global_position, guards[j].global_position))
	return m


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	var g = load("res://level2.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await process_frame
	await physics_frame
	await physics_frame
	var p = g.get_node("Player")
	var guards := get_nodes_in_group("antagonist")
	for l in get_nodes_in_group("lamps"):
		l.set_on(false)
	p.global_position = Vector3(-11.0, 0.2, -2.2)
	Engine.time_scale = 4.0

	# ---- 1) corridor: Guard3 is sent to a spot on Guard1's patrol line ----------------------------------------
	var g1 = g.get_node("Guard1")
	var g3 = g.get_node("Guard3")
	await create_timer(1.0).timeout
	g3.hear_noise(Vector3(-8.0, 0.0, 4.0), 60.0)
	var changes := 0
	var last: int = g1._wp_index
	var g3_back := -1.0
	var t := 0.0
	var mind := 999.0
	for k in 40:
		await create_timer(0.5).timeout
		t += 2.0
		if g1._wp_index != last:
			changes += 1
			last = g1._wp_index
		if g3.state_name() == "PATROL" and g3_back < 0.0 and t > 4.0:
			g3_back = t
		mind = minf(mind, _flat(g1.global_position, g3.global_position))
	print("CORRIDOR Guard1 kept patrolling: waypoint changes ", changes, " in 80 s; Guard3 back on PATROL after ", g3_back, " s; closest they got ", snappedf(mind, 0.01), " m")

	# ---- 2) three guards chase a reachable player in the open centre ---------------------------------------------------
	for l in get_nodes_in_group("lamps"):
		l.set_on(true)
	p.max_health = 100000.0
	p.health = 100000.0
	p.iframe_time = 0.0
	p.global_position = Vector3(1.0, 0.2, 3.0)
	for gd in guards:
		gd.global_position = Vector3(-3.0 + 3.0 * guards.find(gd), 0.0, 6.5)    # three guards in the open, all in range
		gd.state = gd.State.CHASE
		gd.target = p.global_position
	var attackers := {}
	var mind2 := 999.0
	var stuck_time := 0.0
	for k in 30:
		await create_timer(0.5).timeout
		for gd in guards:
			attackers[gd.name] = attackers.get(gd.name, false) or gd.state_name() == "ATTACK"
		mind2 = minf(mind2, _min_pair(guards))
	print("CHASE reachable player: attackers ", attackers, " (all should reach ATTACK), closest two guards ", snappedf(mind2, 0.01), " m, player health lost ", 100000.0 - p.health)

	# ---- 3) player inside a rack aisle the guards cannot enter: they gather at the aisle mouth without piling up ----
	p.global_position = Vector3(-11.9, 0.2, 5.0)
	for gd in guards:
		gd.global_position = Vector3(-8.0, 0.0, 2.0 + 2.0 * guards.find(gd))
		gd.state = gd.State.CHASE
	var mind3 := 999.0
	for k in 30:
		await create_timer(0.5).timeout
		mind3 = minf(mind3, _min_pair(guards))
	var pos := []
	for gd in guards:
		pos.append("%s=(%.1f,%.1f) %s" % [gd.name, gd.global_position.x, gd.global_position.z, gd.state_name()])
	print("AISLE hidden player: ", pos, " closest two guards ", snappedf(mind3, 0.01), " m")

	var tmp := Node3D.new()
	tmp.set_script(load("res://lamp.gd"))
	var tl := OmniLight3D.new()
	tl.name = "OmniLight3D"
	tl.position = Vector3(0, 1.8, 0)
	tmp.light = tl
	tmp.add_child(tl)
	g.add_child(tmp)
	tmp.global_position = Vector3(-11.9, 0.0, 6.0)
	for gd in guards:
		gd.fov_degrees = 360.0
		gd.sight_range = 30.0
		gd.global_position = Vector3(-8.0, 0.0, 1.0 + 3.0 * guards.find(gd))
		gd.state = gd.State.CHASE
	p.global_position = Vector3(-11.9, 0.2, 4.5)
	var mind4 := 999.0
	var jitter := 0.0
	var lastg := {}
	for gd in guards:
		lastg[gd.name] = gd.global_position
	for k in 30:
		await create_timer(0.5).timeout
		mind4 = minf(mind4, _min_pair(guards))
		if k >= 15:
			for gd in guards:
				jitter += _flat(gd.global_position, lastg[gd.name])
		for gd in guards:
			lastg[gd.name] = gd.global_position
	pos = []
	for gd in guards:
		pos.append("%s=(%.1f,%.1f) %s" % [gd.name, gd.global_position.x, gd.global_position.z, gd.state_name()])
	print("AISLE visible but unreachable player (lit): ", pos, " closest two guards ", snappedf(mind4, 0.01), " m, distance moved in the last 30 s (jitter) ", snappedf(jitter, 0.1), " m, player lit=", p.is_lit)
	Engine.time_scale = 1.0

	# ---- 4) level 1 (single guard) ------------------------------------------------------------------------------------
	var l1 = load("res://main.tscn").instantiate()
	root.remove_child(g)
	g.queue_free()
	root.add_child(l1)
	current_scene = l1
	await process_frame
	await physics_frame
	await physics_frame
	var gd1 = l1.get_node("Guard")
	var p1 = l1.get_node("Player")
	p1.max_health = 100000.0
	p1.health = 100000.0
	Engine.time_scale = 4.0
	for l in get_nodes_in_group("lamps"):
		l.set_on(false)
	var walked := 0.0
	gd1.sight_range = 0.0
	gd1.close_range = 0.0
	var lastp: Vector3 = gd1.global_position
	for k in 40:
		await create_timer(0.5).timeout
		walked += _flat(gd1.global_position, lastp)
		lastp = gd1.global_position
	print("LEVEL1 patrol: walked ", snappedf(walked, 0.1), " m in 80 s, state ", gd1.state_name())
	for l in get_nodes_in_group("lamps"):
		l.set_on(true)
	gd1.sight_range = 9.0
	gd1.close_range = 1.8
	p1.global_position = gd1.global_position + Vector3(3.0, 0.2, 0.0)
	var st := {}
	for k in 24:
		await create_timer(0.5).timeout
		st[gd1.state_name()] = true
	print("LEVEL1 chase: states ", st.keys(), " health lost ", 100000.0 - p1.health)
	Engine.time_scale = 1.0
	quit()
