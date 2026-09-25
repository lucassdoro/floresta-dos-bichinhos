class_name PuzzlePiece
extends TextureRect

## Peca do quebra-cabeca: placeholder bege ate a foto "cortar" (shader),
## arrasto horizontal pega a peca (fantasma no drag layer), vertical rola a
## bandeja. O controller e' a fase.

const BOARD_SIZE := 160.79309
const TRAY_SIZE := 189.0
const DRAG_SCALE := 1.1
const DECIDE_THRESHOLD := 8.0
const REVEAL_DURATION := 0.5

@export var row := 0
@export var col := 0

var controller: Node = null
var is_placed := false
var is_busy := false
var ghost: TextureRect = null

var _mode := 0  # 0 indeciso, 1 rola, 2 arrasta, -1 ignora
var _pressed := false
var _total := Vector2.ZERO
var _pointer := Vector2.ZERO

func _ready() -> void:
	material = material.duplicate()
	pivot_offset = size / 2.0

func set_photo(photo: Texture2D, origin: Vector2, region: Vector2) -> void:
	var shader_material: ShaderMaterial = material
	shader_material.set_shader_parameter("photo", photo)
	shader_material.set_shader_parameter("region_origin", origin)
	shader_material.set_shader_parameter("region_size", region)

func reveal() -> void:
	pivot_offset = size / 2.0
	create_tween().tween_property(material, "shader_parameter/revealed", 1.0, REVEAL_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse := create_tween()
	pulse.tween_property(self, "scale", Vector2.ONE * 1.06, REVEAL_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(self, "scale", Vector2.ONE, REVEAL_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if controller == null or not controller.accepting_input() or is_placed or is_busy:
			_mode = -1
			return
		if not controller.is_piece_hittable(self):
			_mode = -1
			return
		_pressed = true
		_mode = 0
		_total = Vector2.ZERO
		_pointer = global_position + event.position

func _input(event: InputEvent) -> void:
	if not _pressed:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _pointer
		_pointer = motion.position
		_total += delta
		if _mode == 0:
			if _total.length() < DECIDE_THRESHOLD:
				return
			if absf(_total.y) > absf(_total.x):
				_mode = 1
			else:
				_mode = 2
				controller.begin_piece_drag(self, _pointer)
		if _mode == 1:
			controller.scroll_tray_by(delta.y)
			return
		if _mode == 2 and not is_placed:
			controller.drag_piece_to(self, _pointer)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_pressed = false
		if _mode == 2 and not is_placed:
			controller.on_piece_dropped(self)
		_mode = 0
