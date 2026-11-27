class_name PushBlocks
extends Node
## Pushing crates in a room. Walk into a block and keep walking, and it slides one tile if the
## tile behind it is open. The room's "puzzles" list names plates ([x, y] each) and a flag: when
## a block sits on every plate of a puzzle, the flag is set and its dialogue plays.

const PUSH_DELAY := 0.15
const SLIDE_SECONDS := 0.18

var room: Room
var _push_t: float = 0.0
var _bump_t: float = 0.0


func _physics_process(delta: float) -> void:
	_bump_t = maxf(0.0, _bump_t - delta)
	var p := room.player
	var dir := p.facing
	if p.locked() or Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO:
		_push_t = 0.0
		return
	var probe := p.position + Vector2(0, -3) + dir * 7.0
	var cell := Vector2i((probe / Room.TILE).floor())
	var b := _block_at(cell)
	if b == null or b.moving:
		_push_t = 0.0
		return
	var center := b.position + Vector2(8, 8)
	var off := (p.position + Vector2(0, -3) - center) * Vector2(absf(dir.y), absf(dir.x))
	if off.length() > 6.0:
		return
	_push_t += delta
	if _push_t < PUSH_DELAY:
		return
	_push_t = 0.0
	var to := cell + Vector2i(dir)
	if not _open(to):
		if _bump_t <= 0.0:
			AudioBus.sfx("block", 1.0, -6.0)
			_bump_t = 0.4
		return
	_slide(b, to)


func _slide(b: Entity, to: Vector2i) -> void:
	b.data["x"] = to.x
	b.data["y"] = to.y
	b.moving = true
	AudioBus.sfx("step_ok", 0.7, -4.0)
	var tw := b.create_tween()
	tw.tween_property(b, "position", Vector2(to) * Room.TILE, SLIDE_SECONDS)
	await tw.finished
	b.moving = false
	b.update_rect()
	_check()


func _block_at(cell: Vector2i) -> Entity:
	for e in room.entities:
		if e.kind == "block" and e.active and Vector2i(int(e.data["x"]), int(e.data["y"])) == cell:
			return e
	return null


func _open(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= room.grid.x or cell.y >= room.grid.y:
		return false
	var td := room.tiles.get_cell_tile_data(cell)
	if td == null or td.get_collision_polygons_count(0) > 0 or _block_at(cell):
		return false
	var mid := (Vector2(cell) + Vector2(0.5, 0.5)) * Room.TILE
	for e in room.entities:
		if e.active and e.kind in ["npc", "encounter", "door", "false_wall"] and e.rect.has_point(mid):
			return false
	return true


func _check() -> void:
	var all_plates: Array[Vector2i] = []
	for pz: Dictionary in room.data.get("puzzles", []):
		var plates: Array[Vector2i] = []
		for c: Array in pz.get("plates", []):
			plates.append(Vector2i(int(c[0]), int(c[1])))
		all_plates.append_array(plates)
		var covered := plates.filter(func(c: Vector2i) -> bool: return _block_at(c) != null).size()
		var flag := str(pz.get("flag", ""))
		if covered == plates.size() and flag != "" and not Game.has_flag(flag):
			AudioBus.sfx("satisfied")
			Game.set_flag(flag)
			DialogueRunner.run(str(pz.get("dialogue", "")))
	for e in room.entities:
		if e.kind == "block" and e.sprite:
			var on := Vector2i(int(e.data["x"]), int(e.data["y"])) in all_plates
			if on and e.sprite.modulate == Color.WHITE:
				AudioBus.sfx("chime", 1.2, -6.0)
			e.sprite.modulate = Color(1.25, 1.15, 0.8) if on else Color.WHITE


func reset() -> void:
	for e in room.entities:
		if e.kind == "block":
			if not e.data.has("x0"):
				continue
			e.data["x"] = e.data["x0"]
			e.data["y"] = e.data["y0"]
			e.position = Vector2(float(e.data["x"]), float(e.data["y"])) * Room.TILE
			e.sprite.modulate = Color.WHITE
			e.update_rect()


func _ready() -> void:
	for e in room.entities:
		if e.kind == "block":
			e.data["x0"] = e.data["x"]
			e.data["y0"] = e.data["y"]
