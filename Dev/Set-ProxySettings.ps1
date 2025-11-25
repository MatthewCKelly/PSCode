<#
.SYNOPSIS
    Sets Windows DefaultConnectionSettings registry proxy configuration
.DESCRIPTION
    This script updates the DefaultConnectionSettings binary registry value
    that controls Internet Explorer and Windows proxy settings. It includes
    automatic validation to ensure consistency (e.g., clearing URLs when features are disabled).
.PARAMETER DirectConnection
    Enable direct connection (no proxy)
.PARAMETER ProxyEnabled
    Enable manual proxy server configuration
.PARAMETER ProxyServer
    Proxy server address and port (e.g., "proxy.example.com:8080")
.PARAMETER ProxyBypass
    Semicolon-separated list of addresses to bypass proxy (e.g., "localhost;*.local")
.PARAMETER AutoConfigEnabled
    Enable automatic configuration script (PAC file)
.PARAMETER AutoConfigURL
    URL to the PAC file (e.g., "http://proxy.example.com/proxy.pac")
.PARAMETER AutoDetectEnabled
    Enable automatic proxy detection (WPAD)
.PARAMETER WhatIf
    Show what would be changed without making actual changes
.EXAMPLE
    .\Set-ProxySettings.ps1 -ProxyEnabled -ProxyServer "proxy.corp.com:8080" -ProxyBypass "localhost;*.corp.com"
    Enables manual proxy with bypass list
.EXAMPLE
    .\Set-ProxySettings.ps1 -AutoConfigEnabled -AutoConfigURL "http://proxy.corp.com/proxy.pac"
    Enables automatic configuration with PAC file
.EXAMPLE
    .\Set-ProxySettings.ps1 -DirectConnection
    Disables all proxy settings, enables direct connection only
.NOTES
    Requires administrative privileges for registry write operations
    Creates automatic backup before making changes
    Version: 1.0
    Created: 2025-11-20
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DirectConnection,

    [Parameter(Mandatory = $false)]
    [switch]$ProxyEnabled,

    [Parameter(Mandatory = $false)]
    [string]$ProxyServer = "",

    [Parameter(Mandatory = $false)]
    [string]$ProxyBypass = "",

    [Parameter(Mandatory = $false)]
    [switch]$AutoConfigEnabled,

    [Parameter(Mandatory = $false)]
    [string]$AutoConfigURL = "",

    [Parameter(Mandatory = $false)]
    [switch]$AutoDetectEnabled
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

Function Read-UInt32FromBytes {
    param(
        [byte[]]$Data,
        [int]$Start,
        [int]$Length = 4
    )

    if (($Start + $Length) -gt $Data.Length) {
        Write-Detail "ERROR: Cannot read UInt32 at position $Start - not enough bytes" -Level Error
        return $null
    }

    try {
        $SubsetBytes = $Data[$Start..($Start + $Length - 1)]
        $Value = [System.BitConverter]::ToUInt32($SubsetBytes, 0)
        return $Value
    }
    catch {
        Write-Detail "ERROR: Failed to read UInt32 at position $Start : $($_.Exception.Message)" -Level Error
        return $null
    }
}

Function Decode-ConnectionSettings {
    param([byte[]]$Data)

    $Settings = @{}

    try {
        $Settings.Version = Read-UInt32FromBytes -Data $Data -Start 0
        $Settings.Flags = Read-UInt32FromBytes -Data $Data -Start 4
        $Settings.UnknownField = Read-UInt32FromBytes -Data $Data -Start 8

        # Decode flags
        $Settings.DirectConnection = ($Settings.Flags -band 0x01) -eq 0x01
        $Settings.ProxyEnabled = ($Settings.Flags -band 0x02) -eq 0x02
        $Settings.AutoConfigEnabled = ($Settings.Flags -band 0x04) -eq 0x04
        $Settings.AutoDetectEnabled = ($Settings.Flags -band 0x08) -eq 0x08

        # Parse variable-length sections starting at offset 12
        $Offset = 12

        # Proxy server
        $ProxyLength = Read-UInt32FromBytes -Data $Data -Start $Offset
        $Offset += 4
        if ($ProxyLength -gt 0 -and ($Offset + $ProxyLength) -le $Data.Length) {
            $ProxyBytes = $Data[$Offset..($Offset + $ProxyLength - 1)]
            $Settings.ProxyServer = [System.Text.Encoding]::ASCII.GetString($ProxyBytes).TrimEnd([char]0)
        } else {
            $Settings.ProxyServer = ""
        }
        $Offset += $ProxyLength

        # Proxy bypass
        $BypassLength = Read-UInt32FromBytes -Data $Data -Start $Offset
        $Offset += 4
        if ($BypassLength -gt 0 -and ($Offset + $BypassLength) -le $Data.Length) {
            $BypassBytes = $Data[$Offset..($Offset + $BypassLength - 1)]
            $Settings.ProxyBypass = [System.Text.Encoding]::ASCII.GetString($BypassBytes).TrimEnd([char]0)
        } else {
            $Settings.ProxyBypass = ""
        }
        $Offset += $BypassLength

        # Auto config URL
        $ConfigLength = Read-UInt32FromBytes -Data $Data -Start $Offset
        $Offset += 4
        if ($ConfigLength -gt 0 -and ($Offset + $ConfigLength) -le $Data.Length) {
            $ConfigBytes = $Data[$Offset..($Offset + $ConfigLength - 1)]
            $Settings.AutoConfigURL = [System.Text.Encoding]::ASCII.GetString($ConfigBytes).TrimEnd([char]0)
        } else {
            $Settings.AutoConfigURL = ""
        }

        return $Settings
    }
    catch {
        Write-Detail "Error decoding binary data: $($_.Exception.Message)" -Level Error
        throw
    }
}

