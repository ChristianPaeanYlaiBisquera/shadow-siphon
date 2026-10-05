extends Node3D
## SHADOW SIPHON - Game manager (attach to the root Main node3D)
## Win:  activate all switches, then reach the ExitArea.
## Lose: the guard catches you.   Press R to restart.

@export var switches_needed := 2
@export var exit_door: Node3D       # StaticBody3D that blocks the exit (slides down when opened)
@export var exit_area: Area3D       # trigger zone just behind the door
@export var hud_label: Label
@export var message_label: Label

var switches_done := 0
var exit_open := false
var finished := false
var won := false


func _enter_tree() -> void:
	add_to_group("game")


func _ready() -> void:
	if exit_area:
		exit_area.body_entered.connect(_on_exit_body_entered)
	if message_label:
		message_label.text = ""


func _process(_delta: float) -> void:
	if hud_label == null:
		return
	var p = get_tree().get_first_node_in_group("player")
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


func win() -> void:
	if finished:
		return
	finished = true
	won = true
	_stop_player()
	if message_label:
		message_label.text = "YOU ESCAPED!\nPress R to play again"


func lose() -> void:
	if finished:
		return
	finished = true
	_stop_player()
	if message_label:
		message_label.text = "CAUGHT!\nPress R to retry"


func _stop_player() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p:
		p.active = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
