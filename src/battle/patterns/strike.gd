extends Pattern
## Red lines hover above the box, then strike straight down through it as columns.
## Params: volleys, lanes (lines in each volley), warn and strike (seconds), width (px),
## aim (true: the first line of each volley hangs over the token).

var _token: Vector2


func token_start() -> Vector2:
	return Vector2(0, half.y * 0.5)


func step(dt: float, token: Vector2) -> void:
	_token = token
	super(dt, token)


func _spawn() -> void:
	var volleys := int(params.get("volleys", 4))
	while spawned < volleys and t >= 0.3 + spawned * duration * 0.8 / volleys:
		for i in int(params.get("lanes", 3)):
			var b := Bullet.new()
			b.kind = Kind.LANE
			b.width = float(params.get("width", 10))
			b.gap = float(params.get("warn", 0.7))
			b.gap_center = float(params.get("strike", 0.35))
			b.grow = 1.0
			b.radius = 0.0
			var edge := half.x - b.width / 2.0
			var x := _token.x if i == 0 and bool(params.get("aim", true)) else rng.randf_range(-edge, edge)
			b.pos = Vector2(clampf(x, -edge, edge), -half.y)
			bullets.append(b)
		spawned += 1
