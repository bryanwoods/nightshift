class_name Pattern
extends RefCounted
## Base for one dodge pattern. A subclass spawns bullets in _spawn(); this class moves them,
## checks hits and takes the snapshots that rewind restores. The pattern type in a worker
## file is the name of a script in this folder.

enum Kind { SPRITE, BAR, RING, LANE, BLOCK, STAFF, FENCE, BLADE, FORK, GRASS, TREE, GOO, BLAZE, SPIKES }

const LANE_DROP := 600.0
const SHINE_REACH := 30.0
const SHINE_HALF_ANGLE := 0.61
const CHARGE_FULL := 0.6
const BLADE_HOLD := 1.5
const BLADE_GLIDE := 1.2
const FORK_DROP := 0.12
const FORK_LIFT := 0.25
const FORK_TINES := 10.0
const GRASS_RISE := 0.08
const GRASS_FALL := 0.15
const TRUNK_GROW := 0.8
const BRANCH_WARN := 0.6
const BRANCH_GROW := 1.0
const BRANCH_THICK := 5.0
const GOO_RECEDE := 0.6
const BLAZE_RISE := 0.25
const BLAZE_FALL := 0.3
const SPIKE_DEPTH := 11.0


class Bullet:
	var kind: int = Kind.SPRITE
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var tex: String = ""
	## Sprite: hit radius. Ring: current radius. Lane: age, scaled by grow (its pace).
	## Blade and fork: age in seconds.
	## Block, staff and fence: half the height.
	var radius: float = 3.0
	## Bar, lane, block, staff and fence: width. Ring: thickness. Blade: radius of its arc.
	var width: float = 6.0
	## Bar: y of the gap. Ring: angle of the gap. Lane: strike time. Blade: start angle.
	## Fork: seconds it stays stuck in the plate.
	var gap_center: float = 0.0
	## Bar: gap in px. Ring: gap in radians. Lane and fork: warning time. Blade: signed sweep.
	var gap: float = 0.0
	var grow: float = 0.0
	## Drift: turn rate. Lane: angle of the beam. Staff and blade: their tilt.
	var steer: float = 0.0
	var alive: bool = true
	## Blade: center of its arc.
	var anchor: Vector2 = Vector2.ZERO
	## Sprite: how high above its shadow it flies. It cannot hit while it is up.
	var height: float = 0.0
	## Tree: one [height above the foot, side (-1 or 1), delay] for each branch.
	var parts: PackedFloat32Array = []

	func copy() -> Bullet:
		var b := Bullet.new()
		b.kind = kind
		b.pos = pos
		b.vel = vel
		b.tex = tex
		b.radius = radius
		b.width = width
		b.gap_center = gap_center
		b.gap = gap
		b.grow = grow
		b.steer = steer
		b.alive = alive
		b.anchor = anchor
		b.height = height
		b.parts = parts.duplicate()
		return b


const DIR := "res://src/battle/patterns/"

var params: Dictionary = {}
var duration: float = 6.0
var t: float = 0.0
var spawned: int = 0
var bullets: Array[Bullet] = []
var half: Vector2 = Vector2(60, 40)
var damage: int = 2
var dark: bool = false
## True: the box is drawn as a plate.
var plate: bool = false
## True: the token is Tadzio with a plate on their head. Stack is what they have caught on it.
var catcher: bool = false
var stack: Array[String] = []
## Pushes the token this many px/s, every step.
var pull: Vector2 = Vector2.ZERO
## The worker's pose during this pattern: a sheet named <sprite>_<pose>, or "" for idle.
var pose: String = ""
## How thick the cloud over the box is, from 0 to 1.
var fog: float = 0.0
## The dodge round of the fight, from 0.
var fight_round: int = 0
## True: the token stays in the middle, and the arrows turn the flashlight to facing.
var locked: bool = false
var facing: Vector2 = Vector2.UP
## True: the token moves only left and right on its row. Lift is how far above that row a
## dash has carried it. Charge is how long confirm has been held.
var rail: bool = false
var lift: float = 0.0
## How far the box is turned, in radians. Bullets and the token live in the turned box.
var turn: float = 0.0
var charge: float = 0.0
var rng := RandomNumberGenerator.new()


static func exists(type: String) -> bool:
	return type != "pattern" and ResourceLoader.exists(DIR + type + ".gd")


static func create(p: Dictionary, arena: Vector2, hit_damage: int) -> Pattern:
	var type := str(p.get("type", ""))
	if not exists(type):
		Game.report("patterns", type, "no pattern script src/battle/patterns/%s.gd" % type)
		return null
	var pat: Pattern = load(DIR + type + ".gd").new()
	pat.setup(p, arena, hit_damage)
	return pat


static func arena_for(p: Dictionary, fallback: Vector2) -> Vector2:
	var a: Variant = p.get("arena", (p.get("inner", {}) as Dictionary).get("arena", null))
	if a is Array and (a as Array).size() == 2:
		return Vector2(float(a[0]), float(a[1]))
	return fallback


