# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Floresta dos Bichinhos Perdidos** — jogo infantil (4 mundos × 10 fases), **Godot 4.7.2-stable**, GDScript.
Migração vinda da versão Flutter/Flame. Plano completo: `~/Games/2026-08-26-migracao-godot-design.md`.

---

## Como trabalhar neste projeto (regras de sessão)

1. **Godot é dirigido pelo MCP Pro, nunca "no escuro".** O editor fica aberto; toda cena, nó,
   propriedade e script passa pelo Godot MCP Pro. Nada de escrever `.tscn` na mão.
2. **Construir visualmente, dentro da engine.** A fase tem que existir no editor enquanto é feita —
   montar nós, ver na viewport, tirar screenshot, ajustar. Não montar por código e "ver depois".
3. **Preferir inspector a código** (`node set-property`). Valor visível no inspector é valor que o
   dono consegue ajustar sem pedir. GDScript só quando a propriedade não existe no inspector ou
   precisa ser dinâmica em runtime.
4. **Referência é `../floresta-dos-bichinhos-old`** (projeto Flutter, git próprio, intacto): arte,
   áudio, vozes, vídeos, layout das telas, regras de cada fase. Nunca recriar de olhômetro — abrir a
   referência.
5. **Animação suave sempre.** `Tween` com easing (nunca linear em movimento de personagem/UI),
   `AnimationPlayer` para o que é coreografado. Nada de teleporte, nada de pop sem escala.
6. **Gráfico bonito, sem serrilhado.** Filtro de textura já é *Linear Mipmap* no projeto e MSAA 2D
   está em 4×; arte que entra precisa de mipmap ligado no `.import` e escala perto de 1,0–1,5×.

### Dirigindo o Godot

Duas vias, mesmo servidor:

```bash
node /Users/lucasdoro/Games/.godot-mcp-pro/server/build/cli.js --help
```

- **Tools MCP** (`.mcp.json` na raiz) — via preferida, aparece após reiniciar a sessão do Claude Code.
- **CLI** — mesma capacidade, funciona sem reiniciar sessão e gasta menos contexto. Grupos:
  `project, scene, node, script, editor, input, runtime`. Sempre `--help` antes de chutar flag.

```bash
CLI=/Users/lucasdoro/Games/.godot-mcp-pro/server/build/cli.js
node $CLI project info            # confere em QUAL projeto está conectado
node $CLI scene tree
node $CLI editor errors
node $CLI editor editor-screenshot
node $CLI scene play              # runtime tools só funcionam depois disto
node $CLI editor screenshot
```

⚠️ **Sempre rodar `project info` primeiro** e confirmar `project_name = "Floresta dos Bichinhos
Perdidos"`. O addon varre as portas 6505–6514 e **todo editor Godot aberto na máquina** se conecta ao
mesmo servidor — quem conecta por último ganha. Se houver outro projeto aberto (ex.: `pop-it`),
fechar antes, senão o comando pode cair no projeto errado.

### Armadilhas do MCP

- **Nunca editar `project.godot` direto** com o editor aberto — usar `project set-setting`. O Godot
  reescreve o arquivo ao sair.
- `execute_game_script` roda em nó temporário: sem `func` aninhado, usar `.get("prop")`.
- Propriedade aceita string: `"Vector2(100, 200)"`, `"Color(1, 0, 0, 1)"`.
- Depois de `create_script`, se não pegar, `editor reload`.
- Tool de runtime sem `scene play` antes **sempre** falha.

---

## Regras permanentes de código

- **Não repetir código** — comum vira cena/script compartilhado (`core/`, `archetypes/`).
- **Poucos comentários**, só onde o código não se explica. **Código em inglês, comentários em pt-BR.**
- **Menos código possível, mais simples possível** — sem abstração inventada. Nativo primeiro:
  `AnimationPlayer`, `Tween`, `NinePatchRect`, `GPUParticles2D`, `Control` com âncoras, `tr()`.
  Script custom só quando não há equivalente nativo.
- **Pós-processamento pega TODAS as telas.** Tela ou overlay novo renderiza *dentro* do
  `CanvasLayer` de post, nunca fora.
- **Nada de gameplay pendurado no fundo.** Fundo escala por conta própria; UI ancora em `Control`.
- Commits sem coautor, sem `Co-Authored-By`, sem "Generated with".

---

## Decisões de engine (fechadas)

| Item | Valor |
|---|---|
| Versão | Godot 4.7.2-stable — fixa; upgrade só entre marcos |
| Linguagem | GDScript |
| Renderer | Mobile (Vulkan); Compatibility como perfil de fallback |
| Resolução base | 1920×1080, stretch `canvas_items`, aspect `expand` |
| Orientação | Landscape travada |
| Alvos | Android (tablet) + macOS |

