extends "res://src/battle/patterns/drift.gd"
## Tadzio moves along the bottom of the box, and confirm flicks a spark of light straight up.
## Shadows drift down and steer toward him. A spark melts the shadow it touches.
## Params: count, speed, turn_rate, sprite, accel, ramp.

const SPARK_SPEED := 220.0
const SPARK_EVERY := 0.2

var _cool: float = 0.0


func _init_pattern() -> void:
	rail = true


func token_start() -> Vector2:
	return Vector2(0, half.y - 6.0)


func step(dt: float, token: Vector2) -> void:
	_cool -= dt
	if Input.is_action_just_pressed("confirm") and _cool <= 0.0:
		_cool = SPARK_EVERY
		sparks.append(token)
		AudioBus.sfx("cursor", 1.6, -8.0)
	super(dt, token)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].y -= SPARK_SPEED * dt
		var hit: Array = bullets.filter(func(b: Bullet) -> bool: return b.pos.distance_to(sparks[i]) < b.radius + 3.0)
		for b: Bullet in hit.slice(0, 1):
			b.alive = false
		if not hit.is_empty() or sparks[i].y < -half.y - 4.0:
			sparks.remove_at(i)
	bullets.assign(bullets.filter(func(b: Bullet) -> bool: return b.alive))


func _spawn() -> void:
	var count := int(params.get("count", 12))
	var base := duration * 0.8 / (count - 0.25 * (count - 1))
	while spawned < count and t >= 0.3 + base * (spawned - 0.25 * spawned * (spawned - 1) / count):
		var pace := (1.0 + float(params.get("ramp", 0.0)) * fight_round) * (1.0 + float(params.get("accel", 0.0)) * spawned / count)
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "drifter"))
		b.radius = 4.0
		b.steer = float(params.get("turn_rate", 0.8))
		b.pos = Vector2(rng.randf_range(-half.x + 6.0, half.x - 6.0), -half.y - 4.0)
		b.vel = Vector2(0, float(params.get("speed", 30)) * pace)
		bullets.append(b)
		spawned += 1
