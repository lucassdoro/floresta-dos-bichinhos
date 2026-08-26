extends Control

@onready var _animation: AnimationPlayer = $Animation

func _ready() -> void:
	$Hum.play()
	_animation.animation_finished.connect(_on_finished)

func _on_finished(_animation_name: StringName) -> void:
	# o fade de 3s comeca aqui, pra ser ouvido junto com o menu aparecendo
	Audio.start_music_fade()
	get_tree().change_scene_to_file("res://ui/menu/main_menu.tscn")

func play_zap() -> void:
	$Zap.play()

func play_thump() -> void:
	$Thump.play()
