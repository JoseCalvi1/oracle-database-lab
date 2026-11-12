#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
if ! docker image inspect "$IMG" > /dev/null 2>&1; then
  echo "La imagen $IMG no está en local: se descarga ANTES de borrar el contenedor"
  docker pull "$IMG" || { echo "ERROR: no se puede descargar $IMG. No se ha tocado nada."; exit 1; }
fi
echo "== 1. ANTES: entornos de negocio =="
bash scripts/ops/sysdba.sh scripts/lab4/03-verificar-negocio.sql
echo "== 2. Parada limpia (SHUTDOWN IMMEDIATE) y borrado del contenedor; el volumen $VOL_NAME se conserva =="
printf 'SHUTDOWN IMMEDIATE\nEXIT\n' | docker exec -i "$CONT_NAME" sqlplus -s -L / as sysdba
docker stop -t 120 "$CONT_NAME" >/dev/null
docker rm "$CONT_NAME"
docker volume ls --filter "name=$VOL_NAME"
echo "== 3. Recrear el contenedor con la definición corregida =="
bash scripts/deployment/env/05-crear-contenedor.sh
bash scripts/ops/esperar-healthy.sh
echo "== 4. DESPUÉS: mismos entornos, mismos datos =="
bash scripts/ops/sysdba.sh scripts/lab4/03-verificar-negocio.sql
echo "== 5. Puertos publicados ahora (ya no aparece 8181) =="
docker port "$CONT_NAME"
