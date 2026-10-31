extends Control
## The designers and the tools, from data/credits.json. Any key goes back.

var _ready_at: int = 0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Game.color("ink")
	bg.size = Vector2(320, 180)
	add_child(bg)
	var d: Variant = Game.load_json("res://data/credits.json")
	var y := 16.0
	for entry: Dictionary in (d.get("lines", []) if d is Dictionary else []):
		var l := Label.new()
		l.text = str(entry.get("text", ""))
		l.position = Vector2(0, y)
		l.size = Vector2(320, 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Game.color(str(entry.get("color", "moon"))))
		add_child(l)
		y += 11.0 if l.text != "" else 6.0
	_ready_at = Time.get_ticks_msec() + 200


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() < _ready_at:
		return
	if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("cancel"):
		AudioBus.sfx("cancel")
		queue_free()
