extends Pattern
## Pink hearts pop in and circle the box. One after another they crack, then splinter into
## shards that fly every way. Params: count, spin (turns each second), crack (seconds before
## the first one cracks), stagger (seconds between hearts), warn (seconds a heart shows its
## crack), shards, speed (of the shards), colors (one sheet name for each heart, in turn).
## The shards fly in toward the box, so they miss the other hearts on the rim.


func _init_pattern() -> void:
	for i in int(params.get("count", 6)):
		var b := Bullet.new()
		var colors: Array = params.get("colors", ["pink"])
		b.tex = "heart_" + str(colors[i % colors.size()])
		b.radius = 4.5
		b.steer = TAU * i / int(params.get("count", 6))
		b.gap_center = float(params.get("crack", 2.6)) + float(params.get("stagger", 0.3)) * i
		b.pos = _orbit(b.steer)
		bullets.append(b)


func _orbit(angle: float) -> Vector2:
	return Vector2.from_angle(angle) * (half - Vector2(12, 12))


func _steer(b: Bullet, dt: float, _token: Vector2) -> void:
	if b.tex.begins_with("heart_shard"):
		return
	b.steer += TAU * float(params.get("spin", 0.35)) * dt * (0.3 if b.tex.begins_with("heart_crack") else 1.0)
	b.pos = _orbit(b.steer)


func step(dt: float, token: Vector2) -> void:
	super(dt, token)
	var warn := float(params.get("warn", 0.5))
	for b: Bullet in bullets.duplicate():
		var color := b.tex.get_slice("_", b.tex.get_slice_count("_") - 1)
		if b.tex == "heart_" + color and t >= b.gap_center:
			b.tex = "heart_crack_" + color
		elif b.tex == "heart_crack_" + color and t >= b.gap_center + warn:
			b.alive = false
			_splinter(b.pos, color)
	bullets.assign(bullets.filter(func(b: Bullet) -> bool: return b.alive))


func _splinter(at: Vector2, color: String) -> void:
	AudioBus.sfx("block")
	var n := int(params.get("shards", 7))
	for i in n:
		var s := Bullet.new()
		s.tex = "heart_shard_" + color
		s.radius = 3.0
		s.pos = at
		var spread := deg_to_rad(150.0) * (float(i) / maxf(1.0, n - 1) - 0.5)
		s.vel = Vector2.from_angle((-at).angle() + spread + rng.randf_range(-0.1, 0.1)) * float(params.get("speed", 55)) * rng.randf_range(0.8, 1.2)
		bullets.append(s)
