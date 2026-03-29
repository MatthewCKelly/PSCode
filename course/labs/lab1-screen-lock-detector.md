# Lab 1: Build a Screen Lock Monitor

## 🎯 Objective

Build a practical PowerShell script that monitors screen lock status and logs the activity. This lab reinforces everything from Module 1 (Foundations) and Module 2 (Logging).

**Time Required:** 60-90 minutes
**Difficulty:** ⭐ Beginner
**Prerequisites:** Lessons 1.1-1.4, 2.1-2.2

---

## 📋 Requirements

Create a script called `Monitor-ScreenLock.ps1` that:

### Functional Requirements

1. **Checks screen lock status** every 5 seconds
2. **Logs state changes** (locked ↔ unlocked)
3. **Records timestamps** for each change
4. **Calculates lock duration** when screen is unlocked
5. **Exports to CSV** with daily log files
6. **Runs continuously** until user presses Ctrl+C
7. **Handles errors gracefully**

### Technical Requirements

1. **Use the Write-Detail function** for console logging
2. **Accept parameters** for check interval and log path
3. **Validate parameters** (interval must be > 0)
4. **Use try-catch blocks** for error handling
5. **Export CSV with proper headers**
6. **Show summary on exit**

---

## 🏗️ Starter Code

Create `Monitor-ScreenLock.ps1` and start with this template:

```powershell
<#
.SYNOPSIS
    Monitors Windows screen lock status and logs activity
.DESCRIPTION
    Continuously checks if the screen is locked and logs state changes
    to both console and CSV file. Useful for tracking workstation activity.
.PARAMETER CheckIntervalSeconds
    How often to check lock status (default: 5 seconds)
.PARAMETER LogPath
    Directory to store log files (default: current directory)
.EXAMPLE
    .\Monitor-ScreenLock.ps1
    Run with default settings
.EXAMPLE
    .\Monitor-ScreenLock.ps1 -CheckIntervalSeconds 10 -LogPath "C:\Logs"
    Check every 10 seconds and log to C:\Logs
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
    # TODO: Implement the Write-Detail function from the repository
    # Hint: Look at Add-WeektoSignature.ps1 line ~150
}

Function Test-ScreenLock {
    # TODO: Implement the screen lock detection
    # Hint: Look at isScreenLocked script
}

Function Export-LockEvent {
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

    # TODO: Export to CSV
    # CSV Format: Timestamp, Status, DurationSeconds
}

#endregion

#region Main Execution

Write-Detail "Screen Lock Monitor starting..." -Level Info
Write-Detail "Check interval: $CheckIntervalSeconds seconds" -Level Info
Write-Detail "Log path: $LogPath" -Level Info
Write-Detail "Press Ctrl+C to stop monitoring" -Level Info
Write-Host ""

# TODO: Implement the monitoring loop
# Hints:
# - Track previous state to detect changes
# - Track lock time to calculate duration
# - Handle Ctrl+C gracefully with try-finally
# - Show summary statistics on exit

#endregion
```

---

## 📝 Step-by-Step Guide

### Step 1: Implement Write-Detail Function

Copy the `Write-Detail` function from any script in the repository (e.g., `Add-WeektoSignature.ps1` around line 150).

**Verify:** Run your script and confirm colored output works:
```powershell
.\Monitor-ScreenLock.ps1
```

### Step 2: Implement Test-ScreenLock Function

Base this on the `isScreenLocked` script, but return a simple boolean:

```powershell
Function Test-ScreenLock {
    $processes = Get-Process | Where-Object { $_.ProcessName -eq "LogonUI" }
    return ($null -ne $processes -and $processes.Count -gt 0)
}
```

**Verify:** Test the function:
```powershell
Test-ScreenLock
# Should return True or False
```

### Step 3: Implement CSV Export Function

```powershell
Function Export-LockEvent {
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

    # Export to CSV (append if file exists)
    $logEntry | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
}
```

**Verify:** Test the function:
```powershell
$testPath = "test-log.csv"
Export-LockEvent -LogFilePath $testPath -Timestamp (Get-Date) -Status "Locked"
Get-Content $testPath
```

### Step 4: Set Up the Monitoring Loop Variables

