@echo off
REM Windows Batch wrapper for PowerShell setup script
REM IOS-XE Software Upgrade - Windows Setup

echo Starting PowerShell setup script...
echo.

REM Check if PowerShell is available
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not installed or not in PATH
    echo Please install PowerShell or run setup_venv.ps1 manually
    pause
    exit /b 1
)

REM Run the PowerShell script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0setup_venv.ps1"

if %errorlevel% neq 0 (
    echo.
    echo Setup failed. Check the error messages above.
    pause
    exit /b 1
)

echo.
echo Setup completed successfully!
pause

