# Modo Livre Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tela "Modo Livre" que lista toda fase achada em `res://levels/**` (oficial ou de terceiros), com busca, filtro por habilidade e mecânica, recordes próprios e retorno à tela após jogar.

**Architecture:** Ficha `LevelInfo` (`.level.tres`) ao lado de cada fase; autoload `LevelCatalog` varre as pastas no boot; autoload `FreePlay` guarda a sessão e o save `user://free_play.json`; `LevelBase` desvia `win()`/`exit_level()` quando a fase veio do livre. Tela em `ui/free_mode/` com card reutilizável.

**Tech Stack:** Godot 4.7.2, GDScript, Godot MCP Pro (editor sempre aberto), ChatGPT (Chrome) para arte, ImageMagick/cwebp para fatiar.

**Spec:** `docs/superpowers/specs/2026-09-25-modo-livre-design.md`

## Global Constraints

- Todo trabalho no checkout principal `/Users/lucasdoro/Games/floresta-dos-bichinhos` (o editor aberto roda ele; worktree é invisível ao editor).
- Cena, nó e propriedade **só pelo MCP** (`add_node`, `update_property`, `save_scene`...). Nunca escrever `.tscn` à mão. Script pelo `create_script`/`edit_script` do MCP (Edit/Write é bloqueado por hook em caminho do main; `force=true` se o arquivo estiver aberto no editor e sem edição pendente).
- Nunca rodar Godot em modo editor headless com o editor aberto. Teste = `run_headless_scene` (modo jogo, seguro).
- `execute_game_script` não aceita `await` nem `func` aninhado.
- Código em inglês, comentários pt-BR, poucos. Nomes descritivos, return early, sem `else` desnecessário.
- Tween sempre com easing, nunca linear em movimento de UI.
- Troca de cena só por `SceneLoader.go_to(path)`.
- Textura de UI: `Lossless` + `mipmaps/generate=true`.
- Commits sem coautor, sem "Co-Authored-By", sem "Generated with".
- Uma branch para a feature: `feature/modo-livre`, criada da `main`. Não há remote; não fazer push nem merge sem pedido.

---

## Task 0: Pré-requisito — árvore limpa e branch

O checkout principal tem correções anteriores sem commit (quebra-cabeça, tela de carregando, fases 6/7/10, créditos). Elas **não** entram na branch do Modo Livre.

- [ ] **Step 1:** Perguntar ao usuário como commitar as correções pendentes (um commit por assunto na `main`, ou branches próprias). Não prosseguir sem a resposta.
- [ ] **Step 2:** Com `git status --short` limpo (exceto spec e plano do Modo Livre), criar a branch:

```bash
cd /Users/lucasdoro/Games/floresta-dos-bichinhos
git switch -c feature/modo-livre
git add docs/superpowers/specs/2026-09-25-modo-livre-design.md docs/superpowers/plans/2026-09-25-modo-livre.md
git commit -m "docs: spec e plano do Modo Livre"
```

---

## Task 1: `LevelInfo` + `LevelCatalog`

**Files:**
- Create: `core/level_info.gd`
- Create: `autoload/level_catalog.gd`
- Create (fixtures, via editor script): `tools/tests/fixtures/catalog/official/one.level.tres`, `tools/tests/fixtures/catalog/official/two.level.tres`, `tools/tests/fixtures/catalog/community/dup.level.tres`, `tools/tests/fixtures/catalog/community/broken.level.tres`
- Create: `tools/tests/test_free_mode.gd`, `tools/tests/test_free_mode.tscn`
- Modify: `project.godot` (autoload `LevelCatalog`, via MCP `add_autoload`)

**Interfaces:**
- Produces:
  - `LevelInfo.Skill { COLORS, NUMBERS, LETTERS, MEMORY, COORDINATION }`
  - `LevelInfo.Mechanic { DRAG_DROP, PAINT, SEQUENCE, ASSEMBLE, MEMORY, PATH, ACTION, PICK_RIGHT, GUIDE }`
  - `LevelInfo.SKILL_KEYS: Array[String]`, `LevelInfo.MECHANIC_KEYS: Array[String]` (mesma ordem dos enums)
  - `LevelInfo` campos: `id: String`, `title: String`, `description: String`, `cover: Texture2D`, `skills: Array[LevelInfo.Skill]`, `mechanic: LevelInfo.Mechanic`, `author: String`, `scene_path: String`
  - `LevelInfo.matches(text: String, skill: int, mechanic_filter: int) -> bool` (`-1` = sem filtro)
  - `LevelCatalog.scan(root: String) -> Array[LevelInfo]` (static)
  - `LevelCatalog.all() -> Array[LevelInfo]`
  - `LevelCatalog.filter(text: String, skill: int, mechanic: int) -> Array[LevelInfo]`

- [ ] **Step 1: Criar `core/level_info.gd`** (MCP `create_script`)

```gdscript
class_name LevelInfo
extends Resource

## Ficha de uma fase pro Modo Livre. Mora ao lado da cena como <fase>.level.tres;
## o LevelCatalog acha sozinho.

enum Skill { COLORS, NUMBERS, LETTERS, MEMORY, COORDINATION }
enum Mechanic { DRAG_DROP, PAINT, SEQUENCE, ASSEMBLE, MEMORY, PATH, ACTION, PICK_RIGHT, GUIDE }

const SKILL_KEYS: Array[String] = [
	"skill.colors", "skill.numbers", "skill.letters", "skill.memory", "skill.coordination",
]
const MECHANIC_KEYS: Array[String] = [
	"mechanic.drag_drop", "mechanic.paint", "mechanic.sequence", "mechanic.assemble",
	"mechanic.memory", "mechanic.path", "mechanic.action", "mechanic.pick_right", "mechanic.guide",
]

@export var id := ""
## Chave de tr() ou texto literal.
@export var title := ""
@export_multiline var description := ""
@export var cover: Texture2D
@export var skills: Array[Skill] = []
@export var mechanic := Mechanic.DRAG_DROP
## Vazio = fase oficial da Floresta.
@export var author := ""
@export_file("*.tscn") var scene_path := ""

func matches(text: String, skill: int, mechanic_filter: int) -> bool:
	if skill >= 0 and not skills.has(skill):
		return false
	if mechanic_filter >= 0 and mechanic != mechanic_filter:
		return false
	if text.strip_edges().is_empty():
		return true
	var needle := text.strip_edges().to_lower()
	return tr(title).to_lower().contains(needle) or tr(description).to_lower().contains(needle)
```

