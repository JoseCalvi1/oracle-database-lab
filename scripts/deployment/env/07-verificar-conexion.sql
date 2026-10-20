-- scripts/deployment/env/07-verificar-conexion.sql
SET ECHO ON;
SET FEEDBACK ON;
SET LINESIZE 150;
SET PAGESIZE 50;

-- 1. Verificar la instancia
SELECT instance_name, host_name, version, status FROM v$instance;

-- 2. Verificar la base de datos y modo de apertura
SELECT name, open_mode, log_mode FROM v$database;

EXIT;
