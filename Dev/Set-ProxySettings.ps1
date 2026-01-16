<#
    .SYNOPSIS
        Remediation Script: Removes unwanted proxy configuration from DefaultConnectionSettings

    .DESCRIPTION
        Reads the DefaultConnectionSettings binary registry value, removes specified
        proxy configuration elements (AutoConfigURL, ProxyServer, ProxyBypass), and
        writes the updated configuration back to the registry.

        This script automatically increments the change counter to simulate Windows
        behavior when modifying proxy settings.

    .PARAMETER RemoveAutoConfig
        Remove the AutoConfigURL and disable AutoConfig flag (default: $true)

    .PARAMETER RemoveProxyServer
        Remove the ProxyServer and ProxyBypass settings and disable Proxy flag (default: $false)

    .PARAMETER EnableDirectConnection
        Ensure DirectConnection flag is enabled (default: $true)

    .PARAMETER CreateBackup
        Create registry backup before making changes (default: $true)

    .EXAMPLE
        .\Set-ProxySettings.ps1
        Removes AutoConfigURL, keeps proxy settings intact

    .EXAMPLE
        .\Set-ProxySettings.ps1 -RemoveAutoConfig $true -RemoveProxyServer $true
        Removes both AutoConfigURL and ProxyServer settings

    .EXAMPLE
        .\Set-ProxySettings.ps1 -RemoveAutoConfig $false -RemoveProxyServer $true
        Removes only ProxyServer, keeps AutoConfigURL

    .NOTES
        Requires elevated privileges to modify HKCU registry
        Creates backup by default before making changes
        Version: 2.0.0.1 - Remediation-focused with 12-byte header support
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$RemoveAutoConfig = $true,

    [Parameter(Mandatory = $false)]
    [bool]$RemoveProxyServer = $false,

    [Parameter(Mandatory = $false)]
    [bool]$EnableDirectConnection = $true,

    [Parameter(Mandatory = $false)]
    [bool]$CreateBackup = $true
)

#region Helper Functions

##########################################################################################
#                                   Helper Functions
##########################################################################################

Function Write-Detail {
<#
    .SYNOPSIS
        Writes to host formatted
    .DESCRIPTION
        "Write-Detail"
    .PARAMETER message
    .INPUTS
        [String]
    .OUTPUTS
        [Standard Out]
    .EXAMPLE
        Write-Detail -message "This is my message for the log file."
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Please Enter string to display.")]
        [string]
        [ValidateNotNullOrEmpty()]
        $message
    )
    Write-Host "$(Get-Date -Format s)`t$($MyInvocation.ScriptLineNumber) `t- $message" -Verbose
}

