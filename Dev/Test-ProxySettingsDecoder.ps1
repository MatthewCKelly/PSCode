<#
.SYNOPSIS
    Test harness for DefaultConnectionSettings decoder using registry exports
.DESCRIPTION
    This script tests the Decode-ConnectionSettings function against multiple
    registry export (.reg) files to verify correct parsing of different
    proxy configuration scenarios.
.PARAMETER TestFolder
    Path to folder containing .reg test files (default: ./ProxySettingsKeys)
.PARAMETER Verbose
    Show detailed debug output for each test
.EXAMPLE
    .\Test-ProxySettingsDecoder.ps1
    Runs all tests in the ProxySettingsKeys folder
.EXAMPLE
    .\Test-ProxySettingsDecoder.ps1 -Verbose
    Runs tests with detailed debug output
.NOTES
    Requires .reg files exported from:
    HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections

    Export command:
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" filename.reg
#>

[CmdletBinding()]
param(
    [string]$TestFolder = "$PSScriptRoot\ProxySettingsKeys",
    [switch]$Verbose
)

#region Import Functions from Main Script

# Source the Read-DefaultProxySettings script to get the functions
$SourceScript = Join-Path $PSScriptRoot "Read-DefaultProxySettings.ps1"

if (-not (Test-Path $SourceScript)) {
    Write-Error "Cannot find source script: $SourceScript"
    exit 1
}

# Load the functions by dot-sourcing (but capture output to avoid running main logic)
$null = . $SourceScript 2>&1

#endregion

#region Helper Functions

Function Parse-RegFile {
    param([string]$FilePath)

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Parsing: $(Split-Path -Leaf $FilePath)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $null
    }

    $Content = Get-Content $FilePath -Raw

    # Look for DefaultConnectionSettings value
    # Format: "DefaultConnectionSettings"=hex:46,00,00,00,4a,01,00,00,...
    $Pattern = '"DefaultConnectionSettings"=hex:([0-9a-fA-F,\\\s]+)'

    if ($Content -match $Pattern) {
        $HexString = $Matches[1]

        # Remove line continuation characters and whitespace
        $HexString = $HexString -replace '\\\s*\r?\n\s*', '' -replace '\s', ''

        # Split by comma and convert to bytes
        $HexValues = $HexString -split ','
        $Bytes = @()

        foreach ($Hex in $HexValues) {
            if ($Hex) {
                $Bytes += [Convert]::ToByte($Hex, 16)
            }
        }

        Write-Host "Successfully extracted $($Bytes.Length) bytes" -ForegroundColor Green
        return $Bytes
    } else {
        Write-Warning "Could not find DefaultConnectionSettings in .reg file"
        return $null
    }
}

Function Display-TestResults {
    param(
        [string]$TestName,
        [hashtable]$Settings,
        [byte[]]$RawBytes
    )

    Write-Host "`nTest: $TestName" -ForegroundColor Yellow
    Write-Host "Binary Data Length: $($RawBytes.Length) bytes" -ForegroundColor Gray

    # Show first 32 bytes in hex
    $HexPreview = ($RawBytes[0..([Math]::Min(31, $RawBytes.Length-1))] | ForEach-Object { $_.ToString('X2') }) -join ' '
    Write-Host "First 32 bytes: $HexPreview" -ForegroundColor Gray

    Write-Host "`nDecoded Settings:" -ForegroundColor Cyan
    Write-Host "  Version/Counter: $($Settings.Version)" -ForegroundColor White
    Write-Host "  Flags: 0x$($Settings.Flags.ToString('X8'))" -ForegroundColor White

    if ($Settings.ContainsKey('UnknownField')) {
        Write-Host "  Unknown Field: $($Settings.UnknownField)" -ForegroundColor Magenta
        if ($Settings.ContainsKey('UnknownExtraByte')) {
            Write-Host "  Unknown Extra Byte: 0x$($Settings.UnknownExtraByte.ToString('X2'))" -ForegroundColor Magenta
        }
    }

    Write-Host "`nConnection Flags:" -ForegroundColor Cyan
    Write-Host "  Direct Connection: $($Settings.DirectConnection)" -ForegroundColor $(if ($Settings.DirectConnection) {'Green'} else {'Gray'})
    Write-Host "  Proxy Enabled: $($Settings.ProxyEnabled)" -ForegroundColor $(if ($Settings.ProxyEnabled) {'Green'} else {'Gray'})
    Write-Host "  Auto Config Enabled: $($Settings.AutoConfigEnabled)" -ForegroundColor $(if ($Settings.AutoConfigEnabled) {'Green'} else {'Gray'})
    Write-Host "  Auto Detect Enabled: $($Settings.AutoDetectEnabled)" -ForegroundColor $(if ($Settings.AutoDetectEnabled) {'Green'} else {'Gray'})

    if ($Settings.ProxyServer) {
        Write-Host "`nProxy Configuration:" -ForegroundColor Cyan
        Write-Host "  Proxy Server: $($Settings.ProxyServer)" -ForegroundColor White
    }

    if ($Settings.ProxyBypass) {
        Write-Host "  Proxy Bypass: $($Settings.ProxyBypass)" -ForegroundColor White
    }

    if ($Settings.AutoConfigURL) {
        Write-Host "`nAuto Configuration:" -ForegroundColor Cyan
        Write-Host "  Config URL: $($Settings.AutoConfigURL)" -ForegroundColor White
    }
}

