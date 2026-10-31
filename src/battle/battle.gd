class_name Battle
extends CanvasLayer
## One fight against a worker from data/workers/<id>.json.
## The loop is menu phase, dodge phase, clock tick. It ends when the worker is satisfied
## or storms off, when Tadzio falls asleep, or when 3:00 arrives.

signal finished(result: String)
signal _menu_done(choice: String)
signal _phase_done
signal _hustle_done(damage: int)

const ARENA_CENTER := Vector2(160, 102)
const OPTIONS: Array[String] = ["help", "hustle", "stall", "wick"]
const WICK_OPTIONS: Array[String] = ["wick_light", "wick_hold"]
const TOKEN_R := 3.0

var worker: Dictionary = {}
var worker_id: String = ""
var patience: int = 0
var patience_max: int = 1
var awake: int = 0
var awake_max: int = 1
var step_index: int = 0
var pattern_index: int = 0
var over: bool = false
var result: String = ""
var base_arena: Vector2 = Vector2(120, 80)

var _stall: bool = false
var _hold: bool = false
var _lit: bool = false
var _dodging: bool = false
var _pattern: Pattern
var _invuln: float = 0.0
var _since_hit: float = 99.0
var _history: Array[Dictionary] = []
var _time_scale: float = 1.0
var _tutorial_on: bool = false
var _tutorial_done: bool = false
var _tutorial_clear: float = 0.0
var _menu_on: bool = false
var _sub: bool = false
var _cursor: int = 0
var _input_at: int = 0
var _hustle_on: bool = false
var _hustle_t: float = 0.0
var _prompt_t: float = 0.0

var _root: Control
var _arena: Arena
var _worker_sprite: Sprite2D
var _worker_base: Vector2
var _shake: float = 0.0
var _anim_t: float = 0.0
var _idle_frames: int = 1
var _task_label: Label
var _awake_label: Label
var _awake_fill: ColorRect
var _patience_label: Label
var _patience_fill: ColorRect
var _boxes: Array[Panel] = []
var _buttons: Array[Label] = []
var _hint: Label
var _prompt: Label
var _wipe: ColorRect


func start(id: String) -> void:
	worker_id = id
	var d: Variant = Game.load_json("res://data/workers/%s.json" % id)
	if not d is Dictionary:
		finished.emit.call_deferred("abandoned")
		return
	worker = d
	patience_max = maxi(1, int(worker.get("patience", 10)))
	patience = patience_max
	awake_max = int(Game.tuning.get("awake_start", 20))
	awake = awake_max
	var dflt: Array = Game.tuning.get("arena_default", [120, 80])
	base_arena = Pattern.arena_for(worker, Vector2(float(dflt[0]), float(dflt[1])))
	_idle_frames = int(worker.get("idle_frames", 1))
	Game.rewind_charges = int(Game.tuning.get("rewind_charges", 3))
	Game.charges_changed.emit()
	_build()
	NightClock.hour_ended.connect(_on_hour_ended)
	if worker.has("music"):
		AudioBus.play_music(str(worker["music"]))
	await _wipe_in()
	await _line("intro")
	_loop()


func _loop() -> void:
	while not over:
		var action: String = await _menu_phase()
		if over:
			break
		var resolved: bool = await _act(action)
		if over or resolved:
			break
		await _dodge_phase()
		if over:
			break
		if awake <= 0:
			AudioBus.sfx("asleep")
			await DialogueRunner.run("battle_asleep")
			result = "asleep"
			break
		NightClock.spend("battle_round")
		AudioBus.sfx("tick")
	if result == "":
		result = "abandoned"
	if not Game.night_over:
		await _wipe_out()
	finished.emit(result)


func _line(key: String) -> void:
	var id := str(worker.get("dialogue", {}).get(key, ""))
	if id != "":
		await DialogueRunner.run(id)


# ------------------------------------------------------------------ menu phase

func _menu_phase() -> String:
	_menu_on = true
	_sub = false
	_input_at = Time.get_ticks_msec() + 150
	_refresh_menu()
	var choice: String = await _menu_done
	_menu_on = false
	_refresh_menu()
	return choice


