class_name NightAmbient
extends Node2D

## Vaga-lumes de ambiente: pontinhos de luz que derivam devagar e piscam.

const COUNT := 18
const HALO := Color(0.847, 1.0, 0.478)
const CORE := Color(0.956, 1.0, 0.753)

var canvas_size := Vector2(1920, 1080)

var _seeds: Array = []
var _time := 0.0

func _ready() -> void:
	for i in COUNT:
		_seeds.append({
			"seed": randf() * 100.0,
			"x": randf(),
			"y": 0.1 + randf() * 0.7,
			"speed": 0.4 + randf() * 0.6,
			"phase": randf() * TAU,
		})

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	for data in _seeds:
		var t: float = _time * data["speed"] + data["seed"]
		var dx: float = sin(t * 0.7) * 0.04 + sin(t * 1.9) * 0.01
		var dy: float = cos(t * 0.5) * 0.03
		var blink: float = 0.5 + 0.5 * sin(_time * 2.2 + data["phase"])
		var alpha: float = 0.15 + 0.55 * blink * blink
		var point := Vector2((data["x"] + dx) * canvas_size.x, (data["y"] + dy) * canvas_size.y)
		draw_circle(point, 9.0, Color(HALO, alpha * 0.35))
		draw_circle(point, 3.5, Color(CORE, alpha))
