# Menu principal em Godot — design

Data: 2026-08-26 · Godot 4.7.2-stable · Migração vinda do Flutter/Flame

Portar o menu principal do jogo para Godot com paridade funcional com a versão
Flutter: os cinco botões, os cinco painéis, música, efeitos sonoros, partículas,
animações e pós-processamento. Referência viva: `../floresta-dos-bichinhos-old`.

Esta é a primeira tela real do projeto Godot, então ela arrasta as fundações que
todas as telas seguintes vão usar (autoloads, i18n, tema, pós-processamento). O
roteiro do `CLAUDE.md` põe o M0 (prova de perf com a fase mais pesada) antes do
M1; o menu cobre boa parte do M0 — shader de bloom, fundo animado sem vídeo,
arte com alpha em ASTC — mas não substitui a fase pesada. Os números de fps e
memória de textura são medidos aqui como leitura parcial.

## Decisões fechadas

| Assunto | Decisão |
|---|---|
| Layout | `Control` com âncoras nativas. Os números do Flutter (que replicavam o canvas 1920×1080 `match 0.5` da Unity) valem como proporção, não como coordenada absoluta |
| Fundo | Still `MenuBackground.png` + shader de folhagem. Sem vídeo, sem sprite sheet |
| Painéis | Cada painel é uma cena `Control` própria, instanciada sob um `CanvasLayer` de overlays do menu |
| Modo História | Abre `world_select`; a carta do Mundo 1 leva a um `world_map.tscn` stub |
| Pós-processamento | Autoload global desde já |
| Splash | Splash da DOMA reescrita em Godot, cena principal do projeto |
| Portão parental | Entra, aberto por um chip no rodapé dos créditos |
| Modo Livre | Botão presente, com som e brilho, sem navegação — igual ao Flutter |
| Destino do portão | `site_url` exportada no inspector, vazia por padrão. O chip dos créditos só aparece quando preenchida |

## Arquitetura de arquivos

```
autoload/
  settings.gd          Settings  — ConfigFile em user://settings.cfg
  audio.gd             Audio     — música persistente, SFX de UI
  post.tscn / post.gd  Post      — CanvasLayer de pós-processamento
core/
  juicy_button.tscn/gd   botão com hover/press
  sparkle_burst.tscn     explosão de brilhos parametrizada
  panel_base.tscn/gd     pop-in + botão voltar + sinal closed
backgrounds/
  menu_background.tscn   still + shader de folhagem
ui/
  theme.tres
  splash/doma_splash.tscn/gd
  menu/main_menu.tscn/gd
  menu/panels/world_select.tscn/gd
  menu/panels/settings_panel.tscn/gd
  menu/panels/credits.tscn/gd
  menu/panels/quit_confirm.tscn/gd
  menu/panels/parental_gate.tscn/gd
  world_map/world_map.tscn/gd    (stub)
shaders/
  post.gdshader       bloom + vinheta + color grading, um passe
  foliage.gdshader    distorção senoidal com máscara de altura
assets/i18n/
  ui.csv → ui.pt_BR.translation, ui.it.translation
```

## Fundações

### Autoload `Settings`

`ConfigFile` em `user://settings.cfg`, seção `settings`:

| Chave | Tipo | Padrão |
|---|---|---|
| `music_volume` | float 0–1 | 1.0 |
| `sfx_volume` | float 0–1 | 1.0 |
| `quality` | int 0/1/2 | 2 |
| `locale` | string | `pt_BR` |

Emite `changed(key)`. No `_ready` carrega o arquivo, aplica
`TranslationServer.set_locale` e publica a qualidade no `Post`. Grava a cada
mudança (arquivo minúsculo, sem debounce).

### Autoload `Audio`

Buses em `default_bus_layout.tres`: `Master > Music / SFX / Voice`. O volume de
`Settings` vira dB no bus com `linear_to_db`, uma vez — nenhum player multiplica
volume por conta própria. Volume 0 desliga o bus (`set_bus_mute`) para não cair
em `-inf` errado.

