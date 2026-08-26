# Menu principal em Godot — plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA: use
> `superpowers:subagent-driven-development` (recomendado) ou
> `superpowers:executing-plans` para executar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para acompanhamento.

**Objetivo:** entregar o menu principal do jogo em Godot com paridade funcional
com a versão Flutter — cinco botões, cinco painéis, música, efeitos, partículas,
animações e pós-processamento — junto com as fundações que todas as telas
seguintes vão reusar.

**Arquitetura:** três autoloads (`Settings`, `Audio`, `Post`) sustentam qualquer
tela; o menu é uma cena `Control` com âncoras nativas; cada painel é uma cena
`Control` independente instanciada sob um `CanvasLayer` de overlays e removida ao
fechar. Animação e partícula saem de nós nativos (`AnimationPlayer`,
`GPUParticles2D`); script custom só onde não há equivalente.

**Stack:** Godot 4.7.2-stable, GDScript, renderer Mobile, Godot MCP Pro para
dirigir o editor.

**Spec:** `docs/superpowers/specs/2026-08-26-menu-principal-godot-design.md`

## Restrições globais

- Godot **4.7.2-stable**, GDScript. Renderer Mobile. Resolução base 1920×1080,
  stretch `canvas_items`, aspect `expand`, landscape travado.
- **Tudo pelos tools do Godot MCP Pro**, nunca pelo `cli.js` e nunca escrevendo
  `.tscn`/`.godot` na mão. Chamada que voltar `-32001` é só repetir — é o token
  de conexão funcionando, não erro.
- **Nunca editar `project.godot` direto** com o editor aberto; usar
  `set_project_setting`.
- **Preferir inspector a código**: valor que existe como propriedade vai por
  `update_property`, não por script. GDScript só quando a propriedade não existe
  ou precisa ser dinâmica em runtime.
- Código em inglês, comentários em pt-BR e escassos. Menos código possível,
  nativo primeiro, sem abstração inventada.
- Sem `if/else` onde `return` cedo resolve. Nomes de variável descritivos.
- **Toda tela nova renderiza dentro do `Post`** (autoload) — nada fora.
- Commits sem coautor, sem `Co-Authored-By`, sem "Generated with". Direto na
  `main`, como os commits anteriores deste repositório.
- Paleta fixa: `brown #6B401C`, `soft_brown #8C6640`, `cream #FFF5DE`,
  `leaf_green #61A84A`, `bar_brown #B88C61`, `sun_yellow #FFD973`,
  `pressed_tint #C7C7C7`.

## Como "testar" neste projeto

Não há framework de teste instalado e não vamos instalar um. Cada tarefa fecha
com uma verificação executável:

- **Lógica pura** (Settings, Audio, i18n): script GDScript em `res://tools/` que
  imprime `OK` ou `FALHOU` com o valor obtido, rodado em headless. Esses passos
  seguem TDD de verdade: rodar **antes** da implementação e ver falhar.
  - Script que **não** toca autoload pode ser `extends SceneTree`, rodado com
    `--script`.
  - Script que toca autoload (`Settings`, `Audio`, `Post`) tem que ser uma
    **cena** — `extends Node` com `_ready` e `get_tree().quit()` no fim, rodada
    com `godot --headless --path . res://tools/<nome>.tscn`. Medido em
    26/08/2026: com `--script` o Godot não instancia autoload nenhum
    (`root.get_children()` volta vazio) e o compilador nem reconhece o
    identificador `Settings`.
  - Rodar pelo terminal, não pelo tool `run_headless_script`: o tool estourava o
    timeout do próprio comando enquanto o mesmo binário, com os mesmos
    argumentos, respondia em menos de um segundo.
  - Os scripts de verificação vivem em `res://tools/` (não no scratchpad) porque
    o Godot só executa caminhos `res://`. A Task 12 apaga a pasta.
- **Cena visual**: `save_scene` → `get_editor_screenshot` (montagem) e
  `play_scene` → `get_game_screenshot` (execução), com um critério de aceitação
  escrito no passo — o que precisa aparecer, onde. Screenshot sem critério não
  conta como verificação.
- **Interação**: `simulate_mouse_click` nas coordenadas do botão seguido de
  `get_game_screenshot` e/ou `assert_node_state`.

Antes de cada tarefa: `get_project_info` para confirmar que o MCP está falando
com **este** projeto.

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `autoload/settings.gd` | Ler/gravar `user://settings.cfg`, publicar `changed` |
| `autoload/audio.tscn` + `audio.gd` | Música persistente e SFX de UI; volumes nos buses |
| `autoload/post.tscn` + `post.gd` | CanvasLayer de pós-processamento, taps por qualidade |
| `shaders/post.gdshader` | Bloom + vinheta + color grading num passe |
| `shaders/foliage.gdshader` | Distorção senoidal com máscara de altura |
| `core/juicy_button.tscn` + `.gd` | Botão com hover/press e brilho no clique |
| `core/sparkle_burst.tscn` + `.gd` | Explosão de brilhos parametrizada, autodestrutiva |
| `core/menu_panel.gd` | Base dos painéis: pop-in, botão voltar, sinal `closed` |
| `backgrounds/menu_background.tscn` + `.gd` | Still com cover + shader de folhagem |
| `ui/theme.tres` | Fonte, paleta, estilos de slider/dropdown |
| `ui/menu/main_menu.tscn` + `.gd` | A tela do menu e a abertura dos painéis |
| `ui/menu/panels/*.tscn` | Os cinco painéis |
| `ui/world_map/world_map.tscn` + `.gd` | Stub do mapa (fundo, título, voltar) |
| `ui/splash/doma_splash.tscn` + `.gd` | Splash da produtora, cena principal |
| `assets/i18n/ui.csv` | Tabela pt-BR/it completa |

---

### Task 1: Autoload `Settings`, buses e autoload `Audio`

**Arquivos:**
- Criar: `autoload/settings.gd`
- Criar: `autoload/audio.gd`, `autoload/audio.tscn`
- Criar: `default_bus_layout.tres` (via editor)
- Modificar: `project.godot` (autoloads, por `add_autoload`)
- Verificação: `scratchpad/check_settings.gd`, `scratchpad/check_audio.gd`

**Interfaces:**
- Produz: `Settings.music_volume: float`, `Settings.sfx_volume: float`,
  `Settings.quality: int`, `Settings.locale: String`,
  `Settings.set_value(key: String, value: Variant) -> void`,
  sinal `Settings.changed(key: String)`.
- Produz: `Audio.play_click() -> void`, `Audio.play_locked() -> void`,
  `Audio.start_music_fade() -> void`, `Audio.apply_volumes() -> void`.

- [x] **Passo 1: escrever o script de verificação que falha**

Salvar em `scratchpad/check_settings.gd` (fora do projeto Godot, executado por
`run_headless_script`):

```gdscript
extends SceneTree

func _init() -> void:
    var settings := load("res://autoload/settings.gd").new()
    settings._ready()
    var defaults_ok := settings.music_volume == 1.0 and settings.sfx_volume == 1.0 \
        and settings.quality == 2 and settings.locale == "pt_BR"
    print("padroes: ", "OK" if defaults_ok else "FALHOU")

    var received := []
    settings.changed.connect(func(key): received.append(key))
    settings.set_value("quality", 0)
    settings.set_value("music_volume", 0.4)
    print("sinal: ", "OK" if received == ["quality", "music_volume"] else "FALHOU %s" % [received])

    var reloaded := load("res://autoload/settings.gd").new()
    reloaded._ready()
    var persisted_ok := reloaded.quality == 0 and is_equal_approx(reloaded.music_volume, 0.4)
    print("persistencia: ", "OK" if persisted_ok else "FALHOU q=%s m=%s" % [reloaded.quality, reloaded.music_volume])

    # o teste não pode deixar o jogo em qualidade baixa
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
    quit()
```

- [x] **Passo 2: rodar e ver falhar**

MCP: `run_headless_script` com o arquivo acima.
Esperado: erro de carregamento — `res://autoload/settings.gd` não existe.

- [x] **Passo 3: criar `autoload/settings.gd`**

MCP: `create_script` em `res://autoload/settings.gd`:

```gdscript
extends Node

## Volumes, qualidade gráfica e idioma, gravados em user://settings.cfg.

signal changed(key: String)

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "settings"

var music_volume := 1.0
var sfx_volume := 1.0
var quality := 2
var locale := "pt_BR"

var _config := ConfigFile.new()

func _ready() -> void:
    _config.load(CONFIG_PATH)
    music_volume = _config.get_value(SECTION, "music_volume", music_volume)
    sfx_volume = _config.get_value(SECTION, "sfx_volume", sfx_volume)
    quality = _config.get_value(SECTION, "quality", quality)
    locale = _config.get_value(SECTION, "locale", locale)
    TranslationServer.set_locale(locale)

func set_value(key: String, value: Variant) -> void:
    set(key, value)
    _config.set_value(SECTION, key, value)
    _config.save(CONFIG_PATH)
    if key == "locale":
        TranslationServer.set_locale(value)
    changed.emit(key)
```

- [x] **Passo 4: rodar e ver passar**

MCP: `run_headless_script` com `check_settings.gd`.
Esperado: `padroes: OK`, `sinal: OK`, `persistencia: OK`.

- [x] **Passo 5: criar os buses de áudio**

