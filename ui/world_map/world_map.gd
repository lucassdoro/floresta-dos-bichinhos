extends Control

## Stub: existe pra transicao menu -> mapa -> menu ser testada de verdade.

func _ready() -> void:
	$BackButton.pressed.connect(_go_back)

func _go_back() -> void:
	get_tree().change_scene_to_file("res://ui/menu/main_menu.tscn")
