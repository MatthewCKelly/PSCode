# Version 1.2.0 - 2026-02-05
# - Added -IncludeETL switch to include WindowsUpdate.log ETL traces (ComApi, Agent, etc.)
# - Added -ETLComponents parameter to filter specific ETL components
# - ETL log parsing via Get-WindowsUpdateLog for detailed WU internals
# Version 1.1.0 - 2026-02-04
# - Added administrator privilege check
# - Added event log existence validation before querying
# - Added -Monitor switch for continuous monitoring mode
# Version 1.0.0 - 2026-02-04
# - Initial release: Export Windows Update events to CM Log format
# - Supports WindowsUpdateClient, UpdateOrchestrator, SetupDiag, DeliveryOptimization logs
# - CMTrace compatible format for easy merging and viewing
# - Configurable lookback period and output directory

<#
.SYNOPSIS
    Exports Windows Update related events to CM Log format files.

.DESCRIPTION
    Collects events from Windows Update related event logs and exports them
    to CM Log format files in the SCCM logs directory. The CM Log format is
    compatible with CMTrace.exe for easy viewing and log merging.

    Event logs collected (if available on system):
    - Microsoft-Windows-WindowsUpdateClient/Operational
    - Microsoft-Windows-UpdateOrchestrator/Operational
    - Microsoft-Windows-SetupDiag/Operational
    - Microsoft-Windows-DeliveryOptimization/Operational
    - Microsoft-Windows-Bits-Client/Operational
    - Microsoft-Windows-CbsPreview/Operational

    ETL Log Components (via -IncludeETL):
    - ComApi - COM API calls (update searches, downloads, installs)
    - Agent - Windows Update Agent operations
    - Handler - Update handlers (CBS, MSI, etc.)
    - DownloadManager - Download operations
    - Setup - Setup/upgrade operations
    - And many more...

.PARAMETER DaysBack
    Number of days to look back for events. Default is 2.

.PARAMETER OutputPath
    Directory to write log files. Default is C:\Windows\CCM\Logs

.PARAMETER LogPrefix
    Prefix for log file names. Default is "WinUpdate"

.PARAMETER IncludeAllEvents
    Include all event IDs, not just the filtered important ones.

.PARAMETER IncludeETL
    Include Windows Update ETL traces (WindowsUpdate.log). This captures detailed
    internal WU operations including ComApi, Agent, Handler, etc.

.PARAMETER ETLComponents
    Filter ETL log to specific components. Default includes common components.
    Available: ComApi, Agent, Handler, DownloadManager, Setup, Misc, IdleTimer,
    Reporter, Service, SLS, EndpointProvider, WuTask, ProtocolTalker, etc.

.PARAMETER Monitor
    Run continuously, monitoring for new events. Press Ctrl+C to stop.

.PARAMETER PollIntervalSeconds
    Interval in seconds between polls when in Monitor mode. Default is 30.

.EXAMPLE
    .\Export-WindowsUpdateEventsToLog.ps1
    Exports last 2 days of Windows Update events to C:\Windows\CCM\Logs

.EXAMPLE
    .\Export-WindowsUpdateEventsToLog.ps1 -IncludeETL
    Includes ETL traces with ComApi, Agent, and Handler events

.EXAMPLE
    .\Export-WindowsUpdateEventsToLog.ps1 -IncludeETL -ETLComponents @('ComApi', 'Agent')
    Includes only ComApi and Agent ETL components

.EXAMPLE
    .\Export-WindowsUpdateEventsToLog.ps1 -DaysBack 7 -OutputPath "C:\Logs"
    Exports last 7 days of events to C:\Logs directory

.EXAMPLE
    .\Export-WindowsUpdateEventsToLog.ps1 -Monitor -IncludeETL
    Continuously monitors including ETL traces. Press Ctrl+C to stop.

.NOTES
    Requires administrative privileges to read certain event logs.
    Output files are compatible with CMTrace.exe log viewer.
    ETL processing requires Windows 10/Server 2016 or later.

