@echo off
REM ============================================================================
REM Single Test Case Runner - Windows Proxy Settings
REM ============================================================================
REM Usage: run-single-test.cmd TC-101
REM ============================================================================

setlocal enabledelayedexpansion

REM Check if test ID provided
if "%~1"=="" (
    echo ERROR: Please provide a test ID
    echo.
    echo Usage: %~nx0 TC-101
    echo.
    pause
    exit /b 1
)

set TEST_ID=%~1
set OUTPUT_FOLDER=TestResults
set OUTPUT_FILE=%OUTPUT_FOLDER%\%TEST_ID%.reg
set REG_PATH=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections

REM Create output folder if it doesn't exist
if not exist "%OUTPUT_FOLDER%" (
    echo Creating output folder: %OUTPUT_FOLDER%
    mkdir "%OUTPUT_FOLDER%"
)

REM Check if file already exists
if exist "%OUTPUT_FILE%" (
    echo.
    echo ============================================================================
    echo WARNING: Output file already exists!
    echo ============================================================================
    echo.
    echo File: %OUTPUT_FILE%
    echo.
    choice /C YN /M "Overwrite existing file"
    if errorlevel 2 (
        echo.
        echo Cancelled by user
        pause
        exit /b 0
    )
)

echo.
echo ============================================================================
echo  PROXY SETTINGS TEST RUNNER
echo ============================================================================
echo.
echo  Test ID: %TEST_ID%
echo.
echo ============================================================================
echo.
echo INSTRUCTIONS:
echo.
echo  1. The Internet Options dialog will open to the Connections tab
echo  2. Click the "LAN settings" button
echo  3. Configure proxy settings for test case %TEST_ID%
echo  4. Click OK to close all dialogs
echo  5. Return to this window and press any key
echo.
echo ============================================================================
echo.
echo Press any key to open Internet Options...
pause >nul

REM Open Internet Options to Connections tab
echo.
echo Opening Internet Options (Connections tab)...
start rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl,,4

REM Wait a moment for the window to open
timeout /t 2 /nobreak >nul

echo.
echo Configure the proxy settings, then press any key when ready to export...
echo.
pause >nul

echo.
echo ============================================================================
echo  EXPORTING REGISTRY SETTINGS
echo ============================================================================
echo.
echo  Source: %REG_PATH%
echo  Target: %OUTPUT_FILE%
echo.

REM Export registry
reg export "%REG_PATH%" "%OUTPUT_FILE%" /y

if errorlevel 1 (
    echo.
    echo ============================================================================
    echo  ERROR: Registry export failed!
    echo ============================================================================
    echo.
    pause
    exit /b 1
)

REM Verify file was created
if not exist "%OUTPUT_FILE%" (
    echo.
    echo ============================================================================
    echo  ERROR: Export succeeded but file not found!
    echo ============================================================================
    echo.
    pause
    exit /b 1
)

REM Get file size
for %%A in ("%OUTPUT_FILE%") do set FILE_SIZE=%%~zA

echo.
echo ============================================================================
echo  SUCCESS: Registry exported successfully!
echo ============================================================================
echo.
echo  File: %OUTPUT_FILE%
echo  Size: %FILE_SIZE% bytes
echo.
echo ============================================================================
echo.

REM Ask if user wants to run decoder
choice /C YN /M "Run decoder on this file"
if errorlevel 2 goto :EOF

REM Check if decoder script exists
set DECODER_SCRIPT=..\Read-ProxyRegistryFiles.ps1
if not exist "%DECODER_SCRIPT%" (
    echo.
    echo Decoder script not found: %DECODER_SCRIPT%
    echo.
    pause
    exit /b 0
)

echo.
echo Running decoder...
echo.
powershell.exe -ExecutionPolicy Bypass -File "%DECODER_SCRIPT%" -FolderPath "%OUTPUT_FOLDER%"

echo.
echo.
pause
