class_name CoralPaintArea
extends Control

## Coral pintavel: a tinta e' carimbada num SubViewport e exibida clipada na
## silhueta (shader paint_mask com o alfa do coral_branches). Uma grade lida
## do coverage mask mede a cobertura; a 90% o coral tinge e dispara o sinal.

signal painted_complete
signal follow_requested(global_point: Vector2)
signal released

const BRUSH_RADIUS := 60.0
const COMPLETE_THRESHOLD := 0.9
const STAMP_ALPHA := 0.85
const FADE_DURATION := 0.5
const TINT_DURATION := 0.4
const POP_SCALE := 1.12
const POP_DURATION := 0.35
const BLOB := preload("res://assets/art/MiniGames/ColorReef/paint_blob.webp")
const MASK := preload("res://assets/art/MiniGames/ColorReef/coral_coverage_mask.webp")

@export var base_scale := 1.5791612

var armed := false
var idle_seconds := 0.0

var _paint_color := Color.WHITE
var _dragging := false
var _last_point := Vector2.ZERO
var _cols := 0
var _rows := 0
var _valid := PackedByteArray()
var _cells_painted := PackedByteArray()
var _valid_count := 0
var _painted_count := 0
var _cell_size := 7.5

@onready var _branches: TextureRect = %Branches
@onready var _paint_display: TextureRect = %PaintDisplay
@onready var _shading: TextureRect = %Shading
@onready var _viewport: SubViewport = %PaintViewport

func _ready() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * base_scale
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shading.modulate.a = 0.0
	_build_grid()
	var paint_material: ShaderMaterial = _paint_display.material
	paint_material.set_shader_parameter("paint_tex", _viewport.get_texture())
	paint_material.set_shader_parameter("group_alpha", 1.0)

func _build_grid() -> void:
	var image := MASK.get_image()
	if image.is_compressed():
		image.decompress()
	_cols = image.get_width()
	_rows = image.get_height()
	_valid.resize(_cols * _rows)
	_cells_painted.resize(_cols * _rows)
	for x in _cols:
		for y in _rows:
			if image.get_pixel(x, y).r > 0.3:
				_valid[y * _cols + x] = 1
				_valid_count += 1
	_cell_size = size.x / _cols

func begin(color: Color) -> void:
	_cells_painted.fill(0)
	_painted_count = 0
	for stamp in _viewport.get_children():
		stamp.queue_free()
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_paint_color = color
	armed = true
	idle_seconds = 0.0
	var paint_material: ShaderMaterial = _paint_display.material
	paint_material.set_shader_parameter("group_alpha", 1.0)
	create_tween().tween_property(_shading, "modulate:a", 1.0, 0.3)

## Tinge a silhueta (lerp branco -> cor) com pop; a pintura some em fade.
func paint_coral(color: Color) -> void:
	create_tween().tween_property(_branches, "self_modulate", color, TINT_DURATION)
	var paint_material: ShaderMaterial = _paint_display.material
	var fade := create_tween().set_parallel(true)
	fade.tween_method(func(alpha: float) -> void:
		paint_material.set_shader_parameter("group_alpha", alpha), 1.0, 0.0, FADE_DURATION)
	fade.tween_property(_shading, "modulate:a", 0.0, FADE_DURATION)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2.ONE * base_scale * POP_SCALE, POP_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2.ONE * base_scale, POP_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func reset_to_neutral() -> void:
	create_tween().tween_property(_branches, "self_modulate", Color.WHITE, TINT_DURATION)

func mark_activity() -> void:
	idle_seconds = 0.0

func _process(delta: float) -> void:
	if armed:
		idle_seconds += delta

func _gui_input(event: InputEvent) -> void:
	if not armed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		_last_point = event.position
		follow_requested.emit(global_position + event.position * scale.x)
		_stamp_at(event.position)

func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var local: Vector2 = (motion.position - global_position) / scale.x
		follow_requested.emit(motion.position)
		_stroke_to(local)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		if armed:
			released.emit()

func _stroke_to(to: Vector2) -> void:
	mark_activity()
	var steps := maxi(1, ceili(_last_point.distance_to(to) / (BRUSH_RADIUS / 2.0)))
	for i in range(1, steps + 1):
		_stamp_at(_last_point + (to - _last_point) * (float(i) / steps))
	_last_point = to

func _stamp_at(local: Vector2) -> void:
	# o loop do stroke continua apos completar; sem o guard o sinal dispara
	# duas vezes e corrompe a fila de pedidos
	if not armed:
		return
	mark_activity()
	var cell_x := local.x / _cell_size
	var cell_y := local.y / _cell_size
	var radius := BRUSH_RADIUS / _cell_size
	if _paint_cells(cell_x, cell_y, radius) == 0:
		return
	var stamp := Sprite2D.new()
	stamp.texture = BLOB
	stamp.position = local
	stamp.rotation = randf() * TAU
	var stamp_size := BRUSH_RADIUS * 2.4 * randf_range(0.9, 1.2)
	stamp.scale = Vector2.ONE * (stamp_size / BLOB.get_width())
	stamp.modulate = Color(_paint_color, STAMP_ALPHA)
	_viewport.add_child(stamp)
	if _painted_count >= int(_valid_count * COMPLETE_THRESHOLD):
		armed = false
		_dragging = false
		painted_complete.emit()

func _paint_cells(cx: float, cy: float, radius: float) -> int:
	var count := 0
	var min_x := maxi(0, floori(cx - radius))
	var max_x := mini(_cols - 1, ceili(cx + radius))
	var min_y := maxi(0, floori(cy - radius))
	var max_y := mini(_rows - 1, ceili(cy + radius))
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var index := y * _cols + x
			if _valid[index] == 0 or _cells_painted[index] == 1:
				continue
			var nx := (x + 0.5 - cx) / radius
			var ny := (y + 0.5 - cy) / radius
			if nx * nx + ny * ny > 1.0:
				continue
			_cells_painted[index] = 1
			_painted_count += 1
			count += 1
	return count
