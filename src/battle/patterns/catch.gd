extends Pattern
## Tadzio walks along the bottom of the box with a plate on their head. Food falls, and they have to
## catch it: food that reaches the floor costs miss_damage. Burnt toast falls too, and catching
## that hurts. Each piece of food lands close enough to the one before it to reach in time.
## Params: count, speed, sprites (the food), burnt (chance of toast, 0 to 1), miss_damage, ramp.

const PLATE_HALF := 10.0
const BURNT := "burnt"

var _hurt: int = 0
var _last_x: float = 0.0


func _init_pattern() -> void:
	rail = true
	catcher = true
	if not params.has("prompt"):
		params["prompt"] = "catch_prompt"


func token_start() -> Vector2:
	return Vector2(0, half.y - 31.0)


func _spawn() -> void:
	var count := int(params.get("count", 12))
	var gap := duration * 0.75 / count
	var reach := float(Game.tuning.get("token_speed", 90)) * gap * 0.8
	while spawned < count and t >= 0.5 + spawned * gap:
		var b := Bullet.new()
		var foods: Array = params.get("sprites", ["crumb", "egg", "cheese", "tomato"])
		var x := clampf(_last_x + rng.randf_range(-reach, reach), -half.x + 6, half.x - 6)
		if spawned > 0 and rng.randf() < float(params.get("burnt", 0.2)):
			b.tex = BURNT
			x = clampf(_last_x + (20.0 + rng.randf() * 20.0) * (1.0 if rng.randf() < 0.5 else -1.0), -half.x + 6, half.x - 6)
		else:
			b.tex = str(foods[rng.randi() % foods.size()])
			_last_x = x
		b.pos = Vector2(x, -half.y - 4)
		b.vel = Vector2(0, float(params.get("speed", 45)) * (1.0 + float(params.get("ramp", 0.0)) * fight_round))
		bullets.append(b)
		spawned += 1


func step(dt: float, token: Vector2) -> void:
	super(dt, token)
	_hurt = 0
	for b in bullets:
		var on_plate := absf(b.pos.x - token.x) <= PLATE_HALF and b.pos.y + 3.0 >= token.y and b.pos.y < token.y + 6.0
		if on_plate and b.tex == BURNT:
			_hurt = damage
		elif on_plate:
			stack.append(b.tex)
			AudioBus.sfx("note", 0.8 + 0.06 * minf(stack.size(), 12), -6.0)
		elif b.pos.y >= half.y - 3.0 and b.tex != BURNT:
			_hurt = int(params.get("miss_damage", 1))
		elif b.pos.y < half.y - 3.0:
			continue
		b.alive = false
	bullets.assign(bullets.filter(func(b: Bullet) -> bool: return b.alive))


func collide(_token: Vector2, _r: float) -> int:
	var d := _hurt
	_hurt = 0
	return d


func would_hit(_token: Vector2, _r: float, _lookahead: float) -> bool:
	return false


func snapshot() -> Dictionary:
	var s := super()
	s["stack"] = stack.duplicate()
	s["last_x"] = _last_x
	return s


func restore(s: Dictionary) -> void:
	super(s)
	stack.assign(s["stack"])
	_last_x = s["last_x"]
