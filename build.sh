#!/usr/bin/env bash
# Reproducible build: clean data.win + mod -> ../build/data.win
# usage: ./build.sh [noop|log|full]   (default full)
set -euo pipefail
STAGE="${1:-full}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CLEAN="${COOP_CLEAN:-$HERE/../clean/data.win}"
OUT_DIR="${COOP_OUT:-$HERE/../build}"
UMT="${UMT:-/workspace/tools/utmt/UndertaleModCli}"
EXPECT=f2cdfb32fabd6b838ecb89bac10bc1cc956a77565fc2530ce1c6f9b9ffd0e38a  # FNaFb3+4LD v2.0.2 data.win
got=$(sha256sum "$CLEAN" | cut -d' ' -f1)
[ "$got" = "$EXPECT" ] || { echo "clean data.win sha256 mismatch: $got" >&2; exit 2; }
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/data.win"; [ "$STAGE" = full ] || OUT="$OUT_DIR/data.$STAGE.win"
COOP_MOD_DIR="$HERE" COOP_STAGE="$STAGE" "$UMT" load "$CLEAN" -s "$HERE/scripts/apply.csx" -o "$OUT" -f > "$OUT_DIR/build.$STAGE.log" 2>&1 || true
grep -E "^\[apply\]|error|Exception" "$OUT_DIR/build.$STAGE.log" | grep -vE "^\s+at " || true
grep -qiE 'exception|error|failed' "$OUT_DIR/build.$STAGE.log" && { echo "BUILD FAILED ($STAGE)" >&2; exit 1; }
rm -f "$OUT.tmp"; [ -s "$OUT" ] || { echo "no output" >&2; exit 1; }
COOP_STAGE="$STAGE" "$UMT" load "$OUT" -s "$HERE/tests/verify.csx" 2>&1 | tee -a "$OUT_DIR/build.$STAGE.log" | grep -E 'VERIFY'
grep -q 'VERIFY OK' "$OUT_DIR/build.$STAGE.log" || { echo "VERIFY FAILED" >&2; exit 1; }
echo "OK $STAGE -> $OUT  sha256 $(sha256sum "$OUT" | cut -d' ' -f1)"
