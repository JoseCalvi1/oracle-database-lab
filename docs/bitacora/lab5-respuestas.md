# Laboratorio 5 — Respuestas de Comprobación, Retrospectiva Game Day y Simulacro 1Z0-182

**Estudiante:** José Antonio Calvillo Olmedo  
**Repositorio:** `oracle-database-lab`

---

## 1. Preguntas de comprobación (Sección 8)

### 8.1. Punto de partida y banco de medida (Partes A y B)

**1. Compara el paso 6 de tu copia `lab4-final` con el de la copia `lab3-final`. ¿Qué demuestra la diferencia?**  
En la copia `lab3-final` (`00-backup-lab3.script.log`), el paso 6 mostraba los 5 datafiles de negocio (`academia01.dbf`, `clinica01.dbf`, `fintech01.dbf`, `logistica01.dbf`, `retail01.dbf`) fuera de `/opt/oracle/oradata/FREE/FREEPDB1/`. En cambio, en `lab4-final` (`00-backup-lab4.script.log`), el paso 6 muestra **`ninguno: el volumen contiene toda la base de datos`**, demostrando que la reubicación de datafiles realizada en el Lab 4 dejó toda la base contenida íntegramente dentro del volumen persistente.

**2. Calcula el factor de bloqueo (`bfr`) de `CLIENTE` y de `PEDIDO` con sus estadísticas. ¿Por qué `PEDIDO` cabe casi el triple de filas por bloque?**  
En `01-perfil-tiendasur.script.log`:
* **`CLIENTE`:** $R = 98\text{ bytes}$, bloque de $8192\text{ bytes}$ con $\text{PCTFREE } 10\% \rightarrow bfr \approx \lfloor (8192 - 122) \times 0,90 / (98 + 2) \rfloor = 72\text{ filas/bloque}$ ($68\text{ medidos}$, dando $1467\text{ bloques}$ para $100.000$ filas).
* **`PEDIDO`:** $R = 32\text{ bytes} \rightarrow bfr \approx \lfloor (8192 - 122) \times 0,90 / (32 + 2) \rfloor = 213\text{ filas/bloque}$ ($188\text{ medidos}$, dando $5320\text{ bloques}$ para $1.000.000$ de filas).  
`PEDIDO` admite casi el triple de filas por bloque porque sus columnas (IDs, fechas, importes numéricos y códigos cortos de 1 a 5 caracteres) ocupan aproximadamente **un tercio del tamaño medio de fila ($32\text{ B}$ frente a $98\text{ B}$)** de `CLIENTE` (que guarda emails, nombres y apellidos largos).

**3. ¿Por qué el banco de medida ejecuta cada sentencia dos veces y mide solo la segunda?**  
Porque la primera ejecución incluye costes puntuales que distorsionan la medida del plan: el **análisis duro (*hard parse*)** de la sentencia en la Shared Pool, la carga de bloques desde disco al Buffer Cache y posibles limpiezas diferidas de bloques (*delayed block cleanout*). Al descartar la primera y medir la segunda ejecución ("en caliente"), obtenemos una métrica limpia y reproducible de lecturas lógicas.

---

### 8.1.1. Anatomía y tipos de índice (Partes C y D)

**4. Con tu evidencia 02: altura, número de hojas y factor de ramificación (*fan-out*) real de `IX_PED_CLIENTE`. ¿Qué altura tendría con mil millones de filas?**  
Según `02-anatomia-indice.script.log` (bloque 2, `INDEX_STATS`):
* **Altura (`HEIGHT`):** `3` (`BLEVEL = 2`).
* **Número de hojas (`LF_BLKS`):** `2216` hojas (`6` bloques de rama).
* **Factor de ramificación real ($fo$):** $(2216 + 6 - 1) / 6 = \mathbf{370}$ hijos por bloque de rama (siendo el máximo físico $543$).
* **Con mil millones ($10^9$) de filas:** Tendría $\approx 2.208.969$ hojas y una **altura de `4`** ($1 + \lceil \log_{543}(2.208.969) \rceil = 4$), requiriendo solo 5 lecturas (4 de índice + 1 de tabla) para localizar una fila entre mil millones.

