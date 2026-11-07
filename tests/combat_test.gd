extends SceneTree

# Player attack: upper-body layer (legs keep walking), animation events, hitbox, guard damage / knockback / death, hit-stop.

var _fails := 0
const LOWER := ["bone_pelvis", "bone_hip_L", "bone_thigh_L", "bone_shin_L", "bone_foot_L", "bone_hip_R", "bone_thigh_R", "bone_shin_R", "bone_foot_R"]


func _check(label: String, ok: bool, extra := "") -> void:
	print("  ", "ok   " if ok else "FAIL ", label, ("   (" + extra + ")") if extra != "" else "")
	if not ok:
		_fails += 1


func _key(pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _swing() -> void:
	_key(true)
	await physics_frame
	await physics_frame
	_key(false)


func _place(gd, pos: Vector3) -> void:
	gd.global_position = Vector3(pos.x, 0.0, pos.z)
	gd.velocity = Vector3.ZERO
	gd._stun = 0.0
	gd._knock = Vector3.ZERO
	gd.state = gd.State.PATROL
	gd._wait = 999.0                       # stands still, sees nothing


func _run(path: String, ppos: Vector3, dir: Vector3) -> void:
	print("== ", path)
	var g = load(path).instantiate()
	root.add_child(g)
	current_scene = g
	await process_frame
	await physics_frame
	await physics_frame
	var p = g.get_node("Player")
	var guards := get_nodes_in_group("antagonist")
	var gd = guards[0]
	for i in range(1, guards.size()):
		guards[i].process_mode = Node.PROCESS_MODE_DISABLED
	for x in guards:
		x.sight_range = 0.0
		x.close_range = 0.0
	p.global_position = ppos
	var yaw := atan2(dir.x, dir.z)
	p.model.rotation.y = yaw
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	await physics_frame

	# ---- the animation layer ------------------------------------------------------------------------------------------
	var tree = p.anim_tree.tree_root
	_check("anim tree is a blend tree with Locomotion + UpperBody layer", tree is AnimationNodeBlendTree and tree.has_node("Locomotion") and tree.has_node("UpperBody"))
	var layer: AnimationNodeOneShot = tree.get_node("UpperBody")
	var rig: Node = p.anim_tree.get_node(p.anim_tree.root_node)
	var skel: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var spath := str(rig.get_path_to(skel))
	var mask_ok := layer.filter_enabled
	for b in p.UPPER_BODY:
		mask_ok = mask_ok and layer.is_path_filtered(NodePath(spath + ":" + b))
	var legs_ok := true
	for b in LOWER:
		legs_ok = legs_ok and not layer.is_path_filtered(NodePath(spath + ":" + b))
	_check("the mask holds exactly the 6 upper-body bones (legs and pelvis are not in it)", mask_ok and legs_ok)
	_check("hitbox exists and is off at rest", p._hitbox != null and not p._hitbox_on and not p._hitbox.monitoring)

	# ---- attack while walking: legs follow Walk, arm follows the swing ---------------------------------------------------
	Input.action_press("move_forward")
	await create_timer(0.7).timeout
	var pb := p.anim_tree.get(p.LOCOMOTION) as AnimationNodeStateMachinePlayback
	_check("walking: the state machine is in Walk", pb.get_current_node() == &"Walk")
	var t0 := Time.get_ticks_msec()
	await _swing()
	var on_t := -1.0
	var off_t := -1.0
	var sampled := false
	var leg_err := 99.0
	var arm_deg := 0.0
	var moving_during := 0.0
	var idle_anim: Animation = p.anim_tree.get_node(p.anim_tree.anim_player).get_animation("Protagonist_Idle")
	var walk_anim: Animation = p.anim_tree.get_node(p.anim_tree.anim_player).get_animation("Protagonist_Walk")
	while Time.get_ticks_msec() - t0 < 600:
		await physics_frame
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if p._hitbox_on and on_t < 0.0:
			on_t = t
		if on_t >= 0.0 and not p._hitbox_on and off_t < 0.0:
			off_t = t
		if not sampled and t >= 0.24:
			sampled = true
			moving_during = Vector2(p.velocity.x, p.velocity.z).length()
			var ti := walk_anim.find_track(NodePath(spath + ":bone_thigh_L"), Animation.TYPE_ROTATION_3D)
			var want := walk_anim.rotation_track_interpolate(ti, pb.get_current_play_position())
			leg_err = rad_to_deg(want.angle_to(skel.get_bone_pose_rotation(skel.find_bone("bone_thigh_L"))))
			var ai := idle_anim.find_track(NodePath(spath + ":bone_upperarm_R"), Animation.TYPE_ROTATION_3D)
			arm_deg = rad_to_deg(idle_anim.rotation_track_interpolate(ai, 0.0).angle_to(skel.get_bone_pose_rotation(skel.find_bone("bone_upperarm_R"))))
	Input.action_release("move_forward")
	_check("the player keeps walking during the swing (not frozen)", moving_during > 2.0, "speed %.1f m/s" % moving_during)
	_check("legs still follow the Walk clip while swinging", leg_err < 8.0, "thigh is %.1f deg off the Walk pose" % leg_err)
	_check("the arm is up in the swing at the strike (about 95 deg from its Idle pose)", arm_deg > 70.0 and arm_deg < 120.0, "%.0f deg" % arm_deg)
	_check("animation event turns the hitbox on at the impact frames", on_t >= 0.10 and on_t <= 0.30, "on at %.2f s" % on_t)
	_check("and off again", off_t > on_t and off_t <= 0.45, "off at %.2f s" % off_t)
	await create_timer(0.8).timeout

	# ---- hitting a guard --------------------------------------------------------------------------------------------------
	p.global_position = ppos
	p.model.rotation.y = yaw
	p._attack_cd = 0.0
	await physics_frame
	_place(gd, ppos + fwd * 3.0)
	await _swing()
	await create_timer(0.6).timeout
	_check("a guard 3 m away is not hit", is_equal_approx(gd.health, 60.0))
	p._attack_cd = 0.0
	_place(gd, ppos - fwd * 1.0)
	await _swing()
	await create_timer(0.6).timeout
	_check("a guard behind the player is not hit", is_equal_approx(gd.health, 60.0))

	p._attack_cd = 0.0
	var start := ppos + fwd * 1.0
	_place(gd, start)
	var scales := []
	await _swing()
	var t1 := Time.get_ticks_msec()
	var min_scale := 1.0
	var stun_seen := 0.0
	var landed_at := -1.0
	while Time.get_ticks_msec() - t1 < 700:
		await process_frame
		min_scale = minf(min_scale, Engine.time_scale)
		stun_seen = maxf(stun_seen, gd._stun)
		if landed_at < 0.0 and gd.health < 60.0:
			landed_at = (Time.get_ticks_msec() - t1) / 1000.0
	_check("a guard in front takes exactly one hit per swing (20 of 60)", is_equal_approx(gd.health, 40.0), "health %.0f" % gd.health)
	var pushed := Vector2(gd.global_position.x - start.x, gd.global_position.z - start.z)
	_check("he is knocked back away from the player", pushed.length() > 0.4 and pushed.dot(Vector2(fwd.x, fwd.z)) > 0.3, "moved %.2f m" % pushed.length())
	_check("and stunned", stun_seen > 0.3)
	_check("hit-stop slowed the game to 5% ...", is_equal_approx(min_scale, 0.05), "min time scale %.2f" % min_scale)
	_check("... and the normal speed came back", is_equal_approx(Engine.time_scale, 1.0))
	_check("his health bar is showing", gd._bar.visible and gd._bar_fill.scale.x < 0.7)
	await create_timer(0.3).timeout
	_check("after the stun he goes for the player (no longer PATROL)", gd.state_name() != "PATROL", gd.state_name())

	p._attack_cd = 0.0
	_place(gd, ppos + fwd * 1.0)
	await _swing()
	await _swing()
	await create_timer(0.3).timeout
	_check("a second swing inside the cooldown does nothing extra (60 - 2 x 20 = 20)", is_equal_approx(gd.health, 20.0), "health %.0f" % gd.health)

	await create_timer(0.7).timeout                  # let that swing finish
	p._attack_cd = 0.0
	_place(gd, ppos + fwd * 1.0)
	await _swing()
	await create_timer(0.7).timeout
	_check("third hit: he goes down", gd.dead and is_equal_approx(gd.health, 0.0))
	_check("and no longer counts as a guard (HUD, music, lamp noise)", not gd.is_in_group("antagonist"))
	var shape_off := true
	for c in gd.get_children():
		if c is CollisionShape3D:
			shape_off = shape_off and (c as CollisionShape3D).disabled
	_check("his body no longer blocks", shape_off)
	await create_timer(3.4).timeout
	_check("the body is removed after a few seconds", not is_instance_valid(gd))
	g.queue_free()
	await process_frame
	await process_frame


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	await _run("res://main.tscn", Vector3(-3.6, 0.2, 3.0), Vector3(0.77, 0, -0.64))
	await _run("res://level2.tscn", Vector3(1.0, 0.2, 3.0), Vector3(1, 0, 0))
	print("== ", "ALL OK" if _fails == 0 else "%d FAILED" % _fails)
	quit(_fails)
