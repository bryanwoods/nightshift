extends ArcadeGame
## Long Cat: steer a cat around a box to eat fish. Every fish makes the cat longer.
## Bumping into a wall or into your own tail ends the game.

const COLS := 28
const ROWS := 14
const CELL := 10.0
const ORIGIN := Vector2(20, 24)

var body: Array[Vector2i]
var dir: Vector2i
var turns: Array[Vector2i]
var fish: Vector2i
var tick: float
var grow: int
var clock: float
var prev: Array[Vector2i]
var every: float = 0.13


func reset() -> void:
	body = [Vector2i(8, 7), Vector2i(7, 7), Vector2i(6, 7)]
	prev = body.duplicate()
	dir = Vector2i.RIGHT
	turns = []
	tick = 0.0
	grow = 0
	_drop_fish()


func _drop_fish() -> void:
	while true:
		fish = Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(0, ROWS - 1))
		if fish not in body:
			return


func step(dt: float) -> bool:
	clock += dt
	var d := pressed_dir()
	var last: Vector2i = turns.back() if not turns.is_empty() else dir
	if d != Vector2i.ZERO and d != last and d != -last and turns.size() < 2:
		turns.append(d)
		AudioBus.sfx("a_cat_turn", 1.0, -6.0)
	tick += dt
	every = maxf(0.06, 0.13 - body.size() * 0.002)
	while tick >= every:
		tick -= every
		if not turns.is_empty():
			dir = turns.pop_front()
		var head: Vector2i = body[0] + dir
		prev = body.duplicate()
		if head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS or head in body.slice(0, body.size() - 1):
			burst(ORIGIN + Vector2(body[0]) * CELL + Vector2(5, 5), "honey", 20, 70.0, 60.0)
			jolt(5.0)
			blink("hush", 0.5)
			AudioBus.sfx("a_cat_crash")
			return false
		body.push_front(head)
		if head == fish:
			score += 10
			grow += 2
			burst(ORIGIN + Vector2(fish) * CELL + Vector2(5, 5), "aqua", 12, 50.0, 0.0)
			popup(ORIGIN + Vector2(fish) * CELL + Vector2(5, 5), "+10", "aqua")
			AudioBus.sfx("a_cat_eat", 1.0 + body.size() / 80.0)
			_drop_fish()
		if grow > 0:
			grow -= 1
		else:
			body.pop_back()
	return true


func _seg(i: int) -> Vector2:
	var from := Vector2(prev[mini(i, prev.size() - 1)])
	return ORIGIN + from.lerp(Vector2(body[i]), clampf(tick / every, 0.0, 1.0)) * CELL + Vector2(5, 5)


func draw(c: CanvasItem) -> void:
	sky(c, col("ink"), col("night"), 0.0, 180.0)
	var field := Rect2(ORIGIN, Vector2(COLS, ROWS) * CELL)
	c.draw_rect(field.grow(6), col("moss").darkened(0.35))
	for i in int(field.size.x / 6.0) + 2:
		for edge: float in [field.position.y - 6.0, field.end.y + 2.0]:
			c.draw_circle(Vector2(field.position.x - 4 + i * 6, edge + 2), 3.0, col("moss"))
	for i in 6:
		c.draw_circle(Vector2(field.position.x + 18 + i * 47, field.position.y - 4), 1.5, col("blossom" if i % 2 else "lamp"))
	for y in ROWS:
		for x in COLS:
			c.draw_rect(Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL)), col("moss") if (x + y) % 2 == 0 else col("moss").darkened(0.15))
	var fp := ORIGIN + Vector2(fish) * CELL + Vector2(5, 5 + sin(clock * 5.0))
	glow(c, fp, 9.0, col("aqua"), 0.5)
	c.draw_circle(fp + Vector2(-1, 0), 3.0, col("aqua"))
	c.draw_colored_polygon(PackedVector2Array([fp + Vector2(1, 0), fp + Vector2(5, -3 + sin(clock * 10.0)), fp + Vector2(5, 3 + sin(clock * 10.0))]), col("aqua"))
	c.draw_rect(Rect2(fp + Vector2(-2, -2), Vector2(2, 1)), col("froth"))
	c.draw_rect(Rect2(fp + Vector2(-3, -1), Vector2(1, 1)), col("ink"))
	if int(clock * 2.0) % 3 == 0:
		c.draw_circle(fp + Vector2(-5, -4 - fmod(clock * 8.0, 4.0)), 1.0, col("froth", 0.6))
	for i in range(body.size() - 1, 0, -1):
		var p := _seg(i)
		var q := _seg(i - 1)
		var r := 3.0 if i == body.size() - 1 else 4.5
		c.draw_circle(p + Vector2(0, 1), r, col("ink", 0.35))
		c.draw_line(p, q, col("honey"), r * 2.0)
		c.draw_circle(p, r, col("honey"))
		if i % 2 == 0:
			var across := Vector2(body[i - 1] - body[i]).orthogonal()
			c.draw_line(p - across * r * 0.8, p + across * r * 0.8, col("rust"), 1.5)
	var tail := _seg(body.size() - 1)
	c.draw_circle(tail, 2.0, col("moon"))
	var hp := _seg(0)
	var fwd := Vector2(dir)
	var side := fwd.orthogonal()
	for s: float in [-1.0, 1.0]:
		var ear := hp + side * s * 3.5 - fwd * 1.5
		c.draw_colored_polygon(PackedVector2Array([ear - side * s * 2.0, ear + side * s * 2.0, ear - fwd * 4.0 + side * s * 1.0]), col("honey"))
		c.draw_colored_polygon(PackedVector2Array([ear - side * s * 1.0, ear + side * s * 1.2, ear - fwd * 2.5 + side * s * 0.8]), col("blossom"))
	c.draw_circle(hp, 5.5, col("honey"))
	c.draw_line(hp - side * 3.0 - fwd * 3.0, hp + side * 3.0 - fwd * 3.0, col("rust"), 1.0)
	for s: float in [-1.0, 1.0]:
		var eye := hp + side * s * 2.2 + fwd * 1.0
		c.draw_rect(Rect2(eye - Vector2(1, 1), Vector2(2, 2)), col("ink"))
		c.draw_rect(Rect2(eye - Vector2(1, 1), Vector2(1, 1)), col("moon"))
		c.draw_line(hp + fwd * 3.0 + side * s * 2.0, hp + fwd * 3.5 + side * s * 7.0, col("moon", 0.7))
	c.draw_rect(Rect2(hp + fwd * 3.5 - Vector2(0.5, 0.5), Vector2(1, 1)), col("blossom"))
