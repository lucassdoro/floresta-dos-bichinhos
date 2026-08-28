extends LevelBase

## Fase 9 do mundo 1 — "Bolhas das Letras": a Lali pede uma letra, tres
## bolhas sobem e a crianca toca na certa. Seis acertos fecham a fase.

const INTRO_DELAY := 0.4
const INTRO_HOLD := 0.6
const ASK_DELAY := 0.9
const REASK_DELAY := 1.0
const NEXT_ROUND_DELAY := 1.1
const FLIGHT_DURATION := 0.5
const FLIGHT_ARC := 140.0
const ROUNDS := 6
const BUBBLES_PER_ROUND := 3
const ASK_HIGHLIGHT := Color(0.169, 0.424, 0.69)
# alfabeto comum pt-BR/it em maiusculas: sem J K W X Y
const LETTER_POOL := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "L", "M",
	"N", "O", "P", "Q", "R", "S", "T", "U", "V", "Z"]
const PRAISES := {
	"praise.great": ["09_elogio_muitobem", "09_elogio_moltobene"],
	"praise.congrats": ["10_elogio_parabens", "10_elogio_perfetto"],
	"praise.excellent": ["11_elogio_excelente", "11_elogio_ottimo"],
	"praise.yes": ["12_elogio_isso", "12_elogio_esatto"],
}
const BUBBLE_SPOTS := [Vector2(0.60, 0.537), Vector2(0.74, 0.370), Vector2(0.87, 0.565)]
const BUBBLE_SCENE := preload("res://levels/world1/letter_bubble.tscn")

const POP_SFX := preload("res://assets/audio/SFX/bubble_pop.wav")
const BAD_SFX := preload("res://assets/audio/SFX/fruit_drop_oops.wav")

var _rounds: Array = []
var _found := 0
var _round_open := false
var _ask_countdown := -1.0
var _reask_countdown := -1.0
var _next_round_countdown := -1.0
var _bubbles: Array[LetterBubble] = []

@onready var _counter: CounterPill = %Counter
@onready var _lali: LaliCharacter = %Lali
@onready var _speech: SpeechBubble = %Bubble
@onready var _necklace: PearlNecklace = %Necklace
@onready var _reject: RejectMarker = %RejectMarker
@onready var _ambient: AmbientBubbles = %Ambient
@onready var _game_root: Control = %GameRoot

func _ready() -> void:
	super()
	_build_rounds()
	_ambient.area = Vector2(1920, 1080)
	_intro_routine()

## 6 alvos sem repeticao; cada rodada ganha 2 distratores diferentes do alvo
## e entre si, em ordem embaralhada.
func _build_rounds() -> void:
	var targets := LETTER_POOL.duplicate()
	targets.shuffle()
	for i in ROUNDS:
		var target: String = targets[i]
		var others := LETTER_POOL.filter(func(l: String) -> bool: return l != target)
		others.shuffle()
		var letters: Array = [target, others[0], others[1]]
		letters.shuffle()
		_rounds.append({"target": target, "letters": letters})

func _intro_routine() -> void:
	await _wait(INTRO_DELAY)
	if _dead():
		return
	_speech.show_bubble()
	_speech.say(tr("level19.intro"))
	_spawn_round()
	if Voice.play("Lali", "14_intro_letras"):
		await Voice.finished
	if _dead():
		return
	if _speech._typing:
		await _speech.typing_finished
	await _wait(INTRO_HOLD)
	if _dead():
		return
	_ask_countdown = 0.0

func _spawn_round() -> void:
	if _found >= ROUNDS:
		return
	var round: Dictionary = _rounds[_found]
	for i in BUBBLES_PER_ROUND:
		var bubble: LetterBubble = BUBBLE_SCENE.instantiate()
		bubble.letter = round["letters"][i]
		bubble.rest_position = _spot(BUBBLE_SPOTS[i])
		bubble.tapped.connect(_on_bubble_tapped)
		_bubbles.append(bubble)
		_game_root.add_child(bubble)
	_round_open = true

func _spot(anchor: Vector2) -> Vector2:
	return Vector2(anchor.x * size.x, (1.0 - anchor.y) * size.y)

func _ask() -> void:
	if _found >= ROUNDS:
		return
	var target: String = _rounds[_found]["target"]
	var template: String = tr("level19.ask")
	var start := template.find("{0}")
	_lali.ask()
	if _speech.modulate.a > 0.5:
		_speech.pulse()
	else:
		_speech.show_bubble()
	_speech.say(template.replace("{0}", target), start, start + 1, ASK_HIGHLIGHT)
	Voice.play("Lali", "letra_" + target)

func _on_bubble_tapped(bubble: LetterBubble) -> void:
	if not _round_open or _found >= ROUNDS:
		return
	var target: String = _rounds[_found]["target"]
	if bubble.letter != target:
		mistake()
		bubble.shake()
		_reject.flash(bubble.global_position + bubble.size / 2.0)
		Audio.play_sfx(BAD_SFX)
		_reask_countdown = REASK_DELAY
		return
	var slot := _found
	_found += 1
	_round_open = false
	_reask_countdown = -1.0
	bubble.pop()
	for other in _bubbles:
		if other != bubble and is_instance_valid(other):
			other.fade_out()
	_bubbles.clear()
	Audio.play_sfx(POP_SFX)
	_lali.correct()
	var praise_files: Array = PRAISES.values()[randi() % PRAISES.size()]
	Voice.play("Lali", praise_files[1] if Settings.locale == "it" else praise_files[0])
	_fly_letter(bubble.letter, bubble.global_position + bubble.size / 2.0, slot)

## Letra voando da bolha estourada ate a perola, em arco.
func _fly_letter(letter: String, from: Vector2, slot: int) -> void:
	var label := Label.new()
	label.text = letter
	label.size = Vector2(160, 160)
	label.pivot_offset = label.size / 2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 110)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.87))
	label.add_theme_color_override("font_outline_color", Color(0.33, 0.19, 0.08))
	label.add_theme_constant_override("outline_size", 22)
	label.z_index = 17
	add_child(label)
	var to := _necklace.pearl_center(slot)
	var elapsed := 0.0
	while elapsed < FLIGHT_DURATION:
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / FLIGHT_DURATION, 0.0, 1.0)
		var center := from.lerp(to, t) - Vector2(0, sin(t * PI) * FLIGHT_ARC)
		label.position = center - label.size / 2.0
		label.scale = Vector2.ONE * (1.0 - 0.5 * t)
		await get_tree().process_frame
		if not is_inside_tree():
			return
	label.queue_free()
	_necklace.set_found(slot, letter)
	_counter.set_collected(_found)
	if _found >= ROUNDS:
		_speech.hide_bubble()
		await _wait(0.8)
		win()
		return
	_next_round_countdown = NEXT_ROUND_DELAY

func _process(delta: float) -> void:
	if completed:
		return
	if _ask_countdown >= 0.0:
		_ask_countdown += delta
		var all_settled := true
		for bubble in _bubbles:
			if is_instance_valid(bubble) and not bubble.is_settled():
				all_settled = false
				break
		if all_settled and _ask_countdown >= ASK_DELAY:
			_ask_countdown = -1.0
			_ask()
	if _reask_countdown > 0.0:
		_reask_countdown -= delta
		if _reask_countdown <= 0.0:
			_ask()
	if _next_round_countdown > 0.0:
		_next_round_countdown -= delta
		if _next_round_countdown <= 0.0:
			_next_round_countdown = -1.0
			_spawn_round()
			_ask_countdown = 0.0

func _dead() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
