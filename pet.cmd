@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"
set "FLUTTER_PATH="
set "STATE_DIR=%USERPROFILE%\.petfy"

where node.exe >nul 2>nul
if errorlevel 1 (
  set "NODE_PATH="
) else (
  for /f "usebackq delims=" %%N in (`where node.exe`) do (
    set "NODE_PATH=%%N"
    goto :node_found
  )
)
:node_found

set "COMMAND=%~1"
if "%COMMAND%"=="" set "COMMAND=help"

if "%COMMAND%"=="help" goto :help
if "%COMMAND%"=="--help" goto :help
if "%COMMAND%"=="-h" goto :help

if "%COMMAND%"=="dev-windows" (
  call :require_node
  if errorlevel 1 exit /b 1
  call :require_flutter
  if errorlevel 1 exit /b 1
  cd /d "%REPO_ROOT%\app"
  "!FLUTTER_PATH!" run -d windows --dart-define="PETFY_ROOT=%REPO_ROOT%" --dart-define="PETFY_STATE_DIR=%STATE_DIR%" --dart-define="PETFY_NODE_PATH=%NODE_PATH%"
  exit /b %ERRORLEVEL%
)

if "%COMMAND%"=="install-windows" (
  call :require_node
  if errorlevel 1 exit /b 1
  call :require_flutter
  if errorlevel 1 exit /b 1
  cd /d "%REPO_ROOT%\app"
  "!FLUTTER_PATH!" build windows --release --dart-define="PETFY_ROOT=%LOCALAPPDATA%\Petfy" --dart-define="PETFY_STATE_DIR=%STATE_DIR%" --dart-define="PETFY_NODE_PATH=%NODE_PATH%"
  if errorlevel 1 exit /b 1
  cd /d "%REPO_ROOT%"
  node scripts\windows-app.js install
  exit /b %ERRORLEVEL%
)

if "%COMMAND%"=="package-windows" (
  call :require_node
  if errorlevel 1 exit /b 1
  call :require_flutter
  if errorlevel 1 exit /b 1
  cd /d "%REPO_ROOT%\app"
  "!FLUTTER_PATH!" build windows --release --dart-define="PETFY_NODE_PATH=%NODE_PATH%"
  if errorlevel 1 exit /b 1
  cd /d "%REPO_ROOT%"
  node scripts\package-windows.js
  exit /b %ERRORLEVEL%
)

if "%COMMAND%"=="start-windows" (
  cd /d "%REPO_ROOT%"
  node scripts\windows-app.js start
  exit /b %ERRORLEVEL%
)

if "%COMMAND%"=="stop-windows" (
  cd /d "%REPO_ROOT%"
  node scripts\windows-app.js stop
  exit /b %ERRORLEVEL%
)

if "%COMMAND%"=="uninstall-windows" (
  cd /d "%REPO_ROOT%"
  node scripts\windows-app.js uninstall
  exit /b %ERRORLEVEL%
)

if "%COMMAND%"=="doctor-windows" (
  cd /d "%REPO_ROOT%"
  node scripts\windows-app.js status
  exit /b %ERRORLEVEL%
)

if "%COMMAND%"=="analyze" (
  call :require_flutter
  if errorlevel 1 exit /b 1
  cd /d "%REPO_ROOT%\app"
  "!FLUTTER_PATH!" analyze
  exit /b %ERRORLEVEL%
)

if "%COMMAND%"=="test" (
  call :require_flutter
  if errorlevel 1 exit /b 1
  cd /d "%REPO_ROOT%\app"
  "!FLUTTER_PATH!" test
  exit /b %ERRORLEVEL%
)

echo Unknown command: %COMMAND%
echo.
goto :help

:require_node
if "%NODE_PATH%"=="" (
  echo Node.js was not found in PATH.
  exit /b 1
)
exit /b 0

:require_flutter
if "%FLUTTER_PATH%"=="" (
  if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER_PATH=%FLUTTER_ROOT%\bin\flutter.bat"
)
if "%FLUTTER_PATH%"=="" (
  for /f "usebackq delims=" %%F in (`where flutter.bat 2^>nul`) do (
    set "FLUTTER_PATH=%%F"
    goto :flutter_found
  )
  for /f "usebackq delims=" %%F in (`where flutter 2^>nul`) do (
    set "FLUTTER_PATH=%%F"
    goto :flutter_found
  )
)
:flutter_found
if "%FLUTTER_PATH%"=="" (
  echo Flutter was not found in PATH.
  echo Install Flutter for Windows, then run this command again.
  exit /b 1
)
exit /b 0

:help
echo Usage:
echo   pet.cmd dev-windows
echo   pet.cmd install-windows
echo   pet.cmd package-windows
echo   pet.cmd start-windows
echo   pet.cmd stop-windows
echo   pet.cmd uninstall-windows
echo   pet.cmd doctor-windows
echo   pet.cmd analyze
echo   pet.cmd test
exit /b 0
