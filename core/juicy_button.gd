class_name JuicyButton
extends TextureButton

## Cresce no hover, encolhe no press, solta brilho no clique.

const PRESSED_TINT := Color(0.78, 0.78, 0.78)
const ANIMATION_SPEED := 14.0

const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")

@export var burst_color := Color(1.0, 0.85, 0.45)
@export var burst_count := 30
@export var burst_max_size := 120.0
## Botoes de modal usam 1.0 nos dois: la' o retorno e' so' o tint de press.
@export var hover_scale := 1.07
@export var pressed_scale := 0.92

func _ready() -> void:
	resized.connect(_center_pivot)
	_center_pivot()
	pressed.connect(_on_pressed)

func _process(delta: float) -> void:
	var step := 1.0 - exp(-ANIMATION_SPEED * delta)
	scale = scale.lerp(Vector2.ONE * _target_scale(), step)
	modulate = modulate.lerp(_target_tint(), step)

func _target_scale() -> float:
	if is_pressed():
		return pressed_scale
	if is_hovered():
		return hover_scale
	return 1.0

func _target_tint() -> Color:
	return PRESSED_TINT if is_pressed() else Color.WHITE

func _center_pivot() -> void:
	pivot_offset = size / 2.0

func _on_pressed() -> void:
	Audio.play_click()
	if burst_count <= 0:
		return
	var effects := get_tree().get_first_node_in_group("effects")
	if effects == null:
		return
	var burst := SPARKLE_BURST.instantiate()
	effects.add_child(burst)
	burst.burst(global_position + size / 2.0, burst_color, burst_count, burst_max_size)
