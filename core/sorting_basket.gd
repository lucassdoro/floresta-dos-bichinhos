class_name SortingBasket
extends Control

## Cesta de itens: acerto testado na elipse do rect, pulso ao receber, slots
## onde os itens coletados ficam entre o fundo e a borda frontal.

const PULSE_SCALE := 1.12
const PULSE_DURATION := 0.25
const SLOTS: Array[Vector2] = [
	Vector2(-110, 48), Vector2(0, 54), Vector2(110, 48),
	Vector2(-150, 24), Vector2(-50, 30), Vector2(50, 30), Vector2(150, 24),
	Vector2(-95, 4), Vector2(95, 4),
]

## O X de erro que esta cesta usa (vive no espaco da fase, um por fase).
@export var reject_marker: RejectMarker
## Item que a cesta aceita; a fase decide a regra lendo este id.
@export var accept_id := ""

var _stored_count := 0
var _pulse_tween: Tween

@onready var stored_root: Control = %StoredRoot

func _ready() -> void:
	pivot_offset = size / 2.0

## A cesta e' oval: vale a elipse do rect, nao os cantos.
func contains_global_point(global_point: Vector2) -> bool:
	var center := global_position + size * scale / 2.0
	var half := size * scale / 2.0
	var normalized := (global_point - center) / half
	return normalized.length_squared() <= 1.0

func pulse() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * PULSE_SCALE, PULSE_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, PULSE_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Slot do proximo item (relativo ao centro, y pra cima), com o X puxado pra
## dentro se o item for largo demais pra silhueta.
func reserve_storage_slot(item_half_width: float) -> Vector2:
	var slot := SLOTS[_stored_count % SLOTS.size()]
	_stored_count += 1
	var max_offset_x := maxf(0.0, size.x / 2.0 - item_half_width - 15.0)
	return Vector2(clampf(slot.x, -max_offset_x, max_offset_x), slot.y)

func show_reject(global_point: Vector2) -> void:
	if reject_marker:
		reject_marker.flash(global_point)