MCP: `add_audio_bus` três vezes — `Music`, `SFX`, `Voice`, todos com
`send = "Master"`. Depois `get_audio_bus_layout` para confirmar que o layout tem
os quatro buses e foi salvo em `res://default_bus_layout.tres`.
Esperado: layout com `Master, Music, SFX, Voice`.

- [x] **Passo 6: escrever o script de verificação do Audio (falha)**

`scratchpad/check_audio.gd`:

```gdscript
extends SceneTree

func _init() -> void:
    var buses := []
    for i in AudioServer.bus_count:
        buses.append(AudioServer.get_bus_name(i))
    print("buses: ", "OK" if buses == ["Master", "Music", "SFX", "Voice"] else "FALHOU %s" % [buses])

    var audio := load("res://autoload/audio.tscn").instantiate()
    root.add_child(audio)
    audio.set_music_fade(0.0)
    var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
    print("mudo em zero: ", "OK" if muted else "FALHOU")

    audio.set_music_fade(1.0)
    # volume cheio = Settings.music_volume (1.0) * MUSIC_BASE_VOLUME (0.25) = -12.04 dB
    var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
    print("volume cheio: ", "OK" if is_equal_approx(db, linear_to_db(0.25)) else "FALHOU %s" % db)

    audio.play_click()
    var first := audio._last_click_ms
    audio.play_click()
    print("guarda de clique: ", "OK" if audio._last_click_ms == first else "FALHOU")
    quit()
```

- [x] **Passo 7: rodar e ver falhar**

MCP: `run_headless_script`.
Esperado: `buses: OK` e falha ao carregar `audio.tscn`.

- [x] **Passo 8: criar `autoload/audio.gd`**

MCP: `create_script` em `res://autoload/audio.gd`:

```gdscript
extends Node

## Música persistente e sons de UI. Volume mora no bus, não no player.

const MUSIC_BASE_VOLUME := 0.25
const FADE_SECONDS := 3.0
const CLICK_GAP_MS := 60

@onready var _music: AudioStreamPlayer = $Music
@onready var _click: AudioStreamPlayer = $Click
@onready var _locked: AudioStreamPlayer = $Locked

var _fade := 0.0
var _fade_tween: Tween
var _last_click_ms := -CLICK_GAP_MS

func _ready() -> void:
    Settings.changed.connect(_on_settings_changed)
    apply_volumes()
    _music.play()

func apply_volumes() -> void:
    _set_bus_linear("Music", Settings.music_volume * MUSIC_BASE_VOLUME * _fade)
    _set_bus_linear("SFX", Settings.sfx_volume)
    _set_bus_linear("Voice", Settings.sfx_volume)

## Sobe a música do silêncio ao volume ajustado em 3s. Chamar de novo não
## reinicia o fade nem empilha tween.
func start_music_fade() -> void:
    if _fade_tween and _fade_tween.is_running():
        return
    _fade_tween = create_tween()
    _fade_tween.tween_method(set_music_fade, 0.0, 1.0, FADE_SECONDS)

func set_music_fade(value: float) -> void:
    _fade = value
    apply_volumes()

func play_click() -> void:
    # dois cliques mais juntos que isso são o mesmo toque chegando por dois caminhos
    var now := Time.get_ticks_msec()
    if now - _last_click_ms < CLICK_GAP_MS:
        return
    _last_click_ms = now
    _click.play()

func play_locked() -> void:
    _locked.play()

func _on_settings_changed(key: String) -> void:
    if key not in ["music_volume", "sfx_volume"]:
        return
    apply_volumes()

func _set_bus_linear(bus_name: String, linear: float) -> void:
    var bus := AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_mute(bus, linear <= 0.001)
    AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.001)))
```

- [x] **Passo 9: montar `autoload/audio.tscn`**

MCP: `create_scene` `res://autoload/audio.tscn` com raiz `Node` chamada `Audio`,
`attach_script` com `audio.gd`, depois `batch_add_nodes` com três
`AudioStreamPlayer`: `Music`, `Click`, `Locked`.

`update_property` em cada um (valores no inspector, não no script):

| Nó | Propriedade | Valor |
|---|---|---|
| Music | `stream` | `res://assets/audio/Music/menu_music.mp3` |
| Music | `bus` | `Music` |
| Click | `stream` | `res://assets/audio/UI/ui_click.wav` |
| Click | `bus` | `SFX` |
| Locked | `stream` | `res://assets/audio/UI/ui_locked.wav` |
| Locked | `bus` | `SFX` |
| Locked | `volume_db` | `-0.9` |

No `Music`, marcar o loop no recurso importado do mp3 (`loop = true` no
`.import`, reimportando pelo editor). `save_scene`.

- [x] **Passo 10: registrar os autoloads**

MCP: `add_autoload` `Settings` → `res://autoload/settings.gd`; `Audio` →
`res://autoload/audio.tscn`. `Settings` precisa vir **antes** de `Audio` na
ordem (o `_ready` do Audio lê `Settings`).
Conferir com `get_autoload`.

- [x] **Passo 11: rodar a verificação do Audio**

MCP: `run_headless_script` com `check_audio.gd`.
Esperado: `buses: OK`, `mudo em zero: OK`, `volume cheio: OK`,
`guarda de clique: OK`.

O passo 6 esperava `volume cheio` em −12,04 dB, não em 0 — o volume base da
música é 0,25 linear, como no Flutter.

- [x] **Passo 12: commit**

```bash
git add autoload project.godot default_bus_layout.tres
git commit -m "feat: autoloads de ajustes e audio com buses Music/SFX/Voice"
```

---

### Task 2: i18n e tema

**Arquivos:**
- Criar: `assets/i18n/ui.csv` (+ `.translation` gerados na importação)
- Criar: `ui/theme.tres`
- Modificar: `project.godot` (lista de traduções, por `set_project_setting`)
- Verificação: `scratchpad/check_i18n.gd`

**Interfaces:**
- Consome: `Settings.locale`, `Settings.set_value`.
- Produz: chaves de tradução `worldselect.title`, `quitmodal.*`, `settings.*`,
  `credits.*`, `worldmap.world1.*` e as de fases; `ui/theme.tres` com as
  variações de tipo `Title80`, `ModalQuestion66`, `ModalButton54`,
  `SettingLabel44`, `Name36`, `Instruction28`, `Bio26`, `Chip18`.

- [ ] **Passo 1: escrever o script de verificação (falha)**

`scratchpad/check_i18n.gd`:

```gdscript
extends SceneTree

func _init() -> void:
    TranslationServer.set_locale("pt_BR")
    print("pt: ", "OK" if tr("worldselect.title") == "Escolha o mundo" else "FALHOU %s" % tr("worldselect.title"))
    TranslationServer.set_locale("it")
    print("it: ", "OK" if tr("worldselect.title") == "Scegli il mondo" else "FALHOU %s" % tr("worldselect.title"))
    print("sem chave crua: ", "OK" if tr("quitmodal.yes") != "quitmodal.yes" else "FALHOU")
    quit()
```

- [ ] **Passo 2: rodar e ver falhar**

MCP: `run_headless_script`.
Esperado: as três linhas com `FALHOU` (a chave volta crua).

- [ ] **Passo 3: escrever o CSV**

Criar `assets/i18n/ui.csv` com cabeçalho `keys,pt_BR,it` e **todas** as entradas
de `../floresta-dos-bichinhos-old/lib/strings.dart` (~60 chaves), portadas
literalmente. Campos com vírgula vão entre aspas duplas.

Além delas, acrescentar as dos créditos, que no Flutter estavam fixas no código:

```csv
credits.person.lucas.name,Lucas Dóro,Lucas Dóro
credits.person.lucas.bio,"Idealizou e desenvolveu a Floresta dos Bichinhos Perdidos, cuidando de cada detalhe da floresta.","Ha ideato e sviluppato la Foresta degli Animaletti Perduti, curando ogni dettaglio della foresta."
credits.person.joao.name,João Henrique Maricato,João Henrique Maricato
credits.person.joao.bio,"Imagina novas aventuras para os bichinhos: traz ideias de fases e ajuda a deixar as que existem ainda mais divertidas.","Immagina nuove avventure per gli animaletti: propone idee per i livelli e aiuta a rendere ancora più divertenti quelli esistenti."
credits.site,Site do jogo,Sito del gioco
```

- [ ] **Passo 4: importar e registrar**

Reimportar pelo editor (o Godot gera `ui.pt_BR.translation` e `ui.it.translation`).
MCP: `set_project_setting` em `internationalization/locale/translations` com o
array dos dois `.translation`.

- [ ] **Passo 5: rodar e ver passar**

MCP: `run_headless_script` com `check_i18n.gd`.
Esperado: `pt: OK`, `it: OK`, `sem chave crua: OK`.

- [ ] **Passo 6: criar o tema**

MCP: `create_theme` em `res://ui/theme.tres`, fonte padrão
`res://assets/fonts/Baloo2-ExtraBold.ttf`. Depois, por
`set_theme_color` / `set_theme_font_size` / `set_theme_stylebox`:

- Variações de tipo com os tamanhos: `Title80` 80, `ModalQuestion66` 66,
  `ModalButton54` 54, `SettingLabel44` 44, `Name36` 36, `Instruction28` 28,
  `Bio26` 26, `Chip18` 18.
- `Label/colors/font_color` = `#6B401C`.
- `HSlider`: `grabber` amarelo `#FFD973`, trilha cheia `#61A84A`, vazia
  `#B88C61`, altura 22, raio do grabber 28.
- `OptionButton`: `normal`/`hover`/`pressed` em `StyleBoxFlat` creme `#FFF5DE`,
  borda `#B88C61` com alpha 0.6 e 2 px, raio 10; `font_color` `#6B401C`.

- [ ] **Passo 7: conferir o tema**

Criar uma cena temporária com um `Label` (`theme_type_variation = Title80`), um
`HSlider` e um `OptionButton`, aplicar o tema na raiz, `save_scene` e
`get_editor_screenshot`.
Aceitação: texto marrom em Baloo2 grande, slider com trilha verde e botão
amarelo, dropdown creme com borda marrom. Apagar a cena temporária depois
(`delete_scene`).

- [ ] **Passo 8: commit**

```bash
git add assets/i18n ui/theme.tres project.godot
git commit -m "feat: tabela de traducao pt-BR/it e tema base da UI"
```

---

### Task 3: Pós-processamento global

**Arquivos:**
- Criar: `shaders/post.gdshader`
- Criar: `autoload/post.gd`, `autoload/post.tscn`
- Modificar: `project.godot` (autoload `Post`)

**Interfaces:**
- Consome: `Settings.quality`, `Settings.changed`.
- Produz: `Post.set_quality(level: int) -> void` (0/1/2 → 0/10/16 taps).

- [ ] **Passo 1: escrever o shader**

MCP: `create_shader` em `res://shaders/post.gdshader`:

```glsl
shader_type canvas_item;

// Ordem do UberPost da URP: bloom -> vinheta -> color grading.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float taps : hint_range(0.0, 16.0) = 16.0;
uniform float bloom_intensity = 0.35;
uniform float bloom_threshold = 0.90;
uniform float bloom_knee = 0.50;
uniform float bloom_radius = 0.035;
uniform float vignette_intensity = 0.16;
uniform float vignette_smoothness = 0.40;
uniform float post_exposure_ev = 0.05;
uniform float contrast_amount = 0.06;
uniform float saturation_amount = 0.10;

const float GOLDEN_ANGLE = 2.39996323;

vec3 prefilter(vec3 color) {
    float brightest = max(color.r, max(color.g, color.b));
    float knee = bloom_threshold * bloom_knee;
    float soft = clamp(brightest - bloom_threshold + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee + 1e-4);
    float contribution = max(soft, brightest - bloom_threshold) / max(brightest, 1e-4);
    return color * contribution;
}

void fragment() {
    vec3 color = texture(screen_texture, SCREEN_UV).rgb;

    int tap_count = int(taps);
    if (tap_count > 0) {
        // disco de Vogel: uma amostra por tap, sem cadeia de mips
        vec3 bloom = vec3(0.0);
        float aspect = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
        for (int i = 0; i < tap_count; i++) {
            float t = (float(i) + 0.5) / taps;
            float radius = sqrt(t) * bloom_radius;
            float angle = float(i) * GOLDEN_ANGLE;
            vec2 offset = vec2(cos(angle) * aspect, sin(angle)) * radius;
            bloom += prefilter(texture(screen_texture, SCREEN_UV + offset).rgb);
        }
        color += bloom / taps * bloom_intensity;
    }

    vec2 distance_from_center = abs(SCREEN_UV - vec2(0.5)) * vignette_intensity * 3.0;
    float vignette = pow(clamp(1.0 - dot(distance_from_center, distance_from_center), 0.0, 1.0),
        vignette_smoothness * 5.0);
    color *= vignette;

    color *= exp2(post_exposure_ev);
    color = (color - vec3(0.5)) * (1.0 + contrast_amount) + vec3(0.5);
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luminance), color, 1.0 + saturation_amount);

    COLOR = vec4(color, 1.0);
}
```

- [ ] **Passo 2: montar `autoload/post.tscn`**

MCP: `create_scene` `res://autoload/post.tscn`, raiz `CanvasLayer` chamada
`Post`. `update_property`: `layer = 100`. Filho `ColorRect` chamado `Screen`.

No `Screen`, por `update_property`:

| Propriedade | Valor |
|---|---|
| `anchors_preset` | full rect (`set_anchor_preset` 15, com margens 0) |
| `mouse_filter` | `2` (IGNORE — senão o retângulo engole todo clique do jogo) |
| `color` | `Color(1, 1, 1, 1)` |

MCP: `assign_shader_material` com `res://shaders/post.gdshader` no `Screen`.
`attach_script` com `post.gd` na raiz. `save_scene`.

- [ ] **Passo 3: escrever `autoload/post.gd`**

```gdscript
extends CanvasLayer

## Bloom + vinheta + grading por cima de todas as telas.

const TAPS_BY_QUALITY := [0.0, 10.0, 16.0]

@onready var _material: ShaderMaterial = $Screen.material

func _ready() -> void:
    Settings.changed.connect(_on_settings_changed)
    set_quality(Settings.quality)

func set_quality(level: int) -> void:
    _material.set_shader_parameter("taps", TAPS_BY_QUALITY[clampi(level, 0, 2)])

func _on_settings_changed(key: String) -> void:
    if key != "quality":
        return
    set_quality(Settings.quality)
```

- [ ] **Passo 4: registrar o autoload**

MCP: `add_autoload` `Post` → `res://autoload/post.tscn`, depois de `Settings` e
`Audio`. Conferir com `get_autoload`.

- [ ] **Passo 5: verificar visualmente nos três níveis**

Criar cena temporária `scratchpad_post.tscn` com um `ColorRect` preto ocupando a
tela e três `ColorRect` brancos pequenos (fontes de luz). `play_scene`,
`get_game_screenshot`.

Depois, por `execute_game_script`: `Post.set_quality(0)` → screenshot;
`Post.set_quality(1)` → screenshot; `Post.set_quality(2)` → screenshot.

Aceitação: em 0 os quadrados brancos têm borda dura; em 1 e 2 têm halo, mais
largo em 2; nos três os cantos estão visivelmente mais escuros que o centro
(vinheta). `stop_scene` e `delete_scene` da cena temporária.

- [ ] **Passo 6: verificar que o clique atravessa**

Ainda na cena temporária, antes de apagá-la: adicionar um `Button` central,
`play_scene`, `simulate_mouse_click` no centro, `get_output_log`.
Aceitação: o botão registra o clique — o `ColorRect` do Post não bloqueia input.

- [ ] **Passo 7: commit**

```bash
git add shaders/post.gdshader autoload/post.gd autoload/post.tscn project.godot
git commit -m "feat: pos-processamento global com bloom, vinheta e grading"
```

---

### Task 4: Fundo do menu

**Arquivos:**
- Criar: `shaders/foliage.gdshader`
- Criar: `backgrounds/menu_background.tscn`, `backgrounds/menu_background.gd`

**Interfaces:**
- Produz: cena `menu_background.tscn` (raiz `Node2D` chamada `MenuBackground`)
  que se escala sozinha para cobrir o viewport.

- [ ] **Passo 1: escrever o shader de folhagem**

MCP: `create_shader` em `res://shaders/foliage.gdshader`:

```glsl
shader_type canvas_item;

// Folhagem de cima balança; o chão fica parado.
uniform float amplitude : hint_range(0.0, 0.02) = 0.004;
uniform float speed : hint_range(0.0, 3.0) = 0.6;
uniform float wave_density : hint_range(1.0, 20.0) = 8.0;
uniform float mask_bottom : hint_range(0.0, 1.0) = 0.55;

void fragment() {
    float mask = 1.0 - smoothstep(0.0, mask_bottom, UV.y);
    float wave = sin(TIME * speed + UV.y * wave_density) * amplitude * mask;
    COLOR = texture(TEXTURE, UV + vec2(wave, 0.0));
}
```

- [ ] **Passo 2: montar a cena**

MCP: `create_scene` `res://backgrounds/menu_background.tscn`, raiz `Node2D`
chamada `MenuBackground`, filho `Sprite2D` chamado `Still`.

`update_property` no `Still`: `texture` =
`res://assets/art/Backgrounds/MenuBackground.png`, `centered = true`.
`assign_shader_material` com `foliage.gdshader`. `save_scene`.

- [ ] **Passo 3: escrever o script de cover**

MCP: `create_script` `res://backgrounds/menu_background.gd`, anexado à raiz:

```gdscript
extends Node2D

## Sprite2D não tem âncora: cobre o viewport na mão e recentraliza no resize.

@onready var _still: Sprite2D = $Still

func _ready() -> void:
    get_viewport().size_changed.connect(_fit)
    _fit()

func _fit() -> void:
    var viewport_size := get_viewport_rect().size
    var texture_size := _still.texture.get_size()
    var cover := maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
    _still.scale = Vector2.ONE * cover
    _still.position = viewport_size / 2.0
```

- [ ] **Passo 4: verificar em execução**

`play_scene` com `menu_background.tscn`, `get_game_screenshot`.
Aceitação: a arte cobre a tela inteira sem barra preta e sem distorção de
proporção; a copa das árvores oscila devagar; o chão não oscila.
Repetir com o viewport em 1440×1080 (`set_project_setting` temporário ou
redimensionando a janela do jogo) e conferir que continua coberto.

- [ ] **Passo 5: ajustar o balanço no inspector**

Se o movimento estiver forte ou rápido demais, ajustar `amplitude`, `speed` e
`mask_bottom` pelo inspector do material — não no shader.
Aceitação escrita: o movimento tem que ser perceptível olhando 3 s, e invisível
olhando de relance.