Function Validate-Parsing {
    param(
        [hashtable]$Settings,
        [byte[]]$RawBytes
    )

    $Issues = @()

    # Basic validation checks
    if ($null -eq $Settings.Version) {
        $Issues += "Version field is null"
    }

    if ($null -eq $Settings.Flags) {
        $Issues += "Flags field is null"
    }

    # Check for unreasonable values
    if ($Settings.ProxyServer -and $Settings.ProxyServer.Length -gt 500) {
        $Issues += "Proxy server string seems too long ($($Settings.ProxyServer.Length) chars)"
    }

    if ($Settings.ProxyBypass -and $Settings.ProxyBypass.Length -gt 1000) {
        $Issues += "Proxy bypass string seems too long ($($Settings.ProxyBypass.Length) chars)"
    }

    if ($Settings.AutoConfigURL -and $Settings.AutoConfigURL.Length -gt 1000) {
        $Issues += "Auto config URL seems too long ($($Settings.AutoConfigURL.Length) chars)"
    }

    # Check for null characters in strings (should be trimmed)
    if ($Settings.ProxyServer -and $Settings.ProxyServer.Contains([char]0)) {
        $Issues += "Proxy server contains null characters"
    }

    if ($Settings.ProxyBypass -and $Settings.ProxyBypass.Contains([char]0)) {
        $Issues += "Proxy bypass contains null characters"
    }

    if ($Settings.AutoConfigURL -and $Settings.AutoConfigURL.Contains([char]0)) {
        $Issues += "Auto config URL contains null characters"
    }

    return $Issues
}

#endregion

#region Main Test Execution

Write-Host "DefaultConnectionSettings Decoder Test Harness" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Check if test folder exists
if (-not (Test-Path $TestFolder)) {
    Write-Error "Test folder not found: $TestFolder"
    Write-Host "`nPlease create the folder and add .reg files exported from:" -ForegroundColor Yellow
    Write-Host "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -ForegroundColor Yellow
    Write-Host "`nExport command:" -ForegroundColor Yellow
    Write-Host 'reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" test.reg' -ForegroundColor Gray
    exit 1
}

# Find all .reg files
$RegFiles = Get-ChildItem -Path $TestFolder -Filter "*.reg" -File

if ($RegFiles.Count -eq 0) {
    Write-Warning "No .reg files found in $TestFolder"
    Write-Host "`nPlease add .reg files exported from:" -ForegroundColor Yellow
    Write-Host "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nFound $($RegFiles.Count) test file(s)" -ForegroundColor Green
Write-Host ""

# Track results
$TestResults = @()
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

# Process each .reg file
foreach ($RegFile in $RegFiles) {
    $TotalTests++
    $TestName = [System.IO.Path]::GetFileNameWithoutExtension($RegFile.Name)

    try {
        # Parse the .reg file to extract binary data
        $Bytes = Parse-RegFile -FilePath $RegFile.FullName

        if ($null -eq $Bytes) {
            $FailedTests++
            $TestResults += @{
                Name = $TestName
                Status = "FAILED"
                Error = "Could not extract binary data from .reg file"
            }
            continue
        }

        # Decode the settings
        $Settings = Decode-ConnectionSettings -Data $Bytes

        # Validate the parsing
        $Issues = Validate-Parsing -Settings $Settings -RawBytes $Bytes

        # Display results
        Display-TestResults -TestName $TestName -Settings $Settings -RawBytes $Bytes

        # Check for issues
        if ($Issues.Count -gt 0) {
            Write-Host "`nValidation Issues:" -ForegroundColor Red
            foreach ($Issue in $Issues) {
                Write-Host "  ❌ $Issue" -ForegroundColor Red
            }
            $FailedTests++
            $TestResults += @{
                Name = $TestName
                Status = "FAILED"
                Error = $Issues -join "; "
            }
        } else {
            Write-Host "`n✅ Parsing successful - No validation issues" -ForegroundColor Green
            $PassedTests++
            $TestResults += @{
                Name = $TestName
                Status = "PASSED"
                Error = $null
            }
        }

    } catch {
        Write-Host "`n❌ Test failed with exception:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray

        $FailedTests++
        $TestResults += @{
            Name = $TestName
            Status = "FAILED"
            Error = $_.Exception.Message
        }
    }

    Write-Host ""
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

Write-Host "`nTotal Tests: $TotalTests" -ForegroundColor White
Write-Host "Passed: $PassedTests" -ForegroundColor Green
Write-Host "Failed: $FailedTests" -ForegroundColor $(if ($FailedTests -gt 0) {'Red'} else {'Green'})

if ($TestResults.Count -gt 0) {
    Write-Host "`nDetailed Results:" -ForegroundColor Cyan
    foreach ($Result in $TestResults) {
        $StatusColor = if ($Result.Status -eq "PASSED") {'Green'} else {'Red'}
        Write-Host "  [$($Result.Status)] $($Result.Name)" -ForegroundColor $StatusColor
        if ($Result.Error) {
            Write-Host "    Error: $($Result.Error)" -ForegroundColor Gray
        }
    }
}

# Exit with appropriate code
if ($FailedTests -gt 0) {
    exit 1
} else {
    exit 0
}

#endregion
