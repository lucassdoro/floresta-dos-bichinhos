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

### Dirigindo o Godot — sempre pelos tools MCP

**Usar os tools MCP, nunca o `cli.js`.** O CLI do addon v1.16.0 não implementa o handshake de
autenticação (`grep -c auth cli.js` = 0) e este projeto exige token — em CLI, 100% dos comandos
falham com `-32001`. Só o servidor stdio (`build/index.js`) autentica.

**Token de conexão** — `godot_mcp_pro/require_connection_token=true` no `project.godot`. O `.mcp.json`
aponta pro arquivo (o token é regenerado a cada início do editor, nunca fixar o valor):

```
~/Library/Application Support/Godot/app_userdata/Floresta dos Bichinhos Perdidos/mcp_auth_token
```

**Por que o token existe:** o addon varre as portas 6505–6514 e *todo* editor Godot aberto na máquina
se conecta ao mesmo servidor MCP; quem conecta por último ganha. Sem token, um comando podia ser
executado dentro de outro projeto sem aviso — medido em 26/08/2026: **4 de 6 comandos caíam no
`pop-it`**. Com token, o projeto errado **recusa** em vez de executar.

⚠️ **Com dois editores abertos dá pra trabalhar, mas com repetição.** Os dois disputam a conexão e o
autenticado é derrubado quando o outro entra. Medido com `pop-it` e floresta abertos juntos:
**4 de 10 chamadas passam, 6 voltam `-32001`, 0 executam no projeto errado**.
**Regra: tool que voltar `-32001` é só repetir** — a recusa é a trava funcionando, não erro de
verdade. Fechar o outro editor elimina a repetição, não o risco (o risco já está coberto pelo token).
O `pop-it` também está com token ligado e documentado no `CLAUDE.md` dele.

Fluxo padrão: `get_project_info` → `get_scene_tree` → construir → `save_scene` →
`get_editor_screenshot` → `play_scene` + `get_game_screenshot` para validar em execução.

### Armadilhas do MCP

- **NUNCA rodar o Godot em modo editor com o editor aberto** — `--import`, `-e`, ou
  qualquer coisa que carregue o plugin num segundo processo. O
  `_prepare_auth_token()` do addon (`websocket_server.gd:249`) **apaga e regrava**
  `user://mcp_auth_token` toda vez que um servidor inicia. O editor aberto continua
  esperando o token que ele gerou no start, o servidor MCP lê o arquivo novo, e
  **100% das chamadas passam a voltar `-32001`** — sem conserto a não ser reiniciar o
  editor. Medido em 26/08/2026: editor iniciado 05:48, um `--headless --import`
  às 07:05 derrubou a sessão inteira. Reimportar é pelo editor (foco na janela ou
  `reload_project`). Rodar **cena ou script headless** (modo jogo) é seguro: os
  autoloads `MCP*` não tocam no token.
- **Recusa `-32001` intermitente é disputa; recusa 100% é token estragado.** Antes de
  repetir sem fim, conferir o mtime do `mcp_auth_token` contra o horário de início do
  editor (`ps -p <pid> -o lstart=`). Token mais novo que o editor = reiniciar o editor.
- **Editor em background derruba o cliente MCP** no macOS: o que responde é o editor
  em foco. Conferir com
  `lsof -nP -a -p <pid> -iTCP | grep 650` — sem socket, o editor está dormindo.

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

**Fundos são vídeo com fallback.** Cada cena de `backgrounds/` tem `Still` (frame 0 + shader
`water`/`foliage`) e `Video` (`VideoStreamPlayer`, Ogg Theora em `assets/video/`). O script
`background.gd` (`SceneBackground`) toca vídeo em `Settings.quality >= 1` e fica no still + shader em
`quality == 0`. No primeiro boot, `core/video_benchmark.gd` mede o fps tocando o vídeo do menu durante
o splash e grava `quality = 0` se ficar abaixo de 80% de min(taxa do monitor, 60), ou seja 48 fps (nunca repete; apagar
`user://settings.cfg` reinicia). Encoder: `ffmpeg2theora` (o ffmpeg do Homebrew não encoda Theora).
Fase 6 não tem vídeo (só still). Spec: `docs/superpowers/specs/2026-09-06-fundos-em-video-design.md`.
Teste das regras puras: `tools/tests/test_video_rules.tscn` via `run_headless_scene` (em modo
`--script` os autoloads não existem, então teste que toca script com `Settings` roda como cena).

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
| Splash | Cópia da `packages/doma_splash` do stackit (`ui/splash/`): halos em `SubViewport` a meia resolução + gaussiana separável (`shaders/neon_blur`), núcleo direto, reflexo espelha a tela (`shaders/neon_reflection`). Referência: `flutter test tools/splash_render_check.dart` no stackit gera PNGs; comparar com o post desligado |

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

- [x] **M0 — Esqueleto e prova de perf** — *fechado em 28/08/2026.* Autoloads, `LevelBase`, bloom,
      fundos sem vídeo, e a fase pesada (`forest_puzzle`) portada — o "corte em runtime" virou
      **shader por peça** (máscara jigsaw + região da foto em UV), custo ~zero. Memória de textura
      do menu: 127 MB. **Fps em aparelho ainda não medido** (limitação do jogo embutido sem foco);
      medir no tablet antes do M4.
- [x] **M1 — Casca do jogo** — *fechado em 28/08/2026.* Splash, menu, os 5 painéis, ajustes,
      i18n pt-BR/it, áudio, **mapa do mundo de verdade** (marcadores com estrelas/trava, estrela
      do jogador, revelação animada de desbloqueio) e progressão em `user://progress.json`.
- [ ] **M2 — Arquétipos** — as 9 cenas, extraídas conforme os mundos 2+ forem montados, **nunca
      antes**. As mecânicas já vivem em cenas/scripts compartilháveis (`core/` + `levels/world1/`).
- [x] **M3 — Mundo 1 completo** — *fechado em 28/08/2026.* As 10 fases portadas e validadas em
      play por script (fluxo completo: jogar → vitória → estrelas → progressão → mapa). Fase 10
      trazida da branch `feature/phase-10-plan-3b246a` do projeto Flutter (código, assets, vozes,
      strings `level110` no `ui.csv`). **Falta QA humano** (tuning de toque real, 4:3, tablet) e
      as pendências visuais pequenas: contorno curvado da fita do mapa, pérola como ícone do
      contador da fase 9 (hoje usa a bolha), showcase da fase 4 conferido a olho.
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
| Theora em CPU engasga no tablet | Benchmark do primeiro boot cai pra still + shader. Medir no tablet do testador antes do M4 |
| `expand` quebra composição em 4:3 | Toda UI em `Control` ancorado; testar 4:3 desde o M0 |
