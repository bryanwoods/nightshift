class_name ClockHUD
extends CanvasLayer
## Top-right clock, always on screen outside menus. Rewind charges sit beside it once the watch is owned.
## When minutes are spent, the cost flies from Tadzio to the clock and the changed digits roll.

const FLY := 0.6
const ROLL := 0.3
const BUMP := 0.2
const SIZE := 16

var _panel: Panel
var _box: StyleBoxFlat
var _digits: Control
var _pops: Control
var _icons: Array[TextureRect] = []
var _t: float = 0.0
var _minute: int = -1
var _text: String = ""
var _old: String = ""
var _rolled: float = ROLL + BUMP
## Each one is [minutes, where it started, seconds in the air, the clock text it lands with].
var _flying: Array = []


func _ready() -> void:
	layer = 10
	_panel = Panel.new()
	_box = StyleBoxFlat.new()
	_box.bg_color = Game.color("ink")
	_box.border_color = Game.color("dusk")
	_box.set_border_width_all(1)
	_box.set_corner_radius_all(2)
	_panel.add_theme_stylebox_override("panel", _box)
	_panel.position = Vector2(283, 3)
	_panel.size = Vector2(34, 16)
	add_child(_panel)
	_digits = Control.new()
	_digits.position = Vector2(284, 3)
	_digits.size = Vector2(32, 15)
	_digits.clip_contents = true
	_digits.draw.connect(_draw_digits)
	add_child(_digits)
	_pops = Control.new()
	_pops.draw.connect(_draw_pops)
	add_child(_pops)
	var tex: Texture2D = load("res://assets/sprites/watch_icon.png")
	for i in int(Game.tuning.get("rewind_charges", 3)):
		var icon := TextureRect.new()
		icon.texture = tex
		icon.position = Vector2(273 - i * 9, 7)
		add_child(icon)
		_icons.append(icon)
	NightClock.minute_passed.connect(_on_minute)
	Game.charges_changed.connect(_update)
	Game.flag_set.connect(func(_f: String) -> void: _update())
	_minute = NightClock.minute
	_text = NightClock.text()
	_update()


func _on_minute(minute: int) -> void:
	var spent := minute - _minute
	var from := _minute
	_minute = minute
	if from < 0 or spent <= 0 or minute >= NightClock.HOUR or not visible:
		_flying.clear()
		_text = NightClock.text()
		_rolled = ROLL + BUMP
	else:
		_flying.append([spent, _source(), 0.0, NightClock.text()])


## Above Tadzio's head while he walks the town. Under the clock in a fight or a menu.
func _source() -> Vector2:
	var room: Room = get_parent().get("room")
	if room == null or room.player == null or Game.in_battle or Game.busy:
		return _panel.position + Vector2(4, 30)
	return room.get_viewport().get_canvas_transform() * (room.player.position + Vector2(-4, -26))


func _update() -> void:
	var has_watch := Game.has_flag("has_watch")
	for i in _icons.size():
		_icons[i].visible = has_watch
		_icons[i].modulate = Color.WHITE if i < Game.rewind_charges else Color(1, 1, 1, 0.25)


func _process(delta: float) -> void:
	_t += delta
	_rolled += delta
	for f: Array in _flying:
		f[2] = float(f[2]) + delta
	while not _flying.is_empty() and float(_flying[0][2]) >= FLY:
		_old = _text
		_text = str(_flying.pop_front()[3])
		_rolled = 0.0
	_box.border_color = Game.color("lamp" if _rolled < BUMP else "dusk")
	_digits.queue_redraw()
	_pops.queue_redraw()


func _color() -> Color:
	if Game.time_state == Game.TimeState.EVENING:
		return Game.color("fog")
	if NightClock.minute >= int(Game.tuning.get("clock_pulse_minute", 55)) and fmod(_t, 1.0) < 0.5:
		return Game.color("ember")
	return Game.color("moon")


func _draw_digits() -> void:
	var font := _digits.get_theme_default_font()
	var base := Vector2(4, font.get_ascent(SIZE))
	var p := 1.0 - pow(1.0 - clampf(_rolled / ROLL, 0.0, 1.0), 2.0)
	for i in _text.length():
		var at := base + Vector2(font.get_string_size(_text.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x, 0)
		if p >= 1.0 or i >= _old.length() or _old[i] == _text[i]:
			_digits.draw_string(font, at, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, _color())
		else:
			var rise := roundf(p * 14.0)
			_digits.draw_string(font, at - Vector2(0, rise), _old[i], HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, _color())
			_digits.draw_string(font, at + Vector2(0, 14 - rise), _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Game.color("lamp"))


func _draw_pops() -> void:
	var font := _pops.get_theme_default_font()
	for f: Array in _flying:
		var p := clampf(float(f[2]) / FLY, 0.0, 1.0)
		var from: Vector2 = f[1]
		var at := (from.lerp(_panel.position + Vector2(8, 14), p * p * (3.0 - 2.0 * p)) - Vector2(0, 6.0 * sin(p * PI))).round()
		var text := "-%d" % int(f[0])
		_pops.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, 2, Game.color("ink"))
		_pops.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Game.color("lamp"))
