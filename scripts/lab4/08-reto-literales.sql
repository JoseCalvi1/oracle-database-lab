@scripts/ops/marca
SPOOL docs/bitacora/lab4/evidencia/spool/&marca._08-reto-literales.spool.log
SET SQLFORMAT DEFAULT
SET LINESIZE 170 PAGESIZE 50 FEEDBACK OFF
COLUMN ejemplo_sql FORMAT A85 TRUNCATED
SELECT TO_CHAR(force_matching_signature) AS firma,
       COUNT(*) AS cursores_distintos,
       SUM(executions) AS ejecuciones_totales,
       ROUND(SUM(sharable_mem)/1024) AS kb_shared_pool,
       MIN(sql_text) AS ejemplo_sql
  FROM v$sql
 WHERE force_matching_signature <> 0
 GROUP BY force_matching_signature
HAVING COUNT(*) > 50
 ORDER BY cursores_distintos DESC;
SPOOL OFF
