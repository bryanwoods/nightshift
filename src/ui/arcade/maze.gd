extends ArcadeGame
## Moth Maze: a moth eats lamp crumbs in a maze while shadow puffs chase it.
## A big lantern crumb scares the shadows for a while, and then the moth can eat them.

const MAP: PackedStringArray = [
	"#####################",
	"#.........#.........#",
	"#o##.####.#.####.##o#",
	"#...................#",
	"#.##.#.#######.#.##.#",
	"#....#....#....#....#",
	"####.####.#.####.####",
	"####.#...GGG...#.####",
	"####.#.#######.#.####",
	"#.........#.........#",
	"#.##.####.#.####.##.#",
	"#o##.............##o#",
	"#.##.#.##.#.##.#.##.#",
	"#....#....#....#....#",
	"#####################",
]
const CELL := 10.0
const ORIGIN := Vector2(55, 22)
const MOTH_START := Vector2i(10, 11)
const HOME := Vector2i(10, 7)
const SHADOW_COLORS: PackedStringArray = ["hush", "violet", "aqua"]
const SCARED_SECONDS := 8.0
const LATE_TURN := 0.4

var lives: int
var level: int
var crumbs: Dictionary
var moth: Dictionary
var shadows: Array
var scared: float
var clock: float
var chomp: bool


func reset() -> void:
	lives = 4
	level = 0
	_fill()


func _fill() -> void:
	crumbs = {}
	for y in MAP.size():
		for x in MAP[y].length():
			if MAP[y][x] in ".o" and Vector2i(x, y) != MOTH_START:
				crumbs[Vector2i(x, y)] = MAP[y][x] == "o"
	_place()


func _place() -> void:
	moth = {"cell": MOTH_START, "dir": Vector2i.ZERO, "want": Vector2i.ZERO, "t": 0.0}
	shadows = []
	for i in 3:
		shadows.append({"cell": HOME + Vector2i(i - 1, 0), "dir": Vector2i.ZERO, "t": 0.0, "wait": 2.0 + i * 3.0, "eyes": false})
	scared = 0.0


func _open(c: Vector2i) -> bool:
	return c.y >= 0 and c.y < MAP.size() and c.x >= 0 and c.x < MAP[c.y].length() and MAP[c.y][c.x] != "#"


func step(dt: float) -> bool:
	clock += dt
	scared = maxf(0.0, scared - dt)
	var d := pressed_dir()
	if d == Vector2i.ZERO:
		for a: String in DIRS:
			if Input.is_action_pressed(a):
				d = DIRS[a]
	if d != Vector2i.ZERO:
		moth.want = d
	_move_moth(dt * 6.0)
	for s: Dictionary in shadows:
		if s.wait > 0.0:
			s.wait -= dt
			continue
		var speed := 10.0 if s.eyes else (2.6 if scared > 0.0 else 3.8 + level * 0.3)
		_move_shadow(s, dt * speed)
		if s.eyes:
			if s.cell == HOME:
				s.eyes = false
			continue
		if _pos(s).distance_to(_pos(moth)) < 5.5:
			if scared > 0.0:
				s.eyes = true
				score += 200
				burst(_pos(s), SHADOW_COLORS[shadows.find(s)], 16, 70.0, 0.0)
				popup(_pos(s), "200", "lamp")
				jolt(2.0)
				AudioBus.sfx("a_maze_eat")
			else:
				lives -= 1
				burst(_pos(moth), "lilac", 24, 80.0, 40.0)
				jolt(5.0)
				blink("hush", 0.6)
				AudioBus.sfx("a_maze_die")
				if lives <= 0:
					return false
				_place()
				freeze = 1.0
				return true
	if crumbs.is_empty():
		level += 1
		blink("moon", 0.8)
		popup(Vector2(160, 90), "CLEAR!", "wake")
		AudioBus.sfx("a_coin")
		_fill()
	return true


