extends CanvasLayer

## Troca de cena com carga em thread. A cortina escurece pro fundo da floresta;
## se a carga passar do fade, entram logo, folhas e "Carregando...".

const CURTAIN_FADE := 0.3
const CONTENT_FADE := 0.35
## Conteudo que apareceu fica pelo menos isso na tela (sem piscar).
const MIN_CONTENT_TIME := 0.8
const DOT_INTERVAL := 0.4
const LOGO_PULSE := 1.2

var _busy := false
var _dot_time := 0.0
var _dots := 0
var _logo_tween: Tween

@onready var _curtain: Control = %Curtain
@onready var _content: Control = %Content
@onready var _logo: TextureRect = %Logo
@onready var _leaves: GPUParticles2D = %Leaves
@onready var _label: Label = %LoadingLabel

func _ready() -> void:
	_curtain.visible = false
	_curtain.modulate.a = 0.0
	set_process(false)

func go_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	ResourceLoader.load_threaded_request(path, "", true)
	_curtain.visible = true
	_content.modulate.a = 0.0
	await _fade(_curtain, 1.0, CURTAIN_FADE)
	if not _finished_loading(path):
		await _show_content_until_loaded(path)
	var scene := ResourceLoader.load_threaded_get(path) as PackedScene
	if scene != null:
		get_tree().change_scene_to_packed(scene)
		# a cena nova precisa de um frame pra desenhar antes de a cortina abrir
		await get_tree().process_frame
		await get_tree().process_frame
	await _fade(_curtain, 0.0, CURTAIN_FADE)
	_curtain.visible = false
	_stop_content()
	_busy = false

func _finished_loading(path: String) -> bool:
	return ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS

func _show_content_until_loaded(path: String) -> void:
	_leaves.restart()
	_leaves.emitting = true
	_logo.pivot_offset = _logo.size / 2.0
	_logo_tween = create_tween().set_loops()
	_logo_tween.tween_property(_logo, "scale", Vector2.ONE * 1.05, LOGO_PULSE / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_logo_tween.tween_property(_logo, "scale", Vector2.ONE, LOGO_PULSE / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dots = 0
	_dot_time = 0.0
	_update_label()
	set_process(true)
	_fade(_content, 1.0, CONTENT_FADE)
	var shown_at := Time.get_ticks_msec()
	while not _finished_loading(path) or Time.get_ticks_msec() - shown_at < MIN_CONTENT_TIME * 1000.0:
		await get_tree().process_frame

func _stop_content() -> void:
	set_process(false)
	_leaves.emitting = false
	if _logo_tween != null:
		_logo_tween.kill()
		_logo_tween = null

func _process(delta: float) -> void:
	_dot_time += delta
	if _dot_time < DOT_INTERVAL:
		return
	_dot_time = 0.0
	_dots = (_dots + 1) % 4
	_update_label()

# texto fixo com os 3 pontos; so a revelacao muda (layout nao reflui)
func _update_label() -> void:
	var base := tr("loading.text")
	_label.text = base + "..."
	_label.visible_characters = base.length() + _dots

func _fade(target: CanvasItem, alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate:a", alpha, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
