extends LevelBase

## Fase 5 do mundo 1 — "Jogo da Memoria da Didia": vire pares de cartas.
## Preview mostra todas viradas 2.5s. Erro custa estrela a cada 5.

const PAIR_COUNT := 6
const INTRO_DELAY := 0.6
const INTRO_HOLD := 1.0
const PREVIEW_HOLD := 2.5
const FLIP_WAIT := 0.3
const MISMATCH_HOLD := 0.9
const CASCADE_STEP := 0.06
const BACKGROUND_SIZE := Vector2(1264, 720)
const DIDIA_ANCHOR := Vector2(0.1298932, 0.28652513)
const GRID_ANCHOR := Vector2(0.5, 0.375)
const BUBBLE_ANCHOR := Vector2(0.3124125, 0.30842274)
const CARD_NAMES := ["card_monkey", "card_croc", "card_lion", "card_tiger", "card_turtle", "card_elephant"]

const GOOD_SFX := preload("res://assets/audio/SFX/fruit_drop_good.wav")
const BAD_SFX := preload("res://assets/audio/SFX/fruit_drop_oops.wav")

var _accepting := false
var _matched_pairs := 0
var _first_pick: MemoryCard = null
var _cards: Array[MemoryCard] = []

var _map_size := Vector2.ZERO
var _map_top_left := Vector2.ZERO

@onready var _didia: DidiaMemory = %Didia
@onready var _bubble: SpeechBubble = %Bubble
@onready var _reject_a: RejectMarker = %RejectA
@onready var _reject_b: RejectMarker = %RejectB
@onready var _card_root: Control = %GameRoot

func _ready() -> void:
	super()
	var deck: Array = []
	for i in 12:
		deck.append(i / 2)
	deck.shuffle()
	var index := 0
	for child in _card_root.get_children():
		if child is MemoryCard:
			child.pair_id = deck[index]
			child.face = load("res://assets/art/MiniGames/MemoryMeadow/%s.webp" % CARD_NAMES[deck[index]])
			child.pressed_card.connect(_on_card_pressed)
			_cards.append(child)
			index += 1
	resized.connect(_relayout)
	_relayout()
	_opening_routine()

func _relayout() -> void:
	var cover := maxf(size.x / BACKGROUND_SIZE.x, size.y / BACKGROUND_SIZE.y)
	_map_size = BACKGROUND_SIZE * cover
	_map_top_left = (size - _map_size) / 2.0
	for index in _cards.size():
		_cards[index].position = _card_center(index) - _cards[index].size / 2.0
	_didia.position = _from_cover(DIDIA_ANCHOR)
	_bubble.position = Vector2(BUBBLE_ANCHOR.x * size.x, (1.0 - BUBBLE_ANCHOR.y) * size.y) - _bubble.size / 2.0

func _from_cover(anchor: Vector2) -> Vector2:
	return _map_top_left + Vector2(anchor.x * _map_size.x, (1.0 - anchor.y) * _map_size.y)

func _card_center(index: int) -> Vector2:
	var grid_top_left := _from_cover(GRID_ANCHOR) - Vector2(445, 332.5)
	return grid_top_left + Vector2(107.5 + (index % 4) * 225.0, 107.5 + (index / 4) * 225.0)

func _opening_routine() -> void:
	await _wait(INTRO_DELAY)
	if _dead():
		return
	_bubble.show_bubble()
	_bubble.say(tr("level15.intro"))
	var suffix := "it" if Settings.locale == "it" else "pt"
	if Voice.play_path("res://assets/i18n/DidiaVoice/level15_intro_%s.wav" % suffix):
		await Voice.finished
	if _dead():
		return
	if _bubble._typing:
		await _bubble.typing_finished
	await _wait(INTRO_HOLD)
	if _dead():
		return
	_bubble.hide_bubble()
	# preview: todas viradas por um tempo, depois cascata de volta
	for card in _cards:
		card.flip_up()
	await _wait(FLIP_WAIT + PREVIEW_HOLD)
	if _dead():
		return
	for card in _cards:
		card.flip_down()
		await _wait(CASCADE_STEP)
		if _dead():
			return
	await _wait(FLIP_WAIT)
	_accepting = true

func _on_card_pressed(card: MemoryCard) -> void:
	if not _accepting:
		return
	Audio.play_click()
	card.flip_up()
	if _first_pick == null:
		_first_pick = card
		return
	var first := _first_pick
	_first_pick = null
	_resolve_pair(first, card)

func _resolve_pair(a: MemoryCard, b: MemoryCard) -> void:
	_accepting = false
	await _wait(FLIP_WAIT)
	if _dead():
		return
	if a.pair_id == b.pair_id:
		Audio.play_sfx(GOOD_SFX)
		a.set_matched()
		b.set_matched()
		_didia.play_hello()
		_matched_pairs += 1
		if _matched_pairs >= PAIR_COUNT:
			await _wait(0.7)
			win()
			return
		_accepting = true
		return
	Audio.play_sfx(BAD_SFX)
	_reject_a.flash(a.global_position + a.size / 2.0)
	_reject_b.flash(b.global_position + b.size / 2.0)
	await _wait(MISMATCH_HOLD)
	if _dead():
		return
	a.flip_down()
	b.flip_down()
	mistake()
	await _wait(FLIP_WAIT)
	if _dead():
		return
	_accepting = true

func _dead() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