- [ ] **Passo 6: commit**

```bash
git add shaders/foliage.gdshader backgrounds
git commit -m "feat: fundo do menu com still e shader de folhagem"
```

---

### Task 5: Botão juicy e explosão de brilhos

**Arquivos:**
- Criar: `core/sparkle_burst.tscn`, `core/sparkle_burst.gd`
- Criar: `core/juicy_button.tscn`, `core/juicy_button.gd`

**Interfaces:**
- Produz: `class_name SparkleBurst`, com
  `burst(at: Vector2, color: Color, count: int, max_size: float) -> void`.
- Produz: `class_name JuicyButton extends TextureButton`, com os `@export`
  `burst_color: Color`, `burst_count: int`, `burst_max_size: float`,
  `hover_scale: float` (padrão 1.07) e `pressed_scale: float` (padrão 0.92). O
  botão se conecta ao próprio `pressed` no `_ready`, então som e brilho saem
  antes de qualquer handler ligado depois por outra cena.
- Contrato: quem usa `JuicyButton` precisa ter, na mesma árvore, um nó no grupo
  `effects` (é onde o brilho é pendurado, pra não herdar a escala do botão).

- [ ] **Passo 1: montar `core/sparkle_burst.tscn`**

MCP: `create_scene`, raiz `GPUParticles2D` chamada `SparkleBurst`.
`create_particles` / `update_property` com:

| Propriedade | Valor |
|---|---|
| `texture` | `res://assets/art/UI/Buttons/sparkle_star.webp` |
| `amount` | 30 |
| `lifetime` | 0.7 |
| `one_shot` | true |
| `explosiveness` | 1.0 |
| `emitting` | false |

No `ParticleProcessMaterial` (via `set_particle_material`):
`emission_shape = Point`, `direction = (0,0)`, `spread = 180`,
`initial_velocity_min = 143`, `initial_velocity_max = 314`
(distância 100–220 px em 0,7 s), `damping_min/max = 200`,
`angular_velocity_min/max = ±240`, `scale_min/max` correspondendo a 26–120 px de
lado, `angle_min/max = 0/90`, `alpha_curve` caindo a zero na metade da vida e
`scale_curve` caindo com o quadrado do progresso.

- [ ] **Passo 2: escrever `core/sparkle_burst.gd`**

```gdscript
class_name SparkleBurst
extends GPUParticles2D

func burst(at: Vector2, color: Color, count: int, max_size: float) -> void:
    # material é compartilhado entre instâncias; sem duplicar, um burst muda os outros
    process_material = process_material.duplicate()
    global_position = at
    amount = count
    modulate = color
    process_material.scale_max = max_size / texture.get_width()
    process_material.scale_min = process_material.scale_max * 0.22
    emitting = true
    finished.connect(queue_free)
```

- [ ] **Passo 3: verificar o brilho isolado**

Criar cena temporária com um nó no grupo `effects` e chamar
`SparkleBurst.burst(Vector2(960, 540), Color(1, 0.85, 0.45), 30, 120)` por
`execute_game_script`. `capture_frames` (4 quadros, ~0,15 s de intervalo).
Aceitação: estrelas saem do centro em todas as direções, giram, encolhem e
somem em ~0,7 s; o nó se remove sozinho depois (`get_game_scene_tree` não
mostra mais o burst).

- [ ] **Passo 4: montar `core/juicy_button.tscn`**

MCP: `create_scene`, raiz `TextureButton` chamada `JuicyButton`.
`update_property`: `ignore_texture_size = true`, `stretch_mode = 5`
(keep aspect centered), `mouse_default_cursor_shape = 2` (mãozinha).

- [ ] **Passo 5: escrever `core/juicy_button.gd`**

```gdscript
class_name JuicyButton
extends TextureButton

## Cresce no hover, encolhe no press, solta brilho no clique.

const PRESSED_TINT := Color(0.78, 0.78, 0.78)
const ANIMATION_SPEED := 14.0

const SPARKLE_BURST := preload("res://core/sparkle_burst.tscn")

@export var burst_color := Color(1.0, 0.85, 0.45)
@export var burst_count := 30
@export var burst_max_size := 120.0
## Botões de modal usam 1.0 nos dois: lá o retorno é só o tint de press.
@export var hover_scale := 1.07
@export var pressed_scale := 0.92

func _ready() -> void:
    resized.connect(_center_pivot)
    _center_pivot()
    pressed.connect(_on_pressed)

func _process(delta: float) -> void:
    var step := 1.0 - exp(-ANIMATION_SPEED * delta)
    scale = scale.lerp(Vector2.ONE * _target_scale(), step)
    modulate = modulate.lerp(_target_tint(), step)

func _target_scale() -> float:
    if is_pressed():
        return pressed_scale
    if is_hovered():
        return hover_scale
    return 1.0

func _target_tint() -> Color:
    return PRESSED_TINT if is_pressed() else Color.WHITE

func _center_pivot() -> void:
    pivot_offset = size / 2.0

func _on_pressed() -> void:
    Audio.play_click()
    var effects := get_tree().get_first_node_in_group("effects")
    if effects == null:
        return
    var burst := SPARKLE_BURST.instantiate()
    effects.add_child(burst)
    burst.burst(global_position + size / 2.0, burst_color, burst_count, burst_max_size)
```

- [ ] **Passo 6: verificar hover, press e brilho**

Cena temporária com um `JuicyButton` (textura `button_story_mode.webp`) e um
`Node2D` no grupo `effects`. `play_scene`, então:
`simulate_mouse_move` sobre o botão → `get_game_screenshot` (aceitação: botão
visivelmente maior); `simulate_mouse_click` → `capture_frames`
(aceitação: encolhe e escurece durante o toque, brilho sai do centro do botão,
som de clique aparece no log).

Clicar duas vezes em menos de 60 ms e conferir no log que só um clique tocou.

- [ ] **Passo 7: commit**

```bash
git add core
git commit -m "feat: botao juicy e explosao de brilhos reutilizaveis"
```

---

### Task 6: A tela do menu

**Arquivos:**
- Criar: `ui/menu/main_menu.tscn`, `ui/menu/main_menu.gd`

**Interfaces:**
- Consome: `menu_background.tscn`, `JuicyButton`, `Audio`.
- Produz: `main_menu.tscn` com os nós `MenuUI` (coluna de botões), `WelcomeSign`,
  `Effects` (grupo `effects`) e `Overlays` (`CanvasLayer`); e os métodos
  `open_panel(scene: PackedScene, hide_sign: bool) -> void` e
  `close_panel() -> void` em `main_menu.gd`.

- [ ] **Passo 1: montar o esqueleto**

MCP: `create_scene` `res://ui/menu/main_menu.tscn`, raiz `Control` chamada
`MainMenu` com `set_anchor_preset` full rect e `mouse_filter = 2` (IGNORE, pra
não roubar clique dos filhos). `theme` = `res://ui/theme.tres`.

Filhos, nesta ordem (a ordem é a profundidade):

1. `Background` — instância de `backgrounds/menu_background.tscn`
   (`add_scene_instance`).
2. `Leaves` — `GPUParticles2D`.
3. `WelcomeSign` — `AnimatedSprite2D`.
4. `MenuUI` — `Control` full rect, `mouse_filter = 2`.
5. `Effects` — `Node2D`, no grupo `effects` (`set_node_groups`).
6. `Overlays` — `CanvasLayer`.

`save_scene` e `get_editor_screenshot` para confirmar a árvore.

- [ ] **Passo 2: logo com intro e idle**

Dentro de `MenuUI`, `TextureRect` chamado `Logo`:
`texture = res://assets/art/UI/MainMenu/logo.webp`, `expand_mode = 1`,
`stretch_mode = 5` (keep aspect centered), âncora topo-centro colada no topo,
tamanho na proporção 919×427, `pivot_offset` no centro,
`modulate = Color(1, 0.894, 0.882)`.

`AnimationPlayer` chamado `LogoAnimation`, com `create_animation` +
`add_animation_track` + `set_animation_keyframe`:

- `intro`, 0,6 s: `scale` `(0.3,0.3)` em 0 → `(1.08,1.08)` em 0,35 → `(1,1)` em
  0,6; `modulate:a` 0 em 0 → 1 em 0,3.
- `idle`, 2 s, loop: `scale` `(1,1)` em 0 → `(1.03,1.03)` em 1,0 → `(1,1)` em 2,0.

`autoplay = intro`; no script, `animation_finished` de `intro` toca `idle`.

- [ ] **Passo 3: placa de boas-vindas**

No `AnimatedSprite2D` `WelcomeSign`: `SpriteFrames` com os 53 frames de
`assets/art/UI/WelcomeSign/` em ordem (`welcome_sign_0001` … `welcome_sign_0105`,
ímpares). Ancorada à direita, ~50 px da borda, ~181 px abaixo do centro
vertical, proporção 886×788.

`AnimationPlayer` chamado `SignAnimation` com uma animação `sway` de ~4,4 s
que anima `frame` de 0 a 52, `loop_mode = pingpong`, e os keyframes com curva de
ease (mais denso no meio, esparso nas pontas) — é isso que zera a velocidade nas
viradas, sem tranco. `autoplay = sway`.

- [ ] **Passo 4: folhas caindo**

No `GPUParticles2D` `Leaves`, ancorado no topo e largo como a tela:

| Propriedade | Valor |
|---|---|
| `texture` | `res://assets/art/Environments/Leaves/leaf_01.webp` |
| `amount` | 2 |
| `lifetime` | 12.0 |
| `preprocess` | 0.0 |
| `randomness` | 1.0 |
| `explosiveness` | 0.0 |

`ParticleProcessMaterial`: `emission_shape = Box` (largura da tela, altura 1),
`gravity = (0, 110)`, `initial_velocity_min/max = 0/30`,
`angular_velocity_min/max = ±40`, `scale_min/max = 0.6/1.0`,
`turbulence_enabled = true` com `turbulence_noise_strength ≈ 3`,
`turbulence_noise_scale ≈ 2`, e `alpha_curve` subindo de 0 a 1 nos primeiros 4%
da vida (~0,5 s).

- [ ] **Passo 5: coluna de botões**

Dentro de `MenuUI`, `VBoxContainer` chamado `Buttons`, centrado
horizontalmente, com o centro do grupo ~184 px abaixo do centro da tela,
`theme_override_constants/separation = 16`, `alignment = center`.

Cinco instâncias de `core/juicy_button.tscn`, nesta ordem, cada uma com
`custom_minimum_size` na proporção e `texture_normal` correspondente:

| Nó | Textura | Tamanho | `burst_color` | `burst_count` | `burst_max_size` |
|---|---|---|---|---|---|
| `StoryMode` | `button_story_mode.webp` | 420×146 | `#FFD973` | 30 | 120 |
| `FreeMode` | `button_free_mode.webp` | 420×148 | `#EBFF9E` | 30 | 120 |
| `SettingsButton` | `button_settings.webp` | 300×101 | `#EBC7FF` | 30 | 120 |
| `CreditsButton` | `button_credits.webp` | 300×101 | `#FFE073` | 30 | 120 |
| `QuitButton` | `button_quit.webp` | 260×88 | `#FFA68C` | 12 | 60 |

- [ ] **Passo 6: escrever `ui/menu/main_menu.gd`**

```gdscript
extends Control

@export var world_select_scene: PackedScene
@export var settings_panel_scene: PackedScene
@export var credits_scene: PackedScene
@export var quit_confirm_scene: PackedScene

@onready var _menu_ui: Control = $MenuUI
@onready var _sign: AnimatedSprite2D = $WelcomeSign
@onready var _overlays: CanvasLayer = $Overlays
@onready var _logo_animation: AnimationPlayer = $MenuUI/Logo/LogoAnimation

func _ready() -> void:
    _logo_animation.animation_finished.connect(_on_logo_intro_finished)
    $MenuUI/Buttons/StoryMode.pressed.connect(open_panel.bind(world_select_scene, true))
    $MenuUI/Buttons/SettingsButton.pressed.connect(open_panel.bind(settings_panel_scene, false))
    $MenuUI/Buttons/CreditsButton.pressed.connect(open_panel.bind(credits_scene, false))
    $MenuUI/Buttons/QuitButton.pressed.connect(open_modal.bind(quit_confirm_scene))

## Painel que substitui o menu: esconde os botões (e a placa, quando pedido).
func open_panel(scene: PackedScene, hide_sign: bool) -> void:
    _menu_ui.visible = false
    _sign.visible = not hide_sign
    _add_panel(scene)

## Modal que aparece por cima, com o menu ainda à vista.
func open_modal(scene: PackedScene) -> void:
    _add_panel(scene)

func _add_panel(scene: PackedScene) -> void:
    # Modo Livre e cenas ainda não ligadas caem aqui e não fazem nada
    if scene == null:
        _menu_ui.visible = true
        _sign.visible = true
        return
    var panel := scene.instantiate()
    panel.closed.connect(_on_panel_closed)
    _overlays.add_child(panel)

func _on_panel_closed() -> void:
    _menu_ui.visible = true
    _sign.visible = true

func _on_logo_intro_finished(animation_name: StringName) -> void:
    if animation_name != &"intro":
        return
    _logo_animation.play("idle")
```

Ligar os `@export` de cena no inspector fica para as tarefas 7–10, conforme cada
painel existir. Até lá, botão com cena vazia não faz nada — e é isso que o
`FreeMode` faz para sempre.

- [ ] **Passo 7: verificar a tela**

`play_scene` com `main_menu.tscn`, `get_game_screenshot`.
Aceitação, comparando com
`../floresta-dos-bichinhos-old/site/floresta-de-bichinhos/assets/shots/01-menu.webp`:
logo colado no topo, centralizado; coluna de cinco botões centralizada, abaixo do
logo; placa à direita, cobrindo em parte a coluna; fundo oscilando; música
tocando; sem sobreposição de botão com botão.

`capture_frames` por ~2 s no início: aceitação — o logo entra crescendo com fade,
depois respira; nenhum elemento aparece por teleporte.

- [ ] **Passo 8: verificar 4:3**

Rodar a 1440×1080 e tirar screenshot.
Aceitação: nenhum botão sai da tela; logo continua colado no topo; a placa não
cobre mais que a borda direita da coluna de botões.

- [ ] **Passo 9: commit**

```bash
git add ui/menu
git commit -m "feat: tela do menu com logo, placa, folhas e botoes"
```

---

### Task 7: Base dos painéis e modal de sair

**Arquivos:**
- Criar: `core/menu_panel.gd`, `core/panel_base.tscn`
- Criar: `ui/menu/panels/quit_confirm.tscn`, `ui/menu/panels/quit_confirm.gd`
- Modificar: `ui/menu/main_menu.tscn` (ligar `quit_confirm_scene`)

**Interfaces:**
- Produz: `class_name MenuPanel extends Control`, sinal `closed`, método
  `close() -> void`, animação `pop_in` no `AnimationPlayer` chamado `Animation`.
- Produz: `quit_confirm.tscn`, que emite `closed` no "Não" e chama
  `get_tree().quit()` no "Sim".

- [ ] **Passo 1: montar `core/panel_base.tscn`**

MCP: `create_scene`, raiz `Control` chamada `MenuPanel`, full rect,
`theme = res://ui/theme.tres`, `pivot_offset` no centro da tela (960, 540).

Filhos: `AnimationPlayer` chamado `Animation` e `JuicyButton` chamado
`BackButton` (`texture_normal = button_back.webp`, ~120×115, ancorado no
topo-esquerdo, `burst_count = 0`).

`create_animation` `pop_in`, 0,25 s: `modulate:a` 0 → 1 em 0,18;
`scale` `(0.92,0.92)` em 0 → `(1.02,1.02)` em 0,14 → `(1,1)` em 0,25.
`autoplay = pop_in`.

- [ ] **Passo 2: escrever `core/menu_panel.gd`**

```gdscript
class_name MenuPanel
extends Control

signal closed

func _ready() -> void:
    $BackButton.pressed.connect(close)

func close() -> void:
    closed.emit()
    queue_free()
```

O clique já toca o som dentro do `JuicyButton`; o painel não repete.

- [ ] **Passo 3: montar `quit_confirm.tscn`**

Cena independente: **não** herda de `panel_base.tscn`, porque este modal não tem
botão voltar e tem animação própria. Raiz `Control` full rect com script
próprio, `create_script` `res://ui/menu/panels/quit_confirm.gd`:

```gdscript
extends Control

signal closed

func _ready() -> void:
    $Panel/NoButton.pressed.connect(_on_no)
    $Panel/YesButton.pressed.connect(get_tree().quit)

func _on_no() -> void:
    closed.emit()
    queue_free()
```

Árvore e propriedades:

| Nó | Tipo | Configuração |
|---|---|---|
| `Dim` | `ColorRect` | full rect, `color = Color(0,0,0,0)`, `mouse_filter = 0` (segura clique fora) |
| `Panel` | `NinePatchRect` | `modal_panel.webp`, patch margin 96 nos quatro lados, 640×380, centro da tela, `pivot_offset` no centro |
| `Panel/Question` | `Label` | `text = tr("quitmodal.question")`, variação `ModalQuestion66`, centralizado, 95 px acima do centro do painel |
| `Panel/NoButton` | `JuicyButton` | `modal_btn_green.webp`, 220×110, a (−140, −75) do centro do painel, `burst_count = 0` |
| `Panel/YesButton` | `JuicyButton` | `modal_btn_red.webp`, 220×110, a (+140, −75), `burst_count = 0` |
| `Panel/NoButton/Label` | `Label` | `tr("quitmodal.no")`, `ModalButton54`, branco, centralizado |
| `Panel/YesButton/Label` | `Label` | `tr("quitmodal.yes")`, `ModalButton54`, branco, centralizado |

`AnimationPlayer` `Animation` com `pop_in` de 0,24 s: `Dim:color:a` 0 → 0,75 em
0,15; `Panel:scale` `(0.75,0.75)` → `(1.06,1.06)` em 0,14 → `(1,1)` em 0,24.
`autoplay = pop_in`.

Botões de modal não crescem nem encolhem — só recebem o tint de press, como no
Flutter. No inspector de `NoButton` e `YesButton`: `hover_scale = 1.0`,
`pressed_scale = 1.0`, `burst_count = 0`.

- [ ] **Passo 4: ligar no menu**

No inspector do `MainMenu`, `quit_confirm_scene` =
`res://ui/menu/panels/quit_confirm.tscn`. `save_scene`.

- [ ] **Passo 5: verificar**

`play_scene` com `main_menu.tscn`; `simulate_mouse_click` no botão Sair;
`get_game_screenshot`.
Aceitação: tela escurece a ~75%, painel aparece com pop, pergunta em pt-BR,
botões verde/vermelho legíveis, **o menu continua visível atrás**.

