extends Control
## "What the lamps remember": after the night ends, what the last lamp save kept and what
## everything since then lost. Live state was already reverted when this opens.

const COL_W := 148.0
const ROWS := 8
const ROW_H := 12.0
const STATUS_COLOR := {"friend": "wake", "enemy": "hush", "gone": "fog"}

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
	_label(Game.text("lamps_title"), Vector2(0, 4), 320, "lamp", HORIZONTAL_ALIGNMENT_CENTER)
	_label(Game.text("lamps_rule"), Vector2(0, 17), 320, "fog", HORIZONTAL_ALIGNMENT_CENTER)
	_column(Game.text("lamps_kept"), _rows(SaveManager.kept(), "lamps_kept_none"), 8, "moon")
	_column(Game.text("lamps_forgotten"), _rows(Game.last_forgotten, "lamps_forgotten_none"), 164, "fog")
	var x := 88.0
	for kind: String in STATUS_COLOR:
		_pip(Vector2(x, 153), STATUS_COLOR[kind])
		_label(Game.text("lamps_" + kind), Vector2(x + 9, 148), 50, "fog")
		x += 54.0
	_label(Game.text("lamps_confirm"), Vector2(0, 164), 320, "moon", HORIZONTAL_ALIGNMENT_CENTER)
	_ready_at = Time.get_ticks_msec() + 800
	AudioBus.play_music("none")
	RenderingServer.set_default_clear_color(Game.color("ink"))
	Game.fade_from(0.8)


## One row per thing, as [text] or [name, status colour]: workers, items, hours, lamps.
## A list that is too long for the column names the item count, then cuts the rest.
func _rows(d: Dictionary, none_key: String) -> Array:
	var people: Array = []
	for kind: String in STATUS_COLOR:
		for id: String in d.get(kind, []):
			people.append([Game.display_name(id), STATUS_COLOR[kind]])
	var items: Array = (d.get("items", []) as Array).map(func(it: Variant) -> Array: return [Game.item_name(str(it))])
	var totals: Array = []
	if int(d.get("hours", 0)) > 0:
		totals.append([Game.text("lamps_hours").replace("{n}", str(d["hours"]))])
	if not (d.get("lamp", []) as Array).is_empty():
		totals.append([Game.text("lamps_lamps").replace("{n}", str((d["lamp"] as Array).size()))])
	if people.size() + items.size() + totals.size() > ROWS:
		items = [[Game.text("lamps_items").replace("{n}", str(items.size()))]]
	var out := people + items + totals
	if out.size() > ROWS:
		var more := out.size() - ROWS + 1
		out = out.slice(0, ROWS - 1) + [[Game.text("lamps_more").replace("{n}", str(more))]]
	return out if not out.is_empty() else [[Game.text(none_key)]]


func _column(title: String, rows: Array, x: float, c: String) -> void:
	_label(title, Vector2(x, 34), COL_W, "lamp")
	for i in rows.size():
		var row: Array = rows[i]
		var y := 47.0 + i * ROW_H
		if row.size() > 1:
			_pip(Vector2(x, y + 5), str(row[1]))
		_label(str(row[0]), Vector2(x + (9 if row.size() > 1 else 0), y), COL_W - 9, c)


func _pip(pos: Vector2, c: String) -> void:
	var r := ColorRect.new()
	r.color = Game.color(c)
	r.position = pos
	r.size = Vector2(5, 5)
	add_child(r)


func _label(t: String, pos: Vector2, w: float, c: String, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l := Label.new()
	l.clip_text = true
	l.size = Vector2(w, ROW_H)
	l.position = pos
	l.text = t
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", Game.color(c))
	add_child(l)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _ready_at and Input.is_action_just_pressed("confirm"):
		_ready_at = Time.get_ticks_msec() + 100000
		AudioBus.sfx("confirm")
		await Game.fade_to(Game.color("ink"), 0.5)
		Game.go_to_morning()
