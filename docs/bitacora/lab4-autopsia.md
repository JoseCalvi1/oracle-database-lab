# Informe de Autopsia de la Instancia Oracle 26ai (`oralab-26ai`)

**Autor:** José Antonio Calvillo Olmedo  
**Cuenta auditora:** `C##OPS_RO` (solo lectura, principio de mínimo privilegio)  
**Instancia / Base:** `FREE` (CDB$ROOT + PDB$SEED + FREEPDB1)

---

## 1. Tabla de hallazgos, riesgos, acciones y prioridad

| Sección (Evid. 15) | Hallazgo y Evidencia Medida | Riesgo Operativo | Acción Recomendada | Prioridad |
| :--- | :--- | :--- | :--- | :--- |
| **1 y 4 (Identidad / Archivos)** | `LOG_MODE = NOARCHIVELOG` y `db_recovery_file_dest` vacío (`0 MB`). | **Alto:** Cualquier fallo físico en disco o corrupción de datafile obliga a restaurar la última copia en frío, perdiendo todas las transacciones posteriores (`RPO > 0`). | Configurar Fast Recovery Area (FRA) dentro del volumen persistente y pasar la CDB a modo `ARCHIVELOG` (planificado para el Lab 5). | **Alta** |
| **4 (Control files y Redo)** | Existen `2` control files (`control01.ctl` y `control02.ctl`) en el mismo directorio `/opt/oracle/oradata/FREE/` y los grupos de redo online solo tienen `1` miembro por grupo (`20 MB` c/u). | **Alto:** Punto único de fallo (*Single Point of Failure*). Si se corrompe un miembro de redo activo o la carpeta común de control files, la instancia cae o pierde cambios confirmados. | Multiplexar los control files y añadir un segundo miembro por cada grupo de redo log en rutas separadas (Lab 5). | **Alta** |
| **Parte A.4 (Diagnóstico inicial)** | `db_create_file_dest` está vacío (sin OMF). Al crear tablespaces con ruta relativa en el Lab 3, se crearon en `$ORACLE_HOME/dbs` (que en esta imagen oficial enlaza a `/opt/oracle/oradata/dbconfig/FREE/dbs`). | **Medio:** Ubicación no estándar fuera de `/opt/oracle/oradata/FREE/FREEPDB1/` y sin límite `MAXSIZE`, con riesgo de agotar los 12 GB de cuota de usuario de Oracle Free. | **Corregido en Parte C:** Reubicados los 5 datafiles (`TBS_*`) a `/opt/oracle/oradata/FREE/FREEPDB1/` con `MAXSIZE 1G`. Fijar `db_create_file_dest` para futuros tablespaces. | **Media (Resuelto)** |
| **Parte J.3 (ADR en Linux)** | `diagnostic_dest = /opt/oracle` reside en la capa efímera del contenedor y no dentro del volumen `/opt/oracle/oradata`. | **Medio:** Al destruir y recrear el contenedor (como hicimos en la prueba de persistencia de la Parte C), el `alert_FREE.log` y los archivos `.trc` se reinician desde cero, perdiendo la trazabilidad forense de incidentes previos. | Mover `diagnostic_dest` a una subcarpeta dentro de `/opt/oracle/oradata` o exportar logs a un colector centralizado. | **Media** |
| **6 (Índices y Estadísticas)** | `ADMIN_ACADEMIA` tiene `ALTURA_MAX = 2` tras `V002`, pero los otros 4 esquemas (`ADMIN_CLINICA`, `FINTECH`, `LOGISTICA`, `RETAIL`) muestran `ALTURA_MAX` vacía y 2 índices de Academia tienen `CF` cercano al número de filas. | **Medio:** Sin estadísticas actualizadas, el optimizador de costes (CBO) estima cardinalidades a ciegas al cargar datos nuevos. | Ejecutar `DBMS_STATS.GATHER_SCHEMA_STATS` tras cada carga masiva y evaluar el factor de agrupamiento (*clustering factor*) en el Lab 5. | **Media** |
| **7 (Seguridad)** | Las 5 cuentas propietarias (`ADMIN_*`) tenían contraseñas en texto plano en `V000`. El usuario local `ALUMNO` del Lab 3 tenía rol `DBA` en `FREEPDB1`. | **Alto (Credenciales):** Exposición de contraseñas en el historial de Git y exceso de privilegios en cuentas de aplicación. | **Corregido en Parte D (`V003`):** Los 5 propietarios son ahora `NO AUTHENTICATION` (*schema-only*). Para `ALUMNO`, revocar `DBA` y aplicar privilegios mínimos por esquema. | **Alta (Resuelto)** |
| **10 (Salud / Alert log)** | Se registran avisos `ORA-00800 [Set Priority Failed] [VKTM]` y errores controlados de las pruebas del laboratorio (`ORA-65025`, `ORA-01507`, `ORA-01219`, `ORA-06512`). | **Bajo:** `ORA-00800` es ruido conocido por falta de `CAP_SYS_NICE` en contenedores Docker; el resto fueron inducidos deliberadamente para verificar etapas y cierres. | Documentar `ORA-00800` y `ORA-20013` en la lista blanca de monitorización para evitar fatiga de alertas (*alert fatigue*). | **Baja** |

---

## 2. Resumen ejecutivo (para dirección no técnica)

La base de datos de **TiendaSur / Academia** se encuentra operativa, con sus cinco áreas de negocio aseguradas dentro del almacenamiento persistente (sobrevive a actualizaciones o borrados del contenedor) y con las contraseñas heredadas ya revocadas para impedir accesos no autorizados. Como siguiente paso prioritario en el Laboratorio 5, activaremos el diario continuo de cambios (`ARCHIVELOG`) y duplicaremos los archivos críticos de control para garantizar que, ante cualquier avería física del servidor, no se pierda ni un solo pedido o matrícula.
