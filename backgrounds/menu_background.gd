extends Node2D

## Sprite2D nao tem ancora: cobre o viewport na mao e recentraliza no resize.

@onready var _still: Sprite2D = $Still

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	var texture_size := _still.texture.get_size()
	var cover := maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	_still.scale = Vector2.ONE * cover
	_still.position = viewport_size / 2.0
