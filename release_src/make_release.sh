#!/bin/bash
# Rebuild the test package from ../build/data.win. No game files go into the zip.
set -e; cd "$(dirname "$0")"; R=$PWD; F=/workspace/frickbears
SRC=${SRC:-$F/clean/data.win}; SRC_NAME=${SRC_NAME:-clean v2.0.2}; VER=${VER:-test}
export WINEPREFIX=$F/prefA WINEDEBUG=-all
rm -rf pkg/FB3-Coop-$VER; P=pkg/FB3-Coop-$VER; mkdir -p $P
cp $F/release/dl/xdelta3-3.1.0-x86_64.exe $P/xdelta3.exe
cp $F/build/data.win out_data.win
wine $P/xdelta3.exe -e -9 -f -s $SRC out_data.win $P/fb3coop.xdelta
OUT=$(sha256sum out_data.win | cut -d' ' -f1); PS=$(sha256sum $P/fb3coop.xdelta | cut -d' ' -f1)
# PowerShell 5.1 needs UTF-8 BOM for Cyrillic strings
{ printf '\xef\xbb\xbf'; sed -e "s/@OUT_SHA@/$OUT/" -e "s/@PATCH_SHA@/$PS/" -e "s/@SRC_SHA@/$(sha256sum $SRC|cut -d' ' -f1)/" -e "s/@SRC_NAME@/$SRC_NAME/" install.ps1.in; } > $P/install.ps1
cp tmpl/*.bat $P/; cp README_RU.txt XDELTA_LICENSE.txt $P/
( cd $P && sha256sum xdelta3.exe fb3coop.xdelta install.ps1 > SHA256SUMS.txt && echo "$OUT  data.win (result after patch)" >> SHA256SUMS.txt && echo "$(sha256sum $SRC|cut -d' ' -f1)  data.win ($SRC_NAME, required)" >> SHA256SUMS.txt )
rm -f FB3-Coop-$VER.zip; (cd pkg && python3 -c "import shutil; shutil.make_archive('../FB3-Coop-$VER','zip','.','FB3-Coop-$VER')")
rm -f out_data.win
echo "OK zip $(sha256sum FB3-Coop-$VER.zip)  data.win->$OUT"
