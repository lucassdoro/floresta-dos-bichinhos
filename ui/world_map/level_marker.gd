class_name LevelMarker
extends Control

## Marcador de fase do mapa: plaquinha com numero e arco de 3 estrelas.
## Bloqueado fica translucido, esconde as estrelas e toca som de trancado.

signal selected(level: int)

const STAR_ON := preload("res://assets/art/UI/WorldMap/star_on.webp")
const STAR_OFF := preload("res://assets/art/UI/WorldMap/star_off.webp")
const LOCKED_ALPHA := 0.5

@export var level_number := 1
## Ancora fracionaria no rect do fundo (y pra cima, como na referencia).
@export var map_anchor := Vector2(0.5, 0.5)

var locked := false
var _earned := 0

@onready var _plaque: TextureButton = %Plaque
@onready var _number: Label = %NumberLabel
@onready var _stars_root: Control = %StarsRoot
@onready var _stars: Array[TextureRect] = [%StarLeft, %StarMiddle, %StarRight]

func _ready() -> void:
	_number.text = str(level_number)
	_plaque.pressed.connect(_on_pressed)
	_apply_state()

func configure(stars: int, is_locked: bool) -> void:
	_earned = clampi(stars, 0, 3)
	locked = is_locked
	if is_node_ready():
		_apply_state()

## Pulinho do desbloqueio: cresce e assenta em escala 1.
func pop() -> void:
	pivot_offset = size / 2.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.15, 0.175) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.175) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _apply_state() -> void:
	for index in 3:
		_stars[index].texture = STAR_ON if index < _earned else STAR_OFF
	_stars_root.visible = not locked
	var alpha := LOCKED_ALPHA if locked else 1.0
	_plaque.modulate.a = alpha

func _on_pressed() -> void:
	if locked:
		Audio.play_locked()
		return
	selected.emit(level_number)