func setup(p: Dictionary, arena: Vector2, hit_damage: int) -> void:
	params = p
	duration = float(p.get("duration", 6.0))
	half = arena / 2.0
	damage = int(p.get("damage", hit_damage))
	rng.randomize()
	_init_pattern()


func _init_pattern() -> void:
	pass


func _spawn() -> void:
	pass


func _steer(_b: Bullet, _dt: float, _token: Vector2) -> void:
	pass


func token_start() -> Vector2:
	return Vector2.ZERO


func finished() -> bool:
	return t >= duration


func step(dt: float, token: Vector2) -> void:
	t += dt
	_spawn()
	for b in bullets:
		_steer(b, dt, token)
		b.pos += b.vel * dt
		b.radius += b.grow * dt
	bullets.assign(bullets.filter(func(b: Bullet) -> bool: return b.alive and not _gone(b)))


func _gone(b: Bullet) -> bool:
	match b.kind:
		Kind.BAR:
			return (b.vel.x > 0 and b.pos.x > half.x + 8) or (b.vel.x < 0 and b.pos.x < -half.x - 8)
		Kind.RING:
			return b.radius > half.length() + 6
		Kind.LANE:
			return b.radius > b.gap + b.gap_center
		Kind.STAFF, Kind.FENCE:
			return false
		Kind.BLADE:
			return b.radius > BLADE_HOLD + BLADE_GLIDE + 0.15
		Kind.FORK:
			return b.radius > b.gap + FORK_DROP + b.gap_center + FORK_LIFT
		Kind.GRASS:
			return b.radius > b.gap + GRASS_RISE + b.gap_center + GRASS_FALL
		Kind.TREE:
			return b.radius > b.gap
		Kind.GOO:
			return b.radius > b.gap + b.gap_center + GOO_RECEDE
		Kind.BLAZE:
			return b.radius > b.gap + BLAZE_RISE + b.gap_center + BLAZE_FALL
		Kind.SPIKES:
			return false
	return b.pos.y > half.y + 10 or b.pos.y < -half.y - 14 or absf(b.pos.x) > half.x + 14


func collide(token: Vector2, r: float) -> int:
	for b in bullets:
		if _hits(b, token, r):
			if b.kind in [Kind.SPRITE, Kind.BLOCK]:
				b.alive = false
			return damage
	return 0


func would_hit(token: Vector2, r: float, lookahead: float) -> bool:
	for b in bullets:
		var f := b.copy()
		f.pos += f.vel * lookahead
		f.radius += f.grow * lookahead
		if _hits(f, token, r):
			return true
	return false


func _hits(b: Bullet, p: Vector2, r: float) -> bool:
	if b.height > 3.0:
		return false
	match b.kind:
		Kind.BAR:
			return absf(p.x - b.pos.x) < b.width / 2.0 + r and absf(p.y - b.gap_center) > b.gap / 2.0 - r
		Kind.RING:
			var d := p.distance_to(b.pos)
			if absf(d - b.radius) > b.width / 2.0 + r:
				return false
			return absf(angle_difference((p - b.pos).angle(), b.gap_center)) > b.gap / 2.0
		Kind.BLOCK:
			return absf(p.x - b.pos.x) < b.width / 2.0 + r and absf(p.y - b.pos.y) < b.radius + r
		Kind.FENCE:
			return false
		Kind.BLADE:
			var tip := (p - b.pos).rotated(-b.steer)
			return b.radius >= BLADE_HOLD and absf(tip.x) < 9.0 + r and absf(tip.y) < 2.5 + r
		Kind.FORK:
			var tip := fork_tip(b)
			var reach := b.width / 2.0 if p.y > tip - FORK_TINES - r else 2.0
			return p.y < tip + r and absf(p.x - b.pos.x) < reach + r
		Kind.GRASS:
			if b.radius < b.gap:
				return false
			var into := (p - b.pos).rotated(-b.steer)
			return absf(into.y) < b.width / 2.0 + r and into.x < grass_length(b) + r
		Kind.TREE:
			var top := b.pos.y - trunk_length(b)
			if absf(p.x - b.pos.x) < 4.0 + r and p.y > top - r:
				return true
			if trunk_length(b) > 0.85 * b.gap_center and p.distance_to(Vector2(b.pos.x, top - 12.0)) < 12.0 + r:
				return true
			for i in b.parts.size() / 3:
				var reach := branch_reach(b, i)
				var y := b.pos.y - b.parts[i * 3]
				var side := b.parts[i * 3 + 1]
				if reach > 0.0 and absf(p.y - y) < BRANCH_THICK / 2.0 + r and (p.x - b.pos.x) * side > -r and (p.x - b.pos.x) * side < reach + r:
					return true
			return false
		Kind.GOO:
			return p.y - r < goo_edge(b, p.x)
		Kind.BLAZE:
			return b.radius >= b.gap and p.y + r > blaze_edge(b, p.x)
		Kind.SPIKES:
			var side := Vector2.from_angle(b.steer)
			var along := absf(side.dot(half))
			var a := p.dot(side.orthogonal())
			return p.dot(side) + r > along - SPIKE_DEPTH * minf(1.0, b.radius / 0.5) and a > b.gap - r and a < b.gap_center + r
		Kind.STAFF:
			var local := (p - b.pos).rotated(-b.steer)
			return absf(local.x) < b.width / 2.0 + r and absf(local.y) < b.radius + r
		Kind.LANE:
			var d := Vector2.from_angle(b.steer)
			var u := (p - b.pos).dot(d)
			return absf((p - b.pos).cross(d)) < b.width / 2.0 + r and u > -r and u - r < lane_reach(b)
	return b.pos.distance_to(p) < b.radius + r


