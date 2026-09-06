class_name SceneBackground
extends Node2D

## Fundo de tela: still + shader em quality 0, video por cima nos outros niveis.
## O still segura a imagem ate o video entregar o primeiro frame (trocar antes pisca preto).

const FADE_DURATION := 0.3

@onready var _still: Sprite2D = $Still
@onready var _video: VideoStreamPlayer = get_node_or_null("Video")

var _still_material: Material
var _fade: Tween

static func wants_video(quality: int) -> bool:
	return quality >= 1

## Sprite2D e VideoStreamPlayer nao tem ancora: escala que cobre o viewport inteiro.
static func cover_scale(viewport_size: Vector2, texture_size: Vector2) -> float:
	return maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)

func _ready() -> void:
	_still_material = _still.material
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_process(false)
	if _video == null:
		return
	_video.visible = false
	_video.modulate.a = 0.0
	Settings.changed.connect(_on_settings_changed)
	_apply_mode()

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	var texture_size := _still.texture.get_size()
	var cover := cover_scale(viewport_size, texture_size)
	_still.scale = Vector2.ONE * cover
	_still.position = viewport_size / 2.0
	if _video == null:
		return
	_video.size = texture_size * cover
	_video.position = (viewport_size - _video.size) / 2.0

func _apply_mode() -> void:
	if wants_video(Settings.quality):
		_start_video()
		return
	_stop_video()

func _start_video() -> void:
	_kill_fade()
	if not _video.is_playing():
		_video.play()
	if _video.stream_position <= 0.0:
		set_process(true)
		return
	_show_video()

## Espera o primeiro frame decodificado.
func _process(_delta: float) -> void:
	if _video.stream_position <= 0.0:
		return
	set_process(false)
	_show_video()

func _show_video() -> void:
	_video.visible = true
	_fade = _new_fade()
	_fade.tween_property(_video, "modulate:a", 1.0, FADE_DURATION)
	_fade.tween_callback(func(): _still.material = null)

func _stop_video() -> void:
	_kill_fade()
	set_process(false)
	_still.material = _still_material
	if not _video.visible:
		_video.stop()
		return
	_fade = _new_fade()
	_fade.tween_property(_video, "modulate:a", 0.0, FADE_DURATION)
	_fade.tween_callback(func():
		_video.stop()
		_video.visible = false)

func _new_fade() -> Tween:
	return create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _kill_fade() -> void:
	if _fade == null:
		return
	_fade.kill()
	_fade = null

func _on_settings_changed(key: String) -> void:
	if key != "quality":
		return
	_apply_mode()
