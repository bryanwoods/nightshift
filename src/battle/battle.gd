class_name Battle
extends CanvasLayer
## One fight against a worker from data/workers/<id>.json.
## The loop is menu phase, dodge phase, clock tick. Every ending goes through _resolve:
## satisfied, spared, finished, or abandoned (asleep, or 3:00).

signal finished(result: String)
signal _menu_done(choice: String)
signal _phase_done
signal _hustle_done(damage: int)
signal _item_done(item: String)

const ARENA_CENTER := Vector2(160, 84)
const OPTIONS: Array[String] = ["help", "hustle", "stall", "wick", "pockets"]
const WICK_OPTIONS: Array[String] = ["wick_light", "wick_hold"]
const TOKEN_R := 3.0
## Battle sheets stand in the left column with their feet here.
const WORKER_FEET := Vector2(50, 136)
const BAND_X := 100.0

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
var _turn: int = 0
var _pending_bubble: String = ""
var _bubble_t: float = -1.0
var _bubble_pitch: float = 1.0
var _bubble_seen: int = 0
var _items: Array[String] = []
var _item_cursor: int = -1

var _root: Control
var _arena: Arena
var _worker_sprite: Sprite2D
var _glow: Sprite2D
var _worker_base: Vector2
var _shake: float = 0.0
var _arena_shake: float = 0.0
var _anim_t: float = 0.0
var _idle_frames: int = 1
var _task_label: Label
var _awake_label: Label
var _level_label: Label
var _awake_fill: ColorRect
var _patience_label: Label
var _patience_fill: ColorRect
var _boxes: Array[Panel] = []
var _menu_bar: Control
var _buttons: Array[Label] = []
var _hint: Label
var _flavor: Label
var _effect: Label
var _bubble: Panel
var _bubble_text: Label
var _stats: Dictionary = {"turns": 0, "hits": 0, "damage": 0, "rewinds": 0, "blocked": 0, "actions": [], "hustle": []}
var _start_msec: int = 0
var _start_minute: int = 0
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
	awake_max = int(Game.tuning.get("awake_start", 20)) + (Game.shift_level() - 1) * int(Game.tuning.get("level_awake", 4))
	awake = awake_max
	var dflt: Array = Game.tuning.get("arena_default", [120, 80])
	base_arena = Pattern.arena_for(worker, Vector2(float(dflt[0]), float(dflt[1])))
	_idle_frames = 2
	Game.rewind_charges = int(Game.tuning.get("rewind_charges", 3))
	Game.charges_changed.emit()
	_build()
	DialogueRunner.textbox.inset = BAND_X - 4.0
	_start_msec = Time.get_ticks_msec()
	_start_minute = NightClock.minute
	Game.playtest("battle_start", {"worker": worker_id})
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
		if over or awake <= 0:
			break
		NightClock.spend("battle_round")
		AudioBus.sfx("tick")
	if result == "":
		await _resolve("abandoned")
	_stats["result"] = result
	_stats["worker"] = worker_id
	_stats["minutes"] = NightClock.minute - _start_minute
	_stats["seconds"] = snappedf((Time.get_ticks_msec() - _start_msec) / 1000.0, 0.1)
	_stats["awake_left"] = awake
	Game.playtest("battle_end", _stats)
	if not Game.night_over:
		await _wipe_out()
	DialogueRunner.textbox.inset = 0.0
	finished.emit(result)


func _line(key: String) -> void:
	var id := str(worker.get("dialogue", {}).get(key, ""))
	if id != "":
		await DialogueRunner.run(id)


# ------------------------------------------------------------------ menu phase

func _menu_phase() -> String:
	while not over:
		_flavor.text = _turn_text("flavor")
		var pats: Array = worker.get("patterns", [])
		if not pats.is_empty() and str(pats[pattern_index % pats.size()].get("type", "")) == "dark":
			_flavor.text = Game.text("dark_warning")
			if Game.has_flag("wick_joined"):
				_cursor = OPTIONS.find("wick")
		_menu_on = true
		_sub = false
		_input_at = Time.get_ticks_msec() + 150
		_refresh_menu()
		var choice: String = await _menu_done
		_menu_on = false
		_refresh_menu()
		if choice != "pockets":
			return choice
		var item := await _pick_item()
		if item != "":
			return "item:" + item
	return ""


