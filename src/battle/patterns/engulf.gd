extends Pattern
## Fire floods the box from the floor, leaving only a thin strip at the top. Then it splits
## down the middle into two arms that race to the top corners, and lifts away through them.
## While it splits, embers fall from the top. Params: warn, rise, hold, split, lift (seconds
## for each part), embers (how many fall), glob (their sprite).


func _init_pattern() -> void:
	var b := Bullet.new()
	b.kind = Kind.FLARE
	b.radius = 0.0
	b.grow = 1.0
	for k: String in ["warn", "rise", "hold", "split", "lift"]:
		b.parts.append(float(params.get(k, {"warn": 1.0, "rise": 1.0, "hold": 0.5, "split": 1.8, "lift": 1.0}[k])))
	b.gap = b.parts[0] + b.parts[1] + b.parts[2] + b.parts[3] + b.parts[4]
	bullets.append(b)


func _spawn() -> void:
	var b := bullets[0] if not bullets.is_empty() and bullets[0].kind == Kind.FLARE else null
	if b == null:
		return
	var start := b.parts[0] + b.parts[1] + b.parts[2] * 0.5
	var span := b.parts[2] * 0.5 + b.parts[3]
	var n := int(params.get("embers", 12))
	while spawned < n and t >= start + spawned * span / n:
		var e := Bullet.new()
		e.tex = str(params.get("glob", "lava_drop"))
		e.radius = 2.5
		e.pos = Vector2(rng.randf_range(-half.x * 0.6, half.x * 0.6), -half.y - 6)
		e.vel = Vector2(rng.randf_range(-8, 8), rng.randf_range(45, 65))
		bullets.append(e)
		spawned += 1


func token_start() -> Vector2:
	return Vector2(0, -half.y * 0.85)


func step(dt: float, token: Vector2) -> void:
	var before := t
	super(dt, token)
	var warn := float(params.get("warn", 1.0))
	if before < 0.05 and t >= 0.05:
		AudioBus.sfx("alert")
	elif before < warn and t >= warn:
		AudioBus.sfx("flicker", 0.7)
