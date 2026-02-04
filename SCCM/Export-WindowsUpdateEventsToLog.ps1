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

    Event logs collected:
    - Microsoft-Windows-WindowsUpdateClient/Operational
    - Microsoft-Windows-UpdateOrchestrator/Operational
    - Microsoft-Windows-SetupDiag/Operational
    - Microsoft-Windows-DeliveryOptimization/Operational

.PARAMETER DaysBack
    Number of days to look back for events. Default is 2.

.PARAMETER OutputPath
    Directory to write log files. Default is C:\Windows\CCM\Logs

.PARAMETER LogPrefix
    Prefix for log file names. Default is "WinUpdate"

.PARAMETER IncludeAllEvents
    Include all event IDs, not just the filtered important ones.

.EXAMPLE
    .\Export-WindowsUpdateEventsToLog.ps1
    Exports last 2 days of Windows Update events to C:\Windows\CCM\Logs

.EXAMPLE
    .\Export-WindowsUpdateEventsToLog.ps1 -DaysBack 7 -OutputPath "C:\Logs"
    Exports last 7 days of events to C:\Logs directory

.EXAMPLE
    .\Export-WindowsUpdateEventsToLog.ps1 -IncludeAllEvents
    Exports all events, not just the filtered important event IDs

.NOTES
    Requires administrative privileges to read certain event logs.
    Output files are compatible with CMTrace.exe log viewer.

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
    [switch]$IncludeAllEvents
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
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Events,

        [Parameter(Mandatory = $true)]
        [string]$LogFile,

        [Parameter(Mandatory = $true)]
        [string]$Component
    )

    if ($Events.Count -eq 0) {
        Write-Detail "No events to export for $Component" -Level Debug
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

#endregion Helper Functions

#region Main Script

Write-Host ""
Write-Detail "Windows Update Events to CM Log Exporter" -Level Info
Write-Detail ("=" * 60) -Level Info
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

# Calculate start time
$startTime = (Get-Date).AddDays(-$DaysBack)
Write-Detail "Collecting events from: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level Info
Write-Detail "Output directory: $OutputPath" -Level Info
Write-Host ""

# Define event log configurations
$eventLogConfigs = @(
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

# Track totals
$totalEvents = 0
$logFiles = @()

# Process each event log
foreach ($config in $eventLogConfigs) {
    Write-Detail "Processing: $($config.Description)" -Level Info

    # Build filter hashtable
    $filter = @{
        LogName = $config.LogName
        StartTime = $startTime
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

        # Remove existing file to start fresh
        if (Test-Path $logFilePath) {
            Remove-Item $logFilePath -Force
        }

        # Export events
        $count = Export-EventsToLog -Events $events -LogFile $logFilePath -Component $config.Component

        Write-Detail "  Exported $count events to $logFileName" -Level Success
        $totalEvents += $count
        $logFiles += $logFilePath
    }
    else {
        Write-Detail "  No events found" -Level Debug
    }
}

Write-Host ""
Write-Detail ("=" * 60) -Level Info

# Create combined log file
if ($logFiles.Count -gt 0) {
    $combinedLogPath = Join-Path $OutputPath "$($LogPrefix)_Combined.log"

    Write-Detail "Creating combined log file..." -Level Info

    # Remove existing combined file
    if (Test-Path $combinedLogPath) {
        Remove-Item $combinedLogPath -Force
    }

    # Collect all events from all sources for combined file
    $allEvents = @()

    foreach ($config in $eventLogConfigs) {
        $filter = @{
            LogName = $config.LogName
            StartTime = $startTime
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
                Message = $event.Message
                LevelDisplayName = $event.LevelDisplayName
                ProcessId = $event.ProcessId
                Component = $config.Component
            }
        }
    }

    # Sort all events by time and write to combined file
    $sortedAllEvents = $allEvents | Sort-Object TimeCreated

    foreach ($event in $sortedAllEvents) {
        $message = "[$($event.Component)] [EventID: $($event.Id)] $($event.Message)"
        $logType = ConvertTo-CMLogType -Level $event.LevelDisplayName

        Write-CMLogEntry -Message $message `
                         -LogFile $combinedLogPath `
                         -Component $event.Component `
                         -Type $logType `
                         -Thread $event.ProcessId `
                         -EventTime $event.TimeCreated
    }

    Write-Detail "Combined log created: $combinedLogPath" -Level Success
}

Write-Host ""
Write-Detail "Export complete!" -Level Success
Write-Detail "Total events exported: $totalEvents" -Level Info
Write-Detail "Log files created in: $OutputPath" -Level Info
Write-Host ""

# Display file list
if ($logFiles.Count -gt 0) {
    Write-Detail "Files created:" -Level Info
    foreach ($file in $logFiles) {
        $fileInfo = Get-Item $file
        Write-Detail "  - $(Split-Path $file -Leaf) ($([math]::Round($fileInfo.Length / 1KB, 2)) KB)" -Level Info
    }

    if (Test-Path $combinedLogPath) {
        $combinedInfo = Get-Item $combinedLogPath
        Write-Detail "  - $(Split-Path $combinedLogPath -Leaf) ($([math]::Round($combinedInfo.Length / 1KB, 2)) KB) [Combined]" -Level Info
    }
}

Write-Host ""
Write-Detail "Use CMTrace.exe to view these log files" -Level Info

#endregion Main Script
