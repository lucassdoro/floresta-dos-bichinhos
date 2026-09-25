extends LevelBase

## Fase 4 do mundo 1 — "Quebra-cabeca da Sophy": arraste as 16 pecas da
## bandeja rolavel pro tabuleiro. Erro no encaixe custa estrela a cada 3.
## O "corte" da foto e' um shader por peca (mascara + regiao da foto).

const GRID := 4
const PHOTO_COUNT := 2
const CELL_SIZE := 107.19539
const HALF_BOARD := 214.39078
const SNAP_RADIUS := 53.5977
const INTRO_DELAY := 0.6
const INTRO_HOLD := 1.0
const SHOWCASE_HOLD := 5.0
const TRAY_VIEWPORT := Vector2(388, 500)
const DECK_PATH := "user://puzzle14_deck.cfg"

const GOOD_SFX := preload("res://assets/audio/SFX/fruit_drop_good.wav")
const BAD_SFX := preload("res://assets/audio/SFX/fruit_drop_oops.wav")
const STAR_CHIME := preload("res://assets/audio/SFX/star_chime.wav")

var _pieces: Array[PuzzlePiece] = []
var _tray_order: Array[PuzzlePiece] = []
var _filled := {}
var _photo: Texture2D = null
var _photo_region_origin := Vector2.ZERO
var _photo_region_scale := Vector2.ONE
var _scroll_y := 0.0
var _intro_done := false
var _cut_done := false

@onready var _board_layer: Control = %BoardLayer
@onready var _tray_content: Control = %TrayContent
@onready var _drag_layer: Control = %DragLayer
@onready var _ghost_photo: TextureRect = %GhostPhoto
@onready var _sophy: AnimatedSprite2D = %Sophy
@onready var _bubble: SpeechBubble = %Bubble
@onready var _reject: RejectMarker = %RejectMarker

func _ready() -> void:
	super()
	for child in _tray_content.get_children():
		if child is PuzzlePiece:
			child.controller = self
			_pieces.append(child)
	_tray_order = _pieces.duplicate()
	_tray_order.shuffle()
	for index in _tray_order.size():
		var piece := _tray_order[index]
		piece.position = _tray_cell_center(index) - piece.size / 2.0
	_intro_routine()
	_setup_routine()

func accepting_input() -> bool:
	return _intro_done and _cut_done and not completed

# peca rolada pra fora do viewport nao recebe toque
func is_piece_hittable(piece: PuzzlePiece) -> bool:
	if piece.is_placed or piece.get_parent() != _tray_content:
		return true
	var viewport_y := _scroll_y + piece.position.y + piece.size.y / 2.0
	return viewport_y >= 0.0 and viewport_y <= TRAY_VIEWPORT.y

func _setup_routine() -> void:
	var index := _pick_photo_index()
	_photo = load("res://assets/puzzle/PuzzleImages/puzzle_%d.webp" % (index + 1))
	var photo_size := _photo.get_size()
	var side := minf(photo_size.x, photo_size.y)
	var square_origin := (photo_size - Vector2(side, side)) / 2.0
	# regiao (em UV da foto) da sub-janela 384 da peca dentro do quadrado central
	for piece in _pieces:
		var origin_px := square_origin + Vector2(piece.col * 256.0 - 64.0, piece.row * 256.0 - 64.0) * (side / 1024.0)
		var size_px := Vector2(384, 384) * (side / 1024.0)
		piece.set_photo(_photo, origin_px / photo_size, size_px / photo_size)
	_ghost_photo.texture = _photo
	var ghost_material: ShaderMaterial = _ghost_photo.material
	ghost_material.set_shader_parameter("photo", _photo)
	ghost_material.set_shader_parameter("region_origin", square_origin / photo_size)
	ghost_material.set_shader_parameter("region_size", Vector2(side, side) / photo_size)
	ghost_material.set_shader_parameter("revealed", 1.0)
	# pulso da bandeja enquanto "corta" + revelacao
	var pulse := create_tween()
	pulse.tween_interval(0.7)
	pulse.tween_callback(_reveal_pieces)

