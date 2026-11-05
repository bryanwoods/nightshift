extends Node
## Plays Night 1 by itself and checks the clock, flags and rooms on the way.
## Routes: help (default), hustle, clock (run out the clock before the square), asleep, forget, finish.
## Run:  godot --path . res://dev/autotest.tscn -- route=help shots=/tmp/shots
## Screenshots need a window (no --headless). Prints AUTOTEST PASS or AUTOTEST FAIL and quits.

var route: String = "help"
var second_night: bool = false
var route_done_once: bool = false
var shots: String = ""
var failures: PackedStringArray = []


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
	if route == "input":
		await _input_route()
		return
	if route == "rewind":
		await _rewind_route()
		return
	if route == "tour":
		await _tour()
		return
	if route == "forget":
		await _forget_route()
		return
	if route == "finish":
		await _finish_route()
		return
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
	if not Game.has_flag("tonight_side_door_open"):
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
	await _wake()
	var want := 3 if route_done_once else 2
	route_done_once = true
	_expect(SaveManager.has_save() and Game.night == want, "night %d saved, night is %d" % [want, Game.night])
	await _wait(0.5)
	await _shot("12_title")
	if second_night and Game.night == 2:
		await _night_two()
		return
	_finish()


## The lamps screen, the morning room, the punch card and back to the title.
func _wake() -> void:
	await _until(func() -> bool: return _on(Game.LAMPS), 30.0)
	await _wait(1.0)
	await _shot("10_lamps")
	await _tap("confirm")
	await _room("bedroom_morning", 30.0)
	await _shot("10_morning")
	_expect(Game.night_over, "night is over in the morning")
	await _idle()
	DialogueRunner.run("morning_card")
	await _until(func() -> bool: return _on(Game.NIGHT_END), 10.0)
	await _wait(1.0)
	await _shot("11_night_end")
	await _tap("confirm")
	await _until(func() -> bool: return _on(Game.TITLE), 10.0)


func _on(scene: String) -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene


## Item 1: a friend made after the last save is forgotten at the end of the night and is a
## stranger next night. A friend saved at a lamp is kept.
func _forget_route() -> void:
	Game.set_flag("met_wick")
	Game.set_flag("tonight_lamp_task")
	NightClock.set_minute(0)
	Game.go_to_room("street_maple", "gate", 0)
	await _room("street_maple")
	await _hold_at(3, 2)
	_expect(Game.has_flag("wick_joined") and SaveManager.committed.get("flags", {}).has("wick_joined"), "the tutorial lamp offers a save, and Save commits Wick")
	await _walk(17, 4)
	await _until(func() -> bool: return Game.in_battle, 15.0)
	await _until(func() -> bool: return not Game.in_battle, 120.0)
	await _idle()
	_expect(Game.has_flag("friend_unbaker"), "helped the Un-Baker, not saved")
	NightClock.add(60)
	await _until(func() -> bool: return _on(Game.LAMPS), 30.0)
	_expect("unbaker" in Game.last_forgotten.get("friend", []), "the unsaved friend is listed under forgotten")
	_expect("wick" in SaveManager.kept().get("friend", []), "the saved friend is listed under kept")
	_expect(not Game.has_flag("friend_unbaker") and Game.has_flag("wick_joined"), "live state reverted to the last save")
	await _wake()
	Game.start_night(false)
	await _room("bedroom")
	_expect(not Game.has_flag("friend_unbaker") and not Game.has_flag("unbaker_seen"), "night 2: the Un-Baker is a stranger")
	NightClock.set_minute(0)
	Game.go_to_room("street_maple", "gate", 0)
	await _room("street_maple")
	await _walk(17, 4)
	await _until(func() -> bool: return Game.in_battle, 15.0)
	await _until(func() -> bool: return not Game.in_battle, 120.0)
	await _idle()
	Game.go_to_room("street_main", "west", 0)
	await _room("street_main")
	var lamp := _target_at(2, 2)
	_expect(lamp != null and lamp.kind == "lamp", "Main Street has a lamp")
	_cur_room().interact(lamp)
	await _idle()
	_expect(Game.has_flag("lamp_main") and SaveManager.committed.get("flags", {}).has("friend_unbaker"), "Wick lit the lamp and the save kept the friend")
	NightClock.add(60)
	await _until(func() -> bool: return _on(Game.LAMPS), 30.0)
	_expect("unbaker" in SaveManager.kept().get("friend", []) and Game.has_flag("friend_unbaker"), "the saved friend is kept")
	await _wake()
	Game.start_night(false)
	await _room("bedroom")
	_expect(Game.night == 3 and Game.has_flag("friend_unbaker") and Game.has_flag("lamp_main"), "night 3 remembers the friend and the lamp")
	_finish()