- [ ] **Step 2: Criar `autoload/level_catalog.gd`** só com o esqueleto (para o teste falhar pelo comportamento, não por parse)

```gdscript
extends Node

const LEVELS_ROOT := "res://levels"
const INFO_SUFFIX := ".level.tres"

static func scan(_root: String) -> Array[LevelInfo]:
	return []
```

Registrar autoload: MCP `add_autoload` name `LevelCatalog`, path `res://autoload/level_catalog.gd`. Se o editor acusar "Identifier not found: LevelCatalog", remover e re-adicionar pelo `EditorAutoloadSettings` via `execute_editor_script` (`autoload_remove("LevelCatalog")` / `autoload_add("LevelCatalog", "res://autoload/level_catalog.gd")`) — foi o que resolveu com o `SceneLoader`.

- [ ] **Step 3: Criar as fixtures** via MCP `execute_editor_script` (`scene_path` aponta para `res://tools/tests/test_video_rules.tscn`, que já existe):

```gdscript
var base := "res://tools/tests/fixtures/catalog"
DirAccess.make_dir_recursive_absolute(base + "/official")
DirAccess.make_dir_recursive_absolute(base + "/community")
var scene := "res://tools/tests/test_video_rules.tscn"
var specs := [
	["official/one.level.tres", "test.one", "Maçã Vermelha", "pinte a maçã", [LevelInfo.Skill.COLORS], LevelInfo.Mechanic.PAINT, "", scene],
	["official/two.level.tres", "test.two", "Contar Peixes", "conte até cinco", [LevelInfo.Skill.NUMBERS], LevelInfo.Mechanic.SEQUENCE, "", scene],
	["community/dup.level.tres", "test.one", "Duplicada", "", [], LevelInfo.Mechanic.PAINT, "ana_dev", scene],
	["community/broken.level.tres", "test.broken", "Sem cena", "", [], LevelInfo.Mechanic.PAINT, "ana_dev", ""],
	["community/three.level.tres", "ana_dev.three", "Pesca das Formas", "formas no lago", [LevelInfo.Skill.COLORS, LevelInfo.Skill.COORDINATION], LevelInfo.Mechanic.ACTION, "ana_dev", scene],
]
for spec in specs:
	var info := LevelInfo.new()
	info.id = spec[1]
	info.title = spec[2]
	info.description = spec[3]
	info.skills.assign(spec[4])
	info.mechanic = spec[5]
	info.author = spec[6]
	info.scene_path = spec[7]
	ResourceSaver.save(info, base + "/" + spec[0])
EditorInterface.get_resource_filesystem().scan()
```

(Arquivo extra `community/three.level.tres` = fase de terceiro válida; ela deve vir **depois** das oficiais.)

- [ ] **Step 4: Escrever o teste** `tools/tests/test_free_mode.gd` (MCP `create_script`) e a cena `tools/tests/test_free_mode.tscn` (MCP `create_scene`, raiz `Node` com esse script):

```gdscript
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
```

- [ ] **Step 5: Rodar e ver falhar**

MCP `run_headless_scene` com `res://tools/tests/test_free_mode.tscn`.
Esperado: `FAIL acha as 3 fichas validas` … `FAILURES:` > 0 (o `levels[0]` pode estourar índice — aceitável como falha; se estourar, o erro é "Out of bounds").

- [ ] **Step 6: Implementar `autoload/level_catalog.gd` completo**

```gdscript
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
```

- [ ] **Step 7: Rodar e ver passar**

MCP `run_headless_scene` `res://tools/tests/test_free_mode.tscn`. Esperado: todas `PASS`, `FAILURES: 0`.
Se "acha as 3" falhar por `list_directory` não devolver subpasta com "/", imprimir `ResourceLoader.list_directory(FIXTURES)` num `execute_editor_script` e ajustar `_find_info_files` para `DirAccess.dir_exists_absolute` em vez do sufixo.

- [ ] **Step 8: Checar editor**: MCP `get_editor_errors` sem erro novo.

- [ ] **Step 9: Commit**

```bash
git add core/level_info.gd core/level_info.gd.uid autoload/level_catalog.gd autoload/level_catalog.gd.uid tools/tests/ project.godot
git commit -m "feat: ficha LevelInfo e LevelCatalog que acha fases por varredura"
```

---

## Task 2: `FreePlay` + desvio no `LevelBase`

**Files:**
- Create: `autoload/free_play.gd`
- Modify: `core/level_base.gd` (`win`, `exit_level`)
- Modify: `tools/tests/test_free_mode.gd` (casos de FreePlay)
- Modify: `project.godot` (autoload `FreePlay`, via MCP)

**Interfaces:**
- Consumes: `LevelInfo` (Task 1), `SceneLoader.go_to(path: String)`
- Produces:
  - `FreePlay.FREE_MODE_SCENE := "res://ui/free_mode/free_mode.tscn"`
  - `FreePlay.current: LevelInfo`
  - `FreePlay.save_path: String` (padrão `user://free_play.json`; teste troca)
  - `FreePlay.start(info: LevelInfo) -> void`, `FreePlay.finish() -> void`
  - `FreePlay.get_best(id: String) -> int`, `FreePlay.get_plays(id: String) -> int`
  - `FreePlay.report(stars: int) -> void`, `FreePlay.reload() -> void`

