extends Node3D
## SHADOW SIPHON - Game manager (attach to the root Main node3D)
## Win:  activate all switches, then reach the ExitArea.
## Lose: the guard catches you.   Press R to restart.
## Win / Game Over show an overlay with Restart and Main Menu buttons.

const MAIN_MENU := "res://main_menu.tscn"

@export var switches_needed := 2
@export var exit_door: Node3D       # StaticBody3D that blocks the exit (slides down when opened)
@export var exit_area: Area3D       # trigger zone just behind the door
@export var hud_label: Label
@export var message_label: Label
@export var health_bar: ProgressBar    # optional: bar showing the player's health
@export var damage_flash: ColorRect    # optional: red full-screen rectangle that flashes when hit

var switches_done := 0
var exit_open := false
var finished := false
var won := false

# "Press E" bubble (built in code, shown by player.gd)
var _prompt_root: VBoxContainer
var _prompt_label: Label
var _prompt_world := Vector3.ZERO
var _prompt_on := false

# Health bar visuals (built in code)
var _hp_root: Control
var _hp_fill: StyleBoxFlat
var _hp_label: Label
var _hp_shown := 100.0

# Win / Game Over overlay (built in code)
var _end_root: Control
var _end_title: Label
var _restart_btn: Button


func _enter_tree() -> void:
	add_to_group("game")


func _ready() -> void:
	_build_health_ui()
	_build_prompt_ui()
	_build_end_ui()
	if exit_area:
		exit_area.body_entered.connect(_on_exit_body_entered)
	if message_label:
		message_label.text = ""
	if damage_flash:
		damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		damage_flash.modulate.a = 0.0
	if health_bar:
		health_bar.show_percentage = false


func _process(delta: float) -> void:
	_update_prompt_position()
	var p = get_tree().get_first_node_in_group("player")
	_update_health_bar(p, delta)
	if hud_label == null:
		return
	var a = get_tree().get_first_node_in_group("antagonist")
	var txt := "Switches: %d / %d" % [switches_done, switches_needed]
	if p:
		txt += "\nYou are: " + ("LIT" if p.is_lit else "HIDDEN")
	if a:
		txt += "\nGuard: " + a.state_name()
	if exit_open:
		txt += "\nEXIT OPEN - GO!"
	hud_label.text = txt


func switch_activated() -> void:
	switches_done += 1
	if switches_done >= switches_needed and not exit_open:
		_open_exit()


func _open_exit() -> void:
	exit_open = true
	if exit_door:
		var t := create_tween()
		t.tween_property(exit_door, "position:y", exit_door.position.y - 3.0, 1.0)
		t.tween_callback(exit_door.queue_free)


func _on_exit_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and exit_open and not finished:
		win()


# Creates the health bar and the red damage flash by code if you haven't assigned your own,
# so no editor setup is needed for them.
func _build_health_ui() -> void:
	if health_bar != null and damage_flash != null:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	if damage_flash == null:
		damage_flash = ColorRect.new()
		damage_flash.color = Color(1, 0, 0)
		damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(damage_flash)
	if health_bar == null:
		_build_health_bar(layer)


# ---------------- HEALTH BAR ----------------
# Rounded bar in the bottom-left corner. Green -> yellow -> red as health drops,
# drains smoothly, and shows "HP 80 / 100" on top of the bar.
func _build_health_bar(layer: CanvasLayer) -> void:
	_hp_root = Control.new()
	_hp_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_root.anchor_left = 0.0
	_hp_root.anchor_right = 0.0
	_hp_root.anchor_top = 1.0
	_hp_root.anchor_bottom = 1.0
	_hp_root.offset_left = 28.0
	_hp_root.offset_right = 348.0      # 320 px wide
	_hp_root.offset_top = -72.0
	_hp_root.offset_bottom = -28.0     # 44 px tall
	layer.add_child(_hp_root)

	# Outer frame
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.06, 0.08, 0.88)
	frame_style.border_color = Color(0.85, 0.88, 0.95, 0.9)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", frame_style)
	_hp_root.add_child(frame)

	# The bar itself, inset a few pixels inside the frame
	health_bar = ProgressBar.new()
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.anchor_right = 1.0
	health_bar.anchor_bottom = 1.0
	health_bar.offset_left = 5.0
	health_bar.offset_top = 5.0
	health_bar.offset_right = -5.0
	health_bar.offset_bottom = -5.0
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.16, 0.17, 0.2, 1.0)
	bar_bg.set_corner_radius_all(10)
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = Color(0.25, 0.85, 0.4)
	_hp_fill.set_corner_radius_all(10)
	health_bar.add_theme_stylebox_override("background", bar_bg)
	health_bar.add_theme_stylebox_override("fill", _hp_fill)
	_hp_root.add_child(health_bar)

	# Text on top of the bar
	_hp_label = Label.new()
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.anchor_right = 1.0
	_hp_label.anchor_bottom = 1.0
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hp_label.add_theme_constant_override("outline_size", 5)
	_hp_root.add_child(_hp_label)


