extends CharacterBody3D
## SHADOW SIPHON - Protagonist controller (Godot 4.x)
## Node setup: Player (CharacterBody3D, this script)
##   ├ CollisionShape3D (Capsule, height 1.8, radius 0.4, move up 0.9)
##   ├ Model        (your imported protagonist .glb)  -> assign to "model"
##   ├ AnimationTree (states named Idle / Walk / Action) -> assign to "anim_tree"
##   └ Camera3D     (fixed angle, e.g. position (0, 9, 6), rotation X -55)

# The "UpperBody" animation layer: the swing plays on these bones only (like an Avatar Mask), the legs keep walking.
const UPPER_BODY := ["bone_spine_01", "bone_chest", "bone_neck", "bone_head", "bone_upperarm_L", "bone_upperarm_R"]
const SWING_LENGTH := 0.55
const HIT_FROM := 0.16         # animation events: the attack hitbox is live from here ...
const HIT_TO := 0.30           # ... to here (the impact frames of the swing, the strike lands at 0.2 s)
# Key poses of the swing: bone -> [time, Euler degrees (pitch, yaw, roll) added on top of the Idle pose].
# Arms: pitch + = forward. Chest / spine: yaw + = the right shoulder goes back, pitch + = lean forward.
const SWING := {
	"bone_upperarm_R": [[0.10, Vector3(-55, 0, 0)], [0.20, Vector3(95, 0, 0)], [0.30, Vector3(80, 0, 0)]],
	"bone_upperarm_L": [[0.10, Vector3(25, 0, 0)], [0.20, Vector3(-30, 0, 0)], [0.30, Vector3(-20, 0, 0)]],
	"bone_chest": [[0.10, Vector3(-3, 22, 0)], [0.20, Vector3(12, -24, 0)], [0.30, Vector3(10, -18, 0)]],
	"bone_spine_01": [[0.10, Vector3(-2, 8, 0)], [0.20, Vector3(6, -10, 0)], [0.30, Vector3(5, -8, 0)]],
	"bone_head": [[0.20, Vector3(4, -8, 0)]],
}
const LOCOMOTION := "parameters/Locomotion/playback"      # the Idle / Walk / Action state machine inside the blend tree

@export var speed := 4.0
@export var sneak_speed := 2.0
@export var turn_speed := 12.0
@export var interact_range := 2.2
@export var model: Node3D
@export var anim_tree: AnimationTree
@export var max_health := 100.0
@export var iframe_time := 1.0     # seconds of invulnerability after a hit (the model blinks white)
@export var attack_damage := 20.0  # a guard has 60 health, so three hits
@export var attack_cooldown := 0.6 # seconds between swings

var is_lit := false        # true when a lit lamp is shining on the player
var is_sneaking := false
var active := true         # set to false on win / lose
var health := 100.0        # current health; 0 = game over
var _acting := false
var _iframes := 0.0                # invulnerability time left
var _blink_mat := StandardMaterial3D.new()
var _meshes: Array[Node] = []      # the model's meshes, flashed white during i-frames
var _attack_cd := 0.0              # seconds until the next swing is allowed
var _hitbox: Area3D                # the attack hurtbox-checker, live only at the swing's impact frames
var _hitbox_on := false
var _swing_hits: Array[Node] = []  # guards already hit by this swing (one hit each)
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
		_build_hitbox()
	if anim_tree:
		_setup_upper_body_layer()
		anim_tree.active = true


