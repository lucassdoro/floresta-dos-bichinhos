extends Control

## Segurar 3s pra abrir link externo; soltar zera.

const HOLD_SECONDS := 3.0

@export var site_url := ""

@onready var _hold_button: TextureProgressBar = $Panel/HoldButton

var _hold_tween: Tween

func _ready() -> void:
	_hold_button.gui_input.connect(_on_hold_input)
	$Panel/BackButton.pressed.connect(queue_free)

func _on_hold_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.pressed:
		start_hold()
		return
	cancel_hold()

func start_hold() -> void:
	cancel_hold()
	_hold_tween = create_tween()
	_hold_tween.tween_property(_hold_button, "value", _hold_button.max_value, HOLD_SECONDS)
	_hold_tween.finished.connect(_on_hold_complete)

func cancel_hold() -> void:
	if _hold_tween:
		_hold_tween.kill()
	_hold_button.value = 0.0

func _on_hold_complete() -> void:
	OS.shell_open(site_url)
	queue_free()
