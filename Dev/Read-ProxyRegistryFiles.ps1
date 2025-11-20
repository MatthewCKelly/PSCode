<#
.SYNOPSIS
    Reads and displays proxy settings from all registry files in ProxySettingsKeys folder
.DESCRIPTION
    This script reads all .reg files in the ProxySettingsKeys folder, decodes the
    DefaultConnectionSettings binary data, and displays the proxy configuration
    in a clear, easy-to-compare format.
.PARAMETER FolderPath
    Path to folder containing .reg test files (default: ./ProxySettingsKeys)
.PARAMETER OutputFormat
    Format for output: Table (default), List, or Grid
.EXAMPLE
    .\Read-ProxyRegistryFiles.ps1
    Reads all registry files and displays settings in table format
.EXAMPLE
    .\Read-ProxyRegistryFiles.ps1 -OutputFormat List
    Displays settings in detailed list format
.NOTES
    Version: 1.0
    Author: Claude AI
    Created: 2025-11-20
    Requires: Read-DefaultProxySettings.ps1 (for Decode-ConnectionSettings function)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$FolderPath = "$PSScriptRoot\ProxySettingsKeys",

    [Parameter(Mandatory = $false)]
    [ValidateSet('Table', 'List', 'Grid')]
    [string]$OutputFormat = 'Table'
)

#region Helper Functions

Function Write-Detail {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $caller = (Get-PSCallStack)[1]
    $lineNumber = $caller.ScriptLineNumber

    # Format: [timestamp] Level Line# Message
    $logEntry = "[{0}] {1,-7} {2,4} {3}" -f $timestamp, $Level, $lineNumber, $Message

    # Color-coded output based on level
    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Debug'   { Write-Host $logEntry -ForegroundColor DarkGray }
        default   { Write-Host $logEntry -ForegroundColor Gray }
    }
}

Function Parse-RegFile {
    <#
    .SYNOPSIS
        Extracts binary data from a .reg file
    .DESCRIPTION
        Parses a Windows registry export file and extracts the hex-encoded
        binary data for the DefaultConnectionSettings value
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Detail "File not found: $FilePath" -Level Error
        return $null
    }

    $Content = Get-Content $FilePath -Raw -Encoding Unicode

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

        Write-Detail "Extracted $($Bytes.Length) bytes from $(Split-Path -Leaf $FilePath)" -Level Debug
        return $Bytes
    }
    else {
        Write-Detail "Could not find DefaultConnectionSettings in $(Split-Path -Leaf $FilePath)" -Level Warning
        return $null
    }
}

#endregion

#region Main Execution

Write-Detail "Proxy Registry File Reader" -Level Info
Write-Detail "=" * 80 -Level Info

# Validate folder path
if (-not (Test-Path $FolderPath)) {
    Write-Detail "Folder not found: $FolderPath" -Level Error
    exit 1
}

# Import the decoder function from Read-DefaultProxySettings.ps1
$DecoderScript = Join-Path $PSScriptRoot "Read-DefaultProxySettings.ps1"
if (-not (Test-Path $DecoderScript)) {
    Write-Detail "Cannot find decoder script: $DecoderScript" -Level Error
    Write-Detail "This script requires Read-DefaultProxySettings.ps1 in the same folder" -Level Error
    exit 1
}

# Dot-source the decoder script to import Decode-ConnectionSettings function
$null = . $DecoderScript 2>&1
Write-Detail "Loaded decoder functions from Read-DefaultProxySettings.ps1" -Level Success

# Find all .reg files
$RegFiles = Get-ChildItem -Path $FolderPath -Filter "*.reg" -File | Sort-Object Name

if ($RegFiles.Count -eq 0) {
    Write-Detail "No .reg files found in $FolderPath" -Level Warning
    exit 0
}

Write-Detail "Found $($RegFiles.Count) registry file(s)" -Level Success
Write-Detail ""

# Collection to store all decoded settings
$AllSettings = @()

# Process each file
foreach ($RegFile in $RegFiles) {
    Write-Detail "Processing: $($RegFile.Name)" -Level Info

    try {
        # Extract binary data from .reg file
        $Bytes = Parse-RegFile -FilePath $RegFile.FullName

        if ($null -eq $Bytes) {
            Write-Detail "Skipping $($RegFile.Name) - could not extract data" -Level Warning
            continue
        }

        # Decode the settings
        $Settings = Decode-ConnectionSettings -Data $Bytes

        # Create custom object for output
        $SettingObject = [PSCustomObject]@{
            File              = $RegFile.Name
            Version           = $Settings.Version
            Flags             = "0x$($Settings.Flags.ToString('X8'))"
            DirectConnection  = $Settings.DirectConnection
            ProxyEnabled      = $Settings.ProxyEnabled
            ProxyServer       = if ($Settings.ProxyServer) { $Settings.ProxyServer } else { "(none)" }
            ProxyBypass       = if ($Settings.ProxyBypass) { $Settings.ProxyBypass } else { "(none)" }
            AutoConfigEnabled = $Settings.AutoConfigEnabled
            AutoConfigURL     = if ($Settings.AutoConfigURL) { $Settings.AutoConfigURL } else { "(none)" }
            AutoDetectEnabled = $Settings.AutoDetectEnabled
            ByteSize          = $Bytes.Length
        }

        $AllSettings += $SettingObject
        Write-Detail "Successfully decoded $($RegFile.Name)" -Level Success

    }
    catch {
        Write-Detail "Error processing $($RegFile.Name): $($_.Exception.Message)" -Level Error
    }
}

Write-Detail ""
Write-Detail "=" * 80 -Level Info
Write-Detail "DECODED SETTINGS SUMMARY" -Level Info
Write-Detail "=" * 80 -Level Info
Write-Detail ""

# Display results based on output format
switch ($OutputFormat) {
    'Table' {
        # Display as formatted table
        $AllSettings | Format-Table -Property File, Version, ProxyEnabled, ProxyServer, AutoConfigEnabled, AutoDetectEnabled -AutoSize

        Write-Detail ""
        Write-Detail "DETAILED SETTINGS:" -Level Info
        Write-Detail ""

        foreach ($Setting in $AllSettings) {
            Write-Host "`n$($Setting.File):" -ForegroundColor Cyan
            Write-Host "  Version/Counter : $($Setting.Version)" -ForegroundColor White
            Write-Host "  Flags           : $($Setting.Flags)" -ForegroundColor White
            Write-Host "  Direct Connect  : $($Setting.DirectConnection)" -ForegroundColor $(if ($Setting.DirectConnection) {'Green'} else {'Gray'})
            Write-Host "  Proxy Enabled   : $($Setting.ProxyEnabled)" -ForegroundColor $(if ($Setting.ProxyEnabled) {'Green'} else {'Gray'})

            if ($Setting.ProxyServer -ne "(none)") {
                Write-Host "  Proxy Server    : $($Setting.ProxyServer)" -ForegroundColor Yellow
            }

            if ($Setting.ProxyBypass -ne "(none)") {
                Write-Host "  Proxy Bypass    : $($Setting.ProxyBypass)" -ForegroundColor Yellow
            }

            Write-Host "  Auto Config     : $($Setting.AutoConfigEnabled)" -ForegroundColor $(if ($Setting.AutoConfigEnabled) {'Green'} else {'Gray'})

            if ($Setting.AutoConfigURL -ne "(none)") {
                Write-Host "  Config URL      : $($Setting.AutoConfigURL)" -ForegroundColor Yellow
            }

            Write-Host "  Auto Detect     : $($Setting.AutoDetectEnabled)" -ForegroundColor $(if ($Setting.AutoDetectEnabled) {'Green'} else {'Gray'})
            Write-Host "  Binary Size     : $($Setting.ByteSize) bytes" -ForegroundColor Gray
        }
    }

    'List' {
        # Display as detailed list
        $AllSettings | Format-List -Property *
    }

    'Grid' {
        # Display in grid view (interactive table)
        $AllSettings | Out-GridView -Title "Proxy Settings from Registry Files" -Wait
    }
}

Write-Detail ""
Write-Detail "=" * 80 -Level Info
Write-Detail "Processing complete - $($AllSettings.Count) file(s) decoded successfully" -Level Success
Write-Detail "=" * 80 -Level Info

#endregion
