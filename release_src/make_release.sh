#!/bin/bash
# Rebuild the release zip from installer/patches (manifest-driven, 4 bases x 2 variants).
# No game files go into the zip: only xdelta patches, the official xdelta3 tool, launchers and docs.
set -e; cd "$(dirname "$0")"; R=$PWD; W=$(cd ../.. && pwd -W)
VER=${VER:-0.8.6}
P=$W/build/pkg/FB3-Coop-$VER
rm -rf "$P"; mkdir -p "$P"
cp "$R/../installer/tools/xdelta3.exe" "$P/xdelta3.exe"
cp "$R/../installer/patches/"*.xdelta "$P/"
cp "$R/../installer/patches/manifest.json" "$P/manifest.json"
# PowerShell 5.1 needs UTF-8 BOM for Cyrillic strings
{ printf '\xef\xbb\xbf'; cat install.ps1.in; } > "$P/install.ps1"
cp tmpl/*.bat "$P/"; cp README_RU.txt XDELTA_LICENSE.txt CUSTOM_CHARACTERS_RU.md CONNECT_RU.md "$P/"
mkdir -p "$P/Addons"; cp -r ../addons/CoopChars "$P/Addons/"
( cd "$P" && sha256sum xdelta3.exe *.xdelta install.ps1 manifest.json > SHA256SUMS.txt )
mkdir -p "$W/dist"; rm -f "$W/dist/FB3-Coop-$VER.zip"
powershell -NoProfile -Command "Compress-Archive -LiteralPath '$P' -DestinationPath '$W/dist/FB3-Coop-$VER.zip' -Force"
echo "OK zip $(sha256sum "$W/dist/FB3-Coop-$VER.zip")"