#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
[ -f config/.env ] || { echo "Falta config/.env" >&2; exit 2; }
source config/.env
[ -n "${OPS_RO_PWD:-}" ] || { echo "OPS_RO_PWD está vacío en config/.env" >&2; exit 2; }
command -v sql > /dev/null || { echo "No encuentro SQLcl (comando sql) en el PATH" >&2; exit 2; }
mkdir -p docs/bitacora/lab4/evidencia/spool docs/bitacora/lab5/evidencia/spool
SQL_FILE="${1:?Uso: ro.sh <archivo.sql> [servicio]}"
SERVICE="${2:-$SERVICE_CDB}"
[ -f "$SQL_FILE" ] || { echo "No existe $SQL_FILE" >&2; exit 2; }
printf 'CONNECT c##ops_ro/"%s"@//localhost:%s/%s\n@%s\nEXIT\n' \
  "$OPS_RO_PWD" "$PORT_DB" "$SERVICE" "$SQL_FILE" | sql -S /nolog
