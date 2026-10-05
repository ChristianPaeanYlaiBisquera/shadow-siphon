extends CharacterBody3D
## SHADOW SIPHON - Antagonist AI (Godot 4.x)
## States: PATROL -> (sees player) CHASE -> (loses player) INVESTIGATE -> PATROL
## Hears lamp clicks -> INVESTIGATE that lamp (this is the "distraction" solution).
## Detection: if the player is LIT, guard sees them inside its vision cone up to sight_range
##            (shorter if sneaking). If the player is in SHADOW, guard only notices at close_range.
##
## Node setup: Antagonist (CharacterBody3D, this script)
##   ├ CollisionShape3D, Model (.glb), AnimationTree (Idle / Walk / Action)
##   └ Waypoints (Node3D) with 3-4 Marker3D children = patrol route (assign to waypoints_root)

enum State { PATROL, INVESTIGATE, CHASE }

@export var model: Node3D
@export var anim_tree: AnimationTree
@export var waypoints_root: Node3D
@export var patrol_speed := 1.8
@export var investigate_speed := 2.6
@export var chase_speed := 3.6
@export var sight_range := 9.0
@export var fov_degrees := 90.0
@export var close_range := 1.8
@export var catch_range := 1.1
@export var wait_time := 2.0
@export var nav_agent: NavigationAgent3D   # pathfinding (add a NavigationAgent3D child to Guard)

var state := State.PATROL
var player = null
var target := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var _wp_index := 0
var _wait := 0.0
var _catching := false
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
	if _catching:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
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
	var arrived := _move_to(target, chase_speed)
	if arrived and not sees:
		state = State.INVESTIGATE   # lost the player, search the last known spot
		_wait = wait_time
	if global_position.distance_to(player.global_position) <= catch_range:
		_catch()


func _start_chase() -> void:
	state = State.CHASE
	target = player.global_position


func _catch() -> void:
	_catching = true
	_travel("Action")
	player.active = false
	var g = get_tree().get_first_node_in_group("game")
	if g:
		g.lose()


# Called by lamps when the player clicks them.
func hear_noise(pos: Vector3, hearing_range: float) -> void:
	if state == State.CHASE or _catching:
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


func _travel(s: String) -> void:
	if anim_tree == null:
		return
	var pb := anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if pb:
		pb.travel(s)
