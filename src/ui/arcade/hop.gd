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
var dist: float
var squash: float
var coyote: float
var buffer: float


func reset() -> void:
	y = GROUND
	vy = 0.0
	speed = 95.0
	gap = 120.0
	run = 0.0
	sparks = 0
	things = []
	dist = 0.0
	squash = 0.0
	coyote = 0.0
	buffer = 0.0


func step(dt: float) -> bool:
	run += dt
	speed += dt * 4.0
	dist += speed * dt
	squash = maxf(0.0, squash - dt * 5.0)
	var on_ground := y >= GROUND
	coyote = 0.1 if on_ground else maxf(0.0, coyote - dt)
	buffer = maxf(0.0, buffer - dt)
	if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("move_up"):
		buffer = 0.12
	var held := Input.is_action_pressed("confirm") or Input.is_action_pressed("move_up")
	if vy < -130.0 and not held:
		vy = -130.0
	if buffer > 0.0 and coyote > 0.0:
		buffer = 0.0
		coyote = 0.0
		vy = -JUMP
		burst(Vector2(KID_X, GROUND), "fog", 6, 30.0, 40.0)
		AudioBus.sfx("a_hop_jump")
	vy += GRAVITY * dt
	y = minf(GROUND, y + vy * dt)
	if y >= GROUND:
		if not on_ground:
			squash = 1.0
			AudioBus.sfx("a_hop_land", 1.0, -4.0)
			burst(Vector2(KID_X, GROUND), "fog", 5, 25.0, 30.0)
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
					burst(Vector2(KID_X, GROUND), "aqua", 24, 90.0, 260.0)
					return _crash(true)
			"crate":
				if kid.intersects(Rect2(t.x - 6, GROUND - 12, 12, 12).grow(-1)):
					burst(Vector2(t.x, GROUND - 6), "honey", 18, 80.0, 200.0)
					return _crash(false)
			"spark":
				if kid.grow(2).has_point(Vector2(t.x, t.y)):
					things.erase(t)
					sparks += 1
					burst(Vector2(t.x, t.y), "lamp", 12, 60.0, 0.0)
					popup(Vector2(t.x, t.y), "+25", "lamp")
					AudioBus.sfx("a_hop_spark")
	score = int(run * 10.0) + sparks * 25
	return true


func _crash(splash: bool) -> bool:
	jolt(5.0)
	blink("hush", 0.5)
	AudioBus.sfx("a_hop_splash" if splash else "a_hop_crash")
	return false


func _spawn() -> void:
	var kind := "puddle" if rng.randf() < 0.6 else "crate"
	var w := rng.randf_range(18.0, 30.0) if kind == "puddle" else 12.0
	things.append({"kind": kind, "x": 340.0, "w": w})
	if rng.randf() < 0.5:
		things.append({"kind": "spark", "x": 340.0 + rng.randf_range(-10, 30), "y": rng.randf_range(95.0, 125.0)})
	gap = rng.randf_range(110.0, 200.0) * (0.7 + speed / 300.0)


func draw(c: CanvasItem) -> void:
	sky(c, col("ink"), col("dusk"), 0.0, GROUND)
	stars(c, run, 30, 100.0, 2.0)
	glow(c, Vector2(262, 40), 30.0, col("moon"), 0.3)
	c.draw_circle(Vector2(262, 40), 12.0, col("moon"))
	c.draw_circle(Vector2(258, 37), 2.5, col("froth"))
	c.draw_circle(Vector2(266, 45), 2.0, col("froth"))
	c.draw_circle(Vector2(265, 34), 1.2, col("froth"))
	for i in 9:
		var hx := fposmod(i * 62.0 - dist * 0.2, 9 * 62.0) - 60.0
		var hh := 30.0 + (i * 37) % 26
		c.draw_rect(Rect2(hx, GROUND - hh, 52, hh), col("night"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(hx - 3, GROUND - hh), Vector2(hx + 26, GROUND - hh - 14), Vector2(hx + 55, GROUND - hh)]), col("night"))
		for wy in 2:
			for wx in 3:
				var on := (i * 7 + wx * 3 + wy * 5) % 4 != 0
				var wr := Rect2(hx + 7 + wx * 15, GROUND - hh + 7 + wy * 12, 6, 6)
				if wr.end.y < GROUND - 4:
					c.draw_rect(wr, col("lamp", 0.85) if on else col("ink"))
	for i in 4:
		var lx := fposmod(i * 110.0 - dist * 0.55, 440.0) - 40.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(lx - 3, GROUND - 46), Vector2(lx + 5, GROUND - 46), Vector2(lx + 22, GROUND), Vector2(lx - 20, GROUND)]), col("lamp", 0.06))
		c.draw_rect(Rect2(lx, GROUND - 46, 2, 46), col("slate"))
		c.draw_rect(Rect2(lx - 2, GROUND - 3, 6, 3), col("slate"))
		c.draw_rect(Rect2(lx - 3, GROUND - 53, 8, 2), col("slate"))
		glow(c, Vector2(lx + 1, GROUND - 49), 14.0, col("lamp"), 0.5)
		c.draw_rect(Rect2(lx - 2, GROUND - 51, 6, 5), col("lamp"))
		c.draw_rect(Rect2(lx - 1, GROUND - 50, 2, 2), col("moon"))
	c.draw_rect(Rect2(0, GROUND, 320, 30), col("dusk"))
	c.draw_rect(Rect2(0, GROUND, 320, 1), col("fog"))
	for row in 3:
		for i in 14:
			var cx := fposmod(i * 26.0 + row * 13.0 - dist, 340.0) - 20.0
			c.draw_rect(Rect2(cx, GROUND + 4 + row * 9, 22, 6), col("slate", 0.5))
	for t: Dictionary in things:
		match t.kind:
			"puddle":
				var half: float = t.w / 2.0
				c.draw_rect(Rect2(t.x - half + 2, GROUND, t.w - 4, 4), col("aqua"))
				c.draw_circle(Vector2(t.x - half + 2, GROUND + 2), 2.0, col("aqua"))
				c.draw_circle(Vector2(t.x + half - 2, GROUND + 2), 2.0, col("aqua"))
				c.draw_rect(Rect2(t.x - half + 4, GROUND + 1, t.w * 0.3, 1), col("froth"))
				c.draw_rect(Rect2(t.x + 2 + sin(run * 6.0) * 2.0, GROUND + 2, 3, 1), col("seafoam"))
			"crate":
				c.draw_rect(Rect2(t.x - 6, GROUND - 12, 12, 12), col("walnut"))
				c.draw_rect(Rect2(t.x - 6, GROUND - 12, 12, 12), col("honey"), false)
				c.draw_rect(Rect2(t.x - 6, GROUND - 7, 12, 1), col("honey"))
				c.draw_line(Vector2(t.x - 6, GROUND - 12), Vector2(t.x + 6, GROUND), col("honey", 0.7))
				c.draw_rect(Rect2(t.x - 5, GROUND - 11, 3, 1), col("straw"))
				c.draw_rect(Rect2(t.x - 8, GROUND, 16, 2), col("ink", 0.5))
			"spark":
				var sp := Vector2(t.x, t.y + sin(run * 5.0 + t.x) * 2.0)
				glow(c, sp, 9.0, col("lamp"), 0.6)
				var a := run * 4.0
				for k in 4:
					c.draw_line(sp, sp + Vector2.from_angle(a + k * PI / 2.0) * 4.0, col("lamp"))
				c.draw_circle(sp, 1.5, col("moon"))
	_kid(c)


func _kid(c: CanvasItem) -> void:
	var air := GROUND - y
	c.draw_rect(Rect2(KID_X - 6 + air * 0.05, GROUND, 12 - air * 0.1, 2), col("ink", 0.5))
	var s := 1.0 - squash * 0.25
	var base := Vector2(KID_X, y)
	var stride := sin(run * 20.0) * 3.0 if air <= 0.0 else 2.0
	var legs := [Vector2(-2 - stride, 0), Vector2(2 + stride, 0)]
	for l: Vector2 in legs:
		c.draw_line(base + Vector2(l.x * 0.4, -5 * s), base + l, col("violet"), 2.0)
		c.draw_rect(Rect2(base + l - Vector2(1, 1), Vector2(3, 1)), col("moon"))
	var body := Rect2(base + Vector2(-4, -12 * s), Vector2(8, 8 * s))
	c.draw_rect(body, col("violet"))
	c.draw_rect(Rect2(body.position + Vector2(0, 2), Vector2(8, 1)), col("lilac"))
	c.draw_rect(Rect2(body.position + Vector2(0, 5 * s), Vector2(8, 1)), col("lilac"))
	var arm := stride * 0.8 if air <= 0.0 else -3.0
	c.draw_line(base + Vector2(-3, -10 * s), base + Vector2(-5 - arm, -6 * s + (-4.0 if air > 0.0 else 0.0)), col("violet"), 2.0)
	c.draw_line(base + Vector2(3, -10 * s), base + Vector2(5 + arm, -6 * s + (-4.0 if air > 0.0 else 0.0)), col("violet"), 2.0)
	var head := base + Vector2(0, -15 * s)
	c.draw_circle(head, 3.5, col("peach"))
	c.draw_rect(Rect2(head + Vector2(-4, -4), Vector2(8, 3)), col("walnut"))
	c.draw_rect(Rect2(head + Vector2(-4, -2), Vector2(2, 3)), col("walnut"))
	c.draw_rect(Rect2(head + Vector2(1.5, -0.5), Vector2(1, 1)), col("ink"))
	c.draw_rect(Rect2(head + Vector2(2, 1.5), Vector2(1, 1)), col("blossom"))
