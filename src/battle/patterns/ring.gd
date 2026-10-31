extends Pattern
## Rings grow from the center. Each has a gap: be in the gap when the ring passes.
## Params: rings, speed, gap_angle (degrees).


func token_start() -> Vector2:
	return Vector2(0, half.y * 0.8)


func _spawn() -> void:
	var rings := int(params.get("rings", 2))
	while spawned < rings and t >= 0.5 + spawned * (duration * 0.8) / rings:
		var b := Bullet.new()
		b.kind = Kind.RING
		b.radius = 2.0
		b.width = 4.0
		b.grow = float(params.get("speed", 35))
		b.gap = deg_to_rad(float(params.get("gap_angle", 50)))
		b.gap_center = rng.randf_range(-PI, PI)
		bullets.append(b)
		spawned += 1
