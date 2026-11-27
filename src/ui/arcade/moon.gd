extends ArcadeGame
## Moon Bounce: slide a pillow along the bottom and bounce the moon up into rows of clouds.
## Every cloud pops when the moon hits it. Clear them all and a faster sky rolls in.

const PILLOW_Y := 162.0
const PILLOW_W := 34.0
const ROWS: PackedStringArray = ["blossom", "lilac", "aqua", "seafoam", "mint"]
const CLOUD := Vector2(26, 9)
const TOP := 26.0

var x: float
var lives: int
var level: int
var ball: Vector2
var vel: Vector2
var stuck: bool
var clouds: Array
var pops: Array
var clock: float
var squish: float
var vx: float


func reset() -> void:
	lives = 3
	level = 0
	_sky()


func _sky() -> void:
	clouds = []
	pops = []
	for r in ROWS.size():
		for i in 10:
			clouds.append({"rect": Rect2(Vector2(28 + i * (CLOUD.x + 1), TOP + r * (CLOUD.y + 2)), CLOUD), "row": r})
	_serve()


func _serve() -> void:
	x = 160.0
	stuck = true
	vel = Vector2.ZERO


func step(dt: float) -> bool:
	clock += dt
	squish = maxf(0.0, squish - dt * 5.0)
	if not stuck and rng.randf() < 0.6:
		_parts.append({"pos": ball, "vel": Vector2.ZERO, "life": 0.3, "max": 0.3, "color": col("moon"), "size": 2.0, "gravity": 0.0})
	vx = move_toward(vx, Input.get_axis("move_left", "move_right") * 210.0, 1800.0 * dt)
	x = clampf(x + vx * dt, PILLOW_W / 2.0 + 4.0, 316.0 - PILLOW_W / 2.0)
	for p: Dictionary in pops.duplicate():
		p.t += dt
		if p.t > 0.4:
			pops.erase(p)
	if stuck:
		ball = Vector2(x, PILLOW_Y - 5.0)
		if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("move_up"):
			stuck = false
			vel = Vector2(clampf(vx / 300.0 + rng.randf_range(-0.2, 0.2), -0.7, 0.7), -1.0).normalized() * _speed()
		return true
	ball += vel * dt
	if ball.x < 6.0 or ball.x > 314.0:
		vel.x = absf(vel.x) * signf(160.0 - ball.x)
		AudioBus.sfx("a_moon_wall", 1.0, -6.0)
	if ball.y < 20.0:
		vel.y = absf(vel.y)
		AudioBus.sfx("a_moon_wall", 1.0, -6.0)
	if vel.y > 0.0 and absf(ball.y - PILLOW_Y) < 4.0 and absf(ball.x - x) < PILLOW_W / 2.0 + 3.0:
		var aim := clampf((ball.x - x) / (PILLOW_W / 2.0) + vx / 600.0, -1.2, 1.2)
		vel = Vector2(aim * 0.9, -1.0).normalized() * _speed()
		squish = 1.0
		burst(Vector2(ball.x, PILLOW_Y), "froth", 5, 30.0, 40.0)
		AudioBus.sfx("a_moon_boing", randf_range(0.95, 1.08))
	for c: Dictionary in clouds:
		var r: Rect2 = c.rect
		if r.grow(3.0).has_point(ball):
			clouds.erase(c)
			pops.append({"pos": r.get_center(), "row": c.row, "t": 0.0})
			score += 10 * (ROWS.size() - int(c.row))
			burst(r.get_center(), ROWS[c.row], 10, 50.0, 30.0)
			popup(r.get_center(), str(10 * (ROWS.size() - int(c.row))), ROWS[c.row])
			AudioBus.sfx("a_moon_pop", 1.4 - c.row * 0.1)
			var from := ball - vel * dt
			if from.x < r.position.x - 3.0 or from.x > r.end.x + 3.0:
				vel.x = -vel.x
			else:
				vel.y = -vel.y
			break
	if clouds.is_empty():
		level += 1
		blink("moon", 0.7)
		popup(Vector2(160, 90), "CLEAR!", "wake")
		AudioBus.sfx("a_moon_clear")
		_sky()
	if ball.y > 184.0:
		lives -= 1
		jolt(4.0)
		blink("hush", 0.4)
		AudioBus.sfx("a_moon_lose")
		if lives <= 0:
			return false
		_serve()
	return true