```powershell
# Generate log filename with today's date
$logFileName = "ScreenLock_$(Get-Date -Format 'yyyy-MM-dd').csv"
$logFilePath = Join-Path $LogPath $logFileName

Write-Detail "Log file: $logFilePath" -Level Info
Write-Host ""

# Initialize tracking variables
$previousState = $null
$lockStartTime = $null
$lockCount = 0
$unlockCount = 0
$totalLockTime = [timespan]::Zero
```

### Step 5: Implement the Monitoring Loop

```powershell
try {
    while ($true) {
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
                $duration = $timestamp - $lockStartTime
                $totalLockTime += $duration
                Write-Detail "🔓 Screen UNLOCKED (was locked for $($duration.ToString('hh\:mm\:ss')))" -Level Success
                Export-LockEvent -LogFilePath $logFilePath -Timestamp $timestamp -Status "Unlocked" -Duration $duration
                $lockStartTime = $null
            }
        }

        $previousState = $currentState
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}
catch {
    Write-Detail "Error in monitoring loop: $($_.Exception.Message)" -Level Error
}
finally {
    # Show summary on exit
    Write-Host ""
    Write-Detail "=" * 50 -Level Info
    Write-Detail "Monitoring stopped" -Level Info
    Write-Detail "Lock events: $lockCount" -Level Info
    Write-Detail "Unlock events: $unlockCount" -Level Info
    Write-Detail "Total lock time: $($totalLockTime.ToString('hh\:mm\:ss'))" -Level Info
    Write-Detail "Log file: $logFilePath" -Level Info
    Write-Detail "=" * 50 -Level Info
}
```

---

## 🧪 Testing Your Script

### Test 1: Basic Functionality

```powershell
# Start monitoring
.\Monitor-ScreenLock.ps1

# Expected output:
# Screen Lock Monitor starting...
# Check interval: 5 seconds
# Log path: .
# Press Ctrl+C to stop monitoring
```

### Test 2: Detect Lock/Unlock

1. Let the script run for a few checks (should show nothing if unlocked)
2. Press `Win + L` to lock your screen
3. Wait 5+ seconds
4. Unlock your screen
5. Observe the console output - should show:
   ```
   🔒 Screen LOCKED
   🔓 Screen UNLOCKED (was locked for 00:00:15)
   ```

### Test 3: CSV Logging

```powershell
# Stop the script (Ctrl+C)
# Check the CSV file
Get-Content .\ScreenLock_2026-03-29.csv

# Expected:
# Timestamp,Status,DurationSeconds
# "2026-03-29 14:30:15","Locked",0
# "2026-03-29 14:30:30","Unlocked",15
```

### Test 4: Custom Parameters

```powershell
# Test with custom interval
.\Monitor-ScreenLock.ps1 -CheckIntervalSeconds 10 -LogPath "C:\Temp"
```

### Test 5: Error Handling

```powershell
# Try invalid parameters
.\Monitor-ScreenLock.ps1 -CheckIntervalSeconds 0
# Should show validation error

.\Monitor-ScreenLock.ps1 -LogPath "C:\NonExistent"
# Should show validation error
```

---

## 🏆 Success Criteria

Your script passes if:

- ✅ Starts without errors
- ✅ Correctly detects screen lock state
- ✅ Logs lock events to console with colors
- ✅ Logs unlock events with duration
- ✅ Creates CSV file with proper format
- ✅ Shows summary statistics on exit
- ✅ Handles Ctrl+C gracefully (finally block)
- ✅ Validates parameters correctly
- ✅ Follows PowerShell best practices (approved verbs, proper naming)

---

## 🌟 Extension Challenges

Want to go further? Try these enhancements:

### Challenge 1: Daily Statistics Report
Generate a summary report at midnight showing:
- Total lock events for the day
- Longest lock duration
- Average lock duration
- First lock time, last lock time

### Challenge 2: Email Notifications
Send an email if screen has been locked for over 1 hour:
```powershell
# Hint: Use Send-MailMessage cmdlet
```

### Challenge 3: GUI Dashboard
Create a Windows Forms GUI showing:
- Real-time lock status (red/green indicator)
- Today's statistics
- Recent events list
- Start/Stop button

