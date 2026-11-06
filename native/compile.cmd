call "%~dp0..\windows-env.cmd"
if errorlevel 1 exit /b 1

cl /I"%JAVA_HOME%\..\include" /I"%JAVA_HOME%\..\include\win32" natives.c /Fobuild\natives.obj /Febuild\natives.dll /LD
