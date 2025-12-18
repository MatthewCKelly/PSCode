<#
.SYNOPSIS
    Interactive test runner for Windows proxy settings test cases
.DESCRIPTION
    This script automates the execution of proxy settings test cases by:
    1. Reading test cases from TEST-MATRIX.csv
    2. Creating a testing output folder
    3. Displaying test instructions
    4. Launching the Internet Options control panel
    5. Pausing for manual configuration
    6. Exporting registry settings
    7. Tracking completion status
.PARAMETER TestID
    Specific test ID to run (e.g., TC-101). If not specified, runs all tests.
.PARAMETER StartFrom
    Start from a specific test ID and continue through remaining tests
.PARAMETER OutputFolder
    Folder to save exported .reg files (default: .\TestResults)
.PARAMETER SkipExisting
    Skip tests that already have exported .reg files
.EXAMPLE
    .\Run-ProxyTests.ps1
    Runs all test cases interactively
.EXAMPLE
    .\Run-ProxyTests.ps1 -TestID TC-101
    Runs only test case TC-101
.EXAMPLE
    .\Run-ProxyTests.ps1 -StartFrom TC-205 -SkipExisting
    Starts from TC-205 and skips any tests with existing .reg files
.NOTES
    Version: 1.0
    Author: Claude AI Assistant
    Created: 2025-12-17
    Requires: Windows with Internet Options control panel
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TestID,

    [Parameter(Mandatory = $false)]
    [string]$StartFrom,

    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = ".\TestResults",

    [Parameter(Mandatory = $false)]
    [switch]$SkipExisting
)

#region Helper Functions

Function Write-Detail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $caller = (Get-PSCallStack)[1]
    $lineNumber = $caller.ScriptLineNumber

    $logEntry = "[{0}] {1,-7} {2,4} {3}" -f $timestamp, $Level, $lineNumber, $Message

    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Debug'   { Write-Host $logEntry -ForegroundColor DarkGray }
        default   { Write-Host $logEntry -ForegroundColor Gray }
    }
}

