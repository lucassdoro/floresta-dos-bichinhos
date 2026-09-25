# Modo Livre — design

**Data:** 2026-09-25
**Status:** aprovado em conversa, aguardando revisão da spec

## Objetivo

Tela onde a criança escolhe **qualquer fase**, sem trava de progressão, filtrando por busca,
habilidade e mecânica. É também a porta de entrada do open source: uma fase feita por
terceiros aparece aqui só por existir numa pasta do projeto — sem editar arquivo central.

Referência visual: mockup aprovado (ChatGPT, conversa "Mockup Modo Livre"), com os ajustes
abaixo. Sem filtro por personagem, sem selo "Mod".

## Decisões fechadas

| Tema | Decisão |
|---|---|
| Como fase de terceiro entra | Pasta no código-fonte + ficha `.tres`, descoberta por varredura. Sem `.pck` em runtime |
| Progressão | Tudo aberto. Estrelas e contagem do livre ficam em save próprio; **não** tocam `Progression` |
| Filtros | Busca (texto) + Habilidade (chips-ícone, principal) + Mecânica (dropdown). Sem personagem |
| Card | Título, capa, descrição (2 linhas), melhor estrela (0–3), vezes jogada, "por <autor>" |
| "Vezes jogada" | Conta só fase **terminada** (vitória). Sair no meio não conta |
| Topo e voltar | Padrão existente: placa `world_header_plaque` + `Title`, `JuicyButton` com `button_back` |

## 1. Dados e descoberta

### `core/level_info.gd` — `class_name LevelInfo extends Resource`

Ficha editável no inspector.

| Campo | Tipo | Nota |
|---|---|---|
| `id` | `String` | Único. Ex.: `world1.fruit_breakfast`, `ana_dev.pesca_formas` |
| `title` | `String` | Chave de `tr()` ou texto literal (fase de terceiro) |
| `description` | `String` | Idem |
| `cover` | `Texture2D` | Capa do card |
| `skills` | `Array[Skill]` | Uma ou mais: `COLORS, NUMBERS, LETTERS, MEMORY, COORDINATION` |
| `mechanic` | `Mechanic` | Um dos 9 arquétipos: `DRAG_DROP, PAINT, SEQUENCE, ASSEMBLE, MEMORY, PATH, ACTION, PICK_RIGHT, GUIDE` |
| `author` | `String` | Vazio = "Floresta" |
| `scene_path` | `String` (`@export_file("*.tscn")`) | Cena da fase; raiz estende `LevelBase`. Caminho e não `PackedScene` para o catálogo não carregar todas as fases no boot |

Enums `Skill` e `Mechanic` vivem em `LevelInfo`.

### Autoload `LevelCatalog`

- No `_ready`, varre `res://levels/` recursivamente com `ResourceLoader.list_directory`
  (lida com os remaps do build exportado) e carrega todo arquivo terminado em `.level.tres`.
- Descarta com `push_warning` a ficha sem `scene_path` (ou apontando pra arquivo inexistente), sem `id` ou com `id` repetido (a primeira vence).
- Ordem: fases sem autor primeiro, na ordem do caminho; depois as de terceiros, por caminho.
- API: `all() -> Array[LevelInfo]`,
  `filter(text: String, skill: int, mechanic: int) -> Array[LevelInfo]` (`-1` = sem filtro).
  Busca compara `tr(title)` e `tr(description)` em minúsculas com `contains`.

### Fichas do mundo 1

`levels/world1/level_XX.level.tres` para as 10 fases, com capa, habilidades e mecânica.
O mapa da história continua usando caminho fixo — não muda.

### Contrato para quem faz fase (`docs/MODDING.md`)

1. Criar `levels/<autor>/<fase>/`.
2. Cena da fase com raiz estendendo `LevelBase` (chama `mistake()` / `win()`).
3. `<fase>.level.tres` do tipo `LevelInfo` preenchido no inspector.
4. Pronto — aparece no Modo Livre. Nenhum arquivo central editado.

## 2. Fluxo de jogo

### Autoload `FreePlay`

- **Sessão:** `current: LevelInfo` (`null` = modo história).
  `start(info)` guarda `current` e chama `SceneLoader.go_to(info.scene_path)`.
