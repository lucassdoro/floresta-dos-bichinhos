# Fundos em vídeo com fallback — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Todas as telas (menu, mapa, 10 fases) tocam o vídeo de fundo da versão Flutter quando `Settings.quality >= 1`; em `quality == 0` (escolhido no menu ou imposto pelo benchmark do primeiro boot) ficam no still + shader de hoje.

**Architecture:** Cada cena de `backgrounds/` ganha um `VideoStreamPlayer` sobre o `Still`, e um script único `backgrounds/background.gd` (`class_name SceneBackground`) cobre o viewport, escolhe o modo por `Settings.quality` e troca com fade. `core/video_benchmark.gd` roda no splash do primeiro boot, mede fps tocando um vídeo e grava `quality = 0` se reprovar. Os 11 vídeos são Ogg Theora em `assets/video/`.

**Tech Stack:** Godot 4.7.2-stable, GDScript, `VideoStreamPlayer` (Theora nativo), Godot MCP Pro (toda edição de cena), `ffmpeg2theora` (Homebrew) para encode, `run_headless_script` para os testes de regra pura.

**Spec:** `docs/superpowers/specs/2026-09-06-fundos-em-video-design.md`

## Global Constraints

- Godot **4.7.2-stable**, GDScript. Renderer Mobile. Resolução base 1920×1080, stretch `canvas_items`, aspect `expand`.
- **Toda cena é editada pelos tools do Godot MCP Pro**, com o editor aberto. Nunca escrever `.tscn` na mão. Tool que voltar `-32001` é só repetir.
- **NUNCA** rodar o Godot em modo editor num segundo processo (`--import`, `-e`). `run_headless_script` (modo jogo) é seguro.
- `open_scene` **antes** de qualquer `add_node`/`update_property`; `create_scene` não abre a cena.
- Edits de `.gd` no disco com o editor aberto: `execute_editor_script` com `EditorInterface.get_resource_filesystem().scan()` antes de tocar o jogo.
- `execute_game_script` / `execute_editor_script` não devolvem `print`: ler estado por `get_game_node_properties` ou por `_mcp_print`.
- `play_scene` roda a main scene (splash). Fase específica: `execute_editor_script` com `EditorInterface.play_custom_scene(path)`.
- Código em inglês, comentários em pt-BR, poucos. Nomes de variáveis descritivos. Return early, sem `if/else`.
- Commits sem coautor, sem "Generated with". Trabalho direto na `main`.
- Preferir inspector (`update_property`) a código. Animação sempre com `Tween` e easing.
- Vídeos: Ogg Theora, sem áudio, 24 fps, maior lado ≤ 1280, `-v 7`, total ≤ 35 MB.
- Fundo nunca carrega gameplay; UI ancora em `Control`.

---

## Estrutura de arquivos

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `assets/video/{menu,worldmap,level11,level12,level13,level14,level15,level17,level18,level19,level110}.ogv` | criar | 11 vídeos Theora |
| `backgrounds/background.gd` | criar | `SceneBackground`: cobrir viewport, modo still/vídeo, fade |
| `backgrounds/menu_background.gd` (+ `.uid`) | apagar | substituído pelo de cima |
| `backgrounds/{menu,worldmap,level11..15,level17,level18}_background.tscn` | modificar | nó `Video` + script novo |
| `backgrounds/level19_background.tscn`, `backgrounds/level110_background.tscn` | criar | fundos próprios das fases 9 e 10 |
| `levels/world1/level_0{1,3,4,5,7,8}.tscn` | modificar | override de script da instância `Background` aponta pro script novo |
| `levels/world1/level_06.tscn` | modificar | `Background` inline com o script novo |
| `levels/world1/level_09.tscn` | modificar | instancia `level19_background` |
| `levels/world1/level_10.tscn` | modificar | instancia `level110_background` como primeiro filho |
| `autoload/settings.gd` | modificar | chave `benchmarked` |
| `core/video_benchmark.gd` | criar | `VideoBenchmark`: mede fps, decide, grava |
| `ui/splash/doma_splash.gd` | modificar | dispara benchmark, segura a troca de cena |
| `tools/tests/test_video_rules.gd` | criar | teste headless das regras puras |
| `CLAUDE.md` | modificar | seção "Fundos" |

---

### Task 1: Encoder e os 11 vídeos Theora

**Files:**
- Create: `assets/video/*.ogv` (11 arquivos)

**Interfaces:**
- Produces: `res://assets/video/<chave>.ogv`, chaves `menu`, `worldmap`, `level11`, `level12`, `level13`, `level14`, `level15`, `level17`, `level18`, `level19`, `level110`. Task 4, 5 e 6 carregam por esses caminhos.

- [ ] **Step 1: Instalar o encoder**

```bash
brew install ffmpeg2theora && ffmpeg2theora --version
```

Esperado: `ffmpeg2theora 0.30`. A fórmula está deprecada (some em 2027-04-06), mas instala. Se o `brew install` falhar, parar e reportar: não há outro encoder Theora na máquina (o `ffmpeg` do Homebrew só decodifica).

