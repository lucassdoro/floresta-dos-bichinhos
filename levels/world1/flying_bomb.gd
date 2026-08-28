class_name FlyingBomb
extends FlyingItem

## Bomba: voa com o pavio em loop e, se for cortada, congela no lugar e toca
## a explosao. Nao cortada, cai fora da tela sem punicao.

signal exploded

const FUSE_FPS := 10.0
const BLAST_FPS := 24.0
const BLAST_SCALE := 2.2

var fuse_frames: Array = []
var blast_frames: Array = []

var _view: AnimatedSprite2D = null

func _ready() -> void:
	hit_radius_factor = 0.42  # hitbox apertada: o alvo grande e' a fruta
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fuse")
	frames.set_animation_speed("fuse", FUSE_FPS)
	frames.set_animation_loop("fuse", true)
	for texture in fuse_frames:
		frames.add_frame("fuse", texture)
	frames.add_animation("blast")
	frames.set_animation_speed("blast", BLAST_FPS)
	frames.set_animation_loop("blast", false)
	for texture in blast_frames:
		frames.add_frame("blast", texture)
	_view = AnimatedSprite2D.new()
	_view.sprite_frames = frames
	_view.scale = Vector2.ONE * (item_size.x / fuse_frames[0].get_width())
	_view.play("fuse")
	add_child(_view)
	_view.animation_finished.connect(_on_animation_finished)

func explode() -> void:
	if sliced:
		return
	sliced = true
	frozen = true
	velocity = Vector2.ZERO
	rotation = 0.0
	_view.scale = Vector2.ONE * (item_size.x * BLAST_SCALE / blast_frames[0].get_width())
	_view.play("blast")
	exploded.emit()

func _on_animation_finished() -> void:
	if _view.animation == &"blast":
		queue_free()
