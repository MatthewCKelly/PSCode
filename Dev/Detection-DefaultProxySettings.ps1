<#
    .SYNOPSIS
        Detection Rule: Checks for specific proxy configuration in DefaultConnectionSettings

    .DESCRIPTION
        Reads and decodes the DefaultConnectionSettings binary registry value and checks
        if AutoConfigURL or ProxyServer contains specified patterns.

        Returns 1 (Non-Compliant) if pattern is found
        Returns 0 (Compliant) if pattern is not found

    .PARAMETER ProxyPattern
        Pattern to search for in ProxyServer field (default: "*webdefence.global.blackspider.com*")

    .PARAMETER AutoConfigPattern
        Pattern to search for in AutoConfigURL field (default: "*webdefence.global.blackspider.com*")

    .EXAMPLE
        .\Detection-DefaultProxySettings.ps1
        Checks for default pattern "*webdefence.global.blackspider.com*"

    .EXAMPLE
        .\Detection-DefaultProxySettings.ps1 -ProxyPattern "*proxy.company.com*"
        Checks for custom proxy pattern

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProxyPattern = "*webdefence.global.blackspider.com*",

    [Parameter(Mandatory = $false)]
    [string]$AutoConfigPattern = "*webdefence.global.blackspider.com*"
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
    .EXAMPLE
       Write-CMLog -Message "Captain's log, supplimental." -AsPlainText
       Writes the given text to the log file determined in the variable $script:logFile
       using plain text. This will add a timestamp, but will be easily readible in
       Notepad or another text editor.
    .EXAMPLE
       $myNum = 4; Write-CMLog "The variable MyNum is currently `"$MyNum`" -a
       Adds the given text, along with the value 4 (enclosed in quotes) to the log file
       defined in $script:logFile. This will also log using plain text using the -a alias.
    .EXAMPLE
       Write-CMLog -Message "Here's a rich log entry. Something went wrong!" -Severity Warning Component "SectionA" -Log
       Writes a warning log entry to the log file specified in $script:logFile. This will
       use the rich log notation used by System Center that is easiest to parse using CMTrace.
    .EXAMPLE
       Write-CMLog "What file is this?" -LogFile (Join-Path $env:TEMP "newLog.log") -A
       Adds the line to a file called newLog.log in the current temporary directory. This
       will log using plain text.
    .INPUTS
       None

       This function does not accept pipeline input.
    .OUTPUTS
       None

       This function does not provide pipeline output.
    .NOTES
       Author: Joshua Taliaferro
       Version: 1.1
    .FUNCTIONALITY
       Provides logging functionality
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

# Function to decode the binary data structure
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

#endregion

#region Global Variables
## Variables: Script Name and Script Paths
[string]$scriptPath     = $MyInvocation.MyCommand.Definition
[string]$scriptName     = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptFileName = Split-Path -Path $scriptPath -Leaf
[string]$scriptRoot     = Split-Path -Path $scriptPath -Parent

[string]$LogFileTime    = Get-Date -Format "yyyyMMdd"
$logFile                = Join-Path 'C:\Windows\Logs' -ChildPath "Detection-DefaultProxySettings-$LogFileTime.log"
$ErrorActionPreference  = "Stop"
$RegistryPath           = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
$ValueName              = "DefaultConnectionSettings"
$foundPattern           = $false
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

Write-CMLog -Message "Starting Detection Rule - DefaultConnectionSettings - v1.0.0.1" -Severity Note -Component 'PreChecks' -LogFile $logFile
Write-CMLog -Message "Executing script `"$scriptPath`"" -Component 'ScriptName'
Write-CMLog -Message "ProxyPattern: `"$ProxyPattern`"" -Component 'Parameters'
Write-CMLog -Message "AutoConfigPattern: `"$AutoConfigPattern`"" -Component 'Parameters'

# Check if registry path exists
If (Test-Path $RegistryPath) {
    Write-CMLog "Registry path found: $RegistryPath" -Component 'RegistryCheck'

    Try {
        # Read the binary registry value
        $BinaryData = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop
        $Bytes = $BinaryData.$ValueName

        if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
            Write-CMLog "Registry value is empty or null" -Severity Warning -Component 'RegistryCheck'
        }
        else {
            Write-CMLog "Successfully read $($Bytes.Length) bytes from registry" -Component 'RegistryCheck'

            # Decode the settings
            $Settings = Decode-ConnectionSettings -Data $Bytes

            # Log decoded settings
            Write-CMLog "Decoded Settings - Change Counter: $($Settings.Version)" -Component 'DecodedSettings'
            Write-CMLog "Decoded Settings - ProxyEnabled: $($Settings.ProxyEnabled)" -Component 'DecodedSettings'
            Write-CMLog "Decoded Settings - ProxyServer: `"$($Settings.ProxyServer)`"" -Component 'DecodedSettings'
            Write-CMLog "Decoded Settings - AutoConfigEnabled: $($Settings.AutoConfigEnabled)" -Component 'DecodedSettings'
            Write-CMLog "Decoded Settings - AutoConfigURL: `"$($Settings.AutoConfigURL)`"" -Component 'DecodedSettings'

            # Check ProxyServer against pattern
            If ($Settings.ProxyServer -and ($Settings.ProxyServer -ilike $ProxyPattern)) {
                Write-CMLog "MATCH FOUND: ProxyServer `"$($Settings.ProxyServer)`" matches pattern `"$ProxyPattern`"" -Severity Warning -Component 'DetectionRule'
                $foundPattern = $true
            }

            # Check AutoConfigURL against pattern
            If ($Settings.AutoConfigURL -and ($Settings.AutoConfigURL -ilike $AutoConfigPattern)) {
                Write-CMLog "MATCH FOUND: AutoConfigURL `"$($Settings.AutoConfigURL)`" matches pattern `"$AutoConfigPattern`"" -Severity Warning -Component 'DetectionRule'
                $foundPattern = $true
            }

            # Additional logging if patterns found
            If ($foundPattern) {
                Write-CMLog "Pattern detected in DefaultConnectionSettings" -Severity Warning -Component 'DetectionRule'
            }
            else {
                Write-CMLog "No pattern matches found" -Component 'DetectionRule'
            }
        }
    }
    Catch {
        Write-CMLog "Error reading registry value: $($_.Exception.Message)" -Severity Error -Component 'RegistryCheck'
        Write-CMLog "Assuming compliant due to error" -Severity Warning -Component 'DetectionRule'
    }
}
else {
    Write-CMLog "Registry path not found: $RegistryPath" -Severity Warning -Component 'RegistryCheck'
    Write-CMLog "Assuming compliant - no settings to check" -Component 'DetectionRule'
}

# Return compliance status
if ($foundPattern) {
    Write-CMLog "RESULT: Not Compliant - Pattern found in proxy settings" -Severity Warning -Component 'Cleanup'
    Return 1
}
else {
    Write-CMLog "RESULT: Compliant - No pattern matches found" -Component 'Cleanup'
    Return 0
}
