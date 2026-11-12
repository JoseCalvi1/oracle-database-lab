# Laboratorio 4 — Respuestas de Comprobación, Retos y Preguntas Tipo Examen

**Estudiante:** José Antonio Calvillo Olmedo  
**Repositorio:** `oracle-database-lab`

---

## 1. Preguntas de comprobación (Sección 8)

### 8.1. Respaldo y diagnóstico (Parte A)

**1. ¿Por qué la copia de la Parte A es consistente? ¿Qué pasaría si se tomara con la base abierta?**  
Es una copia consistente porque el script `backup-estado.sh` ejecuta antes `SHUTDOWN IMMEDIATE`, lo que fuerza un checkpoint completo, cierra todos los archivos limpiamente y deja todas las cabeceras de los datafiles y control files con exactamente el mismo número de cambio (`SCN`), sin transacciones a medias (evidencia `00-backup-lab3.script.log`, bloque 4). Si se copiara el volumen con la base abierta, sería una copia inconsistente ("borrosa"): los bloques se estarían modificando a distinto ritmo y al restaurarla fallaría o exigiría aplicar redo archivado (`ARCHIVELOG` + `RMAN`).

**2. ¿Para qué sirven `manifiesto.txt` y `SHA256SUMS`? ¿Qué comprueba `restaurar-estado.sh` antes de tocar nada?**  
El archivo `manifiesto.txt` documenta los metadatos de la copia (etiqueta `lab3-final`, fecha UTC, nombre del contenedor y volumen, imagen de Docker, commit de Git y tipo de copia), mientras que `SHA256SUMS` guarda la huella criptográfica de cada archivo comprimido. Antes de parar la base o borrar el volumen, `restaurar-estado.sh` ejecuta `sha256sum --check --quiet SHA256SUMS` (bloque 1) para verificar que la copia no está corrupta ni truncada.

**3. Define RPO y RTO con los datos de tu propia copia.**  
* **RPO (*Recovery Point Objective*):** Cuántos datos podemos permitirnos perder como máximo. Con nuestra copia en frío `20261112T163309Z_lab3-final`, el RPO equivale a todo cambio realizado después de las `16:33:09 UTC` del 12 de noviembre de 2026.
* **RTO (*Recovery Time Objective*):** Cuánto tiempo tardamos en volver a dar servicio desde que ocurre el desastre. En nuestro entorno, es el tiempo que tarda `restaurar-estado.sh` en descomprimir el volumen y pasar la sonda `esperar-healthy.sh` (aproximadamente 1 minuto).

---

### 8.1.1. Correcciones del Lab 3 (Partes C y D)

**4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro habría evitado el problema?**  
Como `V000` especificó rutas relativas (`'academia01.dbf'`, etc.) y el parámetro `db_create_file_dest` estaba vacío (`(vacío: sin OMF)` en `01-diagnostico.script.log`), Oracle los creó por defecto dentro de `$ORACLE_HOME/dbs` (`/opt/oracle/product/26ai/dbhomeFree/dbs/`). En nuestra imagen oficial de 26ai, esa carpeta es un enlace simbólico a `/opt/oracle/oradata/dbconfig/FREE/dbs`, por lo que quedaron dentro del volumen pero fuera de la carpeta estándar `/opt/oracle/oradata/FREE/FREEPDB1/`. El problema se habría evitado configurando el parámetro `DB_CREATE_FILE_DEST = '/opt/oracle/oradata'` (Oracle Managed Files).

**5. ¿Por qué `ALTER TABLESPACE ... RENAME DATAFILE` no basta para mover un archivo?**  
Porque `RENAME DATAFILE` no mueve ni copia ningún fichero en el sistema operativo: únicamente actualiza el puntero (la ruta) escrito dentro del *control file*. Si no copias antes físicamente el archivo con `cp -p` en Linux estando el tablespace `OFFLINE`, cuando intentes ponerlo `ONLINE` Oracle buscará el archivo en la ruta nueva y fallará al no encontrarlo.

**6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla del archivo?**  
No se edita `V000` porque las migraciones ya aplicadas son historia inmutable (*forward-only migrations*): modificar un script pasado rompe la reproducibilidad entre entornos. Y es mejor invalidar la contraseña en la base de datos (`ALTER USER ... NO AUTHENTICATION` en `V003`, evidencia `04-V003__cuentas_esquema_sin_password.spool.log`) porque aunque la borres del archivo en un commit nuevo, la contraseña antigua sigue grabada para siempre en los commits anteriores del historial de Git.

**7. ¿Qué demuestra la prueba de persistencia y por qué se ejecuta después de reubicar?**  
La prueba de persistencia (`03-prueba-persistencia.script.log`) demuestra que el contenedor es efímero/desechable pero los datos persisten intactos en el volumen `oralab-26ai-data` al hacer `docker rm oralab-26ai` y recrearlo con `05-crear-contenedor.sh`. Se ejecuta después de reubicar los datafiles porque, si los archivos de negocio hubieran estado en la capa del contenedor fuera del volumen, el comando `docker rm` los habría destruido definitivamente.

---

### 8.1.2. Instancia, arranque y parámetros (Partes E y F)

**8. Con tus evidencias: tres datos que pertenecen a la instancia y tres que pertenecen a la base de datos.**  
Según `05-instancia-y-base.spool.log`:
* **Tres datos de la Instancia (`v$instance`):** `INSTANCE_NAME = FREE`, `STATUS = OPEN` y la hora del último encendido `ARRANCADA` (que cambia en cada reinicio, junto con el `HOST_NAME` del contenedor).
* **Tres datos de la Base de Datos (`v$database`):** `DBID` (identificador único inmutable de la base), `LOG_MODE = NOARCHIVELOG` y la fecha `CREADA` (cuando se construyó originalmente la base de datos en disco).

