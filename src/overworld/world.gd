extends Node2D
## Holds the current room and, during a fight, the battle. The room stays in memory under it.

var room: Room
var battle: Battle
var hud: ClockHUD


func _ready() -> void:
	hud = ClockHUD.new()
	add_child(hud)
	Game.room_requested.connect(_on_room_requested)
	Game.battle_requested.connect(_on_battle_requested)
	_load_room()
	await Game.fade_from(1.0 if Game.room_id == Game.FIRST_ROOM or Game.night_over else 0.2)
	Game.busy = false
	room.enter()


func _on_room_requested() -> void:
	Game.busy = true
	await Game.fade_to(Game.color("ink"), 0.15)
	_load_room()
	await Game.fade_from(0.15)
	Game.busy = false
	room.enter()


func _load_room() -> void:
	if room:
		remove_child(room)
		room.queue_free()
	room = Room.new()
	add_child(room)
	if not room.build(Game.room_id, Game.spawn):
		Game.report("rooms", Game.room_id, "the room could not be built")
		return
	hud.visible = bool(room.data.get("hud", true))
	RenderingServer.set_default_clear_color(Game.color(str(room.data.get("background", "ink"))))
	AudioBus.play_music(str(room.data.get("music", "")))


func _on_battle_requested(worker_id: String) -> void:
	room.process_mode = Node.PROCESS_MODE_DISABLED
	battle = Battle.new()
	add_child(battle)
	battle.finished.connect(_on_battle_finished)
	battle.start(worker_id)


func _on_battle_finished(result: String) -> void:
	battle.queue_free()
	battle = null
	room.process_mode = Node.PROCESS_MODE_INHERIT
	room.visible = true
	AudioBus.play_music(str(room.data.get("music", "")))
	Game.battle_finished.emit(result)
	if result == "asleep":
		Game.end_night("asleep")
