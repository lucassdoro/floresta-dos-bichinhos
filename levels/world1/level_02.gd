extends LevelBase

## Fase 2 do mundo 1 — "Recife das Cores": clique na cor pedida e pinte o
## coral esfregando o pincel. 2 etapas x 3 cores; erro custa estrela a cada 2.

const INTRO_DELAY := 1.2
const INTRO_HOLD := 0.1
const CORRECT_DELAY := 2.5
const NUDGE_AFTER := 9.0
const CORAL_OFFSET_Y := -52.0

const GOOD_SFX := preload("res://assets/audio/SFX/fruit_drop_good.wav")
const BAD_SFX := preload("res://assets/audio/SFX/fruit_drop_oops.wav")
const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")

# [chave, cor, nome do asset]
const STAGE1 := [
	["color.red", Color(0.99, 0.24, 0.11), "star_red"],
	["color.green", Color(0.62, 0.91, 0.06), "star_green"],
	["color.yellow", Color(0.99, 0.85, 0.02), "star_yellow"],
]
const STAGE2 := [
	["color.blue", Color(0.22, 0.82, 0.96), "star_blue"],
	["color.orange", Color(0.98, 0.52, 0.03), "star_orange"],
	["color.purple", Color(0.76, 0.12, 0.94), "star_purple"],
]
const PRAISE_KEYS := ["praise.great", "praise.congrats", "praise.excellent", "praise.yes"]

# clipe de voz da Lali por chave: [pt, it]
const VOICES := {
	"level12.intro": ["02_apresentacao_2", "02_apresentacao_2"],
	"color.red": ["03_pedido_vermelho", "03_pedido_rosso"],
	"color.green": ["04_pedido_verde", "04_pedido_verde"],
	"color.yellow": ["05_pedido_amarelo", "05_pedido_giallo"],
	"color.blue": ["06_pedido_azul", "06_pedido_blu"],
	"color.orange": ["07_pedido_laranja", "07_pedido_arancione"],
	"color.purple": ["08_pedido_roxo", "08_pedido_viola"],
	"praise.great": ["09_elogio_muitobem", "09_elogio_moltobene"],
	"praise.congrats": ["10_elogio_parabens", "10_elogio_perfetto"],
	"praise.excellent": ["11_elogio_excelente", "11_elogio_ottimo"],
	"praise.yes": ["12_elogio_isso", "12_elogio_esatto"],
	"level12.nudge": ["13_incentivo_pintar", "13_incentivo_pintar"],
}

var _stage_index := 0
var _accepting := false
var _current: Array = []
var _queue: Array = []
var _target: Array = []

@onready var _coral: CoralPaintArea = %Coral
@onready var _brush: BrushCursor = %Brush
@onready var _panel: ColorsPanel = %ColorsPanel
@onready var _lali: LaliCharacter = %Lali
@onready var _bubble: SpeechBubble = %Bubble
@onready var _reject: RejectMarker = %RejectMarker

func _ready() -> void:
	super()
	_coral.painted_complete.connect(_on_coral_painted)
	_coral.follow_requested.connect(_brush.follow)
	_coral.released.connect(_brush.release)
	_panel.chosen.connect(_choose)
	resized.connect(_relayout)
	_relayout()
	_enter_lali()
	_intro_routine()
	_nudge_loop()

func _relayout() -> void:
	_coral.position = from_center(Vector2(0, CORAL_OFFSET_Y)) - _coral.size / 2.0
	_lali.position = Vector2(200, size.y - 344)
	_bubble.position = Vector2(570 - _bubble.size.x / 2.0, size.y - 350 - _bubble.size.y / 2.0)

func _enter_lali() -> void:
	_lali.enter_from(Vector2(960, size.y - 540), Vector2(200, size.y - 344))

func _intro_routine() -> void:
	await _wait(INTRO_DELAY)
	if _dead():
		return
	_setup_stage(STAGE1, false)
	_lali.ask()
	_bubble.show_bubble()
	_bubble.say(tr("level12.intro"))
	_play_voice("level12.intro")
	await _bubble.typing_finished
	if _dead():
		return
	# a voz da intro dura mais que a digitacao; o pedido seguinte cortaria a fala
	if Voice.is_playing():
		await Voice.finished
	if _dead():
		return
	await _wait(INTRO_HOLD)
	if _dead():
		return
	_panel.reveal()
	_next_request(false)

