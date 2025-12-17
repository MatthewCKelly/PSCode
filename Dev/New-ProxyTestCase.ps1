<#
.SYNOPSIS
    Helper script to create and manage proxy settings test cases
.DESCRIPTION
    This script helps create new test case files with proper naming and documentation
    templates. It can also track test execution status and generate reports.
.PARAMETER TestID
    Test case ID (e.g., TC-001, TC-205)
.PARAMETER TestName
    Descriptive name for the test case
.PARAMETER Action
    Action to perform: Create, Export, Verify, Report
.PARAMETER AutoExport
    Automatically export current proxy settings after creating test metadata
.EXAMPLE
    .\New-ProxyTestCase.ps1 -TestID TC-001 -TestName "DirectConnectionOnly" -Action Create
    Creates a new test case template file
.EXAMPLE
    .\New-ProxyTestCase.ps1 -Action Report
    Generates a test execution status report
.NOTES
    Version: 1.0
    Author: Claude AI Assistant
    Created: 2025-12-17
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^TC-\d{3}$')]
    [string]$TestID,

    [Parameter(Mandatory = $false)]
    [string]$TestName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Create', 'Export', 'Verify', 'Report', 'List')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [switch]$AutoExport
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

Function Get-ProxyTestFolder {
    $folder = Join-Path $PSScriptRoot "ProxySettingsKeys"
    if (-not (Test-Path $folder)) {
        Write-Detail "Creating ProxySettingsKeys folder" -Level Info
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }
    return $folder
}

Function New-TestCaseTemplate {
    param(
        [string]$TestID,
        [string]$TestName
    )

    $folder = Get-ProxyTestFolder
    $templateFile = Join-Path $folder "$TestID-$TestName.txt"

    if (Test-Path $templateFile) {
        Write-Detail "Test case template already exists: $templateFile" -Level Warning
        $overwrite = Read-Host "Overwrite existing file? (y/n)"
        if ($overwrite -ne 'y') {
            Write-Detail "Cancelled by user" -Level Info
            return $null
        }
    }

    $windowsVersion = if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell Core on non-Windows might not have this
        "PowerShell Core $($PSVersionTable.PSVersion)"
    } else {
        # Windows PowerShell
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            "$($os.Caption) $($os.Version)"
        } catch {
            "Unknown Windows Version"
        }
    }

    $template = @"
Test ID: $TestID
Test Name: $TestName
Windows Version: $windowsVersion
Export Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Tester: $env:USERNAME

==============================================================================
CONFIGURATION STEPS
==============================================================================

1. Open Internet Properties → Connections → LAN Settings
   - Windows 10/11: Win+R → inetcpl.cpl → Connections tab → LAN Settings button

2. Configure proxy settings as follows:
   [ ] Automatically detect settings
   [ ] Use automatic configuration script
       Address: _______________________________________

   [ ] Use a proxy server for your LAN
       Address: _______________ Port: _____

       [Advanced] button:
       [ ] Use the same proxy server for all protocols

       HTTP:   _______________ : _____
       Secure: _______________ : _____
       FTP:    _______________ : _____
       Socks:  _______________ : _____

       Exceptions (Do not use proxy for):
       ___________________________________________________

       [ ] Bypass proxy server for local addresses

3. Click OK to save settings

4. Export registry:
   reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" "$TestID-$TestName.reg"

==============================================================================
EXPECTED RESULTS
==============================================================================

After decoding, the script should return:

Version/Counter: __________
Flags: 0x________

Connection Flags:
  DirectConnection: True / False
  ProxyEnabled: True / False
  AutoConfigEnabled: True / False
  AutoDetectEnabled: True / False

Proxy Configuration:
  ProxyServer: _________________________________
  ProxyBypass: _________________________________

Auto Configuration:
  AutoConfigURL: _________________________________

==============================================================================
ACTUAL RESULTS
==============================================================================

