---
name: "support-jdk8u212"
description: "Permitir compilar DCEVM para HotSpot jdk8u212-b04 sin Mercurial y con VS2017, e instalarlo en el JDK Oracle 1.8.0_212 como altjvm y con el instalador."
created_at: "2026-11-06T12:00:00Z"

created_by:
  tool: "Claude Code"
  model:
    name: "Claude Opus"
    version: "5.5"
    reasoning_effort: "low"

implemented_by:
  tool: "Claude Code"
  model:
    name: "Claude Opus"
    version: "5.5"
    reasoning_effort: "low"
last_implementation_at: "2026-11-06T14:13:58Z"
---

# Soporte de DCEVM para JDK 8u212

## Objetivo

Poder parchear `C:\Workspace\java\jdk1.8.0_212` (Oracle JDK 8u212-b10, Windows x64) con DCEVM. Para ello el build tiene que obtener HotSpot desde Git (hg.openjdk.java.net ya no sirve y no hay Mercurial), compilar con Visual Studio 2017 en lugar del SDK 7.1, disponer de una serie de parches para `jdk8u212-b04` y empaquetar el binario local en el instalador.

## Decisiones

- Se compila desde la etiqueta OpenJDK `jdk8u212-b04` para un JDK Oracle `1.8.0_212-b10`. Es lo mismo que se hacía con 8u181 (fuentes OpenJDK sobre JDK Oracle). El JFR comercial de Oracle (`jfr.jar`) no funcionará con DCEVM.
- Fuentes desde `https://github.com/openjdk/jdk8u.git` (y `https://github.com/openjdk/jdk7u.git` para etiquetas `jdk7`). Ambas URLs se pueden configurar. Se usa un clon en caché, shallow, parcial y sparse (solo `hotspot/`), en `build/hotspot-upstream`, con `core.autocrlf=false` para conservar LF. Su `hotspot/` se copia al directorio `hotspot/` del proyecto. Se descarta clonar el monorepo completo, que pesa varios GB.
- Los parches siguen en `hotspot/.hg/patches` con el mismo formato y el mismo fichero `series`. Así no se mueven ficheros versionados ni cambia `.gitignore`. Se descarta moverlos a `patches/`.
- La selección por guardas reproduce la semántica de mq. Las guardas `#+` exigen que al menos una esté seleccionada y las `#-` excluyen el parche si alguna está seleccionada. Las guardas que se seleccionan son las mismas que hoy (`<flavor>`, `jdk7|jdk8`, `<tag>`, `<flavor>-<tag>`).
- Los parches se aplican con GNU `patch -p1 --fuzz=2`, igual que el fuzz que admite `hg qpush`. Primero se hace un `--dry-run` y, si falla, el proceso se detiene sin aplicar nada de ese parche. Se descarta `git apply`, que no admite fuzz y rechazaría hunks que hoy aplican. El ejecutable se puede configurar (por defecto `patch`, que existe en Git for Windows y en Cygwin).
- Dentro de `hotspot/` se crea un repo Git local, ignorado por el repo externo. Tiene un commit base con la etiqueta y un commit por parche aplicado, y `.hg/` queda en su `info/exclude`. Esto sustituye a `qgoto`/`qrefresh`: `-PpatchUntil=<parche>` detiene la serie tras ese parche, y `refreshPatch` reescribe el último parche aplicado con el diff de las fuentes contra el commit anterior, conservando la cabecera del fichero (líneas previas al primer `diff`).
- Serie 8u212. Se añade `#+light-jdk8u212-b04` a todos los parches que hoy se aplican en 8u202, excepto dos que fallan en 8u212 y se sustituyen por variantes nuevas:
  - `distro-name-java8u212.patch` (upstream eliminó `COMPANY_NAME=`). Para excluir el original, `distro-name.patch` recibe `#-light-jdk8u212-b04`.
  - `arguments-java8u212.patch` (upstream añadió `#ifdef VENDOR_URL_VM_BUG`).
  
  Esto sale de aplicar la serie de 8u202 sobre `jdk8u212-b04` durante la exploración: solo fallaron esos dos hunks.
