#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
echo "== Verificando servicio ORDS en puerto $ORDS_PORT =="
ss -tln | grep ":${ORDS_PORT} "
curl -s -I "http://localhost:${ORDS_PORT}/ords/alumno/_sdw/" | head -n 5
