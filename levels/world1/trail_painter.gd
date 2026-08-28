class_name TrailPainter
extends Node2D

## Desenha a trilha de terra celula a celula: cresce cada segmento, deixa
## pegada, aponta a seta na ponta, mostra pegadas fantasma nas dicas e
## rebobina quando entra num beco.

const STEP_DURATION := 0.08
const CORRIDOR := 72.0
const SHAKE_DURATION := 0.3
const PULSE_SCALE := 1.15
const DIRT := preload("res://assets/art/MiniGames/SeedMaze/trail_dirt.webp")
const FOOTPRINT := preload("res://assets/art/MiniGames/SeedMaze/footprint_bird.webp")
const GHOST := preload("res://assets/art/MiniGames/SeedMaze/footprint_ghost.webp")

var maze_view: MazeView = null
var arrow: Sprite2D = null

var _steps: Array = []  # [{cell, from, length_atual, full, dir}]
var _queue: Array[Vector2i] = []
var _ghosts: Array[Sprite2D] = []
var _threshold_length := 0.0

var _growing := false
var _grow_t := 0.0

var _rewinding := false
var _rewind_t := 0.0
var _rewind_per_cell := 0.09
var _rewind_target := 0

var _shake_t := -1.0
var _arrow_angle := 0.0
var _arrow_scale := 1.0

func is_draining() -> bool:
	return _growing or not _queue.is_empty() or _rewinding

func reset(entrance: Vector2i) -> void:
	_steps = [{"cell": entrance}]
	_queue.clear()
	clear_ghost_hint()
	_growing = false
	_rewinding = false
	_threshold_length = 0.0
	_place_arrow(entrance, entrance, true)
	queue_redraw()

func enqueue(cells: Array[Vector2i]) -> void:
	_queue.append_array(cells)

func rewind_to(cell: Vector2i, max_duration: float) -> void:
	_growing = false
	_queue.clear()
	var target_index := -1
	for i in _steps.size():
		if _steps[i]["cell"] == cell:
			target_index = i
			break
	if target_index < 0 or target_index >= _steps.size() - 1:
		return
	var to_remove := _steps.size() - 1 - target_index
	_rewind_per_cell = minf(0.09, max_duration / to_remove)
	_rewind_target = target_index
	_rewinding = true
	_rewind_t = 0.0

func show_ghost_hint(cells: Array) -> void:
	clear_ghost_hint()
	for cell in cells:
		var ghost := Sprite2D.new()
		ghost.texture = GHOST
		ghost.scale = Vector2.ONE * (36.0 / GHOST.get_width())
		ghost.position = maze_view.cell_to_local(cell)
		ghost.z_index = 5
		_ghosts.append(ghost)
		add_child(ghost)

func clear_ghost_hint() -> void:
	for ghost in _ghosts:
		ghost.queue_free()
	_ghosts.clear()

func shake_arrow() -> void:
	_shake_t = 0.0

func pulse_arrow(on: bool) -> void:
	_arrow_scale = PULSE_SCALE if on else 1.0

# ----- loop -----

func _process(delta: float) -> void:
	if _rewinding:
		_update_rewind(delta)
	elif _growing:
		_update_grow(delta)
	elif not _queue.is_empty():
		_start_grow(_queue.pop_front())
	_update_arrow(delta)

func _start_grow(to: Vector2i) -> void:
	var from: Vector2i = _steps.back()["cell"]
	if _steps.size() == 1:
		var door := maze_view.cell_to_local(from)
		_threshold_length = door.x + 36.0 + 14.0
	var from_p := maze_view.cell_to_local(from)
	var to_p := maze_view.cell_to_local(to)
	var direction := (to_p - from_p).normalized()
	_steps.append({
		"cell": to,
		"from": from,
		"start": from_p - direction * (CORRIDOR / 2.0),
		"dir": direction,
		"full": (to_p - from_p).length() + CORRIDOR,
		"length": CORRIDOR,
	})
	_growing = true
	_grow_t = 0.0
	queue_redraw()

