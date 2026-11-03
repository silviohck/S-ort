#!/bin/bash
# Gera dist/Solicitações.app (Intel + Apple Silicon) e dist/Solicitacoes-<versão>-mac.dmg.
# Uso (num Mac com Xcode): ./scripts/empacotar.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSAO="$(tr -d '[:space:]' < VERSAO)"
NOME="Solicitações"
APP="dist/$NOME.app"

rm -rf dist && mkdir -p dist
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Solicitacoes"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Solicitacoes"
sed "s/__VERSAO__/$VERSAO/g" Recursos/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ícone .icns a partir do PNG de 1024 px
ICONES="dist/AppIcon.iconset"
mkdir -p "$ICONES"
for t in 16 32 128 256 512; do
  sips -z $t $t Recursos/icone.png --out "$ICONES/icon_${t}x${t}.png" >/dev/null
  sips -z $((t * 2)) $((t * 2)) Recursos/icone.png --out "$ICONES/icon_${t}x${t}@2x.png" >/dev/null
done
iconutil -c icns "$ICONES" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONES"

# Assinatura local (ad-hoc): sem ela, Macs com Apple Silicon dizem que o app "está danificado"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

# .dmg com atalho para Aplicativos
PALCO="dist/dmg"
mkdir -p "$PALCO"
cp -R "$APP" "$PALCO/"
ln -s /Applications "$PALCO/Applications"
hdiutil create -volname "$NOME" -srcfolder "$PALCO" -ov -format UDZO "dist/Solicitacoes-$VERSAO-mac.dmg"
rm -rf "$PALCO"

lipo -info "$APP/Contents/MacOS/Solicitacoes"
du -sh "$APP" dist/*.dmg