func _speed() -> float:
	return 130.0 + level * 20.0 + (ROWS.size() * 10 - clouds.size()) * 0.8


func draw(c: CanvasItem) -> void:
	sky(c, col("ink"), col("dusk"), 0.0, 180.0)
	stars(c, clock, 30, 170.0)
	for i in 8:
		var hx := i * 46.0 - 10.0
		c.draw_circle(Vector2(hx, 196), 34.0 + (i * 13) % 12, col("night"))
	for cl: Dictionary in clouds:
		var r: Rect2 = cl.rect
		var tint := col(ROWS[cl.row])
		var bob := sin(clock * 2.0 + r.position.x * 0.1) * 0.6
		var o := r.position + Vector2(0, bob)
		c.draw_rect(Rect2(o + Vector2(2, 4), r.size - Vector2(4, 4)), tint.darkened(0.25))
		c.draw_rect(Rect2(o + Vector2(2, 3), r.size - Vector2(4, 5)), tint)
		c.draw_circle(o + Vector2(8, 4.5), 4.0, tint)
		c.draw_circle(o + Vector2(16, 4), 4.5, tint)
		c.draw_circle(o + Vector2(21, 5.5), 3.0, tint)
		c.draw_circle(o + Vector2(7, 3.5), 1.5, col("froth", 0.8))
		c.draw_rect(Rect2(o + Vector2(14, 1), Vector2(3, 1)), col("froth", 0.8))
	for p: Dictionary in pops:
		var k: float = p.t / 0.4
		c.draw_arc(p.pos, 4.0 + 12.0 * k, 0.0, TAU, 16, col(ROWS[p.row], 1.0 - k), 1.0)
	glow(c, ball, 14.0, col("moon"), 0.45)
	c.draw_circle(ball, 4.5, col("moon"))
	c.draw_circle(ball + Vector2(1.5, -1.0), 1.2, col("fog"))
	c.draw_circle(ball + Vector2(-1.5, 1.5), 0.9, col("fog"))
	c.draw_circle(ball + Vector2(-1.5, -1.8), 0.7, col("froth"))
	var sq := squish * 2.0
	var pr := Rect2(x - PILLOW_W / 2.0 - sq, PILLOW_Y + sq * 0.5, PILLOW_W + sq * 2.0, 8 - sq * 0.5)
	c.draw_rect(Rect2(pr.position + Vector2(1, pr.size.y), Vector2(pr.size.x - 2, 2)), col("ink", 0.5))
	c.draw_rect(Rect2(pr.position + Vector2(1, 0), pr.size - Vector2(2, 0)), col("froth"))
	c.draw_rect(Rect2(pr.position + Vector2(0, 1), pr.size - Vector2(0, 2)), col("froth"))
	c.draw_rect(Rect2(pr.position + Vector2(1, pr.size.y - 3), Vector2(pr.size.x - 2, 2)), col("seafoam"))
	c.draw_rect(Rect2(pr.position + Vector2(3, 2), Vector2(pr.size.x - 6, 1)), col("moon"))
	for corner: float in [pr.position.x - 1, pr.end.x - 1]:
		c.draw_rect(Rect2(corner, pr.position.y - 1, 2, 2), col("lilac"))
		c.draw_rect(Rect2(corner, pr.end.y - 1, 2, 2), col("lilac"))
	if stuck:
		c.draw_string(FONT, Vector2(0, 130), Game.text("arcade_moon_serve"), HORIZONTAL_ALIGNMENT_CENTER, 320.0, 16, col("fog", 0.5 + 0.5 * absf(sin(clock * 3.0))))
	for i in lives:
		var lp := Vector2(302 - i * 12, 9)
		c.draw_circle(lp, 3.5, col("moon"))
		c.draw_circle(lp + Vector2(1, -1), 0.8, col("fog"))