func _act(action: String) -> bool:
	_stall = false
	_hold = false
	_lit = false
	match action:
		"help":
			return await _help()
		"hustle":
			return await _hustle()
		"stall":
			_stall = true
			NightClock.spend("stall")
			await DialogueRunner.run("battle_stall")
		"wick_light":
			_lit = true
			NightClock.spend("wick_light")
			AudioBus.sfx("whoosh")
			await DialogueRunner.run("battle_wick_light")
		"wick_hold":
			_hold = true
			NightClock.spend("wick_hold")
			await DialogueRunner.run("battle_wick_hold")
	return false


func _help() -> bool:
	var steps: Array = worker.get("task", {}).get("steps", [])
	if step_index >= steps.size():
		return false
	NightClock.spend("help")
	if over:
		return false
	var step: Dictionary = steps[step_index]
	await DialogueRunner.run(str(step.get("line", "")))
	if over:
		return false
	if step.has("choice"):
		var ch: Dictionary = step["choice"]
		var opts: Array[String] = []
		for o: Variant in ch.get("options", []):
			opts.append(str(o))
		var correct := int(ch.get("correct", 0))
		var pick := correct
		if not DialogueRunner.autoplay:
			pick = await DialogueRunner.ask("narrator", str(ch.get("prompt", "")), opts)
		if over:
			return false
		if pick != correct:
			AudioBus.sfx("cancel")
			await DialogueRunner.run(str(ch.get("wrong_line", "")))
			return false
	step_index += 1
	AudioBus.sfx("step_ok")
	_refresh_meters()
	if step_index >= steps.size():
		AudioBus.sfx("satisfied")
		await _line("satisfied")
		_reward("satisfied")
		result = "satisfied"
		return true
	return false


func _hustle() -> bool:
	NightClock.spend("hustle")
	if over:
		return false
	_hustle_on = true
	_hustle_t = 0.0
	_arena.hustle_t = 0.0
	_input_at = Time.get_ticks_msec() + 120
	var dmg: int = await _hustle_done
	_hustle_on = false
	_arena.hustle_t = -1.0
	if over:
		return false
	if dmg <= 0:
		AudioBus.sfx("cancel")
		await DialogueRunner.run("battle_hustle_miss")
		return false
	patience = maxi(0, patience - dmg)
	AudioBus.sfx("hustle")
	_shake = 0.35
	_refresh_meters()
	if patience <= 0:
		await _line("defeated")
		_reward("defeated")
		result = "defeated"
		return true
	await _line("hustle_hit")
	return false


func _reward(kind: String) -> void:
	var r: Dictionary = worker.get("rewards", {}).get(kind, {})
	Game.set_flag(str(r.get("flag", ("friend_" if kind == "satisfied" else "enemy_") + worker_id)))
	if r.has("item"):
		Game.give_item(str(r["item"]))


# ------------------------------------------------------------------ dodge phase

func _dodge_phase() -> void:
	var pats: Array = worker.get("patterns", [])
	if pats.is_empty():
		return
	var p: Dictionary = pats[pattern_index % pats.size()]
	pattern_index += 1
	var size := Pattern.arena_for(p, base_arena)
	_hint.visible = false
	await _arena.tween_size(size)
	_pattern = Pattern.create(p, size, int(worker.get("hit_damage", 2)))
	if _pattern == null or over:
		return
	_arena.pattern = _pattern
	_arena.lit = _lit
	_arena.token = _pattern.token_start()
	_arena.token_visible = true
	_invuln = 0.0
	_since_hit = 99.0
	_history.clear()
	_time_scale = 1.0
	_dodging = true
	await _phase_done
	_dodging = false
	if _tutorial_on:
		_end_tutorial()
	_prompt.visible = false
	_time_scale = 1.0
	_arena.pattern = null
	_arena.token_visible = false
	if not over:
		await _arena.tween_size(base_arena)


