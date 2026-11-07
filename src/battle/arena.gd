class_name Arena
extends Node2D
## The rounded box of the dodge phase: border, clipped bullets, the flashlight token, the Hustle bar.

var size: Vector2 = Vector2(120, 80)
var pattern: Pattern
var token: Vector2 = Vector2.ZERO
var token_visible: bool = false
var lit: bool = false
var invuln: float = 0.0
var hustle_t: float = -1.0
var hustle_zone: float = 0.22
var hit_flash: float = 0.0
var rewind_flash: float = 0.0

var _clip: Control
var _layer: Node2D
var _box: StyleBoxFlat
var _tex: Dictionary = {}
var _glow: Texture2D
var _token: Texture2D
var _c: Dictionary = {}


func _ready() -> void:
	for n in ["ink", "night", "dusk", "moon", "ember", "hush", "wake", "lamp"]:
		_c[n] = Game.color(n)
	_box = StyleBoxFlat.new()
	_box.bg_color = _c["ink"]
	_box.border_color = _c["moon"]
	_box.set_border_width_all(1)
	_box.set_corner_radius_all(4)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_layer = Node2D.new()
	_clip.add_child(_layer)
	_layer.draw.connect(_draw_layer)
	_glow = load("res://assets/sprites/glow.png")
	_token = load("res://assets/sprites/token.png")
	hustle_zone = float(Game.tuning.get("hustle", {}).get("center_zone", 0.22))
	set_size(size)


func set_size(s: Vector2) -> void:
	size = s.round()
	if _clip:
		_clip.position = -size / 2.0
		_clip.size = size
		_layer.position = size / 2.0
	queue_redraw()


func tween_size(s: Vector2, seconds: float = 0.25) -> void:
	if s.round() == size:
		return
	var tw := create_tween()
	tw.tween_method(set_size, size, s, seconds)
	await tw.finished


func _draw() -> void:
	draw_style_box(_box, Rect2(-size / 2.0 - Vector2(2, 2), size + Vector2(4, 4)))
	if pattern == null or (pattern.dark and not lit):
		return
	var col := Game.color(str(pattern.params.get("color", "moon")))
	for b in pattern.bullets:
		if b.kind == Pattern.Kind.LANE and b.radius < b.gap and (b.gap - b.radius > 0.25 or fmod(b.radius, 0.1) < 0.06):
			var d := Vector2.from_angle(b.steer)
			var at := b.pos - d * (10.0 + roundf(sin(b.radius * 9.0 + b.pos.x)))
			draw_line(at - d * 5.0, at + d * 5.0, col, 2.0)


func _process(delta: float) -> void:
	hit_flash = maxf(0.0, hit_flash - delta * 3.0)
	rewind_flash = maxf(0.0, rewind_flash - delta * 2.0)
	_layer.queue_redraw()
	queue_redraw()


func _draw_layer() -> void:
	var half := size / 2.0
	var dark := pattern != null and pattern.dark
	_layer.draw_rect(Rect2(-half, size), _c["ink"] if dark else _c["night"])
	if pattern and pattern.locked:
		var f := pattern.facing * Pattern.SHINE_REACH
		_layer.draw_colored_polygon(PackedVector2Array([token, token + f.rotated(Pattern.SHINE_HALF_ANGLE), token + f.rotated(-Pattern.SHINE_HALF_ANGLE)]), Color(_c["moon"], 0.3))
	if pattern and (not dark or lit):
		var col := Game.color(str(pattern.params.get("color", "moon")))
		for b in pattern.bullets:
			_draw_bullet(b, half, col)
		if pattern.charge > 0.0:
			var full := pattern.charge >= Pattern.CHARGE_FULL
			var ring := 3.0 + 6.0 * minf(1.0, pattern.charge / Pattern.CHARGE_FULL)
			_layer.draw_arc(token, ring, 0.0, TAU, 16, Color(_c["lamp"], 1.0 if full and fmod(pattern.charge, 0.2) < 0.1 else 0.5), 1.0)
	if token_visible:
		_layer.draw_texture(_glow, (token - _glow.get_size() / 2.0).round(), Color(1, 1, 1, 0.9))
		if invuln <= 0.0 or fmod(invuln, 0.1) < 0.05:
			_layer.draw_texture(_token, (token - Vector2(3, 3)).round())
	if hustle_t >= 0.0:
		var w := minf(100.0, size.x - 16.0)
		var zw := w * hustle_zone
		_layer.draw_rect(Rect2(-w / 2.0, -4, w, 8), _c["dusk"])
		_layer.draw_rect(Rect2(-zw / 2.0, -4, zw, 8), _c["ember"])
		_layer.draw_rect(Rect2(-w / 2.0 + w * hustle_t - 1.0, -7, 2, 14), _c["moon"])
	if hit_flash > 0.0:
		_layer.draw_rect(Rect2(-half, size), Color(_c["hush"], 0.35 * hit_flash))
	if rewind_flash > 0.0:
		_layer.draw_rect(Rect2(-half, size), Color(_c["wake"], 0.35 * rewind_flash))


func _draw_bullet(b: Pattern.Bullet, half: Vector2, col: Color) -> void:
	match b.kind:
		Pattern.Kind.BAR:
			var x := b.pos.x - b.width / 2.0
			var top := b.gap_center - b.gap / 2.0
			var bottom := b.gap_center + b.gap / 2.0
			_layer.draw_rect(Rect2(x, -half.y, b.width, top + half.y), col)
			_layer.draw_rect(Rect2(x, bottom, b.width, half.y - bottom), col)
		Pattern.Kind.RING:
			var n := 48
			var step := TAU / n
			for i in n:
				if absf(angle_difference(i * step + step / 2.0, b.gap_center)) <= b.gap / 2.0:
					continue
				_layer.draw_arc(b.pos, b.radius, i * step, (i + 1) * step, 3, col, b.width)
		Pattern.Kind.BLOCK:
			_layer.draw_rect(Rect2(b.pos.x - b.width / 2.0 + 0.5, b.pos.y - b.radius, b.width - 1.0, b.radius * 2.0), col)
		Pattern.Kind.LANE:
			var d := Vector2.from_angle(b.steer)
			if b.radius < b.gap:
				_layer.draw_line(b.pos, b.pos + d * size.length(), Color(col, 0.25), 1.0)
			else:
				_layer.draw_line(b.pos, b.pos + d * pattern.lane_reach(b), col, b.width)
		_:
			var tex := _texture(b.tex)
			if tex:
				_layer.draw_texture(tex, (b.pos - tex.get_size() / 2.0).round())


func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := "res://assets/sprites/%s.png" % name
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]
