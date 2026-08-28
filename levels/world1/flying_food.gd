class_name FlyingFood
extends FlyingItem

## Fruta inteira em voo. Ao ser cortada, some e deixa duas metades no lugar,
## que caem com arrasto leve e giram mais rapido — o contraste da o estalo.

const MIN_IMPULSE := 120.0
const MAX_IMPULSE := 190.0
const SPIN_PER_IMPULSE := 0.012
const CUT_ENERGY_LOSS := 0.75

var whole: Texture2D = null
var top: Texture2D = null
var bottom: Texture2D = null

func _ready() -> void:
	add_sprite_view(whole)

func slice(cut_angle: float) -> void:
	if sliced:
		return
	sliced = true
	var host := get_parent()
	if host == null:
		queue_free()
		return
	var sprite_scale := item_size.x / whole.get_width()
	var impulse := randf_range(MIN_IMPULSE, MAX_IMPULSE)
	var perpendicular := Vector2(-sin(cut_angle), cos(cut_angle))
	# o corte tira energia: cortada subindo, ainda sobe um pouco e cai
	var base := Vector2(velocity.x, velocity.y * CUT_ENERGY_LOSS)
	for side in [-1, 1]:
		var half_texture := top if side == -1 else bottom
		var half_size := half_texture.get_size() * sprite_scale
		var half := FlyingItem.new()
		half.item_size = half_size
		half.sliced = true
		half.horizontal_damping = 0.995
		half.despawn_x = despawn_x
		half.despawn_y = despawn_y
		# os PNGs de metade sao recortados no proprio bounding box: corrige o
		# centro pra nao "pular" no primeiro frame
		half.position = position + perpendicular * ((item_size.y - half_size.y) / 2.0 * side)
		half.rotation = cut_angle
		half.velocity = base + perpendicular * (impulse * side)
		half.spin = impulse * SPIN_PER_IMPULSE * side
		half.add_sprite_view(half_texture)
		host.add_child(half)
	queue_free()