- [ ] **Step 2: Extrair o vídeo da fase 10 da branch antiga**

O `git show` de binário passa pelo hook do `rtk` e corrompe o arquivo. Usar `rtk proxy`:

```bash
SCRATCH="$(ls -d /private/tmp/claude-501/-Users-lucasdoro-Games-floresta-dos-bichinhos/*/scratchpad | head -1)"
rtk proxy git -C ../floresta-dos-bichinhos-old show feature/phase-10-plan-3b246a:assets/Video/Level110Background.mp4 > "$SCRATCH/Level110Background.mp4"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,nb_frames -of default=nw=1 "$SCRATCH/Level110Background.mp4"
```

Esperado: `width=1280 height=720 nb_frames=97`. Se vier `moov atom not found`, o arquivo passou pelo filtro: refazer com `rtk proxy`.

- [ ] **Step 3: Encodar os 11 vídeos**

```bash
mkdir -p assets/video
SRC=../floresta-dos-bichinhos-old/assets/Video
SCRATCH="$(ls -d /private/tmp/claude-501/-Users-lucasdoro-Games-floresta-dos-bichinhos/*/scratchpad | head -1)"
for pair in menu:MenuBackground worldmap:WorldMapBackground level11:Level11Background level12:Level12Background level13:Level13Background level14:Level14Background level15:Level15Background level17:Level17Background level18:Level18Background level19:Level19Background; do
  key=${pair%%:*}; name=${pair##*:}
  extra=""
  [ "$key" = "menu" ] && extra="-x 1280 -y 858"
  ffmpeg2theora --noaudio -v 7 -F 24 $extra -o "assets/video/$key.ogv" "$SRC/$name.mp4"
done
ffmpeg2theora --noaudio -v 7 -F 24 -o assets/video/level110.ogv "$SCRATCH/Level110Background.mp4"
```

- [ ] **Step 4: Conferir tamanho, resolução e ausência de áudio**

```bash
du -ch assets/video/*.ogv | tail -1
for f in assets/video/*.ogv; do echo "$f $(ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,r_frame_rate -of csv=p=0 "$f" | tr '\n' ' ')"; done
```

Esperado: total ≤ 35M; cada linha só com `video,theora,<w>,<h>,24/1` (nenhuma linha `audio`); `menu.ogv` em `1280,858`. Se o total passar de 35M, reencodar todos com `-v 6` e conferir de novo.

- [ ] **Step 5: Conferir que o Godot carrega os vídeos**

Foco na janela do editor (o FileSystem reimporta sozinho). Depois:

`execute_editor_script`:
```gdscript
EditorInterface.get_resource_filesystem().scan()
var stream = load("res://assets/video/menu.ogv")
_mcp_print(stream != null and stream is VideoStreamTheora)
_mcp_print(load("res://assets/video/level110.ogv") is VideoStreamTheora)
```

Esperado: `true` duas vezes.

- [ ] **Step 6: Commit**

```bash
git add assets/video
git commit -m "feat: videos de fundo em Ogg Theora para menu, mapa e 9 fases"
```

---

### Task 2: Regras puras com teste headless (`Settings.benchmarked`, `VideoBenchmark.passes`, `SceneBackground.wants_video`/`cover_scale`)

**Files:**
- Modify: `autoload/settings.gd`
- Create: `core/video_benchmark.gd`
- Create: `backgrounds/background.gd`
- Test: `tools/tests/test_video_rules.gd`

**Interfaces:**
- Produces: `Settings.benchmarked: bool` (persistido em `user://settings.cfg`, chave `benchmarked`).
- Produces: `class_name VideoBenchmark extends Node`, `static func passes(average_fps: float, refresh_rate: float) -> bool`. Runtime completo entra na Task 6; aqui só a regra.
- Produces: `class_name SceneBackground extends Node2D`, `static func wants_video(quality: int) -> bool`, `static func cover_scale(viewport_size: Vector2, texture_size: Vector2) -> float`. Comportamento de cena completo entra na Task 3; aqui só as estáticas.

- [ ] **Step 1: Escrever o teste headless**

Criar `tools/tests/test_video_rules.gd`:

```gdscript
extends SceneTree

## Regras puras dos fundos em video. Roda via run_headless_script (godot --headless --script).

func _init() -> void:
	var failures := 0
	failures += check("passa a 60 fps em 60 Hz", VideoBenchmark.passes(60.0, 60.0))
	failures += check("passa exatamente em 48 fps em 60 Hz", VideoBenchmark.passes(48.0, 60.0))
	failures += check("reprova a 47 fps em 60 Hz", not VideoBenchmark.passes(47.0, 60.0))
	failures += check("monitor desconhecido (-1) assume 60 Hz", not VideoBenchmark.passes(47.0, -1.0))
	failures += check("monitor desconhecido (0) assume 60 Hz", VideoBenchmark.passes(48.0, 0.0))
	failures += check("120 Hz exige 96 fps", not VideoBenchmark.passes(90.0, 120.0))
	failures += check("quality 0 usa still", not SceneBackground.wants_video(0))
	failures += check("quality 1 usa video", SceneBackground.wants_video(1))
	failures += check("quality 2 usa video", SceneBackground.wants_video(2))
	failures += check("cover: 16:9 dentro de 4:3 escala pela altura", is_equal_approx(SceneBackground.cover_scale(Vector2(1440, 1080), Vector2(1280, 720)), 1.5))
	failures += check("cover: 16:9 dentro de 16:9 escala pela largura", is_equal_approx(SceneBackground.cover_scale(Vector2(1920, 1080), Vector2(1280, 720)), 1.5))
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func check(name: String, ok: bool) -> int:
	print(("PASS " if ok else "FAIL ") + name)
	return 0 if ok else 1
```

