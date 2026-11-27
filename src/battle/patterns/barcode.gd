extends Pattern
## A barcode slides across the box: red stripes of different widths, each with a gap at a
## different height. Slip through the gaps as the stripes pass. Params: stripes, speed, gap (px).


func _spawn() -> void:
	var n := int(params.get("stripes", 12))
	var speed := float(params.get("speed", 50))
	var span := duration * 0.7
	while spawned < n and t >= 0.3 + spawned * span / n:
		var b := Bullet.new()
		b.kind = Kind.BAR
		b.width = [2.0, 3.0, 5.0, 2.0, 7.0][rng.randi() % 5]
		b.pos = Vector2(half.x + 6, 0)
		b.vel = Vector2(-speed, 0)
		b.gap = float(params.get("gap", 22))
		var last: float = bullets.back().gap_center if not bullets.is_empty() else 0.0
		b.gap_center = clampf(last + rng.randf_range(-16, 16), -half.y + b.gap / 2.0 + 2.0, half.y - b.gap / 2.0 - 2.0)
		bullets.append(b)
		spawned += 1
