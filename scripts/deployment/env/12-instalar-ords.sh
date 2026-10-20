#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
echo "== Verificando instalacion de ORDS en $ORDS_HOME y configuracion en $ORDS_CONFIG =="
"$ORDS_HOME/bin/ords" --config "$ORDS_CONFIG" --version
ls -la "$ORDS_CONFIG/databases/default/"