- [ ] **Step 1: Esqueleto `autoload/free_play.gd`** + registrar autoload `FreePlay` (mesmo procedimento da Task 1 Step 2)

```gdscript
extends Node

const FREE_MODE_SCENE := "res://ui/free_mode/free_mode.tscn"

var save_path := "user://free_play.json"
var current: LevelInfo

func get_best(_id: String) -> int:
	return 0

func get_plays(_id: String) -> int:
	return 0

func report(_stars: int) -> void:
	pass

func reload() -> void:
	pass
```

- [ ] **Step 2: Acrescentar os casos no teste** — em `test_free_mode.gd`, antes do `print("FAILURES...")`:

```gdscript
	failures += _check_free_play()
```

e o método:

```gdscript
func _check_free_play() -> int:
	var failures := 0
	var original_path := FreePlay.save_path
	FreePlay.save_path = "user://test_free_play.json"
	DirAccess.remove_absolute(FreePlay.save_path)
	FreePlay.reload()
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
	FreePlay.reload()
	failures += check("recorde sobrevive ao reload", FreePlay.get_best("test.play") == 3 and FreePlay.get_plays("test.play") == 3)
	failures += check("fase sem registro = 0", FreePlay.get_best("nada") == 0 and FreePlay.get_plays("nada") == 0)
	failures += check("Progression intocada", Progression.get_stars(1, 1) == story_stars)
	FreePlay.current = null
	FreePlay.report(3)
	failures += check("sem fase atual nao registra", FreePlay.get_plays("test.play") == 3)
	DirAccess.remove_absolute(FreePlay.save_path)
	FreePlay.save_path = original_path
	FreePlay.reload()
	return failures
```

- [ ] **Step 3: Rodar e ver falhar** — `run_headless_scene`. Esperado: `FAIL guarda a melhor estrela` etc.

- [ ] **Step 4: Implementar `autoload/free_play.gd`**

```gdscript
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
	reload()

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

func reload() -> void:
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
```

- [ ] **Step 5: Rodar e ver passar** — `run_headless_scene`. Esperado: `FAILURES: 0`.

- [ ] **Step 6: Desviar o `LevelBase`** (MCP `edit_script` em `core/level_base.gd`)

Em `win()`, trocar a linha `Progression.report_level_result(world_number, level_number, stars_earned)` por `_report(stars_earned)`, e trocar `exit_level()` inteiro. Resultado:

```gdscript
func win() -> void:
	if completed:
		return
	completed = true
	await get_tree().create_timer(VICTORY_DELAY).timeout
	var stars_earned := stars_now()
	_report(stars_earned)
	victory_modal.play(stars_earned)

func exit_level() -> void:
	if FreePlay.current:
		FreePlay.finish()
		return
	SceneLoader.go_to("res://ui/world_map/world_map.tscn")

# fase aberta pelo Modo Livre guarda recorde la', sem mexer no mapa da historia
func _report(stars_earned: int) -> void:
	if FreePlay.current:
		FreePlay.report(stars_earned)
		return
	Progression.report_level_result(world_number, level_number, stars_earned)
```

- [ ] **Step 7:** `validate_script` em `core/level_base.gd`; `get_editor_errors` limpo; rodar `test_free_mode.tscn` e `test_video_rules.tscn` de novo (ambos `FAILURES: 0`).

- [ ] **Step 8: Commit**

```bash
git add autoload/free_play.gd autoload/free_play.gd.uid core/level_base.gd tools/tests/test_free_mode.gd project.godot
git commit -m "feat: FreePlay com recordes proprios e LevelBase desviando vitoria e saida no Modo Livre"
```

---

## Task 3: Fichas do mundo 1 + textos

**Files:**
- Create: `levels/world1/level_01.level.tres` … `level_10.level.tres` (via editor script)
- Modify: `assets/i18n/ui.csv` (chaves novas; reimport pelo editor)
- Modify: `tools/tests/test_free_mode.gd` (caso: catálogo real acha 10)

**Interfaces:**
- Consumes: `LevelInfo` (Task 1)
- Produces: ids `world1.level_01` … `world1.level_10`; chaves `level1N.description`

Tabela (título já existe no CSV como `level1N.title`; N = 1..10, fase 10 = `level110`):

| Fase | id | skills | mechanic |
|---|---|---|---|
| 01 | world1.level_01 | COORDINATION | DRAG_DROP |
| 02 | world1.level_02 | COLORS | PAINT |
| 03 | world1.level_03 | NUMBERS | SEQUENCE |
| 04 | world1.level_04 | COORDINATION | ASSEMBLE |
| 05 | world1.level_05 | MEMORY | MEMORY |
| 06 | world1.level_06 | COORDINATION | PATH |
| 07 | world1.level_07 | COORDINATION | ACTION |
| 08 | world1.level_08 | COLORS | DRAG_DROP |
| 09 | world1.level_09 | LETTERS | PICK_RIGHT |
| 10 | world1.level_10 | COORDINATION | GUIDE |

- [ ] **Step 1: Caso no teste** (antes do `print`):

```gdscript
	var world1 := LevelCatalog.all().filter(func(info: LevelInfo) -> bool: return info.id.begins_with("world1."))
	failures += check("catalogo real acha as 10 fases do mundo 1", world1.size() == 10)
	failures += check("mundo 1 em ordem", world1.size() == 10 and world1[0].id == "world1.level_01" and world1[9].id == "world1.level_10")
	failures += check("filtro real por letras acha a fase 9", LevelCatalog.filter("", LevelInfo.Skill.LETTERS, -1).any(func(info: LevelInfo) -> bool: return info.id == "world1.level_09"))
```

- [ ] **Step 2:** Rodar — esperado `FAIL catalogo real acha as 10...`.

- [ ] **Step 3: Chaves no `ui.csv`** (append com Bash; o CSV é arquivo de dados, não cena). Formato `key,pt_BR,it`:

```csv
free_mode.title,Modo Livre,Modalità Libera
free_mode.search,Buscar fase...,Cerca livello...
free_mode.empty,Nenhuma fase encontrada,Nessun livello trovato
free_mode.all,Todas,Tutte
free_mode.by,por %s,di %s
free_mode.studio,Floresta,Floresta
skill.colors,Cores,Colori
skill.numbers,Números,Numeri
skill.letters,Letras,Lettere
skill.memory,Memória,Memoria
skill.coordination,Coordenação,Coordinazione
mechanic.drag_drop,Arrastar,Trascinare
mechanic.paint,Pintar,Dipingere
mechanic.sequence,Sequência,Sequenza
mechanic.assemble,Montar,Montare
mechanic.memory,Memória,Memoria
mechanic.path,Traçar caminho,Tracciare il percorso
mechanic.action,Ação,Azione
mechanic.pick_right,Escolher o certo,Scegliere giusto
mechanic.guide,Conduzir,Guidare
level11.description,Sirva as frutas certas na cesta.,Servi la frutta giusta nel cestino.
level12.description,Pinte o coral com a cor pedida.,Dipingi il corallo del colore richiesto.
level13.description,Toque nos números em ordem.,Tocca i numeri in ordine.
level14.description,Monte o quebra-cabeça da floresta.,Completa il puzzle della foresta.
level15.description,Encontre os pares de cartas.,Trova le coppie di carte.
level16.description,Trace o caminho até o alpiste.,Traccia il percorso fino ai semini.
level17.description,Corte as frutas e desvie da bomba.,Taglia la frutta ed evita la bomba.
level18.description,Separe as flores nas cestas certas.,Metti i fiori nei cestini giusti.
level19.description,Estoure a bolha da letra certa.,Scoppia la bolla della lettera giusta.
level110.description,Leve os filhotes até a fogueira.,Porta i cuccioli fino al falò.
```

Conferir antes com `grep -c "^free_mode\.\|^skill\.\|^mechanic\.\|description," assets/i18n/ui.csv` que nenhuma chave já existe. Reimportar: `execute_editor_script` → `EditorInterface.get_resource_filesystem().reimport_files(["res://assets/i18n/ui.csv"])`.

- [ ] **Step 4: Criar as 10 fichas** (`execute_editor_script`; capa entra na Task 4):

```gdscript
var table := [
	[LevelInfo.Skill.COORDINATION, LevelInfo.Mechanic.DRAG_DROP],
	[LevelInfo.Skill.COLORS, LevelInfo.Mechanic.PAINT],
	[LevelInfo.Skill.NUMBERS, LevelInfo.Mechanic.SEQUENCE],
	[LevelInfo.Skill.COORDINATION, LevelInfo.Mechanic.ASSEMBLE],
	[LevelInfo.Skill.MEMORY, LevelInfo.Mechanic.MEMORY],
	[LevelInfo.Skill.COORDINATION, LevelInfo.Mechanic.PATH],
	[LevelInfo.Skill.COORDINATION, LevelInfo.Mechanic.ACTION],
	[LevelInfo.Skill.COLORS, LevelInfo.Mechanic.DRAG_DROP],
	[LevelInfo.Skill.LETTERS, LevelInfo.Mechanic.PICK_RIGHT],
	[LevelInfo.Skill.COORDINATION, LevelInfo.Mechanic.GUIDE],
]
for index in table.size():
	var number := index + 1
	var info := LevelInfo.new()
	info.id = "world1.level_%02d" % number
	info.title = "level1%d.title" % number
	info.description = "level1%d.description" % number
	info.skills.assign([table[index][0]])
	info.mechanic = table[index][1]
	info.scene_path = "res://levels/world1/level_%02d.tscn" % number
	ResourceSaver.save(info, "res://levels/world1/level_%02d.level.tres" % number)
EditorInterface.get_resource_filesystem().scan()
```

- [ ] **Step 5:** Rodar teste — `FAILURES: 0`. Abrir um `.level.tres` no inspector (`read_resource`) e conferir campos.

- [ ] **Step 6: Commit**

```bash
git add levels/world1/*.level.tres assets/i18n/ tools/tests/test_free_mode.gd
git commit -m "feat: fichas do Modo Livre para as 10 fases do mundo 1"
```

---

## Task 4: Arte — spritesheet do ChatGPT e capas

**Files:**
- Create: `assets/art/UI/FreeMode/{filter_bar,search_field,card_frame,dropdown,replay}.webp`
- Create: `assets/art/UI/FreeMode/chip_{colors,numbers,letters,memory,coordination}{,_on}.webp`
- Create: `assets/art/UI/FreeMode/covers/level_01.webp` … `level_10.webp`
- Modify: `levels/world1/level_XX.level.tres` (campo `cover`)

**Interfaces:**
- Produces: os caminhos acima (Tasks 6 e 7 usam exatamente esses nomes).

- [ ] **Step 1: Pedir a spritesheet** na conversa "Mockup Modo Livre" do ChatGPT (Chrome, `claude-in-chrome`). Digitar o prompt **numa linha só** (quebra de linha envia pela metade):

> A partir do mockup aprovado, gere uma spritesheet com fundo transparente (PNG), elementos separados com bastante espaço entre si, sem texto em nenhum elemento, mesmo estilo: 1) faixa horizontal de madeira da barra de filtros (vazia); 2) campo de busca arredondado bege vazio com a lupa à esquerda; 3) cinco chips quadrados arredondados de habilidade SEM texto — paleta verde, "123" azul, "ABC" vermelho, cérebro roxo, mão laranja — cada um em duas versões: normal e selecionado (com contorno brilhante verde-claro); 4) botão de dropdown bege vazio com a setinha à direita; 5) moldura de card vazia (madeira clara/pergaminho, cantos arredondados, sem título nem imagem); 6) ícone de replay (duas setas em círculo) cinza-escuro.

Aguardar a imagem (≈1–2 min, `wait` em lote + screenshot).

