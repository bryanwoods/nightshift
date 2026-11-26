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
var token_tint: Color = Color.WHITE

var _clip: Control
var _layer: Node2D
var _box: StyleBoxFlat
var _tex: Dictionary = {}
var _glow: Texture2D
var _token: Texture2D
var _c: Dictionary = {}


func _ready() -> void:
	for n in ["ink", "night", "dusk", "slate", "fog", "moon", "ember", "hush", "wake", "lamp", "moss", "honey", "peach", "rosewood", "violet", "aqua", "seafoam", "froth"]:
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
	if pattern and pattern.plate:
		var rim := (half - Vector2.ONE) * minf(1.0, pattern.t / 0.4)
		_ellipse(Vector2.ZERO, rim, _c["fog"])
		_ellipse(Vector2.ZERO, rim - Vector2(4, 4), _c["slate"])
		_ellipse(Vector2.ZERO, rim * 0.62, _c["dusk"])
		_ellipse(Vector2.ZERO, rim * 0.62 - Vector2(1.5, 1.5), _c["slate"])
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
	if pattern and pattern.fog > 0.0:
		var pink := Color(_c["hush"].lerp(_c["moon"], 0.55), pattern.fog)
		_layer.draw_rect(Rect2(-half, size), pink)
		for i in 9:
			var at := Vector2(sin(i * 2.4 + pattern.t * 0.7) * half.x * 0.8, cos(i * 1.7 + pattern.t * 0.5) * half.y * 0.7)
			_layer.draw_circle(at, 12.0 + 4.0 * sin(i + pattern.t), Color(_c["moon"], 0.35 * pattern.fog))
	if token_visible and pattern and pattern.catcher:
		var at := token.round()
		if invuln <= 0.0 or fmod(invuln, 0.1) < 0.05:
			_layer.draw_texture_rect_region(_texture("tadzio"), Rect2(at + Vector2(-8, -1), Vector2(16, 32)), Rect2(0, 0, 16, 32))
		_layer.draw_rect(Rect2(at + Vector2(-5, 0), Vector2(10, 1)), _c["fog"])
		_layer.draw_rect(Rect2(at + Vector2(-10, -2), Vector2(20, 2)), _c["moon"])
		var shown := pattern.stack.slice(-8)
		for i in shown.size():
			var sway := roundf(sin(pattern.t * 5.0 + i) * minf(2.0, i * 0.4))
			_layer.draw_texture(_texture(shown[i]), at + Vector2(-4 + sway, -10 - i * 5))
	elif token_visible:
		_layer.draw_texture(_glow, (token - _glow.get_size() / 2.0).round(), Color(token_tint, 0.9))
		if invuln <= 0.0 or fmod(invuln, 0.1) < 0.05:
			_layer.draw_texture(_token, (token - Vector2(3, 3)).round(), token_tint)
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
		Pattern.Kind.STAFF:
			var ax := Vector2.from_angle(b.steer) * b.width / 2.0
			var ay := Vector2.from_angle(b.steer).orthogonal()
			for i in 5:
				var o := b.pos + ay * (i * 2.0 - 4.0)
				_layer.draw_line(o - ax, o + ax, col, 1.0)
			for end in [-ax, ax]:
				_layer.draw_line(b.pos + end - ay * 4.0, b.pos + end + ay * 4.0, col, 1.0)
		Pattern.Kind.BLADE:
			var gliding := b.radius >= Pattern.BLADE_HOLD
			var shade := Color(_c["hush"].lerp(_c["moon"], 0.6), 1.0 if gliding or fmod(b.radius, 0.16) < 0.1 else 0.5)
			var blade := PackedVector2Array([Vector2(9, 0), Vector2(1, -3), Vector2(-9, -0.5), Vector2(-9, 0.5), Vector2(1, 3)])
			if gliding:
				var a := (b.pos - b.anchor).angle()
				for k: int in [3, 2, 1]:
					var back := a - signf(b.gap) * 0.12 * k
					var ghost := Transform2D(back + signf(b.gap) * PI / 2.0, b.anchor + Vector2.from_angle(back) * b.width)
					_layer.draw_colored_polygon(ghost * blade, Color(shade, 0.12 * (4 - k)))
			_layer.draw_colored_polygon(Transform2D(b.steer, b.pos) * blade, shade)
		Pattern.Kind.FENCE:
			var wood := Game.color("honey")
			var left := b.pos.x - b.width / 2.0
			var top := b.pos.y - b.radius
			for x in [left, left + b.width - 2.0]:
				_layer.draw_rect(Rect2(x, top, 2, b.radius * 2.0), wood)
			for y in [top + 2.0, top + 6.0]:
				_layer.draw_rect(Rect2(left - 2.0, y, b.width + 4.0, 1), wood)
		Pattern.Kind.FORK:
			var tip := pattern.fork_tip(b)
			if tip == -INF:
				_ellipse(b.pos, Vector2(3, 1.5) + Vector2(5, 2) * b.radius / b.gap, Color(_c["ink"], 0.5))
				if fmod(b.radius, 0.2) < 0.14:
					var font := _clip.get_theme_default_font()
					var at := b.pos + Vector2(-font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x / 2.0, -6)
					_layer.draw_string_outline(font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 4, _c["ink"])
					_layer.draw_string(font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, _c["ember"])
			else:
				var neck := tip - Pattern.FORK_TINES
				for x: float in [-5.0, -1.0, 3.0]:
					_layer.draw_rect(Rect2(b.pos.x + x, neck, 2, Pattern.FORK_TINES), _c["moon"])
				_layer.draw_rect(Rect2(b.pos.x - 5, neck - 3, 10, 3), _c["moon"])
				_layer.draw_rect(Rect2(b.pos.x - 2, -half.y, 4, maxf(0.0, neck - 3 + half.y)), _c["fog"])
		Pattern.Kind.BLOCK:
			_layer.draw_rect(Rect2(b.pos.x - b.width / 2.0 + 0.5, b.pos.y - b.radius, b.width - 1.0, b.radius * 2.0), col)
		Pattern.Kind.LANE:
			var d := Vector2.from_angle(b.steer)
			if b.radius < b.gap:
				_layer.draw_line(b.pos, b.pos + d * size.length(), Color(col, 0.25), 1.0)
			else:
				_layer.draw_line(b.pos, b.pos + d * pattern.lane_reach(b), col, b.width)
		Pattern.Kind.GRASS:
			var warning := b.radius < b.gap
			if warning and int(b.radius * 10.0) % 2 == 1:
				return
			var d := Vector2.from_angle(b.steer)
			var n := d.orthogonal()
			var length := pattern.grass_length(b)
			var dark_c := Game.color(str(pattern.params.get("blade_dark", "moss")))
			var light_c := Game.color(str(pattern.params.get("blade", "wake")))
			var lean := float(int(absf(b.pos.x * 7.0 + b.pos.y * 13.0)) % 5 - 2)
			for k: int in [0, 2, 1]:
				var h: float = length * [0.75, 1.0, 0.6][k]
				var bend: float = (lean + (k - 1) * 1.5) * h / 14.0
				var base := b.pos + n * (k - 1) * 2.0
				var tip: Vector2 = base + d * h + n * bend
				var mid: Vector2 = base + d * h * 0.55 + n * bend * 0.3
				var blade := PackedVector2Array([base - n * 1.8, mid - n * 1.2, tip, mid + n * 1.2, base + n * 1.8])
				_layer.draw_colored_polygon(blade, dark_c if k != 1 else (Color(light_c, 0.7) if warning else light_c))
			_layer.draw_rect(Rect2(b.pos - n.abs() * b.width / 2.0 - d.abs(), n.abs() * b.width + d.abs() * 2.0), dark_c)
		Pattern.Kind.GOO:
			for x in range(int(-half.x), int(half.x)):
				var e := pattern.goo_edge(b, x + 0.5)
				if e <= -half.y:
					continue
				_layer.draw_rect(Rect2(x, -half.y, 1, e + half.y), _c["moon"])
				_layer.draw_rect(Rect2(x, e - 3.0, 1, 2), _c["peach"])
				_layer.draw_rect(Rect2(x, e - 1.0, 1, 1), _c["rosewood"])
				var shine := -half.y + (e + half.y) * (0.45 + 0.12 * sin(x * 0.2 + b.radius * 1.7))
				_layer.draw_rect(Rect2(x, shine, 1, 1), _c["froth"])
			for i in b.parts.size() / 3:
				var dx := b.parts[i * 3]
				var tip := pattern.goo_edge(b, dx)
				if tip > -half.y + 3.0:
					_layer.draw_circle(Vector2(dx, tip - 1.0), 2.5, _c["rosewood"])
					_layer.draw_circle(Vector2(dx, tip - 1.5), 2.0, _c["peach"])
					_layer.draw_circle(Vector2(dx - 0.5, tip - 2.5), 1.0, _c["moon"])
		Pattern.Kind.BLAZE:
			if b.radius < b.gap:
				if int(b.radius * 8.0) % 2 == 0:
					for x in range(int(-half.x), int(half.x)):
						var h := 2.0 + 2.0 * absf(sin(x * 0.7 + b.radius * 10.0))
						_layer.draw_rect(Rect2(x, half.y - h, 1, h), _c["violet"])
				return
			for x in range(int(-half.x), int(half.x)):
				var e := pattern.blaze_edge(b, x + 0.5)
				var h := half.y - e
				if h <= 0.0:
					continue
				_layer.draw_rect(Rect2(x, e, 1, h), _c["violet"])
				for band: Array in [[0.22, 0.0, "aqua"], [0.5, 1.7, "seafoam"], [0.78, 3.1, "froth"]]:
					var f: float = band[0] + 0.1 * sin(x * 0.29 - b.radius * 9.0 + band[1])
					_layer.draw_rect(Rect2(x, e + h * f, 1, h * (1.0 - f)), _c[band[2]])
				if sin(x * 2.7 + b.radius * 20.0) > 0.93:
					_layer.draw_rect(Rect2(x, e - 2.0 - 5.0 * fmod(b.radius * 3.0 + x * 0.37, 1.0), 1, 1), _c["violet"])
		Pattern.Kind.SPIKES:
			var side := Vector2.from_angle(b.steer)
			var along := side.orthogonal()
			var wall := side * absf(side.dot(half))
			var depth := Pattern.SPIKE_DEPTH * minf(1.0, b.radius / 0.5)
			var a := b.gap
			while a + 8.0 <= b.gap_center + 0.01:
				var tri := PackedVector2Array([wall + along * a, wall + along * (a + 8.0), wall + along * (a + 4.0) - side * depth])
				_layer.draw_colored_polygon(tri, _c["moon"])
				_layer.draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), _c["rosewood"], 1.0)
				a += 8.0
		Pattern.Kind.TREE:
			var foot := b.pos.y + 2.0
			var length := pattern.trunk_length(b)
			var trunk := _texture("tree_trunk")
			var shown := minf(length + 2.0, trunk.get_height())
			_layer.draw_texture_rect_region(trunk, Rect2(b.pos.x - 9, foot - shown, 18, shown), Rect2(0, trunk.get_height() - shown, 18, shown))
			var branch := _texture("tree_branch")
			for i in b.parts.size() / 3:
				var reach := pattern.branch_reach(b, i)
				var y := b.pos.y - b.parts[i * 3]
				var side := b.parts[i * 3 + 1]
				if reach == -0.5:
					if int(b.radius * 8.0) % 2 == 0:
						_layer.draw_line(Vector2(b.pos.x, y), Vector2(b.pos.x + side * half.x, y), Color(_c["honey"], 0.5), 1.0)
					continue
				reach = minf(reach, 54.0)
				if reach < 1.0:
					continue
				if side > 0.0:
					_layer.draw_texture_rect_region(branch, Rect2(b.pos.x + 2, y - 8, reach, 16), Rect2(0, 0, reach, 16))
				else:
					_layer.draw_texture_rect_region(branch, Rect2(b.pos.x - 2 - reach, y - 8, reach, 16), Rect2(112 - reach, 0, reach, 16))
			var grown := (length / b.gap_center - 0.7) / 0.3
			if grown > 0.0:
				var crown := _texture("tree_crown")
				var tall := ceilf(crown.get_height() * minf(grown, 1.0))
				var top := foot - length - 2.0
				_layer.draw_texture_rect_region(crown, Rect2(b.pos.x - 20, top + 3 - tall, 40, tall), Rect2(0, crown.get_height() - tall, 40, tall))
		_:
			var tex := _texture(b.tex)
			if b.tex.begins_with("heart_crack") and pattern.t - b.gap_center < 0.15:
				_layer.draw_circle(b.pos, 4.0 + 50.0 * (pattern.t - b.gap_center), Color(_c["moon"], 0.7))
			if tex:
				if b.height > 0.0:
					_ellipse(b.pos.round() + Vector2(0, 2), Vector2(5, 2.5) * (1.0 - b.height / 80.0), Color(_c["slate"], 0.9))
				if b.gap < 0.0 and b.gap_center > -b.gap - 0.3 and int(b.gap_center * 12.0) % 2 == 0:
					return
				_layer.draw_texture(tex, (b.pos - Vector2(0, b.height) - tex.get_size() / 2.0).round())


func _ellipse(at: Vector2, r: Vector2, c: Color) -> void:
	if r.x <= 0.5 or r.y <= 0.5:
		return
	var points := PackedVector2Array()
	for i in 40:
		points.append(at + Vector2.from_angle(i / 40.0 * TAU) * r)
	_layer.draw_colored_polygon(points, c)


func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := "res://assets/sprites/%s.png" % name
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]
