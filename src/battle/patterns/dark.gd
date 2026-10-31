extends Pattern
## Wraps another pattern ("inner"). The arena goes dark; the projectiles show only after Wick's Light.

var inner: Pattern


func _init_pattern() -> void:
	dark = true
	var ip: Dictionary = (params.get("inner", {}) as Dictionary).duplicate()
	ip["duration"] = duration
	if not ip.has("damage"):
		ip["damage"] = damage
	inner = Pattern.create(ip, half * 2.0, damage)
	if inner:
		bullets = inner.bullets


func token_start() -> Vector2:
	return inner.token_start() if inner else Vector2.ZERO


func step(dt: float, token: Vector2) -> void:
	t += dt
	if inner:
		inner.step(dt, token)
		bullets = inner.bullets


func collide(token: Vector2, r: float) -> int:
	return inner.collide(token, r) if inner else 0


func would_hit(token: Vector2, r: float, lookahead: float) -> bool:
	return inner.would_hit(token, r, lookahead) if inner else false


func snapshot() -> Dictionary:
	return {"t": t, "inner": inner.snapshot() if inner else {}}


func restore(s: Dictionary) -> void:
	t = s["t"]
	if inner:
		inner.restore(s["inner"])
		bullets = inner.bullets
