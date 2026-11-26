extends Node
## Plays one arcade game with no room around it. Leaving the machine quits.
## Run: godot res://dev/test_arcade.tscn -- game=maze

func _ready() -> void:
	var game := "maze"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("game="):
			game = a.trim_prefix("game=")
	var cabinet: CanvasLayer = load("res://src/ui/arcade.gd").new()
	cabinet.game_id = game
	cabinet.tree_exited.connect(get_tree().quit)
	add_child(cabinet)
