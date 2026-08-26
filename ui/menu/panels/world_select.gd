extends MenuPanel

func _ready() -> void:
	super()
	$Cards/World1.pressed.connect(_open_world_map)
	_connect_locked($Cards/World2)
	_connect_locked($Cards/World3)

func _open_world_map() -> void:
	get_tree().change_scene_to_file("res://ui/world_map/world_map.tscn")

func _connect_locked(card: TextureRect) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input.bind(card))

func _on_card_input(event: InputEvent, card: TextureRect) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	Audio.play_locked()
	card.get_node("Shake").play("shake")
