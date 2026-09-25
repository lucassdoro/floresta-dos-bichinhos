extends Node

## Regras do Modo Livre: varredura do catalogo, filtro e recordes do FreePlay.
## Roda como cena headless (run_headless_scene) porque depende de autoloads.

const FIXTURES := "res://tools/tests/fixtures/catalog"

func _ready() -> void:
	var failures := 0
	var levels := LevelCatalog.scan(FIXTURES)
	var ids := levels.map(func(info: LevelInfo) -> String: return info.id)
	failures += check("acha as 3 fichas validas", ids.size() == 3)
	failures += check("id repetido fica com a primeira (oficial)", ids.count("test.one") == 1 and levels[ids.find("test.one")].author.is_empty())
	failures += check("ficha sem cena e' descartada", not ids.has("test.broken"))
	failures += check("oficiais antes das de terceiros", ids == ["test.one", "test.two", "ana_dev.three"])
	if levels.is_empty():
		print("FAILURES: %d" % (failures + 1))
		get_tree().quit(1)
		return
	var one: LevelInfo = levels[0]
	failures += check("sem filtro casa", one.matches("", -1, -1))
	failures += check("busca ignora caixa", one.matches("MAÇÃ", -1, -1))
	failures += check("busca olha a descricao", one.matches("pinte", -1, -1))
	failures += check("busca sem casar", not one.matches("peixe", -1, -1))
	failures += check("habilidade casa", one.matches("", LevelInfo.Skill.COLORS, -1))
	failures += check("habilidade nao casa", not one.matches("", LevelInfo.Skill.NUMBERS, -1))
	failures += check("mecanica casa", one.matches("", -1, LevelInfo.Mechanic.PAINT))
	failures += check("filtros combinam em E", not one.matches("maçã", LevelInfo.Skill.COLORS, LevelInfo.Mechanic.ACTION))
	failures += _check_free_play()
	var world1 := LevelCatalog.all().filter(func(info: LevelInfo) -> bool: return info.id.begins_with("world1."))
	failures += check("catalogo real acha as 10 fases do mundo 1", world1.size() == 10)
	failures += check("mundo 1 em ordem", world1.size() == 10 and world1[0].id == "world1.level_01" and world1[9].id == "world1.level_10")
	failures += check("filtro real por letras acha a fase 9", LevelCatalog.filter("", LevelInfo.Skill.LETTERS, -1).any(func(info: LevelInfo) -> bool: return info.id == "world1.level_09"))
	print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _check_free_play() -> int:
	var failures := 0
	var original_path := FreePlay.save_path
	FreePlay.save_path = "user://test_free_play.json"
	DirAccess.remove_absolute(FreePlay.save_path)
	FreePlay.load_records()
	var story_stars := Progression.get_stars(1, 1)
	var info := LevelInfo.new()
	info.id = "test.play"
	FreePlay.current = info
	FreePlay.report(2)
	FreePlay.report(1)
	failures += check("guarda a melhor estrela", FreePlay.get_best("test.play") == 2)
	failures += check("conta cada vitoria", FreePlay.get_plays("test.play") == 2)
	FreePlay.report(5)
	failures += check("estrela limitada a 3", FreePlay.get_best("test.play") == 3)
	FreePlay.load_records()
	failures += check("recorde sobrevive ao reload", FreePlay.get_best("test.play") == 3 and FreePlay.get_plays("test.play") == 3)
	failures += check("fase sem registro = 0", FreePlay.get_best("nada") == 0 and FreePlay.get_plays("nada") == 0)
	failures += check("Progression intocada", Progression.get_stars(1, 1) == story_stars)
	FreePlay.current = null
	FreePlay.report(3)
	failures += check("sem fase atual nao registra", FreePlay.get_plays("test.play") == 3)
	DirAccess.remove_absolute(FreePlay.save_path)
	FreePlay.save_path = original_path
	FreePlay.load_records()
	return failures

func check(name: String, ok: bool) -> int:
	print(("PASS " if ok else "FAIL ") + name)
	return 0 if ok else 1
