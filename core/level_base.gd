class_name LevelBase
extends Control

## Casca comum de fase: header com estrelas, botao voltar, modal de vitoria,
## regra de estrela e report pra Progression. A fase concreta chama mistake()
## e win() e implementa o resto.

const VICTORY_DELAY := 0.8

@export var world_number := 1
@export var level_number := 1
## Erros ate perder cada estrela: estrelas = 3 - erros / mistakes_per_star, min 1.
@export var mistakes_per_star := 1

var mistakes := 0
var completed := false

@onready var header: LevelHeader = %Header
@onready var victory_modal: VictoryModal = %VictoryModal

func _ready() -> void:
	%BackButton.pressed.connect(exit_level)
	victory_modal.advance.connect(exit_level)

func stars_now() -> int:
	return clampi(3 - mistakes / mistakes_per_star, 1, 3)

func mistake() -> void:
	if completed:
		return
	mistakes += 1
	header.set_stars(stars_now())

func win() -> void:
	if completed:
		return
	completed = true
	await get_tree().create_timer(VICTORY_DELAY).timeout
	var stars_earned := stars_now()
	Progression.report_level_result(world_number, level_number, stars_earned)
	victory_modal.play(stars_earned)

func exit_level() -> void:
	get_tree().change_scene_to_file("res://ui/world_map/world_map.tscn")

## Converte offset relativo ao centro (y pra cima, como na referencia) em
## posicao no espaco da fase.
func from_center(offset: Vector2) -> Vector2:
	return size / 2.0 + Vector2(offset.x, -offset.y)
