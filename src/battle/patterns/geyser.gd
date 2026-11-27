extends Pattern
## Lava geysers burst up from the floor. Bubbles warn where one will come, then a column of
## lava shoots to the top and spits blobs out to the sides. Later volleys have more geysers,
## and one of them aims at you. Params: volleys, warn and strike (seconds), width (px), spits
## (blobs each geyser throws), glob (their sprite).

var _token: Vector2


func step(dt: float, token: Vector2) -> void:
	_token = token
	super(dt, token)
	for b: Bullet in bullets.duplicate():
		if b.kind == Kind.LANE and b.anchor.x == 0.0 and b.radius >= b.gap:
			b.anchor.x = 1.0
			AudioBus.sfx("hustle", 0.8, -4.0)
			for i in int(params.get("spits", 3)):
				var g := Bullet.new()
				g.tex = str(params.get("glob", "lava_drop"))
				g.radius = 2.5
				g.pos = Vector2(b.pos.x, half.y - 4)
				g.vel = Vector2(rng.randf_range(-70, 70), rng.randf_range(-150, -100))
				bullets.append(g)


func _steer(b: Bullet, dt: float, _token: Vector2) -> void:
	if b.kind == Kind.SPRITE:
		b.vel.y += 200.0 * dt


func _spawn() -> void:
	var volleys := int(params.get("volleys", 5))
	while spawned < volleys and t >= 0.3 + spawned * duration * 0.75 / volleys:
		var n := 1 + mini(2, spawned / 2)
		for i in n:
			var b := Bullet.new()
			b.kind = Kind.LANE
			b.width = float(params.get("width", 10))
			b.gap = float(params.get("warn", 0.9))
			b.gap_center = float(params.get("strike", 0.5))
			b.grow = 1.0
			b.radius = 0.0
			b.steer = -PI / 2.0
			var x := _token.x if i == 0 else rng.randf_range(-half.x + 8, half.x - 8)
			b.pos = Vector2(clampf(x, -half.x + 6, half.x - 6), half.y)
			bullets.append(b)
		spawned += 1