**5. En el volcado de la hoja de `PK_CLIENTE`, localiza una entrada y descompón el `ROWID` que guarda en bloque y fila. ¿Por qué no aparece el número de archivo?**  
En `02-anatomia-indice.script.log` (sección `[B] HOJA`, entrada `row#0` con clave `c1 02` = cliente `1`):  
`data: (6): 00 00 03 1b 00 00`
* **Primeros 4 bytes (`00 00 03 1b`):** En hexadecimal `0x31B` $= \mathbf{795}$ (número de bloque dentro del datafile).
* **Últimos 2 bytes (`00 00`):** Ranura **`0`** dentro del bloque `795`.  
No aparece el número de archivo porque `TBS_TIENDASUR` es un tablespace **`BIGFILE`**, que solo admite **un único datafile**; al no existir ambigüedad de archivo dentro del tablespace, Oracle ahorra espacio usando el *ROWID* corto de 6 bytes.

**6. Elige tres pruebas de la Parte D y explica, con las lecturas lógicas medidas, por qué un tipo de índice gana al otro.**  
Según `03-tipos-indice.script.log`:
1. **Q7 (Compuesto vs. Cubriente):** Con `ix_ped_cliente` hace `15` lecturas lógicas y un `SORT` en memoria; con el compuesto `(id_cliente, fecha_pedido)` baja a `7` lecturas (ya viene ordenado); y con el **cubriente** `(id_cliente, fecha_pedido, importe, estado, id_pedido)` baja a **`3` lecturas lógicas**, porque todas las columnas del `SELECT` están en las hojas del índice y **evita por completo el salto a la tabla**.
2. **Q14 (4 índices Bitmap vs. B-tree en almacén de datos):** Sin bitmaps lee `4073` bloques; con los **4 índices Bitmap** (`anio`, `region`, `canal`, `categoria`) baja a **`528` lecturas lógicas**, porque Oracle combina los mapas de bits en memoria mediante `BITMAP AND` antes de tocar la tabla, ocupando además una fracción mínima del espacio de un B-tree.
3. **Q15 (Clúster Hash vs. Montículo + PK):** Para buscar una sesión exacta por `token`, el **clúster Hash** requiere **`1` única lectura lógica** frente a las `4` de la tabla heap con PK (porque la función hash calcula directamente la dirección del bloque sin bajar por un árbol), aunque pierde en la limpieza por rango (`<`), donde recorre toda la tabla (`2770` lecturas).

---

### 8.1.2. Agrupamiento, equilibrio y sargabilidad (Partes E y F)

**7. ¿Por qué `IX_PED_FECHA` tiene un *clustering factor* cercano al número de bloques e `IX_PED_CLIENTE` cercano al de filas? ¿Lo arreglaría un `REBUILD`?**  
En `04-agrupamiento-equilibrio.script.log`:
* `IX_PED_FECHA` tiene `CF = 5220` (casi igual a los `5320` bloques de la tabla) porque los pedidos se insertaron ordenados cronológicamente (`INSERT /*+ APPEND */ ... ORDER BY n`), de modo que fechas consecutivas del índice están juntas en los mismos bloques de la tabla.
* `IX_PED_CLIENTE` tiene `CF = 999041` (casi igual al `1.000.000` de filas) porque cada cliente compra en momentos distintos y sus pedidos están dispersos por toda la tabla, obligando a saltar de bloque en casi cada entrada del índice.  
**Un `REBUILD` del índice NO lo arreglaría**, porque el *clustering factor* mide el orden físico de las filas **en la tabla**, no en el índice; para cambiarlo habría que reordenar físicamente la tabla.

**8. Según tu curva de la Parte E, ¿a partir de qué porcentaje deja de compensar cada índice? Compáralo con la fórmula de la Unidad 3.**  
En `04-agrupamiento-equilibrio.script.log` (sección 3):
* El recorrido completo de `PEDIDO` cuesta **`5232` lecturas lógicas**.
* El índice con **CF malo (`IX_PED_CLIENTE`)** supera las `5232` lecturas lógicas a partir del **`1 %`** de las filas ($10.000$ filas), y el optimizador deja de elegirlo mucho antes: **entre el `0,1 %` y el `0,2 %`**, coincidiendo con la fórmula de la Unidad 3: $k/r < (1/188) \times (1/5) = \mathbf{0,11\%}$.
* El índice con **CF bueno (`IX_PED_FECHA`)** compensa hasta casi toda la tabla y solo pierde al **`100 %`** (`7875` lecturas frente a `5232`, porque lee el índice entero además de toda la tabla).

**9. Explica por qué Q4b (`'Gonz%'`) usa el índice y aun así lee más bloques que un recorrido completo.**  
En `05-sargabilidad.script.log` (Regla 4), `LIKE 'Gonz%'` tiene el comodín a la derecha, por lo que **es sargable** y usa el índice `ix_cli_apellidos`. Sin embargo, `'Gonz%'` devuelve el **`2,1 %`** de los clientes ($2.100$ filas) con un **clustering factor malo**, lo que obliga a hacer un salto aleatorio a la tabla por cada fila (`2024` lecturas lógicas), superando las `1472` lecturas secuenciales que cuesta leer toda la tabla `CLIENTE` de un tirón.

