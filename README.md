# DCEVM

This project is a fork of original [DCEVM](http://ssw.jku.at/dcevm/) project.

The purpose of the project is to maintain enhanced class redefinition functionality for OpenJDK HotSpot 8. It currently targets **JDK 8u212**.

## Binaries

You can download binaries at [releases](https://github.com/elTorres/dcevm/releases). Release `light-jdk8u212+1` contains, for Windows x64:

* `dcevm-light-jdk8u212-installer.jar`: graphical installer with DCEVM bundled. Run it with `java -jar dcevm-light-jdk8u212-installer.jar`, using a JVM other than the JDK you are going to patch.
* `dcevm-light-jdk8u212-windows-amd64-jvm.dll`: the bare VM library, to install it by hand (see [Installing DCEVM](#installing-dcevm)).

## Supported version

DCEVM is built from the HotSpot tag `jdk8u212-b04` of the [OpenJDK 8u Git repository](https://github.com/openjdk/jdk8u) (only its `hotspot/` directory is downloaded) and is meant for JDK 1.8.0_212. It has been built and tested on Windows x64 against Oracle JDK 1.8.0_212.

The flavor is `light`: additions to class hierarchies are supported, removals (of superclasses, for example) are not.

The patches live in [hotspot/.hg/patches/](hotspot/.hg/patches/). The `series` file lists them and its guards select the ones for `jdk8u212-b04` and the `light` flavor.

## Building

### General Requirements

You need the following software to build DCEVM:

* JDK 8u212 to run Gradle and the tests (for example `C:\Workspace\java\jdk1.8.0_212`).
* Git 2.27 or later and GNU patch (on Windows, the one bundled with Git for Windows is used). Mercurial is no longer needed.
* On Windows x64:
  * Visual Studio 2017 Build Tools 15.9 with the C++ tools (`Microsoft.VisualStudio.Workload.VCTools`, `Microsoft.VisualStudio.Component.VC.Tools.x86.x64`) and the Windows 10 SDK (`Microsoft.VisualStudio.Component.Windows10SDK.19041`). Later Visual Studio versions are not supported by the HotSpot 8u212 build scripts.
  * Cygwin (64-bit) with `make`, `zip`, `unzip`, `gawk`, `findutils`, `file`, `diffutils`, `grep`, `sed` and `coreutils`. Set `CYGWIN_HOME` if it is not in `C:\cygwin`.
* On Linux and macOS: a gcc toolchain supported by the HotSpot 8u212 build scripts (not verified with this version).

See [docs/agents/building.md](docs/agents/building.md) for the details.

#### Mac OS X specific requirements

Currently the build is not compatible with Clang on Mac OS X, you need to install gcc 4.8 using the [Homebrew](http://brew.sh/):

```sh
brew tap homebrew/versions
brew install gcc48
```

Then set the following environmental properties:

```sh
export CC=/usr/local/bin/gcc-4.8
export CFLAGS=-fobjc-exceptions
export CXX=/usr/local/bin/g++-4.8
export SA_LDFLAGS=-fobjc-exceptions
```

### Linux gcc8 specific prebuild steps

```sh
export CFLAGS="${CFLAGS//-O2/-O3} ${CPPFLAGS} -Wno-error=deprecated-declarations -Wno-error=stringop-overflow= -Wno-error=return-type -Wno-error=cpp -fno-lifetime-dse -fno-delete-null-pointer-checks"
export CXXFLAGS="${CXXFLAGS} ${CPPFLAGS}"
```

### Compiling DCEVM

* [gradle.properties](gradle.properties) is already set to `hotspotTag=jdk8u212-b04` and `flavor=light`.
* Run `./gradlew patch` to retrieve HotSpot sources and patch them.
* Run `./gradlew compileFastdebug` to build `fastdebug` version or `./gradlew compileProduct` to build `product` version.
* Compiled libraries are placed in `hotspot/build/fastdebug` or `hotspot/build/product`.

To build the installer with the `product` library you compiled, run `./gradlew :installer:jar -PuseLocalBuild`. The jar is `installer/build/libs/installer.jar`.

### Installing DCEVM

With the installer, select the JDK 8u212 (or add it with "Add installation directory...") and choose to replace the default JVM or to install DCEVM as altjvm.

By hand:

* Replace `jvm.dll` (`libjvm.so` on Linux, `libjvm.dylib` on macOS) in the JDK 8u212 JRE, keeping a copy of the original, or copy it as `jre\bin\dcevm\jvm.dll` to install it side by side.
* Run `java -version` (or `java -XXaltjvm=dcevm -version` side by side), it should include `Dynamic Code Evolution` string.

Or you can install DCEVM using the gradle script:

* Run `./gradlew installFastdebug -PtargetJre=$JAVA_HOME/jre` or `./gradlew installProduct -PtargetJre=$JAVA_HOME/jre`
* DCEVM will be installed as "alternative" JVM. To use it, add `-XXaltjvm=dcevm`

### Testing DCEVM

* Set `JAVA_HOME` to point to JDK 8u212.
* Run `./gradlew patch` to retrieve HotSpot sources and patch them.
* Run `./gradlew test` to run tests. It builds and installs DCEVM first. The build succeeds even if tests fail, so check the reports.
* Tests reports will be in `dcevm/build/reports/tests/index.html`

To run tests from IDE, you need:

* Run `./gradlew agent:build` to build redefinition agent code.
* Add JVM argument to use redefinition agent (`-javaagent:agent/build/libs/agent.jar`).
* Add JVM argument to DCEVM VM if installed side-by-side (`-XXaltjvm=dcevm`).

### Publishing a release

See [docs/agents/releasing.md](docs/agents/releasing.md).

### Hotswap performance tweak (Experimental)

DCEVM executes deoptimization (purge of code cache) after any class redefinition. It leads to decrease JVM's performance (after redefinition).  This is especially problem on large scale projects with significant number of classes. Hotswap performance can be improved using an experimental option `-XX:HotswapDeoptClassPath=`. One or more packages can be specified in comma separated list as parameters. Packages must contain all classes that will be potentially modified (redefined). Classes outside of this list won't be included in the deoptimization. Usually it is sufficient to specify application main or root package. If `com.sun.proxy.Proxy` is used in the application or by application's framework, then this option should contain package `com.sun.proxy` as well. If `HotswapDeoptClassPath` option is not specified, then all classes will be deoptimized after redefinition. It is also recommended to clean all generated byte by reflection.
Example:

```text
    -XX:HotswapDeoptClassPath='com.myproject.,com.sun.proxy.$Proxy,sun.reflect.Generated'
```
