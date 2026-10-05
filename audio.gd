extends Node
## SHADOW SIPHON - Audio manager (attach to a plain Node named "Audio" under Main)
## Children: 3 AudioStreamPlayer nodes -> assign them to bgm / alert / victory below.
##  - bgm      : background music, plays while the guard is on PATROL
##  - alert    : detection sound, plays while the guard is on CHASE or INVESTIGATE
##  - victory  : victory theme, plays once when you win
## When the guard calms down, the alert fades out and the bgm fades back in.

@export var bgm: AudioStreamPlayer
@export var alert: AudioStreamPlayer
@export var victory: AudioStreamPlayer
@export var bgm_db := -8.0
@export var alert_db := -4.0
@export var victory_db := -2.0
@export var fade_speed := 40.0      # decibels per second (higher = faster fade)

var _game = null
var _guard = null
var _ended := false


func _ready() -> void:
	if bgm:
		bgm.volume_db = bgm_db
		bgm.play()
	if alert:
		alert.stop()
		alert.volume_db = -80.0
	if victory:
		victory.stop()


func _process(delta: float) -> void:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	if _guard == null:
		_guard = get_tree().get_first_node_in_group("antagonist")

	# Game over (win or lose)
	if _game and _game.finished:
		if not _ended:
			_ended = true
			if _game.won and victory:
				victory.volume_db = victory_db
				victory.play()
		_fade(bgm, -80.0, delta)
		_fade(alert, -80.0, delta)
		return

	var alerted: bool = _guard != null and _guard.state_name() != "PATROL"

	if alerted:
		_fade(bgm, -80.0, delta)
		if alert and not alert.playing:
			alert.volume_db = alert_db     # starts at full volume so the sting is heard
			alert.play()
		_fade(alert, alert_db, delta)
	else:
		_fade(bgm, bgm_db, delta)
		_fade(alert, -80.0, delta)
		if alert and alert.playing and alert.volume_db <= -79.0:
			alert.stop()


func _fade(p: AudioStreamPlayer, target: float, delta: float) -> void:
	if p:
		p.volume_db = move_toward(p.volume_db, target, fade_speed * delta)