---

### 8.1.3. Coste de escritura y mantenimiento (Partes G y H)

**10. Con tu evidencia 06: bloques modificados por `INSERT` con 4, 9 y 5 índices. ¿Qué índices de la propuesta del compañero rechazaste y con qué dato?**  
En `06-indices.script.log`:
* **Hoy (4 índices):** `10,1` bloques modificados por fila insertada.
* **Propuesta del compañero (9 índices):** `20,2` bloques modificados por fila (el doble de coste de escritura).
* **Con `V005` (5 índices):** `12,2` bloques modificados por fila.  
**Índices rechazados y datos:**
* `IX_PED_CANAL` y `IX_PED_ESTADO`: Baja selectividad (`3` y `4` valores distintos; cada valor supera con creces el umbral del `0,5 %` de viabilidad) y `0` usos en `DBA_OBJECT_USAGE`. Para el `2 %` de pendientes `'P'` se creó el índice parcial `IX_PED_PENDIENTES` (`54` hojas frente a `2933`).
* `IX_PED_FEC_CLI`: Redundante por prefijo izquierdo con `IX_PED_FECHA` y sin consultas que lo necesiten.
* `IX_PED_CLI_FEC`: Sustituido por la versión cubriente `IX_PED_CLI_FEC_CUB` (que además permite borrar `IX_PED_CLIENTE` sin dejar sin índice la clave ajena `id_cliente`).

**11. Distingue, con tus gráficos de la Parte H, un índice con divisiones 50/50, uno con divisiones 90/10 y uno con patrón cola.**  
Según los gráficos de `07-divisiones-y-cola.sh`:
* **Divisiones 50/50 (`IX_AZAR`):** Llenado medio del **`~75 %`**, histograma repartido entre `50 %` y `90 %` y mapa uniforme de `=` y `-` (estado estable normal).
* **Divisiones 90/10 (`IX_CRECIENTE`):** Llenado del **`100 %`** (`398` divisiones, todas `90/10`), todas las hojas en el tramo `90-99 %` y mapa completamente relleno de `#`.
* **Patrón cola (`IX_COLA`):** Mapa vacío a la izquierda (`[      ...`) y lleno a la derecha (`...######]`), con **`76.832` entradas borradas (`DEL_LF_ROWS`)** ocupando sitio en `452` hojas porque se borran claves bajas por la izquierda mientras las nuevas inserciones crecientes entran siempre por la derecha.

**12. ¿Qué remedio elegirías para el patrón cola en producción, en horario de servicio, y por qué?**  
En horario de servicio elegiría **`ALTER INDEX ... COALESCE;`** (o `SHRINK SPACE`), porque se ejecuta **en línea sin bloquear las transacciones DML**, fusiona las hojas vacías o medio vacías de la izquierda y reduce al instante las lecturas de búsqueda del siguiente mensaje de `253` a **`2` lecturas lógicas** (`07c-remedios.script.log`) sin necesitar el doble de espacio ni generar la carga de redo de un `REBUILD`. Como solución estructural definitiva, particionaría la tabla por rango de fecha/ID y haría `DROP/TRUNCATE PARTITION`.

---

### 8.1.4. SCN, control files, redo y FRA (Partes I a L)

**13. Con tu evidencia 08: ¿qué valores compara Oracle al abrir para decidir si hace falta recuperación?**  
En `08-scn-checkpoint.script.log` (bloque 2), Oracle compara el **`CHECKPOINT_CHANGE#` registrado en el *control file*** (`v$datafile.checkpoint_change#`) con el **`CHECKPOINT_CHANGE#` grabado en la cabecera física de cada datafile** (`v$datafile_header.checkpoint_change#`). Si ambos coinciden en todos los archivos y el cierre fue limpio, la base abre sin recuperación; si difieren, aplica redo desde el SCN más antiguo.

**14. ¿Qué protege la multiplexación del control file en el mismo volumen y qué no? ¿Cómo se haría en producción?**  
Tener `control01.ctl`, `control02.ctl` y `control03.ctl` (`09-multiplexar-controlfile.script.log`) en el mismo volumen protege frente al **borrado accidental o corrupción puntual de uno de los archivos**, pero **no protege frente a la pérdida física del disco o volumen completo** (donde caerían los tres a la vez). En producción cada copia de `CONTROL_FILES` debe ubicarse en **discos físicos y controladoras independientes** (o grupos de discos ASM distintos) junto con `CONFIGURE CONTROLFILE AUTOBACKUP ON` en RMAN.

