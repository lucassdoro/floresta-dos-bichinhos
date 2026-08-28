class_name SlashTrail
extends Node2D

## Rastro do dedo: linha branca com brilho que afina pro rabo e esmaece.

const MAX_POINTS := 12
const POINT_LIFE := 0.22
const HEAD_WIDTH := 26.0
const TAIL_WIDTH := 4.0

var _points: Array[Vector2] = []
var _ages: Array[float] = []

func add_point(point: Vector2) -> void:
	_points.append(point)
	_ages.append(0.0)
	if _points.size() > MAX_POINTS:
		_points.pop_front()
		_ages.pop_front()

func clear() -> void:
	_points.clear()
	_ages.clear()
	queue_redraw()

func _process(delta: float) -> void:
	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] > POINT_LIFE:
		_ages.pop_front()
		_points.pop_front()
	queue_redraw()

func _draw() -> void:
	if _points.size() < 2:
		return
	for i in range(1, _points.size()):
		var t := float(i) / (_points.size() - 1)
		var fade := clampf(1.0 - _ages[i] / POINT_LIFE, 0.0, 1.0)
		var width := TAIL_WIDTH + (HEAD_WIDTH - TAIL_WIDTH) * t
		draw_line(_points[i - 1], _points[i], Color(1, 1, 1, 0.25 * fade), width * 2.0)
		draw_line(_points[i - 1], _points[i], Color(1, 1, 1, 0.95 * fade), width)