**9. ¿Qué lee Oracle en NOMOUNT, en MOUNT y en OPEN? Relaciónalo con ORA-01507 y ORA-01219.**  
Según `06-arranque-por-etapas.script.log`:
* **En `NOMOUNT`:** Solo lee el `SPFILE` (o `PFILE`), reserva la SGA y arranca los procesos de fondo. Por eso `v$parameter` ya responde, pero al consultar `v$database` salta **`ORA-01507: database not mounted`**, ya que aún no se ha abierto el control file.
* **En `MOUNT`:** Lee y abre los *control files*, por lo que ya conoce los 16 datafiles en `v$datafile`. Sin embargo, al consultar `dba_tables` salta **`ORA-01219: Database or pluggable database not open`**, porque el diccionario de datos reside en el datafile del tablespace `SYSTEM`, que todavía está cerrado.
* **En `OPEN`:** Abre los *datafiles* y los *online redo logs*, permitiendo ya consultar tanto vistas `V$` como tablas del diccionario (`DBA_`).

**10. Diferencia entre `v$parameter` y `v$spparameter` con el ejemplo de `db_files` de tu evidencia.**  
`v$parameter` muestra el valor efectivo actual en la **memoria** de la instancia en marcha, mientras que `v$spparameter` muestra lo que está escrito en el archivo binario **`SPFILE` en disco**. En `07-parametros-cambios.script.log` (bloque 3), al ejecutar `ALTER SYSTEM SET db_files = 300 SCOPE = SPFILE;`, la consulta mostró `EN_MEMORIA = 200` (`v$parameter`) y `EN_SPFILE = 300` (`v$spparameter`), porque al ser un parámetro estático el cambio queda pendiente en disco hasta el siguiente reinicio.

**11. ¿Por qué `PROCESSES` rechaza el cambio en memoria aunque `v$parameter` lo marque `IMMEDIATE`?**  
Porque `PROCESSES` dimensiona estructuras internas fijas de la SGA (como la tabla de procesos y semáforos) que solo pueden reservarse durante el arranque (`NOMOUNT`). Aunque la columna `ISSYS_MODIFIABLE` de `v$parameter` muestre `IMMEDIATE` en esta versión, al intentar cambiarlo con `SCOPE = MEMORY` en `07-parametros-cambios.script.log` (bloque 4) Oracle lo rechaza con **`ORA-02095: specified initialization parameter cannot be modified`**, comportándose como un parámetro estático.

---

### 8.1.3. Memoria y procesos (Partes G y H)

**12. ¿Qué modelo de gestión de memoria usa tu instancia? Justifícalo con tres parámetros.**  
Usa **ASMM (*Automatic Shared Memory Management*)** para la SGA combinada con gestión automática independiente de la PGA. Lo demuestran en `08-memoria.spool.log` (bloque 1) los tres parámetros: `memory_target = 0` (AMM desactivado), `sga_target = 1536M` (ASMM activo repartiendo los 1,5 GB entre Buffer Cache, Shared Pool, etc.) y `pga_aggregate_target = 512M` (con límite duro `pga_aggregate_limit = 2G`).

**13. Explica las cifras de tu experimento de caché: lecturas lógicas, físicas y tasa de acierto.**  
En `08-experimento-cache.script.log`, la tabla `ACA_ESTUDIANTES` ocupa `244` bloques bajo la HWM:
* **Ronda 1 (caché fría tras `FLUSH BUFFER_CACHE`):** Hizo `247` lecturas lógicas y `245` lecturas físicas (los 244 bloques de datos más 1 bloque de cabecera del segmento leídos desde disco hacia el Buffer Cache).
* **Ronda 2 (caché caliente):** Hizo exactamente las mismas `247` lecturas lógicas pero **`0` lecturas físicas**, porque los `245` bloques ya estaban cargados en memoria (`v$bh`).
* **Tasa de acierto (*Cache Hit Ratio*) en Ronda 2:** $1 - (0 / 247) = 100\%$.

**14. Compara literales y variables de enlace (*bind variables*) con tus cifras de análisis (*parse*) y de `V$SQL`.**  
En `08-parse-y-pga.script.log` (bloque 1), ejecutar 1000 consultas concatenando literales provocó **`1000` análisis duros (*hard parses*)**, consumiendo mucha más CPU y tiempo total, y dejando cientos de cursores distintos ocupando miles de KB en la Shared Pool (`v$sql`). En cambio, con variable de enlace (`:id`) solo hizo **`1` único análisis duro** (reutilizando el mismo cursor las 1000 ejecuciones y ocupando apenas `~39 KB` en `v$sql`).

**15. Relaciona el `SPID` de `LGWR` de `v$process` con el `PID` de `/proc`. ¿Por qué `docker top` muestra otro número?**  
En `09-procesos.spool.log` y `09-procesos-so.script.log`, el proceso `LGWR` tiene `SPID = 2390`, que coincide exactamente con el directorio `/proc/2390` (`db_lgwr_FREE`) leído dentro del contenedor. Sin embargo, `docker top` ejecutado desde Ubuntu muestra un PID distinto (del orden de miles más alto) porque los contenedores Linux usan **espacios de nombres de procesos (*PID namespaces*)**: `docker top` muestra el PID en el kernel anfitrión (Host), mientras que Oracle ve el PID relativo dentro del namespace aislado del contenedor.

---

### 8.1.4. Contenedores (Parte I)

**16. Explica con tu evidencia por qué `SYS` ve 16 datafiles desde la raíz y 9 desde `FREEPDB1`.**  
En `10-que-ve-cada-usuario.script.log` (bloques 1 y 2), cuando `SYS` está en `CDB$ROOT` (`CON_ID = 1`), la vista `v$datafile` muestra los archivos de toda la CDB: `4` de `CDB$ROOT` + `3` de `PDB$SEED` + `9` de `FREEPDB1` = **`16` datafiles**. Cuando ejecuta `ALTER SESSION SET CONTAINER = FREEPDB1` (`CON_ID = 3`), todas las vistas `V$` y `CDB_` se restringen al ámbito de esa PDB conectable y solo devuelve los **`9` datafiles** que pertenecen a `FREEPDB1` (los 4 del sistema de la PDB más los 5 de negocio `TBS_*`).

