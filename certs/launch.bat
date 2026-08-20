@echo off
REM OWASP LLM Top10 2026 Workshop - Docker/local launcher
setlocal EnableExtensions
cd /d "%~dp0"

set "PORT_CONFIG=backend\config.yml"
for /f "tokens=3" %%A in ('findstr /b /c:"x-app-port:" "%PORT_CONFIG%"') do set "APP_PORT=%%A"
for /f "tokens=3" %%A in ('findstr /b /c:"x-container-name:" "%PORT_CONFIG%"') do set "CONTAINER_NAME=%%A"
if not defined APP_PORT set "APP_PORT=20001"
if not defined CONTAINER_NAME set "CONTAINER_NAME=LLMWorkshop_Labs"
set "APP_URL=http://localhost:%APP_PORT%/labs"
set "MODE=%~1"
if not defined MODE set "MODE=auto"
if /i "%MODE%"=="--docker" set "MODE=docker"
if /i "%MODE%"=="--local" set "MODE=local"

if /i not "%MODE%"=="auto" if /i not "%MODE%"=="docker" if /i not "%MODE%"=="local" (
    echo Usage: launch.bat [auto^|docker^|local]
    exit /b 2
)

echo OWASP LLM Top10 2026 Workshop
echo By - Madhu CN
echo ==========================
echo.

REM Avoid starting a second copy when the configured application is ready.
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -Uri '%APP_URL%' -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop; if($r.StatusCode -eq 200){ exit 0 } } catch{}; exit 1" >nul 2>nul
if not errorlevel 1 (
    echo The application is already running. Opening the browser...
    start "" "%APP_URL%"
    exit /b 0
)

if /i "%MODE%"=="local" goto run_local

call :docker_is_healthy
if not errorlevel 1 goto run_docker

if /i "%MODE%"=="docker" (
    echo Docker mode was requested, but Docker is not usable.
    echo Verify Docker Desktop, Docker Compose, and the Docker daemon, then try again.
    pause
    exit /b 1
)

echo Docker is missing, stopped, or unable to reach its backend.
echo Switching to native local mode; Docker and WSL are not required.
echo.
goto run_local

:run_docker
echo Mode: Docker
echo Building image and starting container...
docker compose up --build -d
if errorlevel 1 (
    echo.
    echo Docker is available, but the application build or startup failed.
    echo Review the Docker output above. To bypass Docker, run: launch.bat local
    pause
    exit /b 1
)

echo.
echo Container started. Waiting for the application to be ready...
echo (First run downloads about 1.7 GB of model files and may take several minutes.)
echo.
call :wait_and_open
echo To watch startup progress:   docker logs -f %CONTAINER_NAME%
echo To stop the demo:            docker compose down
echo.
pause
exit /b 0

:run_local
echo Mode: Native local
echo.
call :find_python
if errorlevel 1 call :offer_python_install
if errorlevel 1 (
    echo Python 3.12 is required for local mode.
    echo Install Python 3.12 from https://www.python.org/downloads/windows/ and rerun this launcher.
    pause
    exit /b 1
)

call :prepare_local
if "%errorlevel%"=="20" (
    call :offer_ollama_install
    if errorlevel 1 (
        echo Ollama is required for local mode.
        pause
        exit /b 1
    )
    call :prepare_local
)
if errorlevel 1 (
    echo.
    echo Local runtime preparation failed. Review the message above and .runtime\ollama.log.
    pause
    exit /b 1
)

set "VENV_PYTHON=%CD%\.venv\Scripts\python.exe"
if not exist "%VENV_PYTHON%" (
    echo Local Python environment was not created successfully.
    pause
    exit /b 1
)

echo.
echo Starting the application on %APP_URL%
echo Press Ctrl+C to stop the local application.
echo.
start "Labs readiness check" /b powershell -NoProfile -Command "$url='%APP_URL%'; for($i=0;$i -lt 120;$i++){ try{ $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop; if($r.StatusCode -eq 200){ Write-Host 'App is ready! Opening browser...'; Start-Process $url; exit 0 } } catch{}; Start-Sleep -Seconds 2 }; Write-Host 'Timed out waiting for the app. Open manually:' $url"
"%VENV_PYTHON%" -m uvicorn backend.server:app --host 127.0.0.1 --port "%APP_PORT%"
set "APP_EXIT=%errorlevel%"
echo.
echo Local application stopped.
pause
exit /b %APP_EXIT%

:prepare_local
"%PYTHON_EXE%" %PYTHON_ARGS% scripts\prepare_local_runtime.py
exit /b %errorlevel%

:find_python
set "PYTHON_EXE="
set "PYTHON_ARGS="
where py >nul 2>nul
if not errorlevel 1 (
    py -3.12 -c "import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 12) else 1)" >nul 2>nul
    if not errorlevel 1 (
        set "PYTHON_EXE=py"
        set "PYTHON_ARGS=-3.12"
        exit /b 0
    )
)
where python >nul 2>nul
if not errorlevel 1 (
    python -c "import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 12) else 1)" >nul 2>nul
    if not errorlevel 1 (
        set "PYTHON_EXE=python"
        exit /b 0
    )
)
if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" -c "import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 12) else 1)" >nul 2>nul
    if not errorlevel 1 (
        set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
        exit /b 0
    )
)
exit /b 1

:offer_python_install
where winget >nul 2>nul
if errorlevel 1 exit /b 1
set "INSTALL_PYTHON="
set /p "INSTALL_PYTHON=Python was not found. Install Python 3.12 with winget? [Y/n]: "
if /i "%INSTALL_PYTHON%"=="n" exit /b 1
if /i "%INSTALL_PYTHON%"=="no" exit /b 1
winget install --exact --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
if errorlevel 1 exit /b 1
call :find_python
exit /b %errorlevel%

:offer_ollama_install
echo Ollama was not found. Its official installer runs natively on Windows without WSL.
set "INSTALL_OLLAMA="
set /p "INSTALL_OLLAMA=Download and install Ollama from ollama.com now? [Y/n]: "
if /i "%INSTALL_OLLAMA%"=="n" exit /b 1
if /i "%INSTALL_OLLAMA%"=="no" exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://ollama.com/install.ps1 | iex"
if errorlevel 1 exit /b 1
exit /b 0

:docker_is_healthy
where docker >nul 2>nul
if errorlevel 1 exit /b 1
call :timed_docker_command "compose version"
if errorlevel 1 exit /b 1
call :timed_docker_command "info"
exit /b %errorlevel%

:timed_docker_command
powershell -NoProfile -Command "$psi=[Diagnostics.ProcessStartInfo]::new(); $psi.FileName='docker'; $psi.Arguments='%~1'; $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true; $p=[Diagnostics.Process]::new(); $p.StartInfo=$psi; [void]$p.Start(); if(-not $p.WaitForExit(12000)){ try{$p.Kill()}catch{}; exit 124 }; exit $p.ExitCode" >nul 2>nul
exit /b %errorlevel%

:wait_and_open
powershell -NoProfile -Command "$url='%APP_URL%'; $max=240; for($i=0;$i -lt $max;$i++){ try{ $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop; if($r.StatusCode -eq 200){ Write-Host 'App is ready! Opening browser...'; Start-Process $url; exit 0 } } catch{ if(($i %% 10) -eq 0){ Write-Host ('Waiting for the app... ' + ($i * 3) + ' seconds') } }; Start-Sleep -Seconds 3 }; Write-Host 'Timed out. Open manually:' $url; exit 1"
exit /b %errorlevel%
