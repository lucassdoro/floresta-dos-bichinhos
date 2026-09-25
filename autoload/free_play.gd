extends Node

## Modo Livre: qual fase foi aberta pelo livre e os recordes proprios
## (melhor estrela e vitorias), separados da Progression do modo historia.

const FREE_MODE_SCENE := "res://ui/free_mode/free_mode.tscn"
const SAVE_VERSION := 1
const MAX_STARS := 3

var save_path := "user://free_play.json"
## null = modo historia.
var current: LevelInfo
var _records := {}

func _ready() -> void:
	load_records()

func start(info: LevelInfo) -> void:
	current = info
	SceneLoader.go_to(info.scene_path)

func finish() -> void:
	current = null
	SceneLoader.go_to(FREE_MODE_SCENE)

func get_best(id: String) -> int:
	return _records.get(id, {}).get("best_stars", 0)

func get_plays(id: String) -> int:
	return _records.get(id, {}).get("plays", 0)

func report(stars: int) -> void:
	if current == null:
		return
	var record: Dictionary = _records.get(current.id, {"best_stars": 0, "plays": 0})
	record["best_stars"] = maxi(record["best_stars"], clampi(stars, 0, MAX_STARS))
	record["plays"] += 1
	_records[current.id] = record
	_save()

func load_records() -> void:
	_records = {}
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	var levels: Variant = data.get("levels", {})
	if not levels is Dictionary:
		return
	for id: String in levels:
		var entry: Dictionary = levels[id]
		_records[id] = {
			"best_stars": int(entry.get("best_stars", 0)),
			"plays": int(entry.get("plays", 0)),
		}

func _save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "levels": _records}))