**15. Explica los estados `CURRENT`, `ACTIVE` e `INACTIVE` con tu evidencia 10 y por qué Oracle rechaza los tres borrados del paso 4.**  
En `10-redo.script.log`:
* **`CURRENT`:** Grupo en el que `LGWR` está escribiendo actualmente.
* **`ACTIVE`:** Grupo ya cerrado tras un *log switch*, pero cuyos bloques sucios aún no han sido volcados por completo a los datafiles por `DBWn` (es necesario si cae la instancia).
* **`INACTIVE`:** Grupo cuyos cambios ya están guardados en los datafiles mediante checkpoint; puede sobrescribirse (una vez archivado).  
Oracle rechaza los borrados por integridad: `ORA-01623` (no se puede borrar el grupo `CURRENT`), `ORA-01609` (no se puede borrar el último miembro del grupo `CURRENT`) y `ORA-01567` (toda instancia necesita un **mínimo de 2 grupos** de redo online).

**16. Describe la cadena de causas del escenario de la FRA llena, desde `ORA-19815` hasta que la base deja de aceptar cambios.**  
En `11-fra-llena.script.log`: al reducir la FRA a `2 MB` y generar redo con un `UPDATE`, primero salta el aviso **`ORA-19815`** (100 % de uso de `db_recovery_file_dest_size`); al intentar archivar el grupo lleno, `ARCn` falla con **`ORA-19809`** (*limit exceeded*) y **`ORA-16038`** (*cannot be archived*). Como en modo `ARCHIVELOG` Oracle prohíbe sobrescribir un grupo online que aún no se ha archivado (`ARC = NO`), cuando todos los grupos quedan sin archivar `LGWR` se detiene y las sesiones quedan bloqueadas en el evento **`log file switch (archiving needed)`** (y nuevas conexiones reciben `ORA-00257`) hasta que se amplía la FRA o se liberan archivados con RMAN.

---

### 8.1.5. Undo, WAL y simulacros (Partes M a P)

**17. Explica, con los pasos 1 a 4 de tu evidencia 12, la frase "lectores no bloquean a escritores".**  
En `12-lectura-consistente.script.log`:
* La Sesión A modifica la fila `101` a `'EGRESADO'` sin hacer `COMMIT` (adquiriendo bloqueo `TM` modo 3 en la tabla y `TX` modo 6 en la fila).
* En el paso 1, la Sesión B lee la fila `101` **sin quedar bloqueada** y obtiene el valor confirmado anterior (`'ACTIVO'`), porque Oracle reconstruye una copia consistente del bloque en memoria aplicando la imagen anterior guardada en el segmento de undo (`UNDOTBS1`).
* Solo cuando B intenta **escribir/bloquear** esa misma fila (`SELECT ... FOR UPDATE WAIT 3` en el paso 4) se produce el bloqueo entre escritores (`ORA-00054` / `ORA-40097`).

**18. ¿Por qué un `DELETE` genera más undo que un `INSERT`? ¿Por qué el `ROLLBACK` también genera redo?**  
En `12-undo-y-redo.script.log`, para deshacer un `INSERT` Oracle solo necesita guardar en el undo la instrucción mínima *"borra el ROWID X"*, mientras que para deshacer un `DELETE` tiene que copiar en el undo **todos los valores de la fila completa borrada** (más sus entradas de índice) para poder reinsertarla si hay rollback. Y el `ROLLBACK` también genera redo porque deshacer consiste en **aplicar cambios inversos sobre los bloques de datos e índices** en el Buffer Cache, y por la regla *Write-Ahead Logging* toda modificación de bloques debe quedar registrada en el redo log.

**19. Con tu evidencia 13: ¿dónde está la garantía de durabilidad justo después del `COMMIT`? ¿Y después del checkpoint?**  
En `13-lgwr-dbwn.script.log`:
* **Justo después del `COMMIT` (Paso 1):** La garantía está en los **online redo logs en disco**, escritos secuencialmente por `LGWR`, mientras que los `231` bloques modificados de la tabla siguen sucios (`dirty = Y`) en la memoria SGA (`0` escrituras de `DBWn`).
* **Después de `ALTER SYSTEM CHECKPOINT` (Paso 2):** `DBWn` vuelca todos los bloques sucios (`580` bloques de la instancia) a los **datafiles en disco** (`bloques_sucios_tabla` baja a `0`) y `CKPT` actualiza el SCN en las cabeceras y el control file.

