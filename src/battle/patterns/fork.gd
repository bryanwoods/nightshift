extends Pattern
## The box turns into a plate. A big "!" marks a spot, and after the warning a fork stabs down
## on that spot from the top. Params: count (stabs), warn and stick (seconds), extra (more
## forks in each stab, at random spots), aim (true: the first fork of a stab marks the token).

var _token: Vector2


func _init_pattern() -> void:
	plate = true


func token_start() -> Vector2:
	return Vector2(0, half.y * 0.4)


func step(dt: float, token: Vector2) -> void:
	_token = token
	super(dt, token)


func _spawn() -> void:
	var count := int(params.get("count", 6))
	var warn := float(params.get("warn", 1.0))
	while spawned < count and t >= 0.6 + spawned * (duration - warn - 1.2) / count:
		for i in 1 + int(params.get("extra", 0)):
			var b := Bullet.new()
			b.kind = Kind.FORK
			b.radius = 0.0
			b.grow = 1.0
			b.gap = warn
			b.gap_center = float(params.get("stick", 0.5))
			b.width = FORK_TINES
			var spot := _token if i == 0 and bool(params.get("aim", true)) else Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
			b.pos = spot.clamp(-half + Vector2(7, 12), half - Vector2(7, 3)).round()
			bullets.append(b)
		AudioBus.sfx("cursor", 1.4)
		spawned += 1


func _steer(b: Bullet, _dt: float, _t: Vector2) -> void:
	if b.steer == 0.0 and b.radius >= b.gap + FORK_DROP:
		b.steer = 1.0
		AudioBus.sfx("block")
