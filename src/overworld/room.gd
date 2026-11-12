class_name Room
extends Node2D
## Builds one room from data/rooms/<id>.json: tiles from the ASCII layout, entities, lights,
## darkness and music. Then runs doors, triggers, hold spots, lamps, encounters and the
## interact marker.

const TILE: int = 16
const DIR := "res://data/rooms/"
const VIEW := Vector2(320, 180)
const ATLAS_COLUMNS := 8
## The flashlight cone texture: 56 px long, 60 degrees wide.
const BEAM_LENGTH := 56.0
const BEAM_HALF_ANGLE := 30.0
const BAYER: PackedByteArray = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const GLOW_ALPHA := 0.2
## Seconds a light takes to flicker on, and to flicker out.
const WAKE_ON := 1.35
const WAKE_OFF := 0.48

static var _light_tex: Dictionary = {}

var id: String = ""
var data: Dictionary = {}
var grid: Vector2i
var tiles: TileMapLayer
var actors: Node2D
var overlay: CanvasLayer
var player: Player
var follower: Follower
var camera: Camera2D
var entities: Array[Entity] = []
var lights: Dictionary = {}
var _lamp_posts: Dictionary = {}

var _light_base: Dictionary = {}
var _light_scale: Dictionary = {}
var _glows: Dictionary = {}
var _glow_clip: Control
## Light id to [seconds since the switch, the state it is going to].
var _wake: Dictionary = {}
var _window_lights: Array[String] = []
var _tile_index: Dictionary = {}
var _layout: Array = []
var _marker: Sprite2D
var _hold_bg: ColorRect
var _hold_fill: ColorRect
var _hint: Label
var _shake_t: float = 0.0
var _shake_amp: float = 0.0
var _time: float = 0.0