## Item 2: finish the Un-Baker, save, and start a new night. His post is empty, the bread is
## on the steps, Wick and the Foreman speak about it, and Shift Lv is 1 with 6 hours.
func _finish_route() -> void:
	DialogueRunner.autoplay_fight = "finish"
	Game.set_flag("met_wick")
	Game.set_flag("wick_joined")
	NightClock.set_minute(0)
	Game.go_to_room("street_maple", "gate", 0)
	await _room("street_maple")
	await _walk(17, 4)
	await _until(func() -> bool: return Game.in_battle, 15.0)
	await _until(func() -> bool: return not Game.in_battle, 120.0)
	await _idle()
	_expect(Game.has_flag("gone_unbaker") and Game.hours == 6 and int(Game.tally["finished_count"]) == 1, "finished the Un-Baker: gone, 6 hours, finished_count 1")
	_expect(Game.has_flag("wick_saw_gone"), "Wick spoke the first time a worker was finished")
	Game.go_to_room("street_main", "west", 0)
	await _room("street_main")
	_cur_room().interact(_target_at(2, 2))
	await _idle()
	NightClock.add(60)
	await _wake()
	Game.start_night(false)
	await _room("bedroom")
	NightClock.set_minute(0)
	Game.go_to_room("street_maple", "gate", 0)
	await _room("street_maple")
	var r := _cur_room()
	var unbaker := r.entity_by_id("unbaker")
	_expect(unbaker == null or not unbaker.active, "night 2: the Un-Baker's post is empty")
	_expect(r.tiles.get_cell_atlas_coords(Vector2i(12, 1)) == r._tile_index["house_door_bread"], "night 2: the bread is on the steps")
	await _walk(17, 4)
	await _idle()
	_expect(Game.has_flag("tonight_saw_cart"), "night 2: Wick speaks at the empty post")
	Game.go_to_room("depot_interior", "side", 0)
	await _room("depot_interior")
	_expect(Game.seen.has("foreman_missing"), "night 2: the Foreman names the missing Un-Baker")
	_expect(Game.shift_level() == 1 and Game.hours == 6, "Shift Lv 1 with 6 hours")
	_finish()


func _night_two() -> void:
	_note("--- night 2 (Continue) ---")
	Game.start_night(false)
	await _room("bedroom")
	_expect(Game.night == 2 and Game.has_flag("wick_joined") and not Game.has_flag("tonight_lamp_task"), "night 2 keeps saved flags and resets tonight_ flags")
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