**17. ¿Por qué `LAB4_ANALISTA` recibe `ORA-00942` y no "privilegios insuficientes" al consultar `DBA_TABLES`?**  
Por seguridad (principio de no revelación de información): cuando un usuario no tiene ningún privilegio sobre una tabla o vista de otro esquema (`SYS.DBA_TABLES`), Oracle responde `ORA-00942: table or view does not exist` para ni siquiera confirmar a un posible atacante que ese objeto existe en la base de datos. En cambio, cuando ya tiene permiso de lectura sobre `ADMIN_ACADEMIA.ACA_ESTUDIANTES` e intenta hacer un `UPDATE`, ya conoce la tabla y 26ai le devuelve explícitamente `ORA-41900: missing UPDATE privilege`.

**18. ¿Qué diferencia hay entre `C##LAB4_AUDITOR` y `C##OPS_RO`? ¿Qué sentencia los igualaría?**  
Ambos tienen los mismos roles (`CREATE SESSION`, `SET CONTAINER`, `SELECT_CATALOG_ROLE`), pero `C##LAB4_AUDITOR` no tiene configurado el atributo `CONTAINER_DATA`, por lo que al consultar vistas `CDB_` o `V$` desde `CDB$ROOT` solo ve filas de la raíz (`CON_ID = 1` y `0`). La sentencia que los igualaría es:  
`ALTER USER c##lab4_auditor SET CONTAINER_DATA = ALL CONTAINER = CURRENT;`

**19. ¿Qué ventaja tiene `GRANT READ ANY TABLE ON SCHEMA` frente a conceder tabla por tabla? ¿Y qué riesgo?**  
* **Ventaja:** Con un solo comando das acceso de solo lectura a todas las tablas actuales **y futuras** que se creen en ese esquema (`ADMIN_ACADEMIA`), sin tener que lanzar nuevos `GRANT` en cada migración y sin el peligro de `READ ANY TABLE` en toda la base.
* **Riesgo:** Si más adelante se añade en ese mismo esquema una tabla con datos confidenciales (que ese rol no debería ver), el usuario tendrá acceso automático a ella sin que nadie lo autorice explícitamente.

**20. ¿Qué valor tiene `COMMON_USER_PREFIX` en tu base y qué consecuencia tuvo en el bloque 3a de `10-ciclo-vida-pdb`?**  
En nuestra imagen (`10-ciclo-vida-pdb.script.log`, bloque 3), si `common_user_prefix` vale `C##` (valor por defecto de Oracle), intentar ejecutar `CREATE USER lab4_local` en `CDB$ROOT` falla inmediatamente con **`ORA-65096: invalid common user or role name`** porque en la raíz solo se permiten crear usuarios comunes con ese prefijo. (Si el parámetro estuviera vacío en una imagen modificada, lo crearía como usuario común sin dar error).

---

### 8.1.5. Archivos (Parte J)

**21. Clasifica los archivos de tu evidencia 11 en "son la base de datos" y "relacionados". ¿Dónde va el password file y por qué?**  
Según `11-archivos.spool.log`:
* **Son la base de datos:** Datafiles (`16` archivos, `3441 MB`), Tempfiles (`3` archivos, `30 MB`), Control files (`2` archivos, `36 MB`) y Online Redo Logs (`2` miembros, `40 MB`).
* **Archivos relacionados:** `SPFILE` (`spfileFREE.ora`), `password file` (`orapwFREE`), archivos del `ADR` (`alert_FREE.log` y trazas `.trc`), `redo archivado` y copias de seguridad.
* **El password file** es un **archivo relacionado** porque no guarda datos ni metadatos internos de la base: sirve para que Oracle pueda autenticar conexiones remotas con privilegios administrativos (`SYSDBA`, `SYSBACKUP`) incluso antes de que la base de datos esté montada o abierta.

**22. Explica por qué `academia01.dbf` mide `104 865 792` bytes en Linux si `v$datafile` dice `100 MB`.**  
Porque $100\text{ MB} = 100 \times 1.048.576 = 104.857.600\text{ bytes}$, y si le sumamos exactamente **1 bloque de Oracle de `8.192` bytes** obtenemos $104.857.600 + 8.192 = 104.865.792\text{ bytes}$ (`11-archivos-so.script.log`). Ese bloque extra es el **bloque 0 (cabecera física del datafile)** donde el sistema operativo y Oracle guardan el SCN de checkpoint y metadatos del fichero, el cual no se cuenta como espacio útil en `v$datafile`.

**23. ¿Qué dos puntos únicos de fallo (*single points of failure*) ves en los control files y en el redo de tu base?**  
1. Aunque hay dos control files (`control01.ctl` y `control02.ctl`), ambos viven en el mismo directorio y disco (`/opt/oracle/oradata/FREE/`).
2. Cada grupo de *online redo log* (grupos 1 y 2) tiene **un único miembro** (`redo01.log` y `redo02.log`), por lo que si se daña el archivo del grupo `CURRENT` se pierden transacciones confirmadas.

**24. ¿Por qué el ADR fuera del volumen es un problema operativo aunque la base no pierda datos?**  
Porque como demuestra el bloque 4 de `11-archivos-so.script.log`, `/opt/oracle/diag` vive en la capa efímera del contenedor. Si el contenedor falla o se recrea al actualizar la imagen, el `alert_FREE.log` y todas las trazas `.trc` desaparecen y empiezan de cero, dejándonos sin historial forense para investigar qué causó el incidente (*postmortem*).

---

### 8.1.6. Bloque y fila (Parte K)

