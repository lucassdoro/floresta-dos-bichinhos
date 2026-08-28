extends LevelBase

## Fase 6 do mundo 1 — "Labirinto do Alpiste": desenhe a trilha do vao de
## entrada ate o alpiste. Andar 2 celulas num galho errado (ou topar num
## beco) rebobina a trilha e sela o galho; cada erro custa 1 estrela.

const DEAD_END_DWELL := 0.15
const WRONG_PATH_STEPS := 2
const REWIND_CAP := 1.2
const REFUSE_COOLDOWN := 0.6
const BACK_DWELL := 0.25
const HINT_FOOTPRINTS_AT := 5.0
const HINT_VOICE_AT := 12.0
const HINT_PATH_AT := 20.0
const INTRO_DELAY := 0.6
const INTRO_HOLD := 1.0
const HOP_HEIGHT := 18.0
const WALK_PER_CELL := 0.18
const WALK_MAX_TOTAL := 6.0

const GOOD_SFX := preload("res://assets/audio/SFX/fruit_drop_good.wav")
const BAD_SFX := preload("res://assets/audio/SFX/fruit_drop_oops.wav")

var _maze: MazeLogic = null
var _time := 0.0
var _resolving_dead_end := false
var _dead_end_since := -1.0
var _last_refuse_time := -99.0
var _back_since := -1.0
var _hint_level := 0

@onready var _maze_view: MazeView = %MazeView
@onready var _painter: TrailPainter = %TrailPainter
@onready var _arrow: Sprite2D = %Arrow
@onready var _lolo: LoloCharacter = %Lolo
@onready var _clearing: Sprite2D = %Clearing
@onready var _bubble: SpeechBubble = %Bubble
@onready var _confetti: GPUParticles2D = $Confetti

func _ready() -> void:
	super()
	_maze = MazeLogic.generate(MazeView.COLUMNS, MazeView.ROWS)
	_maze_view.setup(_maze)
	_maze_view.pointer_cell.connect(_on_pointer_cell)
	_painter.maze_view = _maze_view
	_painter.arrow = _arrow
	_painter.reset(_maze.entrance)
	_relayout()
	_run_intro()

func _relayout() -> void:
	var top_left := Vector2(size.x / 2.0 - 738.44, 280.0)
	_maze_view.position = top_left
	var entrance_local := _maze_view.cell_to_local(_maze.entrance)
	if not completed:
		_lolo.position = top_left + entrance_local + Vector2(-120, -26)
	_clearing.position = top_left + entrance_local + Vector2(-120, 54)
	var door := entrance_local + Vector2(-76, 0)
	_bubble.position = top_left + Vector2(door.x + 273, minf(door.y - 60, 700)) - _bubble.size / 2.0

func _run_intro() -> void:
	await _wait(INTRO_DELAY)
	if _dead():
		return
	_bubble.show_bubble()
	_bubble.say(tr("level16.intro"))
	_painter.show_ghost_hint(_next_solution_cells(3))
	if Voice.play("Lolo", "06_intro"):
		await Voice.finished
	if _dead():
		return
	if _bubble._typing:
		await _bubble.typing_finished
	await _wait(INTRO_HOLD)
	if _dead():
		return
	_painter.clear_ghost_hint()
	_bubble.hide_bubble()
	_maze_view.set_enabled(true)

func _on_pointer_cell(cell: Vector2i, is_press: bool) -> void:
	if completed:
		return
	_reset_hint()
	if is_press:
		_back_since = -1.0
		return
	if cell == _maze.head():
		_back_since = -1.0
		return
	var added := _maze.advance(cell)
	if added.is_empty():
		if not _maze.is_on_trail(cell):
			_back_since = -1.0
			return
		if _back_since < 0.0:
			_back_since = _time
			return
		if _time - _back_since >= BACK_DWELL:
			_refuse_backwards()
		return
	_back_since = -1.0
	_painter.enqueue(added)
	_maze_view.snap_anchor = _maze.head()
	Audio.play_sfx(GOOD_SFX)

func _refuse_backwards() -> void:
	if _time - _last_refuse_time < REFUSE_COOLDOWN:
		return
	_last_refuse_time = _time
	_painter.shake_arrow()
	Audio.play_locked()

