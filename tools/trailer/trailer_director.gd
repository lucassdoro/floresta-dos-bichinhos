extends Node

## Joga sozinho trechos do jogo enquanto o Movie Maker grava. Cada trecho bom
## vira uma linha "TRAILER_SEGMENT nome quadro_inicio quadro_fim" no stdout;
## tools/trailer/make_trailer.py corta e junta. Nao grava progresso: nenhuma
## fase chega a ser vencida.

const FPS := 30.0
const DRAG_SECONDS := 0.7
const SWIPE_SECONDS := 0.14
const TAP_GAP := 0.08

var _frame_zero := 0
var _segment_name := ""
var _segment_start := 0

func _ready() -> void:
	_frame_zero = Engine.get_process_frames()
	_apply_lang()
	await _run()
	get_tree().quit()

func _run() -> void:
	await _shot_menu()
	await _shot_map()
	await _shot_fruits()
	await _shot_colors()
	await _shot_memory()
	await _shot_slice()
	await _shot_letters()
	await _shot_free_mode()

# ── trechos ───────────────────────────────────────────────────────

func _shot_menu() -> void:
	await _open("res://ui/menu/main_menu.tscn")
	_begin("menu")
	await _wait(3.2)
	_end()

func _shot_map() -> void:
	await _open("res://ui/world_map/world_map.tscn")
	_begin("mapa")
	await _wait(3.0)
	_end()

func _shot_fruits() -> void:
	var level := await _open("res://levels/world1/level_01.tscn")
	await _wait(1.2)
	_begin("frutas")
	var basket: Control = level.get_node("%Basket")
	var target := basket.get_global_rect().get_center()
	var game_root: Control = level.get_node("%GameRoot")
	var carried := 0
	for item in game_root.get_children():
		if carried >= 3:
			break
		if not (item is DraggableItem) or not item.accepts.call(basket):
			continue
		await _drag(item.get_global_rect().get_center(), target, DRAG_SECONDS)
		await _wait(0.45)
		carried += 1
	await _wait(0.6)
	_end()

func _shot_colors() -> void:
	var level := await _open("res://levels/world1/level_02.tscn")
	await _until(func() -> bool: return level.get("_accepting"), 20.0)
	await _wait(0.2)
	_begin("cores")
	var current: Array = level.get("_current")
	var target: Array = level.get("_target")
	var slot := current.find(target)
	await _tap(level.get_node("%ColorsPanel").button_center(slot))
	await _wait(0.7)
	var coral: Control = level.get_node("%Coral")
	var painted := [false]
	coral.painted_complete.connect(func() -> void: painted[0] = true, CONNECT_ONE_SHOT)
	await _scrub(coral.get_global_rect().grow(-30.0), painted)
	await _wait(1.6)
	_end()

func _shot_memory() -> void:
	var level := await _open("res://levels/world1/level_05.tscn")
	await _until(func() -> bool: return level.get("_accepting"), 20.0)
	_begin("memoria")
	var cards: Array = level.get("_cards")
	var pairs_done := 0
	for card in cards:
		if pairs_done >= 2:
			break
		if card.matched or card.face_up:
			continue
		var partner = _find_partner(cards, card)
		if partner == null:
			continue
		await _tap(card.get_global_rect().get_center())
		await _wait(0.5)
		await _tap(partner.get_global_rect().get_center())
		await _wait(1.2)
		pairs_done += 1
	_end()

func _shot_slice() -> void:
	var level := await _open("res://levels/world1/level_07.tscn")
	await _until(func() -> bool: return level.get("_arena_enabled"), 20.0)
	_begin("cortar")
	var game_root: Control = level.get_node("%GameRoot")
	var elapsed := 0.0
	while elapsed < 5.5:
		var food := _best_food(game_root)
		if food == null:
			await _wait(0.1)
			elapsed += 0.1
			continue
		var center: Vector2 = food.global_position
		await _drag(center + Vector2(-110, 50), center + Vector2(110, -50), SWIPE_SECONDS)
		await _wait(0.35)
		elapsed += SWIPE_SECONDS + 0.35
	_end()

