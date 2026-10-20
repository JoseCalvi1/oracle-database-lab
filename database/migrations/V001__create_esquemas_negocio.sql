WHENEVER SQLERROR EXIT SQL.SQLCODE
-- Esquemas de las 5 areas de negocio (accounts, patients, products, shipments, students)
SELECT table_name FROM user_tables ORDER BY table_name;
EXIT;