- Música: `AudioStreamPlayer` no autoload com `menu_music.mp3` em loop, volume
  base equivalente a 0.25 linear. Nunca reinicia na troca de cena.
- `start_music_fade()`: `Tween` de 3 s subindo o volume do bus `Music` do
  silêncio até o valor de `Settings`. Idempotente — chamar de novo não
  reinicia nem empilha.
- `play_click()`: `ui_click.wav` no bus `SFX`, com guarda de 60 ms entre
  disparos (dois cliques mais juntos que isso são o mesmo toque chegando por
  dois caminhos).
- `play_locked()`: `ui_locked.wav` a 0.9 do volume de SFX.
- `play_voice(path)` fica declarado e sem uso no menu (o bus `Voice` já existe
  para as fases).

### i18n

A tabela do `lib/strings.dart` inteira (~60 chaves pt-BR/it) vira
`assets/i18n/ui.csv` com colunas `key,pt_BR,it`, importado como `.translation`.
Portar tudo de uma vez, não só as chaves do menu: é barato e evita voltar aqui a
cada fase portada.

Chaves usadas pelo menu: `worldselect.title`, `quitmodal.question`,
`quitmodal.yes`, `quitmodal.no`, `settings.music`, `settings.sfx`,
`settings.quality`, `settings.quality.low|medium|high`, `settings.language`,
`credits.role.creation`, `credits.role.programming`, `credits.role.gamedesign`,
`credits.social.gate.title`, `credits.social.gate.instruction`,
`credits.social.gate.hold`, `credits.social.gate.back`.

Os textos dos créditos (nome e descrição de cada pessoa) também entram no CSV,
com chaves `credits.person.<slug>.name` e `credits.person.<slug>.bio` — no
Flutter eles estavam fixos em português dentro do código.

Troca de idioma em runtime: `TranslationServer.set_locale` faz o Godot emitir
`NOTIFICATION_TRANSLATION_CHANGED` e todo `Label`/`Button` com `tr()` se
reconstrói sozinho. Só bandeira e nome do idioma no `OptionButton` precisam ser
redesenhados à mão.

### Tema (`ui/theme.tres`)

Fonte Baloo2 ExtraBold. Paleta exata da cena original:

| Nome | Hex |
|---|---|
| `brown` | `#6B401C` |
| `soft_brown` | `#8C6640` |
| `cream` | `#FFF5DE` |
| `leaf_green` | `#61A84A` |
| `bar_brown` | `#B88C61` |
| `sun_yellow` | `#FFD973` |
| `pressed_tint` | `#C7C7C7` |

Variações de tipo para os tamanhos em uso (80 título, 66 pergunta do modal, 54
botão de modal, 44 rótulo de ajuste, 36 nome/dropdown, 28–30 instrução, 26 bio,
18 chip). Contorno por `font_outline_size`/`font_outline_color`, sem pré-bake de
charset. Estilos de `HSlider` (trilha 22 px verde sobre marrom, thumb amarelo
raio 28), `OptionButton` (fundo creme, borda `bar_brown` 60%, raio 10) e
`ScrollContainer`.

### Autoload `Post`

`CanvasLayer` em layer 100 com um `ColorRect` full-rect e `shaders/post.gdshader`.
Tradução do `shaders/bloom.frag` do Flutter, na ordem do UberPost da URP:

1. **Bloom** — disco de Vogel, threshold/knee da URP.
2. **Vinheta** — `fator = (1 - dot(d,d))^(smoothness*5)`, `d = |uv - centro| * intensity * 3`, com `intensity = 0.16`, `smoothness = 0.4`.
3. **ColorAdjustments** — exposure +0,05 EV, contraste +6%, saturação +10%.

Taps do disco por qualidade: `[0, 10, 16]`. Qualidade 0 vira um passe de uma
amostra só — é o que salva GPU fraca. `Settings.changed` atualiza o uniform.

Ser autoload é o ponto: toda tela nova nasce dentro do pós-processamento sem
ninguém precisar lembrar, que é a regra permanente do `CLAUDE.md`.

## A tela do menu

`ui/menu/main_menu.tscn`, raiz `Control` full-rect. Nada de gameplay pendurado no
fundo; tudo ancorado.