func build(room_id: String, spawn_name: String) -> bool:
	id = room_id
	var d: Variant = Game.load_json(DIR + room_id + ".json")
	if not d is Dictionary:
		return false
	data = d
	var layout: Array = data.get("layout", [])
	grid = Vector2i(str(layout[0]).length() if layout.size() > 0 else 0, layout.size())
	_build_tiles(layout)
	_add_fx(false)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	var ambient := float(data.get("ambient", 1.0))
	var cm := CanvasModulate.new()
	cm.color = Color(ambient, ambient, minf(1.0, ambient * 1.25))
	add_child(cm)
	_build_bounds()
	for e: Dictionary in data.get("entities", []):
		var ent := Entity.new()
		ent.setup(e)
		actors.add_child(ent)
		entities.append(ent)
	for l: Dictionary in data.get("lights", []):
		_add_light(l)
	_build_lamp_posts()
	player = Player.new()
	player.room = self
	actors.add_child(player)
	var sp: Array = data.get("spawns", {}).get(spawn_name, data.get("spawns", {}).get("default", [1, 1]))
	player.position = Vector2(float(sp[0]) * TILE + 8, float(sp[1]) * TILE + 12)
	player.face({"up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(str(sp[2]) if sp.size() > 2 else "", Vector2.DOWN))
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	_add_fx(true)
	_build_overlay()
	_refresh(true)
	_forget_lamps()
	for e in entities:
		e.armed = not e.rect.has_point(player.position)
	_update_camera()
	Game.flag_set.connect(_on_flags_changed)
	Game.flag_cleared.connect(_on_flags_changed)
	Game.light_changed.connect(_on_light_changed)
	DialogueRunner.room_command.connect(_on_room_command)
	return true


func _build_tiles(layout: Array) -> void:
	var info: Dictionary = Game.tilesets.get(str(data.get("tileset", "")), {})
	var names: Array = info.get("tiles", [])
	var solid: Array = info.get("solid", [])
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load(str(info.get("png", "res://assets/tiles/home_night.png")))
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var index := _tile_index
	_layout = layout
	var half := TILE / 2.0
	for i in names.size():
		var c := Vector2i(i % ATLAS_COLUMNS, i / ATLAS_COLUMNS)
		src.create_tile(c)
		index[names[i]] = c
		if names[i] in solid:
			var td := src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	tiles = TileMapLayer.new()
	tiles.tile_set = ts
	add_child(tiles)
	var legend: Dictionary = data.get("legend", {})
	for y in layout.size():
		var row := str(layout[y])
		for x in row.length():
			var tile_name := str(legend.get(row[x], ""))
			if index.has(tile_name):
				tiles.set_cell(Vector2i(x, y), 0, index[tile_name])


## Each lamp_post tile gets a 16x32 post on top. It shows its lit frame while the light on its
## tile is on.
func _build_lamp_posts() -> void:
	if not _tile_index.has("lamp_post"):
		return
	var tex: Texture2D = load("res://assets/sprites/lamp_post.png")
	for c in tiles.get_used_cells_by_id(0, _tile_index["lamp_post"]):
		var post := Sprite2D.new()
		post.texture = tex
		post.hframes = 2
		post.centered = false
		post.offset = Vector2(-8, -32)
		post.position = Vector2(c * TILE) + Vector2(8, TILE)
		actors.add_child(post)
		for lid: String in lights:
			if Vector2i((lights[lid] as PointLight2D).position / TILE) == c:
				_lamp_posts[post] = lights[lid]


func _build_bounds() -> void:
	var body := StaticBody2D.new()
	var size := Vector2(grid) * TILE
	for r: Rect2 in [Rect2(-16, -16, size.x + 32, 16), Rect2(-16, size.y, size.x + 32, 16),
			Rect2(-16, 0, 16, size.y), Rect2(size.x, 0, 16, size.y)]:
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		shape.shape = rs
		shape.position = r.get_center()
		body.add_child(shape)
	add_child(body)


func _add_light(l: Dictionary) -> void:
	var pl := PointLight2D.new()
	var radius := float(l.get("radius", 40))
	var warm := bool(Game.tuning.get("warm_light", true))
	pl.texture = light_texture(radius, false) if warm else load("res://assets/sprites/light_radial.png")
	pl.texture_scale = 1.0 if warm else radius * 2.0 / 64.0
	pl.color = Game.color(str(l.get("color", "lamp")))
	pl.energy = float(l.get("energy", 1.0))
	pl.position = Vector2(float(l.get("x", 0)) * TILE + 8, float(l.get("y", 0)) * TILE + 4)
	var lid := str(l.get("id", "light_%d" % lights.size()))
	pl.enabled = bool(Game.lights.get(lid, bool(l.get("on", true))))
	add_child(pl)
	lights[lid] = pl
	_light_base[lid] = pl.energy
	_light_scale[lid] = pl.texture_scale
	if _tile_index.has("shop_window_lit") and tiles.get_cell_atlas_coords(Vector2i(pl.position / TILE)) == _tile_index["shop_window_lit"]:
		_window_lights.append(lid)
	if warm and str(l.get("color", "lamp")) == "lamp":
		if _glow_clip == null:
			_glow_clip = Control.new()
			_glow_clip.size = Vector2(grid) * TILE
			_glow_clip.clip_contents = true
			_glow_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_glow_clip)
		var glow := Sprite2D.new()
		glow.texture = light_texture(radius, true)
		glow.position = pl.position
		glow.modulate = Color(pl.color.r, pl.color.g, pl.color.b * 0.2, 0.0)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		glow.material = m
		_glow_clip.add_child(glow)
		_glows[lid] = glow


## The light pool at its real size, so each pixel of it is one screen pixel: four bands, as in
## light_radial.png, with dithered edges. The glow copy fades faster toward the rim.
static func light_texture(radius: float, glow: bool) -> Texture2D:
	var size := int(radius) * 2 * (-1 if glow else 1)
	if not _light_tex.has(size):
		size = absi(size)
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var a := pow(maxf(0.0, 1.0 - Vector2(x + 0.5 - radius, y + 0.5 - radius).length() / radius), 0.8)
				var dither := (BAYER[(y & 3) * 4 + (x & 3)] / 16.0 - 0.5) * 0.7 - 0.15
				var level := clampf(ceilf(a * 4.0 + dither) / 4.0, 0.0, 1.0) if a > 0.0 else 0.0
				img.set_pixel(x, y, Color(1, 1, 1, pow(level, 1.6) if glow else level))
		_light_tex[-size if glow else size] = ImageTexture.create_from_image(img)
	return _light_tex[-absi(size) if glow else absi(size)]


func _add_fx(above: bool) -> void:
	var fx := RoomFx.new()
	fx.room = self
	fx.above = above
	add_child(fx)


## A lamp that was lit last night and not saved starts lit, then flickers out.
func _forget_lamps() -> void:
	var lost: Array = Game.last_forgotten.get("lamp", [])
	for e in entities:
		var lid := str(e.data.get("light", ""))
		if e.kind == "lamp" and lights.has(lid) and lost.has(str(e.data.get("id", ""))):
			lost.erase(str(e.data.get("id", "")))
			(lights[lid] as PointLight2D).enabled = true
			_wake[lid] = [-0.8, false]


func _switch_light(lid: String, on: bool, animate: bool = true) -> void:
	if not lights.has(lid):
		return
	var pl: PointLight2D = lights[lid]
	if on == (bool(_wake[lid][1]) if _wake.has(lid) else pl.enabled):
		return
	if animate:
		_wake[lid] = [0.0, on]
	else:
		pl.enabled = on


## x is the brightness and y is the size of a light, t seconds into flickering on or out.
static func _wake_state(t: float, on: bool) -> Vector2:
	if t < 0.0:
		return Vector2.ONE
	if on:
		if t < 0.08:
			return Vector2(0.5, 0.5)
		if t >= 0.3 and t < 0.4:
			return Vector2(0.7, 0.62)
		if t < 0.65:
			return Vector2.ZERO
		return Vector2(1.0, 0.45 + 0.55 * ease_out_back((t - 0.65) / (WAKE_ON - 0.65)))
	if t >= 0.1 and t < 0.24:
		return Vector2(0.6, 0.8)
	if t >= 0.4:
		return Vector2(0.35, 0.5)
	return Vector2.ZERO


static func ease_out_back(p: float) -> float:
	var q := clampf(p, 0.0, 1.0) - 1.0
	return 1.0 + 2.7 * q * q * q + 1.7 * q * q


func cells_of(tile_name: String) -> Array[Vector2i]:
	return tiles.get_used_cells_by_id(0, _tile_index[tile_name]) if _tile_index.has(tile_name) else []


## The pixels of one tile's art that have this palette colour, as offsets inside the tile.
func tile_pixels(tile_name: String, color_name: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _tile_index.has(tile_name):
		var img := (tiles.tile_set.get_source(0) as TileSetAtlasSource).texture.get_image()
		var c := Game.color(color_name)
		for y in TILE:
			for x in TILE:
				if img.get_pixelv(_tile_index[tile_name] * TILE + Vector2i(x, y)).is_equal_approx(c):
					out.append(Vector2i(x, y))
	return out


func lamp_posts() -> Dictionary:
	return _lamp_posts


func window_dip() -> bool:
	return sin(_time * 9.0) * sin(_time * 1.3) > 0.85


func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 2
	overlay.follow_viewport_enabled = true
	add_child(overlay)
	_marker = Sprite2D.new()
	_marker.texture = load("res://assets/sprites/marker.png")
	_marker.visible = false
	overlay.add_child(_marker)
	_hold_bg = ColorRect.new()
	_hold_bg.color = Game.color("ink")
	_hold_bg.size = Vector2(20, 4)
	_hold_bg.visible = false
	overlay.add_child(_hold_bg)
	_hold_fill = ColorRect.new()
	_hold_fill.color = Game.color("lamp")
	_hold_fill.size = Vector2(0, 2)
	_hold_bg.add_child(_hold_fill)
	_hold_fill.position = Vector2(1, 1)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", Game.color("lamp"))
	_hint.add_theme_color_override("font_outline_color", Game.color("ink"))
	_hint.add_theme_constant_override("outline_size", 2)
	_hint.visible = false
	overlay.add_child(_hint)


## Called after the fade-in: the room's on_enter dialogue.
func enter() -> void:
	var on_enter := str(data.get("on_enter", ""))
	if on_enter != "":
		DialogueRunner.run(on_enter)


func find_target(p: Vector2, facing: Vector2) -> Entity:
	var best: Entity = null
	var best_d := INF
	var reach := float(Game.tuning.get("interact_range", 12))
	var all: Array[Entity] = entities.duplicate()
	if follower:
		all.append(follower)
	for e in all:
		if not e.active or not e.interactive():
			continue
		var r := e.rect
		var cp := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var dist := p.distance_to(cp)
		if dist > reach:
			continue
		if dist > 1.0 and (cp - p).normalized().dot(facing) < 0.5:
			continue
		if dist < best_d:
			best = e
			best_d = dist
	return best


func advance_hold(e: Entity, delta: float) -> void:
	if not e.active:
		return
	var minutes := int(e.data.get("minutes", 2))
	e.progress = minf(1.0, e.progress + delta / float(e.data.get("seconds", 2.0)))
	while e.spent < minutes and e.progress >= float(e.spent + 1) / float(minutes + 1):
		e.spent += 1
		NightClock.add(1)
		AudioBus.sfx("tick")
	if e.progress >= 1.0:
		while e.spent < minutes:
			e.spent += 1
			NightClock.add(1)
		e.progress = 0.0
		e.spent = 0
		AudioBus.sfx("whoosh")
		Game.playtest("hold_done", {"x": e.data.get("x"), "y": e.data.get("y"), "minutes": minutes})
		if e.data.has("light"):
			Game.set_light(str(e.data["light"]), true)
		if e.data.has("flag"):
			Game.set_flag(str(e.data["flag"]))
		DialogueRunner.run(e.dialogue)


func interact(e: Entity) -> void:
	if e.kind == "lamp":
		_use_lamp(e)
	elif e.kind == "encounter" and not Game.has_flag("friend_" + str(e.data.get("worker", ""))):
		_encounter(e)
	else:
		DialogueRunner.run(str(e.data.get("chat", e.dialogue)))


## The approach line, the fight, then the line for how it ended. A spared worker leaves for
## the rest of the night; a finished one is gone, and _refresh hides both.
func _encounter(e: Entity) -> void:
	var wid := str(e.data.get("worker", ""))
	e.armed = false
	e.face_toward(player.position)
	var angry := Game.has_flag("enemy_" + wid) and e.data.has("approach_enemy")
	await DialogueRunner.run(str(e.data.get("approach_enemy" if angry else "approach", "")))
	if Game.night_over:
		return
	var outcome: String = await Game.start_battle(wid)
	if Game.night_over:
		return
	if outcome == "spared":
		Game.set_flag(Game.TONIGHT + "left_" + wid)
	DialogueRunner.run(str(e.data.get("after", {}).get(outcome, "")))


## Workers stand at their post every night unless gone, or gone home after being spared.
## A worker that does not respawn leaves for good once the fight is resolved either way.
func _present(e: Entity) -> bool:
	var w := str(e.data.get("worker", ""))
	if Game.has_flag("gone_" + w) or Game.has_flag(Game.TONIGHT + "left_" + w):
		return false
	return str(e.data.get("respawn", "nightly")) != "never" or not (Game.has_flag("friend_" + w) or Game.has_flag("enemy_" + w))


## A lit lamp offers a save. A dark one is lit by Wick, or by itself when "wick" is false.
func _use_lamp(e: Entity) -> void:
	var lid := str(e.data.get("id", ""))
	var needs_wick := bool(e.data.get("wick", true))
	if Game.has_flag("lamp_" + lid):
		DialogueRunner.run("lamp_save")
	elif needs_wick and not Game.has_flag("wick_joined"):
		DialogueRunner.run("lamp_dark")
	else:
		NightClock.spend("lamp")
		AudioBus.sfx("whoosh")
		Game.playtest("lamp_lit", {"id": lid})
		Game.set_flag("lamp_" + lid)
		DialogueRunner.run("lamp_lit_wick" if needs_wick else "lamp_lit")


## A false wall shows its gap tile while the flashlight beam covers it, or while Tadzio stands
## in it, and the room's own wall tile the rest of the time. Only the gap tile is walkable.
func _update_false_walls() -> void:
	var origin := player.position + player.flashlight.position
	for e in entities:
		if e.kind != "false_wall" or not e.active:
			continue
		var c := Vector2i(int(e.data.get("x", 0)), int(e.data.get("y", 0)))
		var v := e.rect.get_center() - origin
		var lit := player.flashlight.enabled and v.length() <= BEAM_LENGTH and absf(v.angle_to(player.facing)) <= deg_to_rad(BEAM_HALF_ANGLE)
		var open := lit or e.rect.grow(4).has_point(player.position)
		var name := str(e.data.get("tile", "")) if open else str(data.get("legend", {}).get(str(_layout[c.y])[c.x], ""))
		if _tile_index.has(name) and tiles.get_cell_atlas_coords(c) != _tile_index[name]:
			tiles.set_cell(c, 0, _tile_index[name])


func _physics_process(_delta: float) -> void:
	if player == null or Game.busy or Game.in_battle or Game.night_over or DialogueRunner.is_active():
		return
	var p := player.position
	for e in entities:
		if e.active and e.kind == "encounter" and not Game.has_flag("friend_" + str(e.data.get("worker", ""))):
			if e.position.distance_to(p) > float(e.data.get("radius", 2)) * TILE:
				e.armed = true
			elif e.armed:
				_encounter(e)
				return
			continue
		if not e.active or not e.kind in ["door", "trigger", "false_wall"]:
			continue
		if not e.rect.has_point(p):
			e.armed = true
			continue
		if not e.armed:
			continue
		e.armed = false
		if e.kind != "trigger":
			var minutes := int(e.data.get("minutes", NightClock.cost("door")))
			Game.go_to_room(str(e.data.get("to", "")), str(e.data.get("spawn", "default")), minutes, e.dialogue)
		else:
			e.fired = true
			var flag := str(e.data.get("flag", ""))
			if flag != "":
				Game.set_flag(flag)
			_refresh()
			DialogueRunner.run(e.dialogue)
		return


func _process(delta: float) -> void:
	_time += delta
	for lid: String in lights:
		var pl: PointLight2D = lights[lid]
		var state := Vector2.ONE
		if _wake.has(lid):
			var w: Array = _wake[lid]
			w[0] = float(w[0]) + delta
			if float(w[0]) >= (WAKE_ON if w[1] else WAKE_OFF):
				pl.enabled = w[1]
				_wake.erase(lid)
			else:
				state = _wake_state(w[0], w[1])
				pl.enabled = state.x > 0.0
		if lid in _window_lights and window_dip():
			state.x *= 0.9
		pl.energy = float(_light_base[lid]) * state.x * (1.0 + 0.02 * sin(_time * 7.0 + pl.position.x) * sin(_time * 2.3))
		pl.texture_scale = float(_light_scale[lid]) * state.y
		if _glows.has(lid):
			var glow: Sprite2D = _glows[lid]
			glow.visible = pl.enabled
			glow.scale = Vector2.ONE * state.y
			glow.modulate.a = GLOW_ALPHA * pl.energy
	if follower:
		follower.scared = entities.any(func(e: Entity) -> bool:
			return e.active and e.kind == "encounter" and not Game.has_flag("friend_" + str(e.data.get("worker", ""))) and e.position.distance_to(follower.position) < 3.0 * TILE)
	for post: Sprite2D in _lamp_posts:
		post.frame = 1 if (_lamp_posts[post] as PointLight2D).enabled else 0
	_update_camera()
	_update_overlay()
	if player:
		_update_false_walls()
	if _shake_t > 0.0:
		_shake_t -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amp if _shake_t > 0 else Vector2.ZERO


func _update_camera() -> void:
	if player == null:
		return
	var size := Vector2(grid) * TILE
	var c := Vector2.ZERO
	for axis in 2:
		if size[axis] <= VIEW[axis]:
			c[axis] = size[axis] / 2.0
		else:
			c[axis] = clampf(player.position[axis] - (8.0 if axis == 1 else 0.0), VIEW[axis] / 2.0, size[axis] - VIEW[axis] / 2.0)
	camera.position = c.round()


func _update_overlay() -> void:
	var t := player.target if player else null
	var show := t != null and not DialogueRunner.is_active() and not Game.busy
	_marker.visible = show
	if show:
		_marker.position = (t.top_point() + Vector2(0, -3 + roundf(sin(_time * 5.0)))).round()
	var holding := show and t.kind == "hold"
	_hold_bg.visible = holding and t.progress > 0.0
	_hint.visible = holding and t.progress == 0.0
	if holding:
		_hold_bg.position = (player.position + Vector2(-10, -40)).round()
		_hold_fill.size.x = 18.0 * t.progress
		_hint.text = Game.text(str(t.data.get("hint", "hold_hint")))
		_hint.position = (player.position + Vector2(-_hint.get_minimum_size().x / 2.0, -46)).round()


## at_build: Wick starts behind Tadzio. Later (he joins mid-room): he starts where his NPC stood.
func _refresh(at_build: bool = false) -> void:
	var legend: Dictionary = data.get("legend", {})
	for o: Dictionary in data.get("overrides", []):
		var c := Vector2i(int(o.get("x", 0)), int(o.get("y", 0)))
		var name := str(o.get("tile", "")) if Game.cond_ok(o) else str(legend.get(str(_layout[c.y])[c.x], ""))
		if _tile_index.has(name):
			tiles.set_cell(c, 0, _tile_index[name])
	for e in entities:
		var ok := Game.cond_ok(e.data)
		if e.kind == "encounter":
			ok = ok and _present(e)
			_switch_light(str(e.data.get("light", "")), ok, not at_build)
		if e.kind == "trigger" and bool(e.data.get("once", false)):
			var flag := str(e.data.get("flag", ""))
			ok = ok and not e.fired and (flag == "" or not Game.has_flag(flag))
		if e.active != ok:
			e.set_active(ok)
		if e.kind == "lamp":
			_switch_light(str(e.data.get("light", "")), Game.has_flag("lamp_" + str(e.data.get("id", ""))), not at_build)
	var wants_follower := Game.has_flag("wick_joined") and bool(data.get("companion", false))
	if wants_follower and follower == null:
		var start := player.position - player.facing * float(Game.tuning.get("follow_distance", 24))
		var npc := entity_by_id("wick")
		if npc and not at_build:
			start = npc.position
		follower = Follower.new()
		follower.setup_follower("wick", str(data.get("companion_dialogue", "wick_chat")), start, player.position)
		actors.add_child(follower)
	elif not wants_follower and follower:
		follower.queue_free()
		follower = null


func entity_by_id(eid: String) -> Entity:
	if eid == "wick" and follower:
		return follower
	for e in entities:
		if str(e.data.get("id", e.data.get("worker", ""))) == eid:
			return e
	return null


func _on_flags_changed(_name: String) -> void:
	_refresh()


func _on_light_changed(lid: String, on: bool) -> void:
	_switch_light(lid, on)


func _on_room_command(cmd: Dictionary) -> void:
	match str(cmd.get("cmd", "")):
		"move":
			var eid := str(cmd.get("entity", ""))
			var target: Node2D = player if eid == "player" else entity_by_id(eid)
			if target == null:
				Game.report("dialogue", "move", "no entity \"%s\" in room %s" % [eid, id])
				return
			var delta := Vector2(float(cmd.get("dx", 0)), float(cmd.get("dy", 0))) * TILE
			var seconds := (absf(delta.x) + absf(delta.y)) / float(cmd.get("speed", Game.tuning.get("move_speed", 40)))
			if target is Entity:
				if bool(cmd.get("enter", false)):
					target.position -= delta
				(target as Entity).walk_to(target.position + delta, seconds)
			else:
				player.face(delta.normalized().snapped(Vector2.ONE))
				create_tween().tween_property(player, "position", player.position + delta, seconds)
		"face":
			var eid := str(cmd.get("entity", ""))
			var dir := str(cmd.get("dir", "down"))
			if eid == "player":
				player.face({"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(dir, Vector2.DOWN))
			elif entity_by_id(eid):
				entity_by_id(eid).face(dir)
		"shake":
			_shake_amp = float(cmd.get("strength", 2))
			_shake_t = float(cmd.get("seconds", 0.4))
