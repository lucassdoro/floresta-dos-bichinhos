class_name AmbientBubbles
extends Node2D

## Bolhinhas decorativas subindo do rodape: so estetica, sem hit-test.

const SPAWN_INTERVAL := 0.7
const SWAY := 14.0
const BUBBLE := preload("res://assets/art/MiniGames/ColorReef/bubble_a.webp")

var area := Vector2.ZERO
var _timer := 0.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer < SPAWN_INTERVAL or area.x == 0.0:
		return
	_timer = 0.0
	var bubble_size := randf_range(26.0, 60.0)
	var sprite := Sprite2D.new()
	sprite.texture = BUBBLE
	sprite.scale = Vector2.ONE * (bubble_size / BUBBLE.get_width())
	sprite.modulate.a = randf_range(0.45, 0.75)
	sprite.position = Vector2(randf() * area.x, area.y + bubble_size)
	add_child(sprite)
	var speed := randf_range(60.0, 110.0)
	var duration := (area.y + bubble_size * 2.0) / speed
	var base_x := sprite.position.x
	var phase := randf() * TAU
	var tween := sprite.create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", -bubble_size, duration)
	tween.tween_method(func(t: float) -> void:
		sprite.position.x = base_x + sin(t * 2.0 + phase) * SWAY, 0.0, duration, duration)
	tween.chain().tween_callback(sprite.queue_free)
