extends Pattern
## Projectiles fall from the top. Params: count, speed, sprite.
## Optional: lanes and sequence make them fall in a fixed lane order, each lane a note pitch.


func _spawn() -> void:
	var count := int(params.get("count", 10))
	var window := duration * 0.75
	while spawned < count and t >= spawned * window / count:
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "crumb"))
		var x := rng.randf_range(-half.x + 4, half.x - 4)
		if params.has("sequence"):
			var seq: Array = params["sequence"]
			var lanes := int(params.get("lanes", 3))
			var lane := int(seq[spawned % seq.size()])
			x = -half.x + (lane + 0.5) * (2.0 * half.x / lanes) + rng.randf_range(-5, 5)
			AudioBus.sfx("note", 0.75 + 0.25 * lane, -6.0)
		b.pos = Vector2(x, -half.y - 4)
		b.vel = Vector2(0, float(params.get("speed", 50)))
		bullets.append(b)
		spawned += 1
