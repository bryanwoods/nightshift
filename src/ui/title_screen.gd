extends Control
## New Night, Continue, Settings, Credits, Quit.

var _menu: MenuList
var _actions: Array[String] = []
var _confirming: bool = false
var _sub: Control
var _note: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Game.color("ink")
	bg.size = Vector2(320, 180)
	add_child(bg)
	var glow := TextureRect.new()
	glow.texture = load("res://assets/sprites/light_radial.png")
	glow.modulate = Color(Game.color("lamp"), 0.35)
	glow.position = Vector2(128, -4)
	add_child(glow)
	var title := _label(Game.text("title"), Vector2(0, 10), "lamp", 32)
	title.size = Vector2(320, 30)
	var sub := Label.new()
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.position = Vector2(20, 44)
	sub.size = Vector2(280, 28)
	sub.text = Game.text("subtitle")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Game.color("fog"))
	add_child(sub)
	_note = _label("", Vector2(0, 148), "fog")
	_note.size = Vector2(320, 14)
	var keys := _label(Game.text("title_keys"), Vector2(0, 164), "dusk")
	keys.size = Vector2(320, 14)
	_menu = MenuList.new()
	_menu.position = Vector2(60, 80)
	_menu.size = Vector2(200, 64)
	add_child(_menu)
	_menu.chosen.connect(_on_chosen)
	_menu.cancelled.connect(_on_cancel)
	_show_main()
	RenderingServer.set_default_clear_color(Game.color("ink"))
	AudioBus.play_music("house_hum")
	Game.fade_from(0.4)


func _label(t: String, pos: Vector2, c: String, font_size: int = 0) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Game.color(c))
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


func _show_main() -> void:
	_confirming = false
	_actions = []
	if SaveManager.has_save():
		_actions.append("continue")
	_actions.append_array(["new", "settings", "credits", "quit"])
	var labels: Array[String] = []
	for a in _actions:
		labels.append(Game.text("menu_" + a))
	_menu.cursor = 0
	_menu.set_items(labels)
	_note.text = Game.text("night_label").replace("{night}", str(_saved_night())) if SaveManager.has_save() else ""


func _saved_night() -> int:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.PATH))
	return int(d.get("night", 1)) if d is Dictionary else 1


func _on_chosen(i: int) -> void:
	if _confirming:
		if i == 0:
			_begin(true)
		else:
			_show_main()
		return
	match _actions[i]:
		"continue":
			_begin(false)
		"new":
			if SaveManager.has_save():
				_confirming = true
				_note.text = Game.text("new_confirm")
				_menu.cursor = 1
				_menu.set_items([Game.text("yes"), Game.text("no")])
			else:
				_begin(true)
		"settings":
			_open("res://src/ui/settings.gd")
		"credits":
			_open("res://src/ui/credits.gd")
		"quit":
			get_tree().quit()


func _on_cancel() -> void:
	if _confirming:
		_show_main()


func _begin(new_game: bool) -> void:
	_menu.active = false
	await Game.fade_to(Game.color("ink"), 0.5)
	Game.start_night(new_game)


func _open(script: String) -> void:
	_menu.active = false
	_sub = load(script).new()
	add_child(_sub)
	await _sub.tree_exited
	_menu.active = true
	_menu.set_items(_menu.items)
