extends CanvasLayer
## An arcade machine: a title card, one small game from src/ui/arcade/, then the score.

const FONT := preload("res://assets/fonts/m6x11.ttf")

static var best: Dictionary = {}

var game_id: String
var _game: ArcadeGame
var _screen: Node2D
var _state := "title"
var _ready_at: int = 0


func _ready() -> void:
	layer = 25
	_game = load("res://src/ui/arcade/%s.gd" % game_id).new()
	_screen = Node2D.new()
	_screen.draw.connect(_draw_screen)
	add_child(_screen)
	_ready_at = Time.get_ticks_msec() + 250


func _process(dt: float) -> void:
	_screen.queue_redraw()
	if Time.get_ticks_msec() < _ready_at:
		return
	if _state == "play":
		if Input.is_action_just_pressed("cancel") or not _game.step(dt):
			_state = "over"
			best[game_id] = maxi(int(best.get(game_id, 0)), _game.score)
			AudioBus.sfx("gone")
			_ready_at = Time.get_ticks_msec() + 500
	elif Input.is_action_just_pressed("confirm"):
		_game.score = 0
		_game.reset()
		_state = "play"
		AudioBus.sfx("confirm")
	elif Input.is_action_just_pressed("cancel"):
		AudioBus.sfx("cancel")
		DialogueRunner.last_end_msec = Time.get_ticks_msec()
		queue_free()


func _draw_screen() -> void:
	var c := _screen
	c.draw_rect(Rect2(0, 0, 320, 180), Game.color("ink"))
	c.draw_rect(Rect2(1, 1, 318, 178), Game.color("lamp"), false)
	if _state == "title":
		_text(Game.text("arcade_" + game_id), Vector2(0, 60), "lamp", 32)
		_text(Game.text("arcade_%s_how" % game_id), Vector2(0, 90), "moon")
		_text(Game.text("arcade_keys"), Vector2(0, 140), "fog")
		return
	_game.draw(c)
	_text(Game.text("arcade_score").replace("{n}", str(_game.score)), Vector2(6, 11), "moon", 16, HORIZONTAL_ALIGNMENT_LEFT)
	if _state == "over":
		c.draw_rect(Rect2(70, 50, 180, 80), Color(Game.color("ink"), 0.9))
		c.draw_rect(Rect2(70, 50, 180, 80), Game.color("lamp"), false)
		_text(Game.text("arcade_over"), Vector2(0, 72), "hush", 16)
		_text(Game.text("arcade_score").replace("{n}", str(_game.score)), Vector2(0, 92), "moon")
		_text(Game.text("arcade_best").replace("{n}", str(best.get(game_id, 0))), Vector2(0, 106), "lamp")
		_text(Game.text("arcade_again"), Vector2(0, 122), "fog")


func _text(t: String, pos: Vector2, col: String, size := 16, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	_screen.draw_string(FONT, pos, t, align, 320.0 if align == HORIZONTAL_ALIGNMENT_CENTER else -1.0, size, Game.color(col))
