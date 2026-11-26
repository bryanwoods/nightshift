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


func reset() -> void:
	body = [Vector2i(8, 7), Vector2i(7, 7), Vector2i(6, 7)]
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
	var d := pressed_dir()
	var last: Vector2i = turns.back() if not turns.is_empty() else dir
	if d != Vector2i.ZERO and d != last and d != -last and turns.size() < 2:
		turns.append(d)
	tick += dt
	var every := maxf(0.06, 0.13 - body.size() * 0.002)
	while tick >= every:
		tick -= every
		if not turns.is_empty():
			dir = turns.pop_front()
		var head: Vector2i = body[0] + dir
		if head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS or head in body.slice(0, body.size() - 1):
			AudioBus.sfx("hit")
			return false
		body.push_front(head)
		if head == fish:
			score += 10
			grow += 2
			AudioBus.sfx("chime", 1.0 + body.size() / 60.0, -6.0)
			_drop_fish()
		if grow > 0:
			grow -= 1
		else:
			body.pop_back()
	return true


func draw(c: CanvasItem) -> void:
	c.draw_rect(Rect2(ORIGIN - Vector2(2, 2), Vector2(COLS, ROWS) * CELL + Vector2(4, 4)), col("moss"), false, 2.0)
	var fp := ORIGIN + Vector2(fish) * CELL + Vector2(5, 5)
	c.draw_circle(fp + Vector2(-1, 0), 3.0, col("aqua"))
	c.draw_colored_polygon(PackedVector2Array([fp + Vector2(1, 0), fp + Vector2(5, -3), fp + Vector2(5, 3)]), col("aqua"))
	c.draw_rect(Rect2(fp + Vector2(-3, -1), Vector2(1, 1)), col("ink"))
	for i in range(body.size() - 1, -1, -1):
		var p := ORIGIN + Vector2(body[i]) * CELL
		var inset := 2.0 if i == body.size() - 1 else 1.0
		c.draw_rect(Rect2(p + Vector2(inset, inset), Vector2(CELL, CELL) - Vector2(inset, inset) * 2.0), col("honey" if i % 2 == 0 else "straw"))
	var hp := ORIGIN + Vector2(body[0]) * CELL + Vector2(5, 5)
	var side := Vector2(dir).orthogonal()
	var back := -Vector2(dir)
	for s: float in [-1.0, 1.0]:
		var ear := hp + side * s * 3.0 + back * 2.0
		c.draw_colored_polygon(PackedVector2Array([ear, ear + side * s * 3.0, hp + side * s * 4.0 - back * 5.0 + back * 2.0]), col("honey"))
		c.draw_rect(Rect2(hp + side * s * 2.0 + Vector2(dir) * 1.5 - Vector2(0.5, 0.5), Vector2(1, 1)), col("ink"))
