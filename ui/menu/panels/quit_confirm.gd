extends Control

## Modal proprio: sem botao voltar, com pop e escurecimento proprios.

signal closed

func _ready() -> void:
	$Panel/NoButton.pressed.connect(_on_no)
	$Panel/YesButton.pressed.connect(get_tree().quit)

func _on_no() -> void:
	closed.emit()
	queue_free()
