extends Control
## The punch card: friends made, minutes used, and "Same time tomorrow". Morning colors.

var _ready_at: int = 0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Game.color("cream")
	bg.size = Vector2(320, 180)
	add_child(bg)
	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.color("white")
	sb.border_color = Game.color("bark")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(40, 18)
	card.size = Vector2(240, 136)
	add_child(card)
	var y := 24.0
	y = _line(Game.text("card_title"), y, "bark") + 4
	var friends: Array[String] = []
	for f in Game.friends():
		friends.append(_name_of(f))
	var enemies: Array[String] = []
	for e in Game.enemies():
		enemies.append(_name_of(e))
	y = _line(Game.text("friends_made") + " " + (", ".join(friends) if not friends.is_empty() else Game.text("nobody")), y, "bark")
	if not enemies.is_empty():
		y = _line(Game.text("not_friends") + " " + ", ".join(enemies), y, "bark")
	var reason := Game.text("reason_" + (Game.last_night_reason if Game.last_night_reason != "" else "time"))
	y = _line(Game.text("minutes_used").replace("{minutes}", str(Game.last_night_minutes)), y, "bark")
	y = _line(reason, y, "bark") + 8
	_line(Game.text("night_complete").replace("{night}", str(Game.night)), y, "bark")
	var hint := _line(Game.text("press_confirm"), 160, "bark")
	_ready_at = Time.get_ticks_msec() + 800
	AudioBus.play_music("none")
	Game.fade_from(0.6)


func _name_of(id: String) -> String:
	var sp: Dictionary = DialogueRunner.speakers.get(id, {})
	return str(sp.get("name", id.capitalize()))


func _line(t: String, y: float, c: String) -> float:
	var l := Label.new()
	l.text = t
	l.position = Vector2(48, y)
	l.size = Vector2(224, 10)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Game.color(c))
	add_child(l)
	return y + 11.0 * maxi(1, l.get_line_count())


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _ready_at and Input.is_action_just_pressed("confirm"):
		_ready_at = Time.get_ticks_msec() + 100000
		AudioBus.sfx("confirm")
		await Game.fade_to(Game.color("ink"), 0.5)
		Game.finish_night()