[Paste output from .\Read-ProxyRegistryFiles.ps1 here after running test]

Binary Size: _____ bytes
First 32 bytes: __ __ __ __ __ __ __ __ ...

Decoded Output:
Version/Counter: __________
Flags: 0x________
DirectConnection: __________
ProxyEnabled: __________
ProxyServer: __________
ProxyBypass: __________
AutoConfigEnabled: __________
AutoConfigURL: __________
AutoDetectEnabled: __________

==============================================================================
VALIDATION
==============================================================================

[ ] Binary data extracted successfully from .reg file
[ ] Version field parsed correctly
[ ] Flags field matches expected value
[ ] DirectConnection flag correct
[ ] ProxyEnabled flag correct
[ ] ProxyServer string matches configuration (if applicable)
[ ] ProxyBypass string matches configuration (if applicable)
[ ] AutoConfigEnabled flag correct
[ ] AutoConfigURL matches configuration (if applicable)
[ ] AutoDetectEnabled flag correct
[ ] No null characters in strings
[ ] No extra whitespace in strings
[ ] Field offsets calculated correctly
[ ] Total binary length correct

TEST RESULT: [ ] PASS  [ ] FAIL  [ ] PARTIAL

==============================================================================
NOTES
==============================================================================

[Add any special observations, issues encountered, or edge cases noted during testing]

==============================================================================
RELATED TEST CASES
==============================================================================

Previous Test: TC-___
Next Test: TC-___
Related Tests: TC-___, TC-___, TC-___

"@

    try {
        $template | Out-File -FilePath $templateFile -Encoding UTF8 -Force
        Write-Detail "Created test case template: $templateFile" -Level Success
        return $templateFile
    }
    catch {
        Write-Detail "Failed to create template: $($_.Exception.Message)" -Level Error
        return $null
    }
}

Function Export-CurrentProxySettings {
    param(
        [string]$TestID,
        [string]$TestName
    )

    $folder = Get-ProxyTestFolder
    $regFile = Join-Path $folder "$TestID-$TestName.reg"

    Write-Detail "Exporting current proxy settings to: $regFile" -Level Info

    # Export registry
    $regPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"

    try {
        $result = reg export $regPath $regFile /y 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Detail "Registry exported successfully" -Level Success
            return $regFile
        }
        else {
            Write-Detail "Registry export failed: $result" -Level Error
            return $null
        }
    }
    catch {
        Write-Detail "Error during export: $($_.Exception.Message)" -Level Error
        return $null
    }
}

Function Test-ProxyTestCase {
    param(
        [string]$TestID,
        [string]$TestName
    )

    $folder = Get-ProxyTestFolder
    $regFile = Join-Path $folder "$TestID-$TestName.reg"
    $txtFile = Join-Path $folder "$TestID-$TestName.txt"

    Write-Detail "Verifying test case: $TestID" -Level Info

    $issues = @()

    # Check if .reg file exists
    if (-not (Test-Path $regFile)) {
        $issues += "Missing .reg file: $regFile"
    }

    # Check if .txt file exists
    if (-not (Test-Path $txtFile)) {
        $issues += "Missing .txt file: $txtFile"
    }

    # Check if decoder script exists
    $decoderScript = Join-Path $PSScriptRoot "Read-ProxyRegistryFiles.ps1"
    if (-not (Test-Path $decoderScript)) {
        $issues += "Missing decoder script: $decoderScript"
    }

    if ($issues.Count -gt 0) {
        Write-Detail "Verification failed with $($issues.Count) issue(s):" -Level Error
        foreach ($issue in $issues) {
            Write-Host "  ❌ $issue" -ForegroundColor Red
        }
        return $false
    }

    Write-Detail "Test case files verified successfully" -Level Success
    return $true
}

