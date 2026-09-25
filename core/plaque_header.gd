@tool
class_name PlaqueHeader
extends Control

## Placa de madeira com titulo, topo padrao das telas (mapa, Modo Livre).

@export var title_key := "":
	set(value):
		title_key = value
		if is_node_ready():
			$Title.text = value

func _ready() -> void:
	$Title.text = title_key
