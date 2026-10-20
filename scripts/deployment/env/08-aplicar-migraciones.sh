#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
set -a; source config/.env; set +a

docker exec -i "$CONT_NAME" sqlplus -s sys/"$ORACLE_PWD"@//localhost:1521/FREEPDB1 AS SYSDBA < database/migrations/V000__setup_entornos_negocio.sql
docker exec -i "$CONT_NAME" sqlplus -s alumno/"$APP_USER_PWD"@//localhost:1521/FREEPDB1 < database/migrations/V001__create_esquemas_negocio.sql
