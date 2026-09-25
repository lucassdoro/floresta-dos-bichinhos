# Criando uma fase para o Modo Livre

O Modo Livre lista toda fase que tiver uma ficha `LevelInfo` em qualquer pasta de
`res://levels/`. Não é preciso editar nenhum arquivo central.

1. Crie a pasta `levels/<seu_nome>/<sua_fase>/`.
2. Crie a cena da fase. A raiz estende `LevelBase` (`core/level_base.gd`):
   chame `mistake()` a cada erro e `win()` ao vencer. Estrelas, modal de vitória,
   botão voltar e o save do Modo Livre vêm de graça.
3. No FileSystem do Godot: botão direito na pasta → Novo Recurso → `LevelInfo`,
   salve como `<sua_fase>.level.tres` e preencha no inspector:
   - `id`: único, ex. `seu_nome.sua_fase`
   - `title` / `description`: texto (ou chave de tradução do `assets/i18n/ui.csv`)
   - `cover`: imagem 16:9 (640×360 recomendado)
   - `skills`: Cores, Números, Letras, Memória, Coordenação (uma ou mais)
   - `mechanic`: o tipo de jogo
   - `author`: seu nome (aparece como "por <autor>")
   - `scene_path`: a cena do passo 2
4. Rode o jogo: a fase aparece no Modo Livre.

Ficha com `id` repetido ou sem cena é ignorada, com aviso no Output. Recordes do
Modo Livre ficam em `user://free_play.json` e não mexem no progresso do modo história.