### Challenge 4: Multiple Machine Monitoring
Modify to monitor multiple computers:
```powershell
# Hint: Use Invoke-Command with -ComputerName parameter
```

### Challenge 5: Break Reminder
Popup a reminder if user hasn't locked screen in 2 hours (ergonomic break reminder).

---

## 💡 Hints & Tips

### Hint 1: Detecting First Run
```powershell
if ($null -eq $previousState) {
    # First check - don't log yet, just initialize
    $previousState = $currentState
    continue
}
```

### Hint 2: Handling Midnight Rollover
```powershell
# Check if date changed
$currentDate = (Get-Date).Date
if ($currentDate -ne $logDate) {
    # Start new log file
    $logFileName = "ScreenLock_$(Get-Date -Format 'yyyy-MM-dd').csv"
    $logFilePath = Join-Path $LogPath $logFileName
    $logDate = $currentDate
}
```

### Hint 3: Better Duration Formatting
```powershell
if ($duration.TotalHours -ge 1) {
    $durationStr = $duration.ToString('hh\:mm\:ss')
} else {
    $durationStr = $duration.ToString('mm\:ss')
}
```

---

## 📊 Example Output

```
2026-03-29 14:25:10 [INFO] Line 45: Screen Lock Monitor starting...
2026-03-29 14:25:10 [INFO] Line 46: Check interval: 5 seconds
2026-03-29 14:25:10 [INFO] Line 47: Log path: .
2026-03-29 14:25:10 [INFO] Line 48: Press Ctrl+C to stop monitoring

2026-03-29 14:25:30 [WARNING] Line 78: 🔒 Screen LOCKED
2026-03-29 14:26:15 [SUCCESS] Line 84: 🔓 Screen UNLOCKED (was locked for 00:00:45)
2026-03-29 14:30:05 [WARNING] Line 78: 🔒 Screen LOCKED
2026-03-29 14:30:20 [SUCCESS] Line 84: 🔓 Screen UNLOCKED (was locked for 00:00:15)

^C
==================================================
2026-03-29 14:35:10 [INFO] Line 105: Monitoring stopped
2026-03-29 14:35:10 [INFO] Line 106: Lock events: 2
2026-03-29 14:35:10 [INFO] Line 107: Unlock events: 2
2026-03-29 14:35:10 [INFO] Line 108: Total lock time: 00:01:00
2026-03-29 14:35:10 [INFO] Line 109: Log file: .\ScreenLock_2026-03-29.csv
==================================================
```

---

## 🎓 What You Learned

By completing this lab, you've practiced:

✅ **Script structure** - Proper header, parameters, functions, main execution
✅ **Parameter validation** - ValidateRange, ValidateScript
✅ **Functions** - Verb-Noun naming, parameter blocks
✅ **Logging** - Write-Detail with different levels
✅ **Error handling** - Try-catch-finally blocks
✅ **File I/O** - CSV export with Export-Csv
✅ **Loops** - Infinite while loop with sleep
✅ **State tracking** - Detecting changes between checks
✅ **Time calculations** - Timespans and durations
✅ **Console output** - Colored text with emojis
✅ **Cleanup code** - Finally blocks for graceful exit

---

## 📤 Submit Your Work

If you're doing this course with others, share your solution:

```powershell
# Create a branch for your solution
git checkout -b lab1/[your-name]

# Add your script
git add Monitor-ScreenLock.ps1

# Commit
git commit -m "Complete Lab 1: Screen Lock Monitor"

# Push (if in a shared repo)
git push origin lab1/[your-name]
```

---

## 🔗 Solution

A reference solution is available at: [solutions/lab1-solution.ps1](../solutions/lab1-solution.ps1)

**But try it yourself first!** You learn more from struggling and solving problems than from reading solutions.

---

## 🚀 Next Steps

**Completed the lab?** Great! Move on to:

- **Module 3:** [Configuration Management](../lessons/03-config/README.md)
- **Lab 2:** [Implement Logging](./lab2-implement-logging.md)
- **Challenge:** Try the extension challenges above

---

**Lab Complete! 🎉**

You've built your first real-world PowerShell monitoring tool. These patterns will appear in almost every script you write from now on!