func _update_health_bar(p, delta: float) -> void:
	if p == null or health_bar == null:
		return
	health_bar.max_value = p.max_health
	_hp_shown = move_toward(_hp_shown, p.health, 60.0 * delta)   # smooth drain
	health_bar.value = _hp_shown
	if _hp_fill:
		var ratio: float = p.health / p.max_health
		var c := Color(0.25, 0.85, 0.4)         # green
		if ratio <= 0.3:
			c = Color(0.92, 0.2, 0.2)           # red
		elif ratio <= 0.6:
			c = Color(0.96, 0.76, 0.2)          # yellow
		_hp_fill.bg_color = c
	if _hp_label:
		_hp_label.text = "HP  %d / %d" % [int(p.health), int(p.max_health)]


# ---------------- "PRESS E" BUBBLE ----------------
func _build_prompt_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt_root = VBoxContainer.new()
	_prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.visible = false
	layer.add_child(_prompt_root)

	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.88)
	style.border_color = Color(1.0, 0.85, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	bubble.add_theme_stylebox_override("panel", style)
	_prompt_root.add_child(bubble)

	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 22)
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(_prompt_label)


func show_prompt(text: String, world_pos: Vector3) -> void:
	if _prompt_root == null or finished:
		return
	if _prompt_label.text != text:
		_prompt_label.text = text
		_prompt_root.reset_size()
	_prompt_world = world_pos
	_prompt_on = true


func hide_prompt() -> void:
	_prompt_on = false
	if _prompt_root:
		_prompt_root.visible = false


# Keeps the bubble stuck above the object it belongs to
func _update_prompt_position() -> void:
	if _prompt_root == null:
		return
	var cam := get_viewport().get_camera_3d()
	if not _prompt_on or finished or cam == null or cam.is_position_behind(_prompt_world):
		_prompt_root.visible = false
		return
	var screen := cam.unproject_position(_prompt_world)
	_prompt_root.visible = true
	_prompt_root.position = screen - Vector2(_prompt_root.size.x * 0.5, _prompt_root.size.y + 6.0)


# Quick red flash on the screen when the player is hit.
func flash_damage() -> void:
	if damage_flash == null:
		return
	damage_flash.modulate.a = 0.45
	var t := create_tween()
	t.tween_property(damage_flash, "modulate:a", 0.0, 0.4)
	if _hp_root:
		_hp_root.modulate = Color(1.7, 0.6, 0.6)       # bar pulses red when hit
		var t2 := create_tween()
		t2.tween_property(_hp_root, "modulate", Color(1, 1, 1), 0.35)


# Burst of sparks at pos + a short camera shake. Called when the guard's hit lands on the player.
func hit_effect(pos: Vector3) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 24
	sparks.lifetime = 0.5
	sparks.spread = 180.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	sparks.scale_amount_curve = shrink
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.2)
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.material = mat
	sparks.mesh = mesh
	add_child(sparks)
	sparks.global_position = pos
	sparks.finished.connect(sparks.queue_free)
	_shake_camera(0.25, 0.35)


func _shake_camera(strength: float, duration: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		create_tween().tween_method(_shake_step.bind(cam, strength), 1.0, 0.0, duration)


# Random camera offset that fades out as k goes 1 -> 0 (the last step is exactly 0 = no offset).
func _shake_step(k: float, cam: Camera3D, strength: float) -> void:
	cam.h_offset = randf_range(-1.0, 1.0) * strength * k
	cam.v_offset = randf_range(-1.0, 1.0) * strength * k


func win() -> void:
	if finished:
		return
	finished = true
	won = true
	_stop_player()
	_show_end("YOU ESCAPED!", Color(0.4, 1.0, 0.55))


func lose() -> void:
	if finished:
		return
	finished = true
	_stop_player()
	_show_end("GAME OVER", Color(1.0, 0.3, 0.3))


func restart() -> void:
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


# ---------------- WIN / GAME OVER OVERLAY ----------------
func _build_end_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_end_root = ColorRect.new()
	_end_root.color = Color(0, 0, 0, 0.7)
	_end_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_root.visible = false
	layer.add_child(_end_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 64)
	box.add_child(_end_title)

	_restart_btn = _end_button("Restart (R)", restart, box)
	_end_button("Main Menu", go_to_menu, box)


func _end_button(text: String, on_press: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _show_end(title: String, color: Color) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", color)
	_end_root.visible = true
	_restart_btn.grab_focus()


func _stop_player() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p:
		p.active = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		restart()