- [ ] **Step 2: Rodar e ver falhar**

`execute_editor_script`: `EditorInterface.get_resource_filesystem().scan()`

`run_headless_script` com `script_path: "res://tools/tests/test_video_rules.gd"`, `timeout_sec: 60`.

Esperado: erro de parse (`Identifier "VideoBenchmark" not declared` ou similar), exit code ≠ 0.

- [ ] **Step 3: `Settings.benchmarked`**

Em `autoload/settings.gd`, depois de `var quality := 2`:

```gdscript
var benchmarked := false
```

e em `_ready()`, depois da linha do `quality`:

```gdscript
	benchmarked = _config.get_value(SECTION, "benchmarked", benchmarked)
```

- [ ] **Step 4: `VideoBenchmark` só com a regra**

Criar `core/video_benchmark.gd`:

```gdscript
class_name VideoBenchmark
extends Node

## Mede fps tocando um video escondido no primeiro boot; reprovou, quality cai pra 0.

const PASS_RATIO := 0.8
const DEFAULT_REFRESH_RATE := 60.0

static func passes(average_fps: float, refresh_rate: float) -> bool:
	var reference := refresh_rate if refresh_rate > 0.0 else DEFAULT_REFRESH_RATE
	return average_fps >= reference * PASS_RATIO
```

- [ ] **Step 5: `SceneBackground` só com as estáticas**

Criar `backgrounds/background.gd`:

```gdscript
class_name SceneBackground
extends Node2D

## Fundo de tela: still + shader em quality 0, video por cima nos outros niveis.

static func wants_video(quality: int) -> bool:
	return quality >= 1

## Sprite2D e VideoStreamPlayer nao tem ancora: escala que cobre o viewport inteiro.
static func cover_scale(viewport_size: Vector2, texture_size: Vector2) -> float:
	return maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
```

- [ ] **Step 6: Rodar e ver passar**

`execute_editor_script`: `EditorInterface.get_resource_filesystem().scan()` (o editor precisa registrar os `class_name` novos no cache global antes do headless).

`run_headless_script` com `script_path: "res://tools/tests/test_video_rules.gd"`.

Esperado: 11 linhas `PASS`, `FAILURES: 0`, exit code 0. Se vier `not declared` ainda, o cache de classes não atualizou: dar foco na janela do editor, esperar 2 s, repetir.

- [ ] **Step 7: Commit**

```bash
git add autoload/settings.gd core/video_benchmark.gd core/video_benchmark.gd.uid backgrounds/background.gd backgrounds/background.gd.uid tools/tests/test_video_rules.gd tools/tests/test_video_rules.gd.uid
git commit -m "feat: regras do benchmark de video e do modo de fundo, com teste headless"
```

(Os `.uid` são gerados pelo editor no scan. Se algum não existir ainda, tirar do `git add` e incluir no commit da task seguinte.)

---

### Task 3: `SceneBackground` completo (cobrir viewport, modo, fade)

**Files:**
- Modify: `backgrounds/background.gd`

**Interfaces:**
- Consumes: `Settings.quality: int`, `Settings.changed(key: String)`.
- Produces: nó filho opcional `Video: VideoStreamPlayer` (Task 4 cria) e obrigatório `Still: Sprite2D`. Sem `Video`, o script só cobre o viewport com o still (fase 6).

- [ ] **Step 1: Escrever o script completo**

Substituir `backgrounds/background.gd` por:

```gdscript
class_name SceneBackground
extends Node2D

## Fundo de tela: still + shader em quality 0, video por cima nos outros niveis.
## O still segura a imagem ate o video entregar o primeiro frame (trocar antes pisca preto).

const FADE_DURATION := 0.3

@onready var _still: Sprite2D = $Still
@onready var _video: VideoStreamPlayer = get_node_or_null("Video")

var _still_material: Material
var _fade: Tween

static func wants_video(quality: int) -> bool:
	return quality >= 1

## Sprite2D e VideoStreamPlayer nao tem ancora: escala que cobre o viewport inteiro.
static func cover_scale(viewport_size: Vector2, texture_size: Vector2) -> float:
	return maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)

func _ready() -> void:
	_still_material = _still.material
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_process(false)
	if _video == null:
		return
	_video.visible = false
	_video.modulate.a = 0.0
	Settings.changed.connect(_on_settings_changed)
	_apply_mode()

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	var texture_size := _still.texture.get_size()
	var cover := cover_scale(viewport_size, texture_size)
	_still.scale = Vector2.ONE * cover
	_still.position = viewport_size / 2.0
	if _video == null:
		return
	_video.size = texture_size * cover
	_video.position = (viewport_size - _video.size) / 2.0

func _apply_mode() -> void:
	if wants_video(Settings.quality):
		_start_video()
		return
	_stop_video()

func _start_video() -> void:
	_kill_fade()
	if not _video.is_playing():
		_video.play()
	if _video.stream_position <= 0.0:
		set_process(true)
		return
	_show_video()

## Espera o primeiro frame decodificado.
func _process(_delta: float) -> void:
	if _video.stream_position <= 0.0:
		return
	set_process(false)
	_show_video()

func _show_video() -> void:
	_video.visible = true
	_fade = _new_fade()
	_fade.tween_property(_video, "modulate:a", 1.0, FADE_DURATION)
	_fade.tween_callback(func(): _still.material = null)

func _stop_video() -> void:
	_kill_fade()
	set_process(false)
	_still.material = _still_material
	if not _video.visible:
		_video.stop()
		return
	_fade = _new_fade()
	_fade.tween_property(_video, "modulate:a", 0.0, FADE_DURATION)
	_fade.tween_callback(func():
		_video.stop()
		_video.visible = false)

func _new_fade() -> Tween:
	return create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _kill_fade() -> void:
	if _fade == null:
		return
	_fade.kill()
	_fade = null

func _on_settings_changed(key: String) -> void:
	if key != "quality":
		return
	_apply_mode()
```

- [ ] **Step 2: Validar no editor**

`execute_editor_script`: `EditorInterface.get_resource_filesystem().scan()`

`validate_script` com `path: "res://backgrounds/background.gd"`.

Esperado: sem erros. Depois `run_headless_script` em `res://tools/tests/test_video_rules.gd`: `FAILURES: 0` (as estáticas continuam valendo).

- [ ] **Step 3: Commit**

```bash
git add backgrounds/background.gd
git commit -m "feat: SceneBackground alterna still e video por Settings.quality com fade"
```

---

### Task 4: Nó `Video` e script novo nas 9 cenas de fundo existentes

**Files:**
- Modify: `backgrounds/menu_background.tscn`, `worldmap_background.tscn`, `level11_background.tscn`, `level12_background.tscn`, `level13_background.tscn`, `level14_background.tscn`, `level15_background.tscn`, `level17_background.tscn`, `level18_background.tscn`
- Modify: `levels/world1/level_0{1,3,4,5,7,8,9}.tscn` (override de script da instância), `levels/world1/level_06.tscn` (inline)
- Delete: `backgrounds/menu_background.gd`, `backgrounds/menu_background.gd.uid`

**Interfaces:**
- Consumes: `res://assets/video/<chave>.ogv` (Task 1), `res://backgrounds/background.gd` (Task 3).
- Produces: cada cena de fundo com `Still` + `Video` e raiz com `background.gd`.

Mapa cena → vídeo: `menu_background` → `menu.ogv`, `worldmap_background` → `worldmap.ogv`, `levelNN_background` → `levelNN.ogv`.

- [ ] **Step 1: Para CADA uma das 9 cenas, a sequência abaixo (mostrada com `menu`)**

1. `open_scene` `res://backgrounds/menu_background.tscn`
2. `attach_script` `node_path: "."`, `script_path: "res://backgrounds/background.gd"`
3. `add_node` `type: "VideoStreamPlayer"`, `name: "Video"`, `parent_path: "."`, `properties: {"expand": true, "loop": true, "autoplay": false, "volume_db": -80.0, "bus": "Music", "mouse_filter": 2}`
4. `execute_editor_script`:
   ```gdscript
   var root = EditorInterface.get_edited_scene_root()
   root.get_node("Video").stream = load("res://assets/video/menu.ogv")
   _mcp_print(root.get_node("Video").stream.resource_path)
   ```
   Esperado: `res://assets/video/menu.ogv`.
5. `get_scene_tree`: raiz → `Still`, `Video` nessa ordem (Video por último = desenha por cima).
6. `save_scene`

Repetir para `worldmap`, `level11`, `level12`, `level13`, `level14`, `level15`, `level17`, `level18`.

- [ ] **Step 2: Conferir os `.tscn` no disco**

```bash
for f in backgrounds/{menu,worldmap,level11,level12,level13,level14,level15,level17,level18}_background.tscn; do
  echo "$f: script=$(grep -c 'backgrounds/background.gd' $f) video=$(grep -c 'type="VideoStreamTheora"' $f) old=$(grep -c 'menu_background.gd' $f) loop=$(grep -c '^loop = true' $f)"
done
```

Esperado em todas: `script=1 video=1 old=0 loop=1`.

- [ ] **Step 3: Limpar o override de script nas 7 fases que instanciam um fundo**

Para cada `level_01`, `level_03`, `level_04`, `level_05`, `level_07`, `level_08`, `level_09`:

1. `open_scene` `res://levels/world1/level_0N.tscn`
2. `attach_script` `node_path: "Background"`, `script_path: "res://backgrounds/background.gd"` (igual ao script da cena instanciada, então o override some ao salvar)
3. `save_scene`

Fase 6 (`Background` inline, sem instância): mesma sequência, `open_scene` `res://levels/world1/level_06.tscn`, `attach_script` em `Background`, `save_scene`.

- [ ] **Step 4: Apagar o script antigo e conferir que ninguém mais o usa**

```bash
git rm -q backgrounds/menu_background.gd backgrounds/menu_background.gd.uid
grep -rln "menu_background.gd" --include='*.tscn' --include='*.gd' . | grep -v addons
```

Esperado: nenhum arquivo (o `level_10.tscn` ainda usa, e é trocado na Task 5; se aparecer só ele, ok). Se aparecer outro, abrir e repetir o `attach_script` nele.

`execute_editor_script`: `EditorInterface.get_resource_filesystem().scan()`, depois `get_editor_errors`: sem erro de script faltando.

- [ ] **Step 5: Validar o menu em play nos 3 modos**

`play_scene` (main = splash, cai no menu). Esperar ~5 s. Então, para cada modo:

`execute_game_script`:
```gdscript
Settings.set_value("quality", 0)
```
esperar 1 s, `get_game_node_properties` `node_path: "/root/MainMenu/Background/Video"`, `properties: ["visible", "modulate"]`. Esperado: `visible: false`. `get_game_node_properties` `/root/MainMenu/Background/Still` `["material"]`: material presente (ShaderMaterial).

`execute_game_script`: `Settings.set_value("quality", 2)`, esperar 1 s. `capture_frames` `count: 5, frame_interval: 12`: os frames diferem entre si (folhagem mexendo) e não há frame preto. `get_game_node_properties` `Video` `["visible", "stream_position"]`: `visible: true`, `stream_position > 0`. `Still.material`: `null`.

`execute_game_script`: `Settings.set_value("quality", 1)`: mesmo resultado do 2.

Volta para 0 e confirma que o `Still` voltou com material. Depois `execute_game_script`: `Settings.set_value("quality", 2)` (deixar o padrão) e `stop_scene`.

Se o caminho `/root/MainMenu` não existir, `get_game_scene_tree` para achar o nome real da raiz.

- [ ] **Step 6: Commit**

```bash
git add backgrounds levels/world1/level_0{1,3,4,5,6,7,8,9}.tscn
git commit -m "feat: video de fundo nas cenas de fundo, com script compartilhado SceneBackground"
```

---

### Task 5: Fundos próprios das fases 9 e 10

**Files:**
- Create: `backgrounds/level19_background.tscn`, `backgrounds/level110_background.tscn`
- Modify: `levels/world1/level_09.tscn`, `levels/world1/level_10.tscn`

**Interfaces:**
- Consumes: `level19.ogv`, `level110.ogv` (Task 1), `background.gd` (Task 3), `level12_background.tscn` (Task 4, já com `Video`).

- [ ] **Step 1: `level19_background.tscn` a partir da `level12_background`**

1. `open_scene` `res://backgrounds/level12_background.tscn`
2. `save_scene` `path: "res://backgrounds/level19_background.tscn"` (salvar-como; a cena editada passa a ser a nova)
3. `open_scene` `res://backgrounds/level19_background.tscn`
4. `rename_node` `node_path: "."`, `new_name: "Level19Background"`
5. `execute_editor_script`:
   ```gdscript
   var root = EditorInterface.get_edited_scene_root()
   root.get_node("Still").texture = load("res://assets/art/Backgrounds/Level19Background.png")
   root.get_node("Video").stream = load("res://assets/video/level19.ogv")
   _mcp_print(root.name)
   _mcp_print(root.get_node("Still").texture.resource_path)
   _mcp_print(root.get_node("Video").stream.resource_path)
   ```
   Esperado: `Level19Background`, `.../Level19Background.png`, `.../level19.ogv`.
6. `save_scene`
7. Conferir no disco: `grep -c "Level19Background.png\|level19.ogv\|water.gdshader" backgrounds/level19_background.tscn` → `3`. E `level12_background.tscn` continua com `Level12Background.png` (`grep -c Level12Background.png backgrounds/level12_background.tscn` → `1`).

- [ ] **Step 2: Fase 9 instancia o fundo novo**

1. `open_scene` `res://levels/world1/level_09.tscn`
2. `get_scene_tree` `max_depth: 1`: anotar o índice do `Background` entre os filhos da raiz (é o primeiro).
3. `delete_node` `node_path: "Background"`
4. `add_scene_instance` `scene_path: "res://backgrounds/level19_background.tscn"`, `name: "Background"`, `parent_path: "."`
5. `execute_editor_script`:
   ```gdscript
   var root = EditorInterface.get_edited_scene_root()
   root.move_child(root.get_node("Background"), 0)
   _mcp_print(root.get_child(0).name)
   ```
   Esperado: `Background`.
