#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
echo "== Verificando servicio ORDS en puerto $ORDS_PORT =="
pgrep -fa "ords" || nohup "$ORDS_HOME/bin/ords" --config "$ORDS_CONFIG" serve --port "$ORDS_PORT" > "$ORDS_LOGS/ords.log" 2>&1 &
sleep 3
curl -s -I "http://localhost:${ORDS_PORT}/ords/" | head -n 5
