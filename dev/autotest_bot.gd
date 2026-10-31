extends Node
## Plays Night 1 by itself and checks the clock, flags and rooms on the way.
## Routes: help (default), hustle, clock (run out the clock before the square), asleep.
## Run:  godot --path . res://dev/autotest.tscn -- route=help shots=/tmp/shots
## Screenshots need a window (no --headless). Prints AUTOTEST PASS or AUTOTEST FAIL and quits.

var route: String = "help"
var second_night: bool = false
var route_done_once: bool = false
var shots: String = ""
var failures: PackedStringArray = []
var log_lines: PackedStringArray = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("route="):
			route = a.trim_prefix("route=")
		elif a.begins_with("shots="):
			shots = a.trim_prefix("shots=")
	process_mode = Node.PROCESS_MODE_ALWAYS
	DialogueRunner.autoplay = true
	DialogueRunner.autoplay_fight = "hustle" if route == "hustle" else "help"
	if route == "night2":
		route = "help"
		second_night = true
	Engine.time_scale = 2.0
	_run.call_deferred()


func _run() -> void:
	await _wait(0.5)
	_note("window %s, screen scale %s, usable %s" % [get_window().size, DisplayServer.screen_get_scale(), DisplayServer.screen_get_usable_rect().size])
	Game.start_night(true)
	await _room("bedroom")
	await _shot("01_bedroom")
	_expect(NightClock.text() == "1:59", "clock reads 1:59 in the bedroom, got " + NightClock.text())
	await _inspect_all()
	await _walk(5, 8)
	await _room("hallway")
	await _walk(7, 3)
	await _idle()
	_expect(Game.has_flag("tonight_bath_flicker"), "bathroom flicker fired")
	await _walk(12, 3)
	await _room("kitchen")
	await _shot("02_kitchen")
	await _talk_at(7, 1)
	await _walk(2, 7)
	await _idle()
	await _walk(2, 8)
	await _room("backyard")
	await _walk(8, 4)
	await _idle()
	await _walk(13, 4)
	await _room("street_maple")
	_expect(NightClock.minute == 0, "clock is 2:00 on Maple, got " + NightClock.text())
	DialogueRunner.autoplay = false
	await _walk(2, 3)
	await _wait(2.0)
	await _shot("03a_textbox")
	for i in 3:
		await _tap("confirm")
		await _wait(0.3)
	await _wait(2.0)
	await _shot("03b_choices")
	DialogueRunner.autoplay = true
	await _idle()
	_expect(Game.has_flag("met_wick") and Game.has_flag("tonight_lamp_task"), "wick intro set met_wick and the lamp task")
	await _shot("03_wick")
	await _hold_at(3, 2)
	_expect(Game.has_flag("wick_joined"), "wick joined after the lamp")
	_expect(NightClock.minute == 2, "lamp cost 2 minutes, clock " + NightClock.text())
	if route == "clock":
		await _walk(6, 3)
		NightClock.add(60)
		await _morning()
		return
	await _hold_at(9, 2)
	await _walk(10, 4)
	await _shot("04_maple_lit")
	var before := NightClock.minute
	await _walk(17, 4)
	await _battle_shots("05_unbaker")
	if route == "asleep":
		await _morning()
		return
	await _idle()
	if route == "hustle":
		_expect(Game.has_flag("enemy_unbaker"), "hustle route sets enemy_unbaker")
	else:
		_expect(Game.has_flag("friend_unbaker") and "heel_of_bread" in Game.items, "help route sets friend_unbaker and gives bread")
	_note("Un-Baker fight took %d minutes" % (NightClock.minute - before))
	await _walk(23, 4)
	await _room("street_main")
	await _shot("06_main")
	await _talk_at(13, 7)
	_expect(Game.has_flag("postman_met"), "postman met")
	await _hold_at(8, 2)
	await _walk(27, 4)
	await _room("depot_exterior")
	await _talk_at(9, 1)
	await _talk_at(11, 1)
	_expect(Game.has_flag("tonight_side_door_open"), "wick opened the side door")
	await _walk(11, 1)
	await _room("depot_interior")
	await _idle()
	_expect(Game.has_flag("tonight_foreman_ok"), "foreman gave the form")
	await _shot("07_depot")
	DialogueRunner.run("depot_board")
	await _wait(0.6)
	await _shot("08_board")
	for i in 4:
		await _tap("move_right")
	await _tap("cancel")
	await _idle()
	await _talk_at(2, 8)
	_expect(Game.has_flag("has_watch"), "watch wound")
	await _walk(21, 3)
	await _room("square")
	_note("reached the square at " + NightClock.text())
	await _walk(3, 6)
	await _battle_shots("09_curfew")
	await _morning()


func _morning() -> void:
	await _room("bedroom_morning", 30.0)
	await _shot("10_morning")
	_expect(Game.night_over, "night is over in the morning")
	await _idle()
	DialogueRunner.run("morning_card")
	await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == Game.NIGHT_END, 10.0)
	await _wait(1.0)
	await _shot("11_night_end")
	await _tap("confirm")
	await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == Game.TITLE, 10.0)
	var want := 3 if route_done_once else 2
	route_done_once = true
	_expect(SaveManager.has_save() and Game.night == want, "night %d saved, night is %d" % [want, Game.night])
	await _wait(0.5)
	await _shot("12_title")
	if second_night and Game.night == 2:
		await _night_two()
		return
	_finish()


