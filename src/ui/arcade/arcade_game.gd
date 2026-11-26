class_name ArcadeGame
extends RefCounted
## One arcade game. step returns false when the game is over.

var score: int = 0
var rng := RandomNumberGenerator.new()


func reset() -> void:
	pass


func step(_dt: float) -> bool:
	return true


func draw(_c: CanvasItem) -> void:
	pass


static func pressed_dir() -> Vector2i:
	for a: String in DIRS:
		if Input.is_action_just_pressed(a):
			return DIRS[a]
	return Vector2i.ZERO


const DIRS := {"move_up": Vector2i.UP, "move_down": Vector2i.DOWN, "move_left": Vector2i.LEFT, "move_right": Vector2i.RIGHT}


static func col(name: String, a := 1.0) -> Color:
	return Color(Game.color(name), a)
