extends CanvasLayer
## The Help Wanted board in the Depot: pinned cards from data/help_wanted.json. Left and right page.

var _postings: Array = []
var _page: int = 0
var _title: Label
var _by: Label
var _body: Label
var _status: Label
var _pager: Label
var _ready_at: int = 0


func _ready() -> void:
	layer = 25
	var d: Variant = Game.load_json("res://data/help_wanted.json")
	_postings = d.get("postings", []) if d is Dictionary else []
	var cork := ColorRect.new()
	cork.color = Game.color("dusk")
	cork.size = Vector2(320, 180)
	add_child(cork)
	var head := _label(Vector2(0, 8), Vector2(320, 10), "lamp")
	head.text = Game.text("board_title")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.color("moon")
	sb.border_color = Game.color("ink")
	sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(50, 26)
	card.size = Vector2(220, 120)
	add_child(card)
	var pin := ColorRect.new()
	pin.color = Game.color("hush")
	pin.position = Vector2(158, 24)
	pin.size = Vector2(4, 4)
	add_child(pin)
	_title = _label(Vector2(58, 32), Vector2(204, 10), "ember")
	_by = _label(Vector2(58, 43), Vector2(204, 10), "slate")
	_body = _label(Vector2(58, 58), Vector2(204, 70), "ink")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = _label(Vector2(58, 132), Vector2(204, 10), "wake")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pager = _label(Vector2(0, 152), Vector2(320, 10), "fog")
	_pager.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var keys := _label(Vector2(0, 164), Vector2(320, 10), "fog")
	keys.text = Game.text("board_keys")
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_render()
	_ready_at = Time.get_ticks_msec() + 200


func _label(pos: Vector2, size: Vector2, c: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.add_theme_color_override("font_color", Game.color(c))
	add_child(l)
	return l


func _render() -> void:
	if _postings.is_empty():
		return
	var p: Dictionary = _postings[_page]
	_title.text = str(p.get("title", ""))
	_by.text = Game.text("posted_by") + " " + str(p.get("posted_by", ""))
	_body.text = str(p.get("text", ""))
	var status := str(p.get("status", "open"))
	_status.text = Game.text("status_" + status)
	_status.add_theme_color_override("font_color", Game.color({"open": "wake", "taken": "ember", "done": "slate"}.get(status, "wake")))
	_pager.text = "< %d / %d >" % [_page + 1, _postings.size()]


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() < _ready_at:
		return
	if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("confirm"):
		if Input.is_action_just_pressed("confirm") and _page == _postings.size() - 1:
			_close()
			return
		_page = wrapi(_page + 1, 0, maxi(1, _postings.size()))
		AudioBus.sfx("cursor")
		_render()
	elif Input.is_action_just_pressed("move_left"):
		_page = wrapi(_page - 1, 0, maxi(1, _postings.size()))
		AudioBus.sfx("cursor")
		_render()
	elif Input.is_action_just_pressed("cancel"):
		_close()


func _close() -> void:
	AudioBus.sfx("cancel")
	DialogueRunner.last_end_msec = Time.get_ticks_msec()
	queue_free()
