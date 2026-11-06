# Building and installing DCEVM

## Requirements

- JDK 7 or 8 to run Gradle (wrapper is Gradle 2.4). The `jre` project property defaults to the Gradle JVM's `java.home` and must be a JDK's `jre/` directory: the build reads `${jre}/../lib/tools.jar` and `${jre}/../include` (JNI headers). When running tests, this JDK must match the `hotspotTag` in `gradle.properties`.
- Git 2.27 or later on the `PATH` (sparse checkout and partial clone) with access to `https://github.com/openjdk/jdk8u.git` (`jdk7u` for JDK 7 tags). Mercurial is not needed.
- GNU `patch`. By default the build runs `patch` from the `PATH`; on Windows it falls back to the one bundled with Git for Windows (`<Git>/usr/bin/patch.exe`). Override it with `-PpatchExecutable=<path>`.
- C++ toolchain supported by the HotSpot make scripts (gcc).

### Platform specifics

- **macOS**: Clang is not supported. Use gcc 4.8 and export `CC=/usr/local/bin/gcc-4.8 CXX=/usr/local/bin/g++-4.8 CFLAGS=-fobjc-exceptions SA_LDFLAGS=-fobjc-exceptions`.
- **Linux with gcc 8**: relax warnings before building:
  ```sh
  export CFLAGS="${CFLAGS//-O2/-O3} ${CPPFLAGS} -Wno-error=deprecated-declarations -Wno-error=stringop-overflow= -Wno-error=return-type -Wno-error=cpp -fno-lifetime-dse -fno-delete-null-pointer-checks"
  export CXXFLAGS="${CXXFLAGS} ${CPPFLAGS}"
  ```
- **Windows**: `make` runs through `build.cmd`, which hardcodes Windows SDK 7.1 (`c:\Program Files\Microsoft SDKs\Windows\v7.1`) and Cygwin at `C:\cygwin`. `native/compile.cmd` uses the same SDK with `cl`.

## Task graph (all defined in root `build.gradle`)

`:hotspot` tasks run with `hotspot/` as their working directory:

1. `fetchSources`: keeps a shallow, partial (`--filter=blob:none`) and sparse (`hotspot/` only) clone of the OpenJDK repository in `build/hotspot-upstream` (`hotspotGitRepository8`, or `hotspotGitRepository7` when `hotspotTag` contains `jdk7`), fetches `refs/tags/<hotspotTag>` if it is not there yet and checks it out. It fails naming the tag if the tag does not exist.
2. `patch`: deletes everything in `hotspot/` except `.hg/` and `build/`, copies the tag's `hotspot/` sources, creates the local Git history (`upstream <tag>` plus one commit per patch) and applies the patches selected by the guards. `-PpatchUntil=<name.patch>` stops after that patch. `refreshPatch` rewrites the last applied patch from the current sources. See [hotspot-patches.md](hotspot-patches.md) for guards and the editing workflow.
3. `compileProduct` / `compileFastdebug` (`InvokeMake`): run HotSpot `make` with `HOTSPOT_BUILD_VERSION=dcevm<flavor>-<buildNumber>`, `ALT_BOOTDIR=<jre>/..` and `COMPILER_WARNINGS_FATAL=false`, then copy `libjvm`/`libjsig` into `hotspot/build/<kind>`. These tasks do not depend on `patch` (they only `mustRunAfter` it), so run `patch` yourself first.
4. `installProduct` / `installFastdebug`: copy `jre` → `targetJre` if they differ (`prepareJvm`), then put the libraries into `<targetJre>/<lib/amd64|bin|lib>/<jvmName>/`.

`:dcevm:test` depends on `:native:compile` and `:hotspot:install<Kind>` (`kind` from `gradle.properties`). Running tests therefore rebuilds and reinstalls the VM.

Override any `gradle.properties` value with `-P`, for example `-PhotspotTag=jdk8u181-b13 -Pkind=product -PtargetJre=$JAVA_HOME/jre`.

## Using the built VM

- Replace `libjvm.so` / `jvm.dll` / `libjvm.dylib` in a JRE, or install side by side and run with `-XXaltjvm=dcevm`.
- `java -version` must mention `Dynamic Code Evolution`.
- Experimental `-XX:HotswapDeoptClassPath=com.myproject.,com.sun.proxy.$Proxy,sun.reflect.Generated` limits code-cache deoptimization after redefinition to the listed package prefixes. If the option is absent, everything is deoptimized.

## Installer (`installer/`)

A plain Java/Swing jar (`Main-Class: com.github.dcevm.installer.Main`). VM binaries are bundled from `installer/build/rawdata`, which is filled by the build server. The `copyData` task skips `fastdebug` builds. Support for JDK vendors and layouts (Oracle, OpenJDK, AdoptOpenJDK, SAP JVM, ...) lives in `ConfigurationInfo`.