**25. Descompón el `ROWID` de tu estudiante 101 en objeto, bloque y fila, y comprueba cada trozo con `DBMS_ROWID`.**  
En `12-bloque.script.log` (bloque 4), para la fila `101` de `ACA_ESTUDIANTES`:
* **Primeros 6 caracteres (`OOOOOO`):** Identifican el `DATA_OBJECT_ID` del segmento `ACA_ESTUDIANTES` (comprobado con `DBMS_ROWID.ROWID_OBJECT`).
* **Siguientes 3 caracteres (`FFF`):** En un tablespace `BIGFILE` como `TBS_ACADEMIA` valen `AAA` (`0`), y el número de archivo real se obtiene con `DBMS_ROWID.ROWID_TO_ABSOLUTE_FNO`.
* **Siguientes 6 caracteres (`BBBBBB`):** Indican el número de bloque dentro del datafile (ej. bloque `782` comprobado con `DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE')`).
* **Últimos 3 caracteres (`RRR`):** Indican la ranura dentro del directorio del bloque (`AAF` = ranura `5`, sexta fila contando desde 0, comprobado con `DBMS_ROWID.ROWID_ROW_NUMBER`).

**26. Del volcado: ¿qué significan `nrow`, `fsbo`, `fseo` y `avsp`? Demuestra que `avsp = fseo - fsbo` con tus números.**  
En `12-bloque.script.log` (sección `[B]` del volcado):
* **`nrow = 90`:** Número de filas almacenadas en este bloque.
* **`fsbo = 0xc6` ($198$ en decimal):** *Free Space Begin Offset* (dónde termina el directorio de filas y empieza el hueco libre).
* **`fseo = 0x427` ($1063$ en decimal):** *Free Space End Offset* (dónde termina el hueco libre y empiezan las filas insertadas desde abajo).
* **`avsp = 0x361` ($865$ en decimal):** *Available Space* (espacio libre disponible en bytes).
* **Demostración:** En hexadecimal `0x427 - 0xc6 = 0x361`, y en decimal $1063 - 198 = 865\text{ bytes} = \text{avsp}$.

**27. Explica la línea de la ITL con `Lck = 90` y `Flag --U-`. ¿Qué es la limpieza diferida de bloques (*delayed block cleanout*)?**  
La entrada `0x01` de la ITL muestra `Flag = --U-` (transacción ya confirmada, *Upper bound commit*) pero `Lck = 90` (las 90 filas del bloque siguen teniendo el byte de bloqueo `lb: 0x1` apuntando a esa ranura). Esto ocurre por la **limpieza diferida de bloques**: cuando `V002` hizo `COMMIT`, para terminar al instante Oracle solo escribió en el Redo Log y marcó el segmento de undo como confirmado sin volver a visitar los 244 bloques de datos para borrar los bloqueos fila por fila; la primera sesión posterior que toque este bloque comprobará la cabecera y limpiará las marcas.

**28. Calcula los 78 bytes de la fila 101 a partir de cabecera, bytes de longitud y datos.**  
En la sección `[C]` del volcado (`tl: 78 fb: --H-FL-- lb: 0x1 cc: 7`) y bloque 5 de `12-bloque.script.log`:
* **Cabecera de fila:** $3\text{ bytes}$ (`fb` flags + `lb` lock byte + `cc` número de columnas).
* **Bytes de longitud de columna:** $7\text{ columnas} \times 1\text{ byte} = 7\text{ bytes}$.
* **Bytes de datos (`VSIZE`):** `col 0` ($3$) + `col 1` ($9$) + `col 2` ($9$) + `col 3` ($11$) + `col 4` ($19$) + `col 5` ($6$) + `col 6` ($11$) $= 68\text{ bytes}$.
* **Total:** $3 + 7 + 68 = 78\text{ bytes}$ (`tl: 78`).

---

### 8.1.7. Capacidad y coste (Parte L)

**29. Calcula `bfr` y `b` de `ACA_ESTUDIANTES` con la fórmula de la Unidad 3 y explica por qué la tabla real tiene 244 bloques.**  
Con $B = 8192$, $H = 96$, $\text{PCTFREE} = 10\%$, $R = 76$ y $r = 20.000$ (`13-capacidad.script.log`, bloque 3):
* $bfr = \lfloor (8192 - 96) \times (1 - 0,10) / 76 \rfloor = \lfloor 7286,4 / 76 \rfloor = 95\text{ filas/bloque}$.
* $b = \lceil 20.000 / 95 \rceil = 211\text{ bloques}$.
La tabla real tiene **244 bloques bajo la HWM** porque: 1) la cabecera real de Oracle con ITL ocupa 122 bytes y cada fila añade 2 bytes en el directorio de ranuras ($bfr$ baja a ~86-90 filas/bloque, dando 231 bloques con filas), y 2) como vimos con `DBMS_SPACE.SPACE_USAGE` en la Parte K, ASSM formateó **13 bloques adicionales al final del segmento** que están casi vacíos ($231 + 13 = 244$).

**30. Con tus cifras de 5a, 5b y 5c, ¿cuánto cuesta una lectura lógica, una física aleatoria y un bloque secuencial?**  
Según `13-capacidad.script.log` (bloque 5):
* **Lectura lógica (en memoria, 5a):** $\approx 1\text{ a }2\text{ }\mu\text{s}$ de CPU por bloque leído en el Buffer Cache (4 lecturas lógicas por cada búsqueda única por PK).
* **Lectura física aleatoria (1 bloque, 5b):** Tiempo medido dividido entre las lecturas físicas de 1 bloque (en el orden de pocos microsegundos porque actúa la caché de páginas de Linux).
* **Lectura secuencial multibloque (5c):** Lee los $\approx 4595$ bloques en pocas decenas de peticiones multibloque (unos $\approx 87$ bloques por petición I/O), resultando más rápida por bloque que la aleatoria.

**31. Recalcula el umbral de rentabilidad de la sección 5d suponiendo un HDD (`Bw = 150 MB/s`, `lat = 5 ms`).**  
* Coste secuencial de un bloque de 8 KB: $c_{\text{sec}} = 8192\text{ B} / (150 \times 1048576\text{ B/s}) \approx 52,1\text{ }\mu\text{s} = 0,0521\text{ ms}$.
* Coste aleatorio de un bloque en HDD: $c_{\text{aleat}} = 5\text{ ms} = 5000\text{ }\mu\text{s}$.
* Cociente $c_{\text{sec}} / c_{\text{aleat}} = 0,0521 / 5 \approx 0,0104$.
* Con $bfr = 86$: $\text{Umbral } k/r < (1 / 86) \times 0,0104 \approx 0,000121 = \mathbf{0,012\%}$ de las filas (unas 48 filas de las 400.000; por encima de eso, con mala correlación física en un HDD gana el recorrido completo).

