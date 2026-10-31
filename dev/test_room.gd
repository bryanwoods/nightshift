extends Node
## Opens one room with the clock running. Run: godot res://dev/test_room.tscn -- room=street_maple


func _ready() -> void:
	var room := "street_maple"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("room="):
			room = a.trim_prefix("room=")
	_go.call_deferred(room)


func _go(room: String) -> void:
	Game.start_night(false)
	Game.room_id = room
	NightClock.set_minute(0)