**20. Simulacro A: explica *roll forward* y *roll back* con las filas 102 y 103 y las líneas del alert log.**  
En `14a-caida-instancia.script.log`, tras `SHUTDOWN ABORT` (corte brusco sin checkpoint), al ejecutar `STARTUP` el proceso `SMON` realiza automáticamente la recuperación de instancia (`Beginning crash recovery`):
1. ***Roll forward* (rehacer):** Lee el redo online desde el último checkpoint (`Started redo scan` / `redo application`) y reaplica todos los cambios registrados, tanto la fila `102` (confirmada) como la `103` (sin confirmar) y sus bloques de undo.
2. **Apertura y *Roll back* (deshacer):** Abre la base y utiliza el undo reconstruido para deshacer las transacciones no confirmadas: la fila `102` conserva `'EGRESADO'` (**durabilidad**) y la fila `103` vuelve a `'ACTIVO'` (**atomicidad**).

**21. Simulacros C y D: tu RTO y tu RPO en cada uno. ¿Por qué son tan distintos?**  
* **Simulacro C (`14c-simulacro-restauracion.script.log`, restauración completa en frío tras `DROP ... PURGE`):** El **RTO** fue de casi **1 minuto** (parada, descompresión de todo el volumen de cientos de MB y arranque completo) y el **RPO** equivale a todo el tiempo transcurrido desde la última copia completa (se pierden los cambios posteriores a la copia).
* **Simulacro D (`14d-perdida-datafile.script.log`, recuperación de medio con RMAN + `ARCHIVELOG`):** El **RTO** fue de **`35 s` (`41 s` desde el fallo)** y el **RPO fue `0`** (la fila `104` conservó `'EGRESADO'`, confirmado después de la copia).  
Son tan distintos porque RMAN restaura **únicamente el datafile dañado (`academia01.dbf`)** sin tocar el resto del volumen, y el modo `ARCHIVELOG` permite aplicar todos los cambios confirmados posteriores a la copia hasta el último segundo.

**22. Clasifica cada error `ORA-` del bloque 5 de tu runbook: incidente real, efecto del laboratorio o ruido conocido.**  
Según `15-healthcheck.spool.log` (bloque 5):
* **`ORA-63999`, `ORA-01116`, `ORA-01110`, `ORA-01113`:** **Efecto esperado del laboratorio** (provocados deliberadamente en el Simulacro D al borrar `academia01.dbf` para probar la recuperación RMAN; tras el `RECOVER` y reapertura quedaron resueltos).
* **`ORA-20013` (y `ORA-00800`):** **Ruido conocido del entorno contenedor** (avisos benignos de `DBMS_QOPATCH` y `CAP_SYS_NICE` en Docker que no afectan al servicio).
* **Incidentes reales pendientes:** **Ninguno** (`0` errores no controlados).

---

## 2. Tabla de Retrospectiva Game Day (Parte O) y Blameless Postmortem (Parte L.3)

### Tabla resumen de los cuatro simulacros (Parte O)

| Simulacro | Fallo provocado | RTO medido | RPO real | Qué ocurrió / Aprendizaje SRE |
| :--- | :--- | :--- | :--- | :--- |
| **A (`14a`)** | Caída brusca de instancia (`SHUTDOWN ABORT`) | ~10–15 s (tiempo de `STARTUP`) | **`0`** | `SMON` ejecutó *roll forward* + *roll back* automático; la fila `102` (confirmada) sobrevivió y la `103` (sin commit) se deshizo. |
| **B (`14b`)** | Borrado de `control03.ctl` | ~10 s (copia en `NOMOUNT` + `OPEN`) | **`0`** | La instancia paró en `NOMOUNT` con `ORA-00205`; gracias a la multiplexación bastó copiar `control01.ctl` sobre `control03.ctl`. |
| **C (`14c`)** | `DROP TABLE` sin `PURGE` y con `PURGE` | ~2 s (Flashback) / ~50–60 s (Restore completo) | `0` (Flashback) / Tiempo desde copia (Restore) | `FLASHBACK TABLE` recupera en segundos desde papelera; con `PURGE` sin RMAN hay que restaurar toda la base. |
| **D (`14d`)** | Pérdida física de `academia01.dbf` | **`35 s`** (reparación) / **`41 s`** (desde fallo) | **`0`** | Oracle detectó el fallo (`ORA-63999`), cerró solo `FREEPDB1` (`MOUNTED`) dejando `CDB$ROOT` activa; RMAN restauró y recuperó con `ARCHIVELOG` sin perder la fila `104`. |

### Retrospectiva sin culpables (*Blameless Postmortem* — FRA llena, Parte L.3)

