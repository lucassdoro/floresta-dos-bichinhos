class_name FlyingItem
extends Node2D

## Item arremessado da fase 7: arco balistico com gravidade constante e giro
## leve. Some sozinho ao sair da tela.

signal escaped

const GRAVITY := 1250.0
const MAX_LIFETIME := 6.0
const SIDE_MARGIN := 500.0

var velocity := Vector2.ZERO
var spin := 0.0
var despawn_x := 0.0
var despawn_y := 0.0
var item_size := Vector2.ZERO
## Cortado (ou ja e' um pedaco): nao conta como perdido ao sumir.
var sliced := false
## Congelado: explosao em curso, para de voar e de girar.
var frozen := false
var horizontal_damping := 1.0
var hit_radius_factor := 0.62

var _life := 0.0

## Raio do teste de corte. Usa o MAIOR lado: em arte mais alta que larga a
## hitbox nao pode encolher junto com o encaixe.
func hit_radius() -> float:
	return maxf(item_size.x, item_size.y) * hit_radius_factor

func add_sprite_view(texture: Texture2D) -> void:
	var view := Sprite2D.new()
	view.texture = texture
	view.scale = Vector2.ONE * (item_size.x / texture.get_width())
	add_child(view)

func _process(delta: float) -> void:
	_life += delta
	if not frozen:
		velocity.y += GRAVITY * delta
		if horizontal_damping != 1.0:
			velocity.x *= pow(horizontal_damping, delta * 60.0)
		position += velocity * delta
		rotation += spin * delta
	var gone := position.y > despawn_y or position.x < -SIDE_MARGIN or position.x > despawn_x
	if _life > MAX_LIFETIME or gone:
		if not sliced:
			escaped.emit()
		queue_free()
