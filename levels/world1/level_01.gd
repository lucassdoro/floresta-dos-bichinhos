extends LevelBase

## Fase 1 do mundo 1 — "O Cafe da Manha da Didia": arraste as frutas boas pra
## cesta (meta 10), evite as estragadas.

const GOOD_TARGET := 10
const BAD_CHANCE := 0.25
const INITIAL_BAD := 2
const MAX_BAD := 4
const RESPAWN_DELAY := 0.25

# pontos de spawn relativos ao centro, y pra cima (como na referencia)
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(-359, 65), Vector2(-44.542, 121), Vector2(267, 75),
	Vector2(211, -75), Vector2(-601, -150), Vector2(-158, -75),
	Vector2(146, -312), Vector2(-231, -333), Vector2(552, -76),
]

# textura, boa?, largura
const FRUIT_DEFS := [
	["res://assets/art/MiniGames/FruitBreakfast/fruit_apple.webp", true, 150.0],
	["res://assets/art/MiniGames/FruitBreakfast/fruit_banana.webp", true, 200.0],
	["res://assets/art/MiniGames/FruitBreakfast/fruit_strawberry.webp", true, 150.0],
	["res://assets/art/MiniGames/FruitBreakfast/fruit_banana_peel.webp", false, 200.0],
	["res://assets/art/MiniGames/FruitBreakfast/fruit_apple_core.webp", false, 115.0],
]

var _collected := 0
var _bad_spawned := 0
var _good_defs: Array = []
var _bad_defs: Array = []

@onready var _basket: SortingBasket = %Basket
@onready var _counter: CounterPill = %Counter
@onready var _game_root: Control = %GameRoot

func _ready() -> void:
	super()
	for def in FRUIT_DEFS:
		if def[1]:
			_good_defs.append(def)
		else:
			_bad_defs.append(def)
	resized.connect(_relayout)
	_relayout()
	_start_spawning()

func _relayout() -> void:
	_basket.position = from_center(Vector2(600, -330)) - _basket.size / 2.0
	for item in _game_root.get_children():
		if item is DraggableItem:
			item.home_position = from_center(item.home_offset) - item.size / 2.0
			if item.is_idle:
				item.position = item.home_position

func _start_spawning() -> void:
	var bad_indices := {}
	while bad_indices.size() < INITIAL_BAD:
		bad_indices[randi() % SPAWN_POINTS.size()] = true
	for index in SPAWN_POINTS.size():
		_spawn_at(index, bad_indices.has(index))

func _spawn_at(point_index: int, spawn_bad: bool) -> void:
	if completed:
		return
	var defs := _bad_defs if spawn_bad else _good_defs
	var def: Array = defs[randi() % defs.size()]
	var texture: Texture2D = load(def[0])
	var width: float = def[2]
	var is_good: bool = def[1]

	var item := DraggableItem.new()
	item.size = Vector2(width, width * texture.get_height() / texture.get_width())
	item.baskets = [_basket]
	item.accepts = func(_basket_hit: SortingBasket) -> bool: return is_good
	item.home_offset = SPAWN_POINTS[point_index]
	item.setup(texture)
	item.home_position = from_center(item.home_offset) - item.size / 2.0
	item.position = item.home_position
	item.collected.connect(_on_collected.bind(point_index))
	item.item_mistake.connect(func(_item: DraggableItem) -> void: mistake())
	if not is_good:
		_bad_spawned += 1
	_game_root.add_child(item)

func _on_collected(_item: DraggableItem, point_index: int) -> void:
	if completed:
		return
	_collected += 1
	_counter.set_collected(_collected)
	if _collected >= GOOD_TARGET:
		win()
		return
	_schedule_respawn(point_index)

func _schedule_respawn(point_index: int) -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if completed or not is_inside_tree():
		return
	_spawn_at(point_index, _roll_bad_fruit())

func _roll_bad_fruit() -> bool:
	if _bad_spawned >= MAX_BAD:
		return false
	return randf() < BAD_CHANCE
