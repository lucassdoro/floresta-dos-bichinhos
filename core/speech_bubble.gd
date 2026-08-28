class_name SpeechBubble
extends Control

## Balao de fala com maquina de escrever: o texto revela char a char sem
## reflow (visible_characters do RichTextLabel) e um trecho pode sair em
## negrito colorido (o nome da cor pedida).

signal typing_finished

const TEXT_COLOR := Color(0.29, 0.18, 0.07)
const CHARS_PER_SECOND := 28.0
const APPEAR_DURATION := 0.35
const HIDE_DURATION := 0.35

var _typing := false
var _revealed := 0.0
var _total := 0

@onready var _label: RichTextLabel = %BubbleText

func _ready() -> void:
	modulate.a = 0.0
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 0.9

func show_bubble() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, APPEAR_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, APPEAR_DURATION * 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func hide_bubble() -> void:
	create_tween().tween_property(self, "modulate:a", 0.0, HIDE_DURATION)

## Pulso quando ja aberto: 1 -> 1.05 -> 1 em 0.25s.
func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.05, 0.125) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.125) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## [bold_start, bold_end) do texto sai em negrito na cor dada.
func say(text: String, bold_start := -1, bold_end := -1, bold_color := Color.WHITE) -> void:
	var bbcode := text
	if bold_start >= 0 and bold_end > bold_start and bold_end <= text.length():
		bbcode = text.substr(0, bold_start) \
			+ "[b][color=#%s]" % bold_color.to_html(false) \
			+ text.substr(bold_start, bold_end - bold_start) \
			+ "[/color][/b]" \
			+ text.substr(bold_end)
	_label.text = bbcode
	_total = text.length()
	_revealed = 0.0
	_label.visible_characters = 0
	_typing = true

func _process(delta: float) -> void:
	if not _typing:
		return
	_revealed = minf(_revealed + CHARS_PER_SECOND * delta, _total)
	_label.visible_characters = int(_revealed)
	if _revealed >= _total:
		_label.visible_characters = -1
		_typing = false
		typing_finished.emit()
