extends SceneTree

func _init() -> void:
	var settings = load("res://autoload/settings.gd").new()
	settings._ready()
	var defaults_ok = settings.music_volume == 1.0 and settings.sfx_volume == 1.0 \
		and settings.quality == 2 and settings.locale == "pt_BR"
	print("padroes: ", "OK" if defaults_ok else "FALHOU")

	var received := []
	settings.changed.connect(func(key): received.append(key))
	settings.set_value("quality", 0)
	settings.set_value("music_volume", 0.4)
	print("sinal: ", "OK" if received == ["quality", "music_volume"] else "FALHOU %s" % [received])

	var reloaded = load("res://autoload/settings.gd").new()
	reloaded._ready()
	var persisted_ok = reloaded.quality == 0 and is_equal_approx(reloaded.music_volume, 0.4)
	print("persistencia: ", "OK" if persisted_ok else "FALHOU q=%s m=%s" % [reloaded.quality, reloaded.music_volume])

	# o teste nao pode deixar o jogo em qualidade baixa
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	quit()
