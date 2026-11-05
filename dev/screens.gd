extends Node
## --screens: every room at its default spawn with no story flags, saved to screens/, then the
## sprite gallery. Godot draws nothing without a window, so a small window opens for this.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	DialogueRunner.autoplay = true
	for id in Game.room_ids():
		Game.show_room(id)
		await _until(func() -> bool:
			var s := get_tree().current_scene
			return s != null and s.scene_file_path == Game.WORLD and s.get("room") != null and s.room.id == id and not Game.busy)
		DialogueRunner.abort()
		await get_tree().create_timer(0.4).timeout
		await Game.save_screen(id)
		print("screen ", id)
	get_tree().change_scene_to_file("res://dev/gallery.tscn")


func _until(cond: Callable) -> void:
	var t := 0.0
	while not cond.call() and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