.LINK
    https://docs.microsoft.com/en-us/mem/configmgr/core/support/cmtrace
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int]$DaysBack = 2,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "C:\Windows\CCM\Logs",

    [Parameter(Mandatory = $false)]
    [string]$LogPrefix = "WinUpdate",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAllEvents,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeETL,

    [Parameter(Mandatory = $false)]
    [string[]]$ETLComponents = @('ComApi', 'Agent', 'Handler', 'DownloadManager', 'Setup', 'Misc'),

    [Parameter(Mandatory = $false)]
    [switch]$Monitor,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 3600)]
    [int]$PollIntervalSeconds = 30
)

#region Helper Functions

function Write-Detail {
    <#
    .SYNOPSIS
        Writes formatted messages to console with log levels
    .DESCRIPTION
        Enhanced logging function that supports different log levels with color coding
        and timestamps for tracking progress
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $lineNumber = $MyInvocation.ScriptLineNumber

    $logEntry = "[{0}] {1,-7} {2,4} {3}" -f $timestamp, $Level, $lineNumber, $Message

    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor White -BackgroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Black -BackgroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Debug'   { Write-Host $logEntry -ForegroundColor Gray }
        default   { Write-Host $logEntry }
    }
}

function Test-Administrator {
    <#
    .SYNOPSIS
        Checks if the current user has administrator privileges
    .DESCRIPTION
        Returns $true if running as administrator, throws exception otherwise
    #>
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    if ($isAdmin -eq $true) {
        Write-Detail "Current user is an Administrator" -Level Success
        return $true
    }
    else {
        Write-Detail "Current user is not an Administrator" -Level Error
        Write-Detail "This script requires administrative privileges to read event logs." -Level Error
        Write-Detail "Please run PowerShell as Administrator and try again." -Level Info
        throw [System.Security.Principal.IdentityNotMappedException]::New("Current user is not an Administrator. Please run as Administrator.")
    }
}

function Test-EventLogExists {
    <#
    .SYNOPSIS
        Tests if an event log exists on the system
    .PARAMETER LogName
        The name of the event log to check
    .OUTPUTS
        Returns $true if the log exists, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogName
    )

    try {
        $null = Get-WinEvent -ListLog $LogName -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-GetWindowsUpdateLogAvailable {
    <#
    .SYNOPSIS
        Tests if Get-WindowsUpdateLog cmdlet is available
    #>
    try {
        $cmd = Get-Command Get-WindowsUpdateLog -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Write-CMLogEntry {
    <#
    .SYNOPSIS
        Writes a single entry to a CM Log format file
    .DESCRIPTION
        Creates log entries in the CM Log format that CMTrace.exe can read.
        Format: <![LOG[Message]LOG]!><time="HH:mm:ss.mmm+TZO" date="MM-DD-YYYY" component="Component" context="" type="1" thread="ThreadID" file="FileName">
    .PARAMETER Message
        The message text to write
    .PARAMETER LogFile
        Full path to the log file
    .PARAMETER Component
        Component name for the log entry
    .PARAMETER Type
        Log type: 1=Info, 2=Warning, 3=Error
    .PARAMETER Thread
        Thread ID (optional, defaults to current thread)
    .PARAMETER EventTime
        DateTime of the event (optional, defaults to current time)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [string]$Component = "WindowsUpdate",

        [Parameter(Mandatory = $false)]
        [ValidateSet(1, 2, 3)]
        [int]$Type = 1,

        [Parameter(Mandatory = $false)]
        [int]$Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId,

        [Parameter(Mandatory = $false)]
        [datetime]$EventTime = (Get-Date)
    )

    # Format time as HH:mm:ss.mmm
    $time = $EventTime.ToString("HH:mm:ss.fff")

    # Calculate timezone offset in minutes
    $tzOffset = [System.TimeZoneInfo]::Local.GetUtcOffset($EventTime).TotalMinutes
    $tzString = "{0:+0;-0}" -f $tzOffset

    # Format date as MM-DD-YYYY
    $date = $EventTime.ToString("MM-dd-yyyy")

    # Clean message - remove newlines and escape special characters
    $cleanMessage = $Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
    $cleanMessage = $cleanMessage -replace '\s+', ' '
    $cleanMessage = $cleanMessage.Trim()

    # Build the CM Log format entry
    $logEntry = "<![LOG[$cleanMessage]LOG]!><time=`"$time$tzString`" date=`"$date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"$Thread`" file=`"$($MyInvocation.ScriptName)`">"

    # Write to file
    try {
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Detail "Failed to write to log file: $($_.Exception.Message)" -Level Error
    }
}

function ConvertTo-CMLogType {
    <#
    .SYNOPSIS
        Converts Windows Event level to CM Log type
    .PARAMETER Level
        Windows Event level or LevelDisplayName
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Level
    )

    switch ($Level) {
        'Error'       { return 3 }
        'Warning'     { return 2 }
        'Critical'    { return 3 }
        'Information' { return 1 }
        'Verbose'     { return 1 }
        default       { return 1 }
    }
}

function Get-EventLogSafely {
    <#
    .SYNOPSIS
        Retrieves events from a Windows Event Log with error handling
    .DESCRIPTION
        Wraps Get-WinEvent with proper error handling for missing logs or no events
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$FilterHashtable,

        [Parameter(Mandatory = $false)]
        [int]$MaxEvents = 0
    )

    try {
        $params = @{
            FilterHashtable = $FilterHashtable
            ErrorAction = 'Stop'
        }

        if ($MaxEvents -gt 0) {
            $params['MaxEvents'] = $MaxEvents
        }

        $events = Get-WinEvent @params
        return $events
    }
    catch [System.Exception] {
        if ($_.Exception.Message -like "*No events were found*") {
            Write-Detail "No events found in $($FilterHashtable.LogName)" -Level Debug
            return @()
        }
        elseif ($_.Exception.Message -like "*could not be found*") {
            Write-Detail "Event log not found: $($FilterHashtable.LogName)" -Level Warning
            return @()
        }
        else {
            Write-Detail "Error reading $($FilterHashtable.LogName): $($_.Exception.Message)" -Level Error
            return @()
        }
    }
}

