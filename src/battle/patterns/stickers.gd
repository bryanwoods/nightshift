extends Pattern
## The Grocer's price gun fires price stickers from the top of the box in a fan aimed at you.
## Later fans have more stickers. Params: volleys, spread (degrees), speed, sprite.

var _token: Vector2


func step(dt: float, token: Vector2) -> void:
	_token = token
	super(dt, token)


func token_start() -> Vector2:
	return Vector2(0, half.y * 0.6)


func _spawn() -> void:
	var volleys := int(params.get("volleys", 6))
	while spawned < volleys and t >= 0.3 + spawned * duration * 0.8 / volleys:
		var from := Vector2(rng.randf_range(-half.x * 0.6, half.x * 0.6), -half.y - 4)
		var aim := (_token - from).angle()
		var n := 3 + mini(2, spawned / 2)
		var spread := deg_to_rad(float(params.get("spread", 40)))
		for i in n:
			var b := Bullet.new()
			b.tex = str(params.get("sprite", "sticker"))
			b.radius = 2.5
			b.pos = from
			b.vel = Vector2.from_angle(aim + spread * (float(i) / (n - 1) - 0.5)) * float(params.get("speed", 60))
			bullets.append(b)
		AudioBus.sfx("hustle", 1.4, -8.0)
		spawned += 1
