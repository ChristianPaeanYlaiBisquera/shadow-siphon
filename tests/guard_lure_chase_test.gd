extends SceneTree

# Level 2 AI: a lamp noise lures the guards (INVESTIGATE, then back to PATROL); a lit player is chased, attacked and defeated.


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	var g = load("res://level2.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await process_frame
	await physics_frame
	var guards := get_nodes_in_group("antagonist")
	var p = g.get_node("Player")
	Engine.time_scale = 3.0

	# 1) noise lure: pressing E on lamp 2 sends nearby patrolling guards to investigate
	var lamp = g.get_node("NavigationRegion3D/Lamp2")
	p.global_position = Vector3(-11.0, 0.2, -2.2)
	await create_timer(2.0).timeout
	lamp.interact()
	var seen := {}
	for gd in guards:
		seen[gd.name] = {}
	for k in 16:
		await create_timer(0.5).timeout
		for gd in guards:
			seen[gd.name][gd.state_name()] = true
	for gd in guards:
		print("LURE ", gd.name, " states seen: ", seen[gd.name].keys(), " distance to lamp now ", snappedf(_flat(gd.global_position, lamp.global_position), 0.1), " m")

	# 2) detection, chase and attack in the lit centre of the map
	for l in get_nodes_in_group("lamps"):
		l.set_on(true)
	var g2 = g.get_node("Guard2")
	g2.global_position = Vector3(2.5, 0.0, 2.0)
	g2.state = g2.State.PATROL
	p.global_position = Vector3(-1.5, 0.2, 3.5)
	var st := {}
	var hp0: float = p.health
	for k in 40:
		await create_timer(0.5).timeout
		st[g2.state_name()] = true
		if p.health < hp0 and not st.has("HIT"):
			st["HIT"] = true
	print("CHASE Guard2 states seen: ", st.keys(), " player health ", p.health, "/", p.max_health, " finished=", g.finished)
	Engine.time_scale = 1.0
	quit()
