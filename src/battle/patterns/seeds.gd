extends Pattern
## Ten seeds stand in a ring around the box, then close in on the middle and squeeze into one
## big seed that drops to the floor. Slanted rain crosses the whole box. Then one tree grows
## from the seed, and its branches climb out to the walls at different heights.
## Params: seeds, hang and fly (seconds), drops, speed, slant (the rain), branches.

const RING_AT := 0.3
const RAIN_AT := 2.7
const RAIN_FOR := 3.0
const TREE_AT := 6.0

var _rain: int = 0


func token_start() -> Vector2:
	return Vector2(-half.x * 0.8, -half.y * 0.75)


func _spawn() -> void:
	var hang := float(params.get("hang", 0.6))
	var fly := float(params.get("fly", 1.2))
	if spawned == 0 and t >= RING_AT:
		var n := int(params.get("seeds", 10))
		var turn := rng.randf_range(0, TAU)
		for i in n:
			var b := Bullet.new()
			b.tex = "seed"
			b.radius = 2.5
			b.anchor = Vector2.from_angle(turn + TAU * i / n) * (half - Vector2(6, 6))
			b.pos = b.anchor
			b.gap = hang
			b.width = fly
			bullets.append(b)
		AudioBus.sfx("alert", 0.8, -6.0)
		spawned = 1
	if spawned == 1 and t >= RING_AT + hang + fly:
		var b := Bullet.new()
		b.tex = "seed_big"
		b.radius = 4.0
		b.vel = Vector2(0, 2.0 * half.y / 0.4)
		b.gap = -1.0
		bullets.append(b)
		AudioBus.sfx("tick", 0.6)
		spawned = 2
	var drops := int(params.get("drops", 14))
	var slant := float(params.get("slant", -32))
	var speed := float(params.get("speed", 80))
	while _rain < drops and t >= RAIN_AT + _rain * RAIN_FOR / drops:
		var d := Bullet.new()
		d.tex = "drop"
		d.pos = Vector2(rng.randf_range(-half.x + 4, half.x - 4) - slant * half.y / speed, -half.y - 4)
		d.vel = Vector2(slant, speed)
		bullets.append(d)
		_rain += 1
	if spawned == 2 and t >= TREE_AT:
		var tree := Bullet.new()
		tree.kind = Kind.TREE
		tree.pos = Vector2(0, half.y)
		tree.gap_center = 2.0 * half.y - 30.0
		tree.grow = 1.0
		tree.radius = 0.0
		tree.gap = duration - TREE_AT - 0.2
		var count := int(params.get("branches", 3))
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		for i in count:
			tree.parts.append_array([tree.gap_center * (i + 0.6) / (count + 0.4), side, i * 0.5])
			side = -side
		bullets.append(tree)
		for b in bullets:
			if b.tex == "seed_big":
				b.alive = false
		AudioBus.sfx("rustle", 0.7)
		spawned = 3


func _steer(b: Bullet, dt: float, _t: Vector2) -> void:
	if b.tex == "seed":
		b.gap_center += dt
		b.pos = b.anchor.lerp(Vector2.ZERO, clampf((b.gap_center - b.gap) / b.width, 0.0, 1.0))
		if b.gap_center >= b.gap + b.width:
			b.alive = false
	elif b.tex == "seed_big" and b.pos.y >= half.y - 4.0:
		b.pos.y = half.y - 4.0
		b.vel = Vector2.ZERO
	elif b.kind == Kind.TREE:
		for i in b.parts.size() / 3:
			var start := TRUNK_GROW + b.parts[i * 3 + 2] + BRANCH_WARN
			if b.radius < start and b.radius + dt >= start:
				AudioBus.sfx("rustle", 1.1, -3.0)


func snapshot() -> Dictionary:
	var s := super()
	s["rain"] = _rain
	return s


func restore(s: Dictionary) -> void:
	super(s)
	_rain = s["rain"]
