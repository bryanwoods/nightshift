extends Pattern
## The worker waves a hand and an alarm plays. The token is pulled toward one wall of the box,
## grass tips poke out of that wall, and then the blades shoot in. One stretch of the wall
## stays bare. Params: volleys, warn and stay (seconds), pull (px/s), reach (share of the box
## the blades cross), gap (px of bare wall), sides (which walls, in order).

const BLADE := 6.0
const SIDES := {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}

var _rustled: int = 0


func _spawn() -> void:
	var volleys := int(params.get("volleys", 4))
	var warn := float(params.get("warn", 0.8))
	var stay := float(params.get("stay", 0.5))
	var each := (duration - 0.4) / volleys
	var sides: Array = params.get("sides", ["down", "left", "right", "up"])
	if spawned < volleys and t >= 0.4 + spawned * each:
		_volley(SIDES[str(sides[spawned % sides.size()])], warn, stay)
		AudioBus.sfx("alert")
		spawned += 1
	var into := t - 0.4 - (spawned - 1) * each
	var side: Vector2 = SIDES[str(sides[(spawned - 1) % sides.size()])] if spawned > 0 else Vector2.ZERO
	pose = "wave" if spawned > 0 and into < warn else ""
	if spawned > _rustled and into >= warn:
		_rustled = spawned
		AudioBus.sfx("rustle")
	pull = side * float(params.get("pull", 55)) if into < warn + GRASS_RISE + stay else Vector2.ZERO


func _volley(side: Vector2, warn: float, stay: float) -> void:
	var along := Vector2(-side.y, side.x).abs()
	var span := absf(along.dot(half)) * 2.0
	var depth := absf(side.dot(half)) * 2.0
	var gap := float(params.get("gap", 22))
	var safe := rng.randf_range(-span / 2.0 + gap / 2.0, span / 2.0 - gap / 2.0)
	var n := int(span / BLADE)
	for i in n:
		var a := -span / 2.0 + (i + 0.5) * span / n
		if absf(a - safe) < gap / 2.0:
			continue
		var b := Bullet.new()
		b.kind = Kind.GRASS
		b.pos = side * absf(side.dot(half)) + along * a
		b.steer = (-side).angle()
		b.width = BLADE
		b.radius = 0.0
		b.grow = 1.0
		b.gap = warn
		b.gap_center = stay
		b.anchor = Vector2(depth * float(params.get("reach", 0.45)) * rng.randf_range(0.9, 1.1), 0)
		bullets.append(b)