- `hotspotTag` por defecto pasa a `jdk8u212-b04`.
- Toolchain de Windows: un script común `windows-env.cmd`, usado por `build.cmd` y `native/compile.cmd`, carga `vcvarsall.bat x64|x86` de VS2017. Lo localiza por la variable `VS2017_VCVARSALL` o, si no está, con `vswhere -version [15.0,16.0)`. Cygwin se toma de `CYGWIN_HOME`, por defecto `C:\cygwin`. Si falta algo, el script falla antes de `make`. Los makefiles de HotSpot 8u212 solo asocian a VS2017 las versiones MSC_VER 1912 y 1913 (las 1914 a 1916 se añadieron en updates posteriores), y no reconocen VS2019 ni VS2022. Por eso `build.cmd` fuerza `FORCE_MSC_VER=1912` y `FORCE_LD_VER=1412` para cl 19.16. Además antepone el directorio de las herramientas MSVC al PATH de Cygwin, porque si no nmake usa el `link.exe` de coreutils, y vacía `NoDefaultCurrentDirectoryInExePath`, porque nmake ejecuta `adlc` desde el directorio actual.
- Riesgo: HotSpot 8u212 no se ha compilado nunca con este toolchain en esta máquina, que no tiene Visual Studio, Cygwin ni Mercurial. La fase 2 puede destapar ajustes de makefile que hoy no se pueden prever.
- Riesgo: al instalar como JVM por defecto, el `classes.jsa` de Oracle en `jre\bin\server` no corresponde al `jvm.dll` de DCEVM, así que CDS queda desactivado. Solo afecta al tiempo de arranque.
- Instalador con binario local: `copyData` admite `-PuseLocalBuild`, que copia `hotspot/build/product/jvm.dll` a `data/<os>_<arch>_compiler2/product/`, la ruta que busca el instalador. Se descarta simular la estructura de `rawdata` del servidor de build.
- Fuera del alcance: compilar o probar versiones posteriores a 8u212 (JFR desde 8u262), JDK 7, Linux y macOS (más allá de no romper la selección de parches), versiones de 32 bits, publicar binarios y modernizar Gradle.

## Fases

### Fase 1: Parcheo de HotSpot 8u212 sin Mercurial

`./gradlew patch` obtiene HotSpot `jdk8u212-b04` desde GitHub y le aplica la serie light sin Mercurial. Los parches se pueden regenerar.

#### Contratos

```properties
# gradle.properties (repo dcevm). Nuevas claves, sobrescribibles con -P
hotspotTag=jdk8u212-b04
hotspotGitRepository8=https://github.com/openjdk/jdk8u.git
hotspotGitRepository7=https://github.com/openjdk/jdk7u.git
patchExecutable=patch
# Opcional, solo por línea de comandos: -PpatchUntil=<nombre.patch>
```

```groovy
// build.gradle (repo dcevm), proyecto :hotspot
task fetchSources                 // caché sparse de hotspot/ para hotspotTag; falla nombrando la etiqueta si no existe
task patch(dependsOn: fetchSources) // limpia hotspot/ (salvo .hg/patches), copia fuentes, commit base, aplica la serie seleccionada
task refreshPatch                 // reescribe el último parche aplicado con el diff actual y rehace su commit
List<String> selectPatches(File series, List<String> guards) // semántica mq #+ / #-
```

```text
# hotspot/.hg/patches/series (repo dcevm)
distro-name.patch #-light-jdk8u212-b04
distro-name-java8u212.patch #+light-jdk8u212-b04
arguments-java8u212.patch #+light-jdk8u212-b04
# + #+light-jdk8u212-b04 en los 8 parches compartidos con 8u202
```

#### Tests

- `:hotspot:patch -PhotspotTag=jdk8u212-b04`: obtiene las fuentes sin hg, aplica la serie sin rechazos y deja un commit por parche.
- `:hotspot:patch -PhotspotTag=jdk8u202-b08`: selecciona la misma lista de parches que hoy (se compara con la lista calculada a mano de `series`) y aplica sin rechazos.
- `:hotspot:patch -PhotspotTag=jdk8u999-b99`: falla nombrando la etiqueta.
- Rechazo de hunk: se aplica `-PhotspotTag=jdk8u212-b04` con el `series` temporal de 8u202 (sin las variantes 8u212) y debe fallar nombrando `distro-name.patch` y `make/openjdk_distro`.
- `refreshPatch`: con `-PpatchUntil=arguments-java8u212.patch` se edita un fichero, se regenera y un `patch` desde cero reproduce el cambio.