Function Show-TestInstructions {
    param(
        [PSCustomObject]$TestCase,
        [int]$TestNumber,
        [int]$TotalTests
    )

    Clear-Host

    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host "  PROXY SETTINGS TEST RUNNER" -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Test Progress: " -NoNewline -ForegroundColor White
    Write-Host "$TestNumber of $TotalTests" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Test ID:   " -NoNewline -ForegroundColor White
    Write-Host $TestCase.'Test ID' -ForegroundColor Cyan
    Write-Host "  Test Name: " -NoNewline -ForegroundColor White
    Write-Host $TestCase.'Test Name' -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""

    Write-Host "CONFIGURATION INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host ""

    # Parse and display configuration steps
    $configLines = $TestCase.Configuration -split ';'
    foreach ($line in $configLines) {
        $line = $line.Trim()
        if ($line) {
            Write-Host "  • " -NoNewline -ForegroundColor Green
            Write-Host $line -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""

    Write-Host "EXPECTED RESULT:" -ForegroundColor Yellow
    Write-Host ""

    # Parse and display expected behavior
    $expectedLines = $TestCase.'Expected Behavior' -split ';'
    foreach ($line in $expectedLines) {
        $line = $line.Trim()
        if ($line) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host $line -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""
}

Function Open-InternetOptions {
    param(
        [switch]$ConnectionsTab
    )

    Write-Host "Launching Internet Options..." -ForegroundColor Cyan

    try {
        if ($ConnectionsTab) {
            # Open directly to Connections tab (tab index 4)
            Start-Process "rundll32.exe" -ArgumentList "shell32.dll,Control_RunDLL inetcpl.cpl,,4"
            Write-Host "  ✓ Opened to Connections tab" -ForegroundColor Green
        }
        else {
            # Open to default tab
            Start-Process "control.exe" -ArgumentList "inetcpl.cpl"
            Write-Host "  ✓ Opened Internet Options" -ForegroundColor Green
        }

        Start-Sleep -Seconds 2
        return $true
    }
    catch {
        Write-Detail "Failed to open Internet Options: $($_.Exception.Message)" -Level Error
        return $false
    }
}

Function Export-ProxySettings {
    param(
        [string]$OutputPath,
        [string]$TestID
    )

    $regPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"

    Write-Host ""
    Write-Host "Exporting registry settings..." -ForegroundColor Cyan
    Write-Host "  Source: $regPath" -ForegroundColor Gray
    Write-Host "  Target: $OutputPath" -ForegroundColor Gray
    Write-Host ""

    try {
        # Ensure output directory exists
        $outputDir = Split-Path -Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }

        # Export registry
        $result = reg export $regPath $OutputPath /y 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Registry exported successfully" -ForegroundColor Green

            # Verify file was created
            if (Test-Path $OutputPath) {
                $fileInfo = Get-Item $OutputPath
                Write-Host "  ✓ File created: $($fileInfo.Length) bytes" -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "  ✗ Export succeeded but file not found" -ForegroundColor Red
                return $false
            }
        }
        else {
            Write-Host "  ✗ Registry export failed: $result" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Detail "Error during export: $($_.Exception.Message)" -Level Error
        return $false
    }
}

Function Get-UserChoice {
    param(
        [string]$Prompt,
        [string[]]$ValidChoices,
        [string]$DefaultChoice
    )

    $choiceStr = ($ValidChoices | ForEach-Object { $_.ToUpper() }) -join '/'

    do {
        Write-Host ""
        Write-Host "$Prompt [$choiceStr] (default: $DefaultChoice): " -NoNewline -ForegroundColor Yellow
        $input = Read-Host

        if ([string]::IsNullOrWhiteSpace($input)) {
            $input = $DefaultChoice
        }

        $input = $input.ToUpper()

        if ($ValidChoices -contains $input) {
            return $input
        }
        else {
            Write-Host "Invalid choice. Please enter one of: $choiceStr" -ForegroundColor Red
        }
    } while ($true)
}

Function Save-TestProgress {
    param(
        [string]$TestID,
        [string]$Status,
        [string]$OutputFile,
        [string]$ProgressFile = ".\test-progress.json"
    )

    $progress = @{}

    if (Test-Path $ProgressFile) {
        $progress = Get-Content $ProgressFile -Raw | ConvertFrom-Json -AsHashtable
    }

    if (-not $progress.ContainsKey('Tests')) {
        $progress['Tests'] = @{}
    }

    $progress.Tests[$TestID] = @{
        Status = $Status
        OutputFile = $OutputFile
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    $progress | ConvertTo-Json -Depth 10 | Out-File -FilePath $ProgressFile -Encoding UTF8 -Force
}

Function Get-TestProgress {
    param(
        [string]$ProgressFile = ".\test-progress.json"
    )

    if (Test-Path $ProgressFile) {
        return Get-Content $ProgressFile -Raw | ConvertFrom-Json -AsHashtable
    }

    return @{ Tests = @{} }
}

#endregion

#region Main Execution

try {
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host "  PROXY SETTINGS TEST RUNNER - INITIALIZATION" -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""

    # Validate CSV file exists
    $csvPath = Join-Path $PSScriptRoot "TEST-MATRIX.csv"
    if (-not (Test-Path $csvPath)) {
        Write-Detail "TEST-MATRIX.csv not found: $csvPath" -Level Error
        exit 1
    }

    Write-Detail "Loading test cases from: $csvPath" -Level Info

    # Load test cases
    $allTests = Import-Csv -Path $csvPath

    Write-Detail "Loaded $($allTests.Count) test cases" -Level Success

    # Filter tests based on parameters
    $testsToRun = @()

    if ($TestID) {
        # Run specific test
        $testsToRun = $allTests | Where-Object { $_.'Test ID' -eq $TestID }
        if ($testsToRun.Count -eq 0) {
            Write-Detail "Test ID not found: $TestID" -Level Error
            exit 1
        }
        Write-Detail "Running single test: $TestID" -Level Info
    }
    elseif ($StartFrom) {
        # Start from specific test
        $startIndex = [array]::IndexOf($allTests.'Test ID', $StartFrom)
        if ($startIndex -eq -1) {
            Write-Detail "Start test ID not found: $StartFrom" -Level Error
            exit 1
        }
        $testsToRun = $allTests[$startIndex..($allTests.Count - 1)]
        Write-Detail "Starting from test: $StartFrom ($($testsToRun.Count) tests remaining)" -Level Info
    }
    else {
        # Run all tests
        $testsToRun = $allTests
        Write-Detail "Running all tests" -Level Info
    }

    # Create output folder
    if (-not (Test-Path $OutputFolder)) {
        New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
        Write-Detail "Created output folder: $OutputFolder" -Level Success
    }
    else {
        Write-Detail "Using existing output folder: $OutputFolder" -Level Info
    }

    # Load progress
    $progress = Get-TestProgress

    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Green
    Write-Host "  READY TO START TESTING" -ForegroundColor Green
    Write-Host ("=" * 100) -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to begin..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

    # Run tests
    $testNumber = 0
    $completed = 0
    $skipped = 0
    $failed = 0

    foreach ($test in $testsToRun) {
        $testNumber++
        $testId = $test.'Test ID'
        $outputFile = Join-Path $OutputFolder "$testId-$($test.'Test Name' -replace ' ','-').reg"

        # Check if already completed
        if ($SkipExisting -and (Test-Path $outputFile)) {
            Write-Host ""
            Write-Host "Skipping $testId - file already exists: $outputFile" -ForegroundColor Yellow
            $skipped++
            continue
        }

        # Show test instructions
        Show-TestInstructions -TestCase $test -TestNumber $testNumber -TotalTests $testsToRun.Count

        Write-Host "NEXT STEPS:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. Press ENTER to open Internet Options (Connections tab)" -ForegroundColor White
        Write-Host "  2. Click 'LAN settings' button" -ForegroundColor White
        Write-Host "  3. Configure proxy settings as shown above" -ForegroundColor White
        Write-Host "  4. Click OK to close all dialogs" -ForegroundColor White
        Write-Host "  5. Return to this window and press ENTER to export" -ForegroundColor White
        Write-Host ""
        Write-Host ("=" * 100) -ForegroundColor Cyan
        Write-Host ""

        # Ask to proceed
        $choice = Get-UserChoice -Prompt "Ready to configure test $testId?" -ValidChoices @('Y', 'N', 'S', 'Q') -DefaultChoice 'Y'

        switch ($choice) {
            'Q' {
                Write-Host ""
                Write-Host "Test runner quit by user" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Summary: Completed=$completed, Skipped=$skipped, Failed=$failed" -ForegroundColor Cyan
                exit 0
            }
            'S' {
                Write-Host ""
                Write-Host "Skipped test $testId" -ForegroundColor Yellow
                $skipped++
                Save-TestProgress -TestID $testId -Status "Skipped" -OutputFile ""
                continue
            }
            'N' {
                Write-Host ""
                $retry = Get-UserChoice -Prompt "Skip this test?" -ValidChoices @('Y', 'N') -DefaultChoice 'N'
                if ($retry -eq 'Y') {
                    Write-Host "Skipped test $testId" -ForegroundColor Yellow
                    $skipped++
                    Save-TestProgress -TestID $testId -Status "Skipped" -OutputFile ""
                    continue
                }
            }
        }

        # Open Internet Options
        Write-Host ""
        $opened = Open-InternetOptions -ConnectionsTab

        if (-not $opened) {
            Write-Host ""
            Write-Host "Failed to open Internet Options. Please open manually:" -ForegroundColor Red
            Write-Host "  rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl,,4" -ForegroundColor Gray
            Write-Host ""
        }

        Write-Host ""
        Write-Host "Configure the proxy settings, then press ENTER when ready to export..." -ForegroundColor Yellow
        Read-Host

        # Export settings
        $exported = Export-ProxySettings -OutputPath $outputFile -TestID $testId

        if ($exported) {
            $completed++
            Save-TestProgress -TestID $testId -Status "Completed" -OutputFile $outputFile

            Write-Host ""
            Write-Host ("=" * 100) -ForegroundColor Green
            Write-Host "  ✓ TEST $testId COMPLETED SUCCESSFULLY" -ForegroundColor Green
            Write-Host ("=" * 100) -ForegroundColor Green
            Write-Host ""
            Write-Host "Output saved to: $outputFile" -ForegroundColor Cyan
        }
        else {
            $failed++
            Save-TestProgress -TestID $testId -Status "Failed" -OutputFile ""

            Write-Host ""
            Write-Host ("=" * 100) -ForegroundColor Red
            Write-Host "  ✗ TEST $testId FAILED" -ForegroundColor Red
            Write-Host ("=" * 100) -ForegroundColor Red
        }

        # Pause before next test
        if ($testNumber -lt $testsToRun.Count) {
            Write-Host ""
            Write-Host "Press any key to continue to next test..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    }

    # Final summary
    Write-Host ""
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host "  TEST EXECUTION SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total Tests:   " -NoNewline -ForegroundColor White
    Write-Host $testsToRun.Count -ForegroundColor Cyan
    Write-Host "  Completed:     " -NoNewline -ForegroundColor White
    Write-Host $completed -ForegroundColor Green
    Write-Host "  Skipped:       " -NoNewline -ForegroundColor White
    Write-Host $skipped -ForegroundColor Yellow
    Write-Host "  Failed:        " -NoNewline -ForegroundColor White
    Write-Host $failed -ForegroundColor $(if ($failed -gt 0) {'Red'} else {'Green'})
    Write-Host ""
    Write-Host "  Output Folder: " -NoNewline -ForegroundColor White
    Write-Host (Resolve-Path $OutputFolder) -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""

    # Offer to run decoder
    if ($completed -gt 0) {
        Write-Host "Would you like to run the decoder on all exported files?" -ForegroundColor Yellow
        $runDecoder = Get-UserChoice -Prompt "Run decoder" -ValidChoices @('Y', 'N') -DefaultChoice 'Y'

        if ($runDecoder -eq 'Y') {
            $decoderScript = Join-Path $PSScriptRoot ".." "Read-ProxyRegistryFiles.ps1"
            if (Test-Path $decoderScript) {
                Write-Host ""
                Write-Host "Running decoder..." -ForegroundColor Cyan
                & $decoderScript -FolderPath $OutputFolder
            }
            else {
                Write-Host ""
                Write-Host "Decoder script not found: $decoderScript" -ForegroundColor Red
            }
        }
    }

    Write-Host ""
    Write-Host "Test runner completed!" -ForegroundColor Green
    Write-Host ""

}
catch {
    Write-Detail "Unexpected error: $($_.Exception.Message)" -Level Error
    Write-Detail "Stack trace: $($_.ScriptStackTrace)" -Level Debug
    exit 1
}

#endregion
