extends Pattern
## Tadzio stands still in the middle and turns his flashlight with the arrows. Shadows come
## straight in from the four sides. The beam melts a shadow; one that reaches him hits.
## Params: count, speed, sprite, accel (how much faster the last shadow is than the first),
## ramp (how much faster each later round of the fight is).


func _init_pattern() -> void:
	locked = true


func step(dt: float, token: Vector2) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v != Vector2.ZERO:
		facing = Vector2(signf(v.x), 0) if absf(v.x) > absf(v.y) else Vector2(0, signf(v.y))
	for b in bullets:
		if b.pos.distance_to(token) < SHINE_REACH and (b.pos - token).normalized().dot(facing) > cos(SHINE_HALF_ANGLE):
			b.alive = false
	super(dt, token)


func _spawn() -> void:
	var count := int(params.get("count", 12))
	var base := duration * 0.8 / (count - 0.25 * (count - 1))
	while spawned < count and t >= 0.4 + base * (spawned - 0.25 * spawned * (spawned - 1) / count):
		var side: Vector2 = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT][rng.randi() % 4]
		var pace := (1.0 + float(params.get("ramp", 0.0)) * fight_round) * (1.0 + float(params.get("accel", 0.0)) * spawned / count)
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "drifter"))
		b.pos = side * (absf(side.dot(half)) + 4.0)
		b.vel = -side * float(params.get("speed", 40)) * pace
		bullets.append(b)
		spawned += 1
