class_name MenuList
extends Control
## A vertical list of text options with a cursor. Up and down move, confirm picks, cancel backs out.

signal chosen(index: int)
signal cancelled
signal changed(index: int, direction: int)

const LINE_H := 11

var items: Array[String] = []
var disabled: Array[bool] = []
var cursor: int = 0
var active: bool = true
var centered: bool = true

var _labels: Array[Label] = []
var _ready_at: int = 0


func set_items(list: Array[String], off: Array[bool] = []) -> void:
	items = list
	disabled = off
	for l in _labels:
		l.queue_free()
	_labels.clear()
	for i in items.size():
		var l := Label.new()
		l.position = Vector2(0, i * LINE_H)
		l.size = Vector2(size.x, LINE_H)
		if centered:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)
		_labels.append(l)
	cursor = clampi(cursor, 0, maxi(0, items.size() - 1))
	while _is_off(cursor) and cursor < items.size() - 1:
		cursor += 1
	_ready_at = Time.get_ticks_msec() + 150
	refresh()


func refresh() -> void:
	for i in _labels.size():
		var on := i == cursor and active
		_labels[i].text = ("> " + items[i] + " <") if on and centered else (("> " if on else "  ") + items[i])
		var c := "lamp" if on else "moon"
		if _is_off(i):
			c = "dusk"
		_labels[i].add_theme_color_override("font_color", Game.color(c))


func _is_off(i: int) -> bool:
	return i < disabled.size() and disabled[i]


func _process(_delta: float) -> void:
	if not active or not is_visible_in_tree() or items.is_empty() or Time.get_ticks_msec() < _ready_at:
		return
	var step := 0
	if Input.is_action_just_pressed("move_down"):
		step = 1
	elif Input.is_action_just_pressed("move_up"):
		step = -1
	if step != 0:
		for _i in items.size():
			cursor = wrapi(cursor + step, 0, items.size())
			if not _is_off(cursor):
				break
		AudioBus.sfx("cursor")
		refresh()
	if Input.is_action_just_pressed("move_left"):
		changed.emit(cursor, -1)
	elif Input.is_action_just_pressed("move_right"):
		changed.emit(cursor, 1)
	if Input.is_action_just_pressed("confirm"):
		AudioBus.sfx("confirm")
		_ready_at = Time.get_ticks_msec() + 150
		chosen.emit(cursor)
	elif Input.is_action_just_pressed("cancel"):
		AudioBus.sfx("cancel")
		_ready_at = Time.get_ticks_msec() + 150
		cancelled.emit()
