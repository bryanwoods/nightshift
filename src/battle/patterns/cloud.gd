extends Pattern
## A pink cloud covers the box, so only Tadzio's own light shows. Then it thins away and
## leaves cloud blades where it was. Each blade glints, then glides along its own arc, and
## it hurts only while it glides. The cloud comes back for each wave.
## Params: waves, blades (in the first wave; each later wave has one more).

const FADE := 0.3


func _wave_len() -> float:
	return duration / int(params.get("waves", 2))


func _spawn() -> void:
	while spawned < int(params.get("waves", 2)) and t >= spawned * _wave_len():
		for i in int(params.get("blades", 5)) + spawned:
			var b := Bullet.new()
			b.kind = Kind.BLADE
			b.grow = 1.0
			b.radius = 0.0
			b.anchor = Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y)) * 0.6
			b.width = rng.randf_range(18.0, 40.0)
			b.gap_center = rng.randf_range(0.0, TAU)
			b.gap = rng.randf_range(2.2, 2.8) * (1.0 if rng.randi() % 2 else -1.0)
			bullets.append(b)
		spawned += 1


func step(dt: float, token: Vector2) -> void:
	super(dt, token)
	var into := fmod(t, _wave_len())
	var cover := BLADE_HOLD - FADE
	fog = 1.0 if into < cover else clampf(1.0 - (into - cover) / FADE, 0.0, 1.0)
	for b in bullets:
		if b.kind == Kind.BLADE:
			var a := b.gap_center + b.gap * smoothstep(0.0, 1.0, (b.radius - BLADE_HOLD) / BLADE_GLIDE)
			b.pos = b.anchor + Vector2.from_angle(a) * b.width
			b.steer = a + signf(b.gap) * PI / 2.0