## Real key presses, no teleports: walls, facing, interact, doors and hold-to-light.
func _input_route() -> void:
	DialogueRunner.autoplay = false
	var r := _cur_room()
	await _press_for("move_up", 0.15)
	_expect(r.player.target != null and r.player.target.dialogue == "bedroom_nightstand", "facing up from the spawn targets the nightstand")
	await _tap("confirm")
	await _wait(0.2)
	_expect(DialogueRunner.is_active(), "confirm opens the nightstand line")
	for i in 6:
		if not DialogueRunner.is_active():
			break
		await _tap("confirm")
		await _wait(0.15)
	await _wait(0.4)
	_expect(not DialogueRunner.is_active(), "the line closes and does not open again")
	await _press_for("move_down", 1.5)
	_expect(int(r.player.position.y / 16) == 7, "the bottom wall stops Tadzio on row 7, he is on row %d" % int(r.player.position.y / 16))
	Input.action_press("move_right")
	await _until(func() -> bool: return r.player.position.x >= 5 * 16 + 7, 5.0)
	Input.action_release("move_right")
	await _press_for("move_down", 0.6)
	await _room("hallway")
	_expect(true, "walked through the bedroom door")
	DialogueRunner.autoplay = true
	Game.set_flag("met_wick")
	Game.set_flag("tonight_lamp_task")
	NightClock.set_minute(0)
	Game.go_to_room("street_maple", "gate", 0)
	await _room("street_maple")
	r = _cur_room()
	await _walk(3, 3)
	await _press_for("move_up", 0.1)
	_expect(r.player.target != null and r.player.target.kind == "hold", "under the lamp, the target is the hold spot")
	Input.action_press("confirm")
	await _until(func() -> bool: return Game.has_flag("lamp_maple"), 8.0)
	Input.action_release("confirm")
	await _idle()
	_expect(Game.has_flag("wick_joined") and NightClock.minute == 2, "holding confirm lit the lamp for 2 minutes, clock " + NightClock.text())
	_expect(r.follower != null, "wick follows")
	await _press_for("move_right", 1.0)
	_expect(r.follower.position.distance_to(r.player.position) < 30.0, "wick stays close behind")
	await _input_battle()
	_finish()


func _input_battle() -> void:
	Engine.time_scale = 1.0
	DialogueRunner.autoplay = false
	Game.start_battle("unbaker")
	var w := _world()
	await _until(func() -> bool: return w.battle != null, 10.0)
	if w.battle == null:
		return
	var b: Battle = w.battle
	while not b._menu_on or DialogueRunner.showing():
		await _tap("confirm")
		await _wait(0.2)
	await _wait(0.3)
	await _tap("move_right")
	_expect(b._cursor == 1, "right arrow moves the battle menu to Hustle")
	await _tap("confirm")
	await _until(func() -> bool: return b._hustle_on, 3.0)
	await _until(func() -> bool: return b._hustle_t >= 0.47, 3.0)
	await _tap("confirm")
	await _wait(0.3)
	_expect(b.patience == 10, "a centered Hustle press does 5, patience is %d" % b.patience)
	while not b._dodging:
		if DialogueRunner.showing():
			await _tap("confirm")
		await _wait(0.2)
	await _press_for("move_left", 0.4)
	_expect(b._arena.token.x < -10.0, "arrow keys move the flashlight token in the arena")
	await _until(func() -> bool: return b._menu_on and not DialogueRunner.showing(), 15.0)
	while b._cursor != 3:
		await _tap("move_right")
	await _tap("confirm")
	_expect(b._sub, "Wick opens the Light / Hold sub-menu")
	await _tap("confirm")
	await _until(func() -> bool: return DialogueRunner.showing(), 3.0)
	_expect(b._lit, "Light was chosen")
	DialogueRunner.autoplay = true
	NightClock.add(60)
	await _until(func() -> bool: return _on(Game.LAMPS), 15.0)
	_expect(not Game.has_flag("friend_unbaker") and not Game.has_flag("enemy_unbaker"), "3:00 mid-fight abandons it with no flag")


## Screenshots of every room and every Curfew pattern. Needs a window and shots=DIR.
func _tour() -> void:
	await _shot("room_bedroom")
	DialogueRunner.autoplay = false
	DialogueRunner.run("unbaker_after_friend")
	for i in 3:
		await _wait(0.9)
		await _tap("confirm")
		await _tap("confirm")
	await _wait(1.0)
	await _shot("tadzio_talks")
	DialogueRunner.abort()
	DialogueRunner.autoplay = true
	Game.set_flag("wick_joined")
	Game.set_flag("met_wick")
	NightClock.set_minute(0)
	for room in ["hallway", "backyard", "street_maple", "depot_exterior", "depot_interior", "square"]:
		Game.busy = false
		Game.go_to_room(room, "default", 0)
		await _room(room)
		await _wait(0.4)
		await _shot("room_" + room)
	Engine.time_scale = 1.0
	Game.set_flag("has_watch")
	Game.start_battle("curfew")
	var w := _world()
	await _until(func() -> bool: return w.battle != null, 10.0)
	var b: Battle = w.battle
	DialogueRunner.autoplay_fight = "hustle"
	for i in 4:
		if not Game.in_battle:
			break
		b._lit = i == 3
		await _until(func() -> bool: return w.battle == null or w.battle._dodging, 30.0)
		await _wait(2.5)
		await _shot("curfew_pattern_%d" % (i + 1))
		await _until(func() -> bool: return w.battle == null or not w.battle._dodging, 30.0)
	await _until(func() -> bool: return not Game.in_battle, 180.0)
	await _tour_choice()
	_finish()


