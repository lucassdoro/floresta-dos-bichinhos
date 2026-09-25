class_name SlashTrail
extends Node2D

## Rastro do dedo: dois Line2D (brilho + nucleo) que afinam e esmaecem pro
## rabo (width_curve + gradient no inspector). Pontos suavizados em Catmull-Rom.

const MAX_POINTS := 12
const POINT_LIFE := 0.22
const SUBDIVISIONS := 4

var _points: Array[Vector2] = []
var _ages: Array[float] = []

@onready var _lines: Array[Line2D] = [$Glow, $Core]

func add_point(point: Vector2) -> void:
	_points.append(point)
	_ages.append(0.0)
	if _points.size() > MAX_POINTS:
		_points.pop_front()
		_ages.pop_front()

func clear() -> void:
	_points.clear()
	_ages.clear()
	_apply(PackedVector2Array())

func _process(delta: float) -> void:
	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] > POINT_LIFE:
		_ages.pop_front()
		_points.pop_front()
	_apply(_smoothed())

func _apply(points: PackedVector2Array) -> void:
	for line in _lines:
		line.points = points

func _smoothed() -> PackedVector2Array:
	var result := PackedVector2Array()
	var count := _points.size()
	if count < 2:
		return result
	for i in count - 1:
		var before := _points[maxi(i - 1, 0)]
		var after := _points[mini(i + 2, count - 1)]
		for step in SUBDIVISIONS:
			result.append(_points[i].cubic_interpolate(_points[i + 1], before, after, float(step) / SUBDIVISIONS))
	result.append(_points[count - 1])
	return result
