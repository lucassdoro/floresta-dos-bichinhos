extends Node

## Acha as fichas de fase (*.level.tres) sob res://levels. Fase nova aparece no
## Modo Livre so' por existir la', sem editar arquivo central.

const LEVELS_ROOT := "res://levels"
const INFO_SUFFIX := ".level.tres"

var _levels: Array[LevelInfo] = []

func _ready() -> void:
	_levels = scan(LEVELS_ROOT)

func all() -> Array[LevelInfo]:
	return _levels

func filter(text: String, skill: int, mechanic: int) -> Array[LevelInfo]:
	var result: Array[LevelInfo] = []
	for info in _levels:
		if info.matches(text, skill, mechanic):
			result.append(info)
	return result

## Oficiais primeiro, depois as de terceiros; id repetido fica com o primeiro dessa ordem.
static func scan(root: String) -> Array[LevelInfo]:
	var loaded: Array[LevelInfo] = []
	var paths := _find_info_files(root)
	paths.sort()
	for path in paths:
		var info := load(path) as LevelInfo
		if info == null:
			push_warning("LevelCatalog: %s nao e' LevelInfo" % path)
			continue
		info.set_meta(&"path", path)
		loaded.append(info)
	var official := loaded.filter(func(info: LevelInfo) -> bool: return info.author.is_empty())
	var community := loaded.filter(func(info: LevelInfo) -> bool: return not info.author.is_empty())
	var result: Array[LevelInfo] = []
	var seen_ids := {}
	for info: LevelInfo in official + community:
		if not _is_valid(info, info.get_meta(&"path"), seen_ids):
			continue
		seen_ids[info.id] = true
		result.append(info)
	return result

# list_directory lida com os .remap do build exportado; subpasta vem com "/" no fim
static func _find_info_files(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for entry in ResourceLoader.list_directory(dir_path):
		if entry.ends_with("/"):
			found.append_array(_find_info_files(dir_path.path_join(entry.trim_suffix("/"))))
			continue
		if entry.ends_with(INFO_SUFFIX):
			found.append(dir_path.path_join(entry))
	return found

static func _is_valid(info: LevelInfo, path: String, seen_ids: Dictionary) -> bool:
	if info.id.is_empty() or info.scene_path.is_empty() or not ResourceLoader.exists(info.scene_path):
		push_warning("LevelCatalog: %s sem id ou com cena inexistente" % path)
		return false
	if seen_ids.has(info.id):
		push_warning("LevelCatalog: id repetido '%s' em %s" % [info.id, path])
		return false
	return true
