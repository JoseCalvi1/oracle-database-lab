1. ¿Cuál es la diferencia entre Working Directory, Staging Area y Local Repository? Da un ejemplo de un archivo pasando por las tres.

Working Directory: Es tu directorio de trabajo físico en el disco duro, donde editas y modificas los archivos.

Staging Area: Es una zona de preparación intermedia donde añades los archivos que quieres incluir en tu próximo commit usando git add.

Local Repository: Es el historial permanente guardado en tu ordenador (dentro de la carpeta oculta .git), donde los cambios se registran de forma inmutable usando git commit.

Ejemplo: Creas un archivo notas.txt (Working Directory), lo preparas ejecutando git add notas.txt (Staging Area) y guardas la versión en el historial con git commit -m "add notas" (Local Repository).

2. Si modificas un archivo pero no haces git add, ¿aparece ese cambio en tu próximo commit? Explica por qué.
No. El comando git commit solo empaqueta y guarda los archivos que han sido previamente añadidos a la Staging Area. Si no haces git add, Git detectará que hay archivos modificados sin seguimiento y el commit no los incluirá.

3. ¿Por qué git status no mostraba las carpetas vacías que creaste en la Parte C? ¿Qué truco usamos para solucionarlo?
Git está diseñado para rastrear el contenido de los archivos, no la estructura de los directorios vacíos. Para obligar a Git a rastrear esas carpetas, usamos el truco de crear dentro de ellas un archivo oculto vacío llamado .gitkeep.

4. Explica con tus palabras qué es HEAD.
HEAD es un puntero interno de Git que indica en qué commit y en qué rama exacta te encuentras trabajando en este momento. Si cambias de rama o viajas a un commit antiguo, HEAD se mueve para señalar esa nueva ubicación.

5. ¿Qué diferencia hay entre crear una branch con git switch -c y crear una carpeta nueva con mkdir? ¿Cómo lo comprobamos en la Parte G?
El comando mkdir crea una carpeta física y real en tu disco duro. En cambio, una rama de Git (git switch -c) es simplemente un puntero hacia un commit, no duplica archivos ni crea carpetas nuevas. Lo comprobamos al alternar entre la rama main y feature/customer-search; al cambiar de rama, Git reescribía instantáneamente nuestro Working Directory haciendo que el archivo customer-search.md apareciera y desapareciera sin crear carpetas adicionales.

6. Durante el conflicto de la Parte H, ¿qué representaba el contenido entre <<<<<<< HEAD y =======? ¿Y entre ======= y >>>>>>>?
El bloque entre <<<<<<< HEAD y ======= representaba la versión del código que teníamos en nuestra rama actual (la versión local en main). El bloque entre ======= y >>>>>>> fix/readme-subtitle mostraba la versión "entrante" de la rama que estábamos intentando fusionar y que colisionaba con la nuestra.

7. ¿Por qué NO se debe hacer git commit --amend sobre un commit que ya se subió con git push?
Porque el comando --amend reescribe la historia de Git: destruye el commit anterior y genera uno completamente nuevo con un identificador distinto. Si ese commit ya estaba en el servidor, otras personas podrían haberlo descargado; al reescribirlo, provocarías historiales incompatibles y asincronías graves en el equipo.

8. Si borras por accidente la carpeta .git de tu proyecto, ¿qué se pierde exactamente? ¿Se pierde también el código fuente que está en el disco?
Si borras la carpeta .git, pierdes toda la infraestructura interna del control de versiones: el historial de commits, las ramas, la configuración y el enlace con el repositorio remoto. Sin embargo, tu código fuente (los archivos físicos en el Working Directory) se mantiene completamente intacto en tu disco duro. El proyecto simplemente deja de ser un repositorio Git.

9. Explica con tus propias palabras la diferencia entre Git y GitHub, sin usar la palabra "nube".
Git es el programa de control de versiones que instalas localmente en tu ordenador para registrar el historial de cambios de tu código. GitHub es una plataforma web, operada por Microsoft, que te ofrece servidores remotos para alojar copias de tus repositorios Git, facilitando la colaboración con otros desarrolladores y la visualización de tu código a través del navegador.

10. ¿Por qué no se debe subir un archivo .env con contraseñas reales a un repositorio, aunque el repositorio sea privado?
Porque el código fuente suele ser accesible por múltiples desarrolladores del equipo, sistemas de integración continua (CI/CD) o herramientas de terceros. Si se filtran los permisos de acceso al repositorio o alguien descarga el código en un equipo comprometido, las credenciales reales de la base de datos quedarían expuestas. Las contraseñas deben inyectarse de forma segura directamente en el servidor de producción.

11. Un compañero te dice: "hice push y ahora GitHub me rechaza el segundo push con 'non-fast-forward'". ¿Qué ha ocurrido probablemente y qué comando ejecutarías primero?
Ese error significa que el repositorio remoto en GitHub tiene commits nuevos que el compañero no tiene en su historial local (por ejemplo, alguien más subió cambios a la misma rama). Para solucionarlo, primero debe ejecutar git pull para descargar e integrar los cambios del servidor en su equipo. Una vez sincronizado, podrá hacer git push de sus propios cambios.

12. ¿Qué tipo de Conventional Commit (feat, fix, docs, test…) usarías para: añadir un índice de rendimiento a una tabla, corregir una restricción mal definida, y actualizar el README?

Añadir un índice de rendimiento a una tabla: perf (o feat dependiendo del estándar interno, pero perf es el más preciso para mejoras de rendimiento).

Corregir una restricción mal definida: fix.

Actualizar el README: docs.