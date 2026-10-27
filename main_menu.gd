extends Control
## SHADOW SIPHON - Main menu (Play starts the game, Quit closes it)

const GAME_SCENE := "res://main.tscn"


func _ready() -> void:
	%Play.pressed.connect(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
	%Quit.pressed.connect(get_tree().quit)
	%Play.grab_focus()
