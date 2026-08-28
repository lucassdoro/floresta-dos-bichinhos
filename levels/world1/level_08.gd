extends LevelBase

## Fase 8 do mundo 1 — "Jardim Colorido": colher as 9 flores do campo e
## soltar cada uma na cesta da cor dela. Tentativa errada conta sempre.

const FLOWER_TOTAL := 9
const BASKET_SCALE := 0.75
const FLOWER_WIDTH := 120.0
const JITTER_X := 22
const JITTER_Y := 18
const TILT_DEGREES := 8.0
const SWAY_DEGREES := 2.5
const INTRO_DELAY := 0.4
const INTRO_HOLD := 0.8
const COLORS := ["pink", "blue", "amber"]
const BUBBLE_ANCHOR := Vector2(0.3229, 0.2593)

# offsets do centro do canvas, y pra cima
const BASKET_SPOTS := [Vector2(-260, -390), Vector2(120, -390), Vector2(500, -390)]
# grade 3x3 com linhas alternadas deslocadas: parece campo, nao tabela
const FIELD_SPOTS := [
	Vector2(-480, 120), Vector2(-80, 120), Vector2(320, 120),
	Vector2(-360, -30), Vector2(40, -30), Vector2(440, -30),
	Vector2(-480, -180), Vector2(-80, -180), Vector2(320, -180),
]

var _collected := 0
var _basket_colors: Array = []
var _baskets: Array[SortingBasket] = []

@onready var _counter: CounterPill = %Counter
@onready var _bubble: SpeechBubble = %Bubble
@onready var _game_root: Control = %GameRoot

func _ready() -> void:
	super()
	# ordem das cores embaralhada por partida: senao a crianca decora a
	# posicao da cesta e para de olhar a cor
	_basket_colors = COLORS.duplicate()
	_basket_colors.shuffle()
	for index in 3:
		var basket: SortingBasket = _game_root.get_node("Basket" + str(index + 1))
		basket.set_badge(load("res://assets/art/MiniGames/FlowerGarden/badge_%s.webp" % _basket_colors[index]))
		_baskets.append(basket)
	resized.connect(_relayout)
	_relayout()
	_plant_field()
	_intro_routine()

func _relayout() -> void:
	for index in 3:
		_baskets[index].position = from_center(BASKET_SPOTS[index]) - _baskets[index].size / 2.0
	_bubble.position = Vector2(BUBBLE_ANCHOR.x * size.x, (1.0 - BUBBLE_ANCHOR.y) * size.y) - _bubble.size / 2.0
	for item in _game_root.get_children():
		if item is DraggableItem:
			item.home_position = from_center(item.home_offset) - item.size / 2.0
			if item.is_idle:
				item.position = item.home_position

func _plant_field() -> void:
	# exatamente 3 de cada cor, embaralhadas: a contagem nunca sai torta
	var field: Array = []
	for color in COLORS:
		for i in 3:
			field.append(color)
	field.shuffle()
	for index in field.size():
		var color: String = field[index]
		var spot: Vector2 = FIELD_SPOTS[index] + Vector2(
			randi_range(-JITTER_X, JITTER_X), randi_range(-JITTER_Y, JITTER_Y))
		var texture: Texture2D = load("res://assets/art/MiniGames/FlowerGarden/flower_%s.webp" % color)
		var flower := DraggableItem.new()
		var aspect := float(texture.get_width()) / texture.get_height()
		flower.size = Vector2(FLOWER_WIDTH, FLOWER_WIDTH / aspect)
		flower.baskets = _baskets
		flower.accepts = func(basket: SortingBasket) -> bool:
			return _basket_colors[_baskets.find(basket)] == color
		flower.home_offset = spot
		flower.tilt_degrees = randf_range(-TILT_DEGREES, TILT_DEGREES)
		flower.sway_degrees = SWAY_DEGREES
		flower.counts_every_mistake = true
		flower.setup(texture)
		flower.home_position = from_center(spot) - flower.size / 2.0
		flower.position = flower.home_position
		flower.collected.connect(_on_collected)
		flower.item_mistake.connect(func(_item: DraggableItem) -> void: mistake())
		_game_root.add_child(flower)

func _on_collected(_item: DraggableItem) -> void:
	if completed:
		return
	_collected += 1
	_counter.set_collected(_collected)
	if _collected >= FLOWER_TOTAL:
		win()

func _intro_routine() -> void:
	await _wait(INTRO_DELAY)
	if _dead():
		return
	_bubble.show_bubble()
	_bubble.say(tr("level18.intro"))
	var suffix := "it" if Settings.locale == "it" else "pt"
	if Voice.play_path("res://assets/i18n/DidiaVoice/level18_intro_%s.wav" % suffix):
		await Voice.finished
	if _dead():
		return
	if _bubble._typing:
		await _bubble.typing_finished
	await _wait(INTRO_HOLD)
	if _dead():
		return
	_bubble.hide_bubble()

func _dead() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
