# Fundos em vídeo com fallback para still + shader

Data: 2026-09-06. Projeto: Floresta dos Bichinhos Perdidos, Godot 4.7.2-stable.

## Objetivo

Trazer de volta os fundos em vídeo da versão Flutter em todas as telas (menu, mapa, 10 fases)
para ter mais movimento. O fundo atual (still + shader de distorção) vira **fallback**, usado em
dois casos:

1. o ajuste de qualidade está em **Baixo** (`Settings.quality == 0`);
2. o aparelho reprovou no **benchmark do primeiro boot**, que então grava `quality = 0`.

Fora disso (Médio ou Alto) o fundo toca vídeo.

## Decisões fechadas

| Item | Decisão |
|---|---|
| Formato | Ogg Theora nativo (`VideoStreamPlayer`), sem GDExtension |
| Quem toca vídeo | `quality` 1 e 2. `quality` 0 usa still + shader |
| Benchmark | Roda uma vez, no splash do primeiro boot. Reprovou: `quality = 0`. Nunca repete |
| Fase 9 | Ganha `level19_background.tscn` próprio (vídeo `Level19Background`), deixa de reusar o da fase 2 |
| Fases 6 e 10 | Seguem com `menu_background`; véus de noite da fase 10 ficam por cima, inalterados |
| Loop | Simples (`loop = true`). Os vídeos já fecham o loop na origem (boomerang) |

## Restrições de engine

- Godot 4.7 só decodifica **Ogg Theora** nativamente, em CPU, sem aceleração. MP4/H.264 exigiria
  GDExtension FFmpeg com binário por plataforma. Descartado.
- `VideoStreamPlayer` é `Control`: cobre o viewport por conta própria com `expand = true` e tamanho
  calculado (mesma conta de `cover` do still).
- Fundo continua **fora** da hierarquia de gameplay (regra do projeto): nada ancora nele.
- Post-processamento pega todas as telas; o vídeo renderiza dentro do fluxo normal, o bloom segue
  por cima.

## Arquitetura

### 1. Cena de fundo (`backgrounds/*.tscn`)

Estrutura de cada cena (10 cenas: `menu`, `worldmap`, `level11`..`level15`, `level17`, `level18`,
`level19`):

```
<Nome>Background (Node2D, script background.gd)
  Still (Sprite2D, textura PNG + ShaderMaterial water/foliage)   ← já existe
  Video (VideoStreamPlayer)                                       ← novo
```

Propriedades do `Video`, setadas no inspector: `stream` (o `.ogv` da tela), `expand = true`,
`loop = true`, `autoplay = false`, `volume_db = -80`, `bus = "Music"`, `mouse_filter = IGNORE`.

`menu_background.gd` é renomeado para `backgrounds/background.gd` e compartilhado pelas 10 cenas.
Responsabilidades:

- **Cobrir o viewport** nos dois nós. Reusa a conta atual (`cover = max(vw/tw, vh/th)`): o `Still`
  via `scale`/`position`; o `Video` via `size`/`position` com o tamanho do stream. O tamanho do vídeo
  vem de `Video.get_video_texture().get_size()` depois do primeiro frame; antes disso o `Video`
  fica invisível, então não importa.
- **Escolher o modo** por `Settings.quality` no `_ready()` e em `Settings.changed("quality")`:
  - `quality >= 1`: `Video.play()`, `Still` continua visível por baixo até o vídeo entregar o
    primeiro frame (`Video.stream_position > 0` ou textura com tamanho não nulo, conferido em
    `_process`); então `Video.visible = true` com fade de alpha (Tween, `EASE_OUT`, 0,3 s) e o
    shader do `Still` é desligado (`Still.material` guardado numa variável, `Still.material = null`).
  - `quality == 0`: `Video.stop()`, `Video.visible = false`, `Still.material` restaurado.
  - Troca em runtime segue o mesmo caminho, com o fade. Nada de teleporte de imagem.
- **Nunca decodificar à toa**: em `quality == 0` o `VideoStreamPlayer` está parado, custo zero.

`_process` só fica ligado enquanto espera o primeiro frame (`set_process(false)` ao entregar).

### 2. Assets (`assets/video/`)

Os 10 MP4 de `../floresta-dos-bichinhos-old/assets/Video/` reencodados com ffmpeg para Theora:

```bash
ffmpeg -i <in>.mp4 -an -vf "scale='min(1280,iw)':-2" -r 24 -c:v libtheora -q:v 7 <out>.ogv
```

- Sem trilha de áudio (`-an`).
- Maior lado ≤ 1280 (menu e mapa são maiores na origem e descem para 1280).
- 24 fps, qualidade 7 (escala 0–10). Alvo: ≤ 35 MB no total. Se passar, baixar para `-q:v 6`.
- Nomes: `menu.ogv`, `worldmap.ogv`, `level11.ogv` … `level19.ogv` (mesma chave do still).
- O still PNG de cada tela continua sendo o frame 0; nada muda nos `.import` de textura.

