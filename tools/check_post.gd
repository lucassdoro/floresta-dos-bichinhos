extends Control

func _ready() -> void:
	$ClickProbe.pressed.connect(func(): print("CLIQUE CHEGOU NO BOTAO"))