func _physics_process(delta: float) -> void:
	if not _dodging or over:
		return
	var dt := delta * _time_scale
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var lim := _arena.size / 2.0 - Vector2(TOKEN_R + 1, TOKEN_R + 1)
	_arena.token = (_arena.token + v * float(Game.tuning.get("token_speed", 90)) * dt).clamp(-lim, lim)
	if Input.is_action_just_pressed("rewind"):
		_try_rewind()
		if over:
			return
	_pattern.step(dt, _arena.token)
	_invuln = maxf(0.0, _invuln - dt)
	_since_hit += dt
	_arena.invuln = _invuln
	if _invuln <= 0.0 and not DialogueRunner.autoplay:
		var dmg := _pattern.collide(_arena.token, TOKEN_R)
		if dmg > 0:
			_take_hit(dmg)
	_check_tutorial()
	_history.append({"token": _arena.token, "p": _pattern.snapshot()})
	if _history.size() > int(Game.tuning.get("rewind_frames", 120)):
		_history.pop_front()
	if _pattern.finished() or awake <= 0:
		_dodging = false
		_phase_done.emit()


func _take_hit(dmg: int) -> void:
	var invuln := float(Game.tuning.get("invuln_seconds", 0.5))
	if _hold:
		_hold = false
		_invuln = invuln
		AudioBus.sfx("block")
		_show_prompt(Game.text("wick_blocked"), 1.0)
		return
	if _stall:
		dmg = ceili(dmg / 2.0)
	awake = maxi(0, awake - dmg)
	_invuln = invuln
	_since_hit = 0.0
	AudioBus.sfx("hit")
	_arena.hit_flash = 1.0
	_shake = 0.15
	_refresh_meters()
	if _tutorial_on:
		_end_tutorial()


func _try_rewind() -> void:
	if not Game.has_flag("has_watch"):
		return
	if Game.rewind_charges <= 0 or _history.size() < 2 or _since_hit < float(Game.tuning.get("invuln_seconds", 0.5)):
		AudioBus.sfx("cancel")
		return
	var s: Dictionary = _history[0]
	_history.clear()
	_arena.token = s["token"]
	_pattern.restore(s["p"])
	Game.rewind_charges -= 1
	Game.charges_changed.emit()
	AudioBus.sfx("rewind")
	_arena.rewind_flash = 1.0
	if _tutorial_on:
		_end_tutorial()
	NightClock.spend("rewind")


func _check_tutorial() -> void:
	var lookahead := float(Game.tuning.get("rewind_tutorial_lookahead", 0.3))
	if _tutorial_on:
		_tutorial_clear = 0.0 if _pattern.would_hit(_arena.token, TOKEN_R, lookahead) else _tutorial_clear + get_physics_process_delta_time()
		if _tutorial_clear > 0.6:
			_end_tutorial()
		return
	if _tutorial_done or not bool(worker.get("rewind_tutorial", false)):
		return
	if not Game.has_flag("has_watch") or Game.rewind_charges <= 0 or _history.size() < 40:
		return
	if _pattern.would_hit(_arena.token, TOKEN_R, lookahead):
		_tutorial_on = true
		_tutorial_clear = 0.0
		_time_scale = float(Game.tuning.get("rewind_tutorial_slowmo", 0.2))
		_show_prompt(Game.text("rewind_prompt"), -1.0)


func _end_tutorial() -> void:
	_tutorial_on = false
	_tutorial_done = true
	_time_scale = 1.0
	_prompt.visible = false


func _show_prompt(t: String, seconds: float) -> void:
	_prompt.text = t
	_prompt.position.y = ARENA_CENTER.y - _arena.size.y / 2.0 + 2.0
	_prompt.visible = true
	_prompt_t = seconds


func _on_hour_ended() -> void:
	over = true
	_dodging = false
	_phase_done.emit()
	_menu_done.emit("")
	_hustle_done.emit(0)


# ------------------------------------------------------------------ input and animation

