extends Pattern
## Runaway shopping carts roll across the box in lanes. Each lane rolls one way, the next lane
## the other, and every cart leaves a gap behind it. Params: lanes, count, speed, sprite.


func _spawn() -> void:
	var lanes := int(params.get("lanes", 4))
	var count := int(params.get("count", 14))
	while spawned < count and t >= spawned * duration * 0.8 / count:
		var lane := rng.randi() % lanes
		var dir := 1.0 if lane % 2 == 0 else -1.0
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "cart"))
		b.radius = 4.0
		b.pos = Vector2(-dir * (half.x + 8), -half.y + (lane + 0.5) * half.y * 2.0 / lanes)
		b.vel = Vector2(dir * float(params.get("speed", 55)) * rng.randf_range(0.85, 1.3), 0)
		bullets.append(b)
		spawned += 1
