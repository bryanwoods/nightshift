class_name ClockHUD
extends CanvasLayer
## Top-right clock, always on screen outside menus. Rewind charges sit beside it once the watch is owned.

var _panel: Panel
var _label: Label
var _icons: Array[TextureRect] = []
var _t: float = 0.0


func _ready() -> void:
	layer = 10
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.color("ink")
	sb.border_color = Game.color("dusk")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(283, 3)
	_panel.size = Vector2(34, 16)
	add_child(_panel)
	_label = Label.new()
	_label.position = Vector2(288, 3)
	add_child(_label)
	var tex: Texture2D = load("res://assets/sprites/watch_icon.png")
	for i in int(Game.tuning.get("rewind_charges", 3)):
		var icon := TextureRect.new()
		icon.texture = tex
		icon.position = Vector2(273 - i * 9, 7)
		add_child(icon)
		_icons.append(icon)
	NightClock.minute_passed.connect(func(_m: int) -> void: _update())
	Game.charges_changed.connect(_update)
	Game.flag_set.connect(func(_f: String) -> void: _update())
	_update()


func _update() -> void:
	_label.text = NightClock.text()
	var has_watch := Game.has_flag("has_watch")
	for i in _icons.size():
		_icons[i].visible = has_watch
		_icons[i].modulate = Color.WHITE if i < Game.rewind_charges else Color(1, 1, 1, 0.25)


func _process(delta: float) -> void:
	_t += delta
	var c := Game.color("moon")
	if not NightClock.started:
		c = Game.color("fog")
	elif NightClock.minute >= int(Game.tuning.get("clock_pulse_minute", 55)) and fmod(_t, 1.0) < 0.5:
		c = Game.color("ember")
	_label.add_theme_color_override("font_color", c)