function Write-CMLog {
    <#
    .Synopsis
       Writes an entry to a log file
    .DESCRIPTION
       This function writes an entry to a log file, using System Center 2012's log
       format.  This format is easiest to read if viewed by CMTrace.exe (provided with
       the SCCM 2012 Admin client) or Trace32.exe (provided with the SCCM 2007 Toolkit).
       To override this behavior, pass the -AsPlainText switch.

       It is recommended to define a scriptwide variable, $script:logFile, for use with
       this function.  This will remove the need to pass the -LogFile parameter each
       time the function is called.

       This function will also write the log message to the Verbose output stream.

       This function does not provide support for pipeline input.
    #>
    [CmdletBinding()]
    param(
        # The message to be displayed in the log file
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $Message,

        # The severity of the log entry (optional, default is 'Note')
        [Parameter(Mandatory = $false)]
        [ValidateSet('Note', 'Warning', 'Error')]
        [String] $Severity = 'Note',

        # The component or module name to record for this log entry (optional)
        [Parameter(Mandatory = $false)]
        [String] $Component = $script:scriptName,

        # The line number to reference for this log entry (optional)
        [Parameter(Mandatory = $false)]
        [String] $LineNumber,

        # The path of the log file to use (optional if $script:logFile is specified)
        [Parameter(Mandatory = $false)]
        [String] $LogFile = $script:logFile,

        [Parameter(Mandatory = $false)]
        [Alias('AsText', 'a')]
        [Switch] $AsPlainText
    )

    if (-not ($LogFile)) {
        Write-Error "You must either define a log file in the variable `$script:logFile or pass the -LogFile argument."
        return
    }

    $date = Get-Date -Format "MM-dd-yyyy"
    $time = Get-Date -Format "hh:mm:ss.fff"

    if ($AsPlainText) {
        $logText = "$date $time [$Severity] - $Message"
    }
    else {
        if ($Severity -eq 'Warning') {
            $s = 2
        }
        elseif ($Severity -eq 'Error') {
            $s = 3
        }
        else {
            $s = 1 #default case
        }

        if ($script:timezoneBias -eq $null) {
            [int] $script:timezoneBias = Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias
        }

        $timeString = "$time$script:timezoneBias"

        if ($LineNumber) {
            $fileName = "${script:scriptName}:$LineNumber"
        }
        else {
            $fileName = $script:scriptName
        }

        $logText = "<![LOG[$($MyInvocation.ScriptLineNumber) `t$Message]LOG]!><time=`"$timeString`" date=`"$date`" component=`"$Component`" context=`"`" type=`"$s`" thread=`"$PID`" file=`"$fileName`">"
    }

    if (-not (Test-Path $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }

    Out-File -InputObject $logText -FilePath $LogFile -Encoding default -Append -NoClobber
    Write-Verbose $Message
}

# Helper function to safely read a 32-bit integer from byte array
Function Read-UInt32FromBytes {
    param(
        [byte[]]$Data,
        [int]$Start,
        [int]$Length = 4
    )

    # Validate we have enough bytes
    if (($Start + $Length) -gt $Data.Length) {
        Write-CMLog "ERROR: Cannot read UInt32 at position $Start - not enough bytes" -Severity Error -Component 'BinaryParser'
        return $null
    }

    # Extract subset and convert
    try {
        $SubsetBytes = $Data[$Start..($Start + $Length - 1)]
        $Value = [System.BitConverter]::ToUInt32($SubsetBytes, 0)
        return $Value
    }
    catch {
        Write-CMLog "ERROR: Failed to read UInt32 at position ${Start}: $($_.Exception.Message)" -Severity Error -Component 'BinaryParser'
        return $null
    }
}

# Function to decode the binary data structure (12-byte header)
Function Decode-ConnectionSettings {
    param([byte[]]$Data)

    Write-CMLog "Decoding DefaultConnectionSettings binary structure" -Component 'Decoder'

    # Create hashtable to store decoded values
    $Settings = @{}

    try {
        # Version Signature (bytes 0x00-0x03)
        $Settings.VersionSignature = Read-UInt32FromBytes -Data $Data -Start 0
        if ($null -eq $Settings.VersionSignature) {
            Write-CMLog "Failed to read version signature" -Severity Error -Component 'Decoder'
            return $Settings
        }

        # Change Counter (bytes 0x04-0x07)
        $Settings.Version = Read-UInt32FromBytes -Data $Data -Start 4
        if ($null -eq $Settings.Version) {
            Write-CMLog "Failed to read change counter" -Severity Error -Component 'Decoder'
            return $Settings
        }

        # Connection FLAGS (bytes 0x08-0x0B)
        $Settings.Flags = Read-UInt32FromBytes -Data $Data -Start 8
        if ($null -eq $Settings.Flags) {
            Write-CMLog "Failed to read flags field" -Severity Error -Component 'Decoder'
            return $Settings
        }

        # Decode individual flag bits
        $Settings.DirectConnection = ($Settings.Flags -band 0x01) -eq 0x01
        $Settings.ProxyEnabled = ($Settings.Flags -band 0x02) -eq 0x02
        $Settings.AutoConfigEnabled = ($Settings.Flags -band 0x04) -eq 0x04
        $Settings.AutoDetectEnabled = ($Settings.Flags -band 0x08) -eq 0x08

        # Structure: 12-byte header + interleaved length+data sections
        $Offset = 12

        # ProxyServer: Read length, then data
        if ($Data.Length -gt ($Offset + 3)) {
            $ProxyLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            $Offset += 4

            if ($ProxyLength -gt 0 -and ($Offset + $ProxyLength) -le $Data.Length) {
                $ProxyBytes = $Data[$Offset..($Offset + $ProxyLength - 1)]
                $Settings.ProxyServer = [System.Text.Encoding]::ASCII.GetString($ProxyBytes).TrimEnd([char]0)
                $Offset += $ProxyLength
            }
            else {
                $Settings.ProxyServer = ""
            }
        }
        else {
            $Settings.ProxyServer = ""
        }

        # ProxyBypass: Read length, then data
        if ($Data.Length -gt ($Offset + 3)) {
            $BypassLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            $Offset += 4

            if ($BypassLength -gt 0 -and ($Offset + $BypassLength) -le $Data.Length) {
                $BypassBytes = $Data[$Offset..($Offset + $BypassLength - 1)]
                $Settings.ProxyBypass = [System.Text.Encoding]::ASCII.GetString($BypassBytes).TrimEnd([char]0)
                $Offset += $BypassLength
            }
            else {
                $Settings.ProxyBypass = ""
            }
        }
        else {
            $Settings.ProxyBypass = ""
        }

        # AutoConfigURL: Read length, then data
        if ($Data.Length -gt ($Offset + 3)) {
            $ConfigLength = Read-UInt32FromBytes -Data $Data -Start $Offset
            $Offset += 4

            if ($ConfigLength -gt 0 -and ($Offset + $ConfigLength) -le $Data.Length) {
                $ConfigBytes = $Data[$Offset..($Offset + $ConfigLength - 1)]
                $Settings.AutoConfigURL = [System.Text.Encoding]::ASCII.GetString($ConfigBytes).TrimEnd([char]0)
                $Offset += $ConfigLength
            }
            else {
                $Settings.AutoConfigURL = ""
            }
        }
        else {
            $Settings.AutoConfigURL = ""
        }

        return $Settings

    }
    catch {
        Write-CMLog "Error decoding binary data: $($_.Exception.Message)" -Severity Error -Component 'Decoder'
        throw
    }
}

# Function to encode settings back to binary format (12-byte header)
Function Encode-ConnectionSettings {
    param([hashtable]$Settings)

    Write-CMLog "Encoding settings back to binary format" -Component 'Encoder'

    try {
        # Prepare string data
        $ProxyStringBytes = @()
        if ($Settings.ProxyEnabled -and $Settings.ProxyServer) {
            $ProxyStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.ProxyServer + [char]0)
        }

        $BypassStringBytes = @()
        if ($Settings.ProxyEnabled -and $Settings.ProxyBypass) {
            $BypassStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.ProxyBypass + [char]0)
        }

        $ConfigStringBytes = @()
        if ($Settings.AutoConfigEnabled -and $Settings.AutoConfigURL) {
            $ConfigStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.AutoConfigURL + [char]0)
        }

        Write-CMLog "String lengths - Proxy: $($ProxyStringBytes.Length), Bypass: $($BypassStringBytes.Length), AutoConfig: $($ConfigStringBytes.Length)" -Component 'Encoder'

        # Build 12-byte fixed header
        $ResultBytes = @()

        # 0x00-0x03: Version Signature (use existing or default to 70)
        $VersionSig = if ($Settings.ContainsKey('VersionSignature')) { $Settings.VersionSignature } else { 70 }
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$VersionSig)

        # 0x04-0x07: Change Counter
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$Settings.Version)

        # 0x08-0x0B: FLAGS
        $FlagsValue = 0
        if ($Settings.DirectConnection) { $FlagsValue = $FlagsValue -bor 0x01 }
        if ($Settings.ProxyEnabled) { $FlagsValue = $FlagsValue -bor 0x02 }
        if ($Settings.AutoConfigEnabled) { $FlagsValue = $FlagsValue -bor 0x04 }
        if ($Settings.AutoDetectEnabled) { $FlagsValue = $FlagsValue -bor 0x08 }
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$FlagsValue)

        Write-CMLog "Header built - Version: $VersionSig, Counter: $($Settings.Version), Flags: 0x$($FlagsValue.ToString('X8'))" -Component 'Encoder'

        # Add interleaved length+data sections starting at 0x0C
        # Section 1: ProxyServer Length + Data
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$ProxyStringBytes.Length)
        if ($ProxyStringBytes.Length -gt 0) {
            $ResultBytes += $ProxyStringBytes
        }

        # Section 2: ProxyBypass Length + Data
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$BypassStringBytes.Length)
        if ($BypassStringBytes.Length -gt 0) {
            $ResultBytes += $BypassStringBytes
        }

        # Section 3: AutoConfigURL Length + Data
        $ResultBytes += [System.BitConverter]::GetBytes([uint32]$ConfigStringBytes.Length)
        if ($ConfigStringBytes.Length -gt 0) {
            $ResultBytes += $ConfigStringBytes
        }

        # Add padding (typically 32 bytes of 0x00)
        $PaddingSize = 32
        $Padding = New-Object byte[] $PaddingSize
        $ResultBytes += $Padding

        Write-CMLog "Successfully encoded $($ResultBytes.Length) bytes total" -Component 'Encoder'
        return $ResultBytes

    }
    catch {
        Write-CMLog "Error encoding settings: $($_.Exception.Message)" -Severity Error -Component 'Encoder'
        throw
    }
}

#endregion

#region Global Variables
## Variables: Script Name and Script Paths
[string]$scriptPath     = $MyInvocation.MyCommand.Definition
[string]$scriptName     = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptFileName = Split-Path -Path $scriptPath -Leaf
[string]$scriptRoot     = Split-Path -Path $scriptPath -Parent

[string]$LogFileTime    = Get-Date -Format "yyyyMMdd"
$logFile                = Join-Path 'C:\Windows\Logs' -ChildPath "Remediation-ProxySettings-$LogFileTime.log"
$ErrorActionPreference  = "Stop"
$RegistryPath           = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
$ValueName              = "DefaultConnectionSettings"
[STRING]$thisScriptPara = ''

# Capture any parameters
foreach ($key in $MyInvocation.BoundParameters.keys) {
    $thisScriptPara += "-$($key) $($MyInvocation.BoundParameters[$key])`r`n"
}

# Test Timezone
If (-not (Test-Path -Path 'variable:LogTimeZoneBias')) {
    [int32]$script:LogTimeZoneBias = [System.TimeZone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes
}

#endregion

Write-CMLog -Message "Starting Remediation Script - Set-ProxySettings - v2.0.0.1" -Severity Note -Component 'PreChecks' -LogFile $logFile
Write-CMLog -Message "Executing script `"$scriptPath`"" -Component 'ScriptName'
Write-CMLog -Message "RemoveAutoConfig: $RemoveAutoConfig" -Component 'Parameters'
Write-CMLog -Message "RemoveProxyServer: $RemoveProxyServer" -Component 'Parameters'
Write-CMLog -Message "EnableDirectConnection: $EnableDirectConnection" -Component 'Parameters'
Write-CMLog -Message "CreateBackup: $CreateBackup" -Component 'Parameters'

# Validate that at least one remediation action is specified
if (-not $RemoveAutoConfig -and -not $RemoveProxyServer) {
    Write-CMLog -Message "WARNING: No remediation actions specified - script will make no changes" -Severity Warning -Component 'Parameters'
    Write-Host "WARNING: No remediation actions specified. Use -RemoveAutoConfig or -RemoveProxyServer"
    Return 0
}

# Check if registry path exists
If (-not (Test-Path $RegistryPath)) {
    Write-CMLog "Registry path not found: $RegistryPath" -Severity Error -Component 'RegistryCheck'
    Write-Host "ERROR: Registry path not found"
    Return 1
}

Try {
    # Read the binary registry value
    Write-CMLog "Reading registry value from $RegistryPath" -Component 'RegistryRead'
    $BinaryData = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop
    $Bytes = $BinaryData.$ValueName

    if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
        Write-CMLog "Registry value is empty or null" -Severity Error -Component 'RegistryRead'
        Return 1
    }

    Write-CMLog "Successfully read $($Bytes.Length) bytes from registry" -Component 'RegistryRead'

    # Decode current settings
    $CurrentSettings = Decode-ConnectionSettings -Data $Bytes

    # Log current settings
    Write-CMLog "CURRENT Settings - Change Counter: $($CurrentSettings.Version)" -Component 'CurrentSettings'
    Write-CMLog "CURRENT Settings - ProxyEnabled: $($CurrentSettings.ProxyEnabled)" -Component 'CurrentSettings'
    Write-CMLog "CURRENT Settings - ProxyServer: `"$($CurrentSettings.ProxyServer)`"" -Component 'CurrentSettings'
    Write-CMLog "CURRENT Settings - AutoConfigEnabled: $($CurrentSettings.AutoConfigEnabled)" -Component 'CurrentSettings'
    Write-CMLog "CURRENT Settings - AutoConfigURL: `"$($CurrentSettings.AutoConfigURL)`"" -Component 'CurrentSettings'

    # Create backup if requested
    if ($CreateBackup) {
        Write-CMLog "Creating registry backup" -Component 'Backup'
        $BackupFile = Join-Path $env:TEMP "DefaultConnectionSettings_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
        $ExportCommand = "reg export `"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`" `"$BackupFile`" /y"

        try {
            Invoke-Expression $ExportCommand | Out-Null
            Write-CMLog "Registry backup created: $BackupFile" -Component 'Backup'
        }
        catch {
            Write-CMLog "WARNING: Failed to create backup: $($_.Exception.Message)" -Severity Warning -Component 'Backup'
        }
    }

    # Create modified settings
    $NewSettings = $CurrentSettings.Clone()

    # Increment change counter
    $NewSettings.Version = $NewSettings.Version + 1
    Write-CMLog "Incremented change counter from $($CurrentSettings.Version) to $($NewSettings.Version)" -Component 'Modification'

    # Apply remediation actions
    $ChangesMade = $false

    if ($RemoveAutoConfig) {
        if ($CurrentSettings.AutoConfigEnabled -or -not [string]::IsNullOrEmpty($CurrentSettings.AutoConfigURL)) {
            Write-CMLog "REMEDIATION: Removing AutoConfigURL and disabling AutoConfig flag" -Severity Note -Component 'Remediation'
            $NewSettings.AutoConfigEnabled = $false
            $NewSettings.AutoConfigURL = ""
            $ChangesMade = $true
        }
        else {
            Write-CMLog "AutoConfig already disabled/empty - no action needed" -Component 'Remediation'
        }
    }

    if ($RemoveProxyServer) {
        if ($CurrentSettings.ProxyEnabled -or -not [string]::IsNullOrEmpty($CurrentSettings.ProxyServer)) {
            Write-CMLog "REMEDIATION: Removing ProxyServer/ProxyBypass and disabling Proxy flag" -Severity Note -Component 'Remediation'
            $NewSettings.ProxyEnabled = $false
            $NewSettings.ProxyServer = ""
            $NewSettings.ProxyBypass = ""
            $ChangesMade = $true
        }
        else {
            Write-CMLog "Proxy already disabled/empty - no action needed" -Component 'Remediation'
        }
    }

    if ($EnableDirectConnection) {
        if (-not $CurrentSettings.DirectConnection) {
            Write-CMLog "REMEDIATION: Enabling DirectConnection flag" -Severity Note -Component 'Remediation'
            $NewSettings.DirectConnection = $true
            $ChangesMade = $true
        }
        else {
            Write-CMLog "DirectConnection already enabled - no action needed" -Component 'Remediation'
        }
    }

    if (-not $ChangesMade) {
        Write-CMLog "No changes needed - settings already compliant" -Component 'Remediation'
        Return 0
    }

    # Encode new settings
    Write-CMLog "Encoding modified settings to binary format" -Component 'Encoding'
    $NewBinaryData = Encode-ConnectionSettings -Settings $NewSettings

    # Write back to registry
    Write-CMLog "Writing modified settings to registry" -Severity Note -Component 'RegistryWrite'
    Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value $NewBinaryData -Type Binary

    # Log new settings
    Write-CMLog "NEW Settings - Change Counter: $($NewSettings.Version)" -Component 'NewSettings'
    Write-CMLog "NEW Settings - ProxyEnabled: $($NewSettings.ProxyEnabled)" -Component 'NewSettings'
    Write-CMLog "NEW Settings - ProxyServer: `"$($NewSettings.ProxyServer)`"" -Component 'NewSettings'
    Write-CMLog "NEW Settings - AutoConfigEnabled: $($NewSettings.AutoConfigEnabled)" -Component 'NewSettings'
    Write-CMLog "NEW Settings - AutoConfigURL: `"$($NewSettings.AutoConfigURL)`"" -Component 'NewSettings'
    Write-CMLog "NEW Settings - DirectConnection: $($NewSettings.DirectConnection)" -Component 'NewSettings'

    Write-CMLog "Registry updated successfully" -Severity Note -Component 'Success'
    Write-CMLog "Changes will take effect after restarting applications or rebooting" -Severity Warning -Component 'Success'

    Return 0
}
Catch {
    Write-CMLog "Error during remediation: $($_.Exception.Message)" -Severity Error -Component 'Error'
    Write-CMLog "Stack trace: $($_.ScriptStackTrace)" -Severity Error -Component 'Error'
    Return 1
}
