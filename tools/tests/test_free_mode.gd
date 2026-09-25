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
	print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func check(name: String, ok: bool) -> int:
	print(("PASS " if ok else "FAIL ") + name)
	return 0 if ok else 1
