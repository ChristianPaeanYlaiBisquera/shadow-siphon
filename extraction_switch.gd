extends Node3D
## SHADOW SIPHON - Extraction switch (attach to a Node3D)
## Children: MeshInstance3D, AudioStreamPlayer3D, GPUParticles3D (one-shot)
## Press E near it to activate. When all switches are active the exit opens.

@export var mesh: MeshInstance3D
@export var mat_inactive: Material   # PBR state A (e.g. dull / dark)
@export var mat_active: Material     # PBR state B (e.g. glowing / green)
@export var sfx: AudioStreamPlayer3D
@export var burst: GPUParticles3D
@export var prompt_height := 1.6     # how high above the switch the "Press E" bubble floats

var activated := false


func _enter_tree() -> void:
	add_to_group("interactable")


func _ready() -> void:
	if mesh and mat_inactive:
		mesh.set_surface_override_material(0, mat_inactive)


func interact() -> void:
	if activated:
		return
	activated = true
	if mesh and mat_active:
		mesh.set_surface_override_material(0, mat_active)
	if sfx:
		sfx.play()
	if burst:
		burst.restart()
		burst.emitting = true
	var g = get_tree().get_first_node_in_group("game")
	if g:
		g.switch_activated()


# ---- "Press E" bubble (read by player.gd) ----
func prompt_text() -> String:
	if activated:
		return ""                      # nothing to show once it's already on
	return "Press E to activate"


func prompt_position() -> Vector3:
	return global_position + Vector3.UP * prompt_height
