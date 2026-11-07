extends SceneTree

# Lamp-noise lure on level 2: do the guards arrive, stop huddling and go back to patrol?


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	var g = load("res://level2.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await process_frame
	await physics_frame
	await physics_frame
	var p = g.get_node("Player")
	p.global_position = Vector3(-11.0, 0.2, -2.2)         # hidden spawn corner
	var guards := get_nodes_in_group("antagonist")
	var lamp = g.get_node("NavigationRegion3D/Lamp2")
	Engine.time_scale = 4.0
	await create_timer(1.0).timeout

	lamp.interact()                                        # E on lamp 2: switches it off and makes noise
	var t := 0.0
	var back := {}
	var mind := 999.0
	var changes := {}
	var lastwp := {}
	for gd in guards:
		changes[gd.name] = 0
		lastwp[gd.name] = gd._wp_index
	var arrived := {}
	for k in 40:
		await create_timer(0.5).timeout
		t += 2.0
		for gd in guards:
			if gd.state_name() == "PATROL" and not back.has(gd.name):
				back[gd.name] = t
			if gd._wp_index != lastwp[gd.name]:
				changes[gd.name] += 1
				lastwp[gd.name] = gd._wp_index
			if gd.state_name() == "INVESTIGATE" and gd.velocity.length() < 0.1 and not arrived.has(gd.name):
				arrived[gd.name] = t
		for i in guards.size():
			for j in range(i + 1, guards.size()):
				mind = minf(mind, _flat(guards[i].global_position, guards[j].global_position))
	for gd in guards:
		print("LURE ", gd.name, ": stopped at the lamp spot after ", arrived.get(gd.name, -1), " s, back on PATROL after ", back.get(gd.name, -1), " s, ends in ", gd.state_name(), ", waypoint changes ", changes[gd.name], ", distance to lamp ", snappedf(_flat(gd.global_position, lamp.global_position), 0.1), " m")
	print("LURE closest two guards got to each other: ", snappedf(mind, 0.01), " m (guard body radius is 0.4, so < 0.8 means they are touching)")
	Engine.time_scale = 1.0
	quit()
