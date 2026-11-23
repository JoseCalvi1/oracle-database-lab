# Runbook de Guardia: Pérdida de un Datafile de Negocio (Media Failure)

## 1. Síntoma y detección
- Las consultas sobre el tablespace afectado fallan con:
  - `ORA-01116: error in opening database file <N>`
  - `ORA-01110: data file <N>: '<ruta_datafile>'`
  - `ORA-27041: unable to open file` (`No such file or directory`)
- Si un proceso de fondo (`DBWn` o checkpoint) detecta el fallo en una PDB, el *alert log* registra `ORA-63999: data file suffered media failure` y Oracle cierra únicamente esa PDB (`MOUNTED`), manteniendo abierta la `CDB$ROOT` y el resto de PDBs.

## 2. Comprobaciones previas (antes de actuar)
1. Verificar que la base está en modo `ARCHIVELOG`: `SELECT log_mode FROM v$database;`
2. Identificar el número de archivo (`FILE#`) y el estado de la PDB en `v$datafile` y `v$pdbs`.
3. Confirmar en RMAN que existe copia válida: `LIST BACKUP OF DATAFILE <FILE#>;`

## 3. Procedimiento de recuperación (RPO = 0)
- **Camino A (PDB abierta `READ WRITE`):** `ALTER DATABASE DATAFILE <FILE#> OFFLINE;` -> RMAN `RESTORE DATAFILE <FILE#>; RECOVER DATAFILE <FILE#>;` -> `ALTER DATABASE DATAFILE <FILE#> ONLINE;`.
- **Camino B (PDB cerrada `MOUNTED` por `ORA-63999`):** Esperar a que `v$pdbs` muestre `MOUNTED` -> RMAN `RESTORE DATAFILE <FILE#>; RECOVER DATAFILE <FILE#>;` -> `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;`.

## 4. Verificación y escalado
- Comprobar `v$pdbs` en `READ WRITE`, `v$datafile` en `ONLINE` y validar datos con `SELECT COUNT(*)`. Documentar `RTO` y `RPO = 0` en el parte de incidencia.
