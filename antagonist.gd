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

var state := State.PATROL
var player = null
var target := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var _wp_index := 0
var _wait := 0.0
var _attack_cd := 0.0
var _windup := -1.0
var _since_swing := 99.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	add_to_group("antagonist")
	add_to_group("characters")


func _ready() -> void:
	if anim_tree:
		anim_tree.active = true
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5


func state_name() -> String:
	return State.keys()[state]


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null or not player.active:
		_idle()
		move_and_slide()
		return

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
	move_and_slide()

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
	if _move_to(target, investigate_speed):
		_wait = wait_time


func _chase(sees: bool) -> void:
	if sees:
		target = player.global_position
	# Close enough (and nothing in between) -> stop and attack
	if _in_attack_range():
		_start_attack()
		return
	var arrived := _move_to(target, chase_speed)
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
func _move_to(pos: Vector3, spd: float) -> bool:
	var flat := pos - global_position
	flat.y = 0.0
	if flat.length() < 0.4:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	# Follow the navmesh path around obstacles (falls back to a straight line if no navmesh)
	var next_pos := pos
	if nav_agent:
		nav_agent.target_position = pos
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
