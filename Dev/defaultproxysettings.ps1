<#
.SYNOPSIS
    Decodes and modifies Windows DefaultConnectionSettings registry binary data
.DESCRIPTION
    This script reads, decodes, and optionally modifies the DefaultConnectionSettings binary
    registry value that controls Internet Explorer and Windows proxy settings. The binary
    format contains proxy configuration, automatic detection settings, and connection flags.
.PARAMETER
    No parameters are accepted - script operates interactively
.INPUTS
    No direct inputs - operates autonomously with user prompts for modifications
.OUTPUTS
    Console logging showing decoded values, progress display, and exit codes
    Registry updates when modifications are made
.EXAMPLE
    .\DefaultConnectionSettings-Tool.ps1
    Executes the script interactively to decode and optionally modify proxy settings
.NOTES
    Requires administrative privileges to modify registry values
    Compatible with PowerShell 5.x using native .NET functions
    Registry path: HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections
.VERSION
    Created by Claude AI - Sonnet 4
#>

#region Helper Functions

Function Write-Detail {
<#
    .SYNOPSIS
        Writes formatted messages to console and optionally to log file
    .DESCRIPTION
        Enhanced logging function that supports different log levels with color coding
        and optional file output with timestamps and line numbers
    .PARAMETER Message
        The message to write to the log
    .PARAMETER Level
        The logging level (Info, Warning, Error, Debug). Default is Info
    .PARAMETER LogFile
        Optional path to log file for persistent logging
    .INPUTS
        [String] Message to log
    .OUTPUTS
        Console output with timestamp and formatting
    .EXAMPLE
        Write-Detail -Message "Processing started" -Level Info
    .EXAMPLE
        Write-Detail -Message "Error occurred" -Level Error -LogFile "C:\logs\app.log"
    .NOTES
        Includes automatic line number detection and color-coded output
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        
        [string]$LogFile = $null
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $lineNumber = $MyInvocation.ScriptLineNumber
    
    # Using format strings for precise alignment
    # {0} = timestamp, {1} = level (padded to 7 chars), {2} = line number (padded to 4 chars), {3} = message
    $logEntry = "[{0}] {1,-7} {2,4} {3}" -f $timestamp, $Level, $lineNumber, $Message

    # Console output with colors
    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor White -BackgroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Black -BackgroundColor Yellow }
        'Debug'   { Write-Host $logEntry -ForegroundColor Gray }
        default   { Write-Host $logEntry }
    }
    
    # Optional file logging
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logEntry
    }
}

#endregion Helper Functions

#region Connection Settings Functions

# Helper function to safely read a 32-bit integer from byte array
Function Read-UInt32FromBytes {
    param(
        [byte[]]$Data,
        [int]$Start,
        [int]$Length = 4
    )

    # Validate we have enough bytes
    if (($Start + $Length) -gt $Data.Length) {
        Write-Detail -Message "ERROR: Cannot read UInt32 at position $Start - not enough bytes (need $Length, have $($Data.Length - $Start))" -Level Error
        return $null
    } # end of bounds check

    # Extract subset and convert
    try {
        # Extract only the bytes we need (should always be 4 for UInt32)
        $SubsetBytes = $Data[$Start..($Start + $Length - 1)]

        # Convert the subset to UInt32 (reading from position 0 of the subset)
        $Value = [System.BitConverter]::ToUInt32($SubsetBytes, 0)

        Write-Detail -Message "Read UInt32 at position $($Start): 0x$($Data[$Start].ToString('X2')) $($Data[$Start+1].ToString('X2')) $($Data[$Start+2].ToString('X2')) $($Data[$Start+3].ToString('X2')) = $Value" -Level Debug
        return $Value
    } catch {
        Write-Detail -Message "ERROR: Failed to read UInt32 at position $Start : $($_.Exception.Message)" -Level Error
        return $null
    } # end of try-catch
} # end of Read-UInt32FromBytes function

# Function to decode the binary data structure
Function Decode-ConnectionSettings {
    param([byte[]]$Data)
    
    Write-Detail -Message "Decoding DefaultConnectionSettings binary structure" -Level Info
    
    # Create hashtable to store decoded values
    $Settings = @{}
    
    try {
        # Version Signature (bytes 0x00-0x03 as little-endian DWORD)
        $Settings.VersionSignature = Read-UInt32FromBytes -Data $Data -Start 0
        if ($null -eq $Settings.VersionSignature) {
            Write-Detail -Message "Failed to read version signature" -Level Error
            return $Settings
        } # end of version signature check
        Write-Detail -Message "Version Signature: $($Settings.VersionSignature)" -Level Debug

        # Version/Counter (bytes 0x04-0x07 as little-endian DWORD)
        $Settings.Version = Read-UInt32FromBytes -Data $Data -Start 4
        if ($null -eq $Settings.Version) {
            Write-Detail -Message "Failed to read version/counter" -Level Error
            return $Settings
        } # end of version check
        Write-Detail -Message "Version/Counter: $($Settings.Version)" -Level Debug

        # Connection FLAGS (bytes 0x08-0x0B as little-endian DWORD)
        $Settings.Flags = Read-UInt32FromBytes -Data $Data -Start 8
        if ($null -eq $Settings.Flags) {
            Write-Detail -Message "Failed to read flags field" -Level Error
            return $Settings
        } # end of flags check
        Write-Detail -Message "Connection flags: 0x$($Settings.Flags.ToString('X8'))" -Level Debug

        # Decode individual flag bits
        $Settings.DirectConnection = ($Settings.Flags -band 0x01) -eq 0x01
        $Settings.ProxyEnabled = ($Settings.Flags -band 0x02) -eq 0x02
        $Settings.AutoConfigEnabled = ($Settings.Flags -band 0x04) -eq 0x04
        $Settings.AutoDetectEnabled = ($Settings.Flags -band 0x08) -eq 0x08

        Write-Detail -Message "Direct Connection: $($Settings.DirectConnection)" -Level Info
        Write-Detail -Message "Proxy Enabled: $($Settings.ProxyEnabled)" -Level Info
        Write-Detail -Message "Auto Config Enabled: $($Settings.AutoConfigEnabled)" -Level Info
        Write-Detail -Message "Auto Detect Enabled: $($Settings.AutoDetectEnabled)" -Level Info

        # Unknown/Reserved field (bytes 0x0C-0x0F)
        $Settings.UnknownField = Read-UInt32FromBytes -Data $Data -Start 12
        Write-Detail -Message "Unknown/Reserved (bytes 0x0C-0x0F): $($Settings.UnknownField)" -Level Debug

        # Read all three length fields from header (28-byte fixed header)
        # Bytes 0x10-0x13: ProxyServer Length (L1)
        # Bytes 0x14-0x17: ProxyBypass Length (L2)
        # Bytes 0x18-0x1B: AutoConfigURL Length (L3)
        # Variable data starts at 0x1C (byte 28)

        $ProxyLength = Read-UInt32FromBytes -Data $Data -Start 16
        Write-Detail -Message "ProxyServer Length (0x10): $ProxyLength bytes" -Level Debug

        $BypassLength = Read-UInt32FromBytes -Data $Data -Start 20
        Write-Detail -Message "ProxyBypass Length (0x14): $BypassLength bytes" -Level Debug

        $ConfigLength = Read-UInt32FromBytes -Data $Data -Start 24
        Write-Detail -Message "AutoConfigURL Length (0x18): $ConfigLength bytes" -Level Debug

        # Variable data starts at offset 0x1C (28 bytes)
        $Offset = 28
        Write-Detail -Message "Starting variable data parsing at offset $Offset (0x1C)" -Level Debug

        # Proxy server string (using length from header)
        if ($ProxyLength -gt 0 -and ($Offset + $ProxyLength) -le $Data.Length) {
            Write-Detail -Message "Extracting ProxyServer string at offset $Offset, length $ProxyLength" -Level Debug
            $ProxyBytes = $Data[$Offset..($Offset + $ProxyLength - 1)]
            $Settings.ProxyServer = [System.Text.Encoding]::ASCII.GetString($ProxyBytes).TrimEnd([char]0)
            Write-Detail -Message "Proxy Server: `"$($Settings.ProxyServer)`"" -Level Info
        } else {
            $Settings.ProxyServer = ""
            if ($ProxyLength -eq 0) {
                Write-Detail -Message "Proxy Server: (none - length is 0)" -Level Info
            } # end of zero length message
        } # end of proxy string extraction
        $Offset += $ProxyLength
        Write-Detail -Message "After proxy section, offset now: $Offset" -Level Debug

        # Proxy bypass string (using length from header)
        if ($BypassLength -gt 0 -and ($Offset + $BypassLength) -le $Data.Length) {
            Write-Detail -Message "Extracting ProxyBypass string at offset $Offset, length $BypassLength" -Level Debug
            $BypassBytes = $Data[$Offset..($Offset + $BypassLength - 1)]
            $Settings.ProxyBypass = [System.Text.Encoding]::ASCII.GetString($BypassBytes).TrimEnd([char]0)
            Write-Detail -Message "Proxy Bypass: $($Settings.ProxyBypass)" -Level Info
        } else {
            $Settings.ProxyBypass = ""
            if ($BypassLength -eq 0) {
                Write-Detail -Message "Proxy Bypass: (none - length is 0)" -Level Info
            } # end of zero length message
        } # end of bypass string extraction
        $Offset += $BypassLength
        Write-Detail -Message "After bypass section, offset now: $Offset" -Level Debug

        # Auto config URL string (using length from header)
        if ($ConfigLength -gt 0 -and ($Offset + $ConfigLength) -le $Data.Length) {
            Write-Detail -Message "Extracting AutoConfigURL string at offset $Offset, length $ConfigLength" -Level Debug
            $ConfigBytes = $Data[$Offset..($Offset + $ConfigLength - 1)]
            $Settings.AutoConfigURL = [System.Text.Encoding]::ASCII.GetString($ConfigBytes).TrimEnd([char]0)
            Write-Detail -Message "Auto Config URL: $($Settings.AutoConfigURL)" -Level Info
        } else {
            $Settings.AutoConfigURL = ""
            if ($ConfigLength -eq 0) {
                Write-Detail -Message "Auto Config URL: (none - length is 0)" -Level Info
            } # end of zero length message
        } # end of config URL extraction
        $Offset += $ConfigLength
        Write-Detail -Message "After AutoConfig section, offset now: $Offset" -Level Debug
        
        return $Settings
        
    } catch {
        Write-Detail -Message "Error decoding binary data: $($_.Exception.Message)" -Level Error
        throw
    } # end of decode try-catch
} # end of Decode-ConnectionSettings function

# Function to encode settings back to binary format
Function Encode-ConnectionSettings {
    param([hashtable]$Settings)
    
    Write-Detail -Message "Encoding settings back to binary format" -Level Info
    
    try {
        # Prepare string data first to calculate lengths
        $ProxyStringBytes = @()
        if ($Settings.ProxyEnabled -and $Settings.ProxyServer) {
            $ProxyStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.ProxyServer + [char]0)
        }
        $ProxyLength = $ProxyStringBytes.Length

        $BypassStringBytes = @()
        if ($Settings.ProxyEnabled -and $Settings.ProxyBypass) {
            $BypassStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.ProxyBypass + [char]0)
        }
        $BypassLength = $BypassStringBytes.Length

        $ConfigStringBytes = @()
        if ($Settings.AutoConfigEnabled -and $Settings.AutoConfigURL) {
            $ConfigStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.AutoConfigURL + [char]0)
        }
        $ConfigLength = $ConfigStringBytes.Length

        Write-Detail -Message "String lengths - Proxy: $ProxyLength, Bypass: $BypassLength, AutoConfig: $ConfigLength" -Level Debug

        # Build 28-byte fixed header
        $ResultBytes = @()

        # 0x00-0x03: Version Signature (use existing or default to 70)
        $VersionSig = if ($Settings.ContainsKey('VersionSignature')) { $Settings.VersionSignature } else { 70 }
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$VersionSig)
        Write-Detail -Message "Added Version Signature at 0x00: $VersionSig" -Level Debug

        # 0x04-0x07: Version/Counter
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$Settings.Version)
        Write-Detail -Message "Added Version/Counter at 0x04: $($Settings.Version)" -Level Debug

        # 0x08-0x0B: FLAGS
        $FlagsValue = 0
        if ($Settings.DirectConnection) { $FlagsValue = $FlagsValue -bor 0x01 }
        if ($Settings.ProxyEnabled) { $FlagsValue = $FlagsValue -bor 0x02 }
        if ($Settings.AutoConfigEnabled) { $FlagsValue = $FlagsValue -bor 0x04 }
        if ($Settings.AutoDetectEnabled) { $FlagsValue = $FlagsValue -bor 0x08 }
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$FlagsValue)
        Write-Detail -Message "Added FLAGS at 0x08: 0x$($FlagsValue.ToString('X8'))" -Level Debug

        # 0x0C-0x0F: Unknown/Reserved (default to 0)
        $UnknownValue = if ($Settings.ContainsKey('UnknownField')) { $Settings.UnknownField } else { 0 }
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$UnknownValue)
        Write-Detail -Message "Added Unknown/Reserved at 0x0C: $UnknownValue" -Level Debug

        # 0x10-0x13: ProxyServer Length
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$ProxyLength)
        Write-Detail -Message "Added ProxyServer Length at 0x10: $ProxyLength" -Level Debug

        # 0x14-0x17: ProxyBypass Length
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$BypassLength)
        Write-Detail -Message "Added ProxyBypass Length at 0x14: $BypassLength" -Level Debug

        # 0x18-0x1B: AutoConfigURL Length
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$ConfigLength)
        Write-Detail -Message "Added AutoConfigURL Length at 0x18: $ConfigLength" -Level Debug

        # Header should now be 28 bytes (0x1C)
        Write-Detail -Message "Header size: $($ResultBytes.Length) bytes (should be 28)" -Level Debug

        # 0x1C+: Variable data
        if ($ProxyLength -gt 0) {
            $ResultBytes += $ProxyStringBytes
            Write-Detail -Message "Added ProxyServer string data: $ProxyLength bytes" -Level Debug
        }

        if ($BypassLength -gt 0) {
            $ResultBytes += $BypassStringBytes
            Write-Detail -Message "Added ProxyBypass string data: $BypassLength bytes" -Level Debug
        }

        if ($ConfigLength -gt 0) {
            $ResultBytes += $ConfigStringBytes
            Write-Detail -Message "Added AutoConfigURL string data: $ConfigLength bytes" -Level Debug
        }

        # Add padding to reach minimum size (typically padded to specific boundaries)
        # Most samples have 32 bytes of 0x00 padding at the end
        $PaddingSize = 32
        $Padding = New-Object byte[] $PaddingSize
        $ResultBytes += $Padding
        Write-Detail -Message "Added $PaddingSize bytes of padding" -Level Debug

        Write-Detail -Message "Successfully encoded $($ResultBytes.Length) bytes total" -Level Info
        return $ResultBytes
        
    } catch {
        Write-Detail -Message "Error encoding settings: $($_.Exception.Message)" -Level Error
        throw
    } # end of encode try-catch
} # end of Encode-ConnectionSettings function

#endregion Connection Settings Functions

#region Main Execution

# Registry path constant
$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
$ValueName = "DefaultConnectionSettings"

Write-Detail -Message "Starting DefaultConnectionSettings decoder/updater tool" -Level Info

try {
    # Read the binary registry value
    Write-Detail -Message "Reading registry value from $RegistryPath" -Level Info
    $BinaryData = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop
    $Bytes = $BinaryData.$ValueName
    
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
        Write-Detail -Message "Registry value is empty or null" -Level Error
        exit 1
    } # end of null check
    
    Write-Detail -Message "Successfully read $($Bytes.Length) bytes from registry" -Level Info
    
    # Display raw binary data for analysis
    Write-Detail -Message "========================================" -Level Info
    Write-Detail -Message "RAW BINARY DATA ANALYSIS" -Level Info
    Write-Detail -Message "========================================" -Level Info
    Write-Detail -Message "Total bytes: $($Bytes.Length)" -Level Info
    
    # Show hex dump in 16-byte rows with offset, hex, and ASCII
    for ($i = 0; $i -lt $Bytes.Length; $i += 16) {
        $HexRow = ""
        $AsciiRow = ""
        $EndIndex = [Math]::Min($i + 15, $Bytes.Length - 1)
        
        # Build hex representation
        for ($j = $i; $j -le $EndIndex; $j++) {
            $HexRow += $Bytes[$j].ToString("X2") + " "
            # Build ASCII representation (printable chars only)
            if ($Bytes[$j] -ge 32 -and $Bytes[$j] -le 126) {
                $AsciiRow += [char]$Bytes[$j]
            } else {
                $AsciiRow += "."
            } # end of ASCII conversion
        } # end of byte loop
        
        # Pad hex row to consistent width (48 chars for 16 bytes)
        $HexRow = $HexRow.PadRight(48)
        
        Write-Detail -Message "$($i.ToString('X4')): $HexRow | $AsciiRow" -Level Info
    } # end of hex dump loop
    
    Write-Detail -Message "STRUCTURE BREAKDOWN:" -Level Info
    Write-Detail -Message "Bytes 0-3   (Ver Sig):      $($Bytes[0].ToString('X2')) $($Bytes[1].ToString('X2')) $($Bytes[2].ToString('X2')) $($Bytes[3].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 0)))" -Level Info
    Write-Detail -Message "Bytes 4-7   (Ver/Cnt):      $($Bytes[4].ToString('X2')) $($Bytes[5].ToString('X2')) $($Bytes[6].ToString('X2')) $($Bytes[7].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 4)))" -Level Info
    Write-Detail -Message "Bytes 8-11  (FLAGS):        $($Bytes[8].ToString('X2')) $($Bytes[9].ToString('X2')) $($Bytes[10].ToString('X2')) $($Bytes[11].ToString('X2')) = 0x$(([System.BitConverter]::ToUInt32($Bytes, 8)).ToString('X8'))" -Level Info
    Write-Detail -Message "Bytes 12-15 (Unknown):      $($Bytes[12].ToString('X2')) $($Bytes[13].ToString('X2')) $($Bytes[14].ToString('X2')) $($Bytes[15].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 12)))" -Level Info
    Write-Detail -Message "Bytes 16-19 (Proxy Len):    $($Bytes[16].ToString('X2')) $($Bytes[17].ToString('X2')) $($Bytes[18].ToString('X2')) $($Bytes[19].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 16)))" -Level Info
    Write-Detail -Message "Bytes 20-23 (Bypass Len):   $($Bytes[20].ToString('X2')) $($Bytes[21].ToString('X2')) $($Bytes[22].ToString('X2')) $($Bytes[23].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 20)))" -Level Info
    if ($Bytes.Length -gt 27) {
        Write-Detail -Message "Bytes 24-27 (AutoCfg Len):  $($Bytes[24].ToString('X2')) $($Bytes[25].ToString('X2')) $($Bytes[26].ToString('X2')) $($Bytes[27].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 24)))" -Level Info
    }
    Write-Host ""

    # Structure documentation
    Write-Detail -Message "STRUCTURE (28-byte header + variable data):" -Level Info
    Write-Detail -Message "  FIXED HEADER (28 bytes = 0x1C):" -Level Info
    Write-Detail -Message "    Bytes 0x00-0x03:  Version Signature (DWORD)" -Level Info
    Write-Detail -Message "    Bytes 0x04-0x07:  Version/Counter (DWORD)" -Level Info
    Write-Detail -Message "    Bytes 0x08-0x0B:  Connection Flags (DWORD)" -Level Info
    Write-Detail -Message "    Bytes 0x0C-0x0F:  Unknown/Reserved (DWORD)" -Level Info
    Write-Detail -Message "    Bytes 0x10-0x13:  ProxyServer Length L1 (DWORD)" -Level Info
    Write-Detail -Message "    Bytes 0x14-0x17:  ProxyBypass Length L2 (DWORD)" -Level Info
    Write-Detail -Message "    Bytes 0x18-0x1B:  AutoConfigURL Length L3 (DWORD)" -Level Info
    Write-Detail -Message "  VARIABLE DATA (starts at 0x1C):" -Level Info
    Write-Detail -Message "    Bytes 0x1C+:      ProxyServer string (L1 bytes)" -Level Info
    Write-Detail -Message "    Bytes 0x1C+L1:    ProxyBypass string (L2 bytes)" -Level Info
    Write-Detail -Message "    Bytes 0x1C+L1+L2: AutoConfigURL string (L3 bytes)" -Level Info
    Write-Detail -Message "    Remaining bytes:  Padding (typically 0x00)" -Level Info
    Write-Detail -Message "========================================" -Level Info
    
} catch {
    Write-Detail -Message "Failed to read registry value: $($_.Exception.Message)" -Level Error
    exit 1
} # end of registry read try-catch

# Decode the current settings
Write-Detail -Message "Decoding current connection settings" -Level Info
$CurrentSettings = Decode-ConnectionSettings -Data $Bytes

Write-Detail -Message "Current settings decoded successfully" -Level Info
Write-Detail -Message "========================================" -Level Info

# Display current configuration summary
Write-Detail -Message "CURRENT CONFIGURATION SUMMARY:" -Level Info
Write-Detail -Message "Version Signature: $($CurrentSettings.VersionSignature)" -Level Info
Write-Detail -Message "Version/Counter: $($CurrentSettings.Version)" -Level Info
if ($CurrentSettings.ContainsKey('UnknownField')) {
    Write-Detail -Message "Unknown/Reserved (bytes 0x0C-0x0F): $($CurrentSettings.UnknownField)" -Level Debug
}
Write-Detail -Message "Direct Connection: $($CurrentSettings.DirectConnection)" -Level Info
Write-Detail -Message "Proxy Enabled: $($CurrentSettings.ProxyEnabled)" -Level Info
if ($CurrentSettings.ProxyServer) {
    Write-Detail -Message "Proxy Server: $($CurrentSettings.ProxyServer)" -Level Info
} # end of proxy server display
if ($CurrentSettings.ProxyBypass) {
    Write-Detail -Message "Proxy Bypass: $($CurrentSettings.ProxyBypass)" -Level Info
} # end of proxy bypass display
Write-Detail -Message "Auto Config Enabled: $($CurrentSettings.AutoConfigEnabled)" -Level Info
if ($CurrentSettings.AutoConfigURL) {
    Write-Detail -Message "Auto Config URL: $($CurrentSettings.AutoConfigURL)" -Level Info
} # end of auto config URL display
Write-Detail -Message "Auto Detect Enabled: $($CurrentSettings.AutoDetectEnabled)" -Level Info
Write-Detail -Message "========================================" -Level Info

# Ask user if they want to make modifications
$ModifyChoice = Read-Host "Do you want to modify these settings? (y/n)"

if ($ModifyChoice -eq 'y' -or $ModifyChoice -eq 'Y') {
    Write-Detail -Message "Starting interactive modification process" -Level Info
    
    # Create a copy of current settings for modification
    $NewSettings = $CurrentSettings.Clone()
    
    # Increment version counter
    $NewSettings.Version = $NewSettings.Version + 1
    Write-Detail -Message "Incremented version counter to $($NewSettings.Version)" -Level Info
    
    # Proxy server configuration
    $ProxyChoice = Read-Host "Enable proxy server? (y/n) [Current: $($NewSettings.ProxyEnabled)]"
    if ($ProxyChoice -eq 'y' -or $ProxyChoice -eq 'Y') {
        $NewSettings.ProxyEnabled = $true
        $NewSettings.DirectConnection = $false
        
        $ProxyServer = Read-Host "Enter proxy server (host:port) [Current: $($NewSettings.ProxyServer)]"
        if (-not [string]::IsNullOrEmpty($ProxyServer)) {
            $NewSettings.ProxyServer = $ProxyServer
        } # end of proxy server input
        
        $ProxyBypass = Read-Host "Enter proxy bypass list (semicolon separated) [Current: $($NewSettings.ProxyBypass)]"
        if (-not [string]::IsNullOrEmpty($ProxyBypass)) {
            $NewSettings.ProxyBypass = $ProxyBypass
        } # end of proxy bypass input
        
    } else {
        $NewSettings.ProxyEnabled = $false
        $NewSettings.ProxyServer = ""
        $NewSettings.ProxyBypass = ""
        Write-Detail -Message "Proxy server disabled" -Level Info
    } # end of proxy configuration
    
    # Auto configuration settings
    $AutoConfigChoice = Read-Host "Enable automatic configuration script? (y/n) [Current: $($NewSettings.AutoConfigEnabled)]"
    if ($AutoConfigChoice -eq 'y' -or $AutoConfigChoice -eq 'Y') {
        $NewSettings.AutoConfigEnabled = $true
        
        $ConfigURL = Read-Host "Enter auto config script URL [Current: $($NewSettings.AutoConfigURL)]"
        if (-not [string]::IsNullOrEmpty($ConfigURL)) {
            $NewSettings.AutoConfigURL = $ConfigURL
        } # end of config URL input
        
    } else {
        $NewSettings.AutoConfigEnabled = $false
        $NewSettings.AutoConfigURL = ""
        Write-Detail -Message "Automatic configuration disabled" -Level Info
    } # end of auto config configuration
    
    # Auto detect settings
    $AutoDetectChoice = Read-Host "Enable automatic proxy detection? (y/n) [Current: $($NewSettings.AutoDetectEnabled)]"
    if ($AutoDetectChoice -eq 'y' -or $AutoDetectChoice -eq 'Y') {
        $NewSettings.AutoDetectEnabled = $true
    } else {
        $NewSettings.AutoDetectEnabled = $false
    } # end of auto detect configuration
    
    # Set direct connection if no other options enabled
    if (-not $NewSettings.ProxyEnabled -and -not $NewSettings.AutoConfigEnabled -and -not $NewSettings.AutoDetectEnabled) {
        $NewSettings.DirectConnection = $true
        Write-Detail -Message "Enabled direct connection (no proxy/auto config/auto detect)" -Level Info
    } # end of direct connection logic
    
    Write-Detail -Message "Encoding new settings to binary format" -Level Info
    
    try {
        # Encode the new settings
        $NewBinaryData = Encode-ConnectionSettings -Settings $NewSettings
        
        Write-Detail -Message "Creating registry backup" -Level Info
        $BackupFile = "DefaultConnectionSettings_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
        $ExportCommand = "reg export `"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`" `"$BackupFile`""
        Invoke-Expression $ExportCommand
        Write-Detail -Message "Registry backup created: $BackupFile" -Level Info
        
        # Write the new binary data to registry
        Write-Detail -Message "Writing new settings to registry" -Level Info
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value $NewBinaryData -Type Binary
        
        Write-Detail -Message "Registry updated successfully" -Level Info
        Write-Detail -Message "Changes will take effect after restarting Internet Explorer or rebooting" -Level Warning
        
    } catch {
        Write-Detail -Message "Failed to update registry: $($_.Exception.Message)" -Level Error
        exit 1
    } # end of registry update try-catch
    
} else {
    Write-Detail -Message "No modifications requested - script complete" -Level Info
} # end of modification choice

Write-Detail -Message "DefaultConnectionSettings tool completed successfully" -Level Info
exit 0

#endregion Main Execution
