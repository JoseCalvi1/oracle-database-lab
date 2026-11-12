WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 170 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
COLUMN etiqueta FORMAT A26
COLUMN operation_type FORMAT A16
COLUMN policy FORMAT A8
COLUMN ultima FORMAT A10
COLUMN name FORMAT A40
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED
PROMPT
PROMPT ===== 1. Análisis (parse) DURO frente a BLANDO: 1000 consultas con literales y 1000 con variable de enlace =====
DECLARE
  v NUMBER; p0 NUMBER; h0 NUMBER; c0 NUMBER; t0 NUMBER;
  FUNCTION estad(p VARCHAR2) RETURN NUMBER IS x NUMBER;
  BEGIN SELECT m.value INTO x FROM v$mystat m JOIN v$statname s ON s.statistic# = m.statistic# WHERE s.name = p; RETURN x; END;
  PROCEDURE informe(modo VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD(modo, 12) || ' análisis totales = ' || LPAD(estad('parse count (total)') - p0, 5)
      || ' | duros = ' || LPAD(estad('parse count (hard)') - h0, 5)
      || ' | CPU de análisis = ' || LPAD((estad('parse time cpu') - c0) * 10, 5) || ' ms'
      || ' | tiempo total = ' || LPAD((DBMS_UTILITY.GET_TIME - t0) * 10, 5) || ' ms');
  END;
BEGIN
  p0 := estad('parse count (total)'); h0 := estad('parse count (hard)'); c0 := estad('parse time cpu'); t0 := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. 1000 LOOP
    EXECUTE IMMEDIATE 'SELECT /* lab4_literal */ COUNT(*) FROM admin_academia.aca_estudiantes WHERE estudiante_id = ' || i INTO v;
  END LOOP;
  informe('LITERALES');
  p0 := estad('parse count (total)'); h0 := estad('parse count (hard)'); c0 := estad('parse time cpu'); t0 := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. 1000 LOOP
    EXECUTE IMMEDIATE 'SELECT /* lab4_bind */ COUNT(*) FROM admin_academia.aca_estudiantes WHERE estudiante_id = :id' INTO v USING i;
  END LOOP;
  informe('BIND (:id)');
END;
/
PROMPT
PROMPT -- Lo que quedó en la shared pool (biblioteca de cursores): V$SQL
SELECT CASE WHEN sql_text LIKE '%lab4_literal%' THEN 'con literales' ELSE 'con :id' END AS etiqueta,
       COUNT(*) AS cursores, SUM(executions) AS ejecuciones, ROUND(SUM(sharable_mem) / 1024) AS kb_shared_pool
  FROM v$sql
 WHERE (sql_text LIKE 'SELECT /* lab4_literal */%' OR sql_text LIKE 'SELECT /* lab4_bind */%')
 GROUP BY CASE WHEN sql_text LIKE '%lab4_literal%' THEN 'con literales' ELSE 'con :id' END ORDER BY 1;
PROMPT
PROMPT ===== 2. La PGA ordena: primero en memoria (óptima) y después forzada a disco (TEMP) =====
DECLARE
  n NUMBER; m0 NUMBER; d0 NUMBER; t0 NUMBER;
  FUNCTION estad(p VARCHAR2) RETURN NUMBER IS x NUMBER;
  BEGIN SELECT m.value INTO x FROM v$mystat m JOIN v$statname s ON s.statistic# = m.statistic# WHERE s.name = p; RETURN x; END;
  PROCEDURE ordenar(etiqueta VARCHAR2) IS
  BEGIN
    m0 := estad('sorts (memory)'); d0 := estad('sorts (disk)'); t0 := DBMS_UTILITY.GET_TIME;
    EXECUTE IMMEDIATE 'SELECT /* ' || etiqueta || ' */ MAX(rn) FROM (SELECT ROW_NUMBER() OVER (ORDER BY m.fecha_matricula, m.matricula_id) rn'
                   || ' FROM admin_academia.aca_matriculas m)' INTO n;
    DBMS_OUTPUT.PUT_LINE(RPAD(etiqueta, 16) || ' filas ordenadas = ' || n || ' | sorts (memory) = ' || (estad('sorts (memory)') - m0)
      || ' | sorts (disk) = ' || (estad('sorts (disk)') - d0) || ' | ' || (DBMS_UTILITY.GET_TIME - t0) * 10 || ' ms');
  END;
BEGIN
  ordenar('lab4_pga_auto');
  EXECUTE IMMEDIATE 'ALTER SESSION SET workarea_size_policy = MANUAL';
  EXECUTE IMMEDIATE 'ALTER SESSION SET sort_area_size = 65536';
  ordenar('lab4_pga_64k');
  EXECUTE IMMEDIATE 'ALTER SESSION SET workarea_size_policy = AUTO';
END;
/
PROMPT
PROMPT -- Cada área de trabajo (work area) por dentro: V$SQL_WORKAREA
SELECT CASE WHEN s.sql_text LIKE '%lab4_pga_auto%' THEN 'PGA automática' ELSE 'manual, 64 KB' END AS etiqueta,
       w.operation_type, w.policy, ROUND(w.estimated_optimal_size / 1024) AS kb_optimo,
       ROUND(w.last_memory_used / 1024) AS kb_usados, w.last_execution AS ultima,
       ROUND(NVL(w.last_tempseg_size, 0) / 1024) AS kb_en_temp
  FROM v$sql_workarea w JOIN v$sql s ON s.sql_id = w.sql_id AND s.child_number = w.child_number
 WHERE s.sql_text LIKE 'SELECT /* lab4_pga_%' ORDER BY 1;
PROMPT
PROMPT -- Toda la instancia (desde la raíz, CON_ID 0): cuánta PGA hay y cuántas ejecuciones fueron óptimas, de una pasada o de varias
ALTER SESSION SET CONTAINER = CDB$ROOT;
SELECT name, ROUND(value / CASE WHEN unit = 'bytes' THEN 1048576 ELSE 1 END, 1) AS valor,
       CASE WHEN unit = 'bytes' THEN 'MB' ELSE unit END AS unidad
  FROM v$pgastat
 WHERE name IN ('aggregate PGA target parameter', 'total PGA allocated', 'maximum PGA allocated',
                'cache hit percentage', 'over allocation count')
   AND con_id = 0;
SELECT optimal_executions AS optimas, onepass_executions AS una_pasada, multipasses_executions AS varias_pasadas
  FROM (SELECT SUM(optimal_executions) optimal_executions, SUM(onepass_executions) onepass_executions,
               SUM(multipasses_executions) multipasses_executions FROM v$sql_workarea_histogram);
EXIT
