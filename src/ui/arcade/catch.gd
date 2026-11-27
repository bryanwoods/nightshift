extends ArcadeGame
## Star Catch: slide a jar along the bottom and catch falling stars. A missed star or a
## caught wax drop costs a heart. A falling moon is worth a lot and gives a heart back.

const JAR_Y := 160.0

var x: float
var hearts: int
var falling: Array
var wait: float
var clock: float
var caught: int
var lean: float
var vx: float


func reset() -> void:
	x = 160.0
	hearts = 3
	falling = []
	wait = 0.5
	clock = 0.0
	caught = 0
	lean = 0.0
	vx = 0.0


func step(dt: float) -> bool:
	clock += dt
	var move := Input.get_axis("move_left", "move_right")
	vx = move_toward(vx, move * 190.0, 1500.0 * dt)
	lean = lerpf(lean, vx / 190.0, dt * 10.0)
	x = clampf(x + vx * dt, 14.0, 306.0)
	if x <= 14.0 or x >= 306.0:
		vx = 0.0
	wait -= dt
	if wait <= 0.0:
		var roll := rng.randf()
		var kind := "moon" if roll < 0.04 else ("wax" if roll < 0.3 + minf(0.15, clock / 400.0) else "star")
		falling.append({"kind": kind, "pos": Vector2(rng.randf_range(16, 304), 18), "v": rng.randf_range(50, 70) + clock * 1.2})
		wait = maxf(0.3, 1.0 - clock / 90.0) * rng.randf_range(0.7, 1.2)
	for f: Dictionary in falling.duplicate():
		f.pos.y += f.v * dt
		if f.kind != "wax" and rng.randf() < 0.5:
			_parts.append({"pos": f.pos + Vector2(rng.randf_range(-2, 2), -4), "vel": Vector2(0, -10), "life": 0.35, "max": 0.35,
				"color": col("lamp" if f.kind == "star" else "moon"), "size": 1.5, "gravity": 0.0})
		if absf(f.pos.x - x) < 14.0 and absf(f.pos.y - JAR_Y) < 7.0:
			falling.erase(f)
			match f.kind:
				"star":
					score += 10
					caught += 1
					burst(f.pos, "lamp", 10, 50.0, 0.0)
					popup(f.pos, "+10", "lamp")
					AudioBus.sfx("a_catch_star", 1.0 + (caught % 8) * 0.06)
				"moon":
					score += 100
					hearts = mini(5, hearts + 1)
					burst(f.pos, "moon", 24, 80.0, 0.0)
					popup(f.pos, "+100", "moon")
					blink("moon", 0.4)
					AudioBus.sfx("a_catch_moon")
				"wax":
					hearts -= 1
					burst(f.pos, "hush", 16, 70.0, 120.0)
					jolt(4.0)
					blink("hush", 0.4)
					AudioBus.sfx("a_catch_wax")
		elif f.pos.y > 182.0:
			falling.erase(f)
			if f.kind == "star":
				hearts -= 1
				burst(Vector2(f.pos.x, 176), "fog", 8, 40.0, 60.0)
				jolt(2.0)
				AudioBus.sfx("a_catch_miss")
	return hearts > 0


func draw(c: CanvasItem) -> void:
	sky(c, col("ink"), col("dusk").lerp(col("violet"), 0.25), 0.0, 180.0)
	stars(c, clock, 40, 150.0)
	for i in 12:
		var bx := i * 28.0 - 4.0
		var bh := 10.0 + (i * 23) % 14
		c.draw_rect(Rect2(bx, 180 - bh, 26, bh), col("night"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(bx, 180 - bh), Vector2(bx + 13, 180 - bh - 7), Vector2(bx + 26, 180 - bh)]), col("night"))
		if i % 3 == 1:
			c.draw_rect(Rect2(bx + 10, 180 - bh + 3, 5, 4), col("lamp", 0.8))
	for f: Dictionary in falling:
		var p: Vector2 = f.pos
		match f.kind:
			"star":
				glow(c, p, 10.0, col("lamp"), 0.5)
				_star(c, p, 5.5, clock * 3.0 + p.x, col("lamp"))
				_star(c, p, 2.5, clock * 3.0 + p.x, col("moon"))
			"moon":
				glow(c, p, 18.0, col("moon"), 0.5)
				c.draw_circle(p, 7.0, col("moon"))
				c.draw_circle(p + Vector2(3, -2), 6.0, col("night"))
				c.draw_rect(Rect2(p + Vector2(-4, -1), Vector2(1, 1)), col("ink"))
				c.draw_rect(Rect2(p + Vector2(-3, 2), Vector2(2, 1)), col("blossom"))
			"wax":
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(-3.5, 0), p + Vector2(0, -9), p + Vector2(3.5, 0)]), col("hush"))
				c.draw_circle(p, 3.5, col("hush"))
				c.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(1, 2)), col("blossom"))
				c.draw_rect(Rect2(p + Vector2(-1, 2), Vector2(3, 1)), col("clay"))
	_jar(c)
	for i in hearts:
		var hp := Vector2(300 - i * 11, 8)
		c.draw_circle(hp + Vector2(-2, 0), 2.5, col("hush"))
		c.draw_circle(hp + Vector2(2, 0), 2.5, col("hush"))
		c.draw_colored_polygon(PackedVector2Array([hp + Vector2(-4.5, 1), hp + Vector2(4.5, 1), hp + Vector2(0, 6)]), col("hush"))
		c.draw_rect(Rect2(hp + Vector2(-3, -1), Vector2(1, 1)), col("blossom"))


func _jar(c: CanvasItem) -> void:
	var tilt := lean * 2.0
	var r := Rect2(x - 11, JAR_Y - 6, 22, 15)
	glow(c, r.get_center(), 14.0 + minf(10.0, caught * 0.4), col("lamp"), 0.45)
	c.draw_rect(Rect2(x - 12, JAR_Y + 9, 24, 2), col("ink", 0.5))
	c.draw_rect(r, col("seafoam", 0.35))
	var fill := minf(13.0, caught * 0.5)
	for i in mini(caught, 18):
		var sp := Vector2(x - 8 + (i * 5) % 16, JAR_Y + 7 - (i / 4) * 3 - fill * 0.0)
		c.draw_rect(Rect2(sp, Vector2(2, 2)), col("lamp" if i % 3 else "moon", 0.6 + 0.4 * absf(sin(clock * 3.0 + i))))
	c.draw_rect(r, col("froth"), false)
	c.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(1, 9)), col("froth", 0.8))
	c.draw_rect(Rect2(x - 12 + tilt, JAR_Y - 9, 24, 3), col("honey"))
	c.draw_rect(Rect2(x - 12 + tilt, JAR_Y - 9, 24, 1), col("straw"))


func _star(c: CanvasItem, p: Vector2, r: float, turn: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(p + Vector2.from_angle(turn + i * PI / 5.0) * (r if i % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, color)
