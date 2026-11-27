extends CanvasLayer
## An arcade machine: a title card, one small game from src/ui/arcade/, then the score.

const FONT := preload("res://assets/fonts/m6x11.ttf")
const MARQUEE := {"maze": "violet", "hop": "aqua", "catch": "lamp", "cat": "honey", "moon": "lilac", "stack": "straw", "lamps": "ember", "flap": "wake"}

const PITCH := {"maze": 1.0, "hop": 1.12, "catch": 1.25, "cat": 0.94, "moon": 1.33, "stack": 0.84, "lamps": 0.89, "flap": 1.19}

static var best: Dictionary = {}

var game_id: String
var _game: ArcadeGame
var _screen: Node2D
var _state := "title"
var _ready_at: int = 0
var _clock: float = 0.0
var _new_best := false
var _over_at: float = 0.0


func _ready() -> void:
	layer = 25
	_game = load("res://src/ui/arcade/%s.gd" % game_id).new()
	_game.reset()
	_screen = Node2D.new()
	_screen.draw.connect(_draw_screen)
	add_child(_screen)
	_ready_at = Time.get_ticks_msec() + 250


func _process(dt: float) -> void:
	_clock += dt
	_game.tick_fx(dt)
	_screen.queue_redraw()
	if Time.get_ticks_msec() < _ready_at:
		return
	if _state == "play":
		if _game.freeze > 0.0 and not Input.is_action_just_pressed("cancel"):
			_game.freeze -= dt
			return
		if Input.is_action_just_pressed("cancel") or not _game.step(dt):
			_state = "over"
			_new_best = _game.score > int(best.get(game_id, 0))
			best[game_id] = maxi(int(best.get(game_id, 0)), _game.score)
			_game.jolt(4.0)
			_over_at = _clock + 0.7
			AudioBus.sfx("a_over", PITCH.get(game_id, 1.0))
			_ready_at = Time.get_ticks_msec() + 900
	elif Input.is_action_just_pressed("confirm"):
		_game.score = 0
		_game.reset()
		_game.freeze = 1.0
		_state = "play"
		AudioBus.sfx("a_coin", PITCH.get(game_id, 1.0))
	elif Input.is_action_just_pressed("cancel"):
		AudioBus.sfx("cancel")
		DialogueRunner.last_end_msec = Time.get_ticks_msec()
		queue_free()


func _draw_screen() -> void:
	var c := _screen
	var tint := Game.color(MARQUEE.get(game_id, "lamp"))
	c.draw_rect(Rect2(0, 0, 320, 180), Game.color("ink"))
	var wobble := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _game.shake
	c.draw_set_transform(wobble)
	_game.draw(c)
	_game.draw_fx(c)
	c.draw_set_transform(Vector2.ZERO)
	if _game.flash > 0.0:
		c.draw_rect(Rect2(0, 0, 320, 180), Color(_game.flash_color, _game.flash * 0.5))
	if _state == "title":
		_title(c, tint)
	else:
		_text(Game.text("arcade_score").replace("{n}", str(_game.score)), Vector2(7, 12), "ink", 16, HORIZONTAL_ALIGNMENT_LEFT)
		_text(Game.text("arcade_score").replace("{n}", str(_game.score)), Vector2(6, 11), "moon", 16, HORIZONTAL_ALIGNMENT_LEFT)
	if _state == "play" and _game.freeze > 0.0 and _game.score == 0:
		_text(Game.text("arcade_ready"), Vector2(0, 96), "moon", 16)
	if _state == "over" and _clock >= _over_at:
		_card(c, tint)
	for y in range(0, 180, 2):
		c.draw_rect(Rect2(0, y, 320, 1), Color(0, 0, 0, 0.12))
	for i in 3:
		c.draw_rect(Rect2(i, i, 320 - i * 2, 180 - i * 2), Color(tint, 0.5 - i * 0.15), false)


func _title(c: CanvasItem, tint: Color) -> void:
	c.draw_rect(Rect2(0, 0, 320, 180), Color(Game.color("ink"), 0.72))
	var title := Game.text("arcade_" + game_id)
	var w := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var x := 160.0 - w / 2.0
	for i in title.length():
		var ch := title[i]
		var bob := sin(_clock * 4.0 + i * 0.5) * 3.0
		c.draw_string(FONT, Vector2(x + 2, 64 + bob + 2), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Game.color("ink"))
		c.draw_string(FONT, Vector2(x + 1, 64 + bob + 1), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, tint.darkened(0.3))
		c.draw_string(FONT, Vector2(x, 64 + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, tint.lightened(0.15))
		x += FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	c.draw_rect(Rect2(60, 74, 200, 1), Color(tint, 0.6))
	_text(Game.text("arcade_%s_how" % game_id), Vector2(0, 96), "moon")
	if int(best.get(game_id, 0)) > 0:
		_text(Game.text("arcade_best").replace("{n}", str(best[game_id])), Vector2(0, 114), "lamp")
	if int(_clock * 2.0) % 2 == 0:
		_text(Game.text("arcade_keys"), Vector2(0, 146), "moon")


func _card(c: CanvasItem, tint: Color) -> void:
	var r := Rect2(70, 46, 180, 88)
	c.draw_rect(r.grow(2), Game.color("ink"))
	c.draw_rect(r, Color(Game.color("night"), 0.95))
	c.draw_rect(r, tint, false)
	c.draw_rect(r.grow(-2), Color(tint, 0.4), false)
	_text(Game.text("arcade_over"), Vector2(0, 68), "hush", 16)
	_text(Game.text("arcade_score").replace("{n}", str(_game.score)), Vector2(0, 88), "moon")
	if _new_best and int(_clock * 4.0) % 2 == 0:
		_text(Game.text("arcade_new_best"), Vector2(0, 104), "wake")
	elif not _new_best:
		_text(Game.text("arcade_best").replace("{n}", str(best.get(game_id, 0))), Vector2(0, 104), "lamp")
	_text(Game.text("arcade_again"), Vector2(0, 124), "fog")


func _text(t: String, pos: Vector2, col: String, size := 16, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	_screen.draw_string(FONT, pos, t, align, 320.0 if align == HORIZONTAL_ALIGNMENT_CENTER else -1.0, size, Game.color(col))
