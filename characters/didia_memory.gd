class_name DidiaMemory
extends AnimatedSprite2D

## Didia com aceno: idle em loop e um "hello" que, se ja estiver tocando,
## enfileira UM replay em vez de cortar o atual.

var _playing_hello := false
var _pending := false

func _ready() -> void:
	play("idle")
	animation_finished.connect(_on_animation_finished)

func play_hello() -> void:
	if _playing_hello:
		_pending = true
		return
	_start_hello()

func _start_hello() -> void:
	_playing_hello = true
	play("hello")

func _on_animation_finished() -> void:
	if animation != &"hello":
		return
	if _pending:
		_pending = false
		_start_hello()
		return
	_playing_hello = false
	play("idle")
