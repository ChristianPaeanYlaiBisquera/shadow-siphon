extends CharacterBody3D
## SHADOW SIPHON - Antagonist AI (Godot 4.x)
## States:
##   PATROL      walks the waypoint route
##   CHASE       runs at the player once it sees them
##   ATTACK      stops next to the player and hits them (player loses health, 0 health = game over)
##   INVESTIGATE goes to a noise / the last place it saw the player, then returns to PATROL
## Flow: PATROL -> CHASE -> ATTACK.  If the player escapes: CHASE -> INVESTIGATE -> PATROL.
## Detection: while the player is LIT the guard sees them inside a vision cone up to sight_range
## (shorter if sneaking). In SHADOW the guard only notices the player within close_range.
##
## Node setup: Guard (CharacterBody3D, this script)
##   ├ CollisionShape3D, Pivot > model (.glb), AnimationTree (Idle / Walk / Action), NavigationAgent3D

enum State { PATROL, INVESTIGATE, CHASE, ATTACK }

@export var model: Node3D
@export var anim_tree: AnimationTree
@export var waypoints_root: Node3D
@export var nav_agent: NavigationAgent3D
@export_group("Movement")
@export var patrol_speed := 1.8
@export var investigate_speed := 2.6
@export var chase_speed := 3.6
@export var wait_time := 2.0
@export_group("Perception")
@export var sight_range := 9.0
@export var fov_degrees := 90.0
@export var close_range := 1.8
@export_group("Attack")
@export var attack_range := 1.6        # starts attacking when this close
@export var attack_damage := 20.0      # health removed per hit (player has 100)
@export var attack_windup := 0.4       # seconds between starting the swing and the hit landing
@export var attack_cooldown := 1.5     # seconds between hits
@export var attack_anim_time := 1.0    # how long the Action animation shows before returning to Idle
@export_group("Health")
@export var max_health := 60.0         # the player's attack takes 20, so three hits take him down
@export var knockback_speed := 7.0     # m/s away from the attacker, fades out in about 0.3 s
@export var stun_time := 0.5           # seconds he cannot act after being hit

const BAR_WIDTH := 0.9

var state := State.PATROL
var player = null
var target := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var _wp_index := 0
var _wait := 0.0
var _attack_cd := 0.0
var _windup := -1.0
var _since_swing := 99.0
var _spread := 0.0     # this guard's own angle around a target shared with other guards (set in _ready)
var _want := 0.0       # speed asked for last frame (stuck check)
var _stuck := 0.0      # seconds spent trying to move without getting anywhere
var health := 60.0
var dead := false
var _stun := 0.0                       # seconds left of being stunned (huge once dead)
var _knock := Vector3.ZERO             # knockback velocity, fades out
var _white := StandardMaterial3D.new() # hit flash
var _bar: Node3D                       # floating health bar, shown after the first hit
var _bar_fill: MeshInstance3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	add_to_group("antagonist")
	add_to_group("characters")


func _ready() -> void:
	health = max_health
	_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_build_health_bar()
	if anim_tree:
		anim_tree.active = true
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		# guards steer around each other (and around a guard standing still) instead of pushing
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.5
		nav_agent.max_speed = chase_speed
		nav_agent.velocity_computed.connect(_on_safe_velocity)
	var guards := get_tree().get_nodes_in_group("antagonist")
	_spread = TAU * guards.find(self) / maxf(guards.size(), 1.0)


func state_name() -> String:
	return State.keys()[state]


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if _stun > 0.0:
		# hit: slides away from the attacker, can't act; afterwards he comes for the player (never, once dead)
		_stun -= delta
		_knock = _knock.move_toward(Vector3.ZERO, knockback_speed * 3.0 * delta)
		velocity.x = _knock.x
		velocity.z = _knock.z
		_travel("Idle")
		move_and_slide()
		if _stun <= 0.0 and player:
			_start_chase()
		return
	if player == null or not player.active:
		_idle()
		_apply_motion()
		return

	_check_stuck(delta)
	var sees := _can_see_player()
	match state:
		State.PATROL:
			_patrol(delta, sees)
		State.INVESTIGATE:
			_investigate(delta, sees)
		State.CHASE:
			_chase(sees)
		State.ATTACK:
			_attack(delta)
	_apply_motion()

	if model:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(facing.x, facing.z), 8.0 * delta)


