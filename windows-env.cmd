@echo off
rem Loads the Visual Studio 2017 (VC++ 14.1x) build environment for ARCH (x64 or x86, default x64)
rem and checks the Cygwin installation used to run HotSpot's make.
rem Optional variables:
rem   VS2017_VCVARSALL  path to vcvarsall.bat (default: located with vswhere, version [15.0,16.0))
rem   CYGWIN_HOME       Cygwin root (default: C:\cygwin)
rem Exits with errorlevel 1 and a message when something is missing.

if "%ARCH%"=="" set ARCH=x64

if defined VS2017_VCVARSALL goto check_vcvars
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto no_vs
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -version [15.0^,16.0^) -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS2017_VCVARSALL=%%i\VC\Auxiliary\Build\vcvarsall.bat"
if not defined VS2017_VCVARSALL goto no_vs

:check_vcvars
if not exist "%VS2017_VCVARSALL%" goto no_vcvars
call "%VS2017_VCVARSALL%" %ARCH% >nul
if errorlevel 1 goto bad_vcvars
where cl >nul 2>nul
if errorlevel 1 goto bad_vcvars
where rc >nul 2>nul
if errorlevel 1 goto no_sdk
rem Directory of cl/link/nmake: it must precede Cygwin's /usr/bin, whose link.exe is unrelated to the MSVC linker
set "VC_TOOLS_BIN=%VCToolsInstallDir%bin\Host%VSCMD_ARG_HOST_ARCH%\%VSCMD_ARG_TGT_ARCH%"
if not exist "%VC_TOOLS_BIN%\link.exe" goto bad_vcvars

if not defined CYGWIN_HOME set "CYGWIN_HOME=C:\cygwin"
if not exist "%CYGWIN_HOME%\bin\bash.exe" goto no_cygwin
if not exist "%CYGWIN_HOME%\bin\make.exe" goto no_cygwin_make
exit /b 0

:no_vs
echo ERROR: Visual Studio 2017 Build Tools with the VC++ x64/x86 tools were not found. Install them or set VS2017_VCVARSALL to the path of vcvarsall.bat. 1>&2
exit /b 1

:no_vcvars
echo ERROR: VS2017_VCVARSALL points to "%VS2017_VCVARSALL%", which does not exist. 1>&2
exit /b 1

:bad_vcvars
echo ERROR: "%VS2017_VCVARSALL%" %ARCH% did not set up the C++ compiler. Check the VC++ tools for %ARCH% in Visual Studio 2017 Build Tools. 1>&2
exit /b 1

:no_sdk
echo ERROR: Windows 10 SDK not found (rc.exe is missing). Add the Windows 10 SDK component (for example Microsoft.VisualStudio.Component.Windows10SDK.19041) to Visual Studio 2017 Build Tools. 1>&2
exit /b 1

:no_cygwin
echo ERROR: Cygwin not found at "%CYGWIN_HOME%". Install it or set CYGWIN_HOME to its root directory. 1>&2
exit /b 1

:no_cygwin_make
echo ERROR: Cygwin at "%CYGWIN_HOME%" has no make. Install the Cygwin package 'make'. 1>&2
exit /b 1
