class_name LoloCharacter
extends AnimatedSprite2D

## Lolo: idle ping-pong e voo (escala 1.45), com flip na direcao do voo.

const FLY_SCALE := 1.45

## Escala que encaixa o frame no rect 195x251 da referencia.
@export var base_scale := 0.6675

var _visual := 1.0
var _facing := 1.0

func _ready() -> void:
	play("idle")
	_apply_scale()

func fly() -> void:
	play("fly")
	_visual = FLY_SCALE
	_apply_scale()

func land() -> void:
	play("idle")
	_visual = 1.0
	_apply_scale()

func face_direction(delta_x: float) -> void:
	_facing = -1.0 if delta_x < 0.0 else 1.0
	_apply_scale()

func _apply_scale() -> void:
	scale = Vector2(_facing * _visual * base_scale, _visual * base_scale)
