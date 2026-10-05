extends CharacterBody3D
## SHADOW SIPHON - Protagonist controller (Godot 4.x)
## Node setup: Player (CharacterBody3D, this script)
##   ├ CollisionShape3D (Capsule, height 1.8, radius 0.4, move up 0.9)
##   ├ Model        (your imported protagonist .glb)  -> assign to "model"
##   ├ AnimationTree (states named Idle / Walk / Action) -> assign to "anim_tree"
##   └ Camera3D     (fixed angle, e.g. position (0, 9, 6), rotation X -55)

@export var speed := 4.0
@export var sneak_speed := 2.0
@export var turn_speed := 12.0
@export var interact_range := 2.2
@export var model: Node3D
@export var anim_tree: AnimationTree

var is_lit := false        # true when a lit lamp is shining on the player
var is_sneaking := false
var active := true         # set to false on win / lose
var _acting := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	add_to_group("player")
	add_to_group("characters")


func _ready() -> void:
	_setup_input()
	if anim_tree:
		anim_tree.active = true


# Creates the key bindings in code so you don't have to touch Input Map.
func _setup_input() -> void:
	var keys := {
		"move_left": KEY_A, "move_right": KEY_D,
		"move_forward": KEY_W, "move_back": KEY_S,
		"interact": KEY_E, "sneak": KEY_SHIFT,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if not active:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input.x, 0.0, input.y)
	is_sneaking = Input.is_action_pressed("sneak")
	var spd := sneak_speed if is_sneaking else speed
	if _acting:
		dir = Vector3.ZERO

	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()

	var moving := dir.length() > 0.1
	if moving and model:
		# glTF models face +Z. If your character walks backwards, add + PI here.
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), turn_speed * delta)
	if not _acting:
		_travel("Walk" if moving else "Idle")

	is_lit = _check_lit()

	if Input.is_action_just_pressed("interact"):
		_try_interact()


func _check_lit() -> bool:
	for l in get_tree().get_nodes_in_group("lamps"):
		if l.illuminates(global_position + Vector3.UP):
			return true
	return false


func _try_interact() -> void:
	var best: Node3D = null
	var best_d := interact_range
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node3D
		var d := global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	if best == null:
		return
	_acting = true
	_travel("Action")
	best.interact()
	await get_tree().create_timer(0.7).timeout
	_acting = false


func _travel(state: String) -> void:
	if anim_tree == null:
		return
	var pb := anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if pb:
		pb.travel(state)
