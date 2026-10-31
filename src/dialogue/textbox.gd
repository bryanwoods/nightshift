class_name Textbox
extends CanvasLayer
## Bottom-of-screen box: portrait, name tab, typewriter text with blips, and a choice list.

signal done(choice: int)

const BOX_X := 4
const BOX_W := 312
const BOX_BOTTOM := 177
const PAD := 5
const PORTRAIT := 32
const MIN_H := 44

var _panel: Panel
var _portrait: TextureRect
var _name_panel: Panel
var _name: Label
var _text: Label
var _choice_labels: Array[Label] = []
var _more: TextureRect
var _waiting: bool = false
var _typing: bool = false
var _fast: bool = false
var _shown: float = 0.0
var _total: int = 0
var _pitch: float = 1.0
var _since_blip: int = 0
var _options: Array[String] = []
var _cursor: int = 0
var _auto: float = -1.0
var _auto_t: float = 0.0
var _last_press: int = -1
var _blink: float = 0.0


func _ready() -> void:
	layer = 20
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _box(Game.color("ink"), Game.color("fog")))
	add_child(_panel)
	_name_panel = Panel.new()
	_name_panel.add_theme_stylebox_override("panel", _box(Game.color("ink"), Game.color("lamp")))
	add_child(_name_panel)
	_name = _label(Game.color("lamp"))
	_portrait = TextureRect.new()
	_portrait.size = Vector2(PORTRAIT, PORTRAIT)
	add_child(_portrait)
	_text = _label(Game.color("moon"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_more = TextureRect.new()
	_more.texture = load("res://assets/sprites/marker.png")
	add_child(_more)
	visible = false


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


func _label(c: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	add_child(l)
	return l


func show_line(speaker_name: String, portrait: Texture2D, text: String, pitch: float, options: Array[String], auto: float) -> int:
	_pitch = pitch
	_options = options
	_cursor = 0
	_auto = auto
	_auto_t = 0.0
	_fast = false
	_shown = 0.0
	_since_blip = 0
	_portrait.texture = portrait
	_portrait.visible = portrait != null
	_name.text = speaker_name
	_name.visible = speaker_name != ""
	_name_panel.visible = _name.visible
	_text.text = text
	_text.visible_characters = 0
	_total = _text.get_total_character_count()
	_typing = _total > 0
	for l in _choice_labels:
		l.queue_free()
	_choice_labels.clear()
	for o in options:
		var l := _label(Game.color("moon"))
		l.text = o
		l.visible = false
		_choice_labels.append(l)
	_layout()
	visible = true
	_waiting = true
	if not _typing:
		_finish_typing()
	return await done


func _layout() -> void:
	var lh := float(_text.get_line_height())
	var text_x := BOX_X + PAD + (PORTRAIT + 6 if _portrait.visible else 2)
	_text.position = Vector2(text_x, 0)
	_text.size = Vector2(BOX_X + BOX_W - PAD - 2 - text_x, 0)
	var lines := maxi(1, _text.get_line_count())
	var content := lines * lh + (_options.size() * lh + 3 if not _options.is_empty() else 0.0)
	var h := maxf(maxf(content, PORTRAIT if _portrait.visible else 0.0) + PAD * 2, MIN_H)
	var top := BOX_BOTTOM - h
	_panel.position = Vector2(BOX_X, top)
	_panel.size = Vector2(BOX_W, h)
	_portrait.position = Vector2(BOX_X + PAD, top + PAD)
	_text.position.y = top + PAD - 2
	for i in _choice_labels.size():
		_choice_labels[i].position = Vector2(text_x + 8, top + PAD - 2 + lines * lh + 3 + i * lh)
	_name.position = Vector2(BOX_X + 8, top - 11)
	_name_panel.position = Vector2(BOX_X + 4, top - 10)
	_name_panel.size = Vector2(_name.get_minimum_size().x + 8, 11)
	_more.position = Vector2(BOX_X + BOX_W - 10, BOX_BOTTOM - 8)


func _process(delta: float) -> void:
	if not _waiting:
		return
	var autoplay := DialogueRunner.autoplay
	var frame := Engine.get_process_frames()
	var pressed := Input.is_action_just_pressed("confirm") and frame != _last_press
	if pressed:
		_last_press = frame
	if _typing:
		if pressed:
			if _fast:
				_finish_typing()
				return
			_fast = true
		elif Input.is_action_just_pressed("cancel"):
			_finish_typing()
			return
		var mult := float(Game.tuning.get("text_fast_multiplier", 4)) if _fast and Input.is_action_pressed("confirm") else 1.0
		if autoplay:
			mult = 40.0
		_shown += float(Game.tuning.get("text_cps", 30)) * SaveManager.text_speed() * mult * delta
		_reveal(mini(int(_shown), _total))
		return
	if _options.is_empty():
		_blink += delta
		_more.visible = _auto < 0 and fmod(_blink, 0.8) < 0.5
		if _auto >= 0:
			_auto_t += delta
			if _auto_t >= _auto:
				_emit(-1)
		elif pressed or autoplay:
			AudioBus.sfx("cursor", 1.0, -10.0)
			_emit(-1)
		return
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		_cursor = wrapi(_cursor + (1 if Input.is_action_just_pressed("move_down") else -1), 0, _options.size())
		AudioBus.sfx("cursor")
		_refresh_choices()
	if pressed or autoplay:
		AudioBus.sfx("confirm")
		_emit(_cursor)


func _reveal(n: int) -> void:
	if n == _text.visible_characters:
		return
	var every := int(Game.tuning.get("blip_every", 2))
	for i in range(_text.visible_characters, n):
		var ch := _text.text.substr(i, 1)
		if ch.strip_edges() == "":
			continue
		_since_blip += 1
		if _since_blip >= every:
			_since_blip = 0
			AudioBus.blip(_pitch)
	_text.visible_characters = n
	if n >= _total:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_blink = 0.0
	for l in _choice_labels:
		l.visible = true
	_refresh_choices()


func _refresh_choices() -> void:
	for i in _choice_labels.size():
		var on := i == _cursor
		_choice_labels[i].text = ("> " if on else "  ") + _options[i]
		_choice_labels[i].add_theme_color_override("font_color", Game.color("lamp") if on else Game.color("moon"))


func _emit(choice: int) -> void:
	_waiting = false
	_more.visible = false
	done.emit(choice)


func hide_box() -> void:
	visible = false


func close() -> void:
	visible = false
	if _waiting:
		_emit(-1)