`simulate_mouse_click` no "Não" → screenshot: modal sumiu, menu intacto e
clicável (clicar em Créditos depois não deve travar).

Não testar o "Sim" com o jogo rodando pelo MCP (ele fecha a sessão de play);
verificar apenas que `YesButton.pressed` está conectado a `quit`, por
`find_signal_connections`.

- [ ] **Passo 6: commit**

```bash
git add core/menu_panel.gd core/panel_base.tscn ui/menu
git commit -m "feat: base dos paineis e modal de confirmacao de saida"
```

---

### Task 8: Painel de ajustes

**Arquivos:**
- Criar: `ui/menu/panels/settings_panel.tscn`, `ui/menu/panels/settings_panel.gd`
- Modificar: `ui/menu/main_menu.tscn` (ligar `settings_panel_scene`)

**Interfaces:**
- Consome: `MenuPanel`, `Settings.set_value`, `Post.set_quality` (via
  `Settings.changed`), `ui/theme.tres`.

- [ ] **Passo 1: montar o painel**

Instanciar `core/panel_base.tscn` como raiz da cena nova
(`add_scene_instance` + "editable children" para poder acrescentar filhos).

| Nó | Tipo | Configuração |
|---|---|---|
| `Panel` | `NinePatchRect` | `modal_panel.webp`, patch 96, 980×760, centro da tela |
| `Panel/Rows` | `VBoxContainer` | 820×640 dentro do painel, `separation = 12` |
| `Panel/Rows/MusicRow` … | `HBoxContainer` | 4 linhas de 100 px de altura |

Cada linha: `Label` (variação `SettingLabel44`) com 42% da largura e o controle
ocupando o resto:

| Linha | Chave do rótulo | Controle |
|---|---|---|
| `MusicRow` | `settings.music` | `HSlider` `MusicSlider`, `min_value = 0`, `max_value = 1`, `step = 0.01` |
| `SfxRow` | `settings.sfx` | `HSlider` `SfxSlider`, idem |
| `QualityRow` | `settings.quality` | `OptionButton` `QualityOption` |
| `LanguageRow` | `settings.language` | `OptionButton` `LanguageOption` |

- [ ] **Passo 2: escrever o script**

```gdscript
extends MenuPanel

const QUALITY_KEYS := ["settings.quality.low", "settings.quality.medium", "settings.quality.high"]
const LOCALES := ["pt_BR", "it"]
const FLAGS := {
    "pt_BR": preload("res://assets/art/UI/Flags/flag_pt_br.webp"),
    "it": preload("res://assets/art/UI/Flags/flag_it.webp"),
}
const LOCALE_NAMES := {"pt_BR": "Português (Brasil)", "it": "Italiano"}

@onready var _music_slider: HSlider = $Panel/Rows/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Panel/Rows/SfxRow/SfxSlider
@onready var _quality_option: OptionButton = $Panel/Rows/QualityRow/QualityOption
@onready var _language_option: OptionButton = $Panel/Rows/LanguageRow/LanguageOption

func _ready() -> void:
    super()
    _music_slider.value = Settings.music_volume
    _sfx_slider.value = Settings.sfx_volume
    _fill_quality()
    _fill_language()

    _music_slider.value_changed.connect(func(value): Settings.set_value("music_volume", value))
    _sfx_slider.value_changed.connect(func(value): Settings.set_value("sfx_volume", value))
    _quality_option.item_selected.connect(func(index): Settings.set_value("quality", index))
    _language_option.item_selected.connect(_on_language_selected)

func _fill_quality() -> void:
    _quality_option.clear()
    for key in QUALITY_KEYS:
        _quality_option.add_item(tr(key))
    _quality_option.selected = Settings.quality

func _fill_language() -> void:
    _language_option.clear()
    for index in LOCALES.size():
        var code: String = LOCALES[index]
        _language_option.add_icon_item(FLAGS[code], LOCALE_NAMES[code])
    _language_option.selected = LOCALES.find(Settings.locale)

func _on_language_selected(index: int) -> void:
    Settings.set_value("locale", LOCALES[index])
    # os Labels se retraduzem sozinhos; os itens do dropdown não
    _fill_quality()
    _fill_language()
```

- [ ] **Passo 3: ligar no menu e abrir**

`settings_panel_scene` no inspector do `MainMenu`. `play_scene`,
`simulate_mouse_click` no botão Ajustes, `get_game_screenshot`.
Aceitação: painel com pop, quatro linhas alinhadas, rótulos em pt-BR, sliders
cheios (volume 1) e dropdowns mostrando "Alta" e "Português (Brasil)" com
bandeira.

- [ ] **Passo 4: verificar que cada controle age**

Por `execute_game_script` e cliques:

1. Arrastar `MusicSlider` para 0 → a música silencia (conferir
   `AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) == true`).
2. Selecionar Qualidade "Baixa" → `Post` com `taps = 0` (conferir
   `get_shader_params` no `Screen` do Post, ou o halo sumindo no screenshot).
3. Selecionar Italiano → screenshot com "Musica / Effetti / Qualità / Lingua",
   e o menu atrás também em italiano ao fechar o painel.
4. Fechar e reabrir o painel → os valores voltam como foram deixados.
5. Reiniciar a cena (`stop_scene` + `play_scene`) → os valores persistem.

- [ ] **Passo 5: commit**

```bash
git add ui/menu
git commit -m "feat: painel de ajustes com volume, qualidade e idioma"
```

---

### Task 9: Seleção de mundo e stub do mapa

**Arquivos:**
- Criar: `ui/world_map/world_map.tscn`, `ui/world_map/world_map.gd`
- Criar: `ui/menu/panels/world_select.tscn`, `ui/menu/panels/world_select.gd`
- Modificar: `ui/menu/main_menu.tscn` (ligar `world_select_scene`)

**Interfaces:**
- Produz: `world_map.tscn` com botão que volta para `res://ui/menu/main_menu.tscn`.
- Consome: `MenuPanel`, `Audio.play_locked`.

- [ ] **Passo 1: montar o stub do mapa**

`create_scene` `res://ui/world_map/world_map.tscn`, raiz `Control` full rect,
`theme` do projeto. Filhos: `Background` (instância de
`backgrounds/menu_background.tscn` — provisório, o mapa real terá o seu),
`Title` (`Label`, `tr("worldmap.world1.title")`, variação `Title80`, topo-centro),
`Subtitle` (`Label`, `tr("worldmap.world1.name")`, `Name36`, abaixo do título),
`BackButton` (`JuicyButton`, `button_back.webp`, topo-esquerdo),
`Effects` (`Node2D` no grupo `effects`).

Script `world_map.gd`:

```gdscript
extends Control

func _ready() -> void:
    $BackButton.pressed.connect(_go_back)

func _go_back() -> void:
    get_tree().change_scene_to_file("res://ui/menu/main_menu.tscn")
```

- [ ] **Passo 2: montar `world_select.tscn`**

Raiz a partir de `core/panel_base.tscn`. Filhos:

| Nó | Tipo | Configuração |
|---|---|---|
| `Title` | `Label` | `tr("worldselect.title")`, `Title80`, topo-centro, 90 px do topo |
| `Cards` | `HBoxContainer` | centrado, `separation = 60`, 60 px abaixo do centro |
| `Cards/World1` | `JuicyButton` | `world_card_1.webp`, 400×600, `burst_count = 0` |
| `Cards/World2` | `TextureRect` + `AnimationPlayer` | `world_card_2.webp`, 400×600 |
| `Cards/World3` | `TextureRect` + `AnimationPlayer` | `world_card_3.webp`, 400×600 |

Nas cartas travadas, `AnimationPlayer` chamado `Shake` com a animação `shake` de
0,4 s (keyframes exatos):

| t (s) | `position:x` | `rotation` (graus) |
|---|---|---|
| 0.00 | 0 | 0 |
| 0.05 | −14 | 3.0 |
| 0.11 | 12 | −2.5 |
| 0.17 | −9 | 2.0 |
| 0.23 | 6 | −1.2 |
| 0.29 | −3 | 0.6 |
| 0.35 | 1.5 | −0.3 |
| 0.40 | 0 | 0 |

`pivot_offset` no centro de cada carta, senão a rotação gira pelo canto.

- [ ] **Passo 3: escrever o script**

```gdscript
extends MenuPanel

func _ready() -> void:
    super()
    $Cards/World1.pressed.connect(_open_world_map)
    _connect_locked($Cards/World2)
    _connect_locked($Cards/World3)

func _open_world_map() -> void:
    get_tree().change_scene_to_file("res://ui/world_map/world_map.tscn")

func _connect_locked(card: TextureRect) -> void:
    card.gui_input.connect(func(event): _on_card_input(event, card))
    card.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_card_input(event: InputEvent, card: TextureRect) -> void:
    if not (event is InputEventMouseButton and event.pressed):
        return
    Audio.play_locked()
    card.get_node("Shake").play("shake")
```

- [ ] **Passo 4: ligar e verificar**

`world_select_scene` no inspector do `MainMenu`. `play_scene`,
`simulate_mouse_click` em Modo História, `get_game_screenshot`.
Aceitação: título no topo, três cartas lado a lado, **menu e placa escondidos**,
botão voltar no canto.

`simulate_mouse_click` na carta 2 → `capture_frames`: aceitação — a carta treme
por ~0,4 s e volta ao lugar exato; som de travado no log.