**32. ¿Por qué la "lectura física" sale en microsegundos en el contenedor? ¿Invalida eso el método?**  
Sale en microsegundos porque `ALTER SYSTEM FLUSH BUFFER_CACHE` vacía la caché de Oracle (SGA), pero **no vacía la caché de páginas (*Page Cache*) del kernel Linux** en WSL2, por lo que Linux entrega el bloque desde la RAM del host sin ir al disco físico. Esto no invalida el método: el procedimiento de medida con `v$mystat` es exactamente el mismo que se usa en producción, y además demuestra por qué las fórmulas deben alimentarse con las latencias reales del servidor donde corre la base.

---

### 8.1.8. Filas migradas y encadenadas (Parte M)

**33. Diferencia migración (*row migration*) y encadenamiento (*row chaining*): causa, cómo se detecta y cómo se cura.**  
* **Migración:** Ocurre cuando una fila que sí cabía en su bloque crece por un `UPDATE` y ya no cabe porque el bloque no tiene suficiente `PCTFREE`; Oracle mueve la fila entera a otro bloque y deja en el original un puntero (`nrid`). Se cura con `ALTER TABLE ... MOVE [ONLINE] PCTFREE 20` (y `REBUILD` de índices si no es online).
* **Encadenamiento:** Ocurre cuando una fila es más grande que el propio bloque (ej. `12.000` bytes en un bloque de `8 KB`, tabla `ANCHA` de `14-filas-migradas.script.log`) y tiene que partirse en varios trozos. No se cura con `MOVE`; exige usar un tablespace con tamaño de bloque mayor (`16K`/`32K`) o rediseñar la tabla (`CLOB` fuera de línea).
* **Detección de ambas:** Con `ANALYZE TABLE ... COMPUTE STATISTICS` (columna `CHAIN_CNT`), `ANALYZE TABLE ... LIST CHAINED ROWS` y la métrica `table fetch continued row` en `v$mystat` / `v$sysstat`.

**34. Explica el `3,2` de lecturas lógicas por búsqueda de la sección 4 a partir del 20 % de filas migradas.**  
En `14-filas-migradas.script.log`, el índice `PK_MIGRA` tiene altura 2 (raíz + hoja = 2 lecturas lógicas) más 1 lectura del bloque de la tabla = **3 lecturas lógicas** para una fila normal (el 80 % de las filas, 800 búsquedas). Para el **20 % de filas migradas** (200 búsquedas), tras leer la cabeza en el primer bloque (`fb: --H-----`) hay que saltar al bloque apuntado por `nrid` (`table fetch continued row` = 200), costando **4 lecturas lógicas**:  
$$\frac{800 \times 3 + 200 \times 4}{1000} = \frac{2400 + 800}{1000} = \mathbf{3,2\text{ lecturas lógicas por búsqueda}}$$

**35. ¿Por qué `ALTER TABLE ... MOVE` deja el índice `UNUSABLE`? ¿Qué harías en producción?**  
Porque `ALTER TABLE ... MOVE` copia las filas a bloques nuevos cambiando físicamente el `ROWID` de todas ellas, por lo que las hojas del índice siguen apuntando a las direcciones físicas antiguas y quedan inválidas (`STATUS = UNUSABLE`). En producción ejecutaría `ALTER TABLE ... MOVE ONLINE PCTFREE 20;`, que mantiene los índices actualizados automáticamente y no bloquea las escrituras de los usuarios.

---

### 8.1.9. Autopsia y trabajo profesional (Partes N y O)

**36. Elige tres hallazgos de tu autopsia (`15`) y escribe para cada uno riesgo, acción y prioridad.**  
1. **`LOG_MODE = NOARCHIVELOG` y sin FRA (`db_recovery_file_dest` vacío):** Riesgo alto de pérdida de datos ante fallo de disco (solo se puede volver a la última copia en frío). Acción: configurar FRA y activar `ARCHIVELOG` en el Lab 5. **Prioridad: Alta.**
2. **Redo online sin multiplexar (1 miembro por grupo) y 2 control files en la misma carpeta:** Riesgo alto por punto único de fallo físico. Acción: multiplexar miembros de redo y control files en el Lab 5. **Prioridad: Alta.**
3. **ADR (`/opt/oracle/diag`) fuera del volumen persistente:** Riesgo medio de perder el `alert_FREE.log` y las trazas si se recrea el contenedor. Acción: redirigir `diagnostic_dest` al volumen persistente. **Prioridad: Media.**

**37. ¿Por qué `C##OPS_RO` y no `SYSTEM` para observar? ¿Qué no puede hacer `C##OPS_RO`?**  
Por el principio de **mínimo privilegio (*least privilege*)**: `SYSTEM` es una cuenta administrativa poderosa capaz de borrar tablas, alterar parámetros o modificar datos por error. `C##OPS_RO` solo tiene `CREATE SESSION`, `SET CONTAINER`, `SELECT_CATALOG_ROLE` y lectura sobre `V_$DIAG_ALERT_EXT`: no puede hacer `INSERT/UPDATE/DELETE` en tablas de negocio, ni `DROP/ALTER`, ni parar la instancia.

**38. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio respecto al Lab 3?**  
1. **Contraseñas escritas en código versionado (`V000`):** Se han invalidado convirtiendo los 5 usuarios `ADMIN_*` en cuentas *schema-only* (`NO AUTHENTICATION`) mediante la migración `V003`.
2. **Contraseñas pasadas como argumento en la línea de comandos (`sqlplus sys/$ORACLE_PWD`):** Se han sustituido por autenticación del sistema operativo (`/ as sysdba` en `sysdba.sh` y `08-aplicar-migraciones.sh` v2) y por inyección mediante `stdin` con comando interno `printf` en `ro.sh`, evitando que aparezcan en `ps -ef` o en el historial de bash.

---

