extends Node
## Opens one room with the clock running. Run: godot res://dev/test_room.tscn -- room=street_main spawn=alley


func _ready() -> void:
	var room := "street_maple"
	var spawn := "default"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("room="):
			room = a.trim_prefix("room=")
		if a.begins_with("spawn="):
			spawn = a.trim_prefix("spawn=")
	_go.call_deferred(room, spawn)


func _go(room: String, spawn: String) -> void:
	Game.start_night(false)
	Game.room_id = room
	Game.spawn = spawn
	NightClock.set_minute(0)
