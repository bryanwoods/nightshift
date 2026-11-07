extends Pattern
## Tadzio moves along the bottom of the box, and rows of blocks come down toward him. Hold
## confirm to charge, then let go: Tadzio dashes up and breaks every block he touches. A
## longer charge dashes farther. On the way back down to his row, blocks hit him again.
## Params: rows, speed, block (px), gaps (open blocks in each row), accel, ramp, color.

const DASH_SPEED := 300.0
const RETURN_SPEED := 160.0
const DASH_MIN := 14.0

var _dash_to: float = 0.0


func _init_pattern() -> void:
	rail = true


func token_start() -> Vector2:
	return Vector2(0, half.y - 6.0)


func step(dt: float, token: Vector2) -> void:
	if Input.is_action_pressed("confirm") and _dash_to == 0.0 and lift == 0.0:
		charge += dt
	elif charge > 0.0:
		_dash_to = lerpf(DASH_MIN, 2.0 * half.y - 12.0, minf(1.0, charge / CHARGE_FULL))
		charge = 0.0
		AudioBus.sfx("whoosh", 1.4, -4.0)
	if _dash_to > 0.0:
		lift = minf(_dash_to, lift + DASH_SPEED * dt)
		if lift >= _dash_to:
			_dash_to = 0.0
		for b in bullets:
			if _hits(b, token, 4.0):
				b.alive = false
	else:
		lift = maxf(0.0, lift - RETURN_SPEED * dt)
	super(dt, token)


func _spawn() -> void:
	var rows := int(params.get("rows", 8))
	var base := duration * 0.8 / (rows - 0.25 * (rows - 1))
	while spawned < rows and t >= 0.3 + base * (spawned - 0.25 * spawned * (spawned - 1) / rows):
		var pace := (1.0 + float(params.get("ramp", 0.0)) * fight_round) * (1.0 + float(params.get("accel", 0.0)) * spawned / rows)
		var w := float(params.get("block", 12))
		var n := int(2.0 * half.x / w)
		var open: Array[int] = []
		for g in int(params.get("gaps", 1)):
			open.append(rng.randi() % n)
		for k in n:
			if k in open:
				continue
			var b := Bullet.new()
			b.kind = Kind.BLOCK
			b.width = w
			b.radius = 3.0
			b.pos = Vector2(-half.x + (k + 0.5) * w, -half.y - 4.0)
			b.vel = Vector2(0, float(params.get("speed", 30)) * pace)
			bullets.append(b)
		spawned += 1
