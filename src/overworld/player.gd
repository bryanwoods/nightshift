class_name Player
extends CharacterBody2D
## Tadzio in the overworld: 4-direction movement, interact, hold-to-help, flashlight.

const ROWS := {Vector2.DOWN: 0, Vector2.UP: 1, Vector2.LEFT: 2, Vector2.RIGHT: 3}

var room: Room
var facing: Vector2 = Vector2.DOWN
var target: Entity
var holding: bool = false
var sprite: Sprite2D
var flashlight: PointLight2D
var speed: float = 60.0

var _anim_t: float = 0.0


func _ready() -> void:
	speed = float(Game.tuning.get("player_speed", 60))
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/tadzio.png")
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.centered = false
	sprite.offset = Vector2(-8, -30)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 6)
	shape.shape = r
	shape.position = Vector2(0, -3)
	add_child(shape)
	flashlight = PointLight2D.new()
	flashlight.texture = load("res://assets/sprites/light_cone.png")
	flashlight.offset = Vector2(32, 0)
	flashlight.position = Vector2(0, -10)
	flashlight.color = Game.color("moon")
	flashlight.energy = 0.8
	add_child(flashlight)
	_update_flashlight()


func locked() -> bool:
	return DialogueRunner.is_active() or Game.busy or Game.in_battle or Game.night_over or Game.overlay_open


func face(dir: Vector2) -> void:
	facing = dir
	_update_flashlight()
	sprite.frame = int(ROWS.get(facing, 0)) * 4


func _physics_process(delta: float) -> void:
	var is_locked := locked()
	var dir := Vector2.ZERO
	if not is_locked and not holding:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if v != Vector2.ZERO:
			dir = Vector2(signf(v.x), 0) if absf(v.x) > absf(v.y) else Vector2(0, signf(v.y))
			facing = dir
	velocity = dir * speed
	move_and_slide()
	_animate(delta, dir != Vector2.ZERO)
	if room.follower:
		room.follower.follow(position)
	target = null if is_locked else room.find_target(position, facing)
	holding = false
	if target == null:
		return
	if target.kind == "hold":
		if Input.is_action_pressed("confirm") and not DialogueRunner.just_ended():
			holding = true
			room.advance_hold(target, delta)
	elif Input.is_action_just_pressed("confirm") and not DialogueRunner.just_ended():
		if target.kind in ["npc", "encounter"]:
			target.face_toward(position)
		room.interact(target)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not locked() and room.data.get("flashlight", true):
		Game.flashlight = not Game.flashlight
		AudioBus.sfx("cursor")
		_update_flashlight()


func _animate(delta: float, moving: bool) -> void:
	if moving:
		_anim_t += delta * 8.0
	else:
		_anim_t = 0.0
	sprite.frame = int(ROWS.get(facing, 0)) * 4 + (int(_anim_t) % 4 if moving else 0)
	_update_flashlight()


func _update_flashlight() -> void:
	if flashlight == null:
		return
	flashlight.enabled = Game.flashlight and room != null and bool(room.data.get("flashlight", true))
	flashlight.rotation = facing.angle()
