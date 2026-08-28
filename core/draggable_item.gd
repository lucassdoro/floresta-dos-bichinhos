class_name DraggableItem
extends Control

## Item arrastavel dos mini-jogos: cuida do proprio drag, sons e animacoes.
## Bom e solto na cesta assenta num arco balistico com squash e quique; ruim
## dispara o X de erro e volta pra casa.

signal collected(item: DraggableItem)
signal item_mistake(item: DraggableItem)

enum Phase { SPAWN, IDLE, RETURNING, FALL, SQUASH, BOUNCE, RESTING }

const DRAG_SCALE := 1.1
const RETURN_DURATION := 0.6
const SPAWN_POP_DURATION := 0.25
const FALL_DURATION := 0.45
const FALL_GRAVITY := 4200.0
const BOUNCE_HEIGHT := 16.0
const BOUNCE_DURATION := 0.16
const SQUASH_HOLD := 0.06
const SWAY_SPEED := 2.5
const STORED_ITEM_SCALE := 1.0

const GOOD_SFX := preload("res://assets/audio/SFX/fruit_drop_good.wav")
const BAD_SFX := preload("res://assets/audio/SFX/fruit_drop_oops.wav")

var baskets: Array[SortingBasket] = []
## Regra de aceitacao: recebe a cesta, devolve se este item pertence a ela.
var accepts: Callable = func(_basket: SortingBasket) -> bool: return true
## Inclinacao de repouso em graus, girando em torno do pe (fase 8).
var tilt_degrees := 0.0
## Balanco leve em idle, em graus, em torno de tilt_degrees. 0 = imovel.
var sway_degrees := 0.0
## Quando o errado e' o lugar (fase 8) cada tentativa conta; quando o item e'
## que e' ruim (fase 1), so o primeiro erro conta.
var counts_every_mistake := false
## Offset do spawn em relacao ao centro do canvas (y pra cima).
var home_offset := Vector2.ZERO
var home_position := Vector2.ZERO

var _phase := Phase.SPAWN
var _dragging := false
var _mistake_counted := false
var _t := 0.0
var _return_start := Vector2.ZERO
var _return_start_scale := 1.0
var _fall_start := Vector2.ZERO
var _fall_slot := Vector2.ZERO
var _fall_velocity := Vector2.ZERO
var _fall_start_scale := 1.0
var _rest_tilt := 0.0
var _stored_scale := 1.0
var _sway_time := randf() * 10.0
var _grab_offset := Vector2.ZERO
var _pointer := Vector2.ZERO
var _view: TextureRect

var is_idle: bool:
	get: return _phase == Phase.IDLE and not _dragging

## Monta o visual. Chamar depois de setar size (largura x altura do item).
func setup(texture: Texture2D) -> void:
	pivot_offset = size / 2.0
	_view = TextureRect.new()
	_view.texture = texture
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.size = size
	# pivo no pe, pra inclinacao e balanco girarem como um pendulo plantado
	_view.pivot_offset = Vector2(size.x / 2.0, size.y)
	_view.rotation_degrees = tilt_degrees
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	scale = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(event.position)

func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_pointer = event.position
		global_position = _pointer - _grab_offset
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(_pointer)

func _start_drag(local_point: Vector2) -> void:
	if _phase != Phase.IDLE or _dragging:
		return
	_dragging = true
	_grab_offset = local_point
	_pointer = global_position + local_point
	move_to_front()
	scale = Vector2.ONE * DRAG_SCALE
	_view.rotation_degrees = tilt_degrees
	Audio.play_click()

func _end_drag(pointer: Vector2) -> void:
	_dragging = false
	var basket: SortingBasket = null
	for candidate in baskets:
		if candidate.contains_global_point(pointer):
			basket = candidate
			break
	if basket == null:
		_start_return_home()
		return
	if accepts.call(basket):
		Audio.play_sfx(GOOD_SFX)
		basket.pulse()
		_start_settle(basket)
		return
	Audio.play_sfx(BAD_SFX)
	basket.show_reject(pointer)
	if counts_every_mistake or not _mistake_counted:
		_mistake_counted = true
		item_mistake.emit(self)
	_start_return_home()

