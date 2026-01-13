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

        # Structure: 12-byte header + interleaved length+data sections
        # Starting at offset 0x0C (12): Length+Data, Length+Data, Length+Data
        $Offset = 12
        Write-Detail -Message "Starting variable sections at offset $Offset (0x0C)" -Level Debug

        # ProxyServer: Read length, then data
        if ($Data.Length -gt ($Offset + 3)) {
            $ProxyLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            Write-Detail -Message "ProxyServer Length at offset $($Offset): $ProxyLength bytes" -Level Debug
            $Offset += 4

            if ($ProxyLength -gt 0 -and ($Offset + $ProxyLength) -le $Data.Length) {
                $ProxyBytes = $Data[$Offset..($Offset + $ProxyLength - 1)]
                $Settings.ProxyServer = [System.Text.Encoding]::ASCII.GetString($ProxyBytes).TrimEnd([char]0)
                Write-Detail -Message "Proxy Server: $($Settings.ProxyServer)" -Level Info
                $Offset += $ProxyLength
            } else {
                $Settings.ProxyServer = ""
                if ($ProxyLength -eq 0) {
                    Write-Detail -Message "Proxy Server: (none - length is 0)" -Level Info
                }
            }
            Write-Detail -Message "After proxy section, offset now: $($Offset)" -Level Debug
        } else {
            $Settings.ProxyServer = ""
        }

        # ProxyBypass: Read length, then data
        if ($Data.Length -gt ($Offset + 3)) {
            $BypassLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            Write-Detail -Message "ProxyBypass Length at offset $($Offset): $BypassLength bytes" -Level Debug
            $Offset += 4

            if ($BypassLength -gt 0 -and ($Offset + $BypassLength) -le $Data.Length) {
                $BypassBytes = $Data[$Offset..($Offset + $BypassLength - 1)]
                $Settings.ProxyBypass = [System.Text.Encoding]::ASCII.GetString($BypassBytes).TrimEnd([char]0)
                Write-Detail -Message "Proxy Bypass: $($Settings.ProxyBypass)" -Level Info
                $Offset += $BypassLength
            } else {
                $Settings.ProxyBypass = ""
                if ($BypassLength -eq 0) {
                    Write-Detail -Message "Proxy Bypass: (none - length is 0)" -Level Info
                }
            }
            Write-Detail -Message "After bypass section, offset now: $($Offset)" -Level Debug
        } else {
            $Settings.ProxyBypass = ""
        }

        # AutoConfigURL: Read length, then data
        if ($Data.Length -gt ($Offset + 3)) {
            $ConfigLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            Write-Detail -Message "AutoConfigURL Length at offset $($Offset): $ConfigLength bytes" -Level Debug
            $Offset += 4

            if ($ConfigLength -gt 0 -and ($Offset + $ConfigLength) -le $Data.Length) {
                $ConfigBytes = $Data[$Offset..($Offset + $ConfigLength - 1)]
                $Settings.AutoConfigURL = [System.Text.Encoding]::ASCII.GetString($ConfigBytes).TrimEnd([char]0)
                Write-Detail -Message "Auto Config URL: $($Settings.AutoConfigURL)" -Level Info
                $Offset += $ConfigLength
            } else {
                $Settings.AutoConfigURL = ""
                if ($ConfigLength -eq 0) {
                    Write-Detail -Message "Auto Config URL: (none - length is 0)" -Level Info
                }
            }
            Write-Detail -Message "After AutoConfig section, offset now: $($Offset)" -Level Debug
        } else {
            $Settings.AutoConfigURL = ""
        }

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

    Write-Detail -Message "STRUCTURE BREAKDOWN (12-byte Fixed Header):" -Level Info
    Write-Detail -Message "Bytes  0-3  (Ver Sig):      $($Bytes[0].ToString('X2')) $($Bytes[1].ToString('X2')) $($Bytes[2].ToString('X2')) $($Bytes[3].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 0)))" -Level Info
    Write-Detail -Message "Bytes  4-7  (Ver/Cnt):      $($Bytes[4].ToString('X2')) $($Bytes[5].ToString('X2')) $($Bytes[6].ToString('X2')) $($Bytes[7].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 4)))" -Level Info
    Write-Detail -Message "Bytes  8-11 (FLAGS):        $($Bytes[8].ToString('X2')) $($Bytes[9].ToString('X2')) $($Bytes[10].ToString('X2')) $($Bytes[11].ToString('X2')) = 0x$(([System.BitConverter]::ToUInt32($Bytes, 8)).ToString('X8'))" -Level Info
    Write-Host ""
    Write-Detail -Message "Variable Sections (Length + Data interleaved, starting at byte 12):" -Level Info
    Write-Detail -Message "Bytes 12-15 (Proxy Len):    $($Bytes[12].ToString('X2')) $($Bytes[13].ToString('X2')) $($Bytes[14].ToString('X2')) $($Bytes[15].ToString('X2')) = $(([System.BitConverter]::ToUInt32($Bytes, 12)))" -Level Info

    $ProxyLen = [System.BitConverter]::ToUInt32($Bytes, 12)
    if ($ProxyLen -gt 0 -and $Bytes.Length -gt (16 + $ProxyLen)) {
        $ProxyDataHex = ($Bytes[16..(15+$ProxyLen)] | ForEach-Object { $_.ToString('X2') }) -join ' '
        Write-Detail -Message "Bytes 16-$(15+$ProxyLen) (Proxy Data):    $ProxyDataHex" -Level Info
        $NextOffset = 16 + $ProxyLen
    } else {
        $NextOffset = 16
    }

    if ($Bytes.Length -gt ($NextOffset + 3)) {
        $BypassLenMsg = "Bytes {0}-{1} (Bypass Len):   {2} {3} {4} {5} = {6}" -f $NextOffset, ($NextOffset+3), $Bytes[$NextOffset].ToString('X2'), $Bytes[$NextOffset+1].ToString('X2'), $Bytes[$NextOffset+2].ToString('X2'), $Bytes[$NextOffset+3].ToString('X2'), ([System.BitConverter]::ToUInt32($Bytes, $NextOffset))
        Write-Detail -Message $BypassLenMsg -Level Info

        $BypassLen = [System.BitConverter]::ToUInt32($Bytes, $NextOffset)
        $NextOffset += 4
        if ($BypassLen -gt 0 -and $Bytes.Length -gt ($NextOffset + $BypassLen)) {
            $BypassDataMsg = "Bytes {0}-{1} (Bypass Data):  [{2} bytes]" -f $NextOffset, ($NextOffset+$BypassLen-1), $BypassLen
            Write-Detail -Message $BypassDataMsg -Level Info
            $NextOffset += $BypassLen
        }

        if ($Bytes.Length -gt ($NextOffset + 3)) {
            $AutoCfgLenMsg = "Bytes {0}-{1} (AutoCfg Len): {2} {3} {4} {5} = {6}" -f $NextOffset, ($NextOffset+3), $Bytes[$NextOffset].ToString('X2'), $Bytes[$NextOffset+1].ToString('X2'), $Bytes[$NextOffset+2].ToString('X2'), $Bytes[$NextOffset+3].ToString('X2'), ([System.BitConverter]::ToUInt32($Bytes, $NextOffset))
            Write-Detail -Message $AutoCfgLenMsg -Level Info

            $AutoCfgLen = [System.BitConverter]::ToUInt32($Bytes, $NextOffset)
            $NextOffset += 4
            if ($AutoCfgLen -gt 0 -and $Bytes.Length -gt ($NextOffset + $AutoCfgLen)) {
                $AutoCfgDataMsg = "Bytes {0}-{1} (AutoCfg Data): [{2} bytes]" -f $NextOffset, ($NextOffset+$AutoCfgLen-1), $AutoCfgLen
                Write-Detail -Message $AutoCfgDataMsg -Level Info
            }
        }
    }
    Write-Host ""

    # Structure documentation
    Write-Detail -Message "STRUCTURE (12-byte header + variable length+data sections):" -Level Info
    Write-Detail -Message "  FIXED HEADER (12 bytes):" -Level Info
    Write-Detail -Message "    Bytes 0x00-0x03:  Version Signature (DWORD)" -Level Info
    Write-Detail -Message "    Bytes 0x04-0x07:  Version/Counter (DWORD)" -Level Info
    Write-Detail -Message "    Bytes 0x08-0x0B:  Connection Flags (DWORD)" -Level Info
    Write-Detail -Message "  VARIABLE SECTIONS (starting at 0x0C, interleaved length+data):" -Level Info
    Write-Detail -Message "    Section 1: ProxyServer Length (4 bytes) + ProxyServer Data (L1 bytes)" -Level Info
    Write-Detail -Message "    Section 2: ProxyBypass Length (4 bytes) + ProxyBypass Data (L2 bytes)" -Level Info
    Write-Detail -Message "    Section 3: AutoConfigURL Length (4 bytes) + AutoConfigURL Data (L3 bytes)" -Level Info
    Write-Detail -Message "    Remaining: Padding (typically 0x00 bytes)" -Level Info
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

