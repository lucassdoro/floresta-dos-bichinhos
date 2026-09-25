extends Control

## Mapa de fases do mundo 1: marcadores ancorados no rect do fundo (cover),
## estrela "voce esta aqui" e revelacao animada de fase recem-desbloqueada.

const WORLD_NUMBER := 1
const REVEAL_DELAY := 0.6
const MARKER_SCALE := 0.876
const BACKGROUND_SIZE := Vector2(1264, 664)
const MARKER_SCENE := preload("res://ui/world_map/level_marker.tscn")
const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")
const UNLOCK_SFX := preload("res://assets/audio/SFX/unlock_sparkle.wav")

# ancoras fracionarias dos marcadores no rect do fundo (y pra cima)
const MARKER_ANCHORS: Array[Vector2] = [
	Vector2(0.15329759, 0.3450741),
	Vector2(0.26149553, 0.287),
	Vector2(0.38558018, 0.3107037),
	Vector2(0.5, 0.287),
	Vector2(0.595997, 0.3610741),
	Vector2(0.6578775, 0.5),
	Vector2(0.7649426, 0.5277778),
	Vector2(0.8454923, 0.66607404),
	Vector2(0.77161044, 0.7685185),
	Vector2(0.6725408, 0.701463),
]

var _markers: Array[LevelMarker] = []
var _star_level := 1

@onready var _map_root: Control = %MapRoot
@onready var _player_star: MapPlayerStar = %PlayerStar
@onready var _header: Control = %WorldHeader

func _ready() -> void:
	$BackButton.pressed.connect(_go_back)
	for index in MARKER_ANCHORS.size():
		var marker: LevelMarker = MARKER_SCENE.instantiate()
		marker.level_number = index + 1
		marker.map_anchor = MARKER_ANCHORS[index]
		marker.scale = Vector2.ONE * MARKER_SCALE
		marker.selected.connect(_open_level)
		_map_root.add_child(marker)
		_markers.append(marker)
	_map_root.move_child(_player_star, -1)
	_apply_progress()
	resized.connect(_relayout)
	_relayout()
	_play_header_entrance()
	if not _try_start_unlock_reveal():
		_place_star_at_current_level()

func _apply_progress() -> void:
	for marker in _markers:
		marker.configure(
			Progression.get_stars(WORLD_NUMBER, marker.level_number),
			not Progression.is_level_unlocked(WORLD_NUMBER, marker.level_number))

func _relayout() -> void:
	# cover do fundo no canvas, centralizado
	var cover := maxf(size.x / BACKGROUND_SIZE.x, size.y / BACKGROUND_SIZE.y)
	var map_size := BACKGROUND_SIZE * cover
	var map_top_left := (size - map_size) / 2.0
	for marker in _markers:
		var center := map_top_left + Vector2(
			marker.map_anchor.x * map_size.x,
			(1.0 - marker.map_anchor.y) * map_size.y)
		marker.position = center - marker.size * MARKER_SCALE / 2.0
	if not _player_star.is_hopping and _markers.size() > 0:
		_player_star.place_above(_marker_center(_star_level))

func _marker_center(level: int) -> Vector2:
	var marker := _markers[level - 1]
	return marker.position + marker.size * MARKER_SCALE / 2.0

## Se uma fase acabou de desbloquear, segura o marcador travado e revela com
## a estrela pulando ate ele.
func _try_start_unlock_reveal() -> bool:
	var pending: Variant = Progression.try_consume_pending_unlock()
	if pending == null:
		return false
	if pending.x != WORLD_NUMBER:
		return false
	var level := int(pending.y)
	if level < 2 or level > _markers.size():
		return false
	_markers[level - 1].configure(0, true)
	_star_level = level - 1
	_player_star.place_above(_marker_center(level - 1))
	_reveal_unlock(level)
	return true

func _reveal_unlock(level: int) -> void:
	await get_tree().create_timer(REVEAL_DELAY).timeout
	_star_level = level
	await _player_star.hop_to(_marker_center(level))
	_markers[level - 1].configure(0, false)
	_markers[level - 1].pop()
	var burst := SPARKLE_BURST.instantiate()
	_map_root.add_child(burst)
	burst.burst(_player_star.global_position, Color.WHITE, 12, 60.0)
	Audio.play_sfx(UNLOCK_SFX)

func _place_star_at_current_level() -> void:
	_star_level = Progression.get_highest_unlocked_level(WORLD_NUMBER)
	_player_star.place_above(_marker_center(_star_level))

# placa do topo entra caindo de cima com quique
func _play_header_entrance() -> void:
	_header.offset_top = -340.0
	var tween := create_tween()
	tween.tween_property(_header, "offset_top", 48.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_header, "offset_top", 8.0, 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_header, "offset_top", 20.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _open_level(level: int) -> void:
	var scene_path := "res://levels/world1/level_%02d.tscn" % level
	if not ResourceLoader.exists(scene_path):
		return
	SceneLoader.go_to(scene_path)

func _go_back() -> void:
	SceneLoader.go_to("res://ui/menu/main_menu.tscn")
