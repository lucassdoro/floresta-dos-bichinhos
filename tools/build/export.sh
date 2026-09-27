#!/usr/bin/env bash
# Gera os builds de uma versão a partir de um clone limpo (sem addons locais nem
# arquivos fora do Git). Saída em build/<versão>/. Usado à mão e pelo workflow
# .github/workflows/release.yml.
#
# Uso: tools/build/export.sh <versão> [ref] [alvos...]
#   tools/build/export.sh 0.1.0                   # tag v0.1.0: android aab windows linux
#   tools/build/export.sh 0.1.0 HEAD windows      # testar a partir do commit atual
#
# A versão é carimbada no clone: nome da versão, versionCode do Android
# (MAIOR*10000 + MENOR*100 + PATCH + 100, sempre acima do 13 do app Flutter) e
# versão do executável do Windows.
#
# Android (APK para testar, AAB para a Play Store) assina com o keystore de
# release lido de variáveis de ambiente, nunca do repositório:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# Sem elas o Android é pulado — ou, com ANDROID_DEBUG_FALLBACK=1, sai assinado
# com a chave de debug (arquivos "-debug", só para validar o fluxo).
set -euo pipefail

VERSION=${1:?"uso: tools/build/export.sh <versão> [ref] [alvos...]"}
REF=${2:-v$VERSION}
shift $(( $# >= 2 ? 2 : 1 ))
TARGETS=${*:-android aab windows linux}
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
NAME=floresta-dos-bichinhos

IFS=. read -r MAJOR MINOR PATCH <<< "$VERSION"
VERSION_CODE=$(( MAJOR * 10000 + MINOR * 100 + PATCH + 100 ))

REPO=$(git rev-parse --show-toplevel)
OUT="$REPO/build/$VERSION"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

echo "== clone limpo de $REF (versão $VERSION, versionCode $VERSION_CODE)"
git clone --quiet --no-local "$REPO" "$WORK/src"
git -C "$WORK/src" checkout --quiet "$REF"
cd "$WORK/src"

sed -i.bak -E \
  -e "s/^version\/code=.*/version\/code=$VERSION_CODE/" \
  -e "s/^version\/name=.*/version\/name=\"$VERSION\"/" \
  -e "s/^application\/(file|product)_version=.*/application\/\1_version=\"$VERSION.0\"/" \
  export_presets.cfg
sed -i.bak -E "s/^config\/version=.*/config\/version=\"$VERSION\"/" project.godot
rm -f export_presets.cfg.bak project.godot.bak

echo "== importando assets"
"$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1

# modo e sufixo do Android: release com o keystore, ou debug para validar o fluxo
ANDROID_MODE=""
ANDROID_SUFFIX=""
if [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
  ANDROID_MODE="--export-release"
elif [ "${ANDROID_DEBUG_FALLBACK:-0}" = "1" ]; then
  ANDROID_MODE="--export-debug"
  ANDROID_SUFFIX="-debug"
fi

export_preset() {
  "$GODOT" --headless --path . --export-release "$1" "$2" > "$OUT/export-$1.log" 2>&1
}

export_android() {
  local preset=$1 file=$2
  shift 2
  "$GODOT" --headless --path . "$@" "$ANDROID_MODE" "$preset" "$OUT/$file" \
    > "$OUT/export-${preset// /-}.log" 2>&1
}

for target in $TARGETS; do
  case $target in
    android|aab)
      if [ -z "$ANDROID_MODE" ]; then
        echo "== $target: pulado (defina GODOT_ANDROID_KEYSTORE_RELEASE_* ou ANDROID_DEBUG_FALLBACK=1)"
        continue
      fi
      if [ "$target" = android ]; then
        echo "== android (APK${ANDROID_SUFFIX})"
        export_android Android "$NAME-$VERSION-android$ANDROID_SUFFIX.apk"
        continue
      fi
      echo "== aab (Play Store, build via Gradle${ANDROID_SUFFIX})"
      export_android "Android AAB" "$NAME-$VERSION-android$ANDROID_SUFFIX.aab" --install-android-build-template
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
