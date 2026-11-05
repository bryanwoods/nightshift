extends Control
## "What the lamps remember": after the night ends, what the last lamp save kept and what
## everything since then lost. Live state was already reverted when this opens.

const COL_W := 136.0

var _ready_at: int = 0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Game.color("ink")
	bg.size = Vector2(320, 180)
	add_child(bg)
	var glow := TextureRect.new()
	glow.texture = load("res://assets/sprites/light_radial.png")
	glow.modulate = Color(Game.color("lamp"), 0.2)
	glow.position = Vector2(128, -20)
	add_child(glow)
	_label(Game.text("lamps_title"), Vector2(0, 8), 320, "lamp", true)
	_column(Game.text("lamps_kept"), _lines(SaveManager.kept(), "lamps_kept_none"), 16, "moon")
	_column(Game.text("lamps_forgotten"), _lines(Game.last_forgotten, "lamps_forgotten_none"), 168, "fog")
	_label(Game.text("lamps_rule"), Vector2(0, 150), 320, "dusk", true)
	_label(Game.text("lamps_confirm"), Vector2(0, 163), 320, "fog", true)
	_ready_at = Time.get_ticks_msec() + 800
	AudioBus.play_music("none")
	RenderingServer.set_default_clear_color(Game.color("ink"))
	Game.fade_from(0.8)


## One short line per thing: friends, enemies, workers gone, items, hours, lamps.
func _lines(d: Dictionary, none_key: String) -> Array[String]:
	var out: Array[String] = []
	for kind in ["friend", "enemy", "gone"]:
		for id: String in d.get(kind, []):
			out.append(Game.text("lamps_" + kind).replace("{name}", Game.display_name(id)))
	for it: String in d.get("items", []):
		out.append(Game.item_name(it))
	if int(d.get("hours", 0)) > 0:
		out.append(Game.text("lamps_hours").replace("{n}", str(d["hours"])))
	if not (d.get("lamp", []) as Array).is_empty():
		out.append(Game.text("lamps_lamps").replace("{n}", str((d["lamp"] as Array).size())))
	if out.is_empty():
		out.append(Game.text(none_key))
	return out


func _column(title: String, lines: Array[String], x: float, c: String) -> void:
	_label(title, Vector2(x, 30), COL_W, "lamp")
	var y := 44.0
	for t in lines:
		y += _label(t, Vector2(x, y), COL_W, c).get_line_count() * 12.0


func _label(t: String, pos: Vector2, w: float, c: String, center: bool = false) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(w, 12)
	l.position = pos
	l.text = t
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Game.color(c))
	add_child(l)
	return l


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _ready_at and Input.is_action_just_pressed("confirm"):
		_ready_at = Time.get_ticks_msec() + 100000
		AudioBus.sfx("confirm")
		await Game.fade_to(Game.color("ink"), 0.5)
		Game.go_to_morning()
