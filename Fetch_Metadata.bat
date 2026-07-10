@echo off
REM Double-click launcher for Fetch_Metadata.py using the portable Python.
set "PY=D:\Projects\Tools\python\python.exe"
if not exist "%PY%" set "PY=python"
"%PY%" "%~dp0Fetch_Metadata.py" %*
pause
