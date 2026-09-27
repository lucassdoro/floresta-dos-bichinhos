#!/usr/bin/env bash
# Gera os builds de uma versão a partir de um clone limpo (sem addons locais nem
# arquivos fora do Git). Saída em build/<versão>/.
#
# Uso: tools/build/export.sh <versão> [ref] [alvos...]
#   tools/build/export.sh 0.1.0                   # tag v0.1.0, android aab windows linux
#   tools/build/export.sh 0.1.0 HEAD windows      # testar a partir do commit atual
#
# Android (APK para testar, AAB para a Play Store) assina com o keystore de release lido de variáveis de ambiente (nunca
# do repositório). Sem elas, o Android é pulado:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
set -euo pipefail

VERSION=${1:?"uso: tools/build/export.sh <versão> [ref] [alvos...]"}
REF=${2:-v$VERSION}
shift $(( $# >= 2 ? 2 : 1 ))
TARGETS=${*:-android aab windows linux}
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
NAME=floresta-dos-bichinhos

REPO=$(git rev-parse --show-toplevel)
OUT="$REPO/build/$VERSION"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

echo "== clone limpo de $REF"
git clone --quiet --no-local "$REPO" "$WORK/src"
git -C "$WORK/src" checkout --quiet "$REF"
cd "$WORK/src"

echo "== importando assets"
"$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1

export_preset() {
  "$GODOT" --headless --path . --export-release "$1" "$2" > "$OUT/export-$1.log" 2>&1
}

for target in $TARGETS; do
  case $target in
    android)
      if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
        echo "== android: pulado (defina as variáveis GODOT_ANDROID_KEYSTORE_RELEASE_*)"
        continue
      fi
      echo "== android"
      export_preset Android "$OUT/$NAME-$VERSION-android.apk"
      ;;
    aab)
      if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
        echo "== aab: pulado (defina as variáveis GODOT_ANDROID_KEYSTORE_RELEASE_*)"
        continue
      fi
      echo "== aab (Play Store, build via Gradle)"
      "$GODOT" --headless --path . --install-android-build-template \
        --export-release "Android AAB" "$OUT/$NAME-$VERSION-android.aab" > "$OUT/export-Android-AAB.log" 2>&1
      ;;
    windows)
      echo "== windows"
      mkdir -p "$WORK/windows"
      export_preset Windows "$WORK/windows/FlorestaDosBichinhos.exe"
      (cd "$WORK/windows" && zip -q -r "$OUT/$NAME-$VERSION-windows.zip" .)
      ;;
    linux)
      echo "== linux"
      mkdir -p "$WORK/linux"
      export_preset Linux "$WORK/linux/$NAME.x86_64"
      tar -czf "$OUT/$NAME-$VERSION-linux.tar.gz" -C "$WORK/linux" .
      ;;
    *)
      echo "alvo desconhecido: $target" >&2
      exit 1
      ;;
  esac
done

echo "== pronto: $OUT"
ls -la "$OUT"
