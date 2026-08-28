class_name FireflyGuide
extends Node2D

## O vaga-lume guia: plana ate o alvo com suavizacao, grava a trilha por
## distancia pros filhotes seguirem e desenha glow + corpinho em codigo.

const GLOW_RADIUS := 120.0
const BODY_SCALE := 1.8
const SMOOTHING := 6.0
const GLOW_COLOR := Color(1.0, 0.886, 0.478)
const BODY_COLOR := Color(0.353, 0.227, 0.102)
const WING_COLOR := Color(0.91, 0.965, 1.0, 0.8)

## Trilha gravada por distancia, nao por frame: independe da taxa de quadros.
class Trail:
	var min_step := 6.0
	var max_points := 400
	var points: Array[Vector2] = []

	func push(point: Vector2) -> void:
		if not points.is_empty() and points.back().distance_to(point) < min_step:
			return
		points.append(point)
		if points.size() > max_points:
			points.pop_front()

	func clear() -> void:
		points.clear()

	## Ponto a `distance` atras da cabeca medindo ao longo da trilha.
	func point_behind(distance: float) -> Variant:
		if points.is_empty():
			return null
		var remaining := distance
		for i in range(points.size() - 1, 0, -1):
			var from := points[i]
			var to := points[i - 1]
			var segment := from.distance_to(to)
			if segment >= remaining:
				return from + (to - from) * (remaining / segment)
			remaining -= segment
		return points[0]

var target := Vector2.ZERO
var trail := Trail.new()

var _time := 0.0
var _facing := 1.0

## Coloca sem planar (inicio da fase) e recomeca a trilha.
func snap_to(point: Vector2) -> void:
	position = point
	target = point
	trail.clear()
	trail.push(position)

func _process(delta: float) -> void:
	_time += delta
	var delta_pos := target - position
	if delta_pos.length_squared() >= 0.25:
		if absf(delta_pos.x) > 1.0:
			_facing = -1.0 if delta_pos.x < 0.0 else 1.0
		position += delta_pos * (1.0 - exp(-SMOOTHING * delta))
		trail.push(position)
	queue_redraw()

func _draw() -> void:
	var center := Vector2(0, sin(_time * 7.0) * 4.0)
	var pulse := 0.85 + 0.15 * sin(_time * 5.0)
	var radius := GLOW_RADIUS * pulse
	# glow radial: aneis concentricos com alpha caindo
	for i in range(6, 0, -1):
		var t := float(i) / 6.0
		draw_circle(center, radius * t, Color(GLOW_COLOR, 0.7 * (1.0 - t) * (1.0 - t) + 0.04))
	var flap := 0.6 + 0.4 * absf(sin(_time * 40.0))
	draw_set_transform(center, 0.0, Vector2(_facing * BODY_SCALE, BODY_SCALE))
	for x in [-6.0, 6.0]:
		draw_set_transform(center + Vector2(x * _facing * BODY_SCALE, -9.0 * BODY_SCALE), 0.0, Vector2(_facing * BODY_SCALE, BODY_SCALE * flap))
		draw_circle(Vector2.ZERO, 9.0, WING_COLOR)
	draw_set_transform(center, 0.0, Vector2(_facing * BODY_SCALE, BODY_SCALE))
	draw_set_transform(center, 0.0, Vector2(_facing * BODY_SCALE, BODY_SCALE * 0.6))
	draw_circle(Vector2.ZERO, 10.0, BODY_COLOR)
	draw_set_transform(center, 0.0, Vector2(_facing * BODY_SCALE, BODY_SCALE))
	draw_circle(Vector2(-10, 0), 5.0, GLOW_COLOR)
	draw_set_transform_matrix(Transform2D())
