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
- **Windows** (x64): `make` runs through `build.cmd` and the test JNI library through `native/compile.cmd`. Both call `windows-env.cmd`, which loads `vcvarsall.bat` of Visual Studio 2017 and checks Cygwin, failing before `make` with a message when something is missing. HotSpot 8u212 makefiles only know VS2017 by MSC_VER 1912/1913 (see below for how `build.cmd` handles the 15.9 compiler, MSC_VER 1916) and do not support VS2019/VS2022.
  - Visual Studio 2017 Build Tools 15.9 with the components `Microsoft.VisualStudio.Workload.VCTools`, `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` and a Windows 10 SDK. The current VS2017 catalog only offers `Microsoft.VisualStudio.Component.Windows10SDK.19041` (older ids such as `...Windows10SDK.17763` are rejected). Install them with `vs_buildtools.exe` from `https://aka.ms/vs/15/release/vs_buildtools.exe`; `--installPath`, `--path cache=` and `--path shared=` can put it on another drive, but the Windows SDK always goes to the existing `KitsRoot10` (usually `C:\Program Files (x86)\Windows Kits\10`). The installation is located with `vswhere -version [15.0,16.0)`; set `VS2017_VCVARSALL=<path to vcvarsall.bat>` to use a specific one.
  - `build.cmd` adapts the environment for HotSpot 8u212: it forces `FORCE_MSC_VER=1912`/`FORCE_LD_VER=1412` (8u212 only maps MSC_VER 1912/1913 to VS2017; with cl 19.16 it would fall back to default compiler settings and fail with `LNK2011: precompiled object not linked in`), puts the MSVC tools directory before Cygwin's `/usr/bin` (Cygwin's `link.exe` is not the linker) and clears `NoDefaultCurrentDirectoryInExePath` (nmake runs the freshly built `adlc` from the current directory). Set `FORCE_MSC_VER`/`FORCE_LD_VER` yourself to override.
  - Cygwin (64-bit) with the packages `make`, `zip`, `unzip`, `gawk`, `findutils`, `file`, `diffutils`, `grep`, `sed` and `coreutils`. It is taken from `CYGWIN_HOME` (default `C:\cygwin`); it does not need to be on the `PATH`.

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

To bundle the VM you compiled locally instead, run `./gradlew :hotspot:compileProduct` and then `./gradlew :installer:jar -PuseLocalBuild`. `copyData` copies `hotspot/build/product/<libjvm>` to `<os>_<arch>_compiler2/product/<libjvm>` (for example `windows_amd64_compiler2/product/jvm.dll`), the resource the installer looks up for the current platform. It fails if that library does not exist. After `jar`, `checkLocalData` verifies the jar contains it. Run the result with `java -jar installer/build/libs/installer.jar`. It also lists the JDKs next to `JAVA_HOME`, and others can be added with its "Add installation directory" button.
