class_name RejectMarker
extends TextureRect

## X vermelho de erro: pisca 3x no ponto do drop.

const BLINK_INTERVAL := 0.09
const HALF_CYCLES := 6  # 3 acende + 3 apaga

var _half_cycles_left := 0
var _timer := 0.0

func _ready() -> void:
	visible = false

## Posicao global do centro do X.
func flash(global_center: Vector2) -> void:
	global_position = global_center - size / 2.0
	visible = true
	_half_cycles_left = HALF_CYCLES
	_timer = 0.0

func _process(delta: float) -> void:
	if _half_cycles_left <= 0:
		visible = false
		return
	_timer += delta
	if _timer < BLINK_INTERVAL:
		return
	_timer -= BLINK_INTERVAL
	visible = not visible
	_half_cycles_left -= 1