- [x] Añadir las claves nuevas a `gradle.properties`, poner `hotspotTag=jdk8u212-b04` y conservar la lista comentada de etiquetas (seguir el estilo actual del fichero).
- [x] Implementar `selectPatches` en `build.gradle` con semántica mq `#+`/`#-`. Las guardas se calculan como en la tarea `patch` actual (`build.gradle:101`).
- [x] Implementar `fetchSources`: `git init` en `build/hotspot-upstream`, `core.autocrlf=false`, sparse-checkout `hotspot`, `git fetch --depth 1 --filter=blob:none origin refs/tags/<tag>` y checkout. Usar `exec` de Gradle 2.4 como en `checkMercurial`/`pull` (`build.gradle:33-75`).
- [x] Reescribir `patch`: borrar `hotspot/` salvo `.hg/patches`, copiar las fuentes, `git init` local con `.hg/` en `info/exclude`, commit base y, por cada parche seleccionado, `patch --dry-run` y luego aplicar con commit. Detenerse en `patchUntil`. Al fallar, mostrar el nombre del parche y los ficheros con hunks rechazados.
- [x] Implementar `refreshPatch`: conservar la cabecera del fichero, escribir `git diff HEAD~1` con prefijos `a/` y `b/` y rehacer el commit con `--amend`.
- [x] Eliminar `checkMercurial`, `init` y `pull`.
- [x] Crear `distro-name-java8u212.patch` y `arguments-java8u212.patch` con `refreshPatch` sobre `jdk8u212-b04` (mismo contenido funcional que `distro-name.patch` y `arguments-java8u40.patch`) y actualizar `series`.
- [x] Revisar los hunks que entran con fuzz en 8u212 (`gc-java8u40.patch` y `light-jdk8u201-b09.patch`) y confirmar que quedan en la función correcta.
- [x] Actualizar `docs/agents/hotspot-patches.md`, `docs/agents/building.md`, `AGENTS.md` y `README.md`: Mercurial deja de ser necesario, `patchUntil`/`refreshPatch` sustituyen a `qgoto`/`qrefresh`, y se explican las guardas `#-`.
- [x] Verifica los cambios en cuanto a comprobación de tipos, linting y pruebas utilizando el comando de verificación del proyecto. Busca el comando en el archivo AGENTS.md o en la configuración del proyecto. Corrige cualquier problema que aparezca.

### Fase 2: Compilación con VS2017 e instalación como altjvm

Se compila `jvm.dll` para 8u212 con VS2017, se instala como `-XXaltjvm=dcevm` en `C:\Workspace\java\jdk1.8.0_212\jre` y se pasa la suite de redefinición.

#### Contratos

```bat
:: windows-env.cmd (repo dcevm). Entrada: ARCH=x64|x86. Variables opcionales:
::   VS2017_VCVARSALL=<ruta a vcvarsall.bat>   (si no, vswhere -version [15.0,16.0))
::   CYGWIN_HOME=<ruta a Cygwin>              (por defecto C:\cygwin)
:: Salida: entorno de cl/link cargado y CYGWIN_HOME validado; exit /b 1 con mensaje si falta algo
```

```bat
:: build.cmd y native\compile.cmd (repo dcevm): llaman a windows-env.cmd en lugar de setenv.cmd del SDK 7.1
```

#### Tests

- `:hotspot:compileProduct` y `:hotspot:installProduct -Pjre=C:/Workspace/java/jdk1.8.0_212/jre -PtargetJre=C:/Workspace/java/jdk1.8.0_212/jre`: `java -XXaltjvm=dcevm -version` muestra `1.8.0_212` y `Dynamic Code Evolution`, y `java -version` sigue mostrando la JVM de Oracle.
- `./gradlew test` con Gradle ejecutándose sobre el JDK 8u212: la suite de `dcevm/` (redefinición, incluida `SimpleNativeTest`) pasa según `dcevm/build/test-results/`, ya que `ignoreFailures = true`.
- `build.cmd` sin VS2017 detectable (`VS2017_VCVARSALL` apuntando a una ruta inexistente): falla antes de `make` con el mensaje de configuración.