- [ ] **Step 2: Baixar** — **pedir permissão ao usuário** (nome do arquivo, origem ChatGPT, tamanho). Com o sim, usar o botão de download do visualizador; o arquivo cai em `~/Downloads`. Copiar para o scratchpad como `free_mode_sheet.png`.

- [ ] **Step 3: Fatiar** — achar os blocos por transparência e recortar:

```bash
cd <scratchpad>
magick free_mode_sheet.png -alpha extract -threshold 5% -morphology Dilate Disk:6 mask.png
magick mask.png -define connected-components:verbose=true -define connected-components:area-threshold=2000 -connected-components 8 null: | tail -n +3
```

Cada linha dá `id: WxH+X+Y`. Olhar a sheet (Read) e mapear cada retângulo ao nome. Recortar e exportar:

```bash
magick free_mode_sheet.png -crop WxH+X+Y +repage -trim +repage part.png
cwebp -lossless part.png -o /Users/lucasdoro/Games/floresta-dos-bichinhos/assets/art/UI/FreeMode/<nome>.webp
```

Nomes: `filter_bar`, `search_field`, `dropdown`, `card_frame`, `replay`, `chip_colors`, `chip_colors_on`, `chip_numbers`, `chip_numbers_on`, `chip_letters`, `chip_letters_on`, `chip_memory`, `chip_memory_on`, `chip_coordination`, `chip_coordination_on`.

Conferir cada recorte com Read antes de seguir.

- [ ] **Step 4: Import** — deixar o editor importar (foco / `reload_project` não; usar `EditorInterface.get_resource_filesystem().scan()`), depois nos `.import` desses arquivos garantir `compress/mode=0` (Lossless) e `mipmaps/generate=true` via `execute_editor_script` (mesmo método usado nos `.import` do puzzle: editar a chave e `reimport_files`).

- [ ] **Step 5: Capas do mundo 1** — para cada fase N:
  1. `play_scene` `res://levels/world1/level_0N.tscn` (10 = `level_10`).
  2. Esperar a fase montar (chamar a próxima tool depois de ~4 s de jogo).
  3. `execute_game_script`:
     ```gdscript
     get_viewport().get_texture().get_image().save_png("<scratchpad>/cover_%02d.png" % N)
     _mcp_print("ok")
     ```
  4. `stop_scene`.
  5. Recortar 16:9 central e reduzir:
     ```bash
     magick <scratchpad>/cover_NN.png -gravity center -crop 1600x900+0+60 +repage -resize 640x360 <scratchpad>/cover_NN_small.png
     cwebp -q 90 <scratchpad>/cover_NN_small.png -o /Users/lucasdoro/Games/floresta-dos-bichinhos/assets/art/UI/FreeMode/covers/level_NN.webp
     ```
     Olhar cada capa com Read; se o header da fase dominar, ajustar o `+Y` do crop.

- [ ] **Step 6: Ligar as capas nas fichas** (`execute_editor_script`):

```gdscript
for number in range(1, 11):
	var path := "res://levels/world1/level_%02d.level.tres" % number
	var info: LevelInfo = load(path)
	info.cover = load("res://assets/art/UI/FreeMode/covers/level_%02d.webp" % number)
	ResourceSaver.save(info, path)
```

- [ ] **Step 7:** Rodar `test_free_mode.tscn` (continua `FAILURES: 0`).

- [ ] **Step 8: Commit**

```bash
git add assets/art/UI/FreeMode/ levels/world1/*.level.tres
git commit -m "feat: arte do Modo Livre (barra, chips, card) e capas das fases do mundo 1"
```

---

## Task 5: `PlaqueHeader` compartilhado

**Files:**
- Create: `core/plaque_header.gd`, `core/plaque_header.tscn`
- Modify: `ui/world_map/world_map.tscn` (troca o `WorldHeader` inline pela instância)

**Interfaces:**
- Produces: `core/plaque_header.tscn`, raiz `Control` com script `PlaqueHeader`, `@export var title_key: String`; filhos `Plaque` (`TextureRect`) e `Title` (`Label`).

- [ ] **Step 1: Script** `core/plaque_header.gd`:

```gdscript
@tool
class_name PlaqueHeader
extends Control

## Placa de madeira com titulo, topo padrao das telas (mapa, Modo Livre).

@export var title_key := "":
	set(value):
		title_key = value
		if is_node_ready():
			$Title.text = value

func _ready() -> void:
	$Title.text = title_key
```

- [ ] **Step 2: Cena** `core/plaque_header.tscn` via MCP (`create_scene` raiz `Control` nome `PlaqueHeader`, `attach_script`):
  - raiz: `size = Vector2(750, 240)`, `mouse_filter = 2`.
  - `Plaque` (`TextureRect`): `anchor_right = 1`, `anchor_bottom = 1`, `mouse_filter = 2`, `texture = res://assets/art/UI/WorldMap/world_header_plaque.webp`, `expand_mode = 1`, `stretch_mode = 5`.
  - `Title` (`Label`): `anchor_right = 1`, `offset_top = 24`, `offset_bottom = 134`, `grow_horizontal = 2`, `theme_type_variation = &"Title80"`, `theme_override_colors/font_color = Color(1,1,1,1)`, `theme_override_colors/font_outline_color = Color(0.33,0.19,0.08,1)`, `theme_override_constants/outline_size = 12`, `horizontal_alignment = 1`.
  - `save_scene`.

- [ ] **Step 3: Trocar no mapa** — abrir `ui/world_map/world_map.tscn` no editor:
  1. `add_scene_instance` de `core/plaque_header.tscn` sob a raiz, nome temporário `PlaqueHeaderNew`; copiar as propriedades de layout do `WorldHeader` atual (`anchor_left = 0.5`, `anchor_right = 0.5`, `offset_left = -375`, `offset_top = 20`, `offset_right = 375`, `offset_bottom = 260`, `mouse_filter = 2`), `title_key = "worldmap.world1.title"`.
  2. `move_node` do `Subtitle` para dentro de `PlaqueHeaderNew`.
  3. `delete_node` `WorldHeader`; `rename_node` `PlaqueHeaderNew` → `WorldHeader`; marcar `unique_name_in_owner = true` (o script usa `%WorldHeader`).
  4. `move_node` para a mesma posição de irmão do antigo (antes do `BackButton`).
  5. `save_scene`.