Function Get-AllTestCases {
    $folder = Get-ProxyTestFolder
    $regFiles = Get-ChildItem -Path $folder -Filter "TC-*.reg" -File | Sort-Object Name

    $testCases = @()

    foreach ($regFile in $regFiles) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($regFile.Name)

        # Extract Test ID (TC-XXX)
        if ($baseName -match '^(TC-\d{3})') {
            $testID = $Matches[1]
        } else {
            $testID = "Unknown"
        }

        # Check for companion .txt file
        $txtFile = Join-Path $folder "$baseName.txt"
        $hasTxt = Test-Path $txtFile

        # Try to determine status from .txt file if it exists
        $status = "Unknown"
        if ($hasTxt) {
            $content = Get-Content $txtFile -Raw
            if ($content -match 'TEST RESULT:.*\[X\]\s*PASS') {
                $status = "✅ Passed"
            }
            elseif ($content -match 'TEST RESULT:.*\[X\]\s*FAIL') {
                $status = "❌ Failed"
            }
            elseif ($content -match 'TEST RESULT:.*\[X\]\s*PARTIAL') {
                $status = "⚠️ Partial"
            }
            else {
                $status = "⬜ Not Tested"
            }
        }

        $testCases += [PSCustomObject]@{
            TestID = $testID
            FileName = $regFile.Name
            HasTemplate = $hasTxt
            Status = $status
            FileSize = $regFile.Length
            LastModified = $regFile.LastWriteTime
        }
    }

    return $testCases
}

Function Show-TestReport {
    $testCases = Get-AllTestCases

    Write-Host ""
    Write-Detail "Proxy Settings Test Case Report" -Level Info
    Write-Detail ("=" * 80) -Level Info
    Write-Host ""

    if ($testCases.Count -eq 0) {
        Write-Detail "No test cases found" -Level Warning
        Write-Host ""
        Write-Host "To create a new test case, run:" -ForegroundColor Cyan
        Write-Host '  .\New-ProxyTestCase.ps1 -TestID TC-001 -TestName "DirectConnectionOnly" -Action Create' -ForegroundColor Gray
        return
    }

    Write-Host "Total test cases: $($testCases.Count)" -ForegroundColor White
    Write-Host ""

    # Summary statistics
    $withTemplates = ($testCases | Where-Object { $_.HasTemplate }).Count
    $withoutTemplates = $testCases.Count - $withTemplates

    $passed = ($testCases | Where-Object { $_.Status -like "*Passed*" }).Count
    $failed = ($testCases | Where-Object { $_.Status -like "*Failed*" }).Count
    $partial = ($testCases | Where-Object { $_.Status -like "*Partial*" }).Count
    $notTested = ($testCases | Where-Object { $_.Status -like "*Not Tested*" }).Count

    Write-Host "Test Templates:" -ForegroundColor Cyan
    Write-Host "  With documentation: $withTemplates" -ForegroundColor $(if ($withTemplates -eq $testCases.Count) {'Green'} else {'Yellow'})
    Write-Host "  Missing docs: $withoutTemplates" -ForegroundColor $(if ($withoutTemplates -gt 0) {'Red'} else {'Green'})
    Write-Host ""

    Write-Host "Test Results:" -ForegroundColor Cyan
    Write-Host "  ✅ Passed: $passed" -ForegroundColor Green
    Write-Host "  ❌ Failed: $failed" -ForegroundColor $(if ($failed -gt 0) {'Red'} else {'Gray'})
    Write-Host "  ⚠️  Partial: $partial" -ForegroundColor $(if ($partial -gt 0) {'Yellow'} else {'Gray'})
    Write-Host "  ⬜ Not Tested: $notTested" -ForegroundColor Gray
    Write-Host ""

    # Detailed list
    Write-Detail "Test Case Details:" -Level Info
    Write-Host ""

    $testCases | Format-Table -Property TestID, FileName, HasTemplate, Status, FileSize, LastModified -AutoSize

    Write-Host ""
    Write-Detail ("=" * 80) -Level Info
}

