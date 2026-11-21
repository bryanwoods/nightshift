extends Node
## Opens one room with the clock running. Run: godot res://dev/test_room.tscn -- room=street_main spawn=alley flags=met_wick,wick_joined items=key_to_nothing


func _ready() -> void:
	var room := "street_maple"
	var spawn := "default"
	var flags: PackedStringArray = []
	var items: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("room="):
			room = a.trim_prefix("room=")
		if a.begins_with("spawn="):
			spawn = a.trim_prefix("spawn=")
		if a.begins_with("flags="):
			flags = a.trim_prefix("flags=").split(",", false)
		if a.begins_with("items="):
			items = a.trim_prefix("items=").split(",", false)
	_go.call_deferred(room, spawn, flags, items)


func _go(room: String, spawn: String, flags: PackedStringArray, items: PackedStringArray) -> void:
	Game.start_night(false)
	for f in flags:
		Game.set_flag(f)
	for i in items:
		Game.give_item(i)
	Game.room_id = room
	Game.spawn = spawn
	NightClock.set_minute(0)
