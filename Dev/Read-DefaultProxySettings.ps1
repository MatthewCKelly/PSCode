<#
.SYNOPSIS
    Reads and decodes Windows DefaultConnectionSettings registry binary data
.DESCRIPTION
    This script reads and decodes the DefaultConnectionSettings binary registry value
    that controls Internet Explorer and Windows proxy settings. The binary format
    contains proxy configuration, automatic detection settings, and connection flags.

    This is a READ-ONLY tool - it does not modify registry values.
.PARAMETER
    No parameters are accepted - script operates autonomously
.INPUTS
    No direct inputs - reads from registry automatically
.OUTPUTS
    Console logging showing decoded values, hex dump, and configuration summary
.EXAMPLE
    .\Read-DefaultProxySettings.ps1
    Reads and displays current proxy settings from the registry
.NOTES
    No administrative privileges required (read-only operation)
    Compatible with PowerShell 5.x using native .NET functions
    Registry path: HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections
.VERSION
    Created by Claude AI - Sonnet 4
    Read-only version of defaultproxysettings.ps1
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
        The logging level (Info, Warning, Error, Debug, Success). Default is Info
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

        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
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
        'Success' { Write-Host $logEntry -ForegroundColor Green }
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

        Write-Detail -Message "Read UInt32 at position ${Start}: 0x$($Data[$Start].ToString('X2')) $($Data[$Start+1].ToString('X2')) $($Data[$Start+2].ToString('X2')) $($Data[$Start+3].ToString('X2')) = $Value" -Level Debug
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
        # Version/Counter (first 4 bytes as little-endian DWORD)
        $Settings.Version = Read-UInt32FromBytes -Data $Data -Start 0
        if ($null -eq $Settings.Version) {
            Write-Detail -Message "Failed to read version field" -Level Error
            return $Settings
        } # end of version check
        Write-Detail -Message "Version/Counter: $($Settings.Version)" -Level Debug

        # Connection flags (bytes 4-7 as little-endian DWORD)
        $Settings.Flags = Read-UInt32FromBytes -Data $Data -Start 4
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

        # Unknown field at bytes 8-11 (possibly increment counter or secondary version)
        $Settings.UnknownField = Read-UInt32FromBytes -Data $Data -Start 8
        Write-Detail -Message "Unknown field (bytes 8-11): $($Settings.UnknownField)" -Level Debug

        # Parse data sections sequentially - structure is:
        # Bytes 12-15: Proxy server length
        # Bytes 16+: Proxy server string (if length > 0)
        # Next 4 bytes: Bypass length
        # Next bytes: Bypass string (if length > 0)
        # Next 4 bytes: PAC URL length
        # Next bytes: PAC URL string (if length > 0)
        # Final 32 bytes: Padding (0x00)

        $Offset = 12
        Write-Detail -Message "Starting data parsing at offset $Offset (proxy length field)" -Level Debug

        # Proxy server section (always read length field)
        if ($Data.Length -gt ($Offset + 3)) {
            Write-Detail -Message "Reading proxy length from offset $Offset" -Level Debug
            Write-Detail -Message "Proxy length bytes: 0x$($Data[$Offset].ToString('X2')) 0x$($Data[$Offset+1].ToString('X2')) 0x$($Data[$Offset+2].ToString('X2')) 0x$($Data[$Offset+3].ToString('X2'))" -Level Debug
            $ProxyLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            Write-Detail -Message "Proxy server section: $ProxyLength bytes at offset $Offset" -Level Debug
            $Offset += 4

            Write-Detail -Message "Proxy length value: $ProxyLength (type: $($ProxyLength.GetType().Name))" -Level Debug
            Write-Detail -Message "Length check: ProxyLength -gt 0 = $($ProxyLength -gt 0)" -Level Debug
            Write-Detail -Message "Bounds check: ($Offset + $ProxyLength) -le $($Data.Length) = $(($Offset + $ProxyLength) -le $Data.Length)" -Level Debug
            Write-Detail -Message "Combined condition result: $(($ProxyLength -gt 0) -and (($Offset + $ProxyLength) -le $Data.Length))" -Level Debug

            if ($ProxyLength -gt 0 -and ($Offset + $ProxyLength) -le $Data.Length) {
                Write-Detail -Message "ENTERING proxy string extraction block" -Level Debug
                # Extract proxy server string only if length > 0
                $ProxyBytes = $Data[$Offset..($Offset + $ProxyLength - 1)]
                $Settings.ProxyServer = [System.Text.Encoding]::ASCII.GetString($ProxyBytes).TrimEnd([char]0)
                Write-Detail -Message "Proxy Server: $($Settings.ProxyServer)" -Level Info
            } else {
                $Settings.ProxyServer = ""
                if ($ProxyLength -eq 0) {
                    Write-Detail -Message "Proxy Server: (none - length is 0)" -Level Info
                } # end of zero length message
            } # end of proxy string extraction
            $Offset += $ProxyLength
            Write-Detail -Message "After proxy section, offset now: $Offset" -Level Debug
        } # end of proxy parsing

        # Proxy bypass section (always read length field)
        if ($Data.Length -gt ($Offset + 3)) {
            Write-Detail -Message "Reading bypass length from offset $Offset" -Level Debug
            Write-Detail -Message "Available bytes from offset: $($Data.Length - $Offset)" -Level Debug
            Write-Detail -Message "Bypass length bytes: 0x$($Data[$Offset].ToString('X2')) 0x$($Data[$Offset+1].ToString('X2')) 0x$($Data[$Offset+2].ToString('X2')) 0x$($Data[$Offset+3].ToString('X2'))" -Level Debug

            # Safety check before conversion
            if (($Offset + 4) -gt $Data.Length) {
                Write-Detail -Message "ERROR: Not enough bytes to read bypass length at offset $Offset" -Level Error
                $Settings.ProxyBypass = ""
                return $Settings
            } # end of bounds check

            $BypassLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            Write-Detail -Message "Proxy bypass section: $BypassLength bytes at offset $Offset" -Level Debug
            $Offset += 4

            # Sanity check on bypass length
            if ($BypassLength -gt 1000) {
                Write-Detail -Message "WARNING: Bypass length $BypassLength seems unreasonable - possible parsing error at offset $Offset" -Level Warning
                Write-Detail -Message "This suggests our offset tracking is incorrect" -Level Warning
                $Settings.ProxyBypass = ""
            } else {
                if ($BypassLength -gt 0 -and ($Offset + $BypassLength) -le $Data.Length) {
                    # Extract proxy bypass string only if length > 0
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
            } # end of sanity check
        } else {
            Write-Detail -Message "Not enough bytes remaining to read bypass length" -Level Warning
            $Settings.ProxyBypass = ""
        } # end of bypass parsing

        # Auto config URL section (always read length field)
        if ($Data.Length -gt ($Offset + 3)) {
            Write-Detail -Message "Reading auto config length from offset $Offset, remaining bytes: $($Data.Length - $Offset)" -Level Debug
            Write-Detail -Message "Next 4 bytes: 0x$($Data[$Offset].ToString('X2')) 0x$($Data[$Offset+1].ToString('X2')) 0x$($Data[$Offset+2].ToString('X2')) 0x$($Data[$Offset+3].ToString('X2'))" -Level Debug

            $ConfigLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            Write-Detail -Message "Auto config URL section: $ConfigLength bytes at offset $Offset" -Level Debug

            # Sanity check - if length is unreasonably large, we have a parsing error
            if ($ConfigLength -gt 1000) {
                Write-Detail -Message "WARNING: Config length $ConfigLength seems too large - possible parsing error" -Level Warning
                Write-Detail -Message "Data from offset $Offset onwards: $([System.BitConverter]::ToString($Data[$Offset..($Offset+15)]))" -Level Debug
                $Settings.AutoConfigURL = ""
                return $Settings
            } # end of sanity check

            $Offset += 4

            if ($ConfigLength -gt 0 -and ($Offset + $ConfigLength) -le $Data.Length) {
                # Extract auto config URL string only if length > 0
                $ConfigBytes = $Data[$Offset..($Offset + $ConfigLength - 1)]
                $Settings.AutoConfigURL = [System.Text.Encoding]::ASCII.GetString($ConfigBytes).TrimEnd([char]0)
                Write-Detail -Message "Auto Config URL (stored): $($Settings.AutoConfigURL)" -Level Info
            } else {
                $Settings.AutoConfigURL = ""
                if ($ConfigLength -eq 0) {
                    Write-Detail -Message "Auto Config URL: (none - length is 0)" -Level Info
                } # end of zero length message
            } # end of config URL extraction
            $Offset += $ConfigLength
        } # end of auto config parsing

        # Re-evaluate enabled states using OR logic:
        # Enabled if flag is set OR value is present
        $FlagProxyEnabled = ($Settings.Flags -band 0x02) -eq 0x02
        $FlagAutoConfigEnabled = ($Settings.Flags -band 0x04) -eq 0x04

        $Settings.ProxyEnabled = $FlagProxyEnabled -or (-not [string]::IsNullOrEmpty($Settings.ProxyServer))
        $Settings.AutoConfigEnabled = $FlagAutoConfigEnabled -or (-not [string]::IsNullOrEmpty($Settings.AutoConfigURL))

        Write-Detail -Message "Final ProxyEnabled: $($Settings.ProxyEnabled) (flag: $FlagProxyEnabled, has value: $(-not [string]::IsNullOrEmpty($Settings.ProxyServer)))" -Level Debug
        Write-Detail -Message "Final AutoConfigEnabled: $($Settings.AutoConfigEnabled) (flag: $FlagAutoConfigEnabled, has value: $(-not [string]::IsNullOrEmpty($Settings.AutoConfigURL)))" -Level Debug

        return $Settings

    } catch {
        Write-Detail -Message "Error decoding binary data: $($_.Exception.Message)" -Level Error
        throw
    } # end of decode try-catch
} # end of Decode-ConnectionSettings function