func _setup_stage(colors: Array, _swap: bool) -> void:
	_current = colors
	_apply_stage_textures(colors)
	_queue = colors.duplicate()
	_queue.shuffle()

func _apply_stage_textures(colors: Array) -> void:
	var actives: Array = []
	var disabled: Array = []
	var texts: Array = []
	for option in colors:
		actives.append(load("res://assets/art/MiniGames/ColorReef/%s.webp" % option[2]))
		disabled.append(load("res://assets/art/MiniGames/ColorReef/%s_bw.webp" % option[2]))
		texts.append(tr(option[0]))
	_panel.setup_stage(actives, disabled, texts)

func _next_request(praise: bool) -> void:
	_coral.reset_to_neutral()
	_panel.restore()
	_target = _queue.pop_front()
	var color_name: String = tr(_target[0]).to_lower()
	var ask_template: String = tr("level12.ask")
	var body := ask_template.replace("{0}", color_name)
	var prefix := ""
	var praise_key := ""
	if praise:
		praise_key = PRAISE_KEYS[randi() % PRAISE_KEYS.size()]
		prefix = tr(praise_key) + " "
		_bubble.pulse()
	var bold_start := prefix.length() + ask_template.find("{0}")
	_lali.ask()
	_bubble.say(prefix + body, bold_start, bold_start + color_name.length(), _darken(_target[1]))
	_speak_request(praise_key, _target[0])
	_enable_after_typing()

func _enable_after_typing() -> void:
	await _bubble.typing_finished
	if _dead():
		return
	_accepting = true

func _speak_request(praise_key: String, color_key: String) -> void:
	if praise_key != "":
		await _play_voice(praise_key)
		if _dead():
			return
	_play_voice(color_key)

func _choose(slot: int) -> void:
	if not _accepting:
		return
	if _current[slot][0] == _target[0]:
		_on_correct(slot)
		return
	_reject.flash(_panel.button_center(slot))
	Audio.play_sfx(BAD_SFX)
	mistake()

func _on_correct(slot: int) -> void:
	_accepting = false
	Audio.play_sfx(GOOD_SFX)
	_panel.dim_others(slot)
	_coral.begin(_target[1])
	_brush.show_invite(_target[1], from_center(Vector2(300, -60)))

func _on_coral_painted() -> void:
	_brush.hide_brush()
	_lali.correct()
	_coral.paint_coral(_target[1])
	var burst := SPARKLE_BURST.instantiate()
	$Effects.add_child(burst)
	burst.burst(from_center(Vector2(0, CORAL_OFFSET_Y)), _target[1].lerp(Color.WHITE, 0.35), 16, 100.0)
	Audio.play_sfx(GOOD_SFX)
	_after_correct()

func _after_correct() -> void:
	await _wait(CORRECT_DELAY)
	if _dead():
		return
	if _queue.is_empty():
		_stage_complete()
		return
	_next_request(true)

func _stage_complete() -> void:
	if _stage_index == 0:
		_stage_index = 1
		_setup_stage(STAGE2, true)
		_next_request(true)
		return
	win()

func _nudge_loop() -> void:
	while not _dead():
		await _wait(1.0)
		if _dead():
			return
		if _coral.idle_seconds < NUDGE_AFTER:
			continue
		_bubble.pulse()
		_bubble.say(tr("level12.nudge"))
		_play_voice("level12.nudge")
		_coral.mark_activity()

func _play_voice(key: String) -> void:
	var files: Array = VOICES.get(key, [])
	if files.is_empty():
		return
	var file: String = files[1] if Settings.locale == "it" else files[0]
	if Voice.play("Lali", file):
		await Voice.finished

# escurece cores muito claras (ex.: amarelo) pra ler no balao creme
func _darken(color: Color) -> Color:
	var luminance := 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
	if luminance <= 0.7:
		return color
	var factor := 0.7 / luminance
	return Color(color.r * factor, color.g * factor, color.b * factor)

func _dead() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