func _reveal_pieces() -> void:
	for piece in _pieces:
		piece.reveal()
	create_tween().tween_property(_ghost_photo, "modulate:a", 0.25, PuzzlePiece.REVEAL_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cut_done = true

func _pick_photo_index() -> int:
	var config := ConfigFile.new()
	config.load(DECK_PATH)
	var deck: Array = config.get_value("deck", "order", [])
	if deck.is_empty():
		for i in PHOTO_COUNT:
			deck.append(i)
		deck.shuffle()
	var chosen: int = deck.pop_front()
	config.set_value("deck", "order", deck)
	config.save(DECK_PATH)
	return chosen

func _intro_routine() -> void:
	await _wait(INTRO_DELAY)
	if _dead():
		return
	_bubble.show_bubble()
	_bubble.say(tr("level14.intro"))
	if Voice.play("Sophy", "01_intro"):
		await Voice.finished
	if _dead():
		return
	if _bubble._typing:
		await _bubble.typing_finished
	await _wait(INTRO_HOLD)
	if _dead():
		return
	_bubble.hide_bubble()
	_intro_done = true

# ----- drag -----

func begin_piece_drag(piece: PuzzlePiece, pointer: Vector2) -> void:
	var ghost := TextureRect.new()
	ghost.texture = piece.texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.material = piece.material
	ghost.size = Vector2.ONE * PuzzlePiece.BOARD_SIZE
	ghost.scale = Vector2.ONE * PuzzlePiece.DRAG_SCALE
	ghost.pivot_offset = ghost.size / 2.0
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.global_position = pointer - ghost.size / 2.0
	piece.ghost = ghost
	piece.modulate.a = 0.0
	_drag_layer.add_child(ghost)

func drag_piece_to(piece: PuzzlePiece, pointer: Vector2) -> void:
	if piece.ghost == null:
		return
	piece.ghost.global_position = pointer - piece.ghost.size / 2.0
	_try_magnet_snap(piece)

func scroll_tray_by(dy: float) -> void:
	var rows := ceili(_tray_order.size() / 2.0)
	var content_height := maxf(TRAY_VIEWPORT.y, rows * 199.0 - 10.0)
	var min_scroll := minf(0.0, -(content_height - TRAY_VIEWPORT.y))
	_scroll_y = clampf(_scroll_y + dy, min_scroll, 0.0)
	_tray_content.position.y = _scroll_y

func _try_magnet_snap(piece: PuzzlePiece) -> void:
	if mistakes < mistakes_per_star * 2:
		return
	if _filled.has(_cell_key(piece.row, piece.col)):
		return
	if _ghost_center(piece).distance_to(_slot_global(piece.row, piece.col)) > SNAP_RADIUS:
		return
	_place_piece(piece)

func on_piece_dropped(piece: PuzzlePiece) -> void:
	var drop_center := _ghost_center(piece)
	_end_ghost(piece)
	var nearest := _nearest_free_slot(drop_center)
	if nearest == Vector2i(-1, -1):
		_return_to_tray(piece)
		return
	if nearest.x == piece.row and nearest.y == piece.col:
		_place_piece(piece)
		return
	Audio.play_sfx(BAD_SFX)
	_reject.flash(_slot_global(nearest.x, nearest.y))
	mistake()
	_return_to_tray(piece)

func _ghost_center(piece: PuzzlePiece) -> Vector2:
	if piece.ghost == null:
		return piece.global_position + piece.size / 2.0
	return piece.ghost.global_position + piece.ghost.size / 2.0

func _end_ghost(piece: PuzzlePiece) -> void:
	if piece.ghost != null:
		piece.ghost.queue_free()
		piece.ghost = null
	piece.modulate.a = 1.0

func _nearest_free_slot(global_point: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := SNAP_RADIUS
	for r in GRID:
		for c in GRID:
			if _filled.has(_cell_key(r, c)):
				continue
			var dist := global_point.distance_to(_slot_global(r, c))
			if dist <= best_dist:
				best_dist = dist
				best = Vector2i(r, c)
	return best

func _place_piece(piece: PuzzlePiece) -> void:
	_end_ghost(piece)
	_filled[_cell_key(piece.row, piece.col)] = true
	Audio.play_sfx(GOOD_SFX)
	piece.is_placed = true
	_tray_order.erase(piece)
	_reparent_to_board.call_deferred(piece)
	_reflow_tray()
	if _filled.size() >= GRID * GRID:
		_victory_routine()

func _reparent_to_board(piece: PuzzlePiece) -> void:
	piece.get_parent().remove_child(piece)
	_board_layer.add_child(piece)
	piece.size = Vector2.ONE * PuzzlePiece.BOARD_SIZE
	piece.pivot_offset = piece.size / 2.0
	piece.position = _slot_board_local(piece.row, piece.col) - piece.size / 2.0
	piece.scale = Vector2.ONE * 1.12
	piece.modulate.a = 1.0
	create_tween().tween_property(piece, "scale", Vector2.ONE, 0.18)

func _return_to_tray(piece: PuzzlePiece) -> void:
	piece.is_busy = true
	var index := _tray_order.find(piece)
	var target := _tray_cell_center(index) - Vector2.ONE * PuzzlePiece.TRAY_SIZE / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(piece, "position", target, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(piece, "size", Vector2.ONE * PuzzlePiece.TRAY_SIZE, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(func() -> void: piece.is_busy = false)

func _reflow_tray() -> void:
	for index in _tray_order.size():
		var piece := _tray_order[index]
		if piece.is_placed or piece.is_busy or piece.get_parent() != _tray_content:
			continue
		var target := _tray_cell_center(index) - piece.size / 2.0
		create_tween().tween_property(piece, "position", target, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ----- vitoria + showcase -----

func _victory_routine() -> void:
	await _wait(0.7)
	if not is_inside_tree():
		return
	await _showcase()
	if not is_inside_tree():
		return
	win()

func _showcase() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var photo := TextureRect.new()
	photo.texture = _ghost_photo.texture
	photo.material = _ghost_photo.material
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.size = Vector2.ONE * 428.782
	photo.global_position = _board_layer.global_position + _board_layer.size / 2.0 - photo.size / 2.0
	add_child(photo)
	Audio.play_sfx(STAR_CHIME)
	var full := Vector2.ONE * size.y * 0.7
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dim, "color:a", 0.55, 0.5)
	tween.tween_property(photo, "size", full, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(photo, "position", size / 2.0 - full / 2.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(0.5 + SHOWCASE_HOLD)
	if not is_inside_tree():
		return
	var back := create_tween().set_parallel(true)
	back.tween_property(dim, "color:a", 0.0, 0.5)
	back.tween_property(photo, "size", Vector2.ONE * 428.782, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(photo, "position", _board_layer.global_position + _board_layer.size / 2.0 - Vector2.ONE * 214.391, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(0.5)
	dim.queue_free()
	photo.queue_free()

# ----- geometria -----

func _cell_key(row: int, col: int) -> int:
	return row * GRID + col

func _slot_board_local(row: int, col: int) -> Vector2:
	return _board_layer.size / 2.0 + Vector2(
		-HALF_BOARD + CELL_SIZE * (col + 0.5),
		-HALF_BOARD + CELL_SIZE * (row + 0.5))

func _slot_global(row: int, col: int) -> Vector2:
	return _board_layer.global_position + _slot_board_local(row, col)

func _tray_cell_center(index: int) -> Vector2:
	return Vector2(TRAY_VIEWPORT.x / 2.0 + (index % 2 - 0.5) * 199.0, 94.5 + (index / 2) * 199.0)

func _dead() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
