#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
SQL_FILE="${1:?Uso: sysdba.sh <archivo.sql> [archivo_log]}"
LOG_FILE="${2:-}"
[ -f "$SQL_FILE" ] || { echo "No existe $SQL_FILE" >&2; exit 2; }
if [ -n "$LOG_FILE" ]; then
  docker exec -i "$CONT_NAME" sqlplus -s -L / as sysdba < "$SQL_FILE" | tee "$LOG_FILE"
else
  docker exec -i "$CONT_NAME" sqlplus -s -L / as sysdba < "$SQL_FILE"
fi
