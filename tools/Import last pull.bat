@echo off
rem Converts the last boss pull of your newest combat log for Dynamic Planner and copies it to the clipboard.
rem Needs Python 3 from python.org or the Microsoft Store. Extra options can be added after the file name.
cd /d "%~dp0"
where py >NUL 2>NUL
if %errorlevel%==0 (
  py -3 "%~dp0log2pull.py" %*
) else (
  where python >NUL 2>NUL
  if errorlevel 1 (
    echo Python 3 was not found. Install it from https://www.python.org/downloads/ and run this file again.
  ) else (
    python "%~dp0log2pull.py" %*
  )
)
echo.
pause