* **Impacto:** Sesiones DML bloqueadas esperando `log file switch (archiving needed)`; **cero pérdida de datos**.
* **Detección:** Las consultas de cambio quedaban en espera sin devolver error inmediato; `v$session` mostró el evento de espera y el alert log registró `ORA-19815` / `ORA-19809` / `ORA-16038`.
* **Causa raíz:** Ejecutar cargas masivas repetidas con `ARCHIVELOG` activo sobre una FRA dimensionada a `4 GB` (o reducida a `2 MB` en la prueba) sin purga ni respaldo periódico de archivados.
* **Mitigación:** Ampliar `db_recovery_file_dest_size` a `4G` y liberar archivados mediante RMAN (`DELETE NOPROMPT ARCHIVELOG ALL` en laboratorio; `BACKUP ARCHIVELOG ALL DELETE INPUT` en producción), nunca con `rm`.
* **Qué cambia:** El runbook diario (`15-healthcheck.sql`, bloque 3) vigila el porcentaje de uso de la FRA para actuar antes de superar el `80 %`.

---

## 3. Simulacro de Examen 1Z0-182 (Preguntas de Parte y Sección 9)

### Preguntas intercaladas (B1 a O4)
* **B1:** **B** — Sin histograma en una columna con distribución sesgada (`estado`, donde `'P'` es el 2 % y `'C'` el 90 %), el optimizador asume distribución uniforme ($1/4 = 25\%$) y estima mal `E-Rows` (Parte B.1).
* **C1:** **C** — `BLEVEL = 2` significa 2 niveles de ramas más 1 nivel de hojas = altura `3` en el índice, más `1` lectura del bloque de la tabla = **`4` lecturas lógicas** (Parte C.1).
* **C2:** **B** — Altura $= 1 + \lceil \log_{500}(2.000.000) \rceil = 1 + \lceil 2,33 \rceil = \mathbf{3}$ (Parte C.1).
* **D1:** **B** — Baja cardinalidad (`6`, `3` y `5` valores) en un almacén de datos con carga nocturna y consultas ad-hoc combinadas es el caso ideal para **índices Bitmap individuales** (Parte D, Q14).
* **D2:** **A y C** — Un índice cubriente evita ir a la tabla (`TABLE ACCESS BY INDEX ROWID`), pero al incluir más columnas ocupa más espacio y encarece cada `INSERT` y `UPDATE` de esas columnas (Parte D y G).
* **E1:** **B** — Con `CLUSTERING_FACTOR` casi igual a los 10 millones de filas, pedir el `3 %` ($300.000$ filas) supondría casi $300.000$ saltos aleatorios frente a los $80.000$ bloques secuenciales de la tabla: gana el **recorrido completo** (Parte E).
* **F1:** **B** — Comparar un `VARCHAR2` (`num_factura`) con un literal numérico (`2025001`) provoca una conversión implícita `TO_NUMBER(num_factura)` sobre la columna e invalida el índice (Parte F, Regla 3).
* **F2:** **A y C** — Dejan la columna `fecha` desnuda usando un rango equivalente desde las `00:00:00` hasta antes del día siguiente sin envolverla en `TRUNC()` ni `TO_CHAR()` (Parte F, Regla 1).
* **G1:** **B** — `ALTER INDEX ... INVISIBLE` hace que el optimizador deje de usarlo mientras Oracle lo sigue manteniendo actualizado, permitiendo volver a `VISIBLE` al instante si algo falla (Parte G.2).
* **G2:** **B** — Según lo medido en la Parte G.1 (`INSERT ≈ 2 + 2 × índices`), cada índice adicional modifica unos `2` bloques por fila (hoja + undo): $500 \times 2 \approx \mathbf{1000\text{ bloques/s}}$.
* **H1:** **B** — `ALTER INDEX ... COALESCE` fusiona las hojas vacías/medio vacías de la izquierda del patrón cola **en línea, sin bloquear** y con mínimo coste (Parte H.3).
* **H2:** **A y C** — Un índice `REVERSE` dispersa claves crecientes evitando contención en la hoja derecha, pero al invertir los bytes pierde el orden lógico y **no sirve para rangos (`BETWEEN`)** (Parte H.1).
* **I1:** **B** — Al abrir, Oracle compara el `CHECKPOINT_CHANGE#` del **control file** con el de la **cabecera de cada datafile** (Parte I).
* **J1:** **B** — Si una de las copias de `CONTROL_FILES` se pierde o corrompe en caliente, la instancia se detiene; hay que sustituirla por una copia sana (o quitarla del SPFILE) y arrancar (Parte J y Simulacro B).
* **J2:** **A y C** — El control file guarda la **ubicación de los datafiles y redo logs** y el **SCN del último checkpoint** (los parámetros van en el SPFILE y las claves en el password file) (Parte J.1).
* **K1:** **C** — Un grupo de redo en estado `ACTIVE` ya no recibe escrituras de `LGWR`, pero sus bloques sucios aún no se han volcado todos a los datafiles y **se necesita para recuperación de instancia** (Parte K).
* **L1:** **B** — Como demostró el paso 2 de `11-activar-archivelog.sh`, fijar `DB_RECOVERY_FILE_DEST` sin haber fijado antes `DB_RECOVERY_FILE_DEST_SIZE` falla con `ORA-19802` (Parte L.1).
* **L2:** **A y C** — Con la FRA llena (`ORA-00257`), las soluciones válidas son **ampliar `DB_RECOVERY_FILE_DEST_SIZE`** o **respaldar y borrar archivados con RMAN (`DELETE INPUT`)**, nunca borrar con `rm` (Parte L.2).
* **M1:** **C** — Por lectura consistente multiversión (MVCC), la Sesión B lee el **valor confirmado anterior reconstruido con el undo** sin quedar bloqueada (Parte M.1).
* **M2:** **C** — `DELETE` guarda en el undo todos los valores de la fila completa eliminada y sus índices, generando mucho más undo que `INSERT` o `UPDATE` (Parte M.2).
* **M3:** **B y D** — `ORA-01555: snapshot too old` se soluciona aumentando `UNDO_RETENTION` y el tamaño de `UNDOTBS1`, o activando `RETENTION GUARANTEE` si la consulta es crítica (Parte M.2).
* **N1:** **A** — `Commit complete` garantiza únicamente que `LGWR` ha escrito el registro de redo en el **redo log online en disco** (Parte N).
* **N2:** **B y C** — `DBWn` escribe bloques sucios de forma diferida en los **checkpoints** y cuando un proceso servidor **no encuentra buffers libres** en el Buffer Cache (Parte N).
* **O1:** **B** — Tras un corte de luz (`SHUTDOWN ABORT`), un `STARTUP` normal dispara automáticamente a `SMON`, que aplica el redo (*roll forward*) y deshace lo no confirmado (*roll back*) (Simulacro A).
* **O2:** **B y D** — Ante `ORA-00205` por pérdida de una de las tres copias del control file, se copia una copia sana sobre la perdida y se monta, o se elimina esa ruta de `CONTROL_FILES` en el SPFILE (Simulacro B).
* **O3:** **B** — En `ARCHIVELOG`, un datafile de aplicación perdido se recupera en caliente poniendo el archivo `OFFLINE`, ejecutando `RESTORE DATAFILE` y `RECOVER DATAFILE` en RMAN y poniéndolo `ONLINE` (Simulacro D).
* **O4:** **D** — Tras un `DROP TABLE ... PURGE` (que salta la papelera), **RMAN `RECOVER TABLE`** hasta un instante previo recupera solo esa tabla usando copias y redo archivado sin afectar al resto de la base (Simulacro C).