# Creates the key bindings in code so you don't have to touch Input Map.
func _setup_input() -> void:
	var keys := {
		"move_left": KEY_A, "move_right": KEY_D,
		"move_forward": KEY_W, "move_back": KEY_S,
		"interact": KEY_E, "sneak": KEY_SHIFT, "attack": KEY_SPACE,
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
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0 and not _acting:
		_start_attack()
	if _hitbox_on:
		_hit_overlaps()


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
	var pb := anim_tree.get(LOCOMOTION) as AnimationNodeStateMachinePlayback
	if pb:
		pb.travel(state)


# ---------------- ATTACK: upper-body layer + hitbox ----------------
# Space swings. The swing clip is layered over the walking legs with a OneShot node whose bone filter is the upper body
# (the Godot version of an Avatar Mask + an override layer at weight 1), so the player can attack while running.
func _start_attack() -> void:
	_attack_cd = attack_cooldown
	_swing_hits.clear()
	anim_tree.set("parameters/UpperBody/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	get_tree().create_timer(SWING_LENGTH).timeout.connect(enable_hitbox.bind(false))     # safety: the hitbox never stays live


# Animation event of the swing clip: live at the impact frames only (HIT_FROM .. HIT_TO).
func enable_hitbox(on: bool) -> void:
	_hitbox_on = on
	if _hitbox:
		_hitbox.monitoring = on


# While live, every guard inside the hitbox (and not behind a wall) takes the hit once per swing.
func _hit_overlaps() -> void:
	for b in _hitbox.get_overlapping_bodies():
		if b.is_in_group("antagonist") and not _swing_hits.has(b) and _clear_line_to(b):
			_swing_hits.append(b)
			b.take_hit(attack_damage, global_position)


func _clear_line_to(body: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, body.global_position + Vector3.UP)
	var ex: Array[RID] = []
	for n in get_tree().get_nodes_in_group("characters"):
		ex.append((n as CollisionObject3D).get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _build_hitbox() -> void:
	_hitbox = Area3D.new()
	_hitbox.collision_layer = 0
	_hitbox.monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, 1.0)          # a metre in front of the chest
	_hitbox.add_child(shape)
	model.add_child(_hitbox)                         # turns with the character


# Builds the layered animation tree: Locomotion (the Idle / Walk / Action state machine from the scene)
# + a OneShot "UpperBody" layer that plays the Swing clip only on the upper-body bones.
func _setup_upper_body_layer() -> void:
	var rig := anim_tree.get_node(anim_tree.root_node)                 # the Protagonist model
	var ap := anim_tree.get_node(anim_tree.anim_player) as AnimationPlayer
	var skel := rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var skel_path := str(rig.get_path_to(skel))
	var idle := ap.get_animation("Protagonist_Idle")
	var swing := Animation.new()
	swing.length = SWING_LENGTH
	var mask: Array[NodePath] = []
	for bone in UPPER_BODY:
		var path := NodePath("%s:%s" % [skel_path, bone])
		mask.append(path)
		if not SWING.has(bone):
			continue
		var i := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		var base := idle.rotation_track_interpolate(i, 0.0) if i >= 0 else skel.get_bone_rest(skel.find_bone(bone)).basis.get_rotation_quaternion()
		var t := swing.add_track(Animation.TYPE_ROTATION_3D)
		swing.track_set_path(t, path)
		swing.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		swing.rotation_track_insert_key(t, 0.0, base)
		for key in SWING[bone]:
			var e: Vector3 = key[1]
			swing.rotation_track_insert_key(t, key[0], base * Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z))))
		swing.rotation_track_insert_key(t, SWING_LENGTH, base)
	# animation events at the impact frames: EnableHitbox(true) / EnableHitbox(false) on this node
	var events := swing.add_track(Animation.TYPE_METHOD)
	var me_path := rig.get_path_to(self)
	swing.track_set_path(events, me_path)
	swing.track_insert_key(events, HIT_FROM, {"method": &"enable_hitbox", "args": [true]})
	swing.track_insert_key(events, HIT_TO, {"method": &"enable_hitbox", "args": [false]})
	mask.append(me_path)                                             # the event track has to pass the mask too
	var lib := AnimationLibrary.new()
	lib.add_animation("Swing", swing)
	ap.add_animation_library("combat", lib)

	var tree := AnimationNodeBlendTree.new()
	tree.add_node("Locomotion", anim_tree.tree_root, Vector2(0, 0))
	var clip := AnimationNodeAnimation.new()
	clip.animation = &"combat/Swing"
	tree.add_node("Swing", clip, Vector2(0, 200))
	var layer := AnimationNodeOneShot.new()
	layer.filter_enabled = true
	for p in mask:
		layer.set_filter_path(p, true)
	layer.fadein_time = 0.04
	layer.fadeout_time = 0.12
	tree.add_node("UpperBody", layer, Vector2(300, 0))
	tree.connect_node("UpperBody", 0, "Locomotion")
	tree.connect_node("UpperBody", 1, "Swing")
	tree.connect_node("output", 0, "UpperBody")
	anim_tree.tree_root = tree