func _tick_dead_end() -> void:
	if _resolving_dead_end:
		return
	var wrong := _maze.is_at_dead_end() or _maze.off_solution_count() >= WRONG_PATH_STEPS
	if not wrong or _painter.is_draining():
		_dead_end_since = -1.0
		return
	if _dead_end_since < 0.0:
		_dead_end_since = _time
		return
	if _time - _dead_end_since < DEAD_END_DWELL:
		return
	_dead_end_since = -1.0
	_dead_end_routine()

func _dead_end_routine() -> void:
	_resolving_dead_end = true
	_maze_view.cancel_active_pointer()
	_maze_view.set_enabled(false)
	Audio.play_sfx(BAD_SFX)
	await _say_line("oops")
	if _dead():
		return
	var divergence := _maze.last_divergence()
	var removed := _maze.rewind(divergence)
	_painter.rewind_to(divergence, REWIND_CAP)
	await _wait(REWIND_CAP)
	if _dead():
		return
	if not removed.is_empty():
		_maze.seal_edge(divergence, removed[0])
		_maze_view.add_seal(divergence, removed[0])
	_maze_view.snap_anchor = _maze.head()
	mistake()
	if mistakes >= 2:
		_painter.show_ghost_hint(_next_solution_cells(3))
	_maze_view.set_enabled(true)
	_resolving_dead_end = false

func _tick_hint() -> void:
	if _painter.is_draining() or _resolving_dead_end:
		_reset_hint()
		return
	var idle := _maze_view.idle_seconds
	if idle < HINT_FOOTPRINTS_AT:
		_reset_hint()
		return
	if _hint_level == 0:
		_hint_level = 1
		_painter.pulse_arrow(true)
		_painter.show_ghost_hint(_next_solution_cells(1))
		return
	if idle >= HINT_VOICE_AT and _hint_level == 1:
		_hint_level = 2
		_say_line("hint")
		return
	if idle >= HINT_PATH_AT and _hint_level == 2:
		_hint_level = 3
		_painter.show_ghost_hint(_next_solution_cells(3))

func _reset_hint() -> void:
	if _hint_level == 0:
		return
	_hint_level = 0
	_painter.pulse_arrow(false)
	_painter.clear_ghost_hint()

func _next_solution_cells(count: int) -> Array:
	var solution := _maze.solution()
	var index := solution.find(_maze.head())
	if index < 0:
		return []
	return solution.slice(index + 1, mini(index + 1 + count, solution.size()))

func _say_line(suffix: String) -> void:
	_bubble.show_bubble()
	_bubble.say(tr("level16." + suffix))
	if Voice.play("Lolo", "06_" + suffix):
		await Voice.finished
	if _dead():
		return
	if _bubble._typing:
		await _bubble.typing_finished
	_bubble.hide_bubble()

func _victory_routine() -> void:
	_maze_view.set_enabled(false)
	_reset_hint()
	_confetti.restart()
	await _walk_trail(_maze.trail)
	if not is_inside_tree():
		return
	win()

func _walk_trail(cells: Array[Vector2i]) -> void:
	if cells.size() < 2:
		return
	_lolo.fly()
	_lolo.position = _lolo_world(cells[0])
	var per_cell := minf(WALK_PER_CELL, WALK_MAX_TOTAL / (cells.size() - 1))
	for i in range(1, cells.size()):
		var from := _maze_view.cell_to_local(cells[i - 1])
		var to := _maze_view.cell_to_local(cells[i])
		_lolo.face_direction(to.x - from.x)
		await _hop_to(_lolo_world(cells[i]), per_cell)
		if not is_inside_tree():
			return
	_lolo.land()

func _hop_to(target: Vector2, duration: float) -> void:
	var start := _lolo.position
	var elapsed := 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / duration, 0.0, 1.0)
		var pos := start.lerp(target, t)
		pos.y -= sin(t * PI) * HOP_HEIGHT
		_lolo.position = pos
		await get_tree().process_frame
	_lolo.position = target

func _lolo_world(cell: Vector2i) -> Vector2:
	return _maze_view.position + _maze_view.cell_to_local(cell)

func _process(delta: float) -> void:
	_time += delta
	if completed:
		return
	if _maze != null and _maze.head() == _maze.exit and not _painter.is_draining() and not _resolving_dead_end:
		_resolving_dead_end = true  # trava reentrada do _process
		_victory_routine()
		return
	_tick_dead_end()
	_tick_hint()

func _dead() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
