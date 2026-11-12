WHENEVER SQLERROR EXIT FAILURE
GRANT SELECT ON sys.v_$diag_alert_ext TO c##ops_ro CONTAINER = ALL;
SET LINESIZE 120
COLUMN grantee FORMAT A12
COLUMN table_name FORMAT A20
COLUMN privilege FORMAT A10
SELECT grantee, table_name, privilege, common FROM dba_tab_privs WHERE grantee = 'C##OPS_RO';
EXIT