### Fundo (`backgrounds/menu_background.tscn`)

`Sprite2D` com `MenuBackground.png` (1744×1168, já importado como VRAM/ASTC com
mipmap), centralizado e escalado por *cover* a partir do tamanho do viewport —
`Sprite2D` não tem âncora, então isso é um script de poucas linhas ligado ao
sinal `resized` do viewport.

`shaders/foliage.gdshader`: deslocamento senoidal de UV com máscara vertical, de
modo que a folhagem de cima balance e o chão fique parado. `uniform` para
amplitude, velocidade e altura da máscara, ajustáveis no inspector.

### Logo

`TextureRect` ancorado no topo-centro e colado no topo da tela, proporção
919×427, tint `#FFE4E1`.
`AnimationPlayer` com duas animações:

- `intro` — 0,6 s. Escala `0.3 → 1.08 (0.35 s) → 1.0`; alpha `0 → 1 (0.3 s)`.
- `idle` — 2 s em loop. Escala `1.0 → 1.03 (1 s) → 1.0`.

`animation_finished` de `intro` dispara `idle`. Voltar ao menu repete a intro,
como no Flutter.

### Placa de boas-vindas

`AnimatedSprite2D` com os 53 frames já portados
(`welcome_sign_0001..0105`, ímpares). O vai-e-volta com ease sai de um
`AnimationPlayer` com track da propriedade `frame`, `loop_mode = pingpong` e
keyframes com curva de ease — a velocidade zera nas viradas, sem tranco. Ida em
~4,4 s. Ancorada à direita da tela, ~50 px da borda e ~181 px abaixo do centro
vertical, proporção 886×788. Ela cobre parcialmente a coluna de botões pela
direita, como na versão Flutter.

### Folhas caindo

`GPUParticles2D` no topo da tela, textura `leaf_01.webp`:

| Parâmetro | Valor |
|---|---|
| `amount` | 2 |
| `lifetime` | longo o bastante pra atravessar a tela |
| `randomness` | alto, pro intervalo entre folhas variar (3–7 s no Flutter) |
| velocidade de queda | 80–140 px/s |
| `angular_velocity` | 15–40°/s, sinal aleatório |
| escala | 0,6–1,0, com flip horizontal aleatório |
| sway | **turbulence** do `ParticleProcessMaterial` |
| fade-in | `alpha_curve`, ~0,5 s |

A turbulence nativa substitui o sway senoidal escrito à mão. Zero script.

### Botões

`core/juicy_button.tscn`: `TextureButton` + `core/juicy_button.gd` (~25 linhas).
Escala alvo por estado — hover 1,07, press 0,92, normal 1,0 — e tint de press
`#C7C7C7`, ambos perseguidos por interpolação exponencial no `_process`
(`1 - exp(-14 * dt)`), a mesma resposta do Flutter e sem tween reiniciando a
cada evento. `pivot_offset` no centro, senão a escala puxa pro canto.

Cinco instâncias num `VBoxContainer` centrado horizontalmente, com o centro do
grupo ~184 px abaixo do centro da tela (o logo ocupa o topo). `separation = 16`
reproduz exatamente o espaçamento do Flutter: lá os intervalos entre centros
variam (163, 140, 117, 111) só porque as alturas dos botões variam — a folga
entre eles é constante.

Ordem e proporções do Flutter:

| Botão | Proporção | Cor do brilho | Ação |
|---|---|---|---|
| História | 420×146 | `#FFD973` | abre `world_select` (esconde menu e placa) |
| Livre | 420×148 | `#EBFF9E` | nenhuma |
| Ajustes | 300×101 | `#EBC7FF` | abre `settings_panel` |
| Créditos | 300×101 | `#FFE073` | abre `credits` |
| Sair | 260×88 | `#FFA68C`, 12 partículas, tamanho máx. 60 | abre `quit_confirm` (por cima do menu) |

### Brilhos (sparkle burst)