- [ ] **Step 4: Validar mapa** — `play_scene` `res://ui/world_map/world_map.tscn`, screenshot via `execute_game_script` (save_png no scratchpad), comparar com o antes (tirar um "antes" no Step 3.0, antes de mexer). Placa, título "Mundo 1" e subtítulo curvado no mesmo lugar; animação de entrada do header (`_header.offset_top = -340`) funcionando. `stop_scene`.

- [ ] **Step 5: Commit**

```bash
git add core/plaque_header.gd core/plaque_header.gd.uid core/plaque_header.tscn ui/world_map/world_map.tscn
git commit -m "refactor: placa de titulo do mapa vira cena compartilhada PlaqueHeader"
```

---

## Task 6: Card `LevelCard`

**Files:**
- Create: `ui/free_mode/level_card.gd`, `ui/free_mode/level_card.tscn`

**Interfaces:**
- Consumes: `LevelInfo`, `FreePlay.get_best/get_plays`, arte da Task 4
- Produces: `class_name LevelCard extends Control`; `signal chosen(info: LevelInfo)`; `setup(level: LevelInfo) -> void` (chamar **depois** de `add_child`)

- [ ] **Step 1: Script** `ui/free_mode/level_card.gd`:

```gdscript
class_name LevelCard
extends Control

## Card do Modo Livre. Toque abre a fase; arrastar rola a lista sem abrir
## (mouse_filter PASS deixa o ScrollContainer receber o arrasto).

signal chosen(info: LevelInfo)

const STAR_ON := preload("res://assets/art/UI/WorldMap/star_on.webp")
const STAR_OFF := preload("res://assets/art/UI/WorldMap/star_off.webp")
const TAP_SLOP := 24.0
const POP_SCALE := 1.06
const POP_TIME := 0.12

var info: LevelInfo
var _press_position := Vector2.INF

@onready var _title: Label = %Title
@onready var _cover: TextureRect = %Cover
@onready var _description: Label = %Description
@onready var _stars: Array[TextureRect] = [%Star1, %Star2, %Star3]
@onready var _plays: Label = %Plays
@onready var _author: Label = %Author

func _ready() -> void:
	resized.connect(_center_pivot)
	_center_pivot()
	gui_input.connect(_on_gui_input)

func setup(level: LevelInfo) -> void:
	info = level
	_title.text = level.title
	_description.text = level.description
	_cover.texture = level.cover
	var best := FreePlay.get_best(level.id)
	for index in _stars.size():
		_stars[index].texture = STAR_ON if index < best else STAR_OFF
	_plays.text = "x%d" % FreePlay.get_plays(level.id)
	var author_name := tr("free_mode.studio") if level.author.is_empty() else level.author
	_author.text = tr("free_mode.by") % author_name

func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_position = button.global_position
		return
	if button.global_position.distance_to(_press_position) > TAP_SLOP:
		return
	_press_position = Vector2.INF
	Audio.play_click()
	_pop()
	chosen.emit(info)

func _pop() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE * POP_SCALE, POP_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_TIME).set_ease(Tween.EASE_IN)

func _center_pivot() -> void:
	pivot_offset = size / 2.0
```

- [ ] **Step 2: Cena** `ui/free_mode/level_card.tscn` via MCP (`create_scene` raiz `Control` nome `LevelCard`, `attach_script`, theme `res://ui/theme.tres`):
  - raiz: `custom_minimum_size = Vector2(400, 440)`, `size_flags_horizontal = 3`, `mouse_filter = 1` (PASS).
  - `Frame` (`NinePatchRect`, full rect, `mouse_filter = 2`, `texture = card_frame.webp`, margens de patch ≈ 40 — ajustar olhando).
  - `Content` (`VBoxContainer`, full rect com margem 22, `mouse_filter = 2`, `separation = 8`):
    - `Title` (`Label`, unique, fonte 34, cor `Color(0.33,0.19,0.08)`, centro, `clip_text = true`, `text_overrun_behavior = 3`).
    - `Cover` (`TextureRect`, unique, `custom_minimum_size.y = 200`, `expand_mode = 1`, `stretch_mode = 6` keep aspect covered, `clip_contents = true`).
    - `Description` (`Label`, unique, fonte 22, cor `Color(0.3,0.22,0.12)`, centro, `autowrap_mode = 3`, `max_lines_visible = 2`, `text_overrun_behavior = 3`, `custom_minimum_size.y = 60`).
    - `Footer` (`HBoxContainer`, `separation = 6`, `alignment = 1`):
      - `Star1`, `Star2`, `Star3` (`TextureRect`, unique, 40×40, `expand_mode = 1`, `stretch_mode = 5`).
      - `Spacer` (`Control`, `size_flags_horizontal = 3`).
      - `ReplayIcon` (`TextureRect`, 32×32, `replay.webp`).
      - `Plays` (`Label`, unique, fonte 24, cor escura).
      - `Spacer2` (`Control`, `size_flags_horizontal = 3`).
      - `Author` (`Label`, unique, fonte 20, cor escura, `text_overrun_behavior = 3`, `clip_text = true`, `custom_minimum_size.x = 120`).
  - todos os filhos `mouse_filter = 2`. `save_scene`. `get_editor_screenshot` para conferir.

- [ ] **Step 3: Validar isolado** — `execute_editor_script` que instancia o card, `add_child` numa cena de teste aberta, chama `setup(load("res://levels/world1/level_02.level.tres"))`, e `get_editor_screenshot`; título "Recife das Cores", capa, descrição 2 linhas, estrelas vazias, "x0", "por Floresta". Remover o nó de teste sem salvar.