## Pockets: the items that do something in a fight, listed in the arena with the effect of
## the selected one under it. Close goes back to the menu.
func _pick_item() -> String:
	_items.clear()
	for it in Game.items:
		var info: Dictionary = Game.item_info.get(it, {})
		if info.has("awake") or info.has("block"):
			_items.append(it)
	if _items.is_empty():
		await DialogueRunner.run("battle_pockets_empty")
		return ""
	_item_cursor = 0
	_input_at = Time.get_ticks_msec() + 150
	_show_items()
	var pick: String = await _item_done
	_item_cursor = -1
	_flavor.visible = false
	_effect.visible = false
	return pick


func _show_items() -> void:
	var lines: PackedStringArray = []
	for i in _items.size() + 1:
		lines.append(("> " if i == _item_cursor else "  ") + (Game.item_name(_items[i]) if i < _items.size() else Game.text("pockets_close")))
		if i == _item_cursor:
			lines.append("")
	_flavor.text = "\n".join(lines)
	_flavor.visible = true
	_effect.text = str(Game.item_info.get(_items[_item_cursor], {}).get("effect", "")) if _item_cursor < _items.size() else ""
	_effect.position.y = _flavor.position.y + (_item_cursor + 1) * _flavor.get_line_height()
	_effect.visible = true


func _use_item(item: String) -> void:
	var info: Dictionary = Game.item_info.get(item, {})
	Game.items.erase(item)
	Game.playtest("item", {"item": item, "worker": worker_id})
	awake = mini(awake_max, awake + int(info.get("awake", 0)))
	_hold = bool(info.get("block", false))
	AudioBus.sfx("step_ok")
	_refresh_meters()
	_show_prompt(str(info.get("use_text", Game.item_name(item))), 1.5)


func _act(action: String) -> bool:
	_stats["turns"] += 1
	(_stats["actions"] as Array).append(action)
	_stall = false
	_hold = false
	_lit = false
	if action.begins_with("item:"):
		_use_item(action.trim_prefix("item:"))
		return false
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
	_pending_bubble = str(step.get("bubble", ""))
	AudioBus.sfx("step_ok")
	_refresh_meters()
	if step_index >= steps.size():
		await _resolve("satisfied")
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
	(_stats["hustle"] as Array).append(dmg)
	_hustle_on = false
	_arena.hustle_t = -1.0
	if over:
		return false
	if dmg <= 0:
		AudioBus.sfx("cancel")
		await DialogueRunner.run("battle_hustle_miss")
		return false
	patience = maxi(0, patience - dmg - (Game.shift_level() - 1) * int(Game.tuning.get("level_hustle", 1)))
	AudioBus.sfx("hustle")
	_shake = 0.35
	_refresh_meters()
	if patience <= 0:
		await _resolve("finished" if await _finish_them() else "spared")
		return true
	_pending_bubble = str(worker.get("dialogue", {}).get("hustle_hit", ""))
	return false


## Patience is gone: let them go, or clock them out. Help is not offered again.
func _finish_them() -> bool:
	var spare_h := mini(1, int(worker.get("hours", 0)))
	var options: Array[String] = [Game.text("spare_option"), Game.text("finish_option")]
	if bool(Game.tuning.get("show_choice_rewards", true)):
		options[0] += " (%s)" % Game.hours_text(spare_h)
		options[1] += " (%s)" % Game.hours_text(int(worker.get("hours", 0)))
	if DialogueRunner.autoplay:
		return DialogueRunner.autoplay_fight == "finish"
	var prompt := Game.text("spare_prompt").replace("{name}", Game.display_name(worker_id))
	return await DialogueRunner.ask("narrator", prompt, options) == 1