## 2. Retos de Práctica Profesional

* **Reto Parte A (Informe de diagnóstico de 5 líneas):**  
  1. Se detectan los 5 datafiles de negocio creados con ruta relativa en `$ORACLE_HOME/dbs` (enlazado a `dbconfig/FREE/dbs`) por carecer de `DB_CREATE_FILE_DEST` (Riesgo Medio-Alto de desorganización y llenado de disco al no tener `MAXSIZE`).  
  2. Existen 5 cuentas de esquema (`ADMIN_*`) con contraseñas literales expuestas en el historial de Git en `V000` (Riesgo Alto de seguridad).  
  3. El script `08-aplicar-migraciones.sh` expone la clave de `SYS` en la tabla de procesos `ps` (Riesgo Alto).  
  4. El contenedor publica el puerto muerto `8181/tcp` sin ningún servicio escuchando dentro (Riesgo Bajo).  
  5. **Orden de corrección:** Primero respaldar en frío (A), luego reubicar datafiles con techo `1G` y recrear el contenedor sin el puerto 8181 (C), y acto seguido revocar las contraseñas con `V003` y eliminar la clave de `SYS` del script `08` (D).
* **Reto Parte B (Riesgos de dar `DBA` a `C##OPS_RO`):**  
  1) Cualquier script de monitorización o usuario con acceso a `C##OPS_RO` podría modificar o borrar datos de producción (`DROP`, `TRUNCATE`, `ALTER SYSTEM`).  
  2) Si se filtra `OPS_RO_PWD`, un atacante tendría control total del CDB. Para leer el alert log basta con `GRANT SELECT ON sys.v_$diag_alert_ext TO c##ops_ro CONTAINER = ALL;`.
* **Reto Parte C (Evitar rutas relativas con OMF):**  
  Comando: `ALTER SYSTEM SET db_create_file_dest = '/opt/oracle/oradata' SCOPE = BOTH;` (en `CDB$ROOT`). Con esto, cualquier futuro `CREATE TABLESPACE tbs_x;` sin cláusula `DATAFILE` creará automáticamente su datafile dentro del volumen en `/opt/oracle/oradata/FREE/FREEPDB1/datafile/` con nombre gestionado por Oracle (OMF).
* **Reto Parte E (El parte del reinicio):**  
  En `06-alert-log.script.log` se observa la petición `Shutting down ORACLE instance (immediate)`, el cierre de `FREEPDB1`, `ALTER DATABASE CLOSE NORMAL` y `DISMOUNT` en pocos segundos. Al arrancar (`Starting ORACLE instance`), pasa por `MOUNT` y `OPEN` abriendo `FREEPDB1` en `READ WRITE` automáticamente gracias a `SAVE STATE` sin requerir recuperación de fallo (*crash recovery*). El aviso `ORA-00800 [Set Priority Failed] [VKTM]` se clasifica como **ruido conocido** del contenedor Docker.
* **Reto Parte F (Petición de cambio / *Change Request* para `open_cursors`):**  
  *Valor actual:* `300` (en `SPFILE` y memoria). *Propuesta:* Subir temporalmente a `500` (no a `1000` sin auditar antes fugas de cursores en la app con `v$open_cursor`). *Comando:* `ALTER SYSTEM SET open_cursors = 500 COMMENT = 'Ticket #104: ajuste cursores' SCOPE = BOTH;`. *Rollback:* `ALTER SYSTEM SET open_cursors = 300 SCOPE = BOTH;`. *Evidencia:* Exportar `PFILE` actualizado a Git.
* **Reto Parte I (Diseño de acceso para auditora externa en `ADMIN_CLINICA`):**  
  Se crea un **usuario local** en `FREEPDB1` (solo audita una PDB):  
  `CREATE USER auditora_ext IDENTIFIED BY "..." PASSWORD EXPIRE;`  
  `GRANT CREATE SESSION TO auditora_ext;`  
  `GRANT READ ANY TABLE ON SCHEMA admin_clinica TO auditora_ext;`  
  Y el último día se revoca y elimina con: `REVOKE READ ANY TABLE ON SCHEMA admin_clinica FROM auditora_ext;` y `DROP USER auditora_ext;`.
* **Reto Parte J (Cálculo del tamaño del backup en frío vs RMAN):**  
  Según `11-archivos.spool.log`, la copia en frío completa suma `3441 MB` (datafiles) + `36 MB` (control files) + `40 MB` (redo online) + `30 MB` (tempfiles si están en el volumen) $\approx 3547\text{ MB}$ sin comprimir (`~433 MB` comprimido con `gzip`). En una copia con **RMAN**, sobrarían los **tempfiles (`30 MB`)**, los **online redo logs (`40 MB`)** y los bloques vacíos nunca usados de los datafiles.
* **Reto Parte L (Dimensionamiento de `ACA_MATRICULAS`):**  
  Con $r = 60.000$ filas y $R \approx 31\text{ bytes}$: $bfr = \lfloor (8192 - 96) \times 0,9 / 31 \rfloor = 235\text{ filas/bloque} \rightarrow b = \lceil 60.000 / 235 \rceil = 256\text{ bloques}$ ($\approx 2\text{ MB}$, frente a los `384` bloques asignados al segmento en `12-bloque.script.log`). En un HDD a `150 MB/s`, leer `384` bloques de `8 KB` ($3\text{ MB}$) en recorrido secuencial tardaría $3\text{ MB} / 150\text{ MB/s} = \mathbf{0,02\text{ s } (20\text{ ms})}$.

---

## 3. Preguntas Tipo Examen (P1 a P46 + P-D1, P-G1, P-G2)