# ---------------- STATES ----------------
func _patrol(delta: float, sees: bool) -> void:
	if sees:
		_start_chase()
		return
	if waypoints_root == null or waypoints_root.get_child_count() == 0:
		_idle()
		return
	if _wait > 0.0:
		_wait -= delta
		_idle()
		return
	var wp := waypoints_root.get_child(_wp_index) as Node3D
	if _move_to(wp.global_position, patrol_speed):
		_wait = wait_time
		_wp_index = (_wp_index + 1) % waypoints_root.get_child_count()


func _investigate(delta: float, sees: bool) -> void:
	if sees:
		_start_chase()
		return
	if _wait > 0.0:
		_wait -= delta
		_idle()
		if _wait <= 0.0:
			state = State.PATROL
		return
	if _move_to(target, investigate_speed, 1.3):
		_wait = wait_time


func _chase(sees: bool) -> void:
	if sees:
		target = player.global_position
	# Close enough (and nothing in between) -> stop and attack
	if _in_attack_range():
		_start_attack()
		return
	# his own slot on a ring around the player; ring + the 0.5 m arrival radius must stay inside attack_range, or he stops short and never swings
	var arrived := _move_to(target, chase_speed, attack_range * 0.6)
	if arrived and not sees:
		state = State.INVESTIGATE   # lost the player, search the last known spot
		_wait = wait_time


func _attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.01:
		facing = to.normalized()

	# A swing is in progress: the hit lands when the windup ends
	if _windup >= 0.0:
		_windup -= delta
		if _windup < 0.0:
			if dist <= attack_range * 1.3 and _clear_line(global_position + Vector3.UP, player.global_position + Vector3.UP):
				player.take_damage(attack_damage)
			_attack_cd = attack_cooldown
		return

	# Between swings
	_since_swing += delta
	if _since_swing > attack_anim_time:
		_travel("Idle")

	# Player backed away -> chase again
	if dist > attack_range * 1.5:
		state = State.CHASE
		target = player.global_position
		return

	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_windup = attack_windup
		_since_swing = 0.0
		_play("Action")


func _start_chase() -> void:
	state = State.CHASE
	target = player.global_position


func _start_attack() -> void:
	state = State.ATTACK
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_cd = 0.0     # first swing starts right away
	_windup = -1.0
	_since_swing = 99.0


func _in_attack_range() -> bool:
	if global_position.distance_to(player.global_position) > attack_range:
		return false
	return _clear_line(global_position + Vector3.UP, player.global_position + Vector3.UP)


# Called by the player's attack hitbox: damage, knockback away from the attacker, a short stun. 0 health = he goes down.
func take_hit(amount: float, from: Vector3) -> void:
	if dead:
		return
	health = maxf(health - amount, 0.0)
	var away := global_position - from
	away.y = 0.0
	_knock = (away.normalized() if away.length() > 0.01 else -facing) * knockback_speed
	_stun = stun_time
	_windup = -1.0                                   # a swing in progress is interrupted
	_flash()
	_update_bar()
	var g = get_tree().get_first_node_in_group("game")
	if g:
		g.hit_effect(global_position + Vector3.UP, 0.12, 0.12 if health <= 0.0 else 0.06)
	for a in get_tree().get_nodes_in_group("antagonist"):
		if a != self:
			a.hear_noise(global_position, 10.0)      # the scuffle is heard
	if health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	_stun = 99999.0                                  # never acts again; the knockback still plays out
	remove_from_group("antagonist")                  # no longer counts for the HUD, the music or lamp noise
	_bar.visible = false
	if nav_agent:
		nav_agent.avoidance_enabled = false
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)   # the body no longer blocks anyone
	var t := create_tween()
	t.tween_property(model, "rotation:x", -PI / 2.0, 0.4).set_ease(Tween.EASE_IN)     # falls on his back
	t.tween_interval(2.5)
	t.tween_callback(queue_free)


func _flash() -> void:
	_set_overlay(_white)
	get_tree().create_timer(0.15).timeout.connect(_set_overlay.bind(null))


func _set_overlay(mat: Material) -> void:
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = mat


func _build_health_bar() -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0.0, 2.3, 0.0)
	_bar.visible = false
	add_child(_bar)
	_bar.add_child(_bar_quad(Color(0.04, 0.04, 0.05, 0.85), BAR_WIDTH + 0.08, 0.17, 0))
	_bar_fill = _bar_quad(Color(0.92, 0.22, 0.2), BAR_WIDTH, 0.11, 1)
	_bar.add_child(_bar_fill)


