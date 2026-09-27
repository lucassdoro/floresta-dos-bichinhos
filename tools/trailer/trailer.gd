extends Node

## Ponto de entrada do trailer: prende o diretor na raiz para ele sobreviver as
## trocas de cena. Uso em tools/trailer/README.md.

const DIRECTOR := preload("res://tools/trailer/trailer_director.gd")

func _ready() -> void:
	get_tree().root.add_child.call_deferred(DIRECTOR.new())