func _process(delta: float) -> void:
	if _worker_sprite:
		_anim_t += delta * 1.5
		_worker_sprite.frame = int(_anim_t) % _idle_frames if _idle_frames > 1 else 0
		_shake = maxf(0.0, _shake - delta)
		_worker_sprite.position = _worker_base + (Vector2(randf_range(-2, 2), 0).round() if _shake > 0.0 else Vector2.ZERO)
	if _prompt_t > 0.0:
		_prompt_t -= delta
		if _prompt_t <= 0.0:
			_prompt.visible = false
	if over or DialogueRunner.showing() or Time.get_ticks_msec() < _input_at or DialogueRunner.just_ended():
		return
	var confirm := Input.is_action_just_pressed("confirm")
	if _hustle_on:
		_hustle_t += delta / float(Game.tuning.get("hustle", {}).get("sweep_seconds", 1.1))
		_arena.hustle_t = minf(_hustle_t, 1.0)
		if confirm or (DialogueRunner.autoplay and _hustle_t >= 0.5):
			var h: Dictionary = Game.tuning.get("hustle", {})
			var centered := absf(_hustle_t - 0.5) <= float(h.get("center_zone", 0.22)) / 2.0
			_hustle_done.emit(int(h.get("center_damage", 5)) if centered else int(h.get("edge_damage", 2)))
		elif _hustle_t >= 1.0:
			_hustle_done.emit(0)
		return
	if not _menu_on:
		return
	if DialogueRunner.autoplay:
		var steps: Array = worker.get("task", {}).get("steps", [])
		_menu_done.emit("help" if step_index < steps.size() and DialogueRunner.autoplay_fight == "help" else "hustle")
		return
	var n := WICK_OPTIONS.size() if _sub else OPTIONS.size()
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		_cursor = wrapi(_cursor + (1 if Input.is_action_just_pressed("move_right") else -1), 0, n)
		AudioBus.sfx("cursor")
		_refresh_menu()
	elif confirm:
		if _sub:
			AudioBus.sfx("confirm")
			_menu_done.emit(WICK_OPTIONS[_cursor])
		elif OPTIONS[_cursor] == "wick":
			if Game.has_flag("wick_joined"):
				AudioBus.sfx("confirm")
				_sub = true
				_cursor = 0
				_refresh_menu()
			else:
				AudioBus.sfx("buzz", 1.0, -6.0)
		else:
			AudioBus.sfx("confirm")
			_menu_done.emit(OPTIONS[_cursor])
	elif Input.is_action_just_pressed("cancel") and _sub:
		AudioBus.sfx("cancel")
		_sub = false
		_cursor = 3
		_refresh_menu()


# ------------------------------------------------------------------ layout

