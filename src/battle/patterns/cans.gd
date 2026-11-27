extends Pattern
## Cans tumble off a shelf above the box, bounce once on the floor, then roll along it.
## Params: count, roll (px/s along the floor), gravity, sprite.


func _spawn() -> void:
	var count := int(params.get("count", 10))
	while spawned < count and t >= spawned * duration * 0.75 / count:
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "can"))
		b.radius = 3.5
		b.pos = Vector2(rng.randf_range(-half.x + 6, half.x - 6), -half.y - 6)
		b.vel = Vector2(rng.randf_range(-15, 15), 20)
		b.gap = 0.0
		bullets.append(b)
		spawned += 1


func _steer(b: Bullet, dt: float, token: Vector2) -> void:
	var floor_y := half.y - 4.0
	if b.gap < 2.0:
		b.vel.y += float(params.get("gravity", 180)) * dt
	if b.pos.y > floor_y and b.vel.y > 0.0:
		b.pos.y = floor_y
		b.gap += 1.0
		if b.gap < 2.0:
			b.vel.y = -b.vel.y * 0.45
		else:
			b.vel = Vector2(signf(token.x - b.pos.x + 0.01) * float(params.get("roll", 60)), 0)