`core/sparkle_burst.tscn`: `GPUParticles2D` one-shot com `sparkle_star.webp` e
`export` de cor, quantidade e tamanho. Padrão: 30 partículas, tamanho 26–120,
distância 100–220, vida 0,7 s, giro ±240°/s, saída em `ease-out` cúbica, escala
caindo com o quadrado do progresso. Cada clique instancia na posição do botão e
o nó se remove no sinal `finished`. O clique toca `Audio.play_click()` antes.

## Painéis

`core/panel_base.tscn` + `core/panel.gd` dão o que todo painel repete: pop-in de
0,25 s (alpha `0 → 1` em 0,18 s; escala `0.92 → 1.02 (0.14 s) → 1.0`) por
`AnimationPlayer`, botão Voltar ancorado no topo-esquerdo (`button_back.webp`
num `JuicyButton`, ~120×115) e o sinal `closed`. Fundo de painel é
`NinePatchRect` com `modal_panel.webp`, borda 96.

O menu instancia o painel pedido sob seu `CanvasLayer` "Overlays" e o remove no
`closed`. Abrir um painel esconde o grupo de botões; `world_select` esconde
também a placa; `quit_confirm` e `parental_gate` não escondem nada — abrem por
cima.

### `world_select.tscn`

Título `tr("worldselect.title")` no topo. Três cartas 400×600 num
`HBoxContainer` centralizado (`world_card_1..3.webp`).

- Carta 1: `JuicyButton` com hover 1,05 / press 0,97 → `world_map.tscn`.
- Cartas 2 e 3: travadas. `AnimationPlayer` com a tremida de 0,4 s — deslocamento
  em X `0, -14, 12, -9, 6, -3, 1.5, 0` e rotação `0, 3, -2.5, 2, -1.2, 0.6,
  -0.3, 0` graus, nos tempos `0, .05, .11, .17, .23, .29, .35, .4` — mais
  `Audio.play_locked()`.

### `settings_panel.tscn`

Painel 980×760. Quatro linhas de 100 px de altura, espaçadas 112, rótulo à
esquerda (42% da largura) e controle a partir de 45%:

| Linha | Controle |
|---|---|
| `settings.music` | `HSlider` 0–1 → `Settings.music_volume` |
| `settings.sfx` | `HSlider` 0–1 → `Settings.sfx_volume` |
| `settings.quality` | `OptionButton` Baixa/Média/Alta → `Settings.quality`, repassado aos taps do `Post` |
| `settings.language` | `OptionButton` com bandeira + nome (`flag_pt_br.webp`, `flag_it.webp`) → `TranslationServer.set_locale` |

Cada mudança grava na hora. Sem botão de confirmar.

### `credits.tscn`

Mesmo painel 980×760, com `ScrollContainer` + `VBoxContainer` (área útil
820×640). Duas entradas, criador primeiro e o resto em ordem alfabética:

1. **Lucas Dóro** — chips Criação (`#F2B840`) e Programação (`#61A84A`).
2. **João Henrique Maricato** — chip Game Design (`#EB8C40`).

Cada entrada: nome (36), linha de chips (`NinePatchRect` com `chip_pill.webp`
tingido, borda 12, altura 36, texto 18 branco), descrição (26, `soft_brown`), e
um separador de 4 px `bar_brown` a 50% entre entradas.

No rodapé, um chip "site" que abre o `parental_gate` — visível apenas se
`site_url` (propriedade exportada no inspector) estiver preenchida.

### `quit_confirm.tscn`

Escurece a tela (`ColorRect` preto, alpha `0 → 0.75` em 0,15 s) e mostra um
painel 640×380 com pop próprio (escala `0.75 → 1.06 (0.14 s) → 1.0` em 0,24 s):

- Pergunta `tr("quitmodal.question")` (66, `brown`) a +95 do centro.
- Botão Não (`modal_btn_green`, 220×110) a (−140, −75): fecha o modal.
- Botão Sim (`modal_btn_red`, 220×110) a (+140, −75): `get_tree().quit()`.

Botões de modal não crescem no hover — só recebem o tint de press.

### `parental_gate.tscn`

Painel 900×620 sobre fundo escurecido:

- Título `credits.social.gate.title` (44, `brown`) a +200.
- Instrução `credits.social.gate.instruction` (28, `soft_brown`) a +90.
- Botão de segurar (420×110) a −60: `chip_pill` cinza `#BFBFBF` com preenchimento
  verde por `TextureProgressBar` (o recorte manual do Flutter vira nativo).
  Segurar por 3 s completa e chama `OS.shell_open(site_url)`; soltar zera.
- Botão Voltar (260×90) a −215: chip `bar_brown` que fecha.

## Splash e navegação

`ui/splash/doma_splash.tscn` — reescrita em Godot da splash da produtora: logo
vetorial desenhada por script (`_draw`/`Line2D`, sem imagem), glow 0,7, sem
vinheta, Baloo2, som no bus `SFX`. É a cena principal do projeto. Ao terminar,
chama `Audio.start_music_fade()` e troca para o menu — o fade de 3 s começa
junto com o menu aparecendo, como no Flutter.

`ui/world_map/world_map.tscn` — stub: fundo, `tr("worldmap.world1.title")` e
`tr("worldmap.world1.name")`, botão Voltar para o menu. Existe para que a
transição menu → mapa → menu seja testada de verdade agora, e para ser
substituído pelo mapa real depois.

Troca de tela por `change_scene_to_file`. Música e pós-processamento sobrevivem
por serem autoload.

## Ordem de construção

1. Autoloads (`Settings`, `Audio`), bus layout, CSV de i18n, `ui/theme.tres`.
2. `Post` + `post.gdshader`, validado por screenshot com e sem, e nos três níveis
   de qualidade.
3. Fundo do menu: still + `foliage.gdshader`.
4. Menu: logo, placa, folhas, cinco botões, brilhos, som de clique.
5. Painéis, na ordem `quit_confirm` (o mais simples) → `settings_panel` →
   `world_select` → `credits` → `parental_gate`.
6. Splash da DOMA + `world_map` stub + navegação completa.
7. Medição e ajuste (seção seguinte).

Cada passo termina com a cena salva e um screenshot do editor; os passos 4 a 6
terminam com `play_scene` e screenshot em execução.

## Validação

- **Paridade visual**: screenshot em execução de cada painel, comparado com o
  Flutter rodando lado a lado.
- **Navegação**: toques sintéticos (`simulate_mouse_click`) percorrendo menu →
  cada painel → volta, e menu → mapa → menu. Confirmar que a música **não**
  recomeça na troca de cena.
- **Áudio**: clique único não dispara som dobrado; sliders mudam o volume ao
  vivo; volume 0 silencia de fato.
- **Idioma**: trocar para `it` e voltar, conferindo que todos os textos das cinco
  telas mudam sem reabrir nada.
- **Performance**: `get_performance_monitors` no menu — alvo de referência do M0,
  60 fps estáveis e memória de textura abaixo de 200 MB (o Flutter usa ~586 MB).
- **4:3**: rodar a 1440×1080 e conferir que nenhuma âncora quebra — é o risco
  conhecido do `stretch aspect = expand`.
- **ASTC**: olhar de perto a borda do logo e da placa. Se a compressão borrar o
  alpha suave, `art/UI/MainMenu` e `art/UI/WelcomeSign` caem para `Lossless`.

## Riscos

| Risco | Mitigação |
|---|---|
| Shader de folhagem não convence perto do vídeo original | Amplitude/velocidade como uniform, ajuste visual na viewport. Não convencendo, sprite sheet a 12 fps continua sendo o plano B |
| ASTC borra borda de logo/placa | Detectar na validação; cair para `Lossless` nessas duas pastas |
| `expand` desloca elementos em 4:3 | Toda UI em `Control` ancorado; teste a 1440×1080 antes de fechar |
| Turbulence de partícula não reproduz o sway das folhas | Ajustar `noise_strength`/`noise_scale`; persistindo, um `Curve` de deslocamento em X no `ParticleProcessMaterial` |

## Fora de escopo

Mapa do mundo real, progressão e estrelas, `LevelBase`, fases, vozes, atlas de
textura, export para Android e macOS.
