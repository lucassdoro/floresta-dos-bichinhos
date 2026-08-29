extends LevelBase

## Fase 3 do mundo 1 — "Trilha dos Numeros": toque as pedras na ordem 1..7 e
## o Lolo voa ate o ninho. Erro custa estrela a cada 2.

const FLIGHT_SPEED := 0.25  # fracao de ancora por segundo
const MIN_FLIGHT_TIME := 0.5
const ARC_HEIGHT := 0.05  # fracao da altura do cover
const INTRO_DELAY := 1.0
const INTRO_HOLD := 1.0
const LOLO_CENTER_RISE := 125.5
const BACKGROUND_SIZE := Vector2(1264, 720)
const LOLO_START_ANCHOR := Vector2(0.185, 0.49314812)
const BUBBLE_ANCHOR := Vector2(0.4245, 0.64)
const NEST_ANCHOR := Vector2(0.855, 0.72)
const PLATFORM_ANCHORS: Array[Vector2] = [
	Vector2(0.30, 0.30), Vector2(0.38, 0.52), Vector2(0.46, 0.24),
	Vector2(0.54, 0.46), Vector2(0.62, 0.22), Vector2(0.71, 0.36),
	Vector2(0.76, 0.53),
]

const GOOD_SFX := preload("res://assets/audio/SFX/fruit_drop_good.wav")
const BAD_SFX := preload("res://assets/audio/SFX/fruit_drop_oops.wav")

var _expected := 1
var _accepting := false
var _lolo_at_start := true
var _lolo_on_platform: NumberPlatform = null
var _platforms: Array[NumberPlatform] = []

var _flying := false
var _flight_elapsed := 0.0
var _flight_duration := 0.0
var _flight_start := Vector2.ZERO
var _flight_target := Vector2.ZERO

var _map_size := Vector2.ZERO
var _map_top_left := Vector2.ZERO

@onready var _lolo: LoloCharacter = %Lolo
@onready var _bubble: SpeechBubble = %Bubble
@onready var _reject: RejectMarker = %RejectMarker
@onready var _platform_root: Control = %GameRoot

func _ready() -> void:
	super()
	for child in _platform_root.get_children():
		if child is NumberPlatform:
			_platforms.append(child)
			child.tapped.connect(_on_platform_tapped)
	_randomize_trail_start()
	resized.connect(_relayout)
	_relayout()
	_run_intro()

func _randomize_trail_start() -> void:
	var numbers: Array = [1, 2, 3, 4] if randi() % 2 == 0 else [2, 1, 4, 3]
	for index in 4:
		_platforms[index].set_number(numbers[index])

func _run_intro() -> void:
	await _wait(INTRO_DELAY)
	if _dead():
		return
	_bubble.show_bubble()
	_bubble.say(tr("level13.intro"))
	if Voice.play("Lolo", "01_intro"):
		await Voice.finished
	if _dead():
		return
	if _bubble._typing:
		await _bubble.typing_finished
	await _wait(INTRO_HOLD)
	if _dead():
		return
	_bubble.hide_bubble()
	_accepting = true

func _on_platform_tapped(platform: NumberPlatform) -> void:
	if not _accepting or completed:
		return
	if platform.visited:
		return
	if platform.number == _expected:
		_fly_to_platform(platform)
		return
	_reject.flash(platform.base_position)
	Audio.play_sfx(BAD_SFX)
	mistake()

func _fly_to_platform(platform: NumberPlatform) -> void:
	_accepting = false
	Audio.play_sfx(GOOD_SFX)
	_lolo_at_start = false
	_lolo_on_platform = null
	await _fly(_platform_lolo_target(platform))
	if _dead():
		return
	_lolo_on_platform = platform
	platform.mark_visited()
	platform.bounce()
	_expected += 1
	if _expected > _platforms.size():
		_final_flight()
		return
	_accepting = true

func _final_flight() -> void:
	await _wait(0.4)
	if _dead():
		return
	_lolo_on_platform = null
	await _fly(_from_cover(NEST_ANCHOR) + Vector2(0, 60 - LOLO_CENTER_RISE))
	if _dead():
		return
	win()

func _fly(target: Vector2) -> void:
	_flight_start = _lolo.position
	_flight_target = target
	var anchor_dist := _pos_to_anchor(_flight_start).distance_to(_pos_to_anchor(_flight_target))
	_flight_duration = maxf(MIN_FLIGHT_TIME, anchor_dist / FLIGHT_SPEED)
	_flight_elapsed = 0.0
	_lolo.fly()
	_lolo.face_direction(target.x - _flight_start.x)
	_flying = true
	while _flying:
		await get_tree().process_frame
		if _dead():
			return

func _platform_lolo_target(platform: NumberPlatform) -> Vector2:
	return platform.landing_center() + Vector2(0, -LOLO_CENTER_RISE)

func _process(delta: float) -> void:
	if _flying:
		_flight_elapsed += delta
		var t := clampf(_flight_elapsed / _flight_duration, 0.0, 1.0)
		var s := t * t * (3.0 - 2.0 * t)
		var pos := _flight_start.lerp(_flight_target, s)
		pos.y -= sin(s * PI) * ARC_HEIGHT * _map_size.y
		_lolo.position = pos
		if t >= 1.0:
			_flying = false
			_lolo.face_direction(1)
			_lolo.land()
		return
	if _lolo_on_platform != null:
		_lolo.position = _platform_lolo_target(_lolo_on_platform)

func _from_cover(anchor: Vector2) -> Vector2:
	return _map_top_left + Vector2(anchor.x * _map_size.x, (1.0 - anchor.y) * _map_size.y)

func _pos_to_anchor(pos: Vector2) -> Vector2:
	return Vector2((pos.x - _map_top_left.x) / _map_size.x, 1.0 - (pos.y - _map_top_left.y) / _map_size.y)

func _relayout() -> void:
	var cover := maxf(size.x / BACKGROUND_SIZE.x, size.y / BACKGROUND_SIZE.y)
	_map_size = BACKGROUND_SIZE * cover
	_map_top_left = (size - _map_size) / 2.0
	for index in _platforms.size():
		_platforms[index].base_position = _from_cover(PLATFORM_ANCHORS[index])
	_bubble.position = _from_cover(BUBBLE_ANCHOR) - _bubble.size / 2.0
	if _lolo_at_start:
		_lolo.position = _from_cover(LOLO_START_ANCHOR)

func _dead() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