#endregion Connection Settings Functions

#region Main Execution

# Registry path constant
$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
$ValueName = "DefaultConnectionSettings"

Write-Detail -Message "Starting DefaultConnectionSettings reader tool (READ-ONLY)" -Level Info

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
    Write-Detail -Message "Bytes 0-3   (Version):      $($Bytes[0].ToString('X2')) $($Bytes[1].ToString('X2')) $($Bytes[2].ToString('X2')) $($Bytes[3].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 0)))" -Level Info
    Write-Detail -Message "Bytes 4-7   (Flags):        $($Bytes[4].ToString('X2')) $($Bytes[5].ToString('X2')) $($Bytes[6].ToString('X2')) $($Bytes[7].ToString('X2')) = 0x$(([System.BitConverter]::ToUInt32($Bytes, 4)).ToString('X8'))" -Level Info
    Write-Detail -Message "Bytes 8-11  (Unknown):      $($Bytes[8].ToString('X2')) $($Bytes[9].ToString('X2')) $($Bytes[10].ToString('X2')) $($Bytes[11].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 8)))" -Level Info
    Write-Detail -Message "Bytes 12-15 (Proxy Len):    $($Bytes[12].ToString('X2')) $($Bytes[13].ToString('X2')) $($Bytes[14].ToString('X2')) $($Bytes[15].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 12)))" -Level Info
    if ($Bytes.Length -gt 19) {
        Write-Detail -Message "Bytes 16-19 (Data/Len):     $($Bytes[16].ToString('X2')) $($Bytes[17].ToString('X2')) $($Bytes[18].ToString('X2')) $($Bytes[19].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 16)))" -Level Info
    }
    if ($Bytes.Length -gt 23) {
        Write-Detail -Message "Bytes 20-23 (Data/Len):     $($Bytes[20].ToString('X2')) $($Bytes[21].ToString('X2')) $($Bytes[22].ToString('X2')) $($Bytes[23].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 20)))" -Level Info
    }

    # Structure documentation
    Write-Detail -Message "STRUCTURE:" -Level Info
    Write-Detail -Message "  Bytes 0-3:   Version/Counter (DWORD)" -Level Info
    Write-Detail -Message "  Bytes 4-7:   Connection Flags (DWORD)" -Level Info
    Write-Detail -Message "  Bytes 8-11:  Unknown Field (DWORD)" -Level Info
    Write-Detail -Message "  Bytes 12-15: Proxy Server Length (DWORD)" -Level Info
    Write-Detail -Message "  Bytes 16+:   Proxy Server String (if length > 0)" -Level Info
    Write-Detail -Message "  Next 4:      Bypass Length (DWORD)" -Level Info
    Write-Detail -Message "  Next bytes:  Bypass String (if length > 0)" -Level Info
    Write-Detail -Message "  Next 4:      PAC URL Length (DWORD)" -Level Info
    Write-Detail -Message "  Next bytes:  PAC URL String (if length > 0)" -Level Info
    Write-Detail -Message "  Final 32:    Padding (0x00 bytes)" -Level Info
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
Write-Detail -Message "Version/Counter: $($CurrentSettings.Version)" -Level Info
if ($CurrentSettings.ContainsKey('UnknownField')) {
    Write-Detail -Message "Unknown Field (bytes 8-11): $($CurrentSettings.UnknownField)" -Level Debug
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

Write-Detail -Message "DefaultConnectionSettings reader completed successfully (READ-ONLY mode)" -Level Info
exit 0

#endregion Main Execution

