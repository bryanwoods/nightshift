extends Pattern
## Price tags flutter down like leaves, swaying side to side. Now and then one stops swaying
## and swoops at you. Params: count, speed (px/s down), sway (px/s side to side), swoop
## (share of tags that dive), sprite.


func _spawn() -> void:
	var count := int(params.get("count", 14))
	while spawned < count and t >= spawned * duration * 0.75 / count:
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "price_tag"))
		b.radius = 3.0
		b.pos = Vector2(rng.randf_range(-half.x + 4, half.x - 4), -half.y - 6)
		b.vel = Vector2(0, float(params.get("speed", 26)))
		b.steer = rng.randf_range(0.0, TAU)
		b.height = 0.0
		b.gap = 1.0 if rng.randf() < float(params.get("swoop", 0.3)) else 0.0
		b.gap_center = rng.randf_range(-half.y * 0.5, 0.0)
		bullets.append(b)
		spawned += 1


func _steer(b: Bullet, dt: float, token: Vector2) -> void:
	if b.gap > 0.5 and b.pos.y > b.gap_center:
		b.gap = 0.0
		b.grow = 0.0
		b.vel = (token - b.pos).normalized() * float(params.get("speed", 26)) * 2.6
		return
	if b.vel.length() < float(params.get("speed", 26)) * 2.0:
		b.vel.x = float(params.get("sway", 34)) * sin(t * 3.0 + b.steer)