func _shot_letters() -> void:
	var level := await _open("res://levels/world1/level_09.tscn")
	await _until(func() -> bool: return level.get("_round_open"), 20.0)
	await _wait(0.6)
	_begin("letras")
	for round_index in 2:
		await _until(func() -> bool: return level.get("_round_open"), 10.0)
		await _wait(0.5)
		var bubble := _target_bubble(level)
		if bubble:
			await _tap(bubble.get_global_rect().get_center())
		await _wait(1.6)
	_end()

func _shot_free_mode() -> void:
	var screen := await _open("res://ui/free_mode/free_mode.tscn")
	_begin("modo_livre")
	await _wait(1.6)
	var chip: Control = screen.get_node("%ChipColors")
	await _tap(chip.get_global_rect().get_center())
	await _wait(1.6)
	await _tap(chip.get_global_rect().get_center())
	await _wait(1.4)
	_end()

# ── escolhas dentro das fases ─────────────────────────────────────

func _find_partner(cards: Array, card) -> Variant:
	for other in cards:
		if other != card and other.pair_id == card.pair_id and not other.matched:
			return other
	return null

func _best_food(game_root: Control) -> Node2D:
	var best: Node2D = null
	for child in game_root.get_children():
		if not (child is FlyingFood) or child.sliced:
			continue
		var point: Vector2 = child.global_position
		if point.y < 180.0 or point.y > 900.0:
			continue
		if best == null or point.y < best.global_position.y:
			best = child
	return best

func _target_bubble(level: Node) -> Control:
	var rounds: Array = level.get("_rounds")
	var found: int = level.get("_found")
	if found >= rounds.size():
		return null
	var target: String = rounds[found]["target"]
	for bubble in level.get("_bubbles"):
		if is_instance_valid(bubble) and bubble.letter == target:
			return bubble
	return null

# ── cenas e marcacao ──────────────────────────────────────────────

func _open(path: String) -> Node:
	SceneLoader.go_to(path)
	await _until(func() -> bool:
		var scene := get_tree().current_scene
		return scene != null and scene.scene_file_path == path, 30.0)
	await _wait(0.7)
	return get_tree().current_scene

func _begin(segment: String) -> void:
	_segment_name = segment
	_segment_start = _frame()

func _end() -> void:
	print("TRAILER_SEGMENT %s %d %d" % [_segment_name, _segment_start, _frame()])

func _frame() -> int:
	return Engine.get_process_frames() - _frame_zero

func _apply_lang() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--lang="):
			continue
		var lang := arg.trim_prefix("--lang=")
		Settings.locale = lang
		TranslationServer.set_locale(lang)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().process_frame
		waited += 1.0 / FPS

# ── mouse ─────────────────────────────────────────────────────────

func _to_window(point: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * point

func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _to_window(point)
	event.global_position = event.position
	Input.parse_input_event(event)

func _motion(point: Vector2, previous: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _to_window(point)
	event.global_position = event.position
	event.relative = _to_window(point) - _to_window(previous)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)

func _tap(point: Vector2) -> void:
	_motion(point, point)
	await get_tree().process_frame
	_button(point, true)
	await _wait(TAP_GAP)
	_button(point, false)
	await get_tree().process_frame

func _drag(from: Vector2, to: Vector2, seconds: float) -> void:
	_motion(from, from)
	await get_tree().process_frame
	_button(from, true)
	await get_tree().process_frame
	var steps := maxi(2, roundi(seconds * FPS))
	var previous := from
	for step in range(1, steps + 1):
		var point := from.lerp(to, ease(float(step) / steps, -2.0))
		_motion(point, previous)
		previous = point
		await get_tree().process_frame
	_button(to, false)
	await get_tree().process_frame

## Esfrega em zigue-zague ate o coral ficar pintado (ou desistir em 4 passadas).
func _scrub(area: Rect2, done: Array) -> void:
	var rows := 7
	var start := area.position
	_motion(start, start)
	await get_tree().process_frame
	_button(start, true)
	var previous := start
	var passes := 0
	while not done[0] and passes < 4:
		for row in rows + 1:
			if done[0]:
				break
			var y := area.position.y + area.size.y * row / rows
			var x := area.end.x if row % 2 == 0 else area.position.x
			var point := Vector2(x, y)
			for step in range(1, 7):
				var mid := previous.lerp(point, step / 6.0)
				_motion(mid, previous)
				previous = mid
				await get_tree().process_frame
		passes += 1
	_button(previous, false)
	await get_tree().process_frame
