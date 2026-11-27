extends Pattern
## Fireballs fall into the box. Each one stops where it was aimed, then bursts into globs of
## hot wax that fly out and fall. Params: count, speed (of the fireballs), globs, burst (how
## fast the globs fly), gravity (px/s each second, on the globs), sprite and glob (their pictures).


func _spawn() -> void:
	var count := int(params.get("count", 6))
	while spawned < count and t >= 0.2 + spawned * duration * 0.6 / count:
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "fireball"))
		b.radius = 4.5
		b.pos = Vector2(rng.randf_range(-half.x + 8, half.x - 8), -half.y - 8)
		b.vel = Vector2(0, float(params.get("speed", 60)))
		b.gap_center = rng.randf_range(-half.y * 0.4, half.y * 0.5)
		bullets.append(b)
		spawned += 1


func _steer(b: Bullet, dt: float, _token: Vector2) -> void:
	if b.radius < 3.0:
		b.vel.y += float(params.get("gravity", 70)) * dt


func step(dt: float, token: Vector2) -> void:
	super(dt, token)
	for b: Bullet in bullets.duplicate():
		if b.radius > 3.0 and b.pos.y >= b.gap_center:
			b.alive = false
			_burst(b.pos)
	bullets.assign(bullets.filter(func(b: Bullet) -> bool: return b.alive))


func _burst(at: Vector2) -> void:
	AudioBus.sfx("flicker")
	var n := int(params.get("globs", 8))
	var turn := rng.randf_range(0.0, TAU)
	for i in n:
		var g := Bullet.new()
		g.tex = str(params.get("glob", "wax_glob"))
		g.radius = 2.5
		g.pos = at
		g.vel = Vector2.from_angle(turn + TAU * i / n) * float(params.get("burst", 45)) * rng.randf_range(0.8, 1.2)
		bullets.append(g)
