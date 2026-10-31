class_name Entity
extends Node2D
## One thing in a room: an npc, an inspect spot, a door, a trigger, or a hold spot.
## Positions in room files are tile coordinates. NPC positions are their feet.

const ROWS := {"down": 0, "up": 1, "left": 2, "right": 3}
const KINDS: PackedStringArray = ["npc", "inspect", "door", "trigger", "hold"]

var kind: String = ""
var data: Dictionary = {}
var rect: Rect2
var dialogue: String = ""
var active: bool = true
var armed: bool = false
var fired: bool = false
var progress: float = 0.0
var spent: int = 0
var sprite: Sprite2D
var body: StaticBody2D
var facing: String = "down"
var moving: bool = false
var frame_size: Vector2i = Vector2i(16, 32)
var idle_frames: int = 1

var _anim_t: float = 0.0


func setup(d: Dictionary) -> void:
	data = d
	kind = str(d.get("type", ""))
	dialogue = str(d.get("dialogue", ""))
	var tile := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
	if kind == "npc":
		position = tile * Room.TILE + Vector2(8, 14)
		make_sprite(str(d.get("sprite", d.get("id", ""))))
		idle_frames = int(d.get("idle_frames", 1))
		face(str(d.get("facing", "down")))
		body = StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(maxf(12, frame_size.x - 4), 6)
		shape.shape = r
		shape.position = Vector2(0, -3)
		body.add_child(shape)
		add_child(body)
	else:
		position = tile * Room.TILE
	update_rect()


func update_rect() -> void:
	if kind == "npc":
		var w := maxf(14.0, frame_size.x - 2.0)
		rect = Rect2(position + Vector2(-w / 2, -8), Vector2(w, 9))
	else:
		rect = Rect2(position, Vector2(float(data.get("w", 1)), float(data.get("h", 1))) * Room.TILE)


func make_sprite(sheet: String) -> void:
	var path := "res://assets/sprites/%s.png" % sheet
	if not ResourceLoader.exists(path):
		Game.report("sprite", sheet, "no file assets/sprites/%s.png" % sheet)
		return
	var tex: Texture2D = load(path)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.centered = false
	frame_size = Vector2i(tex.get_width() / 4, tex.get_height() / 4)
	sprite.offset = Vector2(-frame_size.x / 2.0, -frame_size.y + 2)
	add_child(sprite)


func interactive() -> bool:
	return kind in ["npc", "inspect", "hold"]


func top_point() -> Vector2:
	if kind == "npc":
		return position - Vector2(0, frame_size.y + 1)
	return Vector2(rect.get_center().x, rect.position.y - 2)


func face(dir: String) -> void:
	if ROWS.has(dir):
		facing = dir
	_apply_frame(0)


func face_toward(p: Vector2) -> void:
	var d := p - position
	if absf(d.x) > absf(d.y):
		face("right" if d.x > 0 else "left")
	else:
		face("down" if d.y > 0 else "up")


func face_vector(v: Vector2) -> void:
	if v == Vector2.ZERO:
		return
	if absf(v.x) > absf(v.y):
		facing = "right" if v.x > 0 else "left"
	else:
		facing = "down" if v.y > 0 else "up"


func set_active(on: bool) -> void:
	active = on
	visible = on
	if body:
		for c in body.get_children():
			(c as CollisionShape2D).set_deferred("disabled", not on)


func walk_to(target: Vector2, seconds: float) -> void:
	face_vector(target - position)
	moving = true
	var tw := create_tween()
	tw.tween_property(self, "position", target, seconds)
	await tw.finished
	moving = false
	update_rect()
	_apply_frame(0)


func _process(delta: float) -> void:
	if sprite == null:
		return
	if moving:
		_anim_t += delta * 8.0
		_apply_frame(int(_anim_t) % 4)
	elif idle_frames > 1:
		_anim_t += delta * 1.5
		_apply_frame(int(_anim_t) % idle_frames)


func _apply_frame(f: int) -> void:
	if sprite:
		sprite.frame = int(ROWS.get(facing, 0)) * 4 + f
