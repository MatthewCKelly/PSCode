<#
.SYNOPSIS
    Monitors Windows screen lock status and logs activity
.DESCRIPTION
    Continuously checks if the screen is locked and logs state changes
    to both console and CSV file. Useful for tracking workstation activity.

    This is the reference solution for Lab 1: Screen Lock Monitor
.PARAMETER CheckIntervalSeconds
    How often to check lock status (default: 5 seconds)
.PARAMETER LogPath
    Directory to store log files (default: current directory)
.EXAMPLE
    .\lab1-solution.ps1
    Run with default settings
.EXAMPLE
    .\lab1-solution.ps1 -CheckIntervalSeconds 10 -LogPath "C:\Logs"
    Check every 10 seconds and log to C:\Logs
.NOTES
    Lab 1 Solution - Screen Lock Monitor
    Course: PowerShell Development Masterclass
    Module: 1 - Foundations
#>

param(
    [Parameter()]
    [ValidateRange(1, 3600)]
    [int]$CheckIntervalSeconds = 5,

    [Parameter()]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$LogPath = "."
)

#region Functions

Function Write-Detail {
    <#
    .SYNOPSIS
        Writes detailed log messages with timestamp, level, and line number
    .DESCRIPTION
        Standardized logging function used across all scripts
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$LogFile = $null
    )

    # Get timestamp and caller info
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $caller = (Get-PSCallStack)[1]
    $lineNumber = $caller.ScriptLineNumber

    # Build log entry
    $logEntry = "$timestamp [$Level] Line $lineNumber: $Message"

    # Color-coded console output based on level
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

Function Test-ScreenLock {
    <#
    .SYNOPSIS
        Checks if the Windows screen is currently locked
    .DESCRIPTION
        Detects screen lock by checking for the LogonUI.exe process
    .OUTPUTS
        Boolean - $true if locked, $false if unlocked
    #>

    $processes = Get-Process | Where-Object { $_.ProcessName -eq "LogonUI" }
    return ($null -ne $processes -and $processes.Count -gt 0)
}

Function Export-LockEvent {
    <#
    .SYNOPSIS
        Exports a lock/unlock event to CSV log file
    .DESCRIPTION
        Records screen lock state changes with timestamp and duration
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LogFilePath,

        [Parameter(Mandatory)]
        [datetime]$Timestamp,

        [Parameter(Mandatory)]
        [ValidateSet('Locked', 'Unlocked')]
        [string]$Status,

        [Parameter()]
        [timespan]$Duration = [timespan]::Zero
    )

    # Create object for export
    $logEntry = [PSCustomObject]@{
        Timestamp       = $Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        Status          = $Status
        DurationSeconds = [math]::Round($Duration.TotalSeconds, 2)
    }

    # Export to CSV (append if file exists, create if not)
    if (Test-Path $LogFilePath) {
        $logEntry | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
    }
    else {
        # First entry - creates file with headers
        $logEntry | Export-Csv -Path $LogFilePath -NoTypeInformation
        Write-Detail "Created new log file: $LogFilePath" -Level Info
    }
}

#endregion

#region Main Execution

Write-Detail "Screen Lock Monitor starting..." -Level Info
Write-Detail "Check interval: $CheckIntervalSeconds seconds" -Level Info
Write-Detail "Log path: $LogPath" -Level Info
Write-Detail "Press Ctrl+C to stop monitoring" -Level Info
Write-Host ""

# Generate log filename with today's date
$logFileName = "ScreenLock_$(Get-Date -Format 'yyyy-MM-dd').csv"
$logFilePath = Join-Path $LogPath $logFileName
$currentLogDate = (Get-Date).Date

Write-Detail "Log file: $logFilePath" -Level Info
Write-Host ""

# Initialize tracking variables
$previousState = $null
$lockStartTime = $null
$lockCount = 0
$unlockCount = 0
$totalLockTime = [timespan]::Zero