func _update_grow(delta: float) -> void:
	_grow_t += delta
	var step: Dictionary = _steps.back()
	var t := clampf(_grow_t / STEP_DURATION, 0.0, 1.0)
	var smooth := t * t * (3.0 - 2.0 * t)
	step["length"] = CORRIDOR + (step["full"] - CORRIDOR) * smooth
	queue_redraw()
	if _grow_t < STEP_DURATION:
		return
	step["length"] = step["full"]
	var footprint := Sprite2D.new()
	footprint.texture = FOOTPRINT
	footprint.scale = Vector2.ONE * (36.0 / FOOTPRINT.get_width())
	footprint.position = maze_view.cell_to_local(step["cell"])
	footprint.z_index = 2
	add_child(footprint)
	step["footprint"] = footprint
	_place_arrow(step["from"], step["cell"], false)
	_growing = false

func _update_rewind(delta: float) -> void:
	_rewind_t += delta
	if _rewind_t < _rewind_per_cell:
		return
	_rewind_t -= _rewind_per_cell
	if _steps.size() - 1 <= _rewind_target:
		_rewinding = false
		if _steps.size() == 1:
			_threshold_length = 0.0
		queue_redraw()
		return
	var removed: Dictionary = _steps.pop_back()
	if removed.has("footprint"):
		removed["footprint"].queue_free()
	if _steps.size() >= 2:
		_place_arrow(_steps[_steps.size() - 2]["cell"], _steps.back()["cell"], false)
	else:
		_place_arrow(_steps[0]["cell"], _steps[0]["cell"], true)
	queue_redraw()

func _update_arrow(delta: float) -> void:
	if arrow == null:
		return
	arrow.scale = Vector2.ONE * _arrow_scale * (56.0 / arrow.texture.get_width())
	if _shake_t < 0.0:
		arrow.rotation = _arrow_angle
		return
	_shake_t += delta
	if _shake_t >= SHAKE_DURATION:
		_shake_t = -1.0
		arrow.rotation = _arrow_angle
		return
	arrow.rotation = _arrow_angle + sin(_shake_t * 60.0) * deg_to_rad(12.0)

func _place_arrow(from: Vector2i, to: Vector2i, initial: bool) -> void:
	if arrow == null:
		return
	if initial:
		arrow.position = maze_view.cell_to_local(to) + Vector2(-36, 0)
		_arrow_angle = 0.0
		arrow.rotation = 0.0
		return
	arrow.position = maze_view.cell_to_local(to)
	# linha cresce pra cima -> nega em y-down
	_arrow_angle = atan2(-float(to.y - from.y), float(to.x - from.x))
	arrow.rotation = _arrow_angle

func _draw() -> void:
	if maze_view == null:
		return
	if _threshold_length > 0.0:
		var door := maze_view.cell_to_local(_steps[0]["cell"])
		draw_texture_rect(DIRT, Rect2(-14, door.y - CORRIDOR / 2.0, _threshold_length, CORRIDOR), true)
	for i in range(1, _steps.size()):
		var step: Dictionary = _steps[i]
		var direction: Vector2 = step["dir"]
		var length: float = step["length"]
		var start: Vector2 = step["start"]
		var rect: Rect2
		if absf(direction.x) > 0.5:
			if direction.x > 0.0:
				rect = Rect2(start.x, start.y - CORRIDOR / 2.0, length, CORRIDOR)
			else:
				rect = Rect2(start.x - length, start.y - CORRIDOR / 2.0, length, CORRIDOR)
		else:
			if direction.y > 0.0:
				rect = Rect2(start.x - CORRIDOR / 2.0, start.y, CORRIDOR, length)
			else:
				rect = Rect2(start.x - CORRIDOR / 2.0, start.y - length, CORRIDOR, length)
		draw_texture_rect(DIRT, rect, true)
