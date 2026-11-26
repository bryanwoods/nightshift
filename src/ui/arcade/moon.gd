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
	x = clampf(x + Input.get_axis("move_left", "move_right") * 190.0 * dt, PILLOW_W / 2.0 + 4.0, 316.0 - PILLOW_W / 2.0)
	for p: Dictionary in pops.duplicate():
		p.t += dt
		if p.t > 0.4:
			pops.erase(p)
	if stuck:
		ball = Vector2(x, PILLOW_Y - 5.0)
		if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("move_up"):
			stuck = false
			vel = Vector2(rng.randf_range(-0.5, 0.5), -1.0).normalized() * _speed()
		return true
	ball += vel * dt
	if ball.x < 6.0 or ball.x > 314.0:
		vel.x = absf(vel.x) * signf(160.0 - ball.x)
		AudioBus.sfx("tick", 1.6, -10.0)
	if ball.y < 20.0:
		vel.y = absf(vel.y)
		AudioBus.sfx("tick", 1.6, -10.0)
	if vel.y > 0.0 and absf(ball.y - PILLOW_Y) < 4.0 and absf(ball.x - x) < PILLOW_W / 2.0 + 3.0:
		var aim := (ball.x - x) / (PILLOW_W / 2.0)
		vel = Vector2(aim * 0.9, -1.0).normalized() * _speed()
		AudioBus.sfx("step_ok", 1.2, -6.0)
	for c: Dictionary in clouds:
		var r: Rect2 = c.rect
		if r.grow(3.0).has_point(ball):
			clouds.erase(c)
			pops.append({"pos": r.get_center(), "row": c.row, "t": 0.0})
			score += 10 * (ROWS.size() - int(c.row))
			AudioBus.sfx("chime", 1.6 - c.row * 0.12, -6.0)
			var from := ball - vel * dt
			if from.x < r.position.x - 3.0 or from.x > r.end.x + 3.0:
				vel.x = -vel.x
			else:
				vel.y = -vel.y
			break
	if clouds.is_empty():
		level += 1
		AudioBus.sfx("satisfied")
		_sky()
	if ball.y > 184.0:
		lives -= 1
		AudioBus.sfx("hit")
		if lives <= 0:
			return false
		_serve()
	return true


func _speed() -> float:
	return 130.0 + level * 20.0 + (ROWS.size() * 10 - clouds.size()) * 0.8


func draw(c: CanvasItem) -> void:
	for i in 26:
		c.draw_rect(Rect2((i * 89) % 316 + 2, 20 + (i * 53) % 140, 1, 1), col("slate"))
	for cl: Dictionary in clouds:
		var r: Rect2 = cl.rect
		var tint := col(ROWS[cl.row])
		c.draw_rect(Rect2(r.position + Vector2(2, 3), r.size - Vector2(4, 3)), tint)
		c.draw_circle(r.position + Vector2(8, 4), 4.0, tint)
		c.draw_circle(r.position + Vector2(16, 3.5), 4.5, tint)
		c.draw_rect(Rect2(r.position + Vector2(4, 2), Vector2(3, 1)), col("froth"))
	for p: Dictionary in pops:
		var k: float = p.t / 0.4
		for a in 6:
			c.draw_circle(p.pos + Vector2.from_angle(a * TAU / 6.0) * (4.0 + 14.0 * k), 2.0 * (1.0 - k), col(ROWS[p.row]))
	c.draw_circle(ball, 4.0, col("moon"))
	c.draw_circle(ball + Vector2(1.5, -1.0), 1.0, col("fog"))
	c.draw_circle(ball + Vector2(-1.5, 1.5), 0.8, col("fog"))
	c.draw_circle(ball, 9.0, col("moon", 0.12))
	var pr := Rect2(x - PILLOW_W / 2.0, PILLOW_Y, PILLOW_W, 7)
	c.draw_rect(pr, col("froth"))
	c.draw_rect(Rect2(pr.position + Vector2(0, 5), Vector2(PILLOW_W, 2)), col("seafoam"))
	for corner: float in [pr.position.x, pr.end.x - 2.0]:
		c.draw_rect(Rect2(corner, PILLOW_Y - 1, 2, 9), col("froth"))
	if stuck:
		c.draw_string(load("res://assets/fonts/m6x11.ttf"), Vector2(0, 130), Game.text("arcade_moon_serve"), HORIZONTAL_ALIGNMENT_CENTER, 320.0, 16, col("fog"))
	for i in lives:
		var lp := Vector2(302 - i * 12, 8)
		c.draw_circle(lp, 3.5, col("moon"))
