# Lançando uma versão

Os builds saem sozinhos no GitHub Actions (`.github/workflows/release.yml`): ao
publicar uma tag `vX.Y.Z`, o workflow gera

| Arquivo | Para quê |
|---|---|
| `floresta-dos-bichinhos-android.apk` | instalar direto em tablets e celulares |
| `floresta-dos-bichinhos-android.aab` | enviar para a Play Store |
| `floresta-dos-bichinhos-windows.zip` | Windows 64 bits |
| `floresta-dos-bichinhos-linux.tar.gz` | Linux 64 bits |

e cria o GitHub Release da tag com esses arquivos. Apple (macOS/iOS) ainda não entra.

Os nomes não levam a versão (ela fica no título e na tag do Release), então estes links
baixam sempre a última versão — é o que o site e o README usam:

`https://github.com/lucassdoro/floresta-dos-bichinhos/releases/latest/download/<arquivo>`

## Antes da primeira versão: keystore do Android

O Android é assinado com o keystore de release do app publicado
(`com.domastudio.florestadosbichinhos`). Ele fica só nos **Secrets** do repositório —
nunca no Git. Cadastro, uma vez, com o [GitHub CLI](https://cli.github.com):

```bash
base64 -i /caminho/do/keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64 -R lucassdoro/floresta-dos-bichinhos
gh secret set ANDROID_KEYSTORE_USER -R lucassdoro/floresta-dos-bichinhos
gh secret set ANDROID_KEYSTORE_PASSWORD -R lucassdoro/floresta-dos-bichinhos
```

Os dois últimos pedem o valor sem mostrar na tela: o alias da chave e a senha. O Godot
usa **a mesma senha** para o keystore e para a chave.

Sem esses secrets, uma tag de versão falha de propósito (não sai versão sem assinatura).

## Lançar

Com a `main` pronta para a versão:

```bash
git switch main && git pull
git tag v0.1.0
git push origin v0.1.0
```

Acompanhe em **Actions → Release** (leva cerca de 40 minutos: a importação dos assets
é a parte mais longa). No fim, o Release aparece em **Releases**.

## Versões

- Nome da versão = número da tag (`v0.1.0` → `0.1.0`).
- versionCode do Android = `MAIOR*10000 + MENOR*100 + PATCH + 100` (0.1.0 → 200). Sempre
  acima do 13 do app Flutter e sempre crescente.

## Testar sem lançar

**Actions → Release → Run workflow** gera os builds como artefatos, sem Release. Sem
keystore, o Android sai assinado com uma chave de debug (arquivos `-debug`): serve para
testar, não para a loja.

## Build local

O mesmo script roda na sua máquina: `tools/build/export.sh <versão> [ref] [alvos...]`
(detalhes no topo do arquivo).
