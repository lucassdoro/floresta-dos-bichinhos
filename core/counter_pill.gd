class_name CounterPill
extends Control

## Pilula do HUD com o contador de acertos: fundo, icone e "coletadas/meta".

@export var target := 10
## Icone da pilula (a fruta/flor do mini-jogo).
@export var icon: Texture2D

@onready var _count: Label = %CountLabel
@onready var _icon_rect: TextureRect = %Icon

func _ready() -> void:
	if icon:
		_icon_rect.texture = icon
	set_collected(0)

func set_collected(collected_count: int) -> void:
	_count.text = "%d/%d" % [collected_count, target]
