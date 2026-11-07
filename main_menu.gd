extends Control
## SHADOW SIPHON - Main menu (Play starts the game, How to Play shows the controls and volume sliders, Quit closes it)

const GAME_SCENE := "res://main.tscn"
const HelpPanel := preload("res://help_panel.gd")


func _ready() -> void:
	var help := HelpPanel.new()
	add_child(help)                    # drawn on top of the menu
	help.closed.connect(%HowTo.grab_focus)
	%HowTo.pressed.connect(help.open)
	%Play.pressed.connect(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
	%Quit.pressed.connect(get_tree().quit)
	%Play.grab_focus()
