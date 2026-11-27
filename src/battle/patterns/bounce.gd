extends Pattern
## Little lava blobs hop in from the sides and bounce across the floor of the box.
## Params: count, speed (px/s across), hop (how high each bounce goes, as a share of the box),
## gravity, sprite.


func _spawn() -> void:
	var count := int(params.get("count", 8))
	while spawned < count and t >= 0.2 + spawned * duration * 0.7 / count:
		var b := Bullet.new()
		var side := -1.0 if spawned % 2 == 0 else 1.0
		b.tex = str(params.get("sprite", "kyle_hop"))
		b.radius = 3.5
		b.pos = Vector2(side * (half.x + 6), half.y - 4)
		b.vel = Vector2(-side * float(params.get("speed", 50)) * rng.randf_range(0.8, 1.25), -_hop_speed())
		bullets.append(b)
		spawned += 1


func _hop_speed() -> float:
	var h := half.y * 2.0 * float(params.get("hop", 0.6)) * rng.randf_range(0.6, 1.1)
	return sqrt(2.0 * float(params.get("gravity", 260)) * h)


func _steer(b: Bullet, dt: float, _token: Vector2) -> void:
	b.vel.y += float(params.get("gravity", 260)) * dt
	if b.pos.y > half.y - 4.0 and b.vel.y > 0.0:
		b.pos.y = half.y - 4.0
		b.vel.y = -_hop_speed()
