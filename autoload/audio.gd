extends Node

## Musica persistente e sons de UI. Volume mora no bus, nao no player.

const MUSIC_BASE_VOLUME := 0.25
const FADE_SECONDS := 3.0
const CLICK_GAP_MS := 60

@onready var _music: AudioStreamPlayer = $Music
@onready var _click: AudioStreamPlayer = $Click
@onready var _locked: AudioStreamPlayer = $Locked

var _fade := 0.0
var _fade_tween: Tween
var _last_click_ms := -CLICK_GAP_MS

func _ready() -> void:
	Settings.changed.connect(_on_settings_changed)
	apply_volumes()
	_music.play()

func apply_volumes() -> void:
	_set_bus_linear("Music", Settings.music_volume * MUSIC_BASE_VOLUME * _fade)
	_set_bus_linear("SFX", Settings.sfx_volume)
	_set_bus_linear("Voice", Settings.sfx_volume)

## Sobe a musica do silencio ao volume ajustado em 3s. Chamar de novo nao
## reinicia o fade nem empilha tween.
func start_music_fade() -> void:
	if _fade_tween and _fade_tween.is_running():
		return
	_fade_tween = create_tween()
	_fade_tween.tween_method(set_music_fade, 0.0, 1.0, FADE_SECONDS)

func set_music_fade(value: float) -> void:
	_fade = value
	apply_volumes()

func play_click() -> void:
	# dois cliques mais juntos que isso sao o mesmo toque chegando por dois caminhos
	var now := Time.get_ticks_msec()
	if now - _last_click_ms < CLICK_GAP_MS:
		return
	_last_click_ms = now
	_click.play()

func play_locked() -> void:
	_locked.play()

## SFX curto com sobreposicao livre: player descartavel no bus SFX.
func play_sfx(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _on_settings_changed(key: String) -> void:
	if key not in ["music_volume", "sfx_volume"]:
		return
	apply_volumes()

func _set_bus_linear(bus_name: String, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(bus, linear <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.001)))
