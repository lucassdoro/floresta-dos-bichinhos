class_name LostCub
extends Node2D

## Um filhote perdido: escondido so mostra os olhinhos piscando; achado, da o
## pop e entra na fila atras do vaga-lume; na fogueira, pula pra vaga e fica
## respirando devagar.

enum State { HIDDEN, FOUND, FOLLOWING, SEATED }

const POP_DURATION := 0.35
const HOP_DURATION := 0.5
const HOP_ARC := 90.0
const SMOOTHING := 6.0
const SEATED_SCALE := 0.8
const HOP_HEIGHT := 10.0
const EYE := Color(1.0, 0.956, 0.627)
const EYE_HALO := Color(1.0, 0.886, 0.478, 0.4)

var animation_name := "croc"
var sprite_width := 120.0
var state := State.HIDDEN
## Aonde ir enquanto segue (ponto da trilha ou a fogueira).
var goal: Variant = null

var _view: AnimatedSprite2D = null
var _view_scale := 1.0
var _blink_period := 2.0 + randf() * 2.0
var _blink_t := randf() * 2.0
var _pop_t := -1.0
var _hop_t := -1.0
var _anim_t := 0.0
var _facing := 1.0
var _hop_from := Vector2.ZERO
var _hop_to := Vector2.ZERO
var _eye_size := Vector2.ZERO

func _ready() -> void:
	_view = AnimatedSprite2D.new()
	_view.sprite_frames = load("res://characters/lost_animals_frames.tres")
	var texture: Texture2D = _view.sprite_frames.get_frame_texture(animation_name, 0)
	_view_scale = sprite_width / texture.get_width()
	_eye_size = texture.get_size() * _view_scale
	_view.play(animation_name)
	_view.scale = Vector2.ZERO
	add_child(_view)

func reveal() -> void:
	if state != State.HIDDEN:
		return
	state = State.FOUND
	_pop_t = 0.0
	queue_redraw()

func seat_at(seat: Vector2) -> void:
	state = State.SEATED
	z_index = 13
	goal = null
	_hop_from = position
	_hop_to = seat
	_hop_t = 0.0

func _process(delta: float) -> void:
	_anim_t += delta
	match state:
		State.HIDDEN:
			_blink_t = fmod(_blink_t + delta, _blink_period)
			queue_redraw()
		State.FOUND:
			_pop_t += delta
			var t := clampf(_pop_t / POP_DURATION, 0.0, 1.0)
			_view.scale = Vector2.ONE * _view_scale * _ease_out_back(t)
			if t >= 1.0:
				_pop_t = -1.0
				state = State.FOLLOWING
				z_index = 14
		State.FOLLOWING:
			_walk(delta)
		State.SEATED:
			_hop(delta)

func _walk(delta: float) -> void:
	if goal == null:
		return
	var delta_pos: Vector2 = goal - position
	if delta_pos.length() < 2.0:
		_view.position = Vector2.ZERO
		return
	if absf(delta_pos.x) > 1.0:
		_facing = -1.0 if delta_pos.x < 0.0 else 1.0
	position += delta_pos * (1.0 - exp(-SMOOTHING * delta))
	# pulinhos a 5 Hz enquanto anda
	_view.position = Vector2(0, -absf(sin(_anim_t * 10.0 * PI)) * HOP_HEIGHT)
	_view.scale = Vector2(_facing * _view_scale, _view_scale)

func _hop(delta: float) -> void:
	if _hop_t < 0.0:
		# sentado: respira devagar
		var breath := 1.0 + 0.03 * sin(_anim_t * 3.0)
		_view.scale = Vector2(_facing * _view_scale * SEATED_SCALE, _view_scale * SEATED_SCALE * breath)
		return
	_hop_t += delta
	var t := clampf(_hop_t / HOP_DURATION, 0.0, 1.0)
	position = _hop_from.lerp(_hop_to, t) - Vector2(0, sin(t * PI) * HOP_ARC)
	var scale_now := SEATED_SCALE + (1.0 - SEATED_SCALE) * (1.0 - t)
	_view.scale = Vector2(_facing * _view_scale * scale_now, _view_scale * scale_now)
	if t >= 1.0:
		_hop_t = -1.0
		_view.position = Vector2.ZERO

func _draw() -> void:
	if state != State.HIDDEN:
		return
	# dois olhinhos brilhando no escuro, piscando de vez em quando
	var open := 1.0 if _blink_t < _blink_period - 0.18 else 0.15
	var y := _eye_size.y * -0.12
	for x in [_eye_size.x * -0.08, _eye_size.x * 0.08]:
		draw_circle(Vector2(x, y), 11.0, EYE_HALO)
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, open))
		draw_circle(Vector2.ZERO, 4.5, EYE)
	draw_set_transform_matrix(Transform2D())

func _ease_out_back(t: float) -> float:
	var u := t - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u