Function Encode-ConnectionSettings {
    param([hashtable]$Settings)

    try {
        $BinaryData = @()

        # Version (increment from current)
        $VersionBytes = [System.BitConverter]::GetBytes([uint32]$Settings.Version)
        $BinaryData += $VersionBytes

        # Flags
        $FlagsValue = 0
        if ($Settings.DirectConnection)   { $FlagsValue = $FlagsValue -bor 0x01 }
        if ($Settings.ProxyEnabled)       { $FlagsValue = $FlagsValue -bor 0x02 }
        if ($Settings.AutoConfigEnabled)  { $FlagsValue = $FlagsValue -bor 0x04 }
        if ($Settings.AutoDetectEnabled)  { $FlagsValue = $FlagsValue -bor 0x08 }
        $FlagsBytes = [System.BitConverter]::GetBytes([uint32]$FlagsValue)
        $BinaryData += $FlagsBytes

        # Unknown field (preserve from original)
        $UnknownBytes = [System.BitConverter]::GetBytes([uint32]$Settings.UnknownField)
        $BinaryData += $UnknownBytes

        # Proxy server section
        if ($Settings.ProxyEnabled -and -not [string]::IsNullOrEmpty($Settings.ProxyServer)) {
            $ProxyStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.ProxyServer + [char]0)
            $ProxyLengthBytes = [System.BitConverter]::GetBytes([uint32]$ProxyStringBytes.Length)
            $BinaryData += $ProxyLengthBytes
            $BinaryData += $ProxyStringBytes
        } else {
            $BinaryData += [System.BitConverter]::GetBytes([uint32]0)
        }

        # Proxy bypass section
        if ($Settings.ProxyEnabled -and -not [string]::IsNullOrEmpty($Settings.ProxyBypass)) {
            $BypassStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.ProxyBypass + [char]0)
            $BypassLengthBytes = [System.BitConverter]::GetBytes([uint32]$BypassStringBytes.Length)
            $BinaryData += $BypassLengthBytes
            $BinaryData += $BypassStringBytes
        } else {
            $BinaryData += [System.BitConverter]::GetBytes([uint32]0)
        }

        # Auto config URL section
        if ($Settings.AutoConfigEnabled -and -not [string]::IsNullOrEmpty($Settings.AutoConfigURL)) {
            $ConfigStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.AutoConfigURL + [char]0)
            $ConfigLengthBytes = [System.BitConverter]::GetBytes([uint32]$ConfigStringBytes.Length)
            $BinaryData += $ConfigLengthBytes
            $BinaryData += $ConfigStringBytes
        } else {
            $BinaryData += [System.BitConverter]::GetBytes([uint32]0)
        }

        # Add 32 bytes of padding
        $BinaryData += ,0x00 * 32

        return [byte[]]$BinaryData
    }
    catch {
        Write-Detail "Error encoding settings: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Main Execution

Write-Detail "Windows Proxy Settings Updater" -Level Info
Write-Detail ("=" * 80) -Level Info

# Registry path
$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
$ValueName = "DefaultConnectionSettings"

# Read current settings
Write-Detail "Reading current proxy settings..." -Level Info

try {
    $CurrentData = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop
    $CurrentBytes = $CurrentData.$ValueName
    $CurrentSettings = Decode-ConnectionSettings -Data $CurrentBytes
    Write-Detail "Current settings loaded successfully" -Level Success
}
catch {
    Write-Detail "Failed to read current settings: $($_.Exception.Message)" -Level Error
    exit 1
}

Write-Host ""
Write-Detail "CURRENT SETTINGS:" -Level Info
Write-Detail "  Version/Counter : $($CurrentSettings.Version)" -Level Info
Write-Detail "  Direct Connect  : $($CurrentSettings.DirectConnection)" -Level Info
Write-Detail "  Proxy Enabled   : $($CurrentSettings.ProxyEnabled)" -Level Info
if ($CurrentSettings.ProxyServer) {
    Write-Detail "  Proxy Server    : $($CurrentSettings.ProxyServer)" -Level Info
}
if ($CurrentSettings.ProxyBypass) {
    Write-Detail "  Proxy Bypass    : $($CurrentSettings.ProxyBypass)" -Level Info
}
Write-Detail "  Auto Config     : $($CurrentSettings.AutoConfigEnabled)" -Level Info
if ($CurrentSettings.AutoConfigURL) {
    Write-Detail "  Config URL      : $($CurrentSettings.AutoConfigURL)" -Level Info
}
Write-Detail "  Auto Detect     : $($CurrentSettings.AutoDetectEnabled)" -Level Info

# Build new settings
$NewSettings = @{
    Version = $CurrentSettings.Version + 1  # Increment version
    UnknownField = $CurrentSettings.UnknownField
    DirectConnection = $DirectConnection.IsPresent
    ProxyEnabled = $ProxyEnabled.IsPresent
    ProxyServer = $ProxyServer
    ProxyBypass = $ProxyBypass
    AutoConfigEnabled = $AutoConfigEnabled.IsPresent
    AutoConfigURL = $AutoConfigURL
    AutoDetectEnabled = $AutoDetectEnabled.IsPresent
}

# If no parameters specified, keep current settings
if (-not ($PSBoundParameters.ContainsKey('DirectConnection') -or
          $PSBoundParameters.ContainsKey('ProxyEnabled') -or
          $PSBoundParameters.ContainsKey('AutoConfigEnabled') -or
          $PSBoundParameters.ContainsKey('AutoDetectEnabled'))) {
    Write-Detail "No flags specified - preserving current flag settings" -Level Warning
    $NewSettings.DirectConnection = $CurrentSettings.DirectConnection
    $NewSettings.ProxyEnabled = $CurrentSettings.ProxyEnabled
    $NewSettings.AutoConfigEnabled = $CurrentSettings.AutoConfigEnabled
    $NewSettings.AutoDetectEnabled = $CurrentSettings.AutoDetectEnabled
}

# Validation Rule 1: If ProxyEnabled is False, clear proxy server and bypass
if (-not $NewSettings.ProxyEnabled) {
    if ($NewSettings.ProxyServer -or $NewSettings.ProxyBypass) {
        Write-Detail "Proxy disabled - clearing proxy server and bypass list" -Level Warning
    }
    $NewSettings.ProxyServer = ""
    $NewSettings.ProxyBypass = ""
}

# Validation Rule 2: If AutoConfigEnabled is False, clear auto config URL
if (-not $NewSettings.AutoConfigEnabled) {
    if ($NewSettings.AutoConfigURL) {
        Write-Detail "Auto config disabled - clearing auto config URL" -Level Warning
    }
    $NewSettings.AutoConfigURL = ""
}

# Validation Rule 3: If ProxyEnabled but no server specified, keep current
if ($NewSettings.ProxyEnabled -and [string]::IsNullOrEmpty($NewSettings.ProxyServer)) {
    if (-not [string]::IsNullOrEmpty($CurrentSettings.ProxyServer)) {
        Write-Detail "Proxy enabled without server - keeping current server" -Level Info
        $NewSettings.ProxyServer = $CurrentSettings.ProxyServer
    }
}

# Validation Rule 4: If no bypass specified but proxy enabled, keep current
if ($NewSettings.ProxyEnabled -and [string]::IsNullOrEmpty($NewSettings.ProxyBypass)) {
    if (-not [string]::IsNullOrEmpty($CurrentSettings.ProxyBypass)) {
        Write-Detail "No bypass list specified - keeping current bypass list" -Level Info
        $NewSettings.ProxyBypass = $CurrentSettings.ProxyBypass
    }
}

# Validation Rule 5: If AutoConfigEnabled but no URL specified, keep current
if ($NewSettings.AutoConfigEnabled -and [string]::IsNullOrEmpty($NewSettings.AutoConfigURL)) {
    if (-not [string]::IsNullOrEmpty($CurrentSettings.AutoConfigURL)) {
        Write-Detail "Auto config enabled without URL - keeping current URL" -Level Info
        $NewSettings.AutoConfigURL = $CurrentSettings.AutoConfigURL
    }
}

Write-Host ""
Write-Detail "NEW SETTINGS:" -Level Info
Write-Detail "  Version/Counter : $($NewSettings.Version)" -Level Info
Write-Detail "  Direct Connect  : $($NewSettings.DirectConnection)" -Level Info
Write-Detail "  Proxy Enabled   : $($NewSettings.ProxyEnabled)" -Level Info
if ($NewSettings.ProxyServer) {
    Write-Detail "  Proxy Server    : $($NewSettings.ProxyServer)" -Level Info
}
if ($NewSettings.ProxyBypass) {
    Write-Detail "  Proxy Bypass    : $($NewSettings.ProxyBypass)" -Level Info
}
Write-Detail "  Auto Config     : $($NewSettings.AutoConfigEnabled)" -Level Info
if ($NewSettings.AutoConfigURL) {
    Write-Detail "  Config URL      : $($NewSettings.AutoConfigURL)" -Level Info
}
Write-Detail "  Auto Detect     : $($NewSettings.AutoDetectEnabled)" -Level Info

# Encode new settings
Write-Host ""
Write-Detail "Encoding new settings..." -Level Info

try {
    $NewBytes = Encode-ConnectionSettings -Settings $NewSettings
    Write-Detail "Settings encoded successfully ($($NewBytes.Length) bytes)" -Level Success
}
catch {
    Write-Detail "Failed to encode settings: $($_.Exception.Message)" -Level Error
    exit 1
}

# Create backup before writing
if ($PSCmdlet.ShouldProcess($RegistryPath, "Update proxy settings")) {
    Write-Host ""
    Write-Detail "Creating registry backup..." -Level Info

    $BackupFile = "DefaultConnectionSettings_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
    $ExportCommand = "reg export `"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`" `"$BackupFile`" /y"

    try {
        $null = Invoke-Expression $ExportCommand 2>&1
        Write-Detail "Backup created: $BackupFile" -Level Success
    }
    catch {
        Write-Detail "Warning: Could not create backup: $($_.Exception.Message)" -Level Warning
    }

    # Write new settings to registry
    Write-Detail "Writing new settings to registry..." -Level Info

    try {
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value $NewBytes -Type Binary -ErrorAction Stop
        Write-Detail "Registry updated successfully!" -Level Success
    }
    catch {
        Write-Detail "Failed to write to registry: $($_.Exception.Message)" -Level Error
        exit 1
    }

    # Verify the write
    Write-Host ""
    Write-Detail "Verifying changes..." -Level Info

    try {
        $VerifyData = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop
        $VerifyBytes = $VerifyData.$ValueName
        $VerifySettings = Decode-ConnectionSettings -Data $VerifyBytes

        Write-Host ""
        Write-Detail "VERIFIED SETTINGS:" -Level Success
        Write-Detail "  Version/Counter : $($VerifySettings.Version)" -Level Info
        Write-Detail "  Direct Connect  : $($VerifySettings.DirectConnection)" -Level Info
        Write-Detail "  Proxy Enabled   : $($VerifySettings.ProxyEnabled)" -Level Info
        if ($VerifySettings.ProxyServer) {
            Write-Detail "  Proxy Server    : $($VerifySettings.ProxyServer)" -Level Info
        }
        if ($VerifySettings.ProxyBypass) {
            Write-Detail "  Proxy Bypass    : $($VerifySettings.ProxyBypass)" -Level Info
        }
        Write-Detail "  Auto Config     : $($VerifySettings.AutoConfigEnabled)" -Level Info
        if ($VerifySettings.AutoConfigURL) {
            Write-Detail "  Config URL      : $($VerifySettings.AutoConfigURL)" -Level Info
        }
        Write-Detail "  Auto Detect     : $($VerifySettings.AutoDetectEnabled)" -Level Info
    }
    catch {
        Write-Detail "Warning: Could not verify changes: $($_.Exception.Message)" -Level Warning
    }
}
else {
    Write-Host ""
    Write-Detail "WhatIf: Would update registry with new settings" -Level Info
}

Write-Host ""
Write-Detail ("=" * 80) -Level Info
Write-Detail "Proxy settings update completed" -Level Success
Write-Detail ("=" * 80) -Level Info

exit 0

#endregion