## Pockets, the spare-or-finish choice and the finish, as screenshots.
func _tour_choice() -> void:
	DialogueRunner.autoplay = false
	Game.give_item("heel_of_bread")
	Game.start_battle("unbaker")
	var w := _world()
	await _until(func() -> bool: return w.battle != null, 10.0)
	var b: Battle = w.battle
	while not b._menu_on or DialogueRunner.showing():
		await _tap("confirm")
		await _wait(0.2)
	while b._cursor != 4:
		await _tap("move_right")
	await _tap("confirm")
	await _wait(1.0)
	await _shot("pockets")
	await _tap("move_down")
	await _tap("confirm")
	await _until(func() -> bool: return b._menu_on and not DialogueRunner.showing(), 10.0)
	b.patience = 1
	b._menu_done.emit("hustle")
	await _until(func() -> bool: return b._hustle_on, 3.0)
	b._hustle_done.emit(5)
	await _until(func() -> bool: return DialogueRunner.showing() and DialogueRunner.textbox._options.size() == 2, 10.0)
	await _wait(2.0)
	await _shot("choice")
	await _tap("move_down")
	await _tap("confirm")
	await _wait(0.9)
	await _shot("finish_flicker")
	await _wait(1.6)
	await _shot("finish_gone")
	DialogueRunner.autoplay = true
	await _until(func() -> bool: return not Game.in_battle, 30.0)


func _rewind_route() -> void:
	Engine.time_scale = 1.0
	Game.set_flag("has_watch")
	Game.set_flag("wick_joined")
	NightClock.set_minute(0)
	Game.start_battle("curfew")
	var w := _world()
	await _until(func() -> bool: return w.battle != null, 10.0)
	var b: Battle = w.battle
	b.pattern_index = 3
	await _until(func() -> bool: return b._dodging, 20.0)
	_expect(b._cursor == 3, "a dark turn puts the menu cursor on Wick")
	await _wait(1.5)
	var t_before: float = b._pattern.t
	var minute := NightClock.minute
	await _tap("rewind")
	await get_tree().physics_frame
	_expect(Game.rewind_charges == 2, "rewind spends a charge, %d left" % Game.rewind_charges)
	_expect(NightClock.minute == minute + 1, "rewind costs a minute")
	_expect(b._pattern.t < t_before - 0.5, "rewind rolls the pattern back (%.2f -> %.2f)" % [t_before, b._pattern.t])
	await _tap("rewind")
	await _tap("rewind")
	await _tap("rewind")
	_expect(Game.rewind_charges == 0, "three charges per fight")
	_finish()


func _press_for(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)
	await get_tree().physics_frame


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
	while not DialogueRunner.is_active() and e.active:
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
	print("[bot] ", s)


func _inspect_all() -> void:
	var r := _cur_room()
	for e in r.entities.duplicate():
		if e.active and e.kind == "inspect":
			DialogueRunner.run(e.dialogue)
			await _idle()


func _finish() -> void:
	if route in ["help", "hustle"]:
		var text := FileAccess.get_file_as_string(Game.playtest_path)
		_expect("\tbattle_end\t" in text and "\tnight_end\t" in text, "the playtest log has the fights and the night end")
	if Game.playtest_path != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.playtest_path))
	for e in Game.errors:
		failures.append("data error: " + e)
	print("[bot] errors from data: %d" % Game.errors.size())
	print("AUTOTEST %s route=%s clock=%s night=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", route, NightClock.text(), Game.night, failures.size()])
	for f in failures:
		print("  - ", f)
	get_tree().quit(0 if failures.is_empty() else 1)