## Every way a fight ends. Satisfied: Help finished the task. Spared and finished: Hustle
## took all Patience. Abandoned: asleep, or 3:00.
func _resolve(outcome: String) -> void:
	result = outcome
	match outcome:
		"satisfied":
			AudioBus.sfx("satisfied")
			await _line("satisfied")
			Game.clear_flag("enemy_" + worker_id)
			Game.set_flag("friend_" + worker_id)
			Game.tally["helper_count"] += 1
		"spared":
			_gain(mini(1, int(worker.get("hours", 0))))
			await _line("spared")
			Game.clear_flag("friend_" + worker_id)
			Game.set_flag("enemy_" + worker_id)
			Game.tally["hustler_count"] += 1
		"finished":
			await _go_still()
			Game.clear_flag("friend_" + worker_id)
			Game.clear_flag("enemy_" + worker_id)
			Game.set_flag("gone_" + worker_id)
			if Game.gone().size() >= 2:
				Game.set_flag("many_gone")
			Game.tally["finished_count"] += 1
			_gain(int(worker.get("hours", 0)))
			await DialogueRunner.run("battle_finished")
		"abandoned":
			if awake <= 0 and not over:
				AudioBus.sfx("asleep")
				await DialogueRunner.run("battle_asleep")
	var item := str(worker.get("rewards", {}).get(outcome, {}).get("item", ""))
	if item != "":
		Game.give_item(item)


## Finished: the worker goes still, flickers twice and is gone. The lantern goes out on one
## low note, and the frame holds for a second.
func _go_still() -> void:
	if _worker_sprite == null:
		return
	_idle_frames = 1
	await get_tree().create_timer(0.5).timeout
	for i in 2:
		_worker_sprite.visible = false
		await get_tree().create_timer(0.1).timeout
		_worker_sprite.visible = true
		await get_tree().create_timer(0.15).timeout
	_worker_sprite.visible = false
	_glow.visible = false
	AudioBus.sfx("gone")
	await get_tree().create_timer(1.0).timeout


func _gain(n: int) -> void:
	if n <= 0:
		return
	var before := Game.shift_level()
	Game.hours += n
	var t := Game.hours_text(n)
	if Game.shift_level() > before:
		t += "   " + Game.text("level_up").replace("{n}", str(Game.shift_level()))
	_show_prompt(t, 2.5)
	_refresh_meters()


# ------------------------------------------------------------------ dodge phase

func _dodge_phase() -> void:
	var pats: Array = worker.get("patterns", [])
	if pats.is_empty():
		return
	var p: Dictionary = pats[pattern_index % pats.size()]
	pattern_index += 1
	var size := Pattern.arena_for(p, base_arena)
	_hint.visible = false
	_flavor.visible = false
	await _arena.tween_size(size)
	_show_bubble(_pending_bubble if _pending_bubble != "" else _turn_id("turn_lines"))
	_pending_bubble = ""
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
	_bubble.visible = false
	_bubble_t = -1.0
	_turn += 1
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
		_stats["blocked"] += 1
		_show_prompt(Game.text("wick_blocked"), 1.0)
		return
	if _stall:
		dmg = ceili(dmg / 2.0)
	awake = maxi(0, awake - dmg)
	_stats["hits"] += 1
	_stats["damage"] += dmg
	Game.playtest("battle_hit", {"worker": worker_id, "pattern": str(_pattern.params.get("type", "")), "damage": dmg, "awake": awake})
	_invuln = invuln
	_since_hit = 0.0
	AudioBus.sfx("hit")
	_arena.hit_flash = 1.0
	_arena_shake = 0.2
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
	_stats["rewinds"] += 1
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
		Game.playtest("rewind_tutorial", {"worker": worker_id})


func _end_tutorial() -> void:
	_tutorial_on = false
	_tutorial_done = true
	_time_scale = 1.0
	_prompt.visible = false


