# Lab 3 — Preguntas de comprobación

## 8.1.1. Docker

### 1. ¿Qué diferencia hay entre una imagen y un contenedor? Usa como ejemplo lo que hiciste en los ejercicios G2 y G4.
Una **imagen** es una plantilla estática e inmutable de solo lectura que contiene el código, las librerías y el sistema de archivos necesarios para ejecutar un software, mientras que un **contenedor** es una instancia en ejecución (o detenida) creada a partir de esa imagen con su propia capa de escritura y procesos activos. Por ejemplo, en el ejercicio G2 descargamos la imagen base (`hello-world` / `alpine`) y en el ejercicio G4 lanzamos múltiples contenedores independientes a partir de una misma imagen (como el servidor web `nginx`), comprobando que una sola imagen sirve de molde para crear varios contenedores aislados.

### 2. En el Ejercicio G5 el archivo `nota.txt` desapareció y en el G6 no. Explica por qué.
En el **Ejercicio G5**, el archivo `nota.txt` se creó dentro de la capa efímera de escritura del propio contenedor; al ejecutar `docker rm` para borrar el contenedor, esa capa temporal se destruyó junto con él. En cambio, en el **Ejercicio G6** montamos un **volumen nombrado de Docker** (`-v`), el cual almacena los datos en el disco del sistema anfitrión de forma independiente al ciclo de vida del contenedor, permitiendo que `nota.txt` persistiera aunque borrásemos y recreásemos el contenedor.

### 3. ¿Qué diferencia hay entre `docker ps` y `docker ps -a`, y qué significa `STATUS = Exited (0)`?
El comando `docker ps` muestra únicamente los contenedores que están actualmente en ejecución (*running*), mientras que `docker ps -a` lista absolutamente todos los contenedores existentes, incluyendo los detenidos o finalizados. Un estado `STATUS = Exited (0)` significa que el proceso principal del contenedor terminó su ejecución de forma normal y sin errores (código de salida `0` en estándar POSIX).

### 4. En `-p 8181:8181`, ¿qué número corresponde a tu equipo y cuál al contenedor? ¿Qué pasaría con `-p 80:8080` en el ejercicio de nginx?
El formato es `-p <puerto_host>:<puerto_contenedor>`: el primer `8181` corresponde al puerto de nuestro equipo anfitrión (Windows/WSL2) y el segundo `8181` al puerto interno donde escucha el servicio dentro del contenedor. Si en el ejercicio de `nginx` (que por defecto escucha en el puerto interno `80` del contenedor) pusiéramos `-p 80:8080`, entraríamos por el puerto `80` de nuestro navegador y Docker redirigiría el tráfico al puerto `8080` del contenedor, donde `nginx` no está escuchando, por lo que la conexión fallaría.

### 5. ¿Por qué un contenedor de Oracle se queda en marcha y el de `hello-world` termina solo?
Un contenedor de Docker permanece encendido únicamente mientras su proceso principal (`PID 1`) siga activo en primer plano. El contenedor `hello-world` ejecuta un binario que imprime un mensaje en pantalla y finaliza inmediatamente, deteniendo el contenedor; en cambio, el contenedor de Oracle arranca el listener y los procesos de fondo de la instancia manteniendo un script de supervisión activo de forma indefinida en primer plano.

### 6. ¿Qué es el digest de una imagen y por qué lo registramos si ya sabemos que usamos `:latest`?
El *digest* es una huella criptográfica única e inmutable (`sha256:...`) calculada a partir del contenido exacto de la imagen. Lo registramos en las evidencias porque la etiqueta `:latest` es dinámica y cambia cada vez que Oracle publica una actualización; guardar el *digest* garantiza trazabilidad y reproducibilidad exacta de qué versión binaria se utilizó en el laboratorio.

### 7. ¿Qué comando borraría realmente los datos de Oracle? ¿Por qué `docker rm oralab-26ai` no lo hace?
El comando que borraría realmente los datos de la base de datos es `docker volume rm oralab-26ai-data` (o `docker rm -v` si fuera un volumen anónimo). Ejecutar `docker rm oralab-26ai` solo elimina la carcasa del contenedor, pero respeta intacto el volumen nombrado donde están montados los *datafiles*, *control files* y *redo logs* en `/opt/oracle/oradata`.

---

## 8.1.2. Git, organización y evidencia

### 8. ¿Por qué este laboratorio se hace dentro del repositorio `oracle-database-lab`, con Issue, branch y Pull Request, en vez de en una carpeta aparte?
Porque aplicamos metodologías profesionales de ingeniería de software y administración de bases de datos (*Database Reliability Engineering* / GitOps)[cite: 6]. Trabajar con un Issue, una rama dedicada (`chore/5-install-oracle-environment`) y un Pull Request permite mantener todo el código de infraestructura, scripts de despliegue, migraciones y bitácoras de auditoría centralizados, trazables y revisables en un único repositorio evolutivo[cite: 6].

### 9. ¿Qué diferencia hay entre `source 00-config.sh` y `bash 00-config.sh`? ¿Por qué usamos `source`?
Ejecutar `bash 00-config.sh` abre un subproceso (*subshell*) nuevo, define allí las variables y, al terminar el script, cierra el subproceso perdiéndose todas las variables en nuestra terminal actual. En cambio, `source 00-config.sh` ejecuta los comandos directamente en nuestra sesión de shell actual, manteniendo disponibles las variables de entorno (`$CONT_NAME`, `$VOL_NAME`, `$EVID`, función `ts`) para los comandos siguientes.

### 10. Explica cada parte del nombre `20260915T091230Z_02-docker.script.log`.
* **`20260915`:** Fecha en formato ISO 8601 (año 2026, mes 09, día 15).
* **`T`:** Separador estándar entre fecha y hora.
* **`091230`:** Hora exacta (09 horas, 12 minutos, 30 segundos).
* **`Z`:** Indicador de zona horaria UTC (*Zulu time*), que asegura orden cronológico universal sin ambigüedades de huso horario.
* **`_02-docker`:** Número secuencial de la evidencia (`02`) y nombre descriptivo de la tarea verificada (`docker`).
* **`.script.log`:** Extensión compuesta que indica que es un archivo de registro (`.log`) generado a partir de la salida de un script de bash (`.script`).

### 11. ¿Para qué sirve `.gitattributes` y qué error evita?
El archivo `.gitattributes` define reglas sobre cómo Git debe tratar los archivos según su extensión, especialmente los saltos de línea (`eol=lf`). Evita el clásico error en entornos mixtos Windows/Linux donde Git convierte automáticamente los saltos de línea de `LF` a `CRLF` (`\r\n`), lo cual corrompe los scripts `.sh` y `.sql` provocando fallos como `bad interpreter: /bin/bash^M` al ejecutarlos en Linux o dentro del contenedor.

### 12. ¿Por qué en este Pull Request elegimos `Create a merge commit` en lugar de `Squash and merge`?
Porque `Create a merge commit` conserva intacto todo el historial cronológico de commits individuales que realizamos en la rama de trabajo (un commit por cada evidencia del paso 01 al 13), lo que permite al profesor auditar cuándo y cómo se completó cada etapa. Si usáramos `Squash and merge`, todos los commits se aplastarían en uno solo, perdiéndose la trazabilidad paso a paso.

---

## 8.1.3. Seguridad

### 13. Describe las cuatro capas de la estrategia de contraseñas (Parte D) y qué pasaría si te saltas la primera.
1. **Capa 1 (`.gitignore`):** Ignorar el archivo `config/.env` en Git antes de crearlo para que jamás pueda ser rastreado ni subido por accidente.
2. **Capa 2 (`config/.env.example`):** Subir al repositorio una plantilla sin contraseñas reales que documente qué variables requiere el proyecto.
3. **Capa 3 (`config/.env` con `chmod 600`):** Guardar las credenciales reales en un archivo local con permisos restringidos únicamente al propietario.
4. **Capa 4 (Inyección por variables de entorno):** Cargar el archivo en memoria (`source config/.env`) y pasar las variables (`$ORACLE_PWD`) a los comandos sin escribirlas en el código ni en los scripts.
Si nos saltamos la primera capa, corremos el riesgo de ejecutar un `git add .` y subir nuestras contraseñas reales al repositorio de GitHub.

### 14. ¿Por qué no escribimos la contraseña directamente en el comando `docker run`, aunque el script no se suba a Git?
Porque si escribimos la contraseña en texto plano directamente en la línea de comandos o dentro de un script, quedará expuesta en el historial de la terminal (`~/.bash_history`), en los logs de evidencia generados con `tee` (que sí se suben a Git) y en la lista de procesos del sistema operativo (`ps aux`).

### 15. Si descubres tu contraseña en un commit ya publicado, ¿basta con borrarla en un commit nuevo? ¿Qué debes hacer?
No basta con borrarla en un commit nuevo, porque Git conserva todo el historial y cualquiera puede consultar el commit anterior para ver la contraseña expuesta. En ese caso, primero se debe **considerar la contraseña comprometida y cambiarla/rotarla inmediatamente** en el servidor o base de datos, y después limpiar el historial del repositorio (usando herramientas como `git filter-repo` o BFG) y forzar la actualización remota.

---

## 8.1.4. Oracle y herramientas

### 16. ¿Por qué no usamos `SPOOL` ni `@archivo.sql` con `sqlplus` dentro del contenedor, y qué hicimos en su lugar?
Porque los archivos `.sql` y la carpeta de evidencias `docs/bitacora/evidencia/spool/` residen en nuestro sistema anfitrión (Ubuntu WSL2) y no dentro del sistema de archivos aislado del contenedor de Docker. En su lugar, inyectamos el contenido de los scripts SQL desde Ubuntu a través de la entrada estándar (`docker exec -i ... sqlplus ... < archivo.sql` o mediante bloques *heredoc* `<< 'EOF'`) y capturamos la salida estándar desde fuera con `tee` hacia la carpeta de evidencias de nuestro repositorio.

### 17. ¿Qué hace `WHENEVER SQLERROR EXIT SQL.SQLCODE` al inicio de V000 y V001, y qué pasaría sin esa línea?
Esa directiva le ordena a SQL*Plus que, si ocurre cualquier error en una sentencia SQL o bloque PL/SQL, detenga inmediatamente la ejecución del script y devuelva al sistema operativo un código de salida distinto de cero (el código del error de Oracle). Sin esa línea, SQL*Plus ignoraría el fallo, continuaría ejecutando el resto del archivo y terminaría devolviendo código `0` (éxito), haciendo creer a nuestros scripts de despliegue que la migración se aplicó bien cuando en realidad falló.

### 18. ¿Qué es una migración y por qué V000 y V001 no se deben editar una vez aplicadas?
Una migración es un script versionado y secuencial que aplica un cambio estructural o de datos controlado sobre el esquema de la base de datos (como crear las tablas en `V000` o insertar datos semilla en `V001`). No se deben editar una vez aplicadas porque representan el historial inmutable de evolución de la base de datos; si hay que cambiar algo posteriormente, se debe crear una nueva migración (`V002`) para que todos los entornos mantengan exactamente el mismo estado reproducible.

### 19. ¿Por qué en SQL Developer se usa el servicio `FREEPDB1` y no `FREE` ni un SID?
En la arquitectura *Multitenant* de Oracle moderna, `FREE` corresponde a la base de datos contenedora raíz (`CDB$ROOT`), la cual está reservada para metadatos del sistema y administración global, mientras que `FREEPDB1` es la base de datos conectable (*Pluggable Database* o PDB) donde realmente viven los usuarios de aplicación como `alumno` y las tablas de negocio. Además, las conexiones a una PDB exigen utilizar **Service Name** (`FREEPDB1`) en lugar del antiguo identificador de instancia (SID).

### 20. ¿Qué aporta SQLcl frente a SQL*Plus, y por qué un DBA debe dominar ambas?
**SQLcl** aporta comodidades modernas de productividad: autocompletado con tabulador, historial de comandos navegable con las flechas, formatos de salida directos (`SET SQLFORMAT ansiconsole`, `json`, `csv`) y comandos exclusivos como ` repeat`, `ddl` o `info`. Sin embargo, un DBA debe dominar ambas porque **SQL*Plus** viene preinstalado de serie en absolutamente cualquier servidor o contenedor de Oracle del mundo sin requerir Java, siendo indispensable en servidores de producción minimalistas o tareas de emergencia.

---

## 8.1.5. Entorno de trabajo

### 21. ¿Por qué el curso pasa de Git Bash a Ubuntu en WSL 2? Da al menos dos problemas concretos de Git Bash que desaparecen en Ubuntu.
El curso da el salto a Ubuntu sobre WSL 2 porque proporciona un kernel Linux real y un entorno nativo idéntico al de los servidores de producción donde se administra Oracle. Dos problemas concretos de Git Bash (MinGW/MSYS2) que desaparecen en Ubuntu son:
1. **La conversión automática de rutas POSIX** (por ejemplo, cuando pasamos rutas internas como `/opt/oracle` o parámetros a `docker exec`, Git Bash las traduce erróneamente a rutas de Windows tipo `C:/Program Files/Git/opt/oracle`).
2. **Los problemas de interactividad TTY (`winpty`) y carencia de gestor de paquetes Linux (`apt`)**, que en Git Bash impiden ejecutar contenedores interactivos con normalidad o instalar herramientas nativas de servidor.

### 22. ¿Por qué clonamos el repositorio en `~/oracle-database-lab` y no trabajamos sobre la carpeta de Windows (`/mnt/c/...`)? ¿Y por qué recomendamos `bash` frente a `zsh` para los scripts del curso?
Clonamos el repositorio dentro del sistema de archivos nativo de Linux (`~/oracle-database-lab`, formato `ext4`) porque trabajar sobre `/mnt/c/...` obliga a cruzar el puente de red/traducción 9P entre WSL 2 y el sistema NTFS de Windows, lo que degrada drásticamente el rendimiento de Git y Docker y provoca conflictos de permisos (`chmod`) y finales de línea (`CRLF`). Recomendamos **bash** frente a `zsh` porque `bash` es el estándar universal preinstalado en los servidores empresariales Linux y en los contenedores de Oracle, garantizando que nuestros scripts (`#!/usr/bin/env bash`) se comporten exactamente igual en local, en CI/CD y en producción.
