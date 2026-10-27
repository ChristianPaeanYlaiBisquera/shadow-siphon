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
@export var max_health := 100.0
@export var iframe_time := 1.0     # seconds of invulnerability after a hit (the model blinks white)

var is_lit := false        # true when a lit lamp is shining on the player
var is_sneaking := false
var active := true         # set to false on win / lose
var health := 100.0        # current health; 0 = game over
var _acting := false
var _iframes := 0.0                # invulnerability time left
var _blink_mat := StandardMaterial3D.new()
var _meshes: Array[Node] = []      # the model's meshes, flashed white during i-frames
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	add_to_group("player")
	add_to_group("characters")


func _ready() -> void:
	health = max_health
	_setup_input()
	_blink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # plain white, albedo defaults to white
	if model:
		_meshes = model.find_children("*", "MeshInstance3D", true, false)
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


# Blinks the model white while invulnerable (8 flashes per second, starting "on" at the hit).
func _process(delta: float) -> void:
	if _iframes <= 0.0:
		return
	_iframes = maxf(_iframes - delta, 0.0)
	var overlay: Material = _blink_mat if int(_iframes * 16.0) % 2 == 1 else null
	for m in _meshes:
		(m as MeshInstance3D).material_overlay = overlay


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if not active:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_hide_prompt()
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
	_update_prompt()

	if Input.is_action_just_pressed("interact"):
		_try_interact()


# Called by the guard when an attack lands.
func take_damage(amount: float) -> void:
	if not active or health <= 0.0 or _iframes > 0.0:
		return
	health = maxf(health - amount, 0.0)
	_iframes = iframe_time
	var g = get_tree().get_first_node_in_group("game")
	if g:
		g.flash_damage()
		g.hit_effect(global_position + Vector3.UP)
		if health <= 0.0:
			g.lose()


func _check_lit() -> bool:
	for l in get_tree().get_nodes_in_group("lamps"):
		if l.illuminates(global_position + Vector3.UP):
			return true
	return false


func _nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_d := interact_range
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node3D
		var d := global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


# Shows the "Press E" bubble over whatever lamp / switch is in reach.
func _update_prompt() -> void:
	var g = get_tree().get_first_node_in_group("game")
	if g == null:
		return
	var target := _nearest_interactable()
	if target == null or _acting or not target.has_method("prompt_text"):
		g.hide_prompt()
		return
	var text: String = target.prompt_text()
	if text == "":
		g.hide_prompt()
		return
	g.show_prompt(text, target.prompt_position())


func _hide_prompt() -> void:
	var g = get_tree().get_first_node_in_group("game")
	if g:
		g.hide_prompt()


func _try_interact() -> void:
	var best := _nearest_interactable()
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