func _move_moth(amount: float) -> void:
	if moth.dir == Vector2i.ZERO and _open(moth.cell + moth.want):
		moth.dir = moth.want
	if moth.dir != Vector2i.ZERO and moth.want == -moth.dir:
		moth.cell += moth.dir
		moth.dir = moth.want
		moth.t = 1.0 - moth.t
	elif moth.dir != Vector2i.ZERO and moth.want != moth.dir and moth.t < LATE_TURN and _open(moth.cell + moth.want):
		moth.dir = moth.want
		moth.t = 0.0
	if moth.dir == Vector2i.ZERO:
		return
	moth.t += amount
	while moth.t >= 1.0:
		moth.t -= 1.0
		moth.cell += moth.dir
		_eat(moth.cell)
		if _open(moth.cell + moth.want):
			moth.dir = moth.want
		elif not _open(moth.cell + moth.dir):
			var bends: Array = DIRS.values().filter(func(d: Vector2i) -> bool: return d != -moth.dir and _open(moth.cell + d))
			if bends.size() == 1:
				moth.dir = bends[0]
				moth.want = bends[0]
				continue
			moth.dir = Vector2i.ZERO
			moth.t = 0.0
			return


func _eat(c: Vector2i) -> void:
	if not crumbs.has(c):
		return
	if crumbs[c]:
		scared = SCARED_SECONDS
		score += 50
		burst(ORIGIN + Vector2(c) * CELL + Vector2(5, 5), "lamp", 14, 50.0, 0.0)
		blink("lamp", 0.3)
		AudioBus.sfx("a_maze_power")
	else:
		score += 10
		burst(ORIGIN + Vector2(c) * CELL + Vector2(5, 5), "straw", 3, 25.0, 0.0)
		chomp = not chomp
		AudioBus.sfx("a_maze_chomp_a" if chomp else "a_maze_chomp_b", 1.0, -4.0)
	crumbs.erase(c)


func _move_shadow(s: Dictionary, amount: float) -> void:
	if s.dir == Vector2i.ZERO:
		s.dir = _choose(s)
	s.t += amount
	while s.t >= 1.0:
		s.t -= 1.0
		s.cell += s.dir
		s.dir = _choose(s)


func _choose(s: Dictionary) -> Vector2i:
	var target: Vector2i = HOME if s.eyes else moth.cell
	var options: Array[Vector2i] = []
	for d: Vector2i in DIRS.values():
		if _open(s.cell + d) and d != -s.dir:
			options.append(d)
	if options.is_empty():
		return -s.dir
	if not s.eyes and rng.randf() < 0.4:
		return options[rng.randi() % options.size()]
	var away: bool = scared > 0.0 and not s.eyes
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector2(s.cell + a - target).length()
		var db := Vector2(s.cell + b - target).length()
		return da > db if away else da < db)
	return options[0]


func _pos(m: Dictionary) -> Vector2:
	return ORIGIN + (Vector2(m.cell) + Vector2(m.dir) * m.t) * CELL + Vector2(CELL, CELL) / 2.0


