extends LevelBase

## Fase 10 do mundo 1 — "Os Bichinhos Perdidos": o vaga-lume segue o dedo,
## acha os filhotes no escuro, a fila segue ate a fogueira onde os quatro
## esperam, e a festa fecha o mundo. Sem erro: estrelas fixas em 3.

const BACKGROUND_SIZE := Vector2(1280, 720)
const REVEAL_RADIUS := 150.0
const DELIVER_RADIUS := 260.0
const SEAT_RADIUS := 90.0
const LINE_SPACING := 110.0
const CUB_WIDTH := 120.0
const CUB_COUNT := 6
const INTRO_DELAY := 0.4
const INTRO_HOLD := 0.8
const NUDGE_FIRST := 10.0
const NUDGE_REPEAT := 15.0
const PARTY_DELAY := 0.8
const PARTY_DURATION := 3.8
const CUBS := ["croc", "elephant", "lion", "monkey", "tiger", "turtle"]

const FIRE_ANCHOR := Vector2(0.50, 0.80)
const DIDIA_ANCHOR := Vector2(0.38, 0.97)
const SOPHY_ANCHOR := Vector2(0.25, 0.99)
const LOLO_ANCHOR := Vector2(0.47, 0.60)
const LALI_ANCHOR := Vector2(0.66, 0.70)
const WATER_LINE := 0.715
const BUBBLE_ANCHOR := Vector2(0.285, 0.57)
const FIREFLY_START := Vector2(0.42, 0.72)
const SEAT_ANCHORS := [
	Vector2(0.561, 0.86), Vector2(0.622, 0.90), Vector2(0.683, 0.91),
	Vector2(0.744, 0.89), Vector2(0.805, 0.85), Vector2(0.50, 0.91),
]
const HIDING_SPOTS := [
	Vector2(0.18, 0.34), Vector2(0.30, 0.22), Vector2(0.43, 0.33),
	Vector2(0.60, 0.56), Vector2(0.74, 0.32), Vector2(0.82, 0.46),
	Vector2(0.20, 0.62), Vector2(0.80, 0.64),
]

const GOOD_SFX := preload("res://assets/audio/SFX/fruit_drop_good.wav")
const UNLOCK_SFX := preload("res://assets/audio/SFX/unlock_sparkle.wav")
const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")
const PRAISES := {
	"pt": ["09_elogio_muitobem", "10_elogio_parabens", "11_elogio_excelente", "12_elogio_isso"],
	"it": ["09_elogio_moltobene", "10_elogio_perfetto", "11_elogio_ottimo", "12_elogio_esatto"],
}

var _cubs: Array[LostCub] = []
var _line: Array[LostCub] = []
var _arena_enabled := false
var _collected := 0
var _map_size := Vector2.ZERO
var _map_top_left := Vector2.ZERO
var _fire := Vector2.ZERO
var _seats: Array[Vector2] = []
var _time := 0.0
var _idle_t := 0.0
var _nudge_at := NUDGE_FIRST
var _lali_base := Vector2.ZERO

@onready var _veil: ColorRect = %Veil
@onready var _glow: ColorRect = %Glow
@onready var _firefly: FireflyGuide = %Firefly
@onready var _didia: AnimatedSprite2D = %Didia
@onready var _sophy: AnimatedSprite2D = %Sophy
@onready var _lolo: LoloCharacter = %Lolo
@onready var _lali: Sprite2D = %Lali
@onready var _bubble: SpeechBubble = %Bubble
@onready var _counter: CounterPill = %Counter
@onready var _fireworks: Fireworks = %Fireworks
@onready var _ambient: NightAmbient = %Ambient
@onready var _game_root: Control = %GameRoot

func _ready() -> void:
	super()
	_relayout()
	# 6 esconderijos distintos dos 8, sem reposicao
	var spots := range(HIDING_SPOTS.size())
	spots.shuffle()
	for index in CUB_COUNT:
		var cub := LostCub.new()
		cub.animation_name = CUBS[index]
		cub.sprite_width = CUB_WIDTH
		cub.position = _from_cover(HIDING_SPOTS[spots[index]])
		cub.z_index = 2
		_cubs.append(cub)
		_game_root.add_child(cub)
	_firefly.snap_to(_from_cover(FIREFLY_START))
	_intro_routine()

func _relayout() -> void:
	var cover := maxf(size.x / BACKGROUND_SIZE.x, size.y / BACKGROUND_SIZE.y)
	_map_size = BACKGROUND_SIZE * cover
	_map_top_left = (size - _map_size) / 2.0
	_fire = _from_cover(FIRE_ANCHOR)
	_seats.clear()
	for anchor in SEAT_ANCHORS:
		_seats.append(_from_cover(anchor))
	for veil_material in [_veil.material, _glow.material]:
		veil_material.set_shader_parameter("rect_size", size)
		veil_material.set_shader_parameter("fire_center", _fire)
	_didia.position = _from_cover(DIDIA_ANCHOR)
	_sophy.position = _from_cover(SOPHY_ANCHOR)
	_lolo.position = _from_cover(LOLO_ANCHOR)
	_lali_base = _from_cover(LALI_ANCHOR)
	_bubble.position = _from_cover(BUBBLE_ANCHOR) - _bubble.size / 2.0
	_ambient.canvas_size = size
	_fireworks.canvas_size = size