- **Recordes:** `user://free_play.json`, formato
  `{"version": 1, "levels": {"<id>": {"best_stars": 0-3, "plays": n}}}`.
  API: `get_best(id)`, `get_plays(id)`, `report(stars)` — soma 1 em `plays` e guarda o máximo
  de estrelas do `current`.

### Mudanças em `LevelBase` (só estas)

- `win()`: se `FreePlay.current` existe, `FreePlay.report(stars)` no lugar de
  `Progression.report_level_result`.
- `exit_level()`: se `FreePlay.current` existe, limpa `current` e vai para
  `res://ui/free_mode/free_mode.tscn`; senão, mapa (como hoje).
- `world_number` / `level_number` são ignorados no livre.

### Menu

O botão `FreeMode` do `main_menu` abre `res://ui/free_mode/free_mode.tscn` via `SceneLoader`.

## 3. Tela

### `ui/free_mode/free_mode.tscn`

- **Fundo:** `backgrounds/menu_background.tscn`, escurecido.
- **Topo:** placa + título "Modo Livre" no padrão do mapa. O trecho `WorldHeader`
  (placa + `Title`) vira cena compartilhada `core/plaque_header.tscn`, instanciada pelo mapa
  (que mantém o próprio `Subtitle`) e pelo Modo Livre. `BackButton` = `JuicyButton` com
  `button_back.webp`, volta ao menu.
- **`FilterBar`:** `NinePatchRect` de madeira com
  - `SearchField` (`LineEdit`, placeholder "Buscar fase...");
  - 5 chips de habilidade (`TextureButton` toggle; tocar no aceso desliga; no máximo um aceso);
  - `MechanicDropdown` (`OptionButton`, primeira opção "Todas").
  Filtros combinam em E; qualquer mudança refaz a grade.
- **Lista:** `ScrollContainer` vertical (arrastar por toque) com `GridContainer`.
  Colunas = `floor(largura_útil / largura_mínima_card)`: 4 em 16:9, 3 em 4:3.
- **Vazio:** label "Nenhuma fase encontrada".

### `ui/free_mode/level_card.tscn`

`NinePatchRect` (moldura) → `Title`, `Cover` (`TextureRect`, keep aspect covered, recortado),
`Description` (2 linhas, autowrap, reticências), rodapé: 3 estrelas (reusa as do mapa),
ícone replay + "x<plays>", "por <autor>".

- Entrada: tween escalonado de escala + opacidade (easing, nunca linear).
- Toque: pop de escala e `FreePlay.start(info)`. Arrastar rola sem abrir a fase.

### Assets

- ChatGPT gera spritesheet no estilo do mockup: faixa de madeira dos filtros, campo de busca,
  5 chips (normal e selecionado), botão do dropdown, moldura do card, ícone replay.
  Fatiado em `assets/art/UI/FreeMode/`, `Lossless` + mipmap.
- Capas do mundo 1: captura de cada fase em jogo via MCP, recortada,
  `assets/art/UI/FreeMode/covers/level_XX.webp`.

### i18n (`assets/i18n/ui.csv`, pt-BR e it)

`free_mode.title`, `free_mode.search`, `free_mode.empty`, `free_mode.by`, `free_mode.all`,
`skill.colors|numbers|letters|memory|coordination`, `mechanic.<9 arquétipos>`,
`level1XX.title` / `level1XX.description` para as 10 fases.

## Testes

- `tools/tests/test_free_mode.tscn` via `run_headless_scene`:
  - varredura acha as 10 fichas do mundo 1; ficha com `id` duplicado é descartada;
  - `filter` combina texto + habilidade + mecânica corretamente;
  - `FreePlay.report` guarda melhor estrela, soma `plays`, e `Progression` fica intocado.
- Em jogo (MCP): screenshot em 16:9 e 4:3; fluxo card → fase → vitória → volta com card
  atualizado; arrastar a lista não abre fase.

## Fora de escopo

Carregamento de `.pck` em runtime, filtro por personagem, selo de fase de terceiro,
tempo/cronômetro, idade sugerida, qualquer servidor.