- [x] Crear `windows-env.cmd` (detección con vswhere, validación de `CYGWIN_HOME`, mensajes de error) y usarlo desde `build.cmd` (sustituir las líneas 1-5) y `native/compile.cmd`.
- [x] Instalar en la máquina VS2017 Build Tools (componente VC x64 y Windows 10 SDK) y Cygwin con `make`, `zip`, `unzip`, `gawk` y `findutils`, y anotar los requisitos en `docs/agents/building.md`.
- [x] Compilar `product` y `fastdebug` de 8u212 y corregir los fallos de makefile o de compilación que aparezcan con VS2017. Los ajustes en fuentes de HotSpot van en un parche nuevo guardado con `#+light-jdk8u212-b04`, y los de build en `build.cmd`/`windows-env.cmd`.
- [x] Instalar como altjvm en `C:\Workspace\java\jdk1.8.0_212\jre` y ejecutar la suite. Revisar `dcevm/build/reports/tests/index.html` y documentar en `docs/agents/testing.md` las pruebas que fallen y no se arreglen en este cambio.
- [x] Verifica los cambios en cuanto a comprobación de tipos, linting y pruebas utilizando el comando de verificación del proyecto. Busca el comando en el archivo AGENTS.md o en la configuración del proyecto. Corrige cualquier problema que aparezca.

### Fase 3: Instalador con el binario local

`./gradlew :installer:jar -PuseLocalBuild` genera el instalador con el `jvm.dll` de 8u212. Con él se instala y desinstala DCEVM en el JDK 1.8.0_212.

#### Contratos

```groovy
// installer/build.gradle (repo dcevm)
// -PuseLocalBuild: copyData toma <root>/hotspot/build/product/<libjvm> en lugar de build/rawdata
// destino: build/data/${os.buildPath}_${arch.buildArch}_${compiler}/product/<libjvm>
// sin binario local: GradleException("No hay DCEVM product compilado: ejecuta :hotspot:compileProduct")
task copyData
```

#### Tests

- `:installer:jar -PuseLocalBuild`: el jar contiene `windows_amd64_compiler2/product/jvm.dll`. Lo comprueba una tarea de verificación del propio build sobre el jar.
- `:installer:jar -PuseLocalBuild` sin `hotspot/build/product/jvm.dll`: falla con el mensaje indicado.
- Aceptación manual con el jar: se añade `C:\Workspace\java\jdk1.8.0_212`, se instala como JVM por defecto (`java -version` muestra `Dynamic Code Evolution` y existe el respaldo de `jvm.dll`), se desinstala (vuelve la JVM de Oracle) y se instala como altjvm.

- [ ] Ampliar `copyData` en `installer/build.gradle` con la rama `useLocalBuild`. Tomar `os`, `arch` y `compiler` del proyecto raíz, igual que `compileProduct` (`build.gradle:121-127`). La ruta de recurso debe coincidir con `ConfigurationInfo.WINDOWS` (`windows_amd64_compiler2`) y con `Installer.installClientServer` (`<resourcePath>/product/<lib>`).
- [ ] Añadir la comprobación del contenido del jar y documentar `-PuseLocalBuild` en `docs/agents/building.md`.
- [ ] Ejecutar la aceptación manual del instalador sobre `C:\Workspace\java\jdk1.8.0_212` y dejar el JDK en el estado que elija el usuario.
- [ ] Verifica los cambios en cuanto a comprobación de tipos, linting y pruebas utilizando el comando de verificación del proyecto. Busca el comando en el archivo AGENTS.md o en la configuración del proyecto. Corrige cualquier problema que aparezca.

## Siguiente paso

Fase 2 completada: DCEVM 8u212 se compila con VS2017, está instalado como `-XXaltjvm=dcevm` en `C:\Workspace\java\jdk1.8.0_212\jre` y la suite pasa (96 tests, 0 fallos, 11 con `@Ignore`). Ejecuta `/openspec-apply-change` para implementar la Fase 3 (instalador con el binario local).
