# parcheo-de-hotspot Specification

## Purpose

Obtener el código fuente de HotSpot para una etiqueta de OpenJDK y aplicarle la serie de parches de DCEVM que corresponde a esa etiqueta y al sabor configurado, de forma reproducible.

## Requirements

### Requirement: Obtención de fuentes sin Mercurial
El sistema SHALL obtener el código fuente de HotSpot de la etiqueta configurada desde el repositorio Git público de OpenJDK 8u, sin requerir Mercurial instalado.

#### Scenario: Etiqueta existente
- Given la etiqueta configurada es `jdk8u212-b04` y Mercurial no está instalado, when se ejecuta el parcheo, then el directorio de HotSpot contiene las fuentes de esa etiqueta.

#### Scenario: Etiqueta inexistente
- Given la etiqueta configurada no existe en el repositorio público, when se ejecuta el parcheo, then el proceso falla con un mensaje que nombra la etiqueta y no se aplica ningún parche.

### Requirement: Selección de parches por guardas
El sistema SHALL aplicar, en el orden de la serie, únicamente los parches sin guarda y los que tengan al menos una guarda entre el sabor, la familia (`jdk7` o `jdk8`), la etiqueta y la combinación `<sabor>-<etiqueta>`.

#### Scenario: Parche de otra versión
- Given un parche de la serie solo tiene guardas de otras etiquetas, when se parchea la etiqueta configurada, then ese parche no se aplica.

### Requirement: Fallo de aplicación explícito
El sistema SHALL detener el parcheo cuando un parche no se pueda aplicar completamente, indicando el nombre del parche y los ficheros afectados.

#### Scenario: Hunk rechazado
- Given un parche seleccionado tiene un hunk que no encaja con las fuentes, when se ejecuta el parcheo, then el proceso falla nombrando el parche y el fichero, y no se aplican los parches posteriores.

### Requirement: Parcheo desde fuentes limpias
El sistema SHALL partir siempre de las fuentes intactas de la etiqueta al repetir el parcheo, descartando cualquier modificación previa del directorio de HotSpot que no esté guardada en un parche.

#### Scenario: Repetición tras modificaciones locales
- Given se han editado ficheros de HotSpot tras un parcheo anterior, when se vuelve a ejecutar el parcheo, then las fuentes resultantes son las de la etiqueta más la serie, sin las ediciones locales.

### Requirement: Regeneración de un parche
El sistema SHALL permitir regenerar el fichero del último parche aplicado de la serie a partir de los cambios hechos en las fuentes, en un formato que el propio parcheo vuelva a aplicar.

#### Scenario: Corrección de un parche
- Given las fuentes están parcheadas hasta un parche concreto y se corrige un fichero afectado por él, when se regenera ese parche, then el fichero del parche incluye la corrección y un parcheo posterior desde cero la reproduce.

### Requirement: Soporte de JDK 8u212
El sistema SHALL disponer de una serie de parches del sabor `light` que se aplique sin rechazos sobre la etiqueta `jdk8u212-b04`.

#### Scenario: Parcheo de 8u212
- Given el sabor es `light` y la etiqueta es `jdk8u212-b04`, when se ejecuta el parcheo, then todos los parches seleccionados se aplican sin rechazos.

#### Scenario: Versiones anteriores intactas
- Given el sabor es `light` y la etiqueta es `jdk8u202-b08`, when se ejecuta el parcheo, then se seleccionan los mismos parches que antes de este cambio y se aplican sin rechazos.