try {
    while ($true) {
        # Check if we need to start a new log file (date changed)
        $checkDate = (Get-Date).Date
        if ($checkDate -ne $currentLogDate) {
            Write-Detail "Date changed - starting new log file" -Level Info
            $logFileName = "ScreenLock_$(Get-Date -Format 'yyyy-MM-dd').csv"
            $logFilePath = Join-Path $LogPath $logFileName
            $currentLogDate = $checkDate
        }

        # Check current screen lock state
        $currentState = Test-ScreenLock

        # Detect state change
        if ($previousState -ne $currentState -and $null -ne $previousState) {
            $timestamp = Get-Date

            if ($currentState) {
                # Screen just locked
                $lockCount++
                $lockStartTime = $timestamp

                Write-Detail "🔒 Screen LOCKED" -Level Warning
                Export-LockEvent -LogFilePath $logFilePath -Timestamp $timestamp -Status "Locked"
            }
            else {
                # Screen just unlocked
                $unlockCount++

                if ($null -ne $lockStartTime) {
                    $duration = $timestamp - $lockStartTime
                    $totalLockTime += $duration

                    # Format duration nicely
                    if ($duration.TotalHours -ge 1) {
                        $durationStr = $duration.ToString('hh\:mm\:ss')
                    }
                    else {
                        $durationStr = $duration.ToString('mm\:ss')
                    }

                    Write-Detail "🔓 Screen UNLOCKED (was locked for $durationStr)" -Level Success
                    Export-LockEvent -LogFilePath $logFilePath -Timestamp $timestamp -Status "Unlocked" -Duration $duration
                }
                else {
                    # Shouldn't happen, but handle gracefully
                    Write-Detail "🔓 Screen UNLOCKED" -Level Success
                    Export-LockEvent -LogFilePath $logFilePath -Timestamp $timestamp -Status "Unlocked"
                }

                $lockStartTime = $null
            }
        }
        elseif ($null -eq $previousState) {
            # First check - just initialize
            Write-Detail "Initial state: $(if ($currentState) { 'LOCKED' } else { 'UNLOCKED' })" -Level Debug
        }

        $previousState = $currentState
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}
catch {
    Write-Detail "Error in monitoring loop: $($_.Exception.Message)" -Level Error
    Write-Detail "Stack trace: $($_.ScriptStackTrace)" -Level Debug
}
finally {
    # Show summary on exit (Ctrl+C or error)
    Write-Host ""
    Write-Detail ("=" * 80) -Level Info
    Write-Detail "Monitoring stopped" -Level Info

    # Calculate averages if we have data
    if ($lockCount -gt 0) {
        $avgLockTime = [timespan]::FromSeconds($totalLockTime.TotalSeconds / $lockCount)
        Write-Detail "Lock events: $lockCount" -Level Info
        Write-Detail "Unlock events: $unlockCount" -Level Info
        Write-Detail "Total lock time: $($totalLockTime.ToString('hh\:mm\:ss'))" -Level Info
        Write-Detail "Average lock duration: $($avgLockTime.ToString('mm\:ss'))" -Level Info
    }
    else {
        Write-Detail "No lock events recorded" -Level Info
    }

    Write-Detail "Log file: $logFilePath" -Level Info

    # Show recent events
    if (Test-Path $logFilePath) {
        Write-Detail "Last 5 events:" -Level Info
        $recentEvents = Import-Csv $logFilePath | Select-Object -Last 5

        foreach ($event in $recentEvents) {
            $statusIcon = if ($event.Status -eq "Locked") { "🔒" } else { "🔓" }
            if ($event.DurationSeconds -gt 0) {
                Write-Detail "  $statusIcon $($event.Timestamp) - $($event.Status) ($($event.DurationSeconds)s)" -Level Info
            }
            else {
                Write-Detail "  $statusIcon $($event.Timestamp) - $($event.Status)" -Level Info
            }
        }
    }

    Write-Detail ("=" * 80) -Level Info
}

#endregion
