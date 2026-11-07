extends SceneTree

# A guard in CHASE comes at a player who stands still, from 8 directions, 6 m away.
# He must end up swinging at him (ATTACK) and actually land hits, not stop just outside his reach.


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run(path: String, ppos: Vector3) -> void:
	var g = load(path).instantiate()
	root.add_child(g)
	current_scene = g
	await process_frame
	await physics_frame
	await physics_frame
	var p = g.get_node("Player")
	p.max_health = 1000000.0
	p.health = 1000000.0
	p.iframe_time = 0.0
	for l in get_nodes_in_group("lamps"):
		l.set_on(true)
	p.global_position = ppos
	var guards := get_nodes_in_group("antagonist")
	for i in range(1, guards.size()):
		guards[i].process_mode = Node.PROCESS_MODE_DISABLED       # one guard at a time
	var gd = guards[0]
	var map: RID = g.get_node("NavigationRegion3D").get_navigation_map()
	Engine.time_scale = 4.0
	print("== ", path, "  player at ", ppos, " lit=", p.is_lit)
	var fails := 0
	for k in 8:
		var ang := k * TAU / 8.0
		var s := NavigationServer3D.map_get_closest_point(map, ppos + Vector3(cos(ang), 0.0, sin(ang)) * 6.0)
		gd.global_position = Vector3(s.x, 0.0, s.z)
		gd.velocity = Vector3.ZERO
		gd.state = gd.State.CHASE
		gd.target = ppos
		gd._spread = ang                                         # worst case: his own slot is straight on his side
		var hp0: float = p.health
		var attacked := false
		for i in 12:
			await create_timer(0.5).timeout
			attacked = attacked or gd.state_name() == "ATTACK"
		var hits := int((hp0 - p.health) / 20.0)
		if not attacked or hits == 0:
			fails += 1
		print("  from %3d deg: attacked=%s hits=%d final distance %.2f m  state %s" % [int(rad_to_deg(ang)), attacked, hits, _flat(gd.global_position, ppos), gd.state_name()])
	print("  -> guards that never swung / never hit: ", fails, " of 8")
	Engine.time_scale = 1.0
	g.queue_free()
	await process_frame


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	await _run("res://main.tscn", Vector3(-3.6, 0.2, 3.0))
	await _run("res://level2.tscn", Vector3(1.0, 0.2, 3.0))
	quit()
