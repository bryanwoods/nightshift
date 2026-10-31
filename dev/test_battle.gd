extends Node
## Fights one worker with no room around it. Confirm after the result fights again.
## Run: godot res://dev/test_battle.tscn -- worker=unbaker [wick] [watch]

var _worker: String = "unbaker"
var _info: Label
var _done: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("worker="):
			_worker = a.trim_prefix("worker=")
		elif a == "wick":
			Game.set_flag("wick_joined")
		elif a == "watch":
			Game.set_flag("has_watch")
	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(6, 80)
	_info.size = Vector2(308, 40)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_info)
	add_child(ClockHUD.new())
	Game.battle_requested.connect(_on_battle_requested)
	_fight()


func _fight() -> void:
	_done = false
	_info.text = ""
	NightClock.reset()
	NightClock.set_minute(0)
	Game.night_over = false
	var result: String = await Game.start_battle(_worker)
	if result == "asleep":
		Game.end_night("asleep")
		return
	_info.text = "result: %s   clock %s\nflags: %s\nconfirm: fight again" % [result, NightClock.text(), ", ".join(Game.flags.keys())]
	_done = true


func _on_battle_requested(id: String) -> void:
	var b := Battle.new()
	add_child(b)
	b.finished.connect(func(r: String) -> void:
		b.queue_free()
		Game.battle_finished.emit(r))
	b.start(id)


func _process(_delta: float) -> void:
	if _done and Input.is_action_just_pressed("confirm"):
		for f in Game.flags.keys():
			if str(f).begins_with("friend_") or str(f).begins_with("enemy_"):
				Game.clear_flag(f)
		_fight()
