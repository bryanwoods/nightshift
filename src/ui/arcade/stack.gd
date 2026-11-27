extends ArcadeGame
## Pancake Stack: a pancake slides back and forth over the stack. Drop it, and whatever
## hangs over the edge falls off. A near-perfect drop snaps into place for a bonus.

const BASE_Y := 166.0
const H := 7.0
const SHOW := 16

var stack: Array
var x: float
var w: float
var dir: float
var crumbs: Array
var clock: float
var drip: float


func reset() -> void:
	stack = [Vector2(110, 100)]
	crumbs = []
	drip = 0.0
	_next()


func _next() -> void:
	w = stack.back().y
	dir = 1.0 if stack.size() % 2 == 0 else -1.0
	x = 20.0 if dir > 0.0 else 300.0 - w


func step(dt: float) -> bool:
	clock += dt
	drip = minf(1.0, drip + dt * 0.6)
	x += dir * (80.0 + stack.size() * 6.0) * dt
	if x < 10.0 or x + w > 310.0:
		dir = -dir
		x = clampf(x, 10.0, 310.0 - w)
	for c: Dictionary in crumbs.duplicate():
		c.v += 300.0 * dt
		c.pos.y += c.v * dt
		c.spin += c.turn * dt
		if c.pos.y > 200.0:
			crumbs.erase(c)
	if not (Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("move_down")):
		return true
	var top: Vector2 = stack.back()
	var left := maxf(x, top.x)
	var right := minf(x + w, top.x + top.y)
	var y := _y(stack.size())
	if right - left <= 0.0:
		burst(Vector2(x + w / 2.0, y), "straw", 20, 80.0, 200.0)
		jolt(5.0)
		blink("hush", 0.4)
		AudioBus.sfx("a_stack_fail")
		return false
	if absf(x - top.x) < 2.5:
		left = top.x
		right = top.x + top.y
		score += 15
		burst(Vector2(left + (right - left) / 2.0, y), "lamp", 18, 70.0, 0.0)
		popup(Vector2(left + (right - left) / 2.0, y - 8), "PERFECT!", "lamp")
		blink("lamp", 0.3)
		AudioBus.sfx("a_stack_perfect", 1.0 + mini(stack.size(), 20) * 0.02)
	else:
		score += 10
		popup(Vector2(left + (right - left) / 2.0, y - 8), "+10", "moon")
		AudioBus.sfx("a_stack_drop", 1.0 + mini(stack.size(), 20) * 0.03)
		var cut := Rect2(x, y, left - x, H) if x < left else Rect2(right, y, x + w - right, H)
		crumbs.append({"pos": cut.position, "w": cut.size.x, "v": 0.0, "spin": 0.0, "turn": -3.0 if x < left else 3.0})
	jolt(1.0)
	drip = 0.0
	stack.append(Vector2(left, right - left))
	_next()
	return true


func _scroll() -> float:
	return maxf(0.0, stack.size() - SHOW) * H


func _y(i: int) -> float:
	return BASE_Y - (i + 1) * H + _scroll()


func draw(c: CanvasItem) -> void:
	sky(c, col("dusk"), col("night"), 0.0, 180.0)
	var win := Rect2(22, 24 + _scroll() * 0.3, 60, 46)
	c.draw_rect(win.grow(3), col("walnut"))
	c.draw_rect(win, col("ink"))
	glow(c, win.position + Vector2(40, 14), 14.0, col("moon"), 0.4)
	c.draw_circle(win.position + Vector2(40, 14), 6.0, col("moon"))
	for i in 5:
		c.draw_rect(Rect2(win.position + Vector2(6 + i * 11, 10 + (i * 17) % 30), Vector2(1, 1)), col("moon", 0.4 + 0.6 * absf(sin(clock * 2.0 + i))))
	c.draw_rect(Rect2(win.position.x + 29, win.position.y, 2, win.size.y), col("walnut"))
	c.draw_rect(Rect2(win.position.x, win.position.y + 22, win.size.x, 2), col("walnut"))
	var shelf := Rect2(232, 44 + _scroll() * 0.3, 70, 3)
	c.draw_rect(shelf, col("walnut"))
	for i in 3:
		var jx := shelf.position.x + 6 + i * 22
		c.draw_rect(Rect2(jx, shelf.position.y - 12, 12, 12), col(["blossom", "lamp", "wake"][i], 0.6))
		c.draw_rect(Rect2(jx, shelf.position.y - 14, 12, 3), col("honey"))
		c.draw_rect(Rect2(jx + 2, shelf.position.y - 10, 1, 7), col("froth", 0.6))
	var plate_y := BASE_Y + _scroll()
	c.draw_rect(Rect2(80, plate_y + 3, 160, 3), col("ink", 0.4))
	c.draw_rect(Rect2(86, plate_y, 148, 4), col("froth"))
	c.draw_rect(Rect2(86, plate_y + 3, 148, 1), col("seafoam"))
	for i in stack.size():
		var p: Vector2 = stack[i]
		if i > 0:
			_pancake(c, p.x, _y(i - 1), p.y)
	var top: Vector2 = stack.back()
	if stack.size() > 1:
		var ty := _y(stack.size() - 2)
		for k in 3:
			var dx := top.x + top.y * (0.2 + k * 0.3)
			c.draw_rect(Rect2(dx, ty + 2, 2, 2 + drip * (3 + k * 2)), col("honey"))
			c.draw_circle(Vector2(dx + 1, ty + 4 + drip * (3 + k * 2)), 1.3, col("honey"))
		c.draw_rect(Rect2(top.x + top.y / 2.0 - 4, ty - 3, 8, 3), col("lamp"))
		c.draw_rect(Rect2(top.x + top.y / 2.0 - 3, ty - 3, 3, 1), col("moon"))
	var hover := _y(stack.size() - 1) - 6.0 - 3.0 * absf(sin(clock * 3.0))
	c.draw_rect(Rect2(x + 2, _y(stack.size() - 1) + 1, w - 4, 1), col("ink", 0.3))
	_pancake(c, x, hover, w)
	for cr: Dictionary in crumbs:
		c.draw_set_transform(cr.pos + Vector2(cr.w / 2.0, H / 2.0), cr.spin)
		_pancake(c, -cr.w / 2.0, -H / 2.0, cr.w)
		c.draw_set_transform(Vector2.ZERO)


func _pancake(c: CanvasItem, px: float, py: float, pw: float) -> void:
	if pw <= 0.0:
		return
	var r := (H - 1) / 2.0
	c.draw_rect(Rect2(px + r, py, maxf(0.0, pw - r * 2.0), H - 1), col("straw"))
	c.draw_circle(Vector2(px + r, py + r), r, col("straw"))
	c.draw_circle(Vector2(px + pw - r, py + r), r, col("straw"))
	c.draw_rect(Rect2(px + 1, py + H - 3, maxf(0.0, pw - 2), 2), col("honey"))
	c.draw_rect(Rect2(px + 3, py, maxf(0.0, pw - 6), 1), col("moon", 0.7))
	for k in int(pw / 14.0):
		c.draw_rect(Rect2(px + 6 + k * 14, py + 2, 2, 1), col("honey", 0.6))
