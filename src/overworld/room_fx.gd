class_name RoomFx
extends Node2D
## Small motion that a room draws in code. Below the actors: shadows, puddle ripples and
## reflections, the flicker of lit shop windows. Above them: moths at lit lamps
## and dust in the flashlight beam.

const MOTH_FROM: Array[Vector2] = [Vector2(-90, 10), Vector2(80, -20), Vector2(-20, -60)]

var room: Room
var above: bool = false

var _water: Dictionary = {}
var _panes: Array[Vector2i] = []
var _images: Dictionary = {}
var _moths: Dictionary = {}
var _dust: Array[Vector3] = []
var _t: float = 0.0


func _ready() -> void:
	for p in room.tile_pixels("puddle", "night"):
		_water[p] = true
	_panes = room.tile_pixels("shop_window_lit", "lamp")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		_dust.append(Vector3(rng.randf() * Room.BEAM_LENGTH, rng.randf_range(-20, 20), rng.randf() * TAU))


func _process(delta: float) -> void:
	_t += delta
	for post: Sprite2D in room.lamp_posts() if above else {}:
		var lit: bool = (room.lamp_posts()[post] as PointLight2D).enabled
		var k := float(_moths.get(post, 1.0 if lit else 0.0))
		_moths[post] = clampf(k + (delta / 2.0 if lit else -delta / 1.2), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if room.player == null:
		return
	var t := _t
	if above:
		_draw_moths(t)
		_draw_dust(t)
		return
	var actors := _actors()
	for a: Node2D in actors:
		_draw_shadow(a)
	for cell in room.cells_of("puddle"):
		_draw_puddle(Vector2(cell * Room.TILE), t, actors)
	if room.window_dip():
		for cell in room.cells_of("shop_window_lit"):
			for p in _panes:
				_px(Vector2(cell * Room.TILE + p), Color(Game.color("ember"), 0.3))


func _px(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p.floor(), Vector2.ONE), c)


## Tadzio, Wick and every worker or npc that is on screen.
func _actors() -> Array[Node2D]:
	var out: Array[Node2D] = [room.player]
	if room.follower:
		out.append(room.follower)
	for e in room.entities:
		if e.active and e.sprite:
			out.append(e)
	return out


## A blob at the feet that stretches away from the nearest lit light.
func _draw_shadow(a: Node2D) -> void:
	var feet := a.position
	var own := str(a.data.get("light", "")) if a is Entity else ""
	var away := Vector2.ZERO
	var near := 0.0
	for lid: String in room.lights:
		var pl: PointLight2D = room.lights[lid]
		if not pl.enabled or lid == own:
			continue
		var from := feet - (pl.position + Vector2(0, 11))
		var n := 1.0 - from.length() / (pl.texture.get_width() * pl.texture_scale * 0.625)
		if n > near:
			near = n
			away = from.normalized() * Vector2(1.0, 0.7)
	var length := 5.0 + 9.0 * (1.0 - near) if near > 0.0 else 0.0
	var rows := {}
	var s := 0.0
	while s <= length:
		var w := 4.5 - 2.2 * (s / length if length > 0.0 else 0.0)
		var c := feet + Vector2(0, -1) + away * s
		for j in range(-2, 3):
			var half := w * sqrt(maxf(0.0, 1.0 - j * j / 3.2))
			var y := roundi(c.y) + j
			var span: Vector2 = rows.get(y, Vector2(INF, -INF))
			rows[y] = Vector2(minf(span.x, roundf(c.x - half)), maxf(span.y, roundf(c.x + half)))
		s += 0.5
	var ink := Color(Game.color("ink"), 0.2 + 0.22 * near if near > 0.0 else 0.14)
	for y: int in rows:
		draw_rect(Rect2(rows[y].x, y, rows[y].y - rows[y].x + 1.0, 1), ink)


