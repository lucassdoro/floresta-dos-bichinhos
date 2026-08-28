class_name Fireworks
extends Node2D

## Fogos da festa final: foguetes sobem com rastro e estouram em sparkles
## coloridos. start() dispara a sequencia, que para sozinha.

const DURATION := 3.5
const LAUNCH_INTERVAL := 0.35
const RISE_DURATION := 0.9
const PALETTE := [
	Color(1.0, 0.36, 0.54), Color(1.0, 0.835, 0.29), Color(0.43, 0.906, 1.0),
	Color(0.627, 1.0, 0.43), Color(0.77, 0.55, 1.0),
]
const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")
const EXPLOSION_SFX := preload("res://assets/audio/SFX/explosion.wav")

var canvas_size := Vector2(1920, 1080)

var _rockets: Array = []
var _elapsed := -1.0
var _since_launch := 0.0

func start() -> void:
	_elapsed = 0.0
	_since_launch = LAUNCH_INTERVAL

func _process(delta: float) -> void:
	if _elapsed >= 0.0:
		_elapsed += delta
		_since_launch += delta
		if _since_launch >= LAUNCH_INTERVAL:
			_since_launch = 0.0
			_launch()
		if _elapsed >= DURATION:
			_elapsed = -1.0
	for rocket in _rockets:
		rocket["t"] += delta / RISE_DURATION
	for rocket in _rockets.filter(func(r: Dictionary) -> bool: return r["t"] >= 1.0):
		_rockets.erase(rocket)
		_burst(rocket)
	queue_redraw()

func _launch() -> void:
	var x := canvas_size.x * randf_range(0.2, 0.8)
	var top := canvas_size.y * randf_range(0.12, 0.42)
	_rockets.append({
		"start": Vector2(x + randf_range(-100, 100), canvas_size.y),
		"end": Vector2(x, top),
		"color": PALETTE[randi() % PALETTE.size()],
		"t": 0.0,
	})

func _burst(rocket: Dictionary) -> void:
	var burst := SPARKLE_BURST.instantiate()
	add_child(burst)
	burst.burst(get_global_transform() * rocket["end"], rocket["color"], 24, 90.0)
	Audio.play_sfx(EXPLOSION_SFX)

func _draw() -> void:
	for rocket in _rockets:
		var left: float = 1.0 - clampf(rocket["t"], 0.0, 1.0)
		var eased := 1.0 - left * left
		for i in range(5, -1, -1):
			var back := clampf(eased - i * 0.04, 0.0, 1.0)
			var point: Vector2 = rocket["start"] + (rocket["end"] - rocket["start"]) * back
			var color: Color = Color.WHITE if i == 0 else Color(rocket["color"], 0.6 - i * 0.1)
			draw_circle(point, 6.0 - i * 0.7, color)
