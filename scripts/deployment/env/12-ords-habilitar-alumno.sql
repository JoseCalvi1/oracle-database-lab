WHENEVER SQLERROR EXIT SQL.SQLCODE
SET SERVEROUTPUT ON
BEGIN
  ORDS.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'ALUMNO',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => 'alumno',
    p_auto_rest_auth      => FALSE
  );
  COMMIT;
END;
/
SELECT parsing_schema, status, pattern FROM user_ords_schemas;
EXIT;
