extends Pattern
## Counting sheep. Fences stand on the bottom of the box, and sheep run in from the left and
## hop every fence: just over it, or high up to the top of the box. Only the sheep hurt.
## Params: count, speed, fences, sprite.

const FENCE_H := 10.0
const LOW := 18.0


func _init_pattern() -> void:
	var n := int(params.get("fences", 3))
	for i in n:
		var f := Bullet.new()
		f.kind = Kind.FENCE
		f.width = 10.0
		f.radius = FENCE_H / 2.0
		f.pos = Vector2(_fence_x(i), half.y - f.radius)
		bullets.append(f)


func _fence_x(i: int) -> float:
	return -half.x + (i + 0.5) * 2.0 * half.x / int(params.get("fences", 3))


func _spawn() -> void:
	var count := int(params.get("count", 8))
	while spawned < count and t >= 0.3 + spawned * duration * 0.7 / count:
		var b := Bullet.new()
		b.tex = str(params.get("sprite", "sheep"))
		b.radius = 4.0
		b.pos = Vector2(-half.x - 8.0, half.y - 5.0)
		b.vel = Vector2(float(params.get("speed", 52)), 0)
		b.gap = float(rng.randi() % 256)
		bullets.append(b)
		spawned += 1


## A sheep's height follows its x: one arc over each fence. Bit i of gap makes arc i high.
func _steer(b: Bullet, dt: float, _token: Vector2) -> void:
	if b.kind != Kind.SPRITE:
		return
	var x := b.pos.x + b.vel.x * dt
	var half_span := half.x / int(params.get("fences", 3))
	var lift := 0.0
	for i in int(params.get("fences", 3)):
		var u := (x - _fence_x(i)) / half_span
		if absf(u) < 1.0:
			lift = (2.0 * half.y - 14.0 if int(b.gap) >> i & 1 else LOW) * (1.0 - u * u)
	b.pos.y = half.y - 5.0 - lift
