extends Pattern
## Tadzio moves along the bottom of the box, and rows of blocks come down toward him. Tap
## confirm to flick a spark that breaks one block. Hold it to charge, and let go for a wide
## flash that breaks every block in its path.
## Params: rows, speed, block (px), gaps (open blocks in each row), accel, ramp, color.

const SPARK_SPEED := 220.0
const SPARK_EVERY := 0.2
const FLASH_WIDTH := 26.0

var _cool: float = 0.0


func _init_pattern() -> void:
	rail = true


func token_start() -> Vector2:
	return Vector2(0, half.y - 6.0)


func step(dt: float, token: Vector2) -> void:
	_cool -= dt
	if Input.is_action_pressed("confirm"):
		charge += dt
	elif charge > 0.0:
		if charge >= CHARGE_FULL:
			sparks.append(Vector3(token.x, token.y, FLASH_WIDTH))
			AudioBus.sfx("whoosh", 1.4, -4.0)
		elif _cool <= 0.0:
			sparks.append(Vector3(token.x, token.y, 1.0))
			AudioBus.sfx("cursor", 1.6, -8.0)
		_cool = SPARK_EVERY
		charge = 0.0
	super(dt, token)
	for i in range(sparks.size() - 1, -1, -1):
		var s := sparks[i]
		s.y -= SPARK_SPEED * dt
		sparks[i] = s
		var hit := false
		for b in bullets:
			if b.alive and absf(b.pos.x - s.x) < (b.width + s.z) / 2.0 and absf(b.pos.y - s.y) < b.radius + 3.0:
				b.alive = false
				hit = true
				if s.z <= 1.0:
					break
		if (hit and s.z <= 1.0) or s.y < -half.y - 4.0:
			sparks.remove_at(i)
	bullets.assign(bullets.filter(func(b: Bullet) -> bool: return b.alive))


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
