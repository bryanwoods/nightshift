extends ArcadeGame
## Puddle Hop: a kid in pajamas runs down a night street. Jump over puddles and crates,
## and grab lamp sparks in the air. The street gets faster the longer you run.

const GROUND := 150.0
const KID_X := 60.0
const GRAVITY := 720.0
const JUMP := 250.0

var y: float
var vy: float
var speed: float
var gap: float
var run: float
var sparks: int
var things: Array


func reset() -> void:
	y = GROUND
	vy = 0.0
	speed = 95.0
	gap = 120.0
	run = 0.0
	sparks = 0
	things = []


func step(dt: float) -> bool:
	run += dt
	speed += dt * 4.0
	var on_ground := y >= GROUND
	if on_ground and (Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("move_up")):
		vy = -JUMP
		AudioBus.sfx("step_ok", 1.3, -6.0)
	vy += GRAVITY * dt
	y = minf(GROUND, y + vy * dt)
	if y >= GROUND:
		vy = 0.0
	gap -= speed * dt
	if gap <= 0.0:
		_spawn()
	var kid := Rect2(KID_X - 5, y - 16, 10, 16)
	for t: Dictionary in things.duplicate():
		t.x -= speed * dt
		if t.x < -40:
			things.erase(t)
			continue
		match t.kind:
			"puddle":
				if y >= GROUND - 1.0 and absf(t.x - KID_X) < t.w / 2.0 - 3.0:
					AudioBus.sfx("hit")
					return false
			"crate":
				if kid.intersects(Rect2(t.x - 6, GROUND - 12, 12, 12).grow(-1)):
					AudioBus.sfx("hit")
					return false
			"spark":
				if kid.grow(2).has_point(Vector2(t.x, t.y)):
					things.erase(t)
					sparks += 1
					AudioBus.sfx("chime", 1.5, -6.0)
	score = int(run * 10.0) + sparks * 25
	return true


func _spawn() -> void:
	var kind := "puddle" if rng.randf() < 0.6 else "crate"
	var w := rng.randf_range(18.0, 30.0) if kind == "puddle" else 12.0
	things.append({"kind": kind, "x": 340.0, "w": w})
	if rng.randf() < 0.5:
		things.append({"kind": "spark", "x": 340.0 + rng.randf_range(-10, 30), "y": rng.randf_range(95.0, 125.0)})
	gap = rng.randf_range(110.0, 200.0) * (0.7 + speed / 300.0)


func draw(c: CanvasItem) -> void:
	for i in 24:
		var sx := fposmod(i * 53.0 - run * 6.0, 330.0)
		c.draw_rect(Rect2(sx, 20 + (i * 37) % 70, 1, 1), col("fog"))
	c.draw_circle(Vector2(270, 40), 12.0, col("moon"))
	c.draw_circle(Vector2(265, 37), 11.0, col("ink"))
	for i in 4:
		var lx := fposmod(i * 110.0 - run * speed * 0.4, 440.0) - 40.0
		c.draw_rect(Rect2(lx, GROUND - 46, 2, 46), col("slate"))
		c.draw_circle(Vector2(lx + 1, GROUND - 48), 3.0, col("lamp"))
		c.draw_circle(Vector2(lx + 1, GROUND - 48), 9.0, col("lamp", 0.15))
	c.draw_rect(Rect2(0, GROUND, 320, 30), col("dusk"))
	for i in 12:
		c.draw_rect(Rect2(fposmod(i * 30.0 - run * speed, 330.0) - 10, GROUND + 8, 14, 1), col("slate"))
	for t: Dictionary in things:
		match t.kind:
			"puddle":
				c.draw_rect(Rect2(t.x - t.w / 2.0, GROUND, t.w, 3), col("aqua"))
				c.draw_rect(Rect2(t.x - t.w / 2.0 + 3, GROUND, 4, 1), col("froth"))
			"crate":
				c.draw_rect(Rect2(t.x - 6, GROUND - 12, 12, 12), col("walnut"))
				c.draw_rect(Rect2(t.x - 6, GROUND - 12, 12, 12), col("honey"), false)
				c.draw_line(Vector2(t.x - 6, GROUND - 12), Vector2(t.x + 6, GROUND), col("honey"))
			"spark":
				c.draw_circle(Vector2(t.x, t.y), 2.0, col("lamp"))
				c.draw_circle(Vector2(t.x, t.y), 5.0, col("lamp", 0.25))
	var legs := sin(run * 20.0) * 3.0 if y >= GROUND else 2.0
	c.draw_line(Vector2(KID_X - 2, y - 5), Vector2(KID_X - 2 - legs, y), col("violet"), 2.0)
	c.draw_line(Vector2(KID_X + 2, y - 5), Vector2(KID_X + 2 + legs, y), col("violet"), 2.0)
	c.draw_rect(Rect2(KID_X - 4, y - 12, 8, 8), col("violet"))
	c.draw_rect(Rect2(KID_X - 1, y - 10, 1, 1), col("moon"))
	c.draw_rect(Rect2(KID_X + 1, y - 7, 1, 1), col("moon"))
	c.draw_circle(Vector2(KID_X, y - 15), 3.5, col("peach"))
	c.draw_rect(Rect2(KID_X - 3, y - 19, 7, 2), col("walnut"))
