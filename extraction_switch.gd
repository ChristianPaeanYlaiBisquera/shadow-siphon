extends Node3D
## SHADOW SIPHON - Extraction switch (attach to a Node3D)
## Children: MeshInstance3D, AudioStreamPlayer3D, GPUParticles3D (one-shot)
## Press E near it to activate. When all switches are active the exit opens.

@export var mesh: MeshInstance3D
@export var mat_inactive: Material   # PBR state A (e.g. dull / dark)
@export var mat_active: Material     # PBR state B (e.g. glowing / green)
@export var sfx: AudioStreamPlayer3D
@export var burst: GPUParticles3D

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
