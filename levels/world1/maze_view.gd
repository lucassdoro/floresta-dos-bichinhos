class_name MazeView
extends Node2D

## Desenha as paredes de sebe e faz a ponte celula <-> tela. Tambem captura o
## dedo: converte o ponteiro pra coordenada local e emite (celula, is_press).

signal pointer_cell(cell: Vector2i, is_press: bool)

const PITCH := 112.0
const WALL := 40.0
const CORRIDOR := 72.0
const COLUMNS := 14
const ROWS := 6
const MAZE_WIDTH := COLUMNS * PITCH + WALL
const MAZE_HEIGHT := ROWS * PITCH + WALL
const TILE_SIZE := 40.0
const INPUT_PAD := 400.0
const HEDGE := preload("res://assets/art/MiniGames/SeedMaze/hedge_tile.webp")
const SEAL := preload("res://assets/art/MiniGames/SeedMaze/bush_seal.webp")
const POT := preload("res://assets/art/MiniGames/SeedMaze/seed_pot.webp")

var grid: MazeLogic = null
var snap_anchor := Vector2i.ZERO
var idle_seconds := 0.0

var _enabled := false
var _pressing := false
var _wall_rects: Array[Rect2] = []
var _hedge_texture: ImageTexture

func setup(maze: MazeLogic) -> void:
	grid = maze
	snap_anchor = maze.entrance
	# a sebe de 128px aparece em tiles de 40 (ppu 3.2): reduz uma vez
	var image := HEDGE.get_image()
	if image.is_compressed():
		image.decompress()
	image.resize(int(TILE_SIZE), int(TILE_SIZE), Image.INTERPOLATE_LANCZOS)
	_hedge_texture = ImageTexture.create_from_image(image)
	_build_walls()
	var pot := Sprite2D.new()
	pot.texture = POT
	pot.scale = Vector2.ONE * (76.0 / POT.get_width())
	pot.position = cell_to_local(grid.exit) + Vector2(CORRIDOR / 2.0 + WALL / 2.0, 0)
	pot.z_index = 2
	add_child(pot)
	queue_redraw()

func set_enabled(value: bool) -> void:
	_enabled = value
	if value:
		idle_seconds = 0.0

func cancel_active_pointer() -> void:
	_pressing = false

func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(76.0 + PITCH * cell.x, 76.0 + PITCH * (ROWS - 1 - cell.y))

func try_local_to_cell(local: Vector2) -> Variant:
	if _outside(local):
		return null
	var column := clampi(roundi((local.x - 76.0) / PITCH), 0, COLUMNS - 1)
	var row_from_top := clampi(roundi((local.y - 76.0) / PITCH), 0, ROWS - 1)
	return Vector2i(column, ROWS - 1 - row_from_top)

func try_snap_cell(local: Vector2) -> Variant:
	if _outside(local):
		return null
	var u := (local.x - 76.0) / PITCH
	var v := (local.y - 76.0) / PITCH
	var column := clampi(_snap_axis(u, snap_anchor.x), 0, COLUMNS - 1)
	var row_from_top := clampi(_snap_axis(v, ROWS - 1 - snap_anchor.y), 0, ROWS - 1)
	return Vector2i(column, ROWS - 1 - row_from_top)

func _outside(local: Vector2) -> bool:
	return local.x < -WALL or local.x > MAZE_WIDTH + WALL \
		or local.y < -WALL or local.y > MAZE_HEIGHT + WALL

func _snap_axis(value: float, current: int) -> int:
	if value > current + 0.4:
		return current + 1
	if value < current - 0.4:
		return current - 1
	return current

func add_seal(divergence: Vector2i, branch_start: Vector2i) -> void:
	var seal := Sprite2D.new()
	seal.texture = SEAL
	seal.scale = Vector2.ONE * (CORRIDOR / SEAL.get_width())
	seal.position = (cell_to_local(divergence) + cell_to_local(branch_start)) / 2.0
	seal.z_index = 2
	add_child(seal)

# ----- paredes -----

func _build_walls() -> void:
	_wall_rects.clear()
	for i in range(2 * COLUMNS + 1):
		for j in range(2 * ROWS + 1):
			if not _is_wall_block(i, j):
				continue
			_wall_rects.append(Rect2(_block_origin(i), _block_origin(j), _block_size(i), _block_size(j)))

func _block_origin(i: int) -> float:
	return (i / 2) * PITCH + (WALL if i % 2 == 1 else 0.0)

func _block_size(i: int) -> float:
	return WALL if i % 2 == 0 else CORRIDOR

func _cell_j(row: int) -> int:
	return 2 * (ROWS - 1 - row) + 1

func _row_from_j(j: int) -> int:
	return ROWS - 1 - (j - 1) / 2

func _is_wall_block(i: int, j: int) -> bool:
	if i % 2 == 1 and j % 2 == 1:
		return false
	var is_border := i == 0 or i == 2 * COLUMNS or j == 0 or j == 2 * ROWS
	if is_border:
		if i == 0 and j == _cell_j(grid.entrance.y):
			return false
		if i == 2 * COLUMNS and j == _cell_j(grid.exit.y):
			return false
		return true
	if i % 2 == 0 and j % 2 == 1:
		var r := _row_from_j(j)
		return not grid.is_open(Vector2i(i / 2 - 1, r), Vector2i(i / 2, r))
	if i % 2 == 1 and j % 2 == 0:
		var c := (i - 1) / 2
		return not grid.is_open(Vector2i(c, _row_from_j(j - 1)), Vector2i(c, _row_from_j(j + 1)))
	return _is_wall_block(i - 1, j) or _is_wall_block(i + 1, j) \
		or _is_wall_block(i, j - 1) or _is_wall_block(i, j + 1)

func _draw() -> void:
	if _hedge_texture == null:
		return
	for rect in _wall_rects:
		draw_texture_rect(_hedge_texture, rect, true)

# ----- input -----

func _process(delta: float) -> void:
	if _enabled:
		idle_seconds += delta

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local := to_local(event.position)
			if local.x < -INPUT_PAD or local.x > MAZE_WIDTH + INPUT_PAD \
				or local.y < -INPUT_PAD or local.y > MAZE_HEIGHT + INPUT_PAD:
				return
			_pressing = true
			_report(local, true)
		else:
			_pressing = false
	elif event is InputEventMouseMotion and _pressing:
		_report(to_local(event.position), false)

func _report(local: Vector2, is_press: bool) -> void:
	idle_seconds = 0.0
	var cell: Variant = try_local_to_cell(local) if is_press else try_snap_cell(local)
	if cell == null:
		return
	pointer_cell.emit(cell, is_press)