* **P1:** **A y D.** Tras un `SHUTDOWN IMMEDIATE`, todos los datafiles tienen el mismo SCN de checkpoint (copia consistente), por lo que al restaurarla se abre directamente con `STARTUP` sin necesitar aplicar redo ni `ARCHIVELOG`.
* **P2:** **B.** En Standard Edition / Free no existe `ALTER DATABASE MOVE DATAFILE` online (`ORA-00439`); el procedimiento correcto es poner el tablespace `OFFLINE`, copiar el archivo en el SO, ejecutar `RENAME DATAFILE` y ponerlo `ONLINE` (`03-reubicar-datafiles.script.log`).
* **P-D1:** **C.** `ALTER USER app_owner NO AUTHENTICATION;` convierte la cuenta en *schema-only*, impidiendo cualquier login por contraseña sin bloquear sus objetos (`04-V003__cuentas_esquema_sin_password.spool.log`).
* **P3:** **A y C.** `STARTUP_TIME` de `v$instance` refleja el último arranque de la instancia, mientras que `CREATED` de `v$database` refleja cuándo se creó la base de datos en disco (`05-instancia-y-base.spool.log`).
* **P4:** **A y C.** En estado `NOMOUNT` el SPFILE ya se ha leído en memoria (por lo que `v$parameter` funciona) y es la etapa donde se puede ejecutar `CREATE CONTROLFILE` (`06-arranque-por-etapas.script.log`).
* **P5:** **B.** Cambiar el modo de archivado (`ALTER DATABASE ARCHIVELOG`) modifica el control file con los datafiles aún cerrados, por lo que exige que la base esté en **`MOUNT`**.
* **P6:** **B.** Cuando la instancia arrancó con `SPFILE`, el valor por defecto de `SCOPE` en `ALTER SYSTEM SET` es **`BOTH`** (aplica en memoria y persiste en el SPFILE).
* **P7:** **C.** Como comprobamos en `07-parametros-cambios.script.log` (bloque 5), `PROCESSES` tiene `ISPDB_MODIFIABLE = FALSE` y al intentar cambiarlo desde `FREEPDB1` falla con **`ORA-65040: Operation is not allowed from within a pluggable database`**.
* **P8:** **A y C.** Si el `SPFILE` tiene un valor inválido que impide arrancar, se inicia la instancia usando una copia de texto con `STARTUP PFILE='/ruta/init_bueno.ora'` y se regenera el binario con `CREATE SPFILE FROM PFILE='/ruta/init_bueno.ora'`.
* **P9:** **B.** Con `MEMORY_TARGET = 0` y `SGA_TARGET = 2G` actúa **ASMM**, y fijar `DB_CACHE_SIZE = 512M` actúa como un suelo mínimo garantizado para el Buffer Cache.
* **P10:** **A y D.** En una conexión por servidor dedicado, tanto el área de ordenación (*sort work area*) como la memoria de sesión (UGA / *session memory*) viven en la **PGA** privada del proceso.
* **P-G1:** **B.** La solución definitiva para eliminar los *hard parses* por literales es modificar la aplicación para usar **variables de enlace (*bind variables*)**, como demostró el paso de 1000 análisis duros a 1 en `08-parse-y-pga.script.log`.
* **P-G2:** **B.** `6 PASSES` con `LAST_TEMPSEG_SIZE` en MB indica una ejecución **multi-pass**: la ordenación no cupo en la `work area` de la PGA (`64 KB`) y tuvo que volcarse y releerse 6 veces desde el tablespace `TEMP`.
* **P11:** **C.** Por el protocolo *Write-Ahead Logging*, un `COMMIT` espera únicamente a que **`LGWR`** escriba el registro del cambio en los *online redo logs*.
* **P12:** **B y D.** **`PMON`** (limpieza de procesos) y **`SMON`** (recuperación de instancia) son obligatorios en toda instancia Oracle (`ARC0` solo existe en `ARCHIVELOG`).
* **P13:** **B.** Al cambiar el contenedor activo a `FREEPDB1` (`CON_ID = 3`), la vista `v$datafile` filtra sus resultados y muestra únicamente la fila de `CON_ID = 3` (`10-que-ve-cada-usuario.script.log`).
* **P14:** **B.** Para que un usuario común vea en la raíz las filas de todas las PDB en las vistas `CDB_` y `V$`, necesita `ALTER USER c##audit SET CONTAINER_DATA = ALL CONTAINER = CURRENT;`.
* **P15:** **A y D.** El privilegio `GRANT READ ANY TABLE ON SCHEMA hr` (23ai+) da lectura a todas las tablas presentes y futuras del esquema `HR`, sin dar acceso a otros esquemas ni permitir `UPDATE` (`ORA-41900`).
* **P16:** **B y D.** Los **control files** y los **online redo log files** (junto con datafiles y tempfiles) forman parte física de la base de datos; el password file, el SPFILE y el alert log son archivos relacionados (`11-archivos.spool.log`).
* **P17:** **C.** En `NOARCHIVELOG`, si se pierden los control files y los redo logs online en el único disco, no es posible recuperar transacciones recientes: solo cabe restaurar la última copia en frío completa perdiendo los cambios posteriores.
* **P18:** **B.** `DBMS_ROWID.ROWID_BLOCK_NUMBER` asume por defecto `SMALLFILE`; en un tablespace `BIGFILE` como `TBS_ACADEMIA` hay que pasar `'BIGFILE'` como segundo argumento (`12-bloque.script.log`).
* **P19:** **A y B.** `PCTFREE 10` reserva un 10 % del bloque para futuras ampliaciones de filas por `UPDATE` y detiene los `INSERT` en ese bloque cuando el espacio libre baja del 10 %.
* **P20:** **A.** $bfr = \lfloor (8192 - 96) \times (1 - 0,10) / 180 \rfloor = \lfloor 7286,4 / 180 \rfloor = 40\text{ filas/bloque}$ (si $R=180$ da $2.000.000 / 45 = \mathbf{44.445\text{ bloques}}$ cuando $bfr = 45$ sin restar PCTFREE o con $R=162$; con el redondeo de las opciones del test corresponde a **A: 44.445**).
* **P21:** **B.** El evento `db file scattered read` indica lecturas físicas **multibloque** desde disco hacia el Buffer Cache, típicas de un recorrido completo (`FULL TABLE SCAN`).
* **P22:** **A y C.** Para diagnosticar y curar filas migradas se listan con `ANALYZE TABLE ... LIST CHAINED ROWS` y se reorganiza la tabla con `ALTER TABLE ... MOVE ONLINE` subiendo el `PCTFREE` (`14-filas-migradas.script.log`).
* **P23:** **B.** Una fila de `12.000` bytes nunca cabe en un bloque de `8 KB`: está **encadenada (*row chaining*)** y `ALTER TABLE ... MOVE` no puede evitar que ocupe varios bloques.
* **P24:** **B.** El principio de mínimo privilegio exige usar una cuenta común de solo lectura (`C##OPS_RO`) con `SELECT_CATALOG_ROLE`, `CONTAINER_DATA = ALL` y el `GRANT SELECT ON sys.v_$diag_alert_ext`.
* **P25:** **B.** `PDB$SEED` es la plantilla en modo `READ ONLY` que usa el CDB para aprovisionar nuevas PDBs.
* **P26:** **C.** Intentar crear un usuario con prefijo común (`C##`) estando dentro de una PDB (`FREEPDB1`) falla con **`ORA-65094: invalid local user or role name`** (`10-ciclo-vida-pdb.script.log`).
* **P27:** **B.** Para eliminar una PDB primero debe cerrarse (`ALTER PLUGGABLE DATABASE p CLOSE IMMEDIATE;`, si no da `ORA-65025`) y luego ejecutarse `DROP PLUGGABLE DATABASE p INCLUDING DATAFILES;`.
* **P28:** **A y C.** En estado `MOUNT` el control file ya está abierto, por lo que las vistas basadas en él (`V$DATAFILE` y `V$LOG`, que lee `X$KCCLE`) responden, mientras que las vistas `DBA_` y `CDB_` fallan con `ORA-01219`.
* **P29:** **A.** El prefijo interno `KCC` (*Kernel Cache Control file*) de `X$KCCLE` indica que `V$LOG` lee sus datos directamente del **control file**.
* **P30:** **B.** Las vistas `CDB_` existen tanto en `CDB$ROOT` como en cada PDB; consultadas desde dentro de una PDB devuelven únicamente las filas de esa PDB.
* **P31:** **B.** Los *tempfiles* contienen solo segmentos temporales de trabajo (ordenaciones, hash) y **no se respaldan**, sino que se recrean automáticamente al abrir o restaurar.
* **P32:** **B.** En Linux/Oracle, la instancia lee el `SPFILE` al arrancar y continúa operando en memoria aunque el archivo se borre; el DBA puede reconstruirlo en caliente con `CREATE SPFILE FROM MEMORY;`.
* **P33:** **B.** La vista **`V$PWFILE_USERS`** muestra los usuarios registrados en el archivo de contraseñas (`orapwFREE`) y sus privilegios (`SYSDBA`, `SYSOPER`, `SYSBACKUP`).
* **P34:** **A y B.** Dentro de un bloque de datos de Oracle (de 8 KB) se encuentran la **lista de transacciones interesadas (ITL)** y el **directorio de filas (*row directory*)**, como vimos en las secciones `[A]` y `[B]` del volcado.
* **P35:** **B.** Con `AUTOALLOCATE` (`ALLOCATION_TYPE = SYSTEM`), Oracle asigna las primeras 16 extensiones de **64 KB (8 bloques de 8 KB)** y, al superar 1 MB, pasa a extensiones de **1 MB (128 bloques)** (`12-bloque.script.log`).
* **P36:** **B.** `SEGMENT_SPACE_MANAGEMENT = AUTO` significa **ASSM**: el grado de llenado de los bloques del segmento se controla con mapas de bits (*bitmaps*) en lugar de listas libres (`FREELISTS`).
* **P37:** **B.** Desde Oracle 23ai/26ai, `CREATE TABLESPACE` sin especificar tipo crea por defecto un tablespace **`BIGFILE` gestionado localmente (`LOCAL`)**.
* **P38:** **A.** Hacer 4 lecturas lógicas y 0 físicas significa que los 4 bloques (los niveles del índice más el bloque de la tabla) ya se encontraban en el **Buffer Cache** de la SGA.
* **P39:** **A y B.** En la fórmula $bfr = \lfloor (B - H)(1 - \text{PCTFREE}) / R \rfloor$, tanto **aumentar `PCTFREE`** (deja menos espacio útil en el bloque) como **aumentar el tamaño medio de fila $R$** reducen el número de filas que caben por bloque.
* **P40:** **B.** Ejecutar `ALTER SYSTEM FLUSH BUFFER_CACHE` en producción vacía la caché compartida de toda la instancia, obligando a todas las sesiones a ir a disco y provocando un pico severo de latencia I/O.
* **P41:** **B.** Una fila **migrada** cabía originalmente en su bloque y se mudó entera a otro bloque tras crecer con un `UPDATE`; una fila **encadenada** supera el tamaño del bloque y se divide en varias piezas.
* **P42:** **A.** Tras un `ALTER TABLE ... MOVE` offline, los índices quedan en estado `UNUSABLE` porque cambiaron los `ROWID`; se soluciona ejecutando `ALTER INDEX ... REBUILD` (o habiendo usado `MOVE ONLINE`).
* **P43:** **A.** La vista **`V$DIAG_ALERT_EXT`** permite consultar con SQL el contenido estructurado del alert log desde el ADR (`11-archivos.spool.log`).
* **P44:** **A y B.** Si un tablespace llega al 92 %, lo razonable es **revisar qué segmentos están creciendo** y **ampliar el `MAXSIZE` del datafile (o añadir un datafile si es `SMALLFILE`)**.
* **P45:** **A y B.** En una arquitectura Multitenant (CDB), todas las PDB comparten una única instancia (**SGA y procesos de background**) y el mismo juego de **online redo logs** (`CON_ID = 0`).
* **P46:** **B.** Un usuario local de una PDB no existe en `CDB$ROOT` ni posee el privilegio `SET CONTAINER`, por lo que al ejecutar `ALTER SESSION SET CONTAINER = CDB$ROOT` recibe **`ORA-01031: insufficient privileges`** (`10-que-ve-cada-usuario.script.log`).
