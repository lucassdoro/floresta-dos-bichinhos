extends Control

## Modo Livre: toda fase do LevelCatalog, filtrada por busca, habilidade e mecanica.

const CARD_SCENE := preload("res://ui/free_mode/level_card.tscn")
const MENU_SCENE := "res://ui/menu/main_menu.tscn"
const MIN_CARD_WIDTH := 400.0
const CARD_ENTER_TIME := 0.3
const CARD_STAGGER := 0.04
const CARD_START_SCALE := 0.9

var _chip_group := ButtonGroup.new()

@onready var _search: LineEdit = %SearchField
@onready var _mechanic: OptionButton = %MechanicDropdown
@onready var _chips: Array[BaseButton] = [%ChipColors, %ChipNumbers, %ChipLetters, %ChipMemory, %ChipCoordination]
@onready var _scroll: ScrollContainer = %Scroll
@onready var _grid: GridContainer = %Grid
@onready var _empty: Label = %EmptyLabel

func _ready() -> void:
	%BackButton.pressed.connect(SceneLoader.go_to.bind(MENU_SCENE))
	_chip_group.allow_unpress = true
	for chip in _chips:
		chip.button_group = _chip_group
		# ButtonGroup.pressed nao dispara ao desligar o chip aceso; toggled dispara nos dois
		chip.toggled.connect(func(_on: bool) -> void: _refresh())
	_search.text_changed.connect(func(_text: String) -> void: _refresh())
	_fill_mechanics()
	_mechanic.item_selected.connect(func(_index: int) -> void: _refresh())
	_scroll.resized.connect(_update_columns)
	_update_columns()
	_refresh()

func _fill_mechanics() -> void:
	_mechanic.add_item("free_mode.all")
	for key in LevelInfo.MECHANIC_KEYS:
		_mechanic.add_item(key)
	_mechanic.select(0)

func _update_columns() -> void:
	_grid.columns = maxi(1, floori(_scroll.size.x / MIN_CARD_WIDTH))

func _selected_skill() -> int:
	return _chips.find(_chip_group.get_pressed_button())

func _refresh() -> void:
	for old_card in _grid.get_children():
		_grid.remove_child(old_card)
		old_card.queue_free()
	var levels := LevelCatalog.filter(_search.text, _selected_skill(), _mechanic.selected - 1)
	_empty.visible = levels.is_empty()
	for index in levels.size():
		var card: LevelCard = CARD_SCENE.instantiate()
		_grid.add_child(card)
		card.setup(levels[index])
		card.chosen.connect(FreePlay.start)
		_enter(card, index)

func _enter(card: Control, index: int) -> void:
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * CARD_START_SCALE
	var delay := index * CARD_STAGGER
	var tween := card.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, CARD_ENTER_TIME).set_delay(delay)
	tween.tween_property(card, "scale", Vector2.ONE, CARD_ENTER_TIME).set_delay(delay)
