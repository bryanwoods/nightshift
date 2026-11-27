extends ArcadeGame
## Lamp Lighter: nine lamp posts in a grid. Lamps go dark one by one. Move to a dark lamp
## and relight it before a shadow takes it. Every lost lamp costs a heart.

const ORIGIN := Vector2(100, 32)
const GAP := Vector2(60, 46)

var cursor: Vector2i
var dark: Dictionary
var hearts: int
var wait: float
var clock: float
var lost: Array
var shown := Vector2(1, 1)


func reset() -> void:
	cursor = Vector2i(1, 1)
	dark = {}
	hearts = 3
	wait = 1.0
	clock = 0.0
	lost = []


func _patience() -> float:
	return maxf(1.4, 3.2 - clock / 40.0)


func step(dt: float) -> bool:
	clock += dt
	shown = shown.lerp(Vector2(cursor), minf(1.0, dt * 18.0))
	var d := pressed_dir()
	if d != Vector2i.ZERO:
		cursor = (cursor + d).clamp(Vector2i.ZERO, Vector2i(2, 2))
		AudioBus.sfx("a_lamps_move")
	if Input.is_action_just_pressed("confirm") and dark.has(cursor):
		dark.erase(cursor)
		score += 10
		burst(_pos(cursor) - Vector2(0, 28), "lamp", 14, 60.0, 0.0)
		popup(_pos(cursor) - Vector2(0, 30), "+10", "lamp")
		jolt(1.0)
		AudioBus.sfx("a_lamps_light", randf_range(0.95, 1.1))
	wait -= dt
	if wait <= 0.0:
		var lit: Array = []
		for y in 3:
			for x in 3:
				if not dark.has(Vector2i(x, y)):
					lit.append(Vector2i(x, y))
		if not lit.is_empty():
			dark[lit[rng.randi() % lit.size()]] = _patience()
			AudioBus.sfx("a_lamps_fizzle", 1.0, -4.0)
		wait = maxf(0.45, 1.3 - clock / 60.0) * rng.randf_range(0.7, 1.3)
	for cell: Vector2i in dark.keys():
		dark[cell] -= dt
		if dark[cell] <= 0.0:
			dark.erase(cell)
			lost.append({"pos": _pos(cell), "t": 0.0})
			hearts -= 1
			burst(_pos(cell) - Vector2(0, 28), "violet", 18, 60.0, -30.0)
			jolt(4.0)
			blink("hush", 0.4)
			AudioBus.sfx("a_lamps_lost")
	for l: Dictionary in lost.duplicate():
		l.t += dt
		if l.t > 0.8:
			lost.erase(l)
	return hearts > 0


func _pos(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * GAP + Vector2(0, 30)


func draw(c: CanvasItem) -> void:
	sky(c, col("ink"), col("night"), 0.0, 60.0)
	stars(c, clock, 14, 30.0)
	c.draw_rect(Rect2(0, 22, 320, 158), col("dusk"))
	for row in 20:
		var by := 22.0 + row * 8.0
		c.draw_rect(Rect2(0, by, 320, 1), col("night"))
		for k in 12:
			c.draw_rect(Rect2(k * 28.0 + (14.0 if row % 2 else 0.0), by, 1, 8), col("night"))
	for y in 3:
		var floor_y := _pos(Vector2i(0, y)).y + 2.0
		c.draw_rect(Rect2(60, floor_y, 200, 3), col("slate", 0.6))
	for y in 3:
		for x in 3:
			var cell := Vector2i(x, y)
			var base := _pos(cell)
			var head := base - Vector2(0, 28)
			if not dark.has(cell):
				c.draw_colored_polygon(PackedVector2Array([head + Vector2(-3, 4), head + Vector2(3, 4), base + Vector2(14, 2), base + Vector2(-14, 2)]), col("lamp", 0.08))
				glow(c, head, 16.0, col("lamp"), 0.55)
			c.draw_rect(Rect2(base.x - 5, base.y - 1, 10, 3), col("slate"))
			c.draw_rect(Rect2(base.x - 3, base.y - 4, 6, 3), col("slate"))
			c.draw_rect(Rect2(base.x - 1, head.y + 4, 2, 24), col("slate"))
			c.draw_rect(Rect2(base.x - 2, head.y + 12, 4, 2), col("fog"))
			c.draw_rect(Rect2(head.x - 4, head.y - 4, 8, 8), col("ink") if dark.has(cell) else col("lamp"))
			c.draw_rect(Rect2(head.x - 4, head.y - 4, 8, 8), col("slate"), false)
			c.draw_rect(Rect2(head.x - 0.5, head.y - 4, 1, 8), col("slate"))
			c.draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -4), head + Vector2(6, -4), head + Vector2(0, -9)]), col("slate"))
			c.draw_rect(Rect2(head.x - 1, head.y - 11, 2, 2), col("fog"))
			if dark.has(cell):
				var left: float = dark[cell] / _patience()
				var creep := 1.0 - left
				var blob := head + Vector2(sin(clock * 5.0 + x) * 1.5, -2.0 - 6.0 * creep)
				c.draw_circle(blob, 2.5 + 4.0 * creep, col("violet", 0.35 + 0.5 * creep))
				c.draw_circle(blob + Vector2(0, 2), 2.0 + 3.0 * creep, col("night", 0.6))
				for s: float in [-1.0, 1.0]:
					c.draw_rect(Rect2(blob + Vector2(s * (1.0 + creep * 1.5) - 0.5, -1), Vector2(1, 1)), col("hush"))
				c.draw_rect(Rect2(base.x - 10, base.y + 5, 20, 2), col("ink"))
				c.draw_rect(Rect2(base.x - 10, base.y + 5, 20 * left, 2), col("hush" if left < 0.35 else "lamp"))
			else:
				c.draw_rect(Rect2(head.x - 3, head.y - 3, 2, 2), col("moon"))
			if cell == cursor:
				var pulse := 1.0 + absf(sin(clock * 6.0)) * 2.0
				var r := Rect2(ORIGIN + shown * GAP + Vector2(0, 30) - Vector2(14, 40), Vector2(28, 48)).grow(pulse)
				for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
					var sx := 1.0 if corner.x == r.position.x else -1.0
					var sy := 1.0 if corner.y == r.position.y else -1.0
					c.draw_rect(Rect2(corner + Vector2(minf(0.0, 6 * sx), minf(0.0, sy)), Vector2(6, 1)), col("moon"))
					c.draw_rect(Rect2(corner + Vector2(minf(0.0, sx), minf(0.0, 6 * sy)), Vector2(1, 6)), col("moon"))
	for l: Dictionary in lost:
		var p: Vector2 = l.pos - Vector2(0, 28 + 30.0 * l.t)
		c.draw_circle(p, 5.0, col("violet", 1.0 - l.t))
		c.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(1, 1)), col("hush", 1.0 - l.t))
		c.draw_rect(Rect2(p + Vector2(1, -1), Vector2(1, 1)), col("hush", 1.0 - l.t))
	for i in hearts:
		var hp := Vector2(300 - i * 11, 8)
		c.draw_circle(hp + Vector2(-2, 0), 2.5, col("hush"))
		c.draw_circle(hp + Vector2(2, 0), 2.5, col("hush"))
		c.draw_colored_polygon(PackedVector2Array([hp + Vector2(-4.5, 1), hp + Vector2(4.5, 1), hp + Vector2(0, 6)]), col("hush"))
		c.draw_rect(Rect2(hp + Vector2(-3, -1), Vector2(1, 1)), col("blossom"))
