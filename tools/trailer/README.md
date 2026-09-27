# Trailer automático

`trailer.tscn` joga sozinho trechos do jogo (menu, mapa, frutas, cores, memória, cortar
frutas, letras e Modo Livre) enquanto o **Movie Maker** do Godot grava. Os trechos bons
ficam marcados no log e `make_trailer.py` monta o vídeo final.

Nenhuma fase é vencida: o progresso e os recordes do jogador não mudam.

## Gerar

Com o Godot 4.7.2 e o `ffmpeg` instalados, na raiz do projeto:

```bash
godot --path . --write-movie /tmp/trailer.avi --fixed-fps 30 --quit-after 5400 \
  res://tools/trailer/trailer.tscn -- --lang=pt_BR > /tmp/trailer.log
python3 tools/trailer/make_trailer.py /tmp/trailer.log /tmp/trailer.avi trailer-pt_BR.mp4
```

- `--lang=` aceita qualquer idioma do jogo (`pt_BR`, `it`, ...): um trailer por idioma.
- O Movie Maker grava a 30 quadros por segundo fixos, sem perder quadros, com o áudio do
  jogo (vozes e música). A gravação abre uma janela do jogo; deixe ela rodar até fechar
  sozinha.
- Saída: `trailer-pt_BR.mp4` (1280×720, H.264) e `trailer-pt_BR.webp` (pôster).

## Mudar o roteiro

Cada trecho é uma função `_shot_*` em `trailer_director.gd`. Um trecho novo abre a cena
com `_open()`, marca o começo com `_begin("nome")`, joga com `_tap()`, `_drag()` ou
`_scrub()` e fecha com `_end()`. A ordem fica em `_run()`.
