extends Pattern
## Red lines hover outside the box at any angle, then strike across it as beams.
## Params: volleys, lanes (lines in each volley), warn and strike (seconds), width (px),
## aim (true: the first line of each volley crosses the token), accel (how much faster the
## last volley is than the first), ramp (how much faster each later round of the fight is).

var _token: Vector2


func token_start() -> Vector2:
	return Vector2(0, half.y * 0.5)


func step(dt: float, token: Vector2) -> void:
	_token = token
	super(dt, token)


func _spawn() -> void:
	var volleys := int(params.get("volleys", 4))
	while spawned < volleys and t >= 0.3 + duration * 0.8 * (1.0 - pow(1.0 - float(spawned) / volleys, 2.0)):
		var pace := (1.0 + float(params.get("ramp", 0.0)) * fight_round) * (1.0 + float(params.get("accel", 0.0)) * spawned / volleys)
		for i in int(params.get("lanes", 3)):
			var b := Bullet.new()
			b.kind = Kind.LANE
			b.width = float(params.get("width", 8))
			b.gap = float(params.get("warn", 0.8))
			b.gap_center = float(params.get("strike", 0.35))
			b.grow = pace
			b.radius = 0.0
			b.steer = rng.randf_range(0.0, TAU)
			var p := _token if i == 0 and bool(params.get("aim", true)) else Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
			b.pos = _entry(p.clamp(-half, half), Vector2.from_angle(b.steer))
			bullets.append(b)
		spawned += 1


## Where the line through p in direction d comes into the box.
func _entry(p: Vector2, d: Vector2) -> Vector2:
	var s := INF
	for axis in 2:
		if d[axis] != 0.0:
			s = minf(s, (half[axis] + p[axis] * signf(d[axis])) / absf(d[axis]))
	return p - d * s
