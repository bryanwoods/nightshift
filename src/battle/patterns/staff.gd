extends Pattern
## A music staff swings over the box like a pendulum, in and out of the top, and touching it
## hurts. Each time it passes over the lane of the next note in the sequence, it drops that
## note, so the notes keep the order and the pitch of the lullaby.
## Params: count, speed (px/s the notes fall), sprite, lanes, sequence, period (seconds a swing).

const LENGTH := 76.0
const PIVOT_UP := 50.0


func _init_pattern() -> void:
	var s := Bullet.new()
	s.kind = Kind.STAFF
	s.width = 30.0
	s.radius = 4.5
	s.pos = _at(0.0)
	bullets.append(s)


func _swing(at: float) -> float:
	return asin((half.x - 10.0) / LENGTH) * sin(TAU * at / float(params.get("period", 2.4)))


func _at(angle: float) -> Vector2:
	return Vector2(0, -half.y - PIVOT_UP) + Vector2(sin(angle), cos(angle)) * LENGTH


func step(dt: float, token: Vector2) -> void:
	var x0 := _at(_swing(t)).x
	super(dt, token)
	var a := _swing(t)
	var p := _at(a)
	for b in bullets:
		if b.kind == Kind.STAFF:
			b.pos = p
			b.steer = -a
	var seq: Array = params.get("sequence", [0, 1, 2])
	var lanes := int(params.get("lanes", 3))
	if spawned >= int(params.get("count", 12)):
		return
	var lane := int(seq[spawned % seq.size()])
	var lx := -half.x + (lane + 0.5) * (2.0 * half.x / lanes)
	if x0 != p.x and (x0 - lx) * (p.x - lx) <= 0.0:
		var n := Bullet.new()
		n.tex = str(params.get("sprite", "note"))
		n.pos = Vector2(lx, maxf(p.y + 5.0, -half.y - 4.0))
		n.vel = Vector2(0, float(params.get("speed", 50)))
		bullets.append(n)
		spawned += 1
		AudioBus.sfx("note", 0.75 + 0.25 * lane, -6.0)
