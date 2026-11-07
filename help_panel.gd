extends ColorRect
## SHADOW SIPHON - "How to Play" screen: the controls, a few tips and the Music / SFX volume sliders.
## Built in code. The main menu and the pause menu each add one as a child, call open() and listen for closed.

signal closed

const CLICK := preload("res://button-click.mp3")
const KEY_COLOR := Color(1.0, 0.85, 0.4)
const CONTROLS := [
	["W A S D", "Move"],
	["Shift (hold)", "Sneak: slower, but guards see you from less far away"],
	["E", "Use a lamp or a wall switch"],
	["Space", "Attack with your upper body; you can swing while walking"],
	["R", "Restart the level"],
	["Esc", "Pause"],
]
const TIPS := [
	"Lit lamps expose you from far away. In shadow guards only notice you up close.",
	"E on a lamp turns it off (shadows to hide in) and its noise lures guards within 14 m.",
	"Space hits a guard: three hits take him down, but the scuffle alerts nearby guards.",
	"Activate every wall switch to unlock the exit door, then reach it.",
]

var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # also works while the game is paused
	color = Color(0, 0, 0, 0.85)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)     # (we are already in the tree, so reset the offsets too)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.96)
	style.border_color = Color(0.85, 0.88, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := _label("HOW TO PLAY", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for row in CONTROLS:
		grid.add_child(_label(row[0], 20, KEY_COLOR))
		grid.add_child(_label(row[1], 20))
	for tip in TIPS:
		var t := _label("•  " + tip, 16, Color(0.85, 0.88, 0.95))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 700
		box.add_child(t)
	box.add_child(_label("Volume", 20, KEY_COLOR))
	box.add_child(volume_sliders())

	_back = Button.new()
	_back.text = "Back (Esc)"
	_back.custom_minimum_size = Vector2(260, 56)
	_back.add_theme_font_size_override("font_size", 24)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	box.add_child(_back)


func open() -> void:
	visible = true
	_back.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# Music and SFX volume rows (also used by the pause menu). Settings saves them and applies them to the audio buses.
static func volume_sliders() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var blip := AudioStreamPlayer.new()                  # plays when the SFX slider is released, so the level can be heard
	blip.stream = CLICK
	blip.bus = &"SFX"
	box.add_child(blip)
	for bus in ["Music", "SFX"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var name_label := _label(bus, 20)
		name_label.custom_minimum_size.x = 70
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(220, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.get_volume(bus)
		row.add_child(slider)
		var percent := _label("%d%%" % roundi(slider.value * 100.0), 20)
		percent.custom_minimum_size.x = 52
		row.add_child(percent)
		slider.value_changed.connect(func(v: float) -> void:
			Settings.set_volume(bus, v)
			percent.text = "%d%%" % roundi(v * 100.0))
		if bus == "SFX":
			slider.drag_ended.connect(func(_changed: bool) -> void: blip.play(0.15))     # the click starts 0.16 s in
	return box


static func _label(text: String, size: int, font_color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", font_color)
	return l