function Export-EventsToLog {
    <#
    .SYNOPSIS
        Exports a collection of events to a CM Log format file
    .PARAMETER Events
        Array of Windows Event objects
    .PARAMETER LogFile
        Full path to the output log file
    .PARAMETER Component
        Component name for the log entries
    .PARAMETER Append
        If true, appends to existing file instead of checking for duplicates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Events,

        [Parameter(Mandatory = $true)]
        [string]$LogFile,

        [Parameter(Mandatory = $true)]
        [string]$Component,

        [Parameter(Mandatory = $false)]
        [switch]$Append
    )

    if ($Events.Count -eq 0) {
        return 0
    }

    # Sort events by time
    $sortedEvents = $Events | Sort-Object TimeCreated

    $count = 0
    foreach ($event in $sortedEvents) {
        # Build message with Event ID prefix
        $message = "[EventID: $($event.Id)] $($event.Message)"

        # Determine log type based on event level
        $logType = ConvertTo-CMLogType -Level $event.LevelDisplayName

        # Write the entry
        Write-CMLogEntry -Message $message `
                         -LogFile $LogFile `
                         -Component $Component `
                         -Type $logType `
                         -Thread $event.ProcessId `
                         -EventTime $event.TimeCreated

        $count++
    }

    return $count
}

function Get-WindowsUpdateETLLog {
    <#
    .SYNOPSIS
        Retrieves and parses the Windows Update ETL log
    .DESCRIPTION
        Uses Get-WindowsUpdateLog to convert ETL traces to text, then parses the output.
        Returns parsed log entries with timestamp, component, PID, TID, and message.
    .PARAMETER StartTime
        Only return entries after this time
    .PARAMETER Components
        Filter to specific components (ComApi, Agent, Handler, etc.)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $false)]
        [string[]]$Components = @()
    )

    $entries = @()

    # Create temp file for log output
    $tempLogPath = Join-Path $env:TEMP "WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    try {
        Write-Detail "Generating WindowsUpdate.log from ETL traces..." -Level Info
        Write-Detail "This may take a moment..." -Level Debug

        # Run Get-WindowsUpdateLog (this can take a while)
        $null = Get-WindowsUpdateLog -LogPath $tempLogPath -ErrorAction Stop 2>&1

        if (-not (Test-Path $tempLogPath)) {
            Write-Detail "Failed to generate WindowsUpdate.log" -Level Warning
            return @()
        }

        Write-Detail "Parsing WindowsUpdate.log..." -Level Info

        # Read and parse the log file
        # Format: YYYY/MM/DD HH:MM:SS.fffffff PID  TID  Component       Message
        # Example: 2023/11/15 10:30:45.1234567 12345  6789  ComApi          Title=Feature update...

        $logContent = Get-Content $tempLogPath -ErrorAction Stop

        foreach ($line in $logContent) {
            # Skip empty lines and header lines
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match '^\s*$') { continue }

            # Parse the log line using regex
            # Format: YYYY/MM/DD HH:MM:SS.fffffff PID TID Component Message
            if ($line -match '^(\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(.*)$') {
                $timestampStr = $Matches[1]
                $pid = $Matches[2]
                $tid = $Matches[3]
                $component = $Matches[4]
                $message = $Matches[5]

                # Parse timestamp
                try {
                    # Convert from YYYY/MM/DD HH:MM:SS.fffffff format
                    $timestamp = [datetime]::ParseExact(
                        $timestampStr.Substring(0, 23),  # Trim to milliseconds
                        "yyyy/MM/dd HH:mm:ss.fff",
                        [System.Globalization.CultureInfo]::InvariantCulture
                    )
                }
                catch {
                    # Try alternative parsing
                    try {
                        $timestamp = Get-Date $timestampStr.Substring(0, 19)
                    }
                    catch {
                        continue  # Skip unparseable lines
                    }
                }

                # Filter by start time
                if ($timestamp -lt $StartTime) { continue }

                # Filter by components if specified
                if ($Components.Count -gt 0) {
                    $matchesComponent = $false
                    foreach ($comp in $Components) {
                        if ($component -like "*$comp*") {
                            $matchesComponent = $true
                            break
                        }
                    }
                    if (-not $matchesComponent) { continue }
                }

                # Create entry object
                $entries += [PSCustomObject]@{
                    TimeCreated = $timestamp
                    ProcessId = [int]$pid
                    ThreadId = [int]$tid
                    Component = $component
                    Message = $message
                    Source = "ETL"
                }
            }
        }

        Write-Detail "Found $($entries.Count) ETL entries matching criteria" -Level Info
    }
    catch {
        Write-Detail "Error processing ETL log: $($_.Exception.Message)" -Level Error
    }
    finally {
        # Clean up temp file
        if (Test-Path $tempLogPath) {
            Remove-Item $tempLogPath -Force -ErrorAction SilentlyContinue
        }
    }

    return $entries
}

function Export-ETLEventsToLog {
    <#
    .SYNOPSIS
        Exports ETL log entries to CM Log format file
    .PARAMETER Entries
        Array of parsed ETL log entries
    .PARAMETER LogFile
        Full path to the output log file
    .PARAMETER Append
        If true, appends to existing file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Entries,

        [Parameter(Mandatory = $true)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Append
    )

    if ($Entries.Count -eq 0) {
        return 0
    }

    # Sort by time
    $sortedEntries = $Entries | Sort-Object TimeCreated

    $count = 0
    foreach ($entry in $sortedEntries) {
        # Determine log type based on message content
        $logType = 1  # Default to Info
        if ($entry.Message -match 'error|fail|exception' -and $entry.Message -notmatch 'no error|success') {
            $logType = 3  # Error
        }
        elseif ($entry.Message -match 'warn') {
            $logType = 2  # Warning
        }

        # Write the entry
        Write-CMLogEntry -Message $entry.Message `
                         -LogFile $LogFile `
                         -Component $entry.Component `
                         -Type $logType `
                         -Thread $entry.ThreadId `
                         -EventTime $entry.TimeCreated

        $count++
    }

    return $count
}

