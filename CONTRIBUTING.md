# Contribuindo com a Floresta dos Bichinhos

Obrigado por querer ajudar! Este guia explica como propor e entregar mudanças. Ao
participar, você concorda com o [Código de Conduta](CODE_OF_CONDUCT.md).

## Aberto, mas com curadoria

O código é aberto e qualquer pessoa pode propor mudanças — mas **o jogo é feito para
crianças pequenas, e tudo o que entra passa por análise de quem mantém o projeto**:
fases, arte, áudio, vozes, textos, traduções e código. Ser open source não significa que
toda proposta será aceita.

A análise olha principalmente para:

- **Adequação à idade (3 a 7 anos):** nada de violência, sustos, medo, linguagem
  inadequada ou temas sensíveis; mensagens gentis e positivas.
- **Valor educativo:** a fase trabalha uma habilidade clara (cores, números, letras,
  memória, coordenação...).
- **Jogabilidade para quem está aprendendo:** toque simples resolve, alvos grandes, poucos
  elementos na tela, erro sem punição pesada, nada de pressa excessiva.
- **Segurança da criança:** nenhum anúncio, link externo, compra, coleta de dados, chat ou
  conexão com a internet.
- **Qualidade e consistência:** arte, som e animação no mesmo nível e estilo do jogo;
  textos revisados e traduzidos para todos os idiomas do jogo.

O mantenedor pode pedir ajustes ou recusar uma proposta, sempre explicando o motivo na
issue. Por isso a conversa acontece **na issue, antes do código** — assim ninguém investe
tempo em algo que não vai entrar.

## Regra de ouro: toda mudança começa por uma issue

Nada é feito sem uma issue — nem correção pequena, nem fase nova, nem ajuste de texto.