- [ ] **Step 4: Commit**

```bash
git add ui/free_mode/level_card.gd ui/free_mode/level_card.gd.uid ui/free_mode/level_card.tscn
git commit -m "feat: card de fase do Modo Livre"
```

---

## Task 7: Tela `free_mode.tscn` + botão do menu

**Files:**
- Create: `ui/free_mode/free_mode.gd`, `ui/free_mode/free_mode.tscn`
- Modify: `ui/menu/main_menu.gd` (liga o botão `FreeMode`)

**Interfaces:**
- Consumes: `LevelCatalog.filter`, `LevelInfo.MECHANIC_KEYS`, `LevelCard` (`setup`, `chosen`), `FreePlay.start`, `PlaqueHeader`, `FreePlay.FREE_MODE_SCENE`

- [ ] **Step 1: Script** `ui/free_mode/free_mode.gd`:

```gdscript
extends Control

## Modo Livre: toda fase do LevelCatalog, filtrada por busca, habilidade e mecanica.

const CARD_SCENE := preload("res://ui/free_mode/level_card.tscn")
const MENU_SCENE := "res://ui/menu/main_menu.tscn"
const MIN_CARD_WIDTH := 400.0
const CARD_ENTER_TIME := 0.3
const CARD_STAGGER := 0.04
const CARD_START_SCALE := 0.9

var _chip_group := ButtonGroup.new()

@onready var _search: LineEdit = %SearchField
@onready var _mechanic: OptionButton = %MechanicDropdown
@onready var _chips: Array[BaseButton] = [%ChipColors, %ChipNumbers, %ChipLetters, %ChipMemory, %ChipCoordination]
@onready var _scroll: ScrollContainer = %Scroll
@onready var _grid: GridContainer = %Grid
@onready var _empty: Label = %EmptyLabel

func _ready() -> void:
	%BackButton.pressed.connect(SceneLoader.go_to.bind(MENU_SCENE))
	_chip_group.allow_unpress = true
	for chip in _chips:
		chip.button_group = _chip_group
		# ButtonGroup.pressed nao dispara ao desligar o chip aceso; toggled dispara nos dois
		chip.toggled.connect(func(_on: bool) -> void: _refresh())
	_search.text_changed.connect(func(_text: String) -> void: _refresh())
	_fill_mechanics()
	_mechanic.item_selected.connect(func(_index: int) -> void: _refresh())
	_scroll.resized.connect(_update_columns)
	_update_columns()
	_refresh()

func _fill_mechanics() -> void:
	_mechanic.add_item("free_mode.all")
	for key in LevelInfo.MECHANIC_KEYS:
		_mechanic.add_item(key)
	_mechanic.select(0)

func _update_columns() -> void:
	_grid.columns = maxi(1, floori(_scroll.size.x / MIN_CARD_WIDTH))

func _selected_skill() -> int:
	return _chips.find(_chip_group.get_pressed_button())

func _refresh() -> void:
	for old_card in _grid.get_children():
		_grid.remove_child(old_card)
		old_card.queue_free()
	var levels := LevelCatalog.filter(_search.text, _selected_skill(), _mechanic.selected - 1)
	_empty.visible = levels.is_empty()
	for index in levels.size():
		var card: LevelCard = CARD_SCENE.instantiate()
		_grid.add_child(card)
		card.setup(levels[index])
		card.chosen.connect(FreePlay.start)
		_enter(card, index)

func _enter(card: Control, index: int) -> void:
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * CARD_START_SCALE
	var delay := index * CARD_STAGGER
	var tween := card.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, CARD_ENTER_TIME).set_delay(delay)
	tween.tween_property(card, "scale", Vector2.ONE, CARD_ENTER_TIME).set_delay(delay)
```

- [ ] **Step 2: Cena** `ui/free_mode/free_mode.tscn` via MCP (raiz `Control` `FreeMode`, full rect, theme `res://ui/theme.tres`, script):
  - `Background`: instância de `res://backgrounds/menu_background.tscn`; `modulate = Color(0.7, 0.7, 0.7)` (escurecido).
  - `Header`: instância de `core/plaque_header.tscn`, `anchor_left/right = 0.5`, `offset_left = -375`, `offset_top = 10`, `offset_right = 375`, `offset_bottom = 250`, `title_key = "free_mode.title"`. Ajustar para não sobrepor a barra (olhar screenshot).
  - `BackButton`: instância de `core/juicy_button.tscn`, `texture_normal = button_back.webp`, `offset_left = 50`, `offset_top = 28`, `offset_right = 170`, `offset_bottom = 143`, `burst_count = 0`, unique.
  - `FilterBar` (`NinePatchRect`, `filter_bar.webp`, anchors topo largura total, `offset_left = 40`, `offset_right = -40`, `offset_top = 200`, `offset_bottom = 330`):
    - `Row` (`HBoxContainer`, full rect com margem 20, `separation = 16`, `alignment = 1`):
      - `SearchField` (`LineEdit`, unique, `custom_minimum_size = Vector2(380, 90)`, `placeholder_text = "free_mode.search"`, stylebox `normal`/`focus` = `StyleBoxTexture` com `search_field.webp` e `content_margin_left = 80`, fonte 32, `clear_button_enabled = true`).
      - `ChipColors`, `ChipNumbers`, `ChipLetters`, `ChipMemory`, `ChipCoordination` (`TextureButton`, unique, `toggle_mode = true`, `texture_normal = chip_X.webp`, `texture_pressed = chip_X_on.webp`, `custom_minimum_size = Vector2(110, 110)`, `ignore_texture_size = true`, `stretch_mode = 5`), cada um com `Label` filho (`skill.X`, fonte 20, branca com contorno escuro 6, ancorado embaixo, `mouse_filter = 2`).
      - `MechanicDropdown` (`OptionButton`, unique, `custom_minimum_size = Vector2(300, 90)`, stylebox com `dropdown.webp`, fonte 30).
  - `Scroll` (`ScrollContainer`, unique, anchors full, `offset_left = 40`, `offset_top = 350`, `offset_right = -40`, `offset_bottom = -20`, `horizontal_scroll_mode = 0`, `scroll_deadzone = 12`):
    - `Grid` (`GridContainer`, unique, `size_flags_horizontal = 3`, `h_separation = 24`, `v_separation = 24`).
  - `EmptyLabel` (`Label`, unique, centro da tela, `text = "free_mode.empty"`, fonte 44, branca com contorno, `visible = false`).
  - `save_scene`.

