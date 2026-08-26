extends CanvasLayer

## Bloom + vinheta + grading por cima de todas as telas.

const TAPS_BY_QUALITY := [0.0, 10.0, 16.0]

@onready var _material: ShaderMaterial = $Screen.material

func _ready() -> void:
	Settings.changed.connect(_on_settings_changed)
	set_quality(Settings.quality)

func set_quality(level: int) -> void:
	_material.set_shader_parameter("taps", TAPS_BY_QUALITY[clampi(level, 0, 2)])

func _on_settings_changed(key: String) -> void:
	if key != "quality":
		return
	set_quality(Settings.quality)
