class_name MenuPanel
extends Control

## Base dos paineis: pop-in, botao voltar e aviso de fechamento.

signal closed

func _ready() -> void:
	$BackButton.pressed.connect(close)

func close() -> void:
	closed.emit()
	queue_free()
