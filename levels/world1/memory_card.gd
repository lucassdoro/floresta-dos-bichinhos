class_name MemoryCard
extends TextureRect

## Carta da memoria: vira animando so o eixo X (a face troca no meio), pulsa
## com brilhos ao formar par.

signal pressed_card(card: MemoryCard)

const FLIP_HALF := 0.13
const PULSE_DURATION := 0.3
const PULSE_SCALE := 0.15
const BACK := preload("res://assets/art/MiniGames/MemoryMeadow/card_back.webp")
const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")

var pair_id := 0
var face: Texture2D = null
var face_up := false
var matched := false

var _flipping := false

func _ready() -> void:
	texture = BACK
	pivot_offset = size / 2.0

func flip_up() -> void:
	await _flip(true)

func flip_down() -> void:
	await _flip(false)

func _flip(to_face_up: bool) -> void:
	if face_up == to_face_up and not _flipping:
		return
	_flipping = true
	var tween := create_tween()
	tween.tween_property(self, "scale:x", 0.0, FLIP_HALF) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		face_up = to_face_up
		texture = face if face_up else BACK)
	tween.tween_property(self, "scale:x", 1.0, FLIP_HALF) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_flipping = false

func set_matched() -> void:
	matched = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * (1.0 + PULSE_SCALE), PULSE_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, PULSE_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		var burst := SPARKLE_BURST.instantiate()
		effects.add_child(burst)
		burst.burst(global_position + size / 2.0, Color.WHITE, 18, 72.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if face_up or matched or _flipping:
			return
		pressed_card.emit(self)
