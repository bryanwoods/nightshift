extends Pattern
## Slow projectiles that come in from the edges and steer gently toward the token.
## Params: count, speed, turn_rate (radians per second).


func _spawn() -> void:
	var count := int(params.get("count", 6))
	var window := duration * 0.5
	while spawned < count and t >= spawned * window / count:
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "drifter"))
		b.steer = float(params.get("turn_rate", 1.2))
		match spawned % 4:
			0: b.pos = Vector2(rng.randf_range(-half.x, half.x), -half.y - 4)
			1: b.pos = Vector2(half.x + 4, rng.randf_range(-half.y, half.y))
			2: b.pos = Vector2(rng.randf_range(-half.x, half.x), half.y + 4)
			_: b.pos = Vector2(-half.x - 4, rng.randf_range(-half.y, half.y))
		b.vel = -b.pos.normalized() * float(params.get("speed", 30))
		bullets.append(b)
		spawned += 1


func _steer(b: Bullet, dt: float, token: Vector2) -> void:
	var cur := b.vel.angle()
	var turn := clampf(angle_difference(cur, (token - b.pos).angle()), -b.steer * dt, b.steer * dt)
	b.vel = Vector2.from_angle(cur + turn) * b.vel.length()


func _gone(b: Bullet) -> bool:
	return absf(b.pos.x) > half.x + 30 or absf(b.pos.y) > half.y + 30
