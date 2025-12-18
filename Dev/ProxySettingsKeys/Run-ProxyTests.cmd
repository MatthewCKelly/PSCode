@echo off
REM ============================================================================
REM Automated Proxy Settings Test Runner
REM ============================================================================
REM Executes all test cases from TEST-MATRIX.csv interactively
REM ============================================================================

setlocal enabledelayedexpansion

REM Configuration
set "CSV_FILE=TEST-MATRIX.csv"
set "OUTPUT_FOLDER=TestResults"
set "PROGRESS_FILE=test-progress.txt"
set "REG_PATH=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"

REM Statistics
set /a TOTAL_TESTS=0
set /a COMPLETED=0
set /a SKIPPED=0
set /a FAILED=0
set /a CURRENT_TEST=0

REM Check if CSV file exists
if not exist "%CSV_FILE%" (
    echo.
    echo ============================================================================
    echo ERROR: TEST-MATRIX.csv not found!
    echo ============================================================================
    echo.
    echo Expected location: %CSV_FILE%
    echo.
    pause
    exit /b 1
)

REM Create output folder
if not exist "%OUTPUT_FOLDER%" (
    echo Creating output folder: %OUTPUT_FOLDER%
    mkdir "%OUTPUT_FOLDER%"
)

REM Count total tests (subtract 1 for header)
for /f %%A in ('type "%CSV_FILE%" ^| find /c /v ""') do set /a TOTAL_TESTS=%%A-1

REM Display welcome screen
cls
echo.
echo ================================================================================
echo   PROXY SETTINGS TEST RUNNER
echo ================================================================================
echo.
echo   Total Test Cases: %TOTAL_TESTS%
echo   Output Folder:    %OUTPUT_FOLDER%
echo.
echo ================================================================================
echo.
echo This script will guide you through testing all Windows proxy configurations.
echo.
echo For each test:
echo   1. Instructions will be displayed
echo   2. Internet Options will open to the Connections tab
echo   3. You configure the proxy settings as specified
echo   4. Press ENTER to export the registry
echo   5. Continue to next test
echo.
echo You can skip tests or quit at any time.
echo.
echo ================================================================================
echo.
echo Press any key to begin...
pause >nul

REM Process each line in CSV
set "SKIP_HEADER=1"

for /f "usebackq tokens=1-5 delims=," %%A in ("%CSV_FILE%") do (
    REM Skip header row
    if !SKIP_HEADER!==1 (
        set "SKIP_HEADER=0"
    ) else (
        set "TEST_ID=%%A"
        set "TEST_NAME=%%B"
        set "CONFIGURATION=%%C"
        set "EXPECTED=%%D"
        set "EXPORT_CMD=%%E"

        REM Remove quotes from fields
        set "TEST_ID=!TEST_ID:"=!"
        set "TEST_NAME=!TEST_NAME:"=!"

        REM Increment counter
        set /a CURRENT_TEST+=1

        REM Create output filename
        set "OUTPUT_FILE=%OUTPUT_FOLDER%\!TEST_ID!-!TEST_NAME!.reg"
        set "OUTPUT_FILE=!OUTPUT_FILE: =-!"

        REM Display test information
        call :ShowTestInstructions

        REM Ask to proceed
        echo.
        echo Ready to configure test !TEST_ID!?
        echo   [Y] Yes, proceed with this test
        echo   [N] No, skip this test
        echo   [Q] Quit test runner
        echo.
        choice /C YNQ /N /M "Choice (Y/N/Q): "

        if errorlevel 3 goto :EndTesting
        if errorlevel 2 (
            echo.
            echo Skipped test !TEST_ID!
            set /a SKIPPED+=1
            echo !TEST_ID!,Skipped,!DATE! !TIME! >> "%PROGRESS_FILE%"
            echo.
            echo Press any key to continue...
            pause >nul
            goto :NextTest
        )

        REM Check if file already exists
        if exist "!OUTPUT_FILE!" (
            echo.
            echo ============================================================================
            echo WARNING: Output file already exists!
            echo ============================================================================
            echo.
            echo File: !OUTPUT_FILE!
            echo.
            choice /C YN /M "Overwrite existing file"
            if errorlevel 2 (
                echo.
                echo Skipped test !TEST_ID! - file exists
                set /a SKIPPED+=1
                echo !TEST_ID!,Skipped (file exists),!DATE! !TIME! >> "%PROGRESS_FILE%"
                echo.
                echo Press any key to continue...
                pause >nul
                goto :NextTest
            )
        )

        REM Open Internet Options
        echo.
        echo ============================================================================
        echo   OPENING INTERNET OPTIONS
        echo ============================================================================
        echo.
        echo Launching Internet Options (Connections tab)...
        start rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl,,4

        REM Wait for window to open
        timeout /t 2 /nobreak >nul

        echo.
        echo   1. Click "LAN settings" button
        echo   2. Configure proxy settings as shown above
        echo   3. Click OK to close all dialogs
        echo   4. Return here and press ENTER
        echo.
        echo ============================================================================
        echo.
        pause

        REM Export registry
        echo.
        echo ============================================================================
        echo   EXPORTING REGISTRY SETTINGS
        echo ============================================================================
        echo.
        echo   Source: %REG_PATH%
        echo   Target: !OUTPUT_FILE!
        echo.

        reg export "%REG_PATH%" "!OUTPUT_FILE!" /y >nul 2>&1

        if errorlevel 1 (
            echo.
            echo   [X] Registry export FAILED!
            echo.
            set /a FAILED+=1
            echo !TEST_ID!,Failed,!DATE! !TIME! >> "%PROGRESS_FILE%"
        ) else (
            if exist "!OUTPUT_FILE!" (
                for %%F in ("!OUTPUT_FILE!") do set "FILE_SIZE=%%~zF"
                echo.
                echo   [√] Registry exported successfully!
                echo   [√] File size: !FILE_SIZE! bytes
                echo.
                set /a COMPLETED+=1
                echo !TEST_ID!,Completed,!DATE! !TIME!,!OUTPUT_FILE! >> "%PROGRESS_FILE%"
            ) else (
                echo.
                echo   [X] Export succeeded but file not found!
                echo.
                set /a FAILED+=1
                echo !TEST_ID!,Failed (file not found),!DATE! !TIME! >> "%PROGRESS_FILE%"
            )
        )

        echo ============================================================================
        echo.

        REM Pause before next test
        if !CURRENT_TEST! LSS %TOTAL_TESTS% (
            echo Press any key to continue to next test...
            pause >nul
        )

        :NextTest
    )
)

