class_name ArcadeGame
extends RefCounted
## One arcade game. step returns false when the game is over.
## Effects every game shares: sparkle bursts, floating points, screen shake and a flash.

const FONT := preload("res://assets/fonts/m6x11.ttf")
const DIRS := {"move_up": Vector2i.UP, "move_down": Vector2i.DOWN, "move_left": Vector2i.LEFT, "move_right": Vector2i.RIGHT}

var score: int = 0
var rng := RandomNumberGenerator.new()
var shake: float = 0.0
var flash: float = 0.0
var freeze: float = 0.0
var flash_color := Color.WHITE
var _parts: Array = []
var _popups: Array = []


func reset() -> void:
	pass


func step(_dt: float) -> bool:
	return true


func draw(_c: CanvasItem) -> void:
	pass


func burst(pos: Vector2, color: String, n := 10, speed := 60.0, gravity := 60.0) -> void:
	for i in n:
		var life := rng.randf_range(0.3, 0.7)
		_parts.append({"pos": pos, "vel": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(speed * 0.3, speed),
			"life": life, "max": life, "color": col(color), "size": rng.randf_range(1.0, 2.5), "gravity": gravity})


func popup(pos: Vector2, text: String, color := "moon") -> void:
	_popups.append({"pos": pos, "text": text, "color": col(color), "t": 0.0})


func jolt(amount := 3.0) -> void:
	shake = maxf(shake, amount)


func blink(color: String, amount := 0.5) -> void:
	flash_color = col(color)
	flash = maxf(flash, amount)


func tick_fx(dt: float) -> void:
	shake = maxf(0.0, shake - dt * 12.0)
	flash = maxf(0.0, flash - dt * 2.0)
	for p: Dictionary in _parts.duplicate():
		p.life -= dt
		if p.life <= 0.0:
			_parts.erase(p)
			continue
		p.vel.y += p.gravity * dt
		p.pos += p.vel * dt
	for p: Dictionary in _popups.duplicate():
		p.t += dt
		if p.t > 0.9:
			_popups.erase(p)


func draw_fx(c: CanvasItem) -> void:
	for p: Dictionary in _parts:
		var k: float = p.life / p.max
		var s: float = p.size * (0.5 + k * 0.5)
		c.draw_rect(Rect2(p.pos - Vector2(s, s) / 2.0, Vector2(s, s)), Color(p.color, k))
	for p: Dictionary in _popups:
		var at: Vector2 = p.pos - Vector2(20, 6.0 + p.t * 18.0)
		var a := clampf(1.6 - p.t * 1.8, 0.0, 1.0)
		c.draw_string(FONT, at + Vector2(1, 1), p.text, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(col("ink"), a))
		c.draw_string(FONT, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(p.color, a))


static func pressed_dir() -> Vector2i:
	for a: String in DIRS:
		if Input.is_action_just_pressed(a):
			return DIRS[a]
	return Vector2i.ZERO


static func col(name: String, a := 1.0) -> Color:
	return Color(Game.color(name), a)


## A soft round glow: stacked see-through circles, brightest in the middle.
static func glow(c: CanvasItem, p: Vector2, r: float, color: Color, strength := 0.35) -> void:
	for i in 6:
		c.draw_circle(p, r * (1.0 - i / 6.0), Color(color, strength / 6.0))


## A sky that fades from one colour at the top to another at the bottom, in 4px bands.
static func sky(c: CanvasItem, top: Color, bottom: Color, y0 := 0.0, y1 := 180.0) -> void:
	var y := y0
	while y < y1:
		c.draw_rect(Rect2(0, y, 320, 4), top.lerp(bottom, (y - y0) / (y1 - y0)))
		y += 4.0


## Stars that twinkle in place. The same seed always puts them in the same spots.
static func stars(c: CanvasItem, clock: float, n := 30, y1 := 160.0, drift := 0.0) -> void:
	for i in n:
		var x := fposmod(float((i * 97 + 13) % 316) + 2.0 - clock * drift * (1 + i % 3), 320.0)
		var y := 16.0 + float((i * 53 + 7) % int(y1 - 16.0))
		var tw := 0.4 + 0.6 * absf(sin(clock * (1.0 + i % 5 * 0.4) + i))
		c.draw_rect(Rect2(x, y, 1, 1), col("moon" if i % 4 == 0 else "fog", tw))
		if i % 9 == 0:
			c.draw_rect(Rect2(x - 1, y, 3, 1), col("moon", tw * 0.4))
			c.draw_rect(Rect2(x, y - 1, 1, 3), col("moon", tw * 0.4))