func _start_return_home() -> void:
	_phase = Phase.RETURNING
	_return_start = position
	_return_start_scale = scale.x
	_t = 0.0

# o item cai no slot da cesta num arco balistico, com squash no impacto e um
# quique; fica no espaco da fase (reparent durante input quebra o gesto)
func _start_settle(basket: SortingBasket) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_rest_tilt = randf_range(-18.0, 18.0)
	var tilt_radians := deg_to_rad(_rest_tilt)
	var effective_half_width := (absf(cos(tilt_radians)) * size.x + absf(sin(tilt_radians)) * size.y) * 0.5 * STORED_ITEM_SCALE
	_stored_scale = basket.stored_root.get_global_transform().get_scale().x
	var slot := basket.reserve_storage_slot(effective_half_width / _stored_scale)
	var slot_global := basket.stored_root.global_position + Vector2(slot.x, -slot.y) * _stored_scale - size / 2.0
	_fall_slot = get_parent().get_global_transform().affine_inverse() * slot_global

	_fall_start = position
	_fall_start_scale = scale.x
	var gravity := Vector2(0, FALL_GRAVITY)
	_fall_velocity = (_fall_slot - _fall_start) / FALL_DURATION - gravity * (0.5 * FALL_DURATION)
	_phase = Phase.FALL
	_t = 0.0

func _process(delta: float) -> void:
	match _phase:
		Phase.SPAWN:
			_update_spawn(delta)
		Phase.RETURNING:
			_update_return(delta)
		Phase.FALL:
			_update_fall(delta)
		Phase.SQUASH:
			_update_squash(delta)
		Phase.BOUNCE:
			_update_bounce(delta)
		Phase.IDLE:
			_update_idle_sway(delta)
		Phase.RESTING:
			pass

func _update_idle_sway(delta: float) -> void:
	if sway_degrees == 0.0 or _dragging:
		return
	_sway_time += delta
	_view.rotation_degrees = tilt_degrees + sin(_sway_time * SWAY_SPEED) * sway_degrees

func _update_spawn(delta: float) -> void:
	_t += delta
	scale = Vector2.ONE * smoothstep(0.0, 1.0, _t / SPAWN_POP_DURATION)
	if _t < SPAWN_POP_DURATION:
		return
	scale = Vector2.ONE
	_phase = Phase.IDLE

func _update_return(delta: float) -> void:
	_t += delta
	var progress := smoothstep(0.0, 1.0, _t / RETURN_DURATION)
	position = _return_start + (home_position - _return_start) * progress
	scale = Vector2.ONE * lerpf(_return_start_scale, 1.0, progress)
	if _t < RETURN_DURATION:
		return
	position = home_position
	scale = Vector2.ONE
	_phase = Phase.IDLE

func _update_fall(delta: float) -> void:
	_t += delta
	var flight := minf(_t, FALL_DURATION)
	position = _fall_start + _fall_velocity * flight + Vector2(0, FALL_GRAVITY) * (0.5 * flight * flight)
	var progress := flight / FALL_DURATION
	scale = Vector2.ONE * lerpf(_fall_start_scale, _stored_scale, progress)
	rotation_degrees = -_rest_tilt * progress
	if _t < FALL_DURATION:
		return
	scale = Vector2(_stored_scale * 1.15, _stored_scale * 0.8)
	rotation_degrees = -_rest_tilt
	_phase = Phase.SQUASH
	_t = 0.0

func _update_squash(delta: float) -> void:
	_t += delta
	if _t < SQUASH_HOLD:
		return
	scale = Vector2.ONE * _stored_scale
	_phase = Phase.BOUNCE
	_t = 0.0

func _update_bounce(delta: float) -> void:
	_t += delta
	var progress := clampf(_t / BOUNCE_DURATION, 0.0, 1.0)
	var hop := BOUNCE_HEIGHT * 4.0 * progress * (1.0 - progress)
	position = _fall_slot + Vector2(0, -hop)
	if _t < BOUNCE_DURATION:
		return
	position = _fall_slot
	_phase = Phase.RESTING
	collected.emit(self)
