class_name MapPlayerStar
extends Node2D

## Estrela "voce esta aqui": flutua sobre o marcador da fase atual e avanca
## com pulinhos quando uma fase desbloqueia.

const HOVER_HEIGHT := 160.0
const BOB_AMPLITUDE := 10.0
const BOB_SPEED := 2.2
const PULSE_AMOUNT := 0.05
const HOP_HEIGHT := 80.0
const HOP_DURATION := 0.5
const HOP_COUNT := 2
const SQUASH_DURATION := 0.1

var is_hopping := false

var _time := 0.0
var _visual_base_scale := Vector2.ONE

@onready var _visual: Sprite2D = $Visual

func _ready() -> void:
	_visual_base_scale = _visual.scale

func place_above(marker_center: Vector2) -> void:
	position = marker_center - Vector2(0, HOVER_HEIGHT)

func hop_to(marker_center: Vector2) -> void:
	is_hopping = true
	var start := position
	var target := marker_center - Vector2(0, HOVER_HEIGHT)
	for hop_index in HOP_COUNT:
		var from := start.lerp(target, float(hop_index) / HOP_COUNT)
		var to := start.lerp(target, float(hop_index + 1) / HOP_COUNT)
		var direction := signf(to.x - from.x)
		var elapsed := 0.0
		while elapsed < HOP_DURATION:
			elapsed += get_process_delta_time()
			var progress := minf(elapsed / HOP_DURATION, 1.0)
			var arc := sin(progress * PI) * HOP_HEIGHT
			position = from.lerp(to, progress) - Vector2(0, arc)
			rotation_degrees = direction * 12.0 * sin(progress * PI)
			await get_tree().process_frame
		position = to
		rotation = 0.0
		# squash de pouso
		var squash_time := 0.0
		while squash_time < SQUASH_DURATION:
			squash_time += get_process_delta_time()
			var squash := 1.0 - sin(minf(squash_time / SQUASH_DURATION, 1.0) * PI) * 0.15
			scale = Vector2(2.0 - squash, squash)
			await get_tree().process_frame
		scale = Vector2.ONE
	is_hopping = false

func _process(delta: float) -> void:
	_time += delta
	if is_hopping:
		return
	_visual.position = Vector2(0, -sin(_time * BOB_SPEED) * BOB_AMPLITUDE)
	_visual.scale = _visual_base_scale * (1.0 + sin(_time * BOB_SPEED * 1.7) * PULSE_AMOUNT)
