#!/usr/bin/env bash
source scripts/deployment/env/00-config.sh
set -a; source config/.env; set +a

echo "=== BLOQUE 1: WSL 2 y Sistema Operativo ==="
uname -r && lsb_release -ds

echo "=== BLOQUE 2: Docker Engine y Contenedor Healthy ==="
docker ps --filter "name=$CONT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "=== BLOQUE 3: Volumen Persistente ==="
docker volume ls --filter "name=$VOL_NAME"

echo "=== BLOQUE 4: Conexion a FREEPDB1 y Estado de PDB ==="
docker exec -i "$CONT_NAME" sqlplus -s alumno/"$APP_USER_PWD"@//localhost:1521/FREEPDB1 << 'SQL'
SELECT sys_context('USERENV','CON_NAME') AS con_name, user FROM dual;
EXIT;
SQL

echo "=== BLOQUE 5: 5 Areas de Negocio (Tablas V000 y V001) ==="
docker exec -i "$CONT_NAME" sqlplus -s alumno/"$APP_USER_PWD"@//localhost:1521/FREEPDB1 << 'SQL'
SELECT table_name FROM user_tables ORDER BY table_name;
EXIT;
SQL

echo "=== BLOQUE 6: Java y SQLcl ==="
java -version 2>&1 | head -n 1
sql -version

echo "=== BLOQUE 7: ORDS / Database Actions Activo ==="
curl -s -I "http://localhost:${ORDS_PORT}/ords/" | head -n 1

echo "=== BLOQUE 8: Auditoria de Secretos (0 contraseñas expuestas) ==="
echo "Ocurrencias ORACLE_PWD en git log: $(git log -p | grep -c -F "$ORACLE_PWD" || true)"
echo "Ocurrencias APP_USER_PWD en git log: $(git log -p | grep -c -F "$APP_USER_PWD" || true)"

echo "=== BLOQUE 9: Secuencia Completa de Evidencias (01 a 13) ==="
ls docs/bitacora/evidencia/*/* | grep -o '_[0-9][0-9]-\|[0-9][0-9]-' | sort -u
echo "Total archivos de evidencia: $(ls -1 docs/bitacora/evidencia/*/* | wc -l)"
