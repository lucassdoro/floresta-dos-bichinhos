class_name VictoryModal
extends Control

## Festa do modal de vitoria: painel entra com pop, confete cai, titulo
## estoura, as estrelas acendem uma a uma com brilho e som, e o botao
## AVANCAR chega por ultimo. Depois tudo balanca vivo.

signal advance

const STAR_ON := preload("res://assets/art/UI/WorldMap/star_on.webp")
const STAR_OFF := preload("res://assets/art/UI/WorldMap/star_off.webp")
const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")
const VICTORY_JINGLE := preload("res://assets/audio/SFX/victory_jingle.wav")
const STAR_CHIME := preload("res://assets/audio/SFX/star_chime.wav")

const STARS_BASE := 0.83
const STAR_WAIT := 0.5
const STAR_STEP := 0.85

var _playing := false

@onready var _dim: ColorRect = %Dim
@onready var _panel: NinePatchRect = %PanelBox
@onready var _title: Label = %Title
@onready var _stars: Array[TextureRect] = [%ModalStar1, %ModalStar2, %ModalStar3]
@onready var _advance_root: Control = %AdvanceRoot
@onready var _confetti: GPUParticles2D = %Confetti

func _ready() -> void:
	visible = false
	%AdvanceButton.pressed.connect(_on_advance)
	_panel.pivot_offset = _panel.size / 2.0
	_title.pivot_offset = _title.size / 2.0
	_advance_root.pivot_offset = _advance_root.size / 2.0
	for star in _stars:
		star.pivot_offset = star.size / 2.0

## Comeca a celebracao. Ja festejando ignora (nao sobrepoe duas festas).
func play(stars_earned: int) -> void:
	if _playing:
		return
	_playing = true
	var earned := clampi(stars_earned, 0, 3)
	visible = true
	Audio.play_sfx(VICTORY_JINGLE)
	_dim.modulate.a = 0.0
	_panel.scale = Vector2.ZERO
	_title.scale = Vector2.ZERO
	_advance_root.scale = Vector2.ZERO
	for star in _stars:
		star.texture = STAR_OFF
		star.scale = Vector2.ONE
		star.rotation = 0.0

	var entry := create_tween().set_parallel(true)
	entry.tween_property(_dim, "modulate:a", 1.0, 0.4)
	entry.tween_property(_panel, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entry.tween_callback(_confetti.restart).set_delay(0.4)

	_animate_title()
	for index in earned:
		_animate_star(index)
	_animate_advance(earned)

# titulo vem do fundo: nasce pequeno, estoura na tela e quica ate assentar
func _animate_title() -> void:
	_title.scale = Vector2.ONE * 0.15
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(_title, "scale", Vector2.ONE * 1.35, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_burst_at.bind(_title.position + _title.size / 2.0, 18, 72.0))
	tween.tween_property(_title, "scale", Vector2.ONE * 0.9, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title, "scale", Vector2.ONE * 1.08, 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title, "scale", Vector2.ONE, 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_wiggle.bind(_title, 2.5, 3.5))

func _animate_star(index: int) -> void:
	var star := _stars[index]
	var tween := create_tween()
	tween.tween_interval(STARS_BASE + STAR_WAIT + index * STAR_STEP)
	tween.tween_callback(_light_star.bind(index))
	tween.tween_property(star, "scale", Vector2.ONE * 1.3, 0.21) \
		.from(Vector2.ZERO).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_wiggle.bind(star, 8.0, 2.1))

func _light_star(index: int) -> void:
	var star := _stars[index]
	star.texture = STAR_ON
	_burst_at(star.position + star.size / 2.0, 12, 60.0)
	Audio.play_sfx(STAR_CHIME)

func _animate_advance(earned: int) -> void:
	var tween := create_tween()
	tween.tween_interval(STARS_BASE + earned * STAR_STEP + 0.3)
	tween.tween_property(_advance_root, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_pulse.bind(_advance_root))

# balanco vivo de idle: gira de leve pra la e pra ca, pra sempre
func _wiggle(node: Control, degrees: float, period: float) -> void:
	node.rotation_degrees = -degrees
	var tween := create_tween().set_loops()
	tween.tween_property(node, "rotation_degrees", degrees, period / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "rotation_degrees", -degrees, period / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _pulse(node: Control) -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2.ONE * 1.04, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2.ONE * 0.98, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _burst_at(panel_point: Vector2, count: int, max_size: float) -> void:
	var burst := SPARKLE_BURST.instantiate()
	_panel.add_child(burst)
	burst.burst(_panel.global_position + panel_point, Color.WHITE, count, max_size)

func _on_advance() -> void:
	if not _playing:
		return
	advance.emit()