func _build() -> void:
	layer = 5
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Game.color("ink")
	bg.size = Vector2(320, 180)
	_root.add_child(bg)
	var sheet := "res://assets/sprites/%s.png" % str(worker.get("sprite", worker_id))
	if ResourceLoader.exists(sheet):
		var tex: Texture2D = load(sheet)
		_worker_sprite = Sprite2D.new()
		_worker_sprite.texture = tex
		_worker_sprite.hframes = 4
		_worker_sprite.vframes = 4
		_worker_sprite.centered = false
		_worker_sprite.offset = Vector2(-tex.get_width() / 8.0, -tex.get_height() / 4.0)
		_worker_base = Vector2(160, ARENA_CENTER.y - base_arena.y / 2.0 - 6)
		_worker_sprite.position = _worker_base
		_root.add_child(_worker_sprite)
	_label(Vector2(6, 2), str(worker.get("name", worker_id)), "moon")
	_label(Vector2(6, 11), str(worker.get("job", "")), "fog")
	_task_label = _label(Vector2(6, 20), "", "wake")
	_arena = Arena.new()
	_arena.position = ARENA_CENTER
	_root.add_child(_arena)
	_arena.set_size(base_arena)
	_hint = _label(Vector2(ARENA_CENTER.x - 54, ARENA_CENTER.y - 18), "", "fog")
	_hint.size = Vector2(108, 36)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt = _label(Vector2(0, 30), "", "wake")
	_prompt.size = Vector2(320, 10)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Game.color("ink"))
	_prompt.add_theme_constant_override("outline_size", 2)
	_prompt.visible = false
	_awake_label = _label(Vector2(6, 151), "", "moon")
	_awake_fill = _bar(Vector2(6, 162), "moon")
	_patience_label = _label(Vector2(254, 151), "", "moon")
	_patience_label.size = Vector2(60, 10)
	_patience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_patience_fill = _bar(Vector2(254, 162), "ember")
	for i in OPTIONS.size():
		var box := Panel.new()
		box.position = Vector2(74 + i * 44, 164)
		box.size = Vector2(40, 13)
		_root.add_child(box)
		_boxes.append(box)
		var l := _label(box.position + Vector2(0, 0), "", "moon")
		l.size = Vector2(40, 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_buttons.append(l)
	_wipe = ColorRect.new()
	_wipe.color = Game.color("ink")
	_wipe.size = Vector2(0, 180)
	add_child(_wipe)
	_refresh_meters()
	_refresh_menu()


func _label(pos: Vector2, t: String, c: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = t
	l.add_theme_color_override("font_color", Game.color(c))
	_root.add_child(l)
	return l


func _bar(pos: Vector2, c: String) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Game.color("dusk")
	bg.position = pos
	bg.size = Vector2(60, 4)
	_root.add_child(bg)
	var fill := ColorRect.new()
	fill.color = Game.color(c)
	fill.size = Vector2(60, 4)
	bg.add_child(fill)
	return fill


func _refresh_meters() -> void:
	_awake_label.text = "%s %d/%d" % [Game.text("awake"), awake, awake_max]
	_awake_fill.size.x = 60.0 * awake / awake_max
	_patience_label.text = "%s %d" % [Game.text("patience"), patience]
	_patience_fill.size.x = 60.0 * patience / patience_max
	var task: Dictionary = worker.get("task", {})
	var total := (task.get("steps", []) as Array).size()
	_task_label.text = "%s: %s  %d/%d" % [Game.text("task"), str(task.get("title", "")), step_index, total] if total > 0 else ""


func _refresh_menu() -> void:
	var joined := Game.has_flag("wick_joined")
	for i in _buttons.size():
		var key := ""
		if _sub:
			key = WICK_OPTIONS[i] if i < WICK_OPTIONS.size() else ""
		else:
			key = OPTIONS[i]
		_buttons[i].text = Game.text("btn_" + key) if key != "" else ""
		_boxes[i].visible = key != ""
		var selected := _menu_on and i == _cursor
		var disabled := key == "wick" and not joined
		var sb := StyleBoxFlat.new()
		sb.bg_color = Game.color("night") if selected else Game.color("ink")
		sb.border_color = Game.color("lamp") if selected else Game.color("dusk")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		_boxes[i].add_theme_stylebox_override("panel", sb)
		var c := "lamp" if selected else "moon"
		if disabled or not _menu_on:
			c = "fog" if not disabled else "dusk"
		_buttons[i].add_theme_color_override("font_color", Game.color(c))
	_hint.visible = _menu_on
	if _menu_on:
		var key := WICK_OPTIONS[_cursor] if _sub else OPTIONS[_cursor]
		if key == "wick" and not joined:
			key = "wick_locked"
		_hint.text = Game.text("hint_" + key)


func _wipe_in() -> void:
	var half := float(Game.tuning.get("battle_wipe_seconds", 0.6)) / 2.0
	_wipe.position.x = 0
	_wipe.size.x = 0
	var tw := create_tween()
	tw.tween_property(_wipe, "size:x", 320.0, half)
	await tw.finished
	_root.visible = true
	tw = create_tween()
	tw.tween_property(_wipe, "position:x", 320.0, half)
	await tw.finished


func _wipe_out() -> void:
	var half := float(Game.tuning.get("battle_wipe_seconds", 0.6)) / 2.0
	_wipe.position.x = 0
	_wipe.size.x = 0
	var tw := create_tween()
	tw.tween_property(_wipe, "size:x", 320.0, half)
	await tw.finished
	_root.visible = false
	tw = create_tween()
	tw.tween_property(_wipe, "position:x", 320.0, half)
	await tw.finished
