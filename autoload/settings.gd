extends Node

## Volumes, qualidade grafica e idioma, gravados em user://settings.cfg.

signal changed(key: String)

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "settings"

var music_volume := 1.0
var sfx_volume := 1.0
var quality := 2
var locale := "pt_BR"

var _config := ConfigFile.new()

func _ready() -> void:
	_config.load(CONFIG_PATH)
	music_volume = _config.get_value(SECTION, "music_volume", music_volume)
	sfx_volume = _config.get_value(SECTION, "sfx_volume", sfx_volume)
	quality = _config.get_value(SECTION, "quality", quality)
	locale = _config.get_value(SECTION, "locale", locale)
	TranslationServer.set_locale(locale)

func set_value(key: String, value: Variant) -> void:
	set(key, value)
	_config.set_value(SECTION, key, value)
	_config.save(CONFIG_PATH)
	if key == "locale":
		TranslationServer.set_locale(value)
	changed.emit(key)