`expand` mostra **mais cena** em 4:3 em vez de encolher tudo. Consequência: testar 4:3 desde cedo, e
toda UI em `Control` ancorado.

---

## Arquitetura alvo

```
res://
  autoload/     Progression, Settings, Audio, Voice
  core/         LevelBase, LevelHeader, VictoryModal, SpeechBubble, PauseMenu, CurvedLabel
  archetypes/   DragDropLevel, PaintLevel, SequenceLevel, AssembleLevel, MemoryLevel,
                PathLevel, ActionLevel, PickRightLevel, GuideLevel
  levels/world1/  level_01.tscn ... level_10.tscn  (cena + .tres de config)
  characters/   didia, lali, lolo, sophy
  ui/           menu, world_map, settings, credits, quit_confirm, parental_gate
  backgrounds/  uma cena por fundo
  shaders/      bloom, water, foliage, mask
  assets/       art/ audio/ fonts/ i18n/
```

**`LevelBase` carrega o que toda fase repete**: fundo, header com estrelas, contador, botão voltar,
`VictoryModal`, regra de estrela, `Progression.report_level_result`, transição de saída. A fase
concreta só implementa `_setup()` e chama `mistake()` / `win()`.

**Fundos não usam vídeo.** Os 10 MP4 da versão Flutter viram cena: still (frame 0, já existe como
asset) em `Sprite2D` + shader de distorção + `Parallax2D`. Três shaders cobrem os 10 fundos:
`water` (fases 2 e 9), `foliage` (1, 4, 6, 8, mapa, menu), `night` (10).

**Bloom é shader de canvas próprio**, não `WorldEnvironment` (o `glow` 2D exige HDR 2D e diverge
entre renderers). Traduzir `../floresta-dos-bichinhos-old/shaders/bloom.frag` (disco de Vogel,
threshold/knee da URP) para `.gdshader`. Ordem do passe, fundida: Bloom → Vignette → ColorAdjustments.
Dropdown de Qualidade liga no nº de taps (0 = off, 1 = 10 taps, 2 = 16).

---

## Sistemas transversais

| Sistema | Plano |
|---|---|
| Progressão | Autoload `Progression`. Fase N abre quando N−1 tem estrela; 4×10; máx. 3 estrelas. JSON `user://progress.json`, formato `{version, worlds:[{levelStars}]}` |
| Estrelas | `.tres` por fase (`mistakes_per_star`). Hoje: 1 nas fases 1/6/7, 2 na 2/3, 3 na 4, 5 na 5, fase 10 sem erro |
| Ajustes | Autoload `Settings` (volume música/SFX, qualidade, idioma), `ConfigFile` em `user://` |
| i18n | CSV pt-BR/it → `.translation`, `tr()` nativo, troca em runtime |
| Áudio | Buses `Master > Music / SFX / Voice`. Música em autoload — nunca recomeça na troca de cena. Fade-in na entrada |
| Voz | Autoload `Voice`: `voice/<personagem>/<locale>/<chave>.ogg`, sincronizado com a digitação do balão |
| Splash | Reescrever `doma_splash` como cena Godot, portátil (logo é vetor gerado por script) |

---

## Pipeline de assets

Fonte: `../floresta-dos-bichinhos-old/assets/` — 467 WebP, 95 WAV + 1 MP3, 1 TTF (Baloo2), i18n pt-BR/it.
Árvore: `Art/{Characters,Environments,MiniGames,UI}`, `Audio/{Music,SFX,UI,Voice/<nome>/<locale>}`,
`Fonts`, `Localization`, `Resources/{PuzzleImages,PuzzleMasks}`, `Video` (não portar — ver fundos).

**Texturas** — o padrão do Godot (`Lossless`) é RGBA8888, não economiza VRAM. Compressão é opt-in,
por pasta:

| Pasta | Compressão |
|---|---|
| `art/backgrounds`, `art/characters` | `VRAM Compressed` (ASTC 4×4) |
| `art/ui`, ícones, texto | `Lossless` (artefato de bloco aparece em peça pequena) |
| `art/particles` | `VRAM Compressed` |

`size_limit` no alvo de **1,5× de oversample**. Validar artefato em arte com alpha suave (borda de
personagem veio de chroma key) antes de fechar o preset — se ASTC borrar, cair pra `Lossless`.

**Áudio**: SFX curto continua WAV (latência zero); voz e música viram OGG Vorbis. Os 95 WAV de voz TTS
já gravados são reaproveitados como estão.