1. **Procure** nas [issues](https://github.com/lucassdoro/floresta-dos-bichinhos/issues) se o
   assunto já existe.
2. **Abra uma issue** com o modelo certo (*Bug*, *Ideia/melhoria* ou *Proposta de fase*) se
   ainda não existir.
3. **Espere a aprovação** de quem mantém o projeto na issue (label `aprovada`) e comente
   que vai trabalhar nela — assim ninguém faz o mesmo trabalho em dobro nem gasta tempo em
   algo que não vai entrar.
4. **Abra o pull request citando a issue** no texto: `Closes #123`. PR sem issue ligada é
   reprovado automaticamente pela verificação *Issue ligada*.

## Contribuindo sem programar

Você não precisa saber programar para ajudar — e muita coisa importante no jogo não é
código. Tudo abaixo se faz **pelo site do GitHub**, sem instalar nada: basta uma conta
gratuita e abrir uma issue com o modelo certo. Arquivos (imagens, áudios, planilhas) podem
ser arrastados para dentro da issue; quem mantém o projeto cuida de colocar no jogo.

A curadoria vale aqui também: todo material passa por análise antes de entrar.

### 🧒 Testar com crianças (pais, mães, professores)

É a ajuda mais valiosa. Deixe a criança jogar e observe: onde ela travou, o que achou
difícil ou chato, o que a fez rir, onde pediu ajuda, se entendeu o que a personagem pediu.
Conte no modelo **Relato de teste com criança**.

> **Privacidade da criança:** não informe nome, escola ou cidade e **não envie fotos,
> vídeos ou áudios em que ela apareça ou seja ouvida**. Idade aproximada e o que você
> observou já bastam. Prints da tela do jogo são bem-vindos.

### 🍎 Olhar pedagógico (educadores)

Revise se as fases trabalham bem a habilidade proposta, se a linguagem combina com a faixa
de idade e sugira fases novas com o modelo **Proposta de fase**.

### 🎨 Arte e animação · 🎵 Música e efeitos · 🎙️ Vozes · 🌍 Tradução

Use o modelo **Conteúdo (arte, som, voz, tradução)**. Antes de produzir algo grande,
abra a issue e espere a label `aprovada` — assim o material já nasce no estilo e no
formato do jogo.

- **Arte:** siga o estilo das telas atuais (cartoon, cores vivas, contorno suave). Envie
  PNG ou WebP com fundo transparente, no maior tamanho que tiver.
- **Música e efeitos:** WAV ou OGG, sem trechos de músicas de terceiros.
- **Vozes:** gravadas por adultos, em ambiente silencioso, em WAV ou OGG. O texto de cada
  fala está em `assets/i18n/ui.csv`.
- **Tradução:** os idiomas do jogo são as colunas de `assets/i18n/ui.csv` (hoje português
  e italiano). Para revisar um idioma ou propor um novo, pegue as frases desse arquivo e
  mande a tradução em uma planilha anexada à issue — não precisa editar o arquivo.

Todo material precisa ser **seu** (ou ter licença CC0 ou CC BY) e entra no jogo sob a
[CC BY-NC-SA 4.0](LICENSE-ASSETS.md). Diga na issue como quer ser creditado.

### 🐛 Relatar problemas e dar ideias

Achou algo quebrado? Modelo **Bug**, com print se puder. Tem uma ideia? **Ideia ou
melhoria** ou **Proposta de fase**.

### 📣 Divulgar

Mostre o jogo para escolas, grupos de pais e outros educadores, e deixe uma ⭐ no
repositório — isso ajuda o projeto a encontrar mais gente para contribuir.

## Preparando o ambiente

- **Godot 4.7.2-stable** (versão padrão, sem .NET). Outras versões podem alterar arquivos
  de cena sem necessidade.
- Faça um fork, clone e abra o `project.godot` no Godot. A primeira importação demora.

## Fluxo de trabalho

1. Crie uma branch a partir da `main` atualizada, com o número da issue no nome:
   - `fix/123-balao-cortado`
   - `feature/123-fase-das-formas`
   - `docs/123-guia-de-traducao`
2. Um pull request por issue. Mudanças não relacionadas vão em outra issue e outro PR.
3. Commits em português, curtos, no padrão `tipo: descrição` — `feat`, `fix`, `refactor`,
   `docs`, `test`, `chore`. Ex.: `fix: balao da fase 7 corta o texto (#123)`.
4. Rode os testes antes de abrir o PR (veja abaixo).
5. Mudança visual? Coloque print ou vídeo curto no PR, em 16:9 e em 4:3.

## Regras de código

- **GDScript**, com tipagem. Código (nomes, identificadores) em **inglês**; comentários em
  **português**, poucos, só onde o código não se explica.
- Nomes descritivos; prefira *return early* a `if/else` aninhado.
- Não repita código: o que é comum vira cena ou script compartilhado em `core/`.
- Nativo primeiro: `Tween`, `AnimationPlayer`, `NinePatchRect`, `GPUParticles2D`, `Control`
  com âncoras, `tr()`. Script próprio só quando não existe equivalente.
- Prefira ajustar valores no **inspector** (ficam visíveis para quem mexe na cena) a
  fixá-los em código.
- **Animação sempre suave**: `Tween` com easing, nunca linear em personagem ou UI, nada de
  teleporte.
- **UI em `Control` ancorado** — o jogo usa `stretch canvas_items` + `expand`, e em 4:3 a tela
  mostra mais cena. Teste nas duas proporções.
- Troca de cena só por `SceneLoader.go_to(path)`.
- Todo texto visível passa por `tr()` com chave em `assets/i18n/ui.csv`.

## Textos e idiomas

O jogo terá cada vez mais idiomas, e **nenhum texto entra pela metade**: toda proposta com
texto novo — fase, tela, fala de personagem, mensagem — vem com a tradução para **todos os
idiomas disponíveis no momento**, ou seja, todas as colunas de `assets/i18n/ui.csv`
preenchidas.

- Não fala algum dos idiomas? Diga isso na issue e peça ajuda — alguém da comunidade
  traduz antes do merge. Tradução automática só como rascunho, revisada por quem fala o
  idioma.
- Falas com voz gravada precisam do áudio em todos os idiomas também (ou de uma issue
  aberta pedindo a gravação).
- O teste `test_translations` reprova qualquer chave com coluna vazia, e ele roda em todo
  pull request.

## Criando uma fase

Veja [docs/MODDING.md](docs/MODDING.md). Resumo: pasta própria em `levels/`, cena que estende
`LevelBase` e ficha `LevelInfo` (`.level.tres`). Abra antes uma issue *Proposta de fase*
contando a mecânica, a habilidade que ela trabalha e a faixa de idade.

O público são crianças de 3 a 7 anos: toque simples resolve, alvos grandes, poucos
elementos na tela, punição rara.

## Arte, áudio e vozes

- Só envie material **seu** ou com licença compatível: **CC0**, **CC BY** ou obra sua
  licenciada em **CC BY-NC-SA 4.0**. Informe a origem no PR.
- Imagens em **WebP**; no `.import`, mipmaps ligados. UI e texto em compressão *Lossless*.
- Música e vozes em **OGG Vorbis**; efeitos curtos em **WAV**.

## Testes

```bash
godot --headless --path . res://tools/tests/test_free_mode.tscn
godot --headless --path . res://tools/tests/test_video_rules.tscn
godot --headless --path . res://tools/tests/test_translations.tscn
```

Cada teste imprime `PASS`/`FAIL` e termina com `FAILURES: 0` quando tudo passa. Regras
novas ganham teste em `tools/tests/`.

## Usando assistentes de IA

O `CLAUDE.md` na raiz descreve as regras do projeto para assistentes de IA. O fluxo do
mantenedor usa o addon **Godot MCP Pro**, que é pago e **não está incluído** no
repositório — ele não é necessário para contribuir. Se você também usa esse addon, configure
o filtro que tira as referências dele do `project.godot` nos commits:

```bash
git config filter.strip-mcp.clean "sed -e '/addons\/godot_mcp/d' -e '/^\[godot_mcp_pro\]/d' -e '/^require_connection_token/d' | cat -s"
git config filter.strip-mcp.smudge cat
```

## Licença das contribuições

Ao contribuir, você concorda que seu código é licenciado sob a [GPL-3.0](LICENSE) e que
arte, áudio e textos são licenciados sob a [CC BY-NC-SA 4.0](LICENSE-ASSETS.md), as mesmas
licenças do projeto.
