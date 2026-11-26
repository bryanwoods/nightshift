extends Pattern
## A sheet of melted wax oozes down from the top of the box, dripping. While it hangs there,
## the floor blinks, then a wall of fire leaps up from below. The safe place is the gap
## between them. Params: wax and fire (share of the box each one fills), ooze (seconds the
## wax takes to come down), warn (seconds before the fire), burn (seconds the fire lasts),
## drips (how many hang off the wax).


func _init_pattern() -> void:
	var ooze := float(params.get("ooze", 2.0))
	var warn := float(params.get("warn", 2.0))
	var burn := float(params.get("burn", 2.5))
	var wax := Bullet.new()
	wax.kind = Kind.GOO
	wax.radius = 0.0
	wax.grow = 1.0
	wax.gap = ooze
	wax.width = half.y * 2.0 * float(params.get("wax", 0.32))
	wax.gap_center = warn + BLAZE_RISE + burn + BLAZE_FALL - ooze
	for i in int(params.get("drips", 7)):
		wax.parts.append_array([rng.randf_range(-half.x + 6, half.x - 6), rng.randf_range(5.0, 12.0), rng.randf_range(0.0, TAU)])
	bullets.append(wax)
	var fire := Bullet.new()
	fire.kind = Kind.BLAZE
	fire.radius = 0.0
	fire.grow = 1.0
	fire.gap = warn
	fire.gap_center = burn
	fire.width = half.y * 2.0 * float(params.get("fire", 0.32))
	bullets.append(fire)


func step(dt: float, token: Vector2) -> void:
	var before := t
	super(dt, token)
	var warn := float(params.get("warn", 2.0))
	if before < warn and t >= warn:
		AudioBus.sfx("flicker")
	elif before < 0.05 and t >= 0.05:
		AudioBus.sfx("alert")
