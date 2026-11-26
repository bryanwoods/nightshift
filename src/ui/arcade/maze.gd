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
	"####.####...####.####",
	"####.#...GGG...#.####",
	"####.#.#######.#.####",
	"#.........#.........#",
	"#.##.####.#.####.##.#",
	"#o.#.............#.o#",
	"#..#.#.##.#.##.#.#..#",
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
				AudioBus.sfx("satisfied")
			else:
				lives -= 1
				AudioBus.sfx("hit")
				if lives <= 0:
					return false
				_place()
				return true
	if crumbs.is_empty():
		level += 1
		AudioBus.sfx("chime")
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
		AudioBus.sfx("flicker")
	else:
		score += 10
		if score % 50 == 0:
			AudioBus.sfx("tick", 1.4, -8.0)
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
	for y in MAP.size():
		for x in MAP[y].length():
			var r := Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			if MAP[y][x] == "#":
				c.draw_rect(r.grow(-1), col("dusk"))
				c.draw_rect(r.grow(-1), col("slate"))
	for cell: Vector2i in crumbs:
		var p := ORIGIN + Vector2(cell) * CELL + Vector2(CELL, CELL) / 2.0
		if crumbs[cell]:
			c.draw_circle(p, 3.0 + sin(clock * 8.0), col("lamp"))
		else:
			c.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), col("straw"))
	var mp := _pos(moth)
	_moth(c, _pos(moth), 1.0)
	for i in shadows.size():
		var s: Dictionary = shadows[i]
		var p := _pos(s)
		if not s.eyes:
			var tint := SHADOW_COLORS[i]
			if scared > 0.0:
				tint = "fog" if scared > 2.0 or int(clock * 8.0) % 2 == 0 else "moon"
			c.draw_circle(p + Vector2(0, sin(clock * 6.0 + i) * 0.8), 4.5, col(tint))
			for k in 3:
				c.draw_circle(p + Vector2(-3.0 + k * 3.0, 3.5 + sin(clock * 10.0 + k) * 0.7), 1.6, col(tint))
		for side in [-1.5, 1.5]:
			c.draw_rect(Rect2(p + Vector2(side - 0.5, -1.5), Vector2(1, 2)), col("ink" if not s.eyes and scared <= 0.0 else "moon"))
	for i in lives:
		_moth(c, Vector2(290 - i * 14, 8), 0.7)


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
