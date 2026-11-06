call "%~dp0windows-env.cmd"
if errorlevel 1 exit /b 1

rem HotSpot's nmake files run tools they just built from the current directory (adlc, ...)
set NoDefaultCurrentDirectoryInExePath=

rem HotSpot 8u212 only maps MSC_VER 1912/1913 to VS2017; later VS2017 updates (cl 1914-1916) would fall
rem back to the default compiler settings. The options are the same for the whole VS2017 series.
if not defined FORCE_MSC_VER set FORCE_MSC_VER=1912
if not defined FORCE_LD_VER set FORCE_LD_VER=1412

echo Script arguments: %*
set SCRIPT=%~dp0
set HOTSPOTWORKSPACE=hotspot
rem The MSVC tools go first in the PATH, otherwise nmake picks Cygwin's link.exe
"%CYGWIN_HOME%\bin\bash" --login -c 'export PATH="`/usr/bin/cygpath -u "$VC_TOOLS_BIN"`:$PATH" ; cd `/usr/bin/cygpath "$SCRIPT"/hotspot` ; /usr/bin/pwd ; /usr/bin/make -C "make" %*'