func _bar_quad(color: Color, w: float, h: float, priority: int) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.render_priority = priority
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _update_bar() -> void:
	var ratio := health / max_health
	_bar.visible = true
	_bar_fill.scale.x = maxf(ratio, 0.001)
	_bar_fill.position.x = -(1.0 - ratio) * BAR_WIDTH * 0.5     # shrinks towards the left


# Called by lamps when the player clicks them.
func hear_noise(pos: Vector3, hearing_range: float) -> void:
	if state == State.CHASE or state == State.ATTACK:
		return
	if global_position.distance_to(pos) > hearing_range:
		return
	state = State.INVESTIGATE
	target = pos
	_wait = 0.0


# ---------------- HELPERS ----------------
func _move_to(pos: Vector3, spd: float, ring := 0.0) -> bool:
	var goal := pos
	if ring > 0.0:
		goal += Vector3(cos(_spread), 0.0, sin(_spread)) * ring      # guards fan out around a shared target
	if nav_agent:
		# a lamp's own spot (or a player in a narrow aisle) is not on the navmesh: go to the nearest walkable point instead
		var map := nav_agent.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) != 0:       # 0 = the map has not synced yet
			goal = NavigationServer3D.map_get_closest_point(map, goal)
	var flat := goal - global_position
	flat.y = 0.0
	if flat.length() < 0.5:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	# Follow the navmesh path around obstacles (falls back to a straight line if no navmesh)
	var next_pos := goal
	if nav_agent:
		nav_agent.target_position = goal
		next_pos = nav_agent.get_next_path_position()
	var to := next_pos - global_position
	to.y = 0.0
	if to.length() < 0.05:
		to = flat
	var d := to.normalized()
	facing = d
	velocity.x = d.x * spd
	velocity.z = d.z * spd
	_travel("Walk")
	return false


func _idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_travel("Idle")


# Moves the body. With avoidance on, the wanted velocity goes to the NavigationAgent3D and _on_safe_velocity() applies the result.
func _apply_motion() -> void:
	_want = Vector2(velocity.x, velocity.z).length()
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.velocity = Vector3(velocity.x, 0.0, velocity.z)
	else:
		move_and_slide()


func _on_safe_velocity(safe: Vector3) -> void:
	velocity.x = safe.x
	velocity.z = safe.z
	move_and_slide()


# Safety net: a guard that keeps asking to move but barely moves (blocked by a prop or another guard) tries something else.
func _check_stuck(delta: float) -> void:
	var real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if _want > 0.5 and real < 0.25 * _want:
		_stuck += delta
	else:
		_stuck = 0.0
	if _stuck < 1.5:
		return
	_stuck = 0.0
	_spread += 2.1                          # next time approach from another side
	if state == State.PATROL and waypoints_root and waypoints_root.get_child_count() > 0:
		_wp_index = (_wp_index + 1) % waypoints_root.get_child_count()    # skip the waypoint that cannot be reached
		_wait = 0.0
	elif state == State.INVESTIGATE:
		_wait = wait_time                   # give up on the spot, wait a moment, then go back to patrol


func _can_see_player() -> bool:
	var eye := global_position + Vector3.UP * 1.5
	var tgt: Vector3 = player.global_position + Vector3.UP * 1.0
	var to := tgt - eye
	var dist := to.length()

	var range_limit := close_range                 # in shadow: only very close
	if player.is_lit:
		range_limit = sight_range * (0.6 if player.is_sneaking else 1.0)
	if dist > range_limit:
		return false

	var flat := Vector3(to.x, 0.0, to.z).normalized()
	if dist > close_range and rad_to_deg(facing.angle_to(flat)) > fov_degrees * 0.5:
		return false
	return _clear_line(eye, tgt)


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var ex: Array[RID] = []
	for n in get_tree().get_nodes_in_group("characters"):
		ex.append((n as CollisionObject3D).get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# Moves to an animation state using the arrows in the AnimationTree
func _travel(s: String) -> void:
	if anim_tree == null:
		return
	var pb := anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if pb:
		pb.travel(s)


# Jumps straight to a state and restarts it (used to replay the attack swing)
func _play(s: String) -> void:
	if anim_tree == null:
		return
	var pb := anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if pb:
		pb.start(s, true)