func _draw_puddle(o: Vector2, t: float, actors: Array[Node2D]) -> void:
	var r := fmod(t + o.x * 0.08, 2.6) / 2.6 * 7.0
	for p: Vector2i in _water:
		var d := Vector2((p.x + 0.5 - 7.5) * 0.62, p.y + 0.5 - 9.0).length()
		if absf(d - r * 0.62) < 0.45:
			_px(o + Vector2(p), Color(Game.color("slate"), 1.0 - r / 7.5))
	for post: Sprite2D in room.lamp_posts():
		if (room.lamp_posts()[post] as PointLight2D).enabled and post.position.distance_to(o + Vector2(8, 8)) < 64.0:
			var shift := int(t * 3.0 + o.x) % 2
			for g: Vector2i in [Vector2i(6 + shift, 8), Vector2i(7 - shift, 10)]:
				if _water.has(g):
					_px(o + Vector2(g), Color(Game.color("lamp"), 0.5))
	for a in actors:
		var feet := a.position.round()
		if feet.x > o.x - 6 and feet.x < o.x + 22 and feet.y > o.y - 4 and feet.y < o.y + 12:
			_draw_mirror(a.get("sprite"), feet, o, t)


## A squashed, upside-down copy of the sprite, on the water pixels only.
func _draw_mirror(sprite: Sprite2D, feet: Vector2, o: Vector2, t: float) -> void:
	if sprite == null:
		return
	if not _images.has(sprite.texture):
		_images[sprite.texture] = sprite.texture.get_image()
	var img: Image = _images[sprite.texture]
	var size := Vector2i(img.get_width() / sprite.hframes, img.get_height() / sprite.vframes)
	var frame := Vector2i(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * size
	for j in 9:
		var wobble := roundf(sin(t * 4.0 + j * 1.3) * 0.7)
		for i in size.x:
			var at := Vector2(feet.x - size.x / 2.0 + i + wobble, feet.y + 1 + j)
			if not _water.has(Vector2i(at - o)):
				continue
			var c := img.get_pixelv(frame + Vector2i(i, size.y - 3 - j * 3))
			if c.a > 0.5:
				_px(at, Color(c, 0.6))


## Three moths for each lamp post. They fly in when its light comes on and leave when it goes out.
func _draw_moths(t: float) -> void:
	for post: Sprite2D in _moths:
		var head := post.position + Vector2(0, -27)
		for i in 3:
			var k := clampf(float(_moths[post]) * 1.6 - i * 0.3, 0.0, 1.0)
			if k <= 0.0:
				continue
			k = k * k * (3.0 - 2.0 * k)
			var a := t * 3.1 + i * 2.1 + post.position.x
			var orbit := head + Vector2(cos(a) * (8 + i * 3), sin(a * 1.7) * 5.0 + i)
			var p := (head + MOTH_FROM[i]).lerp(orbit, k).round()
			_px(p, Game.color("moon"))
			_px(p + Vector2(0, 1), Game.color("fog"))
			var up := int(t * 12.0 + i) % 2 == 1
			for side: float in [-1.0, 1.0]:
				_px(p + Vector2(side, -1 if up else 0), Game.color("moon"))
				_px(p + Vector2(side * 2.0, -2 if up else 0), Game.color("fog"))


func _draw_dust(t: float) -> void:
	var light := room.player.flashlight
	if not light.enabled:
		return
	var origin := room.player.position + light.position
	var half := deg_to_rad(Room.BEAM_HALF_ANGLE)
	for d in _dust:
		var along := fmod(d.x + t * 3.0, Room.BEAM_LENGTH)
		var v := Vector2(along, d.y * 0.75 + sin(t * 0.8 + d.z) * 3.0)
		var a := (1.0 - v.length() / Room.BEAM_LENGTH) * (1.0 - pow(v.angle() / half, 2.0))
		if v.length() < Room.BEAM_LENGTH and absf(v.angle()) < half and a > 0.08:
			_px(origin + v.rotated(room.player.facing.angle()), Color(Game.color("moon"), minf(0.85, a * 1.6) * (0.6 + 0.4 * sin(t * 2.0 + d.z))))
