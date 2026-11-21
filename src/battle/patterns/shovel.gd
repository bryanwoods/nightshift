extends Pattern
## The worker turns away and shovels. Clumps fly in from the left over the box, with a shadow
## where each will land. A clump bursts where it lands, and its crumbs slide out and stop.
## Params: count, flight (seconds in the air), peak (px), pieces, spread (px/s), life
## (seconds a crumb stays), aim (true: every other clump lands on the token), sprites.

var _token: Vector2
var _born: Array[Bullet] = []


func _init_pattern() -> void:
	pose = "dig"


func token_start() -> Vector2:
	return Vector2(half.x * 0.4, 0)


func step(dt: float, token: Vector2) -> void:
	_token = token
	super(dt, token)
	bullets.append_array(_born)
	_born.clear()


func _spawn() -> void:
	var count := int(params.get("count", 10))
	var flight := float(params.get("flight", 0.9))
	var sprites: Array = params.get("sprites", ["dirt", "sod"])
	while spawned < count and t >= 0.5 + spawned * (duration - flight - 2.0) / count:
		var b := Bullet.new()
		b.tex = str(sprites[spawned % sprites.size()])
		b.radius = 4.0
		var land := _token if spawned % 2 == 0 and bool(params.get("aim", true)) else Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		land = land.clamp(-half + Vector2(6, 6), half - Vector2(6, 6))
		b.pos = Vector2(-half.x - 6, land.y + rng.randf_range(-10, 10))
		b.vel = (land - b.pos) / flight
		b.gap = flight
		b.gap_center = 0.0
		b.height = 1.0
		bullets.append(b)
		AudioBus.sfx("cursor", 0.6, -4.0)
		spawned += 1


func _steer(b: Bullet, dt: float, _t: Vector2) -> void:
	b.gap_center += dt
	if b.gap > 0.0:
		var u := b.gap_center / b.gap
		b.height = float(params.get("peak", 40)) * 4.0 * u * (1.0 - u)
		if u >= 1.0:
			_burst(b)
		return
	b.vel = b.vel.move_toward(Vector2.ZERO, 90.0 * dt)
	if b.gap_center > -b.gap:
		b.alive = false


func _burst(b: Bullet) -> void:
	b.alive = false
	AudioBus.sfx("block", 0.7)
	var n := int(params.get("pieces", 5))
	var a0 := rng.randf_range(0, TAU)
	for i in n + 1:
		var c := Bullet.new()
		c.tex = "dirt_bit" if i < n else b.tex
		c.radius = 2.5 if i < n else 4.0
		c.pos = b.pos + b.vel * 0.0
		c.vel = Vector2.from_angle(a0 + TAU * i / n) * float(params.get("spread", 45)) * rng.randf_range(0.8, 1.2) if i < n else Vector2.ZERO
		c.gap = -float(params.get("life", 1.4)) * (1.0 if i < n else 0.6)
		_born.append(c)
