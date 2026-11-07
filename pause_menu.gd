extends CanvasLayer
## SHADOW SIPHON - Pause menu (created by game.gd). Esc pauses / resumes. Buttons: Resume, Restart, How to Play, Main Menu,
## plus the Music / SFX volume sliders. Esc is ignored while the Win / Game Over screen is up.

const HelpPanel := preload("res://help_panel.gd")

var _game                      # the level (game.gd)
var _root: ColorRect
var _resume_btn: Button
var _howto_btn: Button
var _help


func _ready() -> void:
	_game = get_parent()
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS          # keeps working while the tree is paused
	_root = ColorRect.new()
	_root.color = Color(0, 0, 0, 0.7)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)
	_resume_btn = _game.make_button("Resume (Esc)", toggle, box)
	_game.make_button("Restart", func() -> void: _leave(_game.restart), box)
	_howto_btn = _game.make_button("How to Play", func() -> void: _help.open(), box)
	_game.make_button("Main Menu", func() -> void: _leave(_game.go_to_menu), box)
	box.add_child(HelpPanel.volume_sliders())
	_help = HelpPanel.new()
	_help.closed.connect(_howto_btn.grab_focus)
	add_child(_help)                                 # drawn above the pause screen


func toggle() -> void:
	if _game.finished:
		return
	var pause := not get_tree().paused
	get_tree().paused = pause
	_root.visible = pause
	if pause:
		_resume_btn.grab_focus()


# Leaves the level (restart / main menu): the tree must not stay paused in the next scene.
func _leave(action: Callable) -> void:
	get_tree().paused = false
	action.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()
