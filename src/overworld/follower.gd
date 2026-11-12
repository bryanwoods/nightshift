class_name Follower
extends Entity
## Wick after he joins: walks the player's trail a fixed distance behind. Talk to him for hints.

var distance: float = 24.0
var scared: bool = false
var _trail: Array[Vector2] = []


func setup_follower(sheet: String, talk: String, start: Vector2, player_pos: Vector2) -> void:
	kind = "npc"
	data = {"type": "npc", "id": "wick"}
	dialogue = talk
	position = start
	make_sprite(sheet)
	distance = float(Game.tuning.get("follow_distance", 24))
	_trail = [start, player_pos]
	update_rect()


func follow(p: Vector2) -> void:
	if _trail.is_empty() or _trail[-1].distance_to(p) >= 1.0:
		_trail.append(p)
	var need := distance
	var i := _trail.size() - 1
	var pos := _trail[i]
	while i > 0 and need > 0.0:
		var seg := _trail[i].distance_to(_trail[i - 1])
		if seg >= need:
			pos = _trail[i].lerp(_trail[i - 1], need / seg)
			need = 0.0
		else:
			need -= seg
			pos = _trail[i - 1]
			i -= 1
	if i > 1:
		_trail = _trail.slice(i - 1)
	var step := pos - position
	moving = step.length() > 0.05
	if moving:
		face_vector(step)
	position = pos.round()
	update_rect()
	if not moving:
		_apply_frame(0)


func _process(delta: float) -> void:
	super(delta)
	var t := Time.get_ticks_msec()
	if sprite:
		sprite.position.x = float(t / 50 % 2) if scared or (Game.has_flag("many_gone") and t % 2400 < 700) else 0.0