`simulate_mouse_click` na carta 1 → screenshot: mapa stub na tela.
Clicar em voltar no mapa → screenshot: menu de volta.

- [ ] **Passo 5: verificar que a música não recomeça**

Antes de sair do menu, anotar `Audio._music.get_playback_position()` por
`execute_game_script`. Ir ao mapa, voltar, e ler de novo.
Aceitação: o segundo valor é **maior** que o primeiro — a música seguiu tocando,
não reiniciou.

- [ ] **Passo 6: commit**

```bash
git add ui/menu ui/world_map
git commit -m "feat: selecao de mundo com cartas travadas e stub do mapa"
```

---

### Task 10: Créditos e portão parental

**Arquivos:**
- Criar: `ui/menu/panels/credits.tscn`, `ui/menu/panels/credits.gd`
- Criar: `ui/menu/panels/parental_gate.tscn`, `ui/menu/panels/parental_gate.gd`
- Modificar: `ui/menu/main_menu.tscn` (ligar `credits_scene`)

**Interfaces:**
- Produz: `credits.gd` com `@export var site_url: String = ""`; o chip do site só
  aparece quando preenchido.
- Produz: `parental_gate.tscn` com `@export var site_url: String`, que abre a URL
  após 3 s de toque contínuo.

- [ ] **Passo 1: montar `credits.tscn`**

Raiz a partir de `core/panel_base.tscn`. Filhos:

| Nó | Tipo | Configuração |
|---|---|---|
| `Panel` | `NinePatchRect` | `modal_panel.webp`, patch 96, 980×760, centro |
| `Panel/Scroll` | `ScrollContainer` | 820×640 dentro do painel |
| `Panel/Scroll/Entries` | `VBoxContainer` | `separation = 28`, largura do scroll |
| `Panel/SiteChip` | `JuicyButton` | `chip_pill.webp` tingido `#B88C61`, 260×60, rodapé do painel, `burst_count = 0`, `hover_scale = 1.0`, `pressed_scale = 1.0` |
| `Panel/SiteChip/Label` | `Label` | `tr("credits.site")`, variação `Chip18`, branco, centralizado |

Cada entrada é uma cena filha montada em `Entries`: `Label` do nome
(`Name36`), `HBoxContainer` de chips (`NinePatchRect` com `chip_pill.webp`,
patch 12, altura 36, `Label` `Chip18` branco centralizado), `Label` da bio
(`Bio26`, cor `#8C6640`, `autowrap_mode = 3`), e um `ColorRect` separador de
4 px `#B88C61` com alpha 0,5 entre entradas.

Entradas e cores dos chips:

| Pessoa | Chips |
|---|---|
| `credits.person.lucas.*` | `credits.role.creation` `#F2B840`, `credits.role.programming` `#61A84A` |
| `credits.person.joao.*` | `credits.role.gamedesign` `#EB8C40` |

- [ ] **Passo 2: escrever `credits.gd`**

```gdscript
extends MenuPanel

const PARENTAL_GATE := preload("res://ui/menu/panels/parental_gate.tscn")

## Vazio esconde o chip do site — o link só existe quando houver endereço.
@export var site_url := ""

func _ready() -> void:
    super()
    $Panel/SiteChip.visible = not site_url.is_empty()
    $Panel/SiteChip.pressed.connect(_open_gate)

func _open_gate() -> void:
    var gate := PARENTAL_GATE.instantiate()
    gate.site_url = site_url
    add_child(gate)
```

- [ ] **Passo 3: montar `parental_gate.tscn`**

Raiz `Control` full rect (sem `panel_base` — este tem botão próprio de voltar):

| Nó | Tipo | Configuração |
|---|---|---|
| `Dim` | `ColorRect` | full rect, preto a 55%, `mouse_filter = 0` |
| `Panel` | `NinePatchRect` | `modal_panel.webp`, patch 96, 900×620, centro |
| `Panel/Title` | `Label` | `tr("credits.social.gate.title")`, `SettingLabel44`, +200 do centro |
| `Panel/Instruction` | `Label` | `tr("credits.social.gate.instruction")`, `Instruction28`, `#8C6640`, +90, centralizado |
| `Panel/HoldButton` | `TextureProgressBar` | `chip_pill.webp` como `texture_under` tingido `#BFBFBF` e `texture_progress` tingido `#61A84A`, `fill_mode = 0` (esquerda→direita), 420×110, −60 |
| `Panel/HoldButton/Label` | `Label` | `tr("credits.social.gate.hold")`, `Instruction28`, branco, centralizado |
| `Panel/BackButton` | `JuicyButton` | `chip_pill.webp` tingido `#B88C61`, 260×90, −215, `burst_count = 0` |
| `Panel/BackButton/Label` | `Label` | `tr("credits.social.gate.back")`, `Instruction28`, branco |

- [ ] **Passo 4: escrever `parental_gate.gd`**

```gdscript
extends Control

const HOLD_SECONDS := 3.0

@export var site_url := ""

@onready var _hold_button: TextureProgressBar = $Panel/HoldButton

var _holding := false

func _ready() -> void:
    _hold_button.gui_input.connect(_on_hold_input)
    $Panel/BackButton.pressed.connect(queue_free)

func _process(delta: float) -> void:
    if not _holding:
        _hold_button.value = 0.0
        return
    _hold_button.value += delta / HOLD_SECONDS * _hold_button.max_value
    if _hold_button.value < _hold_button.max_value:
        return
    _holding = false
    OS.shell_open(site_url)
    queue_free()

func _on_hold_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton:
        return
    _holding = event.pressed
```

- [ ] **Passo 5: verificar os créditos**

`credits_scene` no inspector do `MainMenu`. `play_scene`, clicar em Créditos,
`get_game_screenshot`.
Aceitação: painel com as duas pessoas, chips coloridos legíveis, bio quebrando
linha dentro da largura, separador entre as entradas, rolagem funcionando
(`simulate_mouse_move` + scroll), e **sem chip de site** (URL vazia).

- [ ] **Passo 6: verificar o portão**

Por `execute_game_script`, setar `site_url` do painel de créditos para
`https://example.com` e reabrir. Aceitação: chip aparece; clicar abre o portão;
segurar o botão enche a barra da esquerda para a direita; **soltar antes dos 3 s
zera a barra**; o botão Voltar fecha sem abrir nada.

Não completar os 3 s durante o teste (abriria um navegador na máquina do dono).
Verificar a chamada por leitura do código e por um teste com
`site_url = ""`, que deve manter o chip escondido.

- [ ] **Passo 7: commit**

```bash
git add ui/menu
git commit -m "feat: creditos com chips e portao parental de 3 segundos"
```

---

### Task 11: Splash da DOMA e navegação completa

**Arquivos:**
- Criar: `assets/audio/Splash/hum.wav`, `zap.wav`, `thump.wav` (copiados de
  `../floresta-dos-bichinhos-old/packages/doma_splash/assets/`)
- Criar: `ui/splash/logo_paths.gd`, `ui/splash/neon_logo.gd`,
  `ui/splash/doma_splash.tscn`, `ui/splash/doma_splash.gd`
- Modificar: `project.godot` (`application/run/main_scene`)

**Interfaces:**
- Consome: `Audio.start_music_fade`.
- Produz: cena principal do projeto, que termina em `main_menu.tscn`.

A splash não é "uma animação": é um letreiro de neon que se traça por partes,
com som por parte. Os números abaixo vêm de
`packages/doma_splash/lib/src/timeline.dart` e `neon_sound.dart` e são a
especificação — não estimar nada.

| Momento (s) | O que acontece | Som |
|---|---|---|
| 0.15 → 0.85 | traça `d_purple` | `zap` |
| 0.70 → 1.40 | traça `d_white` | `zap` |
| 1.30 → 1.75 | traça `dpad_cross` | `zap` |
| 1.60 → 2.00 | traça `dpad_buttons` | `zap` |
| 2.05 → 2.60 | "Doma Studio" acende por fade (não é traçado) | `zap` |
| 2.72–2.80, 2.88–2.93 | quedas de tubo: brilho cai a 12% | — |
| 3.05 | estouro (flash) | `thump` |
| 3.30 → 3.70 | fade final da cena, som desce junto | — |
| — | fundo contínuo do início ao fim | `hum` em loop |

Tremulação constante: `1 + 0.05 * sin(t * 17.3) * sin(t * 6.1)`, multiplicando o
brilho de todas as partes e da palavra.

- [ ] **Passo 1: portar os assets de áudio**

```bash
mkdir -p ~/Games/floresta-dos-bichinhos/assets/audio/Splash
cp ~/Games/floresta-dos-bichinhos-old/packages/doma_splash/assets/{hum,zap,thump}.wav \
   ~/Games/floresta-dos-bichinhos/assets/audio/Splash/
```

Reimportar pelo editor. Marcar `loop = true` só no `hum.wav`.

- [ ] **Passo 2: portar os caminhos da logo**

Converter `packages/doma_splash/lib/src/logo_paths.dart` para
`ui/splash/logo_paths.gd`: uma constante por parte
(`D_PURPLE`, `D_WHITE`, `DPAD_CROSS`, `DPAD_BUTTONS`), cada uma um
`PackedVector2Array` com os pontos já resolvidos. O `svg_path.dart` do Flutter
resolvia os comandos SVG em runtime; aqui os pontos entram resolvidos, porque a
logo não muda.

Verificação: script headless que imprime a contagem de pontos de cada parte e
confirma que nenhuma está vazia.
Esperado: quatro linhas com contagem > 0.

- [ ] **Passo 3: escrever `ui/splash/neon_logo.gd`**

`Node2D` que desenha o neon em `_draw`, com a mesma matemática da timeline:

```gdscript
extends Node2D

const LogoPaths := preload("res://ui/splash/logo_paths.gd")

const PART_ONSET := {"d_purple": 0.15, "d_white": 0.70, "dpad_cross": 1.30, "dpad_buttons": 1.60}
const PART_DURATION := {"d_purple": 0.70, "d_white": 0.70, "dpad_cross": 0.45, "dpad_buttons": 0.40}
const BLACKOUTS := [[2.72, 2.80], [2.88, 2.93]]
const TUBE_WIDTH := 14.0

var elapsed := 0.0

func _process(delta: float) -> void:
    elapsed += delta
    queue_redraw()

func _draw() -> void:
    var dip := flicker() * (0.12 if in_blackout() else 1.0)
    for part in PART_ONSET:
        var drawn := progress(PART_ONSET[part], PART_DURATION[part])
        if drawn <= 0.0:
            continue
        var points: PackedVector2Array = LogoPaths.get(part.to_upper())
        var visible_points := points.slice(0, maxi(2, int(points.size() * drawn)))
        draw_polyline(visible_points, color_of(part) * (drawn * dip), TUBE_WIDTH, true)

## brilho tremulando: nunca apaga, só oscila
func flicker() -> float:
    return 1.0 + 0.05 * sin(elapsed * 17.3) * sin(elapsed * 6.1)

func in_blackout() -> bool:
    for range_pair in BLACKOUTS:
        if elapsed >= range_pair[0] and elapsed < range_pair[1]:
            return true
    return false

func progress(onset: float, duration: float) -> float:
    return clampf((elapsed - onset) / duration, 0.0, 1.0)

func color_of(part: String) -> Color:
    return Color(0.62, 0.35, 0.95) if part == "d_purple" else Color(1, 1, 1)
```

O glow do Flutter era um `MaskFilter.blur`; aqui vem de graça do `Post`
(bloom já roda por cima de tudo). Conferir no passo 6 se o brilho está fraco e,
se estiver, subir `bloom_intensity` **no material do Post**, não neste script.

- [ ] **Passo 4: montar `doma_splash.tscn`**

`create_scene` `res://ui/splash/doma_splash.tscn`, raiz `Control` full rect:

| Nó | Tipo | Configuração |
|---|---|---|
| `Backdrop` | `ColorRect` | full rect, `Color(0.04, 0.03, 0.07)` |
| `Logo` | `Node2D` com `neon_logo.gd` | centro da tela |
| `Word` | `Label` | "Doma Studio", Baloo2, `modulate:a = 0` no início |
| `Flash` | `ColorRect` | full rect branco, `modulate:a = 0` |
| `Hum` | `AudioStreamPlayer` | `hum.wav`, bus `SFX` |
| `Zap` | `AudioStreamPlayer` | `zap.wav`, bus `SFX` |
| `Thump` | `AudioStreamPlayer` | `thump.wav`, bus `SFX` |
| `Animation` | `AnimationPlayer` | animação `splash`, 3,7 s |

Na animação `splash`, por `set_animation_keyframe`:
`Word:modulate:a` 0 em 2,05 → 1 em 2,60; `Flash:modulate:a` 0 em 3,00 → 0,9 em
3,05 → 0 em 3,25; `modulate:a` da raiz 1 em 3,30 → 0 em 3,70. `autoplay = splash`.

Os cinco `zap` e o `thump` entram como **call method tracks** na mesma animação,
nos tempos da tabela — assim os cues vivem no editor, não num tracker em código.

- [ ] **Passo 5: escrever `doma_splash.gd`**

```gdscript
extends Control

@onready var _animation: AnimationPlayer = $Animation

func _ready() -> void:
    $Hum.play()
    _animation.animation_finished.connect(_on_finished)

func _on_finished(_animation_name: StringName) -> void:
    # o fade de 3s começa aqui, pra ser ouvido junto com o menu aparecendo
    Audio.start_music_fade()
    get_tree().change_scene_to_file("res://ui/menu/main_menu.tscn")

func play_zap() -> void:
    $Zap.play()

func play_thump() -> void:
    $Thump.play()
```

- [ ] **Passo 6: definir como cena principal e verificar**

MCP: `set_project_setting` `application/run/main_scene` =
`res://ui/splash/doma_splash.tscn`.

`play_scene` sem argumento. `record_frames` cobrindo os 3,7 s.
Aceitação: o "D" roxo se traça primeiro, depois o branco, depois a cruz e os
botões do d-pad; "Doma Studio" acende por fade sem ser traçado; há duas quedas
rápidas de brilho perto de 2,8 s; um estouro branco em 3,05; a cena some em fade
e o menu entra. Cada traçado tem um `zap`; o estouro tem um `thump`; o `hum`
toca o tempo inteiro.

- [ ] **Passo 7: verificar o fade da música**

Por `execute_game_script`, ler o volume do bus `Music` logo depois da troca de
cena e de novo 3 s depois.
Aceitação: o segundo valor é maior — a música entrou subindo, não de uma vez.

- [ ] **Passo 8: verificar o caminho completo**

Desde a splash: menu → Ajustes → voltar → Créditos → voltar → Modo História →
carta 1 → mapa → voltar → Sair → Não.
Aceitação: nenhuma tela fica presa, nenhum painel some sem devolver o menu,
música contínua do começo ao fim, `get_editor_errors` e `get_output_log` limpos.

- [ ] **Passo 9: commit**

```bash
git add ui/splash assets/audio/Splash project.godot
git commit -m "feat: splash de neon da produtora como cena inicial do jogo"
```

---

### Task 12: Medição, 4:3 e acabamento

**Arquivos:**
- Modificar: presets de import de `assets/art/UI/MainMenu` e
  `assets/art/UI/WelcomeSign`, **se** a compressão borrar
- Modificar: `CLAUDE.md` (marcar o que fechou do M1)
- Criar: `CC-Session-Logs/<data>-menu-principal.md`

- [ ] **Passo 1: medir performance**

Com o menu rodando, `get_performance_monitors`.
Registrar: `TIME_FPS`, `RENDER_TEXTURE_MEM_USED`, `MEMORY_STATIC`.
Referência do M0: 60 fps estáveis e memória de textura abaixo de 200 MB (o
Flutter usa ~586 MB). Anotar os números no log da sessão, mesmo que passem.

- [ ] **Passo 2: medir com qualidade baixa**

`Post.set_quality(0)` e medir de novo.
Aceitação: fps igual ou melhor; se qualidade 2 não bater 60 fps num alvo fraco,
o dropdown já é a válvula de escape — registrar, não otimizar às cegas.

- [ ] **Passo 3: rodar em 4:3**

1440×1080. Screenshot do menu e de cada um dos cinco painéis.
Aceitação: nenhum elemento cortado, nenhum botão fora da tela, nenhum texto
transbordando o painel. Corrigir por âncora — nunca por número mágico de
posição.

- [ ] **Passo 4: inspecionar a compressão**

Cena temporária com o `logo.webp` e um frame da placa em `scale = 3` sobre fundo
escuro; `play_scene` e `get_game_screenshot`.
Aceitação: sem blocos de 4×4 na borda translúcida, sem halo sujo em volta do
contorno. Se houver, mudar `compress/mode` para `Lossless` em
`assets/art/UI/MainMenu` e `assets/art/UI/WelcomeSign`, reimportar, repetir o
screenshot e comparar os dois com `compare_screenshots`. Medir a textura de novo
depois da troca e anotar a diferença.

- [ ] **Passo 5: passar o menu inteiro em italiano**

Trocar o idioma em Ajustes e percorrer as cinco telas.
Aceitação: nenhum texto em português sobrou, nenhum texto estourou o container.

- [ ] **Passo 6: limpar**

Apagar as cenas temporárias criadas nas tarefas 2, 3 e 5 (`delete_scene`) e os
scripts do scratchpad. `get_project_statistics` para confirmar que não sobrou
cena órfã. `find_unused_resources` como conferência.

- [ ] **Passo 7: atualizar documentação e commitar**

Marcar no `CLAUDE.md` o que do M1 fechou (menu, ajustes, i18n, áudio,
pós-processamento) e o que continua aberto (mapa real, progressão, fases).
Escrever o log da sessão em `CC-Session-Logs/`, com os números medidos.

```bash
git add CLAUDE.md CC-Session-Logs assets
git commit -m "docs: menu principal fechado, com medicoes de fps e textura"
```

---

## Cobertura da spec

| Seção da spec | Tarefa |
|---|---|
| Autoload `Settings` | 1 |
| Autoload `Audio`, buses, fade | 1 |
| i18n | 2 |
| Tema | 2 |
| Autoload `Post`, shader | 3 |
| Fundo com shader de folhagem | 4 |
| Logo, placa, folhas | 6 |
| Botões e brilhos | 5, 6 |
| `world_select` | 9 |
| `settings_panel` | 8 |
| `credits` | 10 |
| `quit_confirm` | 7 |
| `parental_gate` | 10 |
| Splash e navegação | 11 |
| `world_map` stub | 9 |
| Validação (perf, 4:3, ASTC, idioma) | 12 |
