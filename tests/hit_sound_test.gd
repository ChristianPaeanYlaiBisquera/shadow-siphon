extends SceneTree

# The hit sound plays once per landed hit (not for a hit blocked by i-frames) and the player node frees itself afterwards.

func _hit_players(g) -> int:
	return g.get_children().filter(func(c): return c is AudioStreamPlayer and c.stream == g.HIT_SOUND).size()


func _init() -> void:
	await process_frame                      # autoloads (Settings) are registered after _init
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var p = g.get_node("Player")
	var dur: float = g.HIT_SOUND.get_length()
	print("stream: ", g.HIT_SOUND.get_class(), " length: ", snappedf(dur, 0.01))
	print("hit sound players before hit (expect 0): ", _hit_players(g))
	p.take_damage(20.0)
	print("after hit (expect 1): ", _hit_players(g), " health: ", p.health)
	p.take_damage(20.0)   # blocked by i-frames, so no second sound
	print("after blocked hit (expect 1): ", _hit_players(g), " health: ", p.health)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int((dur + 0.6) * 1000.0):
		await process_frame
	print("after clip ends (expect 0): ", _hit_players(g))
	quit()