Function Show-TestList {
    $testCases = Get-AllTestCases

    if ($testCases.Count -eq 0) {
        Write-Detail "No test cases found" -Level Warning
        return
    }

    Write-Host "`nAvailable Test Cases:" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan

    foreach ($test in $testCases) {
        $icon = if ($test.HasTemplate) { "📄" } else { "❓" }
        Write-Host "$icon $($test.TestID) - $($test.FileName)" -ForegroundColor White
        Write-Host "   Status: $($test.Status)" -ForegroundColor Gray
        Write-Host "   Modified: $($test.LastModified.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        Write-Host ""
    }
}

#endregion

#region Main Execution

try {
    Write-Host ""
    Write-Detail "Proxy Settings Test Case Manager" -Level Info
    Write-Detail ("=" * 80) -Level Info
    Write-Host ""

    switch ($Action) {
        'Create' {
            if (-not $TestID -or -not $TestName) {
                Write-Detail "TestID and TestName are required for Create action" -Level Error
                Write-Host "Example: .\New-ProxyTestCase.ps1 -TestID TC-001 -TestName 'DirectConnectionOnly' -Action Create" -ForegroundColor Yellow
                exit 1
            }

            $templateFile = New-TestCaseTemplate -TestID $TestID -TestName $TestName

            if ($templateFile) {
                Write-Host ""
                Write-Host "Next steps:" -ForegroundColor Cyan
                Write-Host "1. Configure Windows proxy settings according to test case" -ForegroundColor White
                Write-Host "2. Export registry:" -ForegroundColor White
                Write-Host "   .\New-ProxyTestCase.ps1 -TestID $TestID -TestName '$TestName' -Action Export" -ForegroundColor Gray
                Write-Host "3. Fill in the template file with test details:" -ForegroundColor White
                Write-Host "   notepad `"$templateFile`"" -ForegroundColor Gray

                if ($AutoExport) {
                    Write-Host ""
                    Write-Detail "Auto-export enabled, exporting current proxy settings..." -Level Info
                    Export-CurrentProxySettings -TestID $TestID -TestName $TestName
                }
            }
        }

        'Export' {
            if (-not $TestID -or -not $TestName) {
                Write-Detail "TestID and TestName are required for Export action" -Level Error
                exit 1
            }

            $regFile = Export-CurrentProxySettings -TestID $TestID -TestName $TestName

            if ($regFile) {
                Write-Host ""
                Write-Host "Next steps:" -ForegroundColor Cyan
                Write-Host "1. Update the test template with actual results:" -ForegroundColor White
                Write-Host "   notepad `"$(Join-Path (Get-ProxyTestFolder) "$TestID-$TestName.txt")`"" -ForegroundColor Gray
                Write-Host "2. Run the decoder to verify:" -ForegroundColor White
                Write-Host "   .\Read-ProxyRegistryFiles.ps1" -ForegroundColor Gray
            }
        }

        'Verify' {
            if (-not $TestID -or -not $TestName) {
                Write-Detail "TestID and TestName are required for Verify action" -Level Error
                exit 1
            }

            $result = Test-ProxyTestCase -TestID $TestID -TestName $TestName

            if ($result) {
                Write-Host ""
                Write-Host "To run decoder on this test case:" -ForegroundColor Cyan
                Write-Host "  .\Read-ProxyRegistryFiles.ps1" -ForegroundColor Gray
            }
        }

        'Report' {
            Show-TestReport
        }

        'List' {
            Show-TestList
        }
    }

    Write-Host ""
    Write-Detail ("=" * 80) -Level Info
    Write-Detail "Operation completed" -Level Success
    Write-Host ""

}
catch {
    Write-Detail "Unexpected error: $($_.Exception.Message)" -Level Error
    Write-Detail "Stack trace: $($_.ScriptStackTrace)" -Level Debug
    exit 1
}

#endregion
