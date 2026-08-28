extends Node

## Estrelas por fase e desbloqueio derivado (fase N abre quando a N-1 tem
## estrela). JSON user://progress.json, formato {version, worlds:[{levelStars}]}.

const WORLD_COUNT := 4
const LEVELS_PER_WORLD := 10
const MAX_STARS := 3
const SAVE_PATH := "user://progress.json"

var _stars: Array = []
var _pending_unlock := Vector2i.ZERO

func _ready() -> void:
	_load()

func get_stars(world: int, level: int) -> int:
	return _stars[world - 1][level - 1]

func get_world_stars(world: int) -> int:
	var total := 0
	for stars in _stars[world - 1]:
		total += stars
	return total

func is_level_completed(world: int, level: int) -> bool:
	return get_stars(world, level) > 0

func is_level_unlocked(world: int, level: int) -> bool:
	if level == 1:
		return true
	return is_level_completed(world, level - 1)

func get_highest_unlocked_level(world: int) -> int:
	for level in range(LEVELS_PER_WORLD, 1, -1):
		if is_level_unlocked(world, level):
			return level
	return 1

func report_level_result(world: int, level: int, stars_earned: int) -> void:
	var clamped := clampi(stars_earned, 0, MAX_STARS)
	if clamped <= get_stars(world, level):
		return
	var first_completion := get_stars(world, level) == 0
	_stars[world - 1][level - 1] = clamped
	_save()
	if first_completion and level < LEVELS_PER_WORLD:
		_pending_unlock = Vector2i(world, level + 1)

## Desbloqueio recem-conquistado, pro mapa animar uma unica vez.
func try_consume_pending_unlock() -> Variant:
	if _pending_unlock == Vector2i.ZERO:
		return null
	var pending := _pending_unlock
	_pending_unlock = Vector2i.ZERO
	return pending

func _load() -> void:
	_stars = []
	for world in WORLD_COUNT:
		var row := PackedInt32Array()
		row.resize(LEVELS_PER_WORLD)
		_stars.append(row)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	# dados capengas (json invalido, versao desconhecida) viram progresso vazio
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != 1:
		return
	var worlds: Array = data.get("worlds", [])
	for world in mini(WORLD_COUNT, worlds.size()):
		var level_stars: Array = worlds[world].get("levelStars", [])
		for level in mini(LEVELS_PER_WORLD, level_stars.size()):
			_stars[world][level] = clampi(int(level_stars[level]), 0, MAX_STARS)

func _save() -> void:
	var worlds := []
	for world in WORLD_COUNT:
		worlds.append({"levelStars": Array(_stars[world])})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "worlds": worlds}))
