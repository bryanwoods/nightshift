extends Pattern
## Projectiles fall from the top. Params: count, speed, sprite.
## Optional: lanes and sequence make them fall in a fixed lane order, each lane a note pitch.
## from "bottom" makes them rise, slant moves them sideways (px/s), wobble swings them (px/s).


func _spawn() -> void:
	var count := int(params.get("count", 10))
	var window := duration * 0.75
	while spawned < count and t >= spawned * window / count:
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "crumb"))
		var slant := float(params.get("slant", 0))
		var speed := float(params.get("speed", 50))
		var x := rng.randf_range(-half.x + 4, half.x - 4) - slant * half.y / speed
		if params.has("sequence"):
			var seq: Array = params["sequence"]
			var lanes := int(params.get("lanes", 3))
			var lane := int(seq[spawned % seq.size()])
			x = -half.x + (lane + 0.5) * (2.0 * half.x / lanes) + rng.randf_range(-5, 5)
			AudioBus.sfx("note", 0.75 + 0.25 * lane, -6.0)
		var up := str(params.get("from", "top")) == "bottom"
		b.pos = Vector2(x, half.y + 4 if up else -half.y - 4)
		b.vel = Vector2(slant, -speed if up else speed)
		b.steer = rng.randf_range(0, TAU)
		bullets.append(b)
		spawned += 1


func _steer(b: Bullet, _dt: float, _token: Vector2) -> void:
	b.vel.x = float(params.get("slant", 0)) + float(params.get("wobble", 0)) * cos(t * 4.0 + b.steer)