func _show_prompt(t: String, seconds: float) -> void:
	_prompt.text = t
	_prompt.position.y = ARENA_CENTER.y - _arena.size.y / 2.0 + 3.0
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
	if _arena:
		_arena_shake = maxf(0.0, _arena_shake - delta)
		_arena.position = ARENA_CENTER + (Vector2(randf_range(-2, 2), randf_range(-2, 2)).round() if _arena_shake > 0.0 else Vector2.ZERO)
		_menu_bar.visible = not DialogueRunner.showing() and not _bubble.visible
	if _bubble_t >= 0.0:
		_type_bubble(delta)
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
	if _item_cursor >= 0:
		var step := int(Input.is_action_just_pressed("move_down")) - int(Input.is_action_just_pressed("move_up"))
		if step != 0:
			_item_cursor = wrapi(_item_cursor + step, 0, _items.size() + 1)
			AudioBus.sfx("cursor")
			_show_items()
		elif confirm:
			AudioBus.sfx("confirm")
			_item_done.emit(_items[_item_cursor] if _item_cursor < _items.size() else "")
		elif Input.is_action_just_pressed("cancel"):
			AudioBus.sfx("cancel")
			_item_done.emit("")
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
	var sheet := "res://assets/sprites/%s_battle.png" % str(worker.get("sprite", worker_id))
	if ResourceLoader.exists(sheet):
		var tex: Texture2D = load(sheet)
		_worker_sprite = Sprite2D.new()
		_worker_sprite.texture = tex
		_worker_sprite.hframes = _idle_frames
		_worker_sprite.centered = false
		_worker_sprite.offset = Vector2(-tex.get_width() / 2.0 / _idle_frames, -tex.get_height())
		_worker_base = WORKER_FEET
		_worker_sprite.position = _worker_base
		_glow = Sprite2D.new()
		_glow.texture = load("res://assets/sprites/light_radial.png")
		_glow.modulate = Color(Game.color("lamp"), 0.3)
		_glow.position = _worker_base - Vector2(0, tex.get_height() / 2.0)
		_root.add_child(_glow)
		_root.add_child(_worker_sprite)
	var tag := bool(worker.get("name_tag", true))
	_label(Vector2(4, 2), str(worker.get("name", worker_id)) if tag else "", "moon")
	_label(Vector2(4, 15), str(worker.get("job", "")) if tag else "", "fog", 220)
	_task_label = _right(20, "wake")
	_arena = Arena.new()
	_arena.position = ARENA_CENTER
	_root.add_child(_arena)
	_arena.set_size(base_arena)
	var text_w := base_arena.x - 12.0
	_flavor = _label(ARENA_CENTER + Vector2(-text_w / 2.0, -base_arena.y / 2.0 + 3), "", "moon", text_w)
	_effect = _label(_flavor.position + Vector2(12, 0), "", "wake")
	_hint = _label(Vector2(BAND_X, ARENA_CENTER.y + base_arena.y / 2.0 + 4), "", "fog", 316 - BAND_X)
	_build_bubble()
	_prompt = _label(Vector2(ARENA_CENTER.x - base_arena.x / 2.0, 0), "", "wake", base_arena.x)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Game.color("ink"))
	_prompt.add_theme_constant_override("outline_size", 2)
	_prompt.visible = false
	_patience_label = _right(60, "moon")
	_patience_fill = _bar(Vector2(256, 74), "ember")
	_level_label = _right(82, "fog")
	_awake_label = _right(95, "moon")
	_awake_fill = _bar(Vector2(256, 110), "moon")
	_menu_bar = Control.new()
	_root.add_child(_menu_bar)
	for i in OPTIONS.size():
		var box := Panel.new()
		box.position = Vector2(6 + i * 62, 163)
		box.size = Vector2(56, 15)
		_menu_bar.add_child(box)
		_boxes.append(box)
		var l := _label(box.position, "", "moon")
		l.size = Vector2(56, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.reparent(_menu_bar)
		_buttons.append(l)
	_wipe = ColorRect.new()
	_wipe.color = Game.color("ink")
	_wipe.size = Vector2(0, 180)
	add_child(_wipe)
	_refresh_meters()
	_refresh_menu()


## width > 0 wraps the text. Wrapping must be on before the label enters the tree.
func _label(pos: Vector2, t: String, c: String, width: float = 0.0) -> Label:
	var l := Label.new()
	l.position = pos
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(width, 0)
	l.text = t
	l.add_theme_color_override("font_color", Game.color(c))
	_root.add_child(l)
	return l


## A label in the right column, beside the arena.
func _right(y: float, c: String) -> Label:
	var l := _label(Vector2(226, y), "", c, 90)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	_level_label.text = Game.text("battle_lv").replace("{n}", str(Game.shift_level()))
	_awake_label.text = "%s %d/%d" % [Game.text("awake"), awake, awake_max]
	_awake_fill.size.x = 60.0 * awake / awake_max
	_patience_label.text = "%s %d" % [Game.text("patience"), patience]
	_patience_fill.size.x = 60.0 * patience / patience_max
	var task: Dictionary = worker.get("task", {})
	var total := (task.get("steps", []) as Array).size()
	_task_label.text = "%s %d/%d\n%s" % [Game.text("task"), step_index, total, str(task.get("title", ""))] if total > 0 else ""


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
	_flavor.visible = _menu_on
	if _menu_on:
		var key := WICK_OPTIONS[_cursor] if _sub else OPTIONS[_cursor]
		if key == "wick" and not joined:
			key = "wick_locked"
		_hint.text = Game.text("hint_" + key)


# ------------------------------------------------------------------ speech bubble

## The dialogue id for this turn from a list in the worker file ("turn_lines" or "flavor").
func _turn_id(list_key: String) -> String:
	var ids: Array = worker.get(list_key, [])
	return str(ids[_turn % ids.size()]) if not ids.is_empty() else ""


func _turn_text(list_key: String) -> String:
	return str(DialogueRunner.first_line(_turn_id(list_key)).get("text", ""))


func _build_bubble() -> void:
	_bubble = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.color("moon")
	sb.border_color = Game.color("ink")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.visible = false
	_root.add_child(_bubble)
	_bubble_text = Label.new()
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.position = Vector2(5, 5)
	_bubble_text.add_theme_color_override("font_color", Game.color("ink"))
	_bubble.add_child(_bubble_text)
	var tail := Polygon2D.new()
	tail.color = Game.color("moon")
	tail.polygon = PackedVector2Array([Vector2(1, 4), Vector2(-6, 7), Vector2(1, 10)])
	_bubble.add_child(tail)


## A worker line beside the worker. It types out while the dodge phase starts and never waits for a key.
func _show_bubble(id: String) -> void:
	var line := DialogueRunner.first_line(id)
	var text := str(line.get("text", ""))
	if text == "":
		return
	_bubble_pitch = float(DialogueRunner.speakers.get(str(line.get("speaker", "")), {}).get("pitch", 1.0))
	var font := _bubble_text.get_theme_font("font")
	var max_w := 316.0 - BAND_X - 10.0
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_w, _bubble_text.get_theme_font_size("font_size"))
	_bubble_text.size = Vector2(max_w, size.y)
	_bubble_text.text = text
	_bubble_text.visible_characters = 0
	var w := maxf(size.x, 90.0) + 10.0
	var h := size.y + 8.0
	_bubble.position = Vector2(BAND_X, minf(ARENA_CENTER.y + _arena.size.y / 2.0 + 4.0, 179.0 - h))
	_bubble.size = Vector2(w, h)
	_bubble.visible = true
	_bubble_t = 0.0
	_bubble_seen = 0


func _type_bubble(delta: float) -> void:
	_bubble_t += delta
	var cps := float(Game.tuning.get("text_cps", 30)) * SaveManager.text_speed()
	var n := mini(int(_bubble_t * cps), _bubble_text.get_total_character_count())
	if n == _bubble_text.visible_characters:
		return
	_bubble_text.visible_characters = n
	if n - _bubble_seen >= int(Game.tuning.get("blip_every", 2)):
		_bubble_seen = n
		AudioBus.blip(_bubble_pitch)


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
