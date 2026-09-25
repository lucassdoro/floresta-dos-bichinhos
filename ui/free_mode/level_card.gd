class_name LevelCard
extends Control

## Card do Modo Livre. Toque abre a fase; arrastar rola a lista sem abrir
## (mouse_filter PASS deixa o ScrollContainer receber o arrasto).

signal chosen(info: LevelInfo)

const STAR_ON := preload("res://assets/art/UI/WorldMap/star_on.webp")
const STAR_OFF := preload("res://assets/art/UI/WorldMap/star_off.webp")
const TAP_SLOP := 24.0
const POP_SCALE := 1.06
const POP_TIME := 0.12

var info: LevelInfo
var _press_position := Vector2.INF

@onready var _title: Label = %Title
@onready var _cover: TextureRect = %Cover
@onready var _description: Label = %Description
@onready var _stars: Array[TextureRect] = [%Star1, %Star2, %Star3]
@onready var _plays: Label = %Plays
@onready var _author: Label = %Author

func _ready() -> void:
	resized.connect(_center_pivot)
	_center_pivot()
	gui_input.connect(_on_gui_input)

func setup(level: LevelInfo) -> void:
	info = level
	_title.text = level.title
	_description.text = level.description
	_cover.texture = level.cover
	var best := FreePlay.get_best(level.id)
	for index in _stars.size():
		_stars[index].texture = STAR_ON if index < best else STAR_OFF
	_plays.text = "x%d" % FreePlay.get_plays(level.id)
	var author_name := tr("free_mode.studio") if level.author.is_empty() else level.author
	_author.text = tr("free_mode.by") % author_name

func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_position = button.global_position
		return
	if button.global_position.distance_to(_press_position) > TAP_SLOP:
		return
	_press_position = Vector2.INF
	Audio.play_click()
	_pop()
	chosen.emit(info)

func _pop() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE * POP_SCALE, POP_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_TIME).set_ease(Tween.EASE_IN)

func _center_pivot() -> void:
	pivot_offset = size / 2.0
