extends Pattern
## Walls sweep across the arena, each with a gap to slip through.
## Params: bars, gap_px, speed, from (left, right or both).


func _spawn() -> void:
	var bars := int(params.get("bars", 3))
	var window := duration * 0.7
	while spawned < bars and t >= spawned * window / bars:
		var from := str(params.get("from", "left"))
		var left := from == "left" or (from == "both" and spawned % 2 == 0)
		var b := Bullet.new()
		b.kind = Kind.BAR
		b.width = 6.0
		b.gap = float(params.get("gap_px", 24))
		b.gap_center = rng.randf_range(-half.y + b.gap / 2.0 + 2.0, half.y - b.gap / 2.0 - 2.0)
		var speed := float(params.get("speed", 60))
		b.pos = Vector2(-half.x - 4 if left else half.x + 4, 0)
		b.vel = Vector2(speed if left else -speed, 0)
		bullets.append(b)
		spawned += 1
