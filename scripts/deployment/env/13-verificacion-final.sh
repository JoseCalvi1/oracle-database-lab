#!/usr/bin/env bash
echo "== 1. Estado del contenedor y volumen =="
docker ps --filter "name=oralab-26ai"
docker volume ls --filter "name=oralab"
echo
echo "== 2. Tablas del usuario alumno en FREEPDB1 =="
docker exec -i oralab-26ai sqlplus -s alumno/"$APP_USER_PWD"@//localhost:1521/FREEPDB1 << 'SQL'
SET PAGESIZE 50
SELECT table_name FROM user_tables ORDER BY table_name;
EXIT;
SQL
echo
echo "== 3. Evidencias registradas =="
ls -la docs/bitacora/evidencia/script/ docs/bitacora/evidencia/spool/ docs/bitacora/evidencia/capturas/
