class_name Pattern
extends RefCounted
## Base for one dodge pattern. A subclass spawns bullets in _spawn(); this class moves them,
## checks hits and takes the snapshots that rewind restores. The pattern type in a worker
## file is the name of a script in this folder.

enum Kind { SPRITE, BAR, RING, LANE }

const LANE_DROP := 600.0
const SHINE_REACH := 30.0
const SHINE_HALF_ANGLE := 0.61


class Bullet:
	var kind: int = Kind.SPRITE
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var tex: String = ""
	## Sprite: hit radius. Ring: current radius. Lane: age, scaled by grow (its pace).
	var radius: float = 3.0
	## Bar and lane: width. Ring: thickness.
	var width: float = 6.0
	## Bar: y of the gap. Ring: angle of the gap. Lane: strike time.
	var gap_center: float = 0.0
	## Bar: gap in px. Ring: gap in radians. Lane: warning time.
	var gap: float = 0.0
	var grow: float = 0.0
	## Drift: turn rate. Lane: angle of the beam.
	var steer: float = 0.0
	var alive: bool = true

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
## The dodge round of the fight, from 0.
var fight_round: int = 0
## True: the token stays in the middle, and the arrows turn the flashlight to facing.
var locked: bool = false
var facing: Vector2 = Vector2.UP
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
	return b.pos.y > half.y + 10 or b.pos.y < -half.y - 14 or absf(b.pos.x) > half.x + 14


func collide(token: Vector2, r: float) -> int:
	for b in bullets:
		if _hits(b, token, r):
			if b.kind == Kind.SPRITE:
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
	match b.kind:
		Kind.BAR:
			return absf(p.x - b.pos.x) < b.width / 2.0 + r and absf(p.y - b.gap_center) > b.gap / 2.0 - r
		Kind.RING:
			var d := p.distance_to(b.pos)
			if absf(d - b.radius) > b.width / 2.0 + r:
				return false
			return absf(angle_difference((p - b.pos).angle(), b.gap_center)) > b.gap / 2.0
		Kind.LANE:
			var d := Vector2.from_angle(b.steer)
			var u := (p - b.pos).dot(d)
			return absf((p - b.pos).cross(d)) < b.width / 2.0 + r and u > -r and u - r < lane_reach(b)
	return b.pos.distance_to(p) < b.radius + r


## How far into the box a lane has struck, or -INF while it still hovers outside.
func lane_reach(b: Bullet) -> float:
	return (b.radius - b.gap) * LANE_DROP if b.radius >= b.gap else -INF


func snapshot() -> Dictionary:
	return {"t": t, "spawned": spawned, "rng": rng.state, "bullets": bullets.map(func(b: Bullet) -> Bullet: return b.copy())}


func restore(s: Dictionary) -> void:
	t = s["t"]
	spawned = s["spawned"]
	rng.state = s["rng"]
	bullets.assign((s["bullets"] as Array).map(func(b: Bullet) -> Bullet: return b.copy()))
