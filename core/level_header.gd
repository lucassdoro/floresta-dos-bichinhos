class_name LevelHeader
extends Control

## Header padrao da fase: placa, "FASE N", titulo e 3 estrelas. A cada erro
## uma estrela cresce, solta brilhos e apaga (clip Star_Lose da referencia).

const STAR_ON := preload("res://assets/art/UI/WorldMap/star_on.webp")
const STAR_OFF := preload("res://assets/art/UI/WorldMap/star_off.webp")
const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")

@export var phase_key := "level11.phase"
@export var title_key := "level11.title"

var _earned := 3

@onready var _stars: Array[TextureRect] = [%Star1, %Star2, %Star3]

func _ready() -> void:
	%PhaseLabel.text = phase_key
	%TitleLabel.text = title_key
	for star in _stars:
		star.pivot_offset = star.size / 2.0

## Ajusta as estrelas acesas; cada uma que apaga roda a animacao de perda.
func set_stars(count: int) -> void:
	var clamped := clampi(count, 0, 3)
	if clamped >= _earned:
		_earned = clamped
		return
	for index in range(clamped, _earned):
		_lose_star(_stars[index])
	_earned = clamped

func _lose_star(star: TextureRect) -> void:
	var tween := create_tween()
	tween.tween_property(star, "scale", Vector2.ONE * 1.4, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_extinguish.bind(star))
	tween.tween_property(star, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func _extinguish(star: TextureRect) -> void:
	star.texture = STAR_OFF
	var effects := get_tree().get_first_node_in_group("effects")
	if effects == null:
		return
	var burst := SPARKLE_BURST.instantiate()
	effects.add_child(burst)
	burst.burst(star.global_position + star.size / 2.0, Color.WHITE, 10, 32.0)