---

### Simulacro de examen final (Sección 9: S1 a S26)

* **S1:** **B** — Un `CLUSTERING_FACTOR` cercano al número de filas indica que las filas están desordenadas en disco respecto al índice, obligando a saltar a un bloque distinto en casi cada entrada (Parte E).
* **S2:** **A y C** — Para evitar el `FULL SCAN` por `UPPER(email)`, o bien se crea un índice funcional sobre `UPPER(email)` o bien se reescribe como `WHERE email = LOWER(:e)` aprovechando `ux_cli_email` (Partes D y F).
* **S3:** **B** — Al comparar `VARCHAR2` con un número (`30001`), Oracle aplica `TO_NUMBER()` sobre la columna indexada e inutiliza el índice (Parte F, Regla 3).
* **S4:** **B** — Baja cardinalidad (`4` valores) en un almacén de datos con carga nocturna y consultas diurnas es el escenario ideal para un **índice Bitmap** (Parte D).
* **S5:** **B** — Cuando la primera columna del índice compuesto tiene pocos valores distintos (`5` países) y se filtra por la segunda (`ciudad`), Oracle puede realizar un **`INDEX SKIP SCAN`** (Parte D).
* **S6:** **B** — `ALTER INDEX ... INVISIBLE` oculta el índice al optimizador manteniéndolo actualizado para poder revertir al instante si empeora el rendimiento (Parte G).
* **S7:** **A y C** — En un patrón cola, tanto **`ALTER INDEX ... COALESCE`** como **`ALTER INDEX ... SHRINK SPACE`** compactan las hojas vacías en línea sin bloquear la tabla (Parte H).
* **S8:** **B** — Un `INSERT` de una fila modifica $\approx 2$ bloques en la tabla (dato + undo) más $\approx 2$ bloques por cada índice (hoja + undo): $2 + 3 \times 2 = \mathbf{8\text{ bloques}}$ (Parte G.1).
* **S9:** **B** — `SGA_TARGET` gestiona dinámicamente los pools de la SGA (ASMM), mientras que la PGA se gestiona por separado mediante `PGA_AGGREGATE_TARGET` (Parte B / Lab 4 G).
* **S10:** **B y D** — Al abrir, Oracle compara el SCN de checkpoint del **control file** con la **cabecera de cada datafile**; si la base cayó sin cierre limpio, `SMON` aplica el redo automáticamente (Partes I y O).
* **S11:** **B** — Si una de las copias multiplexadas de `CONTROL_FILES` falla en caliente, la instancia se detiene inmediatamente para evitar inconsistencias (Parte J).
* **S12:** **C** — Un grupo de redo `ACTIVE` aún tiene bloques sucios pendientes de checkpoint en memoria y es imprescindible si ocurre una caída de instancia antes de que `DBWn` los escriba (Parte K).
* **S13:** **B** — El modo de archivado modifica el control file con los datafiles cerrados, por lo que requiere `SHUTDOWN IMMEDIATE`, `STARTUP MOUNT`, `ALTER DATABASE ARCHIVELOG` y `ALTER DATABASE OPEN` (Parte L.1).
* **S14:** **B** — Fijar `DB_RECOVERY_FILE_DEST` sin haber establecido primero `DB_RECOVERY_FILE_DEST_SIZE` falla con `ORA-19802` (Parte L.1).
* **S15:** **B y D** — Cuando la FRA se llena (`ORA-00257`), debe ampliarse `DB_RECOVERY_FILE_DEST_SIZE` o respaldar y borrar archivados con **RMAN (`DELETE INPUT`)**, nunca usar `rm` en el SO (Parte L.2).
* **S16:** **B** — Por lectura consistente multiversión (MVCC), otra sesión ve siempre el último valor **confirmado** reconstruido desde el segmento de undo (Parte M.1).
* **S17:** **C** — `DELETE` guarda en el undo la fila entera eliminada y todas sus entradas de índice, generando mucho más undo que `INSERT` o `UPDATE` (Parte M.2).
* **S18:** **B** — `ORA-01555: snapshot too old` ocurre cuando una consulta larga necesita reconstruir una versión antigua de un bloque y ese undo ya se ha sobrescrito por falta de retención o espacio (Parte M.2).
* **S19:** **B** — Por el protocolo *Write-Ahead Logging*, `COMMIT` espera únicamente a que **`LGWR`** escriba el registro de redo en los *online redo logs*; `DBWn` escribe los datafiles después (Parte N).
* **S20:** **B** — `SHUTDOWN ABORT` no corrompe la base: al ejecutar `STARTUP`, `SMON` realiza la recuperación de instancia automáticamente aplicando redo y deshaciendo lo no confirmado (Parte O.1).
* **S21:** **B** — Un datafile de usuario perdido en `ARCHIVELOG` se aísla con `OFFLINE`, se restaura y recupera con RMAN (`RESTORE` + `RECOVER`) y se vuelve a poner `ONLINE` sin detener la CDB (Parte O.4).
* **S22:** **B** — En una arquitectura Multitenant, si un datafile de una PDB sufre un fallo de medios (`ORA-63999`), Oracle aísla y cierra **únicamente esa PDB (`MOUNTED`)**, manteniendo abierta la `CDB$ROOT` y el resto de PDBs (Parte O.4).
* **S23:** **B** — Si se borra una tabla sin `PURGE`, permanece en la papelera (`DBA_RECYCLEBIN`) y se recupera al instante con `FLASHBACK TABLE ... TO BEFORE DROP` (Parte O.3).
* **S24:** **B** — La vista **`V$DIAG_ALERT_EXT`** permite consultar mediante SQL las entradas del alert log desde el ADR (Parte P.1).
* **S25:** **B** — En una CDB, cada PDB tiene su propio tablespace de undo local (`UNDOTBS1`), pero **todas comparten la instancia (SGA/procesos) y los online redo logs** (Partes I, K y M).
* **S26:** **B** — El índice sobre una clave ajena (`id_cliente` en `PEDIDO`) evita que cada `DELETE` o actualización de clave en la tabla padre (`CLIENTE`) bloquee la tabla hija entera (`TM` share lock) (Parte G.2).