func _night_two() -> void:
	_note("--- night 2 (Continue) ---")
	Game.start_night(false)
	await _room("bedroom")
	_expect(Game.night == 2 and Game.has_flag("wick_joined") and not Game.has_flag("tonight_lamp_lit"), "night 2 keeps flags and resets tonight_ flags")
	await _walk(5, 8)
	await _room("hallway")
	await _walk(12, 3)
	await _room("kitchen")
	await _walk(2, 7)
	await _idle()
	await _walk(2, 8)
	await _room("backyard")
	await _walk(13, 4)
	await _room("street_maple")
	_expect(NightClock.minute == 0, "night 2 starts at 2:00 at the gate")
	_expect(_cur_room().follower != null, "wick follows from the start of night 2")
	await _walk(17, 4)
	await _idle()
	await _walk(23, 4)
	await _room("street_main")
	await _walk(27, 4)
	await _room("depot_exterior")
	await _talk_at(11, 1)
	await _walk(11, 1)
	await _room("depot_interior")
	await _idle()
	_expect(Game.has_flag("tonight_foreman_ok"), "night 2 foreman scene plays again")
	await _walk(21, 3)
	await _room("square")
	await _walk(3, 6)
	await _battle_shots("n2_curfew")
	second_night = false
	await _morning()


# ------------------------------------------------------------------ helpers

func _world() -> Node:
	var s := get_tree().current_scene
	return s if s != null and s.scene_file_path == Game.WORLD else null


func _cur_room() -> Room:
	var w := _world()
	return w.get("room") if w else null


func _room(id: String, timeout: float = 10.0) -> void:
	await _until(func() -> bool:
		var r := _cur_room()
		return r != null and r.id == id and not Game.busy, timeout)
	_note("room %s at %s" % [id, NightClock.text()])
	await _idle()


func _idle(timeout: float = 30.0) -> void:
	var calm := 0
	var t := 0.0
	while calm < 8 and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
		calm = calm + 1 if not DialogueRunner.is_active() and not Game.busy and not Game.in_battle and not Game.overlay_open else 0
	if t >= timeout:
		_fail("timed out waiting for idle in " + Game.room_id)


func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	if t >= timeout:
		_fail("timed out in %s at %s" % [Game.room_id, NightClock.text()])


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		for i in 3:
			await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _walk(x: int, y: int) -> void:
	var r := _cur_room()
	if r == null:
		_fail("no room to walk in")
		return
	r.player.position = Vector2(x * 16 + 8, y * 16 + 12)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _target_at(x: int, y: int) -> Entity:
	var r := _cur_room()
	var p := Vector2(x * 16 + 8, y * 16 + 8)
	for e in r.entities:
		if e.active and e.interactive() and e.rect.grow(2).has_point(p):
			return e
	return null


func _talk_at(x: int, y: int) -> void:
	var e := _target_at(x, y)
	if e == null:
		_fail("nothing to talk to at %d,%d in %s" % [x, y, Game.room_id])
		return
	DialogueRunner.run(e.dialogue)
	await _idle()


func _hold_at(x: int, y: int) -> void:
	var e := _target_at(x, y)
	if e == null or e.kind != "hold":
		_fail("no hold spot at %d,%d in %s" % [x, y, Game.room_id])
		return
	var r := _cur_room()
	while not DialogueRunner.is_active():
		r.advance_hold(e, 0.05)
		await get_tree().physics_frame
	await _idle()


func _battle_shots(prefix: String) -> void:
	await _until(func() -> bool: return Game.in_battle, 15.0)
	DialogueRunner.autoplay = false
	var w := _world()
	await _wait(2.5)
	await _shot(prefix + "_a")
	await _until(func() -> bool:
		if DialogueRunner.showing() and Engine.get_process_frames() % 20 == 0:
			_tap("confirm")
		return w.battle != null and w.battle._menu_on and not DialogueRunner.showing(), 20.0)
	await _wait(0.5)
	await _shot(prefix + "_menu")
	DialogueRunner.autoplay = true
	if route == "asleep" and w and w.get("battle"):
		await _until(func() -> bool: return w.battle._dodging, 20.0)
		w.battle.awake = 0
	else:
		await _until(func() -> bool: return w.battle != null and w.battle._dodging, 20.0)
		await _wait(1.5)
		await _shot(prefix + "_b")
	await _until(func() -> bool: return not Game.in_battle, 120.0)


func _shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png("%s/%s_%s.png" % [shots, route, name])


func _expect(ok: bool, what: String) -> void:
	if ok:
		_note("ok   " + what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	failures.append(what)
	var r := _cur_room()
	_note("FAIL %s  [room=%s dialogue=%s busy=%s battle=%s overlay=%s player=%s]" % [what, Game.room_id,
		DialogueRunner.is_active(), Game.busy, Game.in_battle, Game.overlay_open, (r.player.position / 16).floor() if r else Vector2.ZERO])
	if failures.size() >= 3:
		_finish()


func _note(s: String) -> void:
	log_lines.append(s)
	print("[bot] ", s)


func _inspect_all() -> void:
	var r := _cur_room()
	for e in r.entities.duplicate():
		if e.active and e.kind == "inspect":
			DialogueRunner.run(e.dialogue)
			await _idle()


func _finish() -> void:
	for e in Game.errors:
		failures.append("data error: " + e)
	print("[bot] errors from data: %d" % Game.errors.size())
	print("AUTOTEST %s route=%s clock=%s night=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", route, NightClock.text(), Game.night, failures.size()])
	for f in failures:
		print("  - ", f)
	get_tree().quit(0 if failures.is_empty() else 1)