- [ ] **Step 3: Menu** — em `ui/menu/main_menu.gd`, no `_ready`, depois da linha do `StoryMode`:

```gdscript
	$MenuUI/Buttons/FreeMode.pressed.connect(SceneLoader.go_to.bind(FreePlay.FREE_MODE_SCENE))
```

- [ ] **Step 4: Validar em jogo (16:9)** — `play_scene` `res://ui/menu/main_menu.tscn`; clicar "Modo Livre" (`simulate_mouse_click` com coordenada de janela = `get_tree().root.get_final_transform() * ponto_viewport`); screenshot via `execute_game_script` save_png. Esperado: placa "Modo Livre", barra com busca/chips/dropdown, 4 colunas, 10 cards com capa, "x0", "por Floresta". Conferir com Read.

- [ ] **Step 5: Filtros** — via `execute_game_script` (sem await; checar na chamada seguinte):
  - `%SearchField.text = "cores"; %SearchField.text_changed.emit("cores")` → grid com 1 card (`Recife das Cores`).
  - limpar busca; `%ChipLetters.button_pressed = true` → 1 card (fase 9).
  - `%ChipLetters.button_pressed = false` → 10 cards.
  - `%MechanicDropdown.select(1); %MechanicDropdown.item_selected.emit(1)` (Arrastar) → 2 cards (fases 1 e 8).
  - busca "zzz" → `EmptyLabel.visible == true`.

- [ ] **Step 6: 4:3** — `execute_game_script`: `get_window().size = Vector2i(1440, 1080)`; screenshot; esperado 3 colunas, nada cortado na barra. Voltar `Vector2i(1920, 1080)`.

- [ ] **Step 7: Rolagem não abre fase** — injetar arrasto (press em um card, motion 200 px pra cima, release) com `Input.parse_input_event` em coordenadas de janela; na chamada seguinte, conferir que a cena atual ainda é `free_mode` e `Scroll.scroll_vertical > 0`.

- [ ] **Step 8: Commit**

```bash
git add ui/free_mode/ ui/menu/main_menu.gd
git commit -m "feat: tela do Modo Livre com busca, filtros e grade de cards"
```

---

## Task 8: Fluxo ponta a ponta + documentação

**Files:**
- Create: `docs/MODDING.md`
- Modify: `CLAUDE.md` (linha em "Sistemas transversais"; árvore `autoload/`)

- [ ] **Step 1: Fluxo** — em jogo: menu → Modo Livre → tocar card "Recife das Cores" → fase carrega (`FreePlay.current.id == "world1.level_02"`). Forçar vitória: `execute_game_script` → `get_tree().current_scene.win()`. Depois de ~1 s, tocar "avançar" do modal (ou `get_tree().current_scene.exit_level()`). Esperado: volta para `free_mode.tscn`, card da fase 2 com estrelas e "x1"; `FreePlay.current == null`; `Progression.get_stars(1, 2)` igual ao de antes do teste.

- [ ] **Step 2: Modo história intacto** — do menu, Modo História → mapa → fase 1 → `win()` → `exit_level()` → volta ao **mapa**, estrela gravada em `Progression`.

- [ ] **Step 3: Limpar save de teste** — apagar `user://free_play.json` gerado no Step 1 se o usuário não quiser manter (perguntar).

- [ ] **Step 4: `docs/MODDING.md`**:

```markdown
# Criando uma fase para o Modo Livre

1. Crie a pasta `levels/<seu_nome>/<sua_fase>/`.
2. Crie a cena da fase. A raiz estende `LevelBase` (`core/level_base.gd`):
   chame `mistake()` a cada erro e `win()` ao vencer. Estrelas, modal de vitória,
   botão voltar e o save do Modo Livre vêm de graça.
3. No FileSystem do Godot: botão direito na pasta → Novo Recurso → `LevelInfo`,
   salve como `<sua_fase>.level.tres` e preencha no inspector:
   - `id`: único, ex. `seu_nome.sua_fase`
   - `title` / `description`: texto (ou chave de tradução do `ui.csv`)
   - `cover`: imagem 16:9 (640×360 recomendado)
   - `skills`: Cores, Números, Letras, Memória, Coordenação (uma ou mais)
   - `mechanic`: o tipo de jogo
   - `author`: seu nome (aparece como "por <autor>")
   - `scene_path`: a cena do passo 2
4. Rode o jogo: a fase aparece no Modo Livre. Nenhum outro arquivo precisa mudar.

Ficha com `id` repetido ou sem cena é ignorada com aviso no Output.
```

- [ ] **Step 5: `CLAUDE.md`** — na tabela "Sistemas transversais", nova linha:

```
| Modo Livre | Fase aparece por ficha `LevelInfo` (`<fase>.level.tres`) em qualquer pasta de `res://levels/`; autoload `LevelCatalog` varre no boot. Autoload `FreePlay` guarda sessão e recordes em `user://free_play.json`, separado da `Progression`. Guia: `docs/MODDING.md` |
```

e na árvore: `autoload/     Progression, Settings, Audio, Voice, SceneLoader, LevelCatalog, FreePlay`.

- [ ] **Step 6: Commit**

```bash
git add docs/MODDING.md CLAUDE.md
git commit -m "docs: guia de fase para o Modo Livre"
```

- [ ] **Step 7:** Reportar ao usuário com screenshots (SendUserFile) e perguntar sobre merge — **não mergear sem pedido**.
