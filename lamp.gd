extends Node3D
## SHADOW SIPHON - Toggleable lamp (attach to a Node3D)
## Children: OmniLight3D, MeshInstance3D (bulb/lampshade), AudioStreamPlayer3D, GPUParticles3D (one-shot)
## Press E near it: the light toggles AND the guard hears it and goes to investigate (distraction).

@export var start_on := true
@export var radius := 6.0
@export var noise_range := 14.0
@export var light: Light3D
@export var bulb: MeshInstance3D
@export var mat_on: Material      # PBR material: lit / clean state
@export var mat_off: Material     # PBR material: dark / dim state
@export var sfx: AudioStreamPlayer3D
@export var burst: GPUParticles3D

var is_on := true


func _enter_tree() -> void:
	add_to_group("lamps")
	add_to_group("interactable")


func _ready() -> void:
	is_on = start_on
	if light is OmniLight3D:
		(light as OmniLight3D).omni_range = radius
	_apply(false)


func interact() -> void:
	set_on(not is_on)
	for a in get_tree().get_nodes_in_group("antagonist"):
		a.hear_noise(global_position, noise_range)


func set_on(value: bool) -> void:
	is_on = value
	_apply(true)


func _apply(feedback: bool) -> void:
	if light:
		light.visible = is_on
	if bulb and mat_on and mat_off:
		bulb.set_surface_override_material(0, mat_on if is_on else mat_off)
	if feedback:
		if sfx:
			sfx.play()
		if burst:
			burst.restart()
			burst.emitting = true


# True if this lamp is ON, in range, and nothing solid blocks the light.
func illuminates(point: Vector3) -> bool:
	if not is_on:
		return false
	var from := light.global_position if light else global_position
	if from.distance_to(point) > radius:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, point)
	var ex: Array[RID] = []
	for n in get_tree().get_nodes_in_group("characters"):
		ex.append((n as CollisionObject3D).get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