## How far into the box a lane has struck, or -INF while it still hovers outside.
func lane_reach(b: Bullet) -> float:
	return (b.radius - b.gap) * LANE_DROP if b.radius >= b.gap else -INF


## The y of a fork's tips, or -INF while its "!" still warns. It drops from above the box,
## stays stuck, then lifts out.
func fork_tip(b: Bullet) -> float:
	var age := b.radius - b.gap
	if age < 0.0:
		return -INF
	var top := -half.y - FORK_TINES - 2.0
	if age < FORK_DROP:
		return lerpf(top, b.pos.y, age / FORK_DROP)
	return lerpf(b.pos.y, top, clampf((age - FORK_DROP - b.gap_center) / FORK_LIFT, 0.0, 1.0))


## How far a grass blade reaches in from its wall: a short tip while it warns, then the full
## length (anchor.x) while it is up, then back down.
func grass_length(b: Bullet) -> float:
	var age := b.radius - b.gap
	if age < 0.0:
		return 4.0
	var full := b.anchor.x
	if age < GRASS_RISE:
		return full * age / GRASS_RISE
	return full * (1.0 - clampf((age - GRASS_RISE - b.gap_center) / GRASS_FALL, 0.0, 1.0))


## A tree grows a trunk gap_center tall from pos, then each branch in parts waits its delay,
## blinks for BRANCH_WARN and climbs out to the wall of the box. It is gone at age gap.
func trunk_length(b: Bullet) -> float:
	return b.gap_center * ease(clampf(b.radius / TRUNK_GROW, 0.0, 1.0), 0.6)


## How far branch i reaches from the trunk: below 0 while it waits, -0.5 while it blinks.
func branch_reach(b: Bullet, i: int) -> float:
	var age := b.radius - TRUNK_GROW - b.parts[i * 3 + 2] - BRANCH_WARN
	if age < -BRANCH_WARN:
		return -1.0
	if age < 0.0:
		return -0.5
	return half.x * minf(age / BRANCH_GROW, 1.0)


## The bottom of a sheet of goo at x. It oozes down width px over gap seconds, with drips
## from parts ([x, length, phase] each) that stretch and wobble, stays for gap_center, then
## pulls back up.
func goo_edge(b: Bullet, x: float) -> float:
	var age := b.radius
	var level := ease(clampf(age / b.gap, 0.0, 1.0), 0.5)
	if age > b.gap + b.gap_center:
		level = 1.0 - clampf((age - b.gap - b.gap_center) / GOO_RECEDE, 0.0, 1.0)
	var drip := 0.0
	for i in b.parts.size() / 3:
		var d := absf(x - b.parts[i * 3])
		if d < 3.0:
			drip = maxf(drip, goo_drip(b, i) * sqrt(1.0 - d * d / 9.0))
	return -half.y + level * (b.width + 1.5 * sin(x * 0.25 + age * 1.3) + drip)


func goo_drip(b: Bullet, i: int) -> float:
	return b.parts[i * 3 + 1] * (0.6 + 0.4 * sin(b.radius * 2.0 + b.parts[i * 3 + 2]))


## The top of a wall of fire at x. After gap seconds of warning it leaps up to width px,
## its tongues licking up and down, burns for gap_center, then drops.
func blaze_edge(b: Bullet, x: float) -> float:
	var age := b.radius - b.gap
	if age < 0.0:
		return half.y
	var level := clampf(age / BLAZE_RISE, 0.0, 1.0) * (1.0 - clampf((age - BLAZE_RISE - b.gap_center) / BLAZE_FALL, 0.0, 1.0))
	var lick := 0.28 * sin(x * 0.17 + b.radius * 7.0) + 0.16 * sin(x * 0.41 - b.radius * 10.0) + 0.05 * sin(x * 1.1 + b.radius * 15.0)
	return half.y - level * b.width * (1.0 + lick)


func snapshot() -> Dictionary:
	return {"t": t, "spawned": spawned, "rng": rng.state, "bullets": bullets.map(func(b: Bullet) -> Bullet: return b.copy())}


func restore(s: Dictionary) -> void:
	t = s["t"]
	spawned = s["spawned"]
	rng.state = s["rng"]
	bullets.assign((s["bullets"] as Array).map(func(b: Bullet) -> Bullet: return b.copy()))
