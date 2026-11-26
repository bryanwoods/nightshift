extends Pattern
## The box turns slowly while rows of spikes stick in from its walls and globs fly in at the
## token. The arrows still move on screen, not in the turned box. Params: spin (turns each
## second), rows (spike rows on each wall), shots, speed (of the shots), sprite.


func _init_pattern() -> void:
	for k in 4:
		var side := Vector2.from_angle(k * PI / 2.0)
		var span := absf(side.orthogonal().dot(half))
		var rows := int(params.get("rows", 2))
		var each := 2.0 * span / (rows * 2)
		for i in rows:
			var b := Bullet.new()
			b.kind = Kind.SPIKES
			b.steer = k * PI / 2.0
			b.gap = -span + each * (i * 2 + (k % 2))
			b.gap_center = b.gap + floorf(each / 8.0) * 8.0
			b.radius = 0.0
			b.grow = 1.0
			bullets.append(b)


func _spawn() -> void:
	turn = TAU * float(params.get("spin", 0.08)) * t
	var shots := int(params.get("shots", 10))
	while spawned < shots and t >= 0.8 + spawned * (duration - 1.6) / shots:
		spawned += 1
		var from := Vector2.from_angle(rng.randf_range(0.0, TAU)) * half.length()
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "wax_glob"))
		b.radius = 2.5
		b.pos = from.clamp(-half - Vector2(6, 6), half + Vector2(6, 6))
		b.vel = (_aim - b.pos).normalized() * float(params.get("speed", 45))
		bullets.append(b)


var _aim: Vector2 = Vector2.ZERO


func step(dt: float, token: Vector2) -> void:
	_aim = token
	super(dt, token)
