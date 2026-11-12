#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
DEST=docs/bitacora/lab4/evidencia/config
mkdir -p "$DEST"
for f in initFREE_lab4.ora initFREE_lab4_memoria.ora; do
  docker cp "$CONT_NAME:/tmp/$f" "$DEST/$f"
done
wc -l "$DEST"/initFREE_lab4*.ora
nombres() { grep -oE '^([*A-Za-z0-9]+\.)?[a-z][a-z0-9_]*=' "$1" | sed -E 's/^.*\.//; s/=$//' | sort -u; }
echo "== Parámetros que tienen valor en MEMORIA pero NO están escritos en el SPFILE (derivados o por defecto) =="
comm -13 <(nombres "$DEST/initFREE_lab4.ora") <(nombres "$DEST/initFREE_lab4_memoria.ora") | paste -sd " " | fold -s -w 120