**Fonte**: Baloo2 TTF importa direto. Contorno/sombra viram `font_outline_size`/`font_outline_color`
no `Label` — acaba o pré-bake de charset e a armadilha do atlas SDF.

**Atlas**: fora de escopo inicial. Medir antes de resolver.

---

## As 10 fases do mundo 1 e os arquétipos

| # | Nome | Mecânica | Personagem | Arquétipo |
|---|---|---|---|---|
| 1 | Fruit Breakfast | arrastar frutas na cesta | Didia | Arrastar-e-soltar |
| 2 | Color Reef | pintar coral esfregando até 90% | Lali | Pintar |
| 3 | Number Trail | tocar números em ordem | Lolo | Sequência |
| 4 | Forest Puzzle | jigsaw 4×4 cortado em runtime | Sophy | Montar |
| 5 | Memory Meadow | memória, 12 cartas / 6 pares | Didia | Memória |
| 6 | Seed Maze | labirinto gerado, trilha até o alpiste | — | Traçar caminho |
| 7 | Fruit Slice | cortar frutas, desviar de bomba | Sophy | Ação/timing |
| 8 | Flower Garden | separar flores nas cestas certas | Didia | Arrastar-e-soltar (classificar) |
| 9 | Letter Bubbles | estourar a bolha da letra certa | Lali | Escolher o certo |
| 10 | Lost Animals | vaga-lume conduz 6 filhotes até a fogueira | todos | Conduzir |

**Mundos 2–4 não ganham mecânica nova** — ganham tema, arte e dificuldade. Cada arquétipo é cena
parametrizada por `Resource`. Teste de sucesso da arquitetura: **a fase 2-1 deve ser `.tscn` de
instância + `.tres` + arte. Se precisou de script novo, o arquétipo está mal desenhado.**

**Dificuldade** (o testador real é o filho do dono, que reprovou a fase 7 de primeira — "não
acertava", "rápido demais"): arquétipo de ação nasce frouxo — hitbox generosa, ≤3 alvos no ar, toque
simples resolve, punição rara. Isso é **valor padrão do `.tres`**, não lembrete.

---

## Roteiro da migração

Cada marco termina em algo rodando no aparelho. **Conforme um marco fecha, a seção dele sai daqui.**

- [ ] **M0 — Esqueleto e prova de perf** *(decide se a migração continua)*
      Projeto, autoloads, `LevelBase`, shader de bloom, um fundo animado sem vídeo, e **uma** fase
      pesada portada (`forest_puzzle`, 572 linhas no Flutter, corte em runtime — o pior caso).
      **Aceite:** 60 fps estáveis e memória de textura < 200 MB (Flutter hoje: ~586 MB). Não bateu,
      parar e reavaliar.
- [ ] **M1 — Casca do jogo** — splash, menu, mapa do mundo, 5 overlays, progressão, ajustes, i18n,
      áudio. Sai um jogo navegável com uma fase.
- [ ] **M2 — Arquétipos** — as 9 cenas, extraídas conforme as fases forem portadas, **nunca antes**.
- [ ] **M3 — Mundo 1 completo** — as 10 fases, paridade com o Flutter.
- [ ] **M4 — Publicação** — export Android (keystore) e macOS (assinatura); atualizar `LINKS` no topo
      de `../floresta-dos-bichinhos-old/site/floresta-de-bichinhos/app.js`.
- [ ] **M5+ — Mundos 2, 3 e 4** — um por vez, cada fase medida contra a regra do arquétipo.

**A versão Flutter fica viva e publicável até o M3 passar.** Nada é deletado antes da paridade.

### O que NÃO portar

Código que existe só porque Flutter não é engine: `unity_canvas.dart`, `unity_anim.dart`,
`nine_slice.dart`, `background_video.dart`, `outlined_text.dart` (menos o `CurvedText`, que vira
`_draw()` custom com `Font.draw_char`), o mixin `DragClick`, os 14 players de `game_audio.dart`.

Também fica pra trás a amarra do 1:1 com a Unity: nome de cena, ordem de fase e valor de layout
passam a valer por si.

### Riscos vivos

| Risco | Mitigação |
|---|---|
| ASTC borra borda de personagem | Preset por pasta, cai pra `Lossless` onde aparecer. Detectar no M0 |
| Fundo por shader não fica tão bonito quanto o vídeo | Fazer o do mar primeiro (fase 2, o mais visível). Não convenceu, sprite sheet a 12 fps ainda é ordens de grandeza mais barato |
| `expand` quebra composição em 4:3 | Toda UI em `Control` ancorado; testar 4:3 desde o M0 |