Conferir cada `.ogv` a olho no editor (Godot toca no inspector) antes de ligar na cena: borda
de chroma key e gradiente de céu são onde Theora pode aparecer bloco.

### 3. Benchmark do primeiro boot (`core/video_benchmark.gd`)

`Settings` ganha `benchmarked := false`, persistido como as outras chaves.

O splash (`ui/splash/doma_splash.gd`) chama o benchmark no `_ready()` quando
`Settings.benchmarked == false`. O benchmark é um `Node` filho do splash, `visible = false`:

1. Cria um `VideoStreamPlayer` com `assets/video/menu.ogv`, `volume_db = -80`, `visible = false`,
   `play()`.
2. Espera o primeiro frame (mesma condição da cena de fundo). Timeout de 3 s sem frame conta como
   reprovação (decode não acompanha nem o start).
3. Mede por 2 s: soma de `get_process_delta_time()` por frame, média de fps.
4. Regra: `fps_medio < 0.8 * DisplayServer.screen_get_refresh_rate()` (48 em 60 Hz) reprova.
   Se a taxa do monitor vier inválida (`-1`), assume 60.
5. Reprovou: `Settings.set_value("quality", 0)`. Aprovou: não mexe (padrão atual, 2).
6. `Settings.set_value("benchmarked", true)`, `queue_free()`.

O benchmark roda em paralelo com a animação do logo (3,7 s). Caso típico: ~0,2 s até o primeiro
frame + 2 s de medição, cabe dentro da animação. Pior caso (timeout de 3 s + 2 s = 5 s) passa da
animação: nesse caso o splash segura a troca de cena até o benchmark terminar, para que o menu
já nasça no modo certo. Implementação: `_on_finished` faz `await` num sinal `done` do benchmark
quando ele ainda não acabou.

Depois do primeiro boot, o ajuste de qualidade no painel é a única fonte de verdade; o benchmark
não roda de novo. Apagar `user://settings.cfg` reinicia tudo (útil no QA).

### 4. Fase 9

Nova `backgrounds/level19_background.tscn`, cópia da `level12_background` com o still
`Level19Background.png` (já importado) e `level19.ogv`. `levels/world1/level_09.tscn` passa a
instanciar essa cena no lugar da `level12_background`.

## O que NÃO entra

- Nenhum vídeo novo para fases 6 e 10 (não existem na referência).
- Nenhum controle de "reexecutar benchmark" na UI.
- Nenhuma mudança nos shaders `water`/`foliage`, nem no post.
- Nenhum atlas, sprite sheet ou parallax como alternativa: vídeo ou still, só isso.

## Riscos

| Risco | Mitigação |
|---|---|
| Theora em CPU engasga no tablet alvo | É exatamente o caso do benchmark: reprova, cai pra shader. Validar limiar no tablet do testador |
| Splash mede errado por causa da animação do logo | O logo é `_draw` leve; benchmark só compara contra 80% da taxa, tem folga. Se reprovar aparelho bom, subir a janela de medição ou baixar para 70% |
| Theora borra gradiente/borda | Conferir cada `.ogv` no editor; subir `-q:v` no vídeo que precisar |
| Tamanho do APK sobe ~35 MB | Aceito. O Flutter já embarcava 29 MB de MP4 mais os stills |
| Fundo de vídeo e post-processamento | Vídeo renderiza no fluxo normal, dentro do `CanvasLayer` de post como qualquer outro nó |

## Testes

Tudo em play pelo MCP, com screenshot:

1. Menu com `quality` forçado 0, 1 e 2 via `execute_game_script` (`Settings.set_value`): em 0 o
   `Video` está parado e invisível e o `Still` tem material; em 1/2 o `Video` está visível e
   `stream_position` avança, `Still.material == null`.
2. Troca ao vivo pelo painel de ajustes no menu: fade, sem pulo, sem frame preto.
3. Uma fase de cada fundo (1, 2, 3, 4, 5, 7, 8, 9, 6 e 10 com o do menu) em `quality = 2`:
   vídeo cobre o viewport em 16:9 e em 4:3 (janela redimensionada).
4. Benchmark forçado a reprovar (limiar temporariamente em 1000 fps) com `settings.cfg` apagado:
   ao chegar no menu, `Settings.quality == 0` e `benchmarked == true` gravados no arquivo.
5. Benchmark normal com `settings.cfg` apagado: `quality` segue 2.
6. Fps de verdade só no tablet (M4). Anotar o resultado do benchmark no aparelho do testador.
