extends Node

## Toca a voz TTS dos personagens no bus Voice, uma fala por vez.
## Arquivos em res://assets/audio/Voice/<Personagem>/<locale>/<arquivo>.wav

signal finished

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Voice"
	add_child(_player)
	_player.finished.connect(func() -> void: finished.emit())

## Locale das pastas de voz usa hifen (pt-BR), o do jogo usa underline (pt_BR).
func locale_folder() -> String:
	return Settings.locale.replace("_", "-")

func play(character: String, file_name: String) -> void:
	var path := "res://assets/audio/Voice/%s/%s/%s.wav" % [character, locale_folder(), file_name]
	play_path(path)

func play_path(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Voz nao encontrada: " + path)
		return
	_player.stop()
	_player.stream = load(path)
	_player.play()

func stop() -> void:
	_player.stop()

func is_playing() -> bool:
	return _player.playing
