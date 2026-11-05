class_name Room
extends Node2D
## Builds one room from data/rooms/<id>.json: tiles from the ASCII layout, entities, lights,
## darkness and music. Then runs doors, triggers, hold spots, lamps and the interact marker.

const TILE: int = 16
const DIR := "res://data/rooms/"
const VIEW := Vector2(320, 180)
const ATLAS_COLUMNS := 8

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

var _light_base: Dictionary = {}
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
	player = Player.new()
	player.room = self
	actors.add_child(player)
	var sp: Array = data.get("spawns", {}).get(spawn_name, data.get("spawns", {}).get("default", [1, 1]))
	player.position = Vector2(float(sp[0]) * TILE + 8, float(sp[1]) * TILE + 12)
	player.face({"up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(str(sp[2]) if sp.size() > 2 else "", Vector2.DOWN))
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	_build_overlay()
	_refresh(true)
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
	pl.texture = load("res://assets/sprites/light_radial.png")
	pl.texture_scale = float(l.get("radius", 40)) * 2.0 / 64.0
	pl.color = Game.color(str(l.get("color", "lamp")))
	pl.energy = float(l.get("energy", 1.0))
	pl.position = Vector2(float(l.get("x", 0)) * TILE + 8, float(l.get("y", 0)) * TILE + 4)
	var lid := str(l.get("id", "light_%d" % lights.size()))
	pl.enabled = bool(Game.lights.get(lid, bool(l.get("on", true))))
	add_child(pl)
	lights[lid] = pl
	_light_base[lid] = pl.energy


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
	else:
		DialogueRunner.run(e.dialogue)


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


func _physics_process(_delta: float) -> void:
	if player == null or Game.busy or Game.in_battle or Game.night_over or DialogueRunner.is_active():
		return
	var p := player.position
	for e in entities:
		if not e.active or not (e.kind == "door" or e.kind == "trigger"):
			continue
		if not e.rect.has_point(p):
			e.armed = true
			continue
		if not e.armed:
			continue
		e.armed = false
		if e.kind == "door":
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
		pl.energy = float(_light_base[lid]) * (1.0 + 0.02 * sin(_time * 7.0 + pl.position.x) * sin(_time * 2.3))
	_update_camera()
	_update_overlay()
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
		if e.kind == "trigger" and bool(e.data.get("once", false)):
			var flag := str(e.data.get("flag", ""))
			ok = ok and not e.fired and (flag == "" or not Game.has_flag(flag))
		if e.active != ok:
			e.set_active(ok)
		if e.kind == "lamp" and lights.has(str(e.data.get("light", ""))):
			(lights[e.data["light"]] as PointLight2D).enabled = Game.has_flag("lamp_" + str(e.data.get("id", "")))
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
		if str(e.data.get("id", "")) == eid:
			return e
	return null


func _on_flags_changed(_name: String) -> void:
	_refresh()


func _on_light_changed(lid: String, on: bool) -> void:
	if lights.has(lid):
		(lights[lid] as PointLight2D).enabled = on


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