function Get-ValidatedEventLogConfigs {
    <#
    .SYNOPSIS
        Returns event log configurations after validating which logs exist on the system
    #>
    [CmdletBinding()]
    param()

    # Define all possible event log configurations
    $allConfigs = @(
        @{
            Name = "WindowsUpdateClient"
            LogName = "Microsoft-Windows-WindowsUpdateClient/Operational"
            Component = "WUClient"
            EventIds = @(19, 20, 25, 26, 30, 31, 32, 43, 44)
            Description = "Windows Update Client events (download, install, reboot)"
        },
        @{
            Name = "UpdateOrchestrator"
            LogName = "Microsoft-Windows-UpdateOrchestrator/Operational"
            Component = "WUOrch"
            EventIds = @(115, 116, 121, 200, 201, 257, 258)
            Description = "Update Orchestrator events (scheduling, policies)"
        },
        @{
            Name = "SetupDiag"
            LogName = "Microsoft-Windows-SetupDiag/Operational"
            Component = "SetupDiag"
            EventIds = $null  # Get all events
            MaxEvents = 50
            Description = "Setup diagnostic events (upgrade analysis)"
        },
        @{
            Name = "DeliveryOptimization"
            LogName = "Microsoft-Windows-DeliveryOptimization/Operational"
            Component = "DO"
            EventIds = @(10000, 10001, 10003, 200, 201, 202, 203, 204)
            Description = "Delivery Optimization events (download sources, peers)"
        },
        @{
            Name = "BITS"
            LogName = "Microsoft-Windows-Bits-Client/Operational"
            Component = "BITS"
            EventIds = @(3, 4, 5, 59, 60, 61)
            Description = "Background Intelligent Transfer Service events"
        },
        @{
            Name = "CBS"
            LogName = "Microsoft-Windows-CbsPreview/Operational"
            Component = "CBS"
            EventIds = $null  # Get all events
            MaxEvents = 100
            Description = "Component Based Servicing events"
        }
    )

    # Validate which logs exist
    $validConfigs = @()
    Write-Detail "Checking available event logs..." -Level Info

    foreach ($config in $allConfigs) {
        if (Test-EventLogExists -LogName $config.LogName) {
            Write-Detail "  [OK] $($config.LogName)" -Level Success
            $validConfigs += $config
        }
        else {
            Write-Detail "  [--] $($config.LogName) (not available)" -Level Debug
        }
    }

    Write-Host ""
    Write-Detail "Found $($validConfigs.Count) of $($allConfigs.Count) event logs available" -Level Info

    return $validConfigs
}

