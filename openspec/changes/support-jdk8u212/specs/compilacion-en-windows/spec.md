## Purpose

Compilar DCEVM y la librería nativa de pruebas en Windows x64 con un toolchain de Visual Studio actual soportado por HotSpot 8.

## ADDED Requirements

### Requirement: Compilación con Visual Studio 2017
El sistema SHALL compilar HotSpot en Windows usando las herramientas de compilación de Visual Studio 2017, ubicadas mediante configuración o, si no se indica, detectando la instalación existente.

#### Scenario: Toolchain detectado
- Given Visual Studio 2017 Build Tools y Cygwin están instalados y no se configura ninguna ruta, when se compila la versión `product`, then se genera `jvm.dll` para Windows x64.

#### Scenario: Ruta configurada
- Given las herramientas de Visual Studio 2017 están en una ruta no estándar indicada por configuración, when se compila, then se usan las herramientas de esa ruta.

#### Scenario: Toolchain ausente
- Given no hay Visual Studio 2017 configurado ni detectable, when se compila, then el proceso falla antes de invocar `make` con un mensaje que indica qué configurar.

### Requirement: Ubicación de Cygwin configurable
El sistema SHALL usar la instalación de Cygwin indicada por configuración y, si no se indica, la de `C:\cygwin`.

#### Scenario: Cygwin en otra ruta
- Given Cygwin está instalado en `C:\cygwin64` y así se configura, when se compila, then la compilación se ejecuta con esa instalación.

### Requirement: Librería nativa de pruebas
El sistema SHALL compilar la librería nativa que usan las pruebas con el mismo toolchain que HotSpot.

#### Scenario: Pruebas nativas
- Given el toolchain de Visual Studio 2017 está disponible, when se ejecutan las pruebas, then la librería nativa se compila y la prueba nativa se ejecuta.