6. Correção de owner antes de salvar (instância corrompe owner dos filhos internos):
   ```gdscript
   var root = EditorInterface.get_edited_scene_root()
   var fixed := 0
   for node in root.find_children("*", "", true, false):
       var instance_root := node
       while instance_root != root and instance_root.scene_file_path == "":
           instance_root = instance_root.get_parent()
       if instance_root != root and node != instance_root and node.owner == root:
           node.owner = instance_root
           fixed += 1
   _mcp_print(fixed)
   ```
7. `save_scene`
8. Conferir: `grep -c "level19_background.tscn" levels/world1/level_09.tscn` → `1`; `grep -c "level12_background\|menu_background.gd" levels/world1/level_09.tscn` → `0`; `grep -c 'name="Still"' levels/world1/level_09.tscn` → `0` (nenhum filho interno duplicado).

- [ ] **Step 3: `level110_background.tscn` do zero**

1. `create_scene` `path: "res://backgrounds/level110_background.tscn"`, `root_name: "Level110Background"`, `root_type: "Node2D"`
2. `open_scene` `res://backgrounds/level110_background.tscn`
3. `attach_script` `node_path: "."`, `script_path: "res://backgrounds/background.gd"`
4. `add_node` `type: "Sprite2D"`, `name: "Still"`, `parent_path: "."`
5. `add_node` `type: "VideoStreamPlayer"`, `name: "Video"`, `parent_path: "."`, `properties: {"expand": true, "loop": true, "autoplay": false, "volume_db": -80.0, "bus": "Music", "mouse_filter": 2}`
6. `execute_editor_script`:
   ```gdscript
   var root = EditorInterface.get_edited_scene_root()
   root.get_node("Still").texture = load("res://assets/art/MiniGames/LostAnimals/level110_video_still.webp")
   root.get_node("Video").stream = load("res://assets/video/level110.ogv")
   _mcp_print(root.get_node("Still").texture.get_size())
   ```
   Esperado: tamanho não nulo.
7. `save_scene`

- [ ] **Step 4: Fase 10 instancia o fundo novo como primeiro filho**

1. `open_scene` `res://levels/world1/level_10.tscn`
2. `delete_node` `node_path: "Background"`
3. `add_scene_instance` `scene_path: "res://backgrounds/level110_background.tscn"`, `name: "Background"`, `parent_path: "."`
4. `execute_editor_script` com o `move_child(..., 0)` e o `_mcp_print(root.get_child(0).name)` do Step 2 → `Background`. E `_mcp_print(root.get_child(1).name)` → `Veil`.
5. Correção de owner (script do Step 2, item 6).
6. `save_scene`
7. Conferir: `grep -c "level110_background.tscn" levels/world1/level_10.tscn` → `1`; `grep -c "menu_background.gd\|level110_video_still" levels/world1/level_10.tscn` → `0`; `grep -c 'name="Still"' levels/world1/level_10.tscn` → `0`.

- [ ] **Step 5: Ninguém mais referencia o script antigo**

```bash
grep -rln "menu_background" --include='*.tscn' --include='*.gd' . | grep -v addons
```

Esperado: vazio. `get_editor_errors`: sem erro.

- [ ] **Step 6: Validar as fases 9 e 10 em play**

`execute_editor_script`: `EditorInterface.play_custom_scene("res://levels/world1/level_09.tscn")`. Esperar 3 s. `capture_frames` `count: 4, frame_interval: 15`: mar em movimento, bolhas e Lali por cima, nada preto. `stop_scene`.

Mesmo para `level_10.tscn`: noite com véu por cima do vídeo, vaga-lume e filhotes visíveis. `get_game_node_properties` do `Background/Video`: `visible: true`. `stop_scene`.

- [ ] **Step 7: Commit**

```bash
git add backgrounds/level19_background.tscn backgrounds/level110_background.tscn levels/world1/level_09.tscn levels/world1/level_10.tscn
git commit -m "feat: fundos em video proprios das fases 9 e 10"
```

---

### Task 6: Benchmark do primeiro boot no splash

**Files:**
- Modify: `core/video_benchmark.gd`
- Modify: `ui/splash/doma_splash.gd`

**Interfaces:**
- Consumes: `Settings.benchmarked`, `Settings.set_value(key, value)`, `res://assets/video/menu.ogv`.
- Produces: `VideoBenchmark` com `signal done`, `var finished: bool`; roda sozinho ao entrar na árvore e se remove ao terminar.

- [ ] **Step 1: Runtime do benchmark**

Substituir `core/video_benchmark.gd` por:

```gdscript
class_name VideoBenchmark
extends Node

## Mede fps tocando um video escondido no primeiro boot; reprovou, quality cai pra 0.
## Roda uma vez e nunca mais: depois disso o ajuste no menu manda.

signal done

const SAMPLE_VIDEO := "res://assets/video/menu.ogv"
const FIRST_FRAME_TIMEOUT := 3.0
const SAMPLE_DURATION := 2.0
const PASS_RATIO := 0.8
const DEFAULT_REFRESH_RATE := 60.0

var finished := false

static func passes(average_fps: float, refresh_rate: float) -> bool:
	var reference := refresh_rate if refresh_rate > 0.0 else DEFAULT_REFRESH_RATE
	return average_fps >= reference * PASS_RATIO

func _ready() -> void:
	var player := _make_player()
	var got_first_frame := await _wait_first_frame(player)
	var passed := false
	if got_first_frame:
		passed = passes(await _measure_fps(), DisplayServer.screen_get_refresh_rate())
	if not passed:
		Settings.set_value("quality", 0)
	Settings.set_value("benchmarked", true)
	finished = true
	done.emit()
	queue_free()

## Toca em tela cheia e transparente: custo de decode e de desenho iguais ao uso real.
func _make_player() -> VideoStreamPlayer:
	var player := VideoStreamPlayer.new()
	player.stream = load(SAMPLE_VIDEO)
	player.volume_db = -80.0
	player.expand = true
	player.size = get_viewport().get_visible_rect().size
	player.modulate.a = 0.0
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player)
	player.play()
	return player

func _wait_first_frame(player: VideoStreamPlayer) -> bool:
	var waited := 0.0
	while player.stream_position <= 0.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > FIRST_FRAME_TIMEOUT:
			return false
	return true

func _measure_fps() -> float:
	var elapsed := 0.0
	var frames := 0
	while elapsed < SAMPLE_DURATION:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		frames += 1
	return frames / elapsed
```

- [ ] **Step 2: Splash dispara e segura**

Substituir `ui/splash/doma_splash.gd` por:

```gdscript
extends Control

@onready var _animation: AnimationPlayer = $Animation

var _benchmark: VideoBenchmark

func _ready() -> void:
	$Hum.play()
	_animation.animation_finished.connect(_on_finished)
	if Settings.benchmarked:
		return
	_benchmark = VideoBenchmark.new()
	add_child(_benchmark)

func _on_finished(_animation_name: StringName) -> void:
	# o menu precisa nascer ja no modo certo
	if is_instance_valid(_benchmark) and not _benchmark.finished:
		await _benchmark.done
	# o fade de 3s comeca aqui, pra ser ouvido junto com o menu aparecendo
	Audio.start_music_fade()
	get_tree().change_scene_to_file("res://ui/menu/main_menu.tscn")

func play_zap() -> void:
	$Zap.play()

func play_thump() -> void:
	$Thump.play()
```

- [ ] **Step 3: Validar scripts e teste headless**

`execute_editor_script`: `EditorInterface.get_resource_filesystem().scan()`. `validate_script` em `res://core/video_benchmark.gd` e `res://ui/splash/doma_splash.gd`: sem erro. `run_headless_script` em `res://tools/tests/test_video_rules.gd`: `FAILURES: 0`.

- [ ] **Step 4: Benchmark aprovando (caminho normal)**

Apagar o config pra simular primeiro boot:

```bash
rm -f "$HOME/Library/Application Support/Godot/app_userdata/Floresta dos Bichinhos Perdidos/settings.cfg"
```

`play_scene`. Esperar 8 s (splash 3,7 s + folga). `execute_game_script`:
```gdscript
_mcp_print("quality=%d benchmarked=%s" % [Settings.quality, Settings.benchmarked])
```
Esperado: `quality=2 benchmarked=true` (o Mac passa). `stop_scene`.

```bash
grep -E "quality|benchmarked" "$HOME/Library/Application Support/Godot/app_userdata/Floresta dos Bichinhos Perdidos/settings.cfg"
```
Esperado: `benchmarked=true` presente; `quality` ausente ou 2.

- [ ] **Step 5: Benchmark reprovando (forçado)**

Temporariamente, em `core/video_benchmark.gd`, `const PASS_RATIO := 0.8` → `const PASS_RATIO := 100.0`. `scan()`. Apagar o `settings.cfg` de novo (comando do Step 4). `play_scene`, esperar 8 s, mesmo `execute_game_script`.

Esperado: `quality=0 benchmarked=true`. `get_game_node_properties` `/root/MainMenu/Background/Video` `["visible"]` → `false` (menu nasceu no still). `stop_scene`. Conferir no `settings.cfg`: `quality=0`.

Restaurar `PASS_RATIO := 0.8`, `scan()`, e conferir com `git diff core/video_benchmark.gd` que o valor voltou. Apagar o `settings.cfg` mais uma vez e rodar o Step 4 de novo pra deixar o aparelho de desenvolvimento em `quality=2`.

- [ ] **Step 6: Segundo boot não repete**

Com `benchmarked=true` no arquivo, `play_scene`, esperar 1 s, `execute_game_script`:
```gdscript
_mcp_print(get_tree().root.find_child("VideoBenchmark", true, false) == null)
_mcp_print(get_tree().current_scene.get_children().filter(func(child): return child is VideoBenchmark).size())
```
Esperado: `true` e `0`. `stop_scene`.

- [ ] **Step 7: Commit**

```bash
git add core/video_benchmark.gd ui/splash/doma_splash.gd
git commit -m "feat: benchmark de video no primeiro boot poe a qualidade no minimo se reprovar"
```

---

### Task 7: Varredura final, 4:3, troca ao vivo pelo painel, docs

**Files:**
- Modify: `CLAUDE.md` (seção "Arquitetura alvo", parágrafo "Fundos não usam vídeo")

- [ ] **Step 1: Todas as fases em `quality = 2`, 16:9**

Para cada `level_01` … `level_10`: `execute_editor_script` `EditorInterface.play_custom_scene("res://levels/world1/level_0N.tscn")`, esperar 3 s, `get_game_screenshot`, `get_game_node_properties` `Background/Video` `["visible", "stream_position"]` (fase 6: o nó não existe, é o esperado), `stop_scene`.

Esperado: vídeo cobrindo a tela, personagens e UI por cima, nada preto. Registrar qualquer fase em que o vídeo apareça cortado ou deslocado.

- [ ] **Step 2: 4:3**

`execute_editor_script`:
```gdscript
EditorInterface.play_custom_scene("res://levels/world1/level_02.tscn")
```
Depois, no jogo: `execute_game_script`:
```gdscript
DisplayServer.window_set_size(Vector2i(1440, 1080))
```
Esperar 1 s, `get_game_screenshot`: vídeo cobre a janela inteira (sem barra), sem esticar. `get_game_node_properties` `Background/Video` `["size", "position"]`: `size.y == 1080` e `position.x < 0` (sobra cortada nas laterais). `stop_scene`. Repetir para `main_menu.tscn`.

- [ ] **Step 3: Troca ao vivo pelo painel de ajustes**

`play_scene`, esperar 6 s (menu). `execute_game_script`:
```gdscript
var panel = get_tree().current_scene.find_child("QualityOption", true, false)
panel.select(0)
panel.item_selected.emit(0)
```
`capture_frames` `count: 6, frame_interval: 6`: vídeo some em fade de ~0,3 s, still com shader fica. Depois `select(2)` + `item_selected.emit(2)`: vídeo volta com fade. Sem frame preto em nenhum frame. `stop_scene`.

- [ ] **Step 4: Sem erro no editor**

`get_editor_errors`: nenhum erro novo. `get_output_log` `filter: "Video"`: nenhum `ERROR`.

- [ ] **Step 5: Atualizar o `CLAUDE.md`**

Em "Arquitetura alvo", trocar o parágrafo que começa com **"Fundos não usam vídeo."** por:

```markdown
**Fundos são vídeo com fallback.** Cada cena de `backgrounds/` tem `Still` (frame 0 + shader
`water`/`foliage`) e `Video` (`VideoStreamPlayer`, Ogg Theora em `assets/video/`). O script
`background.gd` toca vídeo em `Settings.quality >= 1` e fica no still + shader em `quality == 0`.
No primeiro boot, `core/video_benchmark.gd` mede o fps tocando o vídeo do menu durante o splash e
grava `quality = 0` se ficar abaixo de 80% da taxa do monitor (nunca repete; apagar
`user://settings.cfg` reinicia). Encoder: `ffmpeg2theora` (o ffmpeg do Homebrew não encoda Theora).
Fase 6 não tem vídeo (só still). Spec: `docs/superpowers/specs/2026-09-06-fundos-em-video-design.md`.
```

Na tabela "Riscos vivos", remover a linha "Fundo por shader não fica tão bonito quanto o vídeo" e acrescentar:

```markdown
| Theora em CPU engasga no tablet | Benchmark do primeiro boot cai pra still + shader. Medir no tablet do testador antes do M4 |
```

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: fundos em video com fallback documentados no CLAUDE.md"
```

---

## Verificação final contra o spec

| Requisito do spec | Task |
|---|---|
| Vídeo em `quality` 1 e 2, still + shader em 0 | 3, 4 |
| Troca em runtime com fade, still segura até o primeiro frame | 3, 7 (Step 3) |
| 11 vídeos Theora ≤ 35 MB, sem áudio, ≤ 1280 | 1 |
| `Settings.benchmarked` | 2 |
| Benchmark no splash: primeiro frame com timeout, 2 s de medição, 80% da taxa, `-1` vira 60 | 2, 6 |
| Splash segura a troca de cena até o benchmark terminar | 6 |
| Fase 9 com fundo próprio | 5 |
| Fase 10 com fundo próprio, véus por cima | 5 |
| Fase 6 só still, script compartilhado | 4 (Step 3) |
| Override redundante de script nas 7 fases limpo | 4 (Step 3) |
| 4:3 coberto | 7 |
| Sem gameplay pendurado no fundo, post pega tudo | inalterado (fundo continua nó irmão, `Post` é autoload `CanvasLayer`) |
