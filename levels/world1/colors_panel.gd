class_name ColorsPanel
extends Control

## Painel dos 3 botoes-estrela de cor: sobe deslizando no reveal, troca
## sprites/rotulos entre as etapas e apaga (P&B + alpha) os nao escolhidos.

signal chosen(slot: int)

const HIDDEN_OFFSET := 281.49
const SHOWN_OFFSET := -38.51
const REVEAL_DURATION := 0.45
const DISABLED_ALPHA := 0.45
const BUTTON_RECT := Vector2(168, 173)
const PANEL_HEIGHT := 210.0

var _active_textures: Array = []
var _disabled_textures: Array = []

@onready var _buttons: Array[TextureButton] = [%ColorButton1, %ColorButton2, %ColorButton3]
@onready var _labels: Array[Label] = [%ColorLabel1, %ColorLabel2, %ColorLabel3]

func _ready() -> void:
	for slot in 3:
		_buttons[slot].pressed.connect(func() -> void: chosen.emit(slot))
	# escondido abaixo da borda ate o reveal (size ainda nao resolveu no _ready)
	offset_top = HIDDEN_OFFSET
	offset_bottom = HIDDEN_OFFSET + PANEL_HEIGHT

func setup_stage(actives: Array, disabled: Array, texts: Array) -> void:
	_active_textures = actives
	_disabled_textures = disabled
	for slot in 3:
		_labels[slot].text = texts[slot]
	restore()

func reveal() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "offset_top", SHOWN_OFFSET - PANEL_HEIGHT, REVEAL_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "offset_bottom", SHOWN_OFFSET, REVEAL_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func restore() -> void:
	for slot in 3:
		_buttons[slot].texture_normal = _active_textures[slot]
		_buttons[slot].modulate.a = 1.0

func dim_others(selected: int) -> void:
	for slot in 3:
		if slot == selected:
			continue
		_buttons[slot].texture_normal = _disabled_textures[slot]
		_buttons[slot].modulate.a = DISABLED_ALPHA

## Centro global do botao, pro X de erro.
func button_center(slot: int) -> Vector2:
	return _buttons[slot].get_global_rect().get_center()
