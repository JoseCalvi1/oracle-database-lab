-- scripts/deployment/env/10-verificar-sqlcl.sql
SET SQLFORMAT ANSICONSOLE;
SELECT user AS usuario_actual, TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS fecha_hora FROM dual;

PROMPT == Tablas del usuario ==
SELECT table_name FROM user_tables ORDER BY table_name;

EXIT;