func _from_cover(anchor: Vector2) -> Vector2:
	return _map_top_left + Vector2(anchor.x * _map_size.x, anchor.y * _map_size.y)

func _intro_routine() -> void:
	await _wait(INTRO_DELAY)
	if _stopped():
		return
	await _speak("intro")
	if _stopped():
		return
	_arena_enabled = true

func _speak(clip: String) -> void:
	_bubble.show_bubble()
	_bubble.say(tr("level110." + clip))
	var suffix := "it" if Settings.locale == "it" else "pt"
	if Voice.play_path("res://assets/i18n/DidiaVoice/level110_%s_%s.wav" % [clip, suffix]):
		await Voice.finished
	if _stopped():
		return
	if _bubble._typing:
		await _bubble.typing_finished
	await _wait(INTRO_HOLD)
	if _stopped():
		return
	_bubble.hide_bubble()

func _unhandled_input(event: InputEvent) -> void:
	if not _arena_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_firefly.target = event.position
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_firefly.target = event.position

func _process(delta: float) -> void:
	_time += delta
	var flicker := 1.0 + 0.05 * sin(_time * 9.0) + 0.03 * sin(_time * 23.0)
	for veil_material in [_veil.material, _glow.material]:
		veil_material.set_shader_parameter("light_center", _firefly.position)
		veil_material.set_shader_parameter("flicker", flicker)
	_lali.position = _lali_base + Vector2(0, sin(_time * 2.0) * 5.0)
	if completed or not _arena_enabled:
		return
	_reveal_lit_cubs()
	_steer_line()
	_deliver_arrivals()
	_idle_t += minf(delta, 0.1)
	if _idle_t >= _nudge_at:
		_nudge_at += NUDGE_REPEAT
		_speak("nudge")

func _reveal_lit_cubs() -> void:
	for cub in _cubs:
		if cub.state != LostCub.State.HIDDEN:
			continue
		if _firefly.position.distance_to(cub.position) > REVEAL_RADIUS:
			continue
		cub.reveal()
		_line.append(cub)
		var burst := SPARKLE_BURST.instantiate()
		$Effects.add_child(burst)
		burst.burst(cub.global_position, Color.WHITE, 10, 50.0)
		Audio.play_sfx(UNLOCK_SFX)
		_progress_made()

## Na trilha, cada filhote mira o ponto a (i+1)x110 px atras do vaga-lume.
## Com o vaga-lume na fogueira, todo mundo larga a trilha e corre pro fogo.
func _steer_line() -> void:
	var at_fire := _firefly.position.distance_to(_fire) <= DELIVER_RADIUS
	for i in _line.size():
		var cub := _line[i]
		if at_fire:
			cub.goal = _fire
		else:
			var behind: Variant = _firefly.trail.point_behind((i + 1) * LINE_SPACING)
			if behind != null:
				cub.goal = behind

func _deliver_arrivals() -> void:
	for cub in _line.duplicate():
		if cub.state != LostCub.State.FOLLOWING:
			continue
		if cub.position.distance_to(_fire) > SEAT_RADIUS:
			continue
		_line.erase(cub)
		cub.seat_at(_seats[_collected])
		_handle_seated()

func _handle_seated() -> void:
	_collected += 1
	_counter.set_collected(_collected)
	Audio.play_sfx(GOOD_SFX)
	_react(_collected % 4)
	var suffix := "it" if Settings.locale == "it" else "pt"
	Voice.play("Lali", PRAISES[suffix][randi() % 4])
	_progress_made()
	if _collected < CUB_COUNT:
		return
	_arena_enabled = false
	_victory_routine()

func _victory_routine() -> void:
	await _wait(PARTY_DELAY)
	if not is_inside_tree():
		return
	_fireworks.start()
	for who in 4:
		_react(who)
	await _wait(PARTY_DURATION)
	if not is_inside_tree():
		return
	win()

func _progress_made() -> void:
	_idle_t = 0.0
	_nudge_at = NUDGE_FIRST

# ----- reacoes dos quatro -----

func _react(who: int) -> void:
	match who:
		0:
			_pop(_didia)
		1:
			_lolo.fly()
			get_tree().create_timer(0.8).timeout.connect(_lolo.land)
		2:
			_pop(_lali)
		_:
			_pop(_sophy)

func _pop(target: Node2D) -> void:
	var base := target.scale
	var tween := create_tween()
	tween.tween_property(target, "scale", base * 1.15, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", base, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _stopped() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
