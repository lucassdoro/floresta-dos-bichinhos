extends Node

## Roda como CENA (nao como --script): so' assim os autoloads existem.

func _ready() -> void:
	var buses := []
	for i in AudioServer.bus_count:
		buses.append(AudioServer.get_bus_name(i))
	print("buses: ", "OK" if buses == ["Master", "Music", "SFX", "Voice"] else "FALHOU %s" % [buses])

	Audio.set_music_fade(0.0)
	var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	print("mudo em zero: ", "OK" if muted else "FALHOU")

	Audio.set_music_fade(1.0)
	# volume cheio = Settings.music_volume (1.0) * MUSIC_BASE_VOLUME (0.25) = -12.04 dB
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	print("volume cheio: ", "OK" if is_equal_approx(db, linear_to_db(0.25)) else "FALHOU %s" % db)

	Audio.play_click()
	var first = Audio._last_click_ms
	Audio.play_click()
	print("guarda de clique: ", "OK" if Audio._last_click_ms == first else "FALHOU")

	print("musica tocando: ", "OK" if Audio._music.playing else "FALHOU")
	get_tree().quit()