func draw(c: CanvasItem) -> void:
	sky(c, col("night"), col("ink"), 0.0, 180.0)
	stars(c, clock, 20, 170.0)
	var size := Vector2(MAP[0].length(), MAP.size()) * CELL
	c.draw_rect(Rect2(ORIGIN, size), col("ink"))
	for layer: Array in [[3.0, col("violet", 0.18)], [2.0, col("slate")], [1.0, col("dusk")]]:
		for y in MAP.size():
			for x in MAP[y].length():
				if MAP[y][x] == "#":
					c.draw_rect(Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(layer[0]), layer[1])
	for y in MAP.size():
		for x in MAP[y].length():
			if MAP[y][x] == "#" and y > 0 and _open(Vector2i(x, y - 1)):
				c.draw_rect(Rect2(ORIGIN + Vector2(x * CELL - 1, y * CELL - 1), Vector2(CELL + 2, 1)), col("lilac", 0.5))
	for cell: Vector2i in crumbs:
		var p := ORIGIN + Vector2(cell) * CELL + Vector2(CELL, CELL) / 2.0
		if crumbs[cell]:
			glow(c, p, 9.0 + sin(clock * 6.0) * 2.0, col("lamp"), 0.5)
			c.draw_circle(p, 3.0 + sin(clock * 8.0) * 0.6, col("lamp"))
			c.draw_circle(p + Vector2(-1, -1), 1.0, col("moon"))
		else:
			c.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), col("straw", 0.25))
			c.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), col("straw"))
	var mp := _pos(moth)
	if moth.dir != Vector2i.ZERO and rng.randf() < 0.3:
		_parts.append({"pos": mp - Vector2(moth.dir) * 4.0, "vel": Vector2.ZERO, "life": 0.4, "max": 0.4, "color": col("lilac"), "size": 1.5, "gravity": 0.0})
	glow(c, mp, 10.0, col("lilac"), 0.4)
	_moth(c, mp, 1.0)
	for i in shadows.size():
		var s: Dictionary = shadows[i]
		var p := _pos(s)
		var look := (mp - p).normalized()
		if not s.eyes:
			var tint := SHADOW_COLORS[i]
			if scared > 0.0:
				tint = "slate" if scared > 2.0 or int(clock * 8.0) % 2 == 0 else "moon"
			glow(c, p, 9.0, col(tint), 0.3)
			var bob := sin(clock * 6.0 + i) * 0.8
			c.draw_circle(p + Vector2(0, bob - 0.5), 4.5, col(tint))
			c.draw_rect(Rect2(p + Vector2(-4.5, bob - 0.5), Vector2(9, 3)), col(tint))
			for k in 4:
				c.draw_circle(p + Vector2(-3.4 + k * 2.3, 3.0 + bob + sin(clock * 12.0 + k * 1.7) * 0.8), 1.3, col(tint))
			c.draw_circle(p + Vector2(-2, bob - 3), 1.0, Color(1, 1, 1, 0.35))
			if scared > 0.0:
				for k in 4:
					c.draw_rect(Rect2(p + Vector2(-3 + k * 1.6, bob + 1.5 + (k % 2)), Vector2(1, 1)), col("ink"))
		for side: float in [-1.6, 1.6]:
			var e := p + Vector2(side, -1.0)
			c.draw_rect(Rect2(e - Vector2(1, 1), Vector2(2, 2)), col("moon"))
			if scared <= 0.0 or s.eyes:
				c.draw_rect(Rect2(e + look * 0.8 - Vector2(0.5, 0.5), Vector2(1, 1)), col("ink"))
	for i in lives:
		_moth(c, Vector2(290 - i * 14, 9), 0.7)


func _moth(c: CanvasItem, p: Vector2, size: float) -> void:
	var flap := 0.65 + 0.35 * absf(sin(clock * 14.0))
	for sx: float in [-1.0, 1.0]:
		var top := p + Vector2(sx * 4.0 * flap, -1.5) * size
		var low := p + Vector2(sx * 3.0 * flap, 2.5) * size
		c.draw_circle(top, 3.5 * size, col("lilac"))
		c.draw_circle(low, 2.5 * size, col("lilac"))
		c.draw_circle(top + Vector2(sx * 0.5, -0.5) * size, 1.4 * size, col("blossom"))
		c.draw_line(p + Vector2(sx * 1.0, -2.5) * size, p + Vector2(sx * 3.0, -6.0) * size, col("fog"))
		c.draw_circle(p + Vector2(sx * 3.0, -6.0) * size, 1.0 * size, col("straw"))
	c.draw_circle(p, 3.0 * size, col("froth"))
	c.draw_circle(p + Vector2(0, 2.2) * size, 2.0 * size, col("froth"))
	if size < 1.0:
		return
	for sx: float in [-1.0, 1.0]:
		c.draw_rect(Rect2(p + Vector2(sx * 1.3 - 0.5, -1.0), Vector2(1, 2)), col("ink"))
		c.draw_rect(Rect2(p + Vector2(sx * 2.2 - 0.5, 1.0), Vector2(1, 1)), col("blossom"))
