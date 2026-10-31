extends Node
## Starts the autotest bot on the root, so it survives scene changes. See autotest_bot.gd.


func _ready() -> void:
	var bot := Node.new()
	bot.name = "AutotestBot"
	bot.set_script(load("res://dev/autotest_bot.gd"))
	get_tree().root.add_child.call_deferred(bot)
