## Purpose

Instalar el DCEVM compilado localmente en un JDK 8 existente, tanto como JVM alternativa como mediante la aplicación instaladora.

## ADDED Requirements

### Requirement: Instalación como JVM alternativa
El sistema SHALL instalar el DCEVM compilado en el JRE del JDK destino como JVM alternativa con el nombre configurado, sin modificar su JVM por defecto.

#### Scenario: JDK 8u212
- Given DCEVM está compilado para `jdk8u212-b04` y el JRE destino es el de `C:\Workspace\java\jdk1.8.0_212`, when se instala como JVM alternativa, then `java -XXaltjvm=dcevm -version` informa de la versión 1.8.0_212 y de `Dynamic Code Evolution`, y `java -version` sigue mostrando la JVM original.

### Requirement: Instalador con binario local
El sistema SHALL generar la aplicación instaladora incluyendo el DCEVM `product` compilado localmente para la plataforma actual, sin depender de binarios aportados por un servidor de build.

#### Scenario: Binario disponible
- Given existe un `jvm.dll` `product` compilado localmente, when se genera el instalador desde el binario local, then el instalador incluye ese binario y puede instalarlo.

#### Scenario: Binario ausente
- Given no existe ningún DCEVM `product` compilado localmente, when se genera el instalador desde el binario local, then la generación falla con un mensaje que indica que primero hay que compilar.

### Requirement: Parcheo de JDK 8u212 con el instalador
El sistema SHALL permitir, desde la aplicación instaladora, instalar y desinstalar DCEVM en `C:\Workspace\java\jdk1.8.0_212`, tanto como JVM por defecto como alternativa.

#### Scenario: Instalar como JVM por defecto
- Given el instalador incluye el binario para 8u212 y el directorio del JDK se ha añadido, when se instala DCEVM como JVM por defecto, then `java -version` de ese JDK muestra `Dynamic Code Evolution` y el `jvm.dll` original queda respaldado.

#### Scenario: Desinstalar
- Given DCEVM está instalado como JVM por defecto en ese JDK, when se desinstala desde el instalador, then se restaura el `jvm.dll` original y `java -version` vuelve a mostrar la JVM de Oracle.
