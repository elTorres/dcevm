# Publishing a release on GitHub

Releases are published by hand from a local build: the build server that used to fill `installer/build/rawdata` does not exist any more. A release is a tag plus two assets: the installer jar, with the VM bundled, and the bare VM library for installing it as an altjvm by hand.

This guide uses the Windows x64 `light` build for `jdk8u212-b04` as its example (the first one, `light-jdk8u212+1`, is at [releases](https://github.com/elTorres/dcevm/releases)). For other updates or platforms, change the names to match.

## Requirements

- The toolchain from [building.md](building.md) (on Windows: VS2017 Build Tools, Cygwin, a JDK 8 to run Gradle).
- GitHub CLI (`gh`) logged in with an account that can push to the repository (`gh auth status`).
- Commit and push the branch you release from first: the tag is created on GitHub on the last pushed commit of `--target`.

## Naming

| Item | Pattern | Example |
| --- | --- | --- |
| Tag | `<flavor>-jdk8u<update>+<n>` | `light-jdk8u212+1` |
| Installer | `dcevm-<flavor>-jdk8u<update>-installer.jar` | `dcevm-light-jdk8u212-installer.jar` |
| VM library | `dcevm-<flavor>-jdk8u<update>-<os>-<arch>-<libjvm>` | `dcevm-light-jdk8u212-windows-amd64-jvm.dll` |

`<n>` is the build number for that update. Increase it whenever you publish again for the same update; do not reuse or move a published tag.

## Steps

Run them from the repository root in PowerShell, with `hotspotTag` and `flavor` in `gradle.properties` set to what you release.

1. Build the product VM from pristine sources, and check it, if the patches or the tag changed since the last build:

   ```powershell
   $env:JAVA_HOME = "C:\Workspace\java\jdk1.8.0_212"
   .\gradlew --no-daemon :hotspot:patch :hotspot:compileProduct
   ```

   Before publishing, run the test suite on it (see [testing.md](testing.md)), or at least install it as an altjvm and check that `java -XXaltjvm=dcevm -version` reports `Dynamic Code Evolution`.
2. Build the installer with that VM bundled. `checkLocalData` must log `... contains windows_amd64_compiler2/product/jvm.dll`:

   ```powershell
   .\gradlew --no-daemon :installer:jar -PuseLocalBuild "-PinstallerJarName=dcevm-light-jdk8u212-installer.jar"
   ```

3. Collect the assets in `build/release` (ignored by git)

   ```powershell
   New-Item -ItemType Directory -Force build\release | Out-Null
   Copy-Item installer\build\libs\dcevm-light-jdk8u212-installer.jar build\release\
   Copy-Item hotspot\build\product\jvm.dll build\release\dcevm-light-jdk8u212-windows-amd64-jvm.dll
   ```

4. Create the tag and the release, and upload the assets. Add `--draft` to check it on the web before it becomes public:

   ```powershell
   gh release create light-jdk8u212+1 `
     --repo elTorres/dcevm `
     --target feature/support-jdk8u212 `
     --title "DCEVM light para JDK 8u212 (Windows x64)" `
     --notes "Compilado desde jdk8u212-b04 con VS2017. Instalador: java -jar dcevm-light-jdk8u212-installer.jar. Altjvm manual: copiar el dll como jre\bin\dcevm\jvm.dll y ejecutar con -XXaltjvm=dcevm." `
     build\release\dcevm-light-jdk8u212-installer.jar `
     build\release\dcevm-light-jdk8u212-windows-amd64-jvm.dll
   ```

5. Check the result: `gh release view light-jdk8u212+1 --repo elTorres/dcevm` must list both assets. If there is time, download the installer from the release and install it on a JDK of that update.

## Fixing a release

- Replace an asset without changing the tag (for example after uploading the wrong file): `gh release upload <tag> <file> --clobber --repo elTorres/dcevm`. Only do this before others have downloaded it; if the binary changes, publish a new `+<n>` instead.
- Publish a draft: `gh release edit <tag> --draft=false --repo elTorres/dcevm`.
- Delete a release and its tag: `gh release delete <tag> --cleanup-tag --repo elTorres/dcevm`.

## Licence

HotSpot is GPLv2, so the corresponding source must be available with the binaries. The release tag points at the commit with the patch series and the build, and the upstream sources come from the OpenJDK tag in `hotspotTag`. Do not attach anything taken from an Oracle JDK: only the library built from OpenJDK sources.