#endregion Helper Functions

#region Main Script

Write-Host ""
Write-Detail "Windows Update Events to CM Log Exporter" -Level Info
Write-Detail ("=" * 60) -Level Info
Write-Host ""

# Check for administrator privileges
try {
    Test-Administrator | Out-Null
}
catch {
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host ""

# Validate output path
if (-not (Test-Path $OutputPath)) {
    Write-Detail "Creating output directory: $OutputPath" -Level Info
    try {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    catch {
        Write-Detail "Failed to create output directory: $($_.Exception.Message)" -Level Error
        exit 1
    }
}

# Get validated event log configurations
$eventLogConfigs = Get-ValidatedEventLogConfigs

# Check ETL availability if requested
$etlAvailable = $false
if ($IncludeETL) {
    Write-Host ""
    Write-Detail "Checking ETL log availability..." -Level Info
    if (Test-GetWindowsUpdateLogAvailable) {
        Write-Detail "  [OK] Get-WindowsUpdateLog cmdlet available" -Level Success
        Write-Detail "  ETL Components to capture: $($ETLComponents -join ', ')" -Level Info
        $etlAvailable = $true
    }
    else {
        Write-Detail "  [--] Get-WindowsUpdateLog not available (requires Windows 10/Server 2016+)" -Level Warning
        Write-Detail "  ETL traces will be skipped" -Level Warning
    }
}

if ($eventLogConfigs.Count -eq 0 -and -not $etlAvailable) {
    Write-Detail "No event logs or ETL sources are available. Exiting." -Level Error
    exit 1
}

Write-Host ""

# Calculate start time
$startTime = (Get-Date).AddDays(-$DaysBack)
Write-Detail "Collecting events from: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level Info
Write-Detail "Output directory: $OutputPath" -Level Info

if ($Monitor) {
    Write-Detail "Monitor mode: ENABLED (Poll interval: $PollIntervalSeconds seconds)" -Level Info
    Write-Detail "Press Ctrl+C to stop monitoring" -Level Warning
}

Write-Host ""

# Track ETL last processed time for monitor mode
$script:lastETLTime = $startTime

# Function to process events (used in both one-shot and monitor modes)
function Invoke-EventExport {
    param(
        [datetime]$FromTime,
        [switch]$Append,
        [switch]$SuppressNoEventsMessage
    )

    $totalEvents = 0
    $logFiles = @()

    # Process each event log
    foreach ($config in $eventLogConfigs) {
        if (-not $SuppressNoEventsMessage) {
            Write-Detail "Processing: $($config.Description)" -Level Info
        }

        # Build filter hashtable
        $filter = @{
            LogName = $config.LogName
            StartTime = $FromTime
        }

        # Add event ID filter unless getting all events or IncludeAllEvents is set
        if (-not $IncludeAllEvents -and $config.EventIds) {
            $filter['Id'] = $config.EventIds
        }

        # Get events
        $maxEvents = if ($config.MaxEvents) { $config.MaxEvents } else { 0 }
        $events = Get-EventLogSafely -FilterHashtable $filter -MaxEvents $maxEvents

        if ($events.Count -gt 0) {
            # Create log file path
            $logFileName = "{0}_{1}.log" -f $LogPrefix, $config.Name
            $logFilePath = Join-Path $OutputPath $logFileName

            # Remove existing file only if not appending
            if (-not $Append -and (Test-Path $logFilePath)) {
                Remove-Item $logFilePath -Force
            }

            # Export events
            $count = Export-EventsToLog -Events $events -LogFile $logFilePath -Component $config.Component -Append:$Append

            Write-Detail "  Exported $count events to $logFileName" -Level Success
            $totalEvents += $count
            if ($logFilePath -notin $logFiles) {
                $logFiles += $logFilePath
            }
        }
        elseif (-not $SuppressNoEventsMessage) {
            Write-Detail "  No events found" -Level Debug
        }
    }

    # Process ETL logs if enabled
    if ($etlAvailable -and $IncludeETL) {
        if (-not $SuppressNoEventsMessage) {
            Write-Detail "Processing: Windows Update ETL traces (ComApi, Agent, etc.)" -Level Info
        }

        $etlEntries = Get-WindowsUpdateETLLog -StartTime $FromTime -Components $ETLComponents

        if ($etlEntries.Count -gt 0) {
            # Group by component and create separate log files
            $groupedEntries = $etlEntries | Group-Object Component

            foreach ($group in $groupedEntries) {
                $componentName = $group.Name -replace '[^\w]', ''  # Clean component name
                $logFileName = "{0}_ETL_{1}.log" -f $LogPrefix, $componentName
                $logFilePath = Join-Path $OutputPath $logFileName

                # Remove existing file only if not appending
                if (-not $Append -and (Test-Path $logFilePath)) {
                    Remove-Item $logFilePath -Force
                }

                $count = Export-ETLEventsToLog -Entries $group.Group -LogFile $logFilePath -Append:$Append

                Write-Detail "  Exported $count ETL events to $logFileName" -Level Success
                $totalEvents += $count
                if ($logFilePath -notin $logFiles) {
                    $logFiles += $logFilePath
                }
            }
        }
        elseif (-not $SuppressNoEventsMessage) {
            Write-Detail "  No ETL events found" -Level Debug
        }
    }

    # Create/update combined log file
    if ($totalEvents -gt 0) {
        $combinedLogPath = Join-Path $OutputPath "$($LogPrefix)_Combined.log"

        if (-not $Append) {
            Write-Detail "Creating combined log file..." -Level Info

            # Remove existing combined file only if not appending
            if (Test-Path $combinedLogPath) {
                Remove-Item $combinedLogPath -Force
            }
        }

        # Collect all events from all sources for combined file
        $allEvents = @()

        foreach ($config in $eventLogConfigs) {
            $filter = @{
                LogName = $config.LogName
                StartTime = $FromTime
            }

            if (-not $IncludeAllEvents -and $config.EventIds) {
                $filter['Id'] = $config.EventIds
            }

            $maxEvents = if ($config.MaxEvents) { $config.MaxEvents } else { 0 }
            $events = Get-EventLogSafely -FilterHashtable $filter -MaxEvents $maxEvents

            foreach ($event in $events) {
                $allEvents += [PSCustomObject]@{
                    TimeCreated = $event.TimeCreated
                    Id = $event.Id
                    Message = "[EventID: $($event.Id)] $($event.Message)"
                    LevelDisplayName = $event.LevelDisplayName
                    ProcessId = $event.ProcessId
                    Component = $config.Component
                    Source = "EventLog"
                }
            }
        }

        # Add ETL events to combined log
        if ($etlAvailable -and $IncludeETL) {
            $etlEntries = Get-WindowsUpdateETLLog -StartTime $FromTime -Components $ETLComponents
            foreach ($entry in $etlEntries) {
                $allEvents += [PSCustomObject]@{
                    TimeCreated = $entry.TimeCreated
                    Id = 0
                    Message = $entry.Message
                    LevelDisplayName = "Information"
                    ProcessId = $entry.ThreadId
                    Component = $entry.Component
                    Source = "ETL"
                }
            }
        }

        # Sort all events by time and write to combined file
        $sortedAllEvents = $allEvents | Sort-Object TimeCreated

        foreach ($event in $sortedAllEvents) {
            $message = "[$($event.Component)] $($event.Message)"
            $logType = ConvertTo-CMLogType -Level $event.LevelDisplayName

            # Override log type for ETL based on content
            if ($event.Source -eq "ETL") {
                if ($event.Message -match 'error|fail|exception' -and $event.Message -notmatch 'no error|success') {
                    $logType = 3
                }
                elseif ($event.Message -match 'warn') {
                    $logType = 2
                }
            }

            Write-CMLogEntry -Message $message `
                             -LogFile $combinedLogPath `
                             -Component $event.Component `
                             -Type $logType `
                             -Thread $event.ProcessId `
                             -EventTime $event.TimeCreated
        }

        if (-not $Append) {
            Write-Detail "Combined log created: $combinedLogPath" -Level Success
        }
    }

    return @{
        TotalEvents = $totalEvents
        LogFiles = $logFiles
    }
}

# Initial export
$result = Invoke-EventExport -FromTime $startTime

Write-Host ""
Write-Detail ("=" * 60) -Level Info
Write-Host ""
Write-Detail "Initial export complete!" -Level Success
Write-Detail "Total events exported: $($result.TotalEvents)" -Level Info
Write-Detail "Log files created in: $OutputPath" -Level Info
Write-Host ""

# Display file list
$logFiles = $result.LogFiles
$combinedLogPath = Join-Path $OutputPath "$($LogPrefix)_Combined.log"

if ($logFiles.Count -gt 0) {
    Write-Detail "Files created:" -Level Info
    foreach ($file in $logFiles) {
        if (Test-Path $file) {
            $fileInfo = Get-Item $file
            Write-Detail "  - $(Split-Path $file -Leaf) ($([math]::Round($fileInfo.Length / 1KB, 2)) KB)" -Level Info
        }
    }

    if (Test-Path $combinedLogPath) {
        $combinedInfo = Get-Item $combinedLogPath
        Write-Detail "  - $(Split-Path $combinedLogPath -Leaf) ($([math]::Round($combinedInfo.Length / 1KB, 2)) KB) [Combined]" -Level Info
    }
}

Write-Host ""
Write-Detail "Use CMTrace.exe to view these log files" -Level Info

# Monitor mode - continuous polling
if ($Monitor) {
    Write-Host ""
    Write-Detail ("=" * 60) -Level Info
    Write-Detail "Entering monitor mode..." -Level Info
    Write-Detail "Polling every $PollIntervalSeconds seconds for new events" -Level Info
    if ($IncludeETL -and $etlAvailable) {
        Write-Detail "Note: ETL processing in monitor mode may have delays" -Level Warning
    }
    Write-Detail "Press Ctrl+C to stop" -Level Warning
    Write-Host ""

    # Track the last check time
    $lastCheckTime = Get-Date

    try {
        while ($true) {
            Start-Sleep -Seconds $PollIntervalSeconds

            $currentTime = Get-Date
            Write-Detail "Checking for new events since $($lastCheckTime.ToString('HH:mm:ss'))..." -Level Debug

            # Get events since last check
            $monitorResult = Invoke-EventExport -FromTime $lastCheckTime -Append -SuppressNoEventsMessage

            if ($monitorResult.TotalEvents -gt 0) {
                Write-Detail "Added $($monitorResult.TotalEvents) new events to logs" -Level Success
            }

            $lastCheckTime = $currentTime
        }
    }
    catch {
        # Ctrl+C or other interruption
        Write-Host ""
        Write-Detail "Monitor mode stopped" -Level Info
    }
    finally {
        Write-Host ""
        Write-Detail "Monitoring ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
    }
}

#endregion Main Script
