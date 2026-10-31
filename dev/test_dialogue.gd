extends Control
## Runs one dialogue on a blank screen and lists the flags after it. Confirm runs it again.
## Run: godot res://dev/test_dialogue.tscn -- dialogue=wick_intro

var _id: String = "wick_intro"
var _info: Label


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dialogue="):
			_id = a.trim_prefix("dialogue=")
	var bg := ColorRect.new()
	bg.color = Game.color("night")
	bg.size = Vector2(320, 180)
	add_child(bg)
	_info = Label.new()
	_info.position = Vector2(6, 6)
	_info.size = Vector2(300, 100)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	add_child(ClockHUD.new())
	NightClock.set_minute(0)
	_run()


func _run() -> void:
	_info.text = "running " + _id
	await DialogueRunner.run(_id)
	_info.text = "%s done. clock %s\nflags: %s\nitems: %s\nconfirm: run again" % [
		_id, NightClock.text(), ", ".join(Game.flags.keys()), ", ".join(Game.items)]


func _process(_delta: float) -> void:
	if not DialogueRunner.is_active() and not DialogueRunner.just_ended() and Input.is_action_just_pressed("confirm"):
		_run()