:EndTesting

REM Display summary
cls
echo.
echo ================================================================================
echo   TEST EXECUTION SUMMARY
echo ================================================================================
echo.
echo   Total Tests:   %TOTAL_TESTS%
echo   Completed:     %COMPLETED%
echo   Skipped:       %SKIPPED%
echo   Failed:        %FAILED%
echo.
echo   Output Folder: %CD%\%OUTPUT_FOLDER%
echo   Progress File: %PROGRESS_FILE%
echo.
echo ================================================================================
echo.

REM Offer to run decoder
if %COMPLETED% GTR 0 (
    echo.
    choice /C YN /M "Run decoder on all exported files"
    if not errorlevel 2 (
        set "DECODER_SCRIPT=..\Read-ProxyRegistryFiles.ps1"
        if exist "!DECODER_SCRIPT!" (
            echo.
            echo Running decoder...
            echo.
            powershell.exe -ExecutionPolicy Bypass -File "!DECODER_SCRIPT!" -FolderPath "%OUTPUT_FOLDER%"
        ) else (
            echo.
            echo Decoder script not found: !DECODER_SCRIPT!
        )
    )
)

echo.
echo Test runner completed!
echo.
pause
exit /b 0

REM ============================================================================
REM Subroutine: Display test instructions
REM ============================================================================
:ShowTestInstructions
cls
echo.
echo ================================================================================
echo   PROXY SETTINGS TEST RUNNER
echo ================================================================================
echo.
echo   Test Progress: %CURRENT_TEST% of %TOTAL_TESTS%
echo.
echo   Test ID:   !TEST_ID!
echo   Test Name: !TEST_NAME!
echo.
echo ================================================================================
echo.
echo CONFIGURATION INSTRUCTIONS:
echo.

REM Parse configuration (split on semicolons)
set "CONFIG_DISPLAY=!CONFIGURATION!"
set "CONFIG_DISPLAY=!CONFIG_DISPLAY:"=!"

REM Replace semicolons with newlines for display
set "CONFIG_DISPLAY=!CONFIG_DISPLAY:;=^

!"

REM Display each line with bullet point
for /f "tokens=* delims=" %%L in ("!CONFIG_DISPLAY!") do (
    set "LINE=%%L"
    if defined LINE (
        echo   * !LINE!
    )
)

echo.
echo ================================================================================
echo.
echo EXPECTED RESULT:
echo.

REM Parse expected behavior
set "EXPECTED_DISPLAY=!EXPECTED!"
set "EXPECTED_DISPLAY=!EXPECTED_DISPLAY:"=!"

REM Display expected result
for /f "tokens=* delims=" %%L in ("!EXPECTED_DISPLAY!") do (
    set "LINE=%%L"
    if defined LINE (
        echo   √ !LINE!
    )
)

echo.
echo ================================================================================
echo.
goto :EOF
