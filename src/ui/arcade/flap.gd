extends ArcadeGame
## Firefly Flap: a firefly flaps through gaps in tall hedges. Each flap lifts it a little,
## and it sinks the rest of the time. Touching a hedge, the ground or the top ends the game.

const FLY_X := 80.0
const GROUND := 168.0
const TOP := 16.0
const HEDGE_W := 22.0

var y: float
var vy: float
var started: bool
var hedges: Array
var gap: float
var clock: float


func reset() -> void:
	y = 90.0
	vy = 0.0
	started = false
	hedges = []
	gap = 60.0
	clock = 0.0


func step(dt: float) -> bool:
	clock += dt
	if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("move_up"):
		started = true
		vy = -140.0
		burst(Vector2(FLY_X - 3, y + 2), "seafoam", 3, 20.0, 0.0)
		AudioBus.sfx("a_flap_flap", randf_range(0.9, 1.1))
	if not started:
		y = 90.0 + sin(clock * 4.0) * 3.0
		return true
	vy = minf(vy + 400.0 * dt, 190.0)
	y += vy * dt
	if rng.randf() < 0.7:
		_parts.append({"pos": Vector2(FLY_X - 3, y + 1), "vel": Vector2(-40, 0), "life": 0.5, "max": 0.5, "color": col("lamp"), "size": 1.5, "gravity": 0.0})
	if y < TOP + 3.0 or y > GROUND - 3.0:
		return _crash()
	var speed := 70.0 + score * 0.15
	gap -= speed * dt
	if gap <= 0.0:
		hedges.append({"x": 330.0, "mid": rng.randf_range(55.0, 130.0), "passed": false})
		gap = 130.0
	var opening := maxf(46.0, 62.0 - score * 0.08)
	for h: Dictionary in hedges.duplicate():
		h.x -= speed * dt
		if h.x < -HEDGE_W:
			hedges.erase(h)
			continue
		if absf(h.x + HEDGE_W / 2.0 - FLY_X) < HEDGE_W / 2.0 and absf(y - h.mid) > opening / 2.0 - 1.0:
			return _crash()
		if not h.passed and h.x + HEDGE_W < FLY_X:
			h.passed = true
			score += 10
			popup(Vector2(FLY_X, y - 6), "+10", "wake")
			AudioBus.sfx("a_flap_pass")
	return true


func _crash() -> bool:
	burst(Vector2(FLY_X, y), "lamp", 20, 70.0, 80.0)
	jolt(5.0)
	blink("hush", 0.4)
	AudioBus.sfx("a_flap_crash")
	return false


func draw(c: CanvasItem) -> void:
	sky(c, col("ink"), col("night").lerp(col("moss"), 0.3), 0.0, GROUND)
	stars(c, clock, 30, 120.0, 1.0)
	glow(c, Vector2(250, 44), 24.0, col("moon"), 0.3)
	c.draw_circle(Vector2(250, 44), 10.0, col("moon"))
	c.draw_circle(Vector2(254, 41), 9.0, col("night").lerp(col("ink"), 0.3))
	var slide := clock * (70.0 + score * 0.15) if started else clock * 20.0
	for i in 8:
		var tx := fposmod(i * 50.0 - slide * 0.25, 400.0) - 40.0
		var th := 30.0 + (i * 19) % 22
		c.draw_rect(Rect2(tx - 2, GROUND - th * 0.5, 4, th * 0.5), col("night"))
		c.draw_circle(Vector2(tx, GROUND - th * 0.6), th * 0.35, col("night"))
		c.draw_circle(Vector2(tx - 6, GROUND - th * 0.45), th * 0.25, col("night"))
		c.draw_circle(Vector2(tx + 6, GROUND - th * 0.45), th * 0.25, col("night"))
	for i in 6:
		var fx := fposmod(i * 61.0 + sin(clock * 0.7 + i) * 20.0 - slide * 0.15, 320.0)
		var fy := 40.0 + (i * 29) % 90 + sin(clock * 1.3 + i * 2.0) * 6.0
		var on := 0.3 + 0.7 * absf(sin(clock * 2.0 + i))
		glow(c, Vector2(fx, fy), 5.0, col("lamp"), 0.4 * on)
		c.draw_rect(Rect2(fx, fy, 1, 1), col("lamp", on))
	var opening := maxf(46.0, 62.0 - score * 0.08)
	for h: Dictionary in hedges:
		var top: float = h.mid - opening / 2.0
		var bottom: float = h.mid + opening / 2.0
		for part: Rect2 in [Rect2(h.x, TOP - 4, HEDGE_W, top - TOP + 4), Rect2(h.x, bottom, HEDGE_W, GROUND - bottom)]:
			var edge_y := part.end.y if part.position.y < TOP else part.position.y
			c.draw_rect(part, col("moss").darkened(0.2))
			c.draw_rect(Rect2(part.position.x + 2, part.position.y, HEDGE_W - 6, part.size.y), col("moss"))
			for k in 5:
				c.draw_circle(Vector2(h.x + 2 + k * 4.5, edge_y), 3.5, col("moss"))
			c.draw_rect(Rect2(h.x + 3, edge_y - (2.0 if part.position.y < TOP else -1.0), HEDGE_W - 8, 1), col("wake", 0.5))
			for k in int(part.size.y / 9.0):
				var ly := part.position.y + 5 + k * 9
				c.draw_rect(Rect2(h.x + 4 + (k * 7) % 12, ly, 3, 2), col("wake", 0.35))
				if k % 3 == 1:
					c.draw_circle(Vector2(h.x + 14 - (k * 5) % 10, ly + 3), 1.2, col("hush"))
	c.draw_rect(Rect2(0, GROUND, 320, 12), col("moss").darkened(0.45))
	for i in 54:
		var gx := fposmod(i * 6.0 - slide, 324.0) - 2.0
		var sway := sin(clock * 3.0 + i) * 1.0
		c.draw_line(Vector2(gx, GROUND + 1), Vector2(gx + sway, GROUND - 3 - (i * 7) % 4), col("moss"), 1.0)
	var p := Vector2(FLY_X, y)
	var tilt := clampf(vy / 300.0, -0.6, 0.8) if started else 0.0
	var on := 0.6 + 0.4 * absf(sin(clock * 4.0))
	glow(c, p + Vector2(-2, 0), 16.0, col("lamp"), 0.5 * on)
	c.draw_set_transform(p, tilt)
	var flap := absf(sin(clock * 22.0))
	c.draw_colored_polygon(PackedVector2Array([Vector2(1, -1), Vector2(-3, -6 - flap * 2.0), Vector2(-1, -1)]), col("seafoam", 0.8))
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, -1), Vector2(-5, -5 - flap * 2.0), Vector2(-2, -1)]), col("froth", 0.7))
	c.draw_circle(Vector2(-2.5, 0.5), 2.8, col("lamp"))
	c.draw_circle(Vector2(-3, 0.5), 1.3, col("moon", on))
	c.draw_circle(Vector2(1.5, 0), 2.2, col("walnut"))
	c.draw_rect(Rect2(2, -1, 1, 1), col("moon"))
	c.draw_line(Vector2(3, -1), Vector2(6, -4), col("fog"))
	c.draw_set_transform(Vector2.ZERO)
