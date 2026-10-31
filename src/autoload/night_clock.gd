extends Node
## The hour from 2:00 to 3:00. Minutes pass only on actions, never in real time.

signal minute_passed(minute: int)
signal hour_ended

const HOUR: int = 60

## -1 means the clock has not started: it reads 1:59.
var minute: int = -1
var started: bool = false
var paused: bool = false
var costs: Dictionary = {}


func _ready() -> void:
	costs = Game.tuning.get("costs", {})


func reset() -> void:
	minute = -1
	started = false
	paused = false
	minute_passed.emit(minute)


func cost(kind: String) -> int:
	return int(costs.get(kind, 0))


func spend(kind: String) -> void:
	add(cost(kind))


func add(n: int) -> void:
	if not started or paused or n <= 0:
		return
	set_minute(minute + n)


func set_minute(m: int) -> void:
	if paused:
		return
	started = true
	minute = clampi(m, 0, HOUR)
	minute_passed.emit(minute)
	if minute >= HOUR:
		paused = true
		hour_ended.emit()


func text() -> String:
	if not started:
		return "1:59"
	if minute >= HOUR:
		return "3:00"
	return "2:%02d" % minute
