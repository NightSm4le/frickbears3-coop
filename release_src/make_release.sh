#!/bin/bash
# Rebuild the test package from ../build/data.win. No game files go into the zip.
set -e; cd "$(dirname "$0")"; R=$PWD; F=/workspace/frickbears
export WINEPREFIX=$F/prefA WINEDEBUG=-all
rm -rf pkg/FB3-Coop-test; P=pkg/FB3-Coop-test; mkdir -p $P
cp dl/xdelta3-3.1.0-x86_64.exe $P/xdelta3.exe
cp $F/build/data.win out_data.win
wine $P/xdelta3.exe -e -9 -f -s $F/clean/data.win out_data.win $P/fb3coop.xdelta
OUT=$(sha256sum out_data.win | cut -d' ' -f1); PS=$(sha256sum $P/fb3coop.xdelta | cut -d' ' -f1)
# PowerShell 5.1 needs UTF-8 BOM for Cyrillic strings
{ printf '\xef\xbb\xbf'; sed -e "s/@OUT_SHA@/$OUT/" -e "s/@PATCH_SHA@/$PS/" install.ps1.in; } > $P/install.ps1
cp tmpl/*.bat $P/; cp README_RU.txt XDELTA_LICENSE.txt $P/
( cd $P && sha256sum xdelta3.exe fb3coop.xdelta install.ps1 > SHA256SUMS.txt && echo "$OUT  data.win (result after patch)" >> SHA256SUMS.txt && echo "f2cdfb32fabd6b838ecb89bac10bc1cc956a77565fc2530ce1c6f9b9ffd0e38a  data.win (clean v2.0.2, required)" >> SHA256SUMS.txt )
rm -f FB3-Coop-test.zip; (cd pkg && python3 -c "import shutil; shutil.make_archive('../FB3-Coop-test','zip','.','FB3-Coop-test')")
rm -f out_data.win
echo "OK zip $(sha256sum FB3-Coop-test.zip)  data.win->$OUT"
