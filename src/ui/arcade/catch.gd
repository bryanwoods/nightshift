extends ArcadeGame
## Star Catch: slide a jar along the bottom and catch falling stars. A missed star or a
## caught wax drop costs a heart. A falling moon is worth a lot and gives a heart back.

const JAR_Y := 160.0

var x: float
var hearts: int
var falling: Array
var wait: float
var clock: float


func reset() -> void:
	x = 160.0
	hearts = 3
	falling = []
	wait = 0.5
	clock = 0.0


func step(dt: float) -> bool:
	clock += dt
	x = clampf(x + Input.get_axis("move_left", "move_right") * 170.0 * dt, 14.0, 306.0)
	wait -= dt
	if wait <= 0.0:
		var roll := rng.randf()
		var kind := "moon" if roll < 0.04 else ("wax" if roll < 0.3 + minf(0.15, clock / 400.0) else "star")
		falling.append({"kind": kind, "pos": Vector2(rng.randf_range(16, 304), 18), "v": rng.randf_range(50, 70) + clock * 1.2})
		wait = maxf(0.3, 1.0 - clock / 90.0) * rng.randf_range(0.7, 1.2)
	for f: Dictionary in falling.duplicate():
		f.pos.y += f.v * dt
		if absf(f.pos.x - x) < 12.0 and absf(f.pos.y - JAR_Y) < 6.0:
			falling.erase(f)
			match f.kind:
				"star":
					score += 10
					AudioBus.sfx("chime", 1.0 + (score % 100) / 200.0, -6.0)
				"moon":
					score += 100
					hearts = mini(5, hearts + 1)
					AudioBus.sfx("satisfied")
				"wax":
					hearts -= 1
					AudioBus.sfx("hit")
		elif f.pos.y > 182.0:
			falling.erase(f)
			if f.kind == "star":
				hearts -= 1
				AudioBus.sfx("buzz", 1.0, -6.0)
	return hearts > 0


func draw(c: CanvasItem) -> void:
	for i in 30:
		c.draw_rect(Rect2((i * 97) % 316 + 2, 16 + (i * 41) % 130, 1, 1), col("slate"))
	for f: Dictionary in falling:
		var p: Vector2 = f.pos
		match f.kind:
			"star":
				_star(c, p, 5.0, clock * 3.0, col("lamp"))
			"moon":
				c.draw_circle(p, 7.0, col("moon"))
				c.draw_circle(p + Vector2(3, -2), 6.0, col("ink"))
			"wax":
				c.draw_circle(p, 3.5, col("hush"))
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -1), p + Vector2(0, -8), p + Vector2(3, -1)]), col("hush"))
	c.draw_rect(Rect2(x - 11, JAR_Y - 6, 22, 14), col("seafoam", 0.5))
	c.draw_rect(Rect2(x - 11, JAR_Y - 6, 22, 14), col("froth"), false)
	c.draw_rect(Rect2(x - 12, JAR_Y - 8, 24, 3), col("honey"))
	for i in hearts:
		var hp := Vector2(300 - i * 11, 8)
		c.draw_circle(hp + Vector2(-2, 0), 2.5, col("hush"))
		c.draw_circle(hp + Vector2(2, 0), 2.5, col("hush"))
		c.draw_colored_polygon(PackedVector2Array([hp + Vector2(-4.5, 1), hp + Vector2(4.5, 1), hp + Vector2(0, 6)]), col("hush"))


func _star(c: CanvasItem, p: Vector2, r: float, turn: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(p + Vector2.from_angle(turn + i * PI / 5.0) * (r if i % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, color)
