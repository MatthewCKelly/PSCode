<#
.SYNOPSIS
    Manages Outlook signature with dynamic work location status table
.DESCRIPTION
    PowerShell script with Windows Forms GUI to update Outlook signature files (HTML and TXT)
    with work status for upcoming days. Features include optional today's status, configurable 
    number of days (1-14), AM/PM split mode, signature backup in registry and file system, 
    removal of MSO-specific tags, table width limited to 400px, HTML preview with copy support,
    and persistent configuration storage in registry.
.PARAMETER
    No parameters accepted - operates with GUI form interaction
.INPUTS
    User selections via Windows Forms dropdowns for each day's AM/PM status
    Number of days to display (1-14)
    Option to include today's status
    Split AM/PM mode toggle
.OUTPUTS
    Updated signature files in Outlook signature directory
    Console logging via Write-Detail
    Exit code 0 on success, 1 on error
.EXAMPLE
    .\Add-WeektoSignature.ps1
    Launches GUI form for weekly status configuration
.NOTES
    Author: Claude AI
    Version: 2.4.1
    Requires: PowerShell 5.0+, .NET Framework for Windows Forms
    Registry: HKCU\Software\OutlookSignatureManager
    Configuration: Number of days and today's status preference stored in registry
.VERSION
    2.0 - Added dynamic day selection, today's status option, configuration persistence,
          HTML preview copy support, and improved body tag handling
    2.1 - Added panel with autosize for the day dropdowns. controls below bound to that.
    2.2 - Fixed form layout positioning, added up/down buttons for table positioning,
          fixed text signature duplication, added comprehensive memory cleanup with
          try-finally blocks, improved Update-FormLayout function
    2.3 - Enabled vertical form resizing, removed scrollbars, repositioned move buttons
          to right of each preview section, fixed text-only view to show clean text
          without HTML entities, dynamic height allocation for preview areas
    2.3.1 - Fixed text output generation to use plain text directly instead of HTML
            conversion, properly formats each day on separate line with clean status
    2.4 - Added registry persistence for weekly selections and split mode preference
          Selections are now saved when Apply is clicked and restored on next launch
          Form height automatically adjusts to ensure all buttons are visible
          Fixed form cut-off issues with bottom buttons
    2.4.1 - Fixed parameter type error in Set-SignatureConfig function
            Changed WeeklySelections parameter from [hashtable] to [array] to match actual data type
#>

#region Initialization and Global Variables

# Load required assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Registry path for storing configuration and last known signature file name
$regPath = "HKCU:\Software\OutlookSignatureManager"
$regValueName = "LastSignatureFile"
$regNumDaysValue = "NumberOfDays"
$regIncludeTodayValue = "IncludeToday"
$regWeeklySelectionsValue = "WeeklySelections"
$regSplitModeValue = "SplitMode"

# Backup directory in roaming appdata
$backupPath = "$env:APPDATA\OutlookSignatureManager\Backups"

# Registry property suffix for signature lists
$script:sigListSuffix = "_roaming_signature_list"

# Layout spacing constants
$script:rowHeight = 35          # Height for single row (full day mode)
$script:labelToControlGap = 25  # Gap between day label and AM/PM controls in split mode

# Global status options and display mapping
$script:statusOptions = @('Office', 'WFH', 'Leave', 'Meeting', 'Training', 'Travel', 'Client Site')

# HTML display with emoji HTML entities
$script:statusMap = @{
    'Office' = '&#127970; Office'
    'WFH' = '&#127968; WFH'
    'Leave' = '&#127796; Leave'
    'Meeting' = '&#128101; Meeting'
    'Training' = '&#128218; Training'
    'Travel' = '&#9992; Travel'
    'Client Site' = '&#127970; Client Site'
}

# Plain text display without HTML entities
$script:statusMapText = @{
    'Office' = 'Office'
    'WFH' = 'WFH'
    'Leave' = 'Leave'
    'Meeting' = 'Meeting'
    'Training' = 'Training'
    'Travel' = 'Travel'
    'Client Site' = 'Client Site'
}

# Default configuration values
$script:defaultNumDays = 5
$script:defaultIncludeToday = $false

# Table position tracking (number of lines to move up from bottom)
$script:tablePosition = 0  # 0 = at bottom, positive = lines up from bottom

#endregion Initialization and Global Variables

#region Global Functions

# Define Write-Detail function for consistent logging
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
} # end of Write-Detail function

#endregion Global Functions

#region Configuration Functions

# Function to load configuration from registry
Function Get-SignatureConfig {
    Write-Detail -Message "Loading configuration from registry" -Level Debug

    try {
        if (-not (Test-Path $regPath)) {
            Write-Detail -Message "No configuration found, using defaults" -Level Debug
            return @{
                NumDays = $script:defaultNumDays
                IncludeToday = $script:defaultIncludeToday
                SplitMode = $false
                WeeklySelections = $null
            }
        }

        $numDays = (Get-ItemProperty -Path $regPath -Name $regNumDaysValue -ErrorAction SilentlyContinue).$regNumDaysValue
        $includeToday = (Get-ItemProperty -Path $regPath -Name $regIncludeTodayValue -ErrorAction SilentlyContinue).$regIncludeTodayValue
        $splitMode = (Get-ItemProperty -Path $regPath -Name $regSplitModeValue -ErrorAction SilentlyContinue).$regSplitModeValue
        $weeklySelectionsJson = (Get-ItemProperty -Path $regPath -Name $regWeeklySelectionsValue -ErrorAction SilentlyContinue).$regWeeklySelectionsValue

        # Use defaults if values not found
        if ($null -eq $numDays) { $numDays = $script:defaultNumDays }
        if ($null -eq $includeToday) { $includeToday = $script:defaultIncludeToday }
        if ($null -eq $splitMode) { $splitMode = $false }

        # Parse weekly selections from JSON
        $weeklySelections = $null
        if ($weeklySelectionsJson) {
            try {
                $weeklySelections = $weeklySelectionsJson | ConvertFrom-Json
                Write-Detail -Message "Loaded weekly selections from registry" -Level Debug
            } catch {
                Write-Detail -Message "Failed to parse weekly selections: $($_.Exception.Message)" -Level Warning
            }
        }

        Write-Detail -Message "Configuration loaded: NumDays=$numDays, IncludeToday=$includeToday, SplitMode=$splitMode" -Level Info

        return @{
            NumDays = $numDays
            IncludeToday = $includeToday
            SplitMode = $splitMode
            WeeklySelections = $weeklySelections
        }

    } catch {
        Write-Detail -Message "Failed to load configuration: $($_.Exception.Message)" -Level Warning
        return @{
            NumDays = $script:defaultNumDays
            IncludeToday = $script:defaultIncludeToday
            SplitMode = $false
            WeeklySelections = $null
        }
    }
} # end of Get-SignatureConfig function

# Function to save configuration to registry
Function Set-SignatureConfig {
    param(
        [int]$NumDays,
        [bool]$IncludeToday,
        [bool]$SplitMode,
        [array]$WeeklySelections
    )

    Write-Detail -Message "Saving configuration to registry: NumDays=$NumDays, IncludeToday=$IncludeToday, SplitMode=$SplitMode" -Level Debug

    try {
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
            Write-Detail -Message "Created registry key: $regPath" -Level Debug
        }

        Set-ItemProperty -Path $regPath -Name $regNumDaysValue -Value $NumDays
        Set-ItemProperty -Path $regPath -Name $regIncludeTodayValue -Value ([int]$IncludeToday)
        Set-ItemProperty -Path $regPath -Name $regSplitModeValue -Value ([int]$SplitMode)

        # Save weekly selections as JSON
        if ($WeeklySelections) {
            $weeklySelectionsJson = $WeeklySelections | ConvertTo-Json -Compress
            Set-ItemProperty -Path $regPath -Name $regWeeklySelectionsValue -Value $weeklySelectionsJson
            Write-Detail -Message "Saved weekly selections to registry" -Level Debug
        }

        Write-Detail -Message "Configuration saved successfully" -Level Info
        return $true

    } catch {
        Write-Detail -Message "Failed to save configuration: $($_.Exception.Message)" -Level Error
        return $false
    }
} # end of Set-SignatureConfig function

#endregion Configuration Functions

#region Outlook Helper Functions

# Function to get Outlook signature path
Function Get-OutlookSignaturePath {
    Write-Detail -Message "Locating Outlook signature directory" -Level Debug
    
    # Check common Outlook signature locations
    $signaturePath = "$env:APPDATA\Microsoft\Signatures"
    
    if (Test-Path $signaturePath) {
        Write-Detail -Message "Signature path found: $signaturePath" -Level Info
        return $signaturePath
    } else {
        Write-Detail -Message "Signature path not found" -Level Error
        return $null
    }
} # end of Get-OutlookSignaturePath function

# Function to get current user's email account (UPN)
Function Get-OutlookUserAccount {
    Write-Detail -Message "Retrieving Outlook user account (UPN)" -Level Debug
    
    try {
        # Method 1: Check Outlook Profiles for account information
        $profilesBasePath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\Outlook"
        
        if (Test-Path $profilesBasePath) {
            # Look for account keys under profiles
            $accountKeys = Get-ChildItem -Path $profilesBasePath -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { $_.PSChildName -match '^[0-9a-fA-F]{32}$' }
            
            foreach ($key in $accountKeys) {
                # Try to get Account Name or Email property
                $accountName = (Get-ItemProperty -Path $key.PSPath -Name "Account Name" -ErrorAction SilentlyContinue).'Account Name'
                
                if ($accountName) {
                    if ($accountName -is [byte[]]) {
                        $accountName = [System.Text.Encoding]::Unicode.GetString($accountName) -replace '\x00', ''
                    }
                    
                    # Check if it looks like an email address
                    if ($accountName -match '^[^@]+@[^@]+\.[^@]+$') {
                        Write-Detail -Message "Found account email: $accountName" -Level Info
                        return $accountName
                    }
                }
                
                # Try Email property
                $email = (Get-ItemProperty -Path $key.PSPath -Name "Email" -ErrorAction SilentlyContinue).'Email'
                if ($email) {
                    if ($email -is [byte[]]) {
                        $email = [System.Text.Encoding]::Unicode.GetString($email) -replace '\x00', ''
                    }
                    
                    if ($email -match '^[^@]+@[^@]+\.[^@]+$') {
                        Write-Detail -Message "Found account email: $email" -Level Info
                        return $email
                    }
                }
            } # end of foreach account key loop
        }
        
        # Method 2: Check Outlook Settings Data for account info
        $settingsPath = "HKCU:\Software\Microsoft\Office\Outlook\Settings\Data"
        if (Test-Path $settingsPath) {
            $properties = Get-Item -Path $settingsPath | Select-Object -ExpandProperty Property
            
            # Look for properties that look like email addresses with _roaming_signature_list
            $emailPattern = "^([^@]+@[^@]+\.[^@]+)$([regex]::Escape($script:sigListSuffix))$"
            $emailProps = $properties | Where-Object { $_ -match $emailPattern }
            
            if ($emailProps.Count -gt 0) {
                # Extract email from property name
                $emailProps[0] -match $emailPattern | Out-Null
                $email = $matches[1]
                Write-Detail -Message "Found account email from settings: $email" -Level Info
                return $email
            }
        }
        
        # Method 3: Try to get from environment or whoami
        $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ($username -match '@') {
            Write-Detail -Message "Using Windows identity: $username" -Level Info
            return $username
        }
        
        Write-Detail -Message "Could not determine user account email" -Level Warning
        return $null
        
    } catch {
        Write-Detail -Message "Error retrieving user account: $($_.Exception.Message)" -Level Error
        return $null
    }
} # end of Get-OutlookUserAccount function

# Function to get default signature name from registry
Function Get-DefaultSignatureName {
    param([string]$userAccount)
    
    Write-Detail -Message "Retrieving default signature name for account: $userAccount" -Level Debug
    
    try {
        # Method 1: Try newer Outlook Settings with JSON data using UPN
        if ($userAccount) {
            $settingsPath = "HKCU:\Software\Microsoft\Office\Outlook\Settings\Data"
            if (Test-Path $settingsPath) {
                Write-Detail -Message "Checking Outlook Settings for signature data" -Level Debug
                
                # Look for UPN-specific property
                $sigListProp = "$userAccount$script:sigListSuffix"
                
                try {
                    $jsonData = (Get-ItemProperty -Path $settingsPath -Name $sigListProp -ErrorAction SilentlyContinue).$sigListProp
                    
                    if ($jsonData) {
                        Write-Detail -Message "Found signature list for $userAccount" -Level Debug
                        
                        # Parse JSON data
                        $sigData = $jsonData | ConvertFrom-Json
                        
                        # Look for default signature in JSON
                        if ($sigData.defaultNew) {
                            Write-Detail -Message "Default signature from JSON: $($sigData.defaultNew)" -Level Info
                            return $sigData.defaultNew
                        }
                        
                        # If no default but has signatures, return first one
                        if ($sigData.signatures -and $sigData.signatures.Count -gt 0) {
                            $firstSig = $sigData.signatures[0].name
                            Write-Detail -Message "Using first signature from JSON: $firstSig" -Level Info
                            return $firstSig
                        }
                    }
                } catch {
                    Write-Detail -Message "Failed to parse JSON for $userAccount : $($_.Exception.Message)" -Level Debug
                }
            }
        }
        
        # Method 2: Check common MailSettings paths (older method)
        Write-Detail -Message "Checking legacy MailSettings registry paths" -Level Debug
        $outlookVersions = @(
            "HKCU:\Software\Microsoft\Office\16.0\Common\MailSettings",
            "HKCU:\Software\Microsoft\Office\15.0\Common\MailSettings",
            "HKCU:\Software\Microsoft\Office\14.0\Common\MailSettings"
        )
        
        foreach ($path in $outlookVersions) {
            if (Test-Path $path) {
                $sigName = (Get-ItemProperty -Path $path -Name "NewSignature" -ErrorAction SilentlyContinue).NewSignature
                if ($sigName) {
                    Write-Detail -Message "Default signature from MailSettings: $sigName" -Level Info
                    return $sigName
                }
            }
        } # end of foreach outlook version loop
        
        Write-Detail -Message "No default signature found in registry" -Level Warning
        return $null
    } catch {
        Write-Detail -Message "Error reading signature registry: $($_.Exception.Message)" -Level Error
        return $null
    }
} # end of Get-DefaultSignatureName function

# Function to prompt user to select signature file
Function Select-SignatureFile {
    Write-Detail -Message "Prompting user to select signature file" -Level Info
    
    $sigPath = Get-OutlookSignaturePath
    if (-not $sigPath -or -not (Test-Path $sigPath)) {
        Write-Detail -Message "Signature path not found for file selection" -Level Error
        return $null
    }
    
    # Get all HTML signature files
    $htmlFiles = Get-ChildItem -Path $sigPath -Filter "*.htm" | Sort-Object LastWriteTime -Descending
    
    if ($htmlFiles.Count -eq 0) {
        Write-Detail -Message "No signature files found in $sigPath" -Level Warning
        return $null
    }
    
    # Create file selection dialog
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.InitialDirectory = $sigPath
    $fileDialog.Filter = "HTML Signature Files (*.htm)|*.htm|All Files (*.*)|*.*"
    $fileDialog.Title = "Select Your Outlook Signature File"
    
    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedFile = [System.IO.Path]::GetFileNameWithoutExtension($fileDialog.FileName)
        Write-Detail -Message "User selected signature file: $selectedFile" -Level Info
        return $selectedFile
    }
    
    Write-Detail -Message "User cancelled file selection" -Level Warning
    return $null
} # end of Select-SignatureFile function

#endregion Outlook Helper Functions

#region Signature Processing Functions

# Function to backup signature to file
Function Backup-SignatureToFile {
    param(
        [string]$htmlContent,
        [string]$signatureFileName
    )
    
    Write-Detail -Message "Backing up signature to file" -Level Info
    
    try {
        # Create backup directory if it doesn't exist
        if (-not (Test-Path $backupPath)) {
            New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
            Write-Detail -Message "Created backup directory: $backupPath" -Level Debug
        }
        
        # Generate backup filename with timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFileName = "${signatureFileName}_${timestamp}.htm"
        $backupFilePath = Join-Path $backupPath $backupFileName
        
        # Write backup file
        Set-Content -Path $backupFilePath -Value $htmlContent -Encoding UTF8 -Force
        Write-Detail -Message "Signature backed up to: $backupFilePath" -Level Info
        
        # Update registry with last known signature file name
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
            Write-Detail -Message "Created registry key: $regPath" -Level Debug
        }
        
        $registryData = [PSCustomObject]@{
            SignatureFileName = $signatureFileName
            LastBackup = $backupFilePath
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        } | ConvertTo-Json -Compress
        
        Set-ItemProperty -Path $regPath -Name $regValueName -Value $registryData
        Write-Detail -Message "Registry updated with last signature info" -Level Debug
        
        # Clean up old backups (keep last 10)
        $allBackups = Get-ChildItem -Path $backupPath -Filter "${signatureFileName}_*.htm" | 
            Sort-Object LastWriteTime -Descending
        
        if ($allBackups.Count -gt 10) {
            $oldBackups = $allBackups | Select-Object -Skip 10
            foreach ($oldBackup in $oldBackups) {
                Remove-Item -Path $oldBackup.FullName -Force
                Write-Detail -Message "Removed old backup: $($oldBackup.Name)" -Level Debug
            }
        }
        
        return $backupFilePath
        
    } catch {
        Write-Detail -Message "Failed to backup signature: $($_.Exception.Message)" -Level Error
        return $null
    }
} # end of Backup-SignatureToFile function

# Function to get last known signature file from registry
Function Get-LastSignatureFile {
    Write-Detail -Message "Retrieving last known signature file from registry" -Level Debug
    
    try {
        if (-not (Test-Path $regPath)) {
            Write-Detail -Message "No registry data found" -Level Debug
            return $null
        }
        
        $registryData = (Get-ItemProperty -Path $regPath -Name $regValueName -ErrorAction SilentlyContinue).$regValueName
        
        if (-not $registryData) {
            Write-Detail -Message "No last signature data found" -Level Debug
            return $null
        }
        
        # Parse JSON
        $data = $registryData | ConvertFrom-Json
        Write-Detail -Message "Last known signature: $($data.SignatureFileName)" -Level Info
        
        return $data.SignatureFileName
        
    } catch {
        Write-Detail -Message "Failed to retrieve last signature info: $($_.Exception.Message)" -Level Error
        return $null
    }
} # end of Get-LastSignatureFile function

# Function to list available backups
Function Get-SignatureBackups {
    param([string]$signatureFileName)
    
    Write-Detail -Message "Listing backups for: $signatureFileName" -Level Debug
    
    try {
        if (-not (Test-Path $backupPath)) {
            Write-Detail -Message "No backup directory found" -Level Debug
            return @()
        }
        
        $backups = Get-ChildItem -Path $backupPath -Filter "${signatureFileName}_*.htm" | 
            Sort-Object LastWriteTime -Descending
        
        Write-Detail -Message "Found $($backups.Count) backup(s)" -Level Info
        
        return $backups
        
    } catch {
        Write-Detail -Message "Failed to list backups: $($_.Exception.Message)" -Level Error
        return @()
    }
} # end of Get-SignatureBackups function

# Function to clean MSO tags from HTML
Function Remove-MSOTags {
    param([string]$html)
    
    Write-Detail -Message "Cleaning MSO-specific tags from HTML" -Level Debug
    
    # Remove MSO conditional comments (including nested content)
    $html = $html -replace '<!--\[if[^\]]*\]>.*?<!\[endif\]-->', ''
    
    # Remove standalone conditional comment tags
    $html = $html -replace '<!--\[if[^\]]*\]>.*?-->', ''
    $html = $html -replace '<!--<!\[endif\]-->', ''
    
    # Remove MSO-specific style attributes
    $html = $html -replace 'mso-[^:;]+:[^;]+;?', ''
    
    # Remove empty style attributes
    $html = $html -replace '\s*style=""\s*', ' '
    $html = $html -replace '\s*style="\s*"\s*', ' '
    
    # Remove XML namespace declarations
    $html = $html -replace '\s*xmlns:[^=]+="[^"]+"\s*', ' '
    
    # Remove o: and w: prefixed tags and their content
    $html = $html -replace '<o:[^>]+>.*?</o:[^>]+>', ''
    $html = $html -replace '<w:[^>]+>.*?</w:[^>]+>', ''
    $html = $html -replace '</?[ow]:[^>]+/?>', ''
    
    # Remove v: prefixed tags (VML - Vector Markup Language)
    $html = $html -replace '<v:[^>]+>.*?</v:[^>]+>', ''
    $html = $html -replace '</?v:[^>]+/?>', ''
    
    # Remove excessive whitespace - multiple blank lines to single blank line
    $html = $html -replace '(\r?\n\s*){3,}', "`n`n"
    
    # Remove trailing whitespace from each line
    $html = $html -replace '[ \t]+(\r?\n)', '$1'
    
    # Remove leading/trailing whitespace from the entire content
    $html = $html.Trim()
    
    Write-Detail -Message "MSO tags removed and whitespace cleaned" -Level Debug
    return $html
} # end of Remove-MSOTags function

# Function to generate status table HTML with improved body tag handling
Function New-StatusTableHTML {
    param(
        [hashtable]$statusData,
        [bool]$isSplitMode = $true
    )
    
    Write-Detail -Message "Generating status table HTML (Split Mode: $isSplitMode)" -Level Debug
    
    $html = New-Object System.Text.StringBuilder
    
    # Add unique identifier comment for easy replacement
    [void]$html.AppendLine('<!-- OutlookSignatureManager:WeeklyStatusTable:Start -->')
    
    # Add table title
    [void]$html.AppendLine('<p style="font-family: Calibri, Arial, sans-serif; font-size: 11pt; font-weight: bold; margin-bottom: 5px; color: #FF6600;">My Upcoming Week</p>')
    
    [void]$html.AppendLine('<table border="1" cellpadding="4" cellspacing="0" style="border-collapse: collapse; font-family: Calibri, Arial, sans-serif; font-size: 10pt; max-width: 400px; width: 100%;">')
    
    # Header row with brand orange
    [void]$html.AppendLine('  <tr style="background-color: #FF6600; color: white; font-weight: bold;">')
    
    # Get sorted day keys
    $dayKeys = $statusData.Keys | Sort-Object
    $numDays = $dayKeys.Count
    
    # Calculate column widths based on number of days
    if ($isSplitMode) {
        # Split mode: Time column + day columns
        $timeColWidth = 15
        $dayColWidth = [math]::Floor((100 - $timeColWidth) / $numDays)
        
        [void]$html.AppendLine("    <td style='text-align: center; padding: 6px; width: ${timeColWidth}%;'></td>")
        
        foreach ($dayKey in $dayKeys) {
            $dayData = $statusData[$dayKey]
            $dayHeader = "$($dayData.DayName)<br/><span style='font-size: 8pt;'>$($dayData.Date.ToString('dd/MM'))</span>"
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px; width: ${dayColWidth}%;'>$dayHeader</td>")
        } # end of header day loop
        
        [void]$html.AppendLine('  </tr>')
        
        # AM row
        [void]$html.AppendLine('  <tr>')
        [void]$html.AppendLine("    <td style='background-color: #58595B; color: white; font-weight: bold; text-align: center; padding: 6px;'>AM</td>")
        
        foreach ($dayKey in $dayKeys) {
            $statusKey = $statusData[$dayKey]['AM']
            $statusDisplay = $script:statusMap[$statusKey]
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px;'>$statusDisplay</td>")
        } # end of AM day loop
        
        [void]$html.AppendLine('  </tr>')
        
        # PM row
        [void]$html.AppendLine('  <tr>')
        [void]$html.AppendLine("    <td style='background-color: #58595B; color: white; font-weight: bold; text-align: center; padding: 6px;'>PM</td>")
        
        foreach ($dayKey in $dayKeys) {
            $statusKey = $statusData[$dayKey]['PM']
            $statusDisplay = $script:statusMap[$statusKey]
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px;'>$statusDisplay</td>")
        } # end of PM day loop
        
        [void]$html.AppendLine('  </tr>')
    } else {
        # Full day mode: Just day headers, single row
        $dayColWidth = [math]::Floor(100 / $numDays)
        
        foreach ($dayKey in $dayKeys) {
            $dayData = $statusData[$dayKey]
            $dayHeader = "$($dayData.DayName)<br/><span style='font-size: 8pt;'>$($dayData.Date.ToString('dd/MM'))</span>"
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px; width: ${dayColWidth}%;'>$dayHeader</td>")
        } # end of header day loop
        
        [void]$html.AppendLine('  </tr>')
        
        # Single data row with full day status
        [void]$html.AppendLine('  <tr>')
        
        foreach ($dayKey in $dayKeys) {
            $statusKey = $statusData[$dayKey]['AM']  # Use AM since both AM/PM are same in full day mode
            $statusDisplay = $script:statusMap[$statusKey]
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px;'>$statusDisplay</td>")
        } # end of day loop
        
        [void]$html.AppendLine('  </tr>')
    }
    
    [void]$html.AppendLine('</table>')
    [void]$html.AppendLine('<!-- OutlookSignatureManager:WeeklyStatusTable:End -->')
    
    return $html.ToString()
} # end of New-StatusTableHTML function

# Function to generate plain text version
Function New-StatusTableText {
    param(
        [hashtable]$statusData,
        [bool]$isSplitMode = $true
    )

    Write-Detail -Message "Generating status table plain text" -Level Debug

    $text = New-Object System.Text.StringBuilder

    [void]$text.AppendLine("=" * 50)

    $dayKeys = $statusData.Keys | Sort-Object

    if ($isSplitMode) {
        # Split mode: Show AM and PM for each day
        foreach ($dayKey in $dayKeys) {
            $dayData = $statusData[$dayKey]
            $amStatus = $script:statusMapText[$statusData[$dayKey]['AM']]
            $pmStatus = $script:statusMapText[$statusData[$dayKey]['PM']]
            $dayLine = "{0,-16} :  AM: {1}  PM: {2}" -f "$($dayData.DayName) $($dayData.Date.ToString('dd/MM'))", $amStatus, $pmStatus
            [void]$text.AppendLine($dayLine)
        } # end of text day loop
    } else {
        # Full day mode: Show single status for each day
        foreach ($dayKey in $dayKeys) {
            $dayData = $statusData[$dayKey]
            $status = $script:statusMapText[$statusData[$dayKey]['AM']]
            $dayLine = "{0,-16} :  {1}" -f "$($dayData.DayName) $($dayData.Date.ToString('dd/MM'))", $status
            [void]$text.AppendLine($dayLine)
        } # end of text day loop
    }

    [void]$text.AppendLine("=" * 50)

    return $text.ToString()
} # end of New-StatusTableText function

# Function to convert HTML to plain text
Function ConvertFrom-HTMLToText {
    param([string]$html)
    
    Write-Detail -Message "Converting HTML to plain text" -Level Debug
    
    if ([string]::IsNullOrWhiteSpace($html)) {
        return ""
    }
    
    # Extract body content only
    if ($html -match '(?s)<body[^>]*>(.*)</body>') {
        $html = $matches[1]
    }
    
    # Remove script and style tags with their content
    $html = $html -replace '(?s)<script[^>]*>.*?</script>', ''
    $html = $html -replace '(?s)<style[^>]*>.*?</style>', ''
    
    # Convert common HTML elements to text equivalents
    $html = $html -replace '<br[^>]*>', "`n"
    $html = $html -replace '<p[^>]*>', "`n"
    $html = $html -replace '</p>', "`n"
    $html = $html -replace '<div[^>]*>', "`n"
    $html = $html -replace '</div>', ''
    $html = $html -replace '<hr[^>]*>', $("`n" + ("-" * 50) + "`n")
    
    # Remove all remaining HTML tags
    $html = $html -replace '<[^>]+>', ''
    
    # Decode HTML entities
    $html = [System.Net.WebUtility]::HtmlDecode($html)
    
    # Clean up whitespace
    $html = $html -replace '[ \t]+', ' '  # Multiple spaces to single space
    $html = $html -replace '(\r?\n\s*){3,}', "`n`n"  # Multiple blank lines to double line break
    $html = $html.Trim()
    
    return $html
} # end of ConvertFrom-HTMLToText function

#endregion Signature Processing Functions

#region Main Script Execution

Write-Detail -Message "Starting Outlook Signature Manager" -Level Info

# Load configuration
$config = Get-SignatureConfig
$numDays = $config.NumDays
$includeToday = $config.IncludeToday
$script:savedSplitMode = $config.SplitMode
$script:savedWeeklySelections = $config.WeeklySelections

Write-Detail -Message "Configuration: NumDays=$numDays, IncludeToday=$includeToday, SplitMode=$($script:savedSplitMode)" -Level Info
if ($script:savedWeeklySelections) {
    Write-Detail -Message "Loaded saved weekly selections from previous session" -Level Info
}

# Check if running in startup/minimized mode
$isStartupMode = $false

if ($isStartupMode) {
    Write-Detail -Message "Running in startup mode - showing prompt" -Level Info
    
    # Prompt user if they want to update signature
    Add-Type -AssemblyName System.Windows.Forms
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Would you like to update your Outlook signature for this week?",
        "Outlook Signature Manager",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($response -eq [System.Windows.Forms.DialogResult]::No) {
        Write-Detail -Message "User declined to update signature at startup" -Level Info
        exit 0
    }
}

# Get signature path and name early for preview
$sigPath = Get-OutlookSignaturePath
$userAccount = Get-OutlookUserAccount
$sigName = $null
$existingHTML = ""

Write-Detail -Message "User account detected: $userAccount" -Level Info

if ($sigPath) {
    # Try to get signature name using account
    if ($userAccount) {
        $sigName = Get-DefaultSignatureName -userAccount $userAccount
    }
    
    # If no signature from registry, try to get last known from our registry
    if (-not $sigName) {
        $sigName = Get-LastSignatureFile
        if ($sigName) {
            Write-Detail -Message "Using last known signature from registry: $sigName" -Level Info
        }
    }
    
    # If still no signature name, prompt user to select file
    if (-not $sigName) {
        Write-Detail -Message "No default signature found, prompting user to select file" -Level Info
        $sigName = Select-SignatureFile
    }
    
    # Load existing signature if we have a name
    if ($sigName) {
        $htmlFile = Join-Path $sigPath "$sigName.htm"
        if (Test-Path $htmlFile) {
            $existingHTML = Get-Content -Path $htmlFile -Raw -Encoding UTF8
            $existingHTML = Remove-MSOTags -html $existingHTML
            Write-Detail -Message "Loaded existing signature: $htmlFile" -Level Info
        } else {
            Write-Detail -Message "Signature file not found: $htmlFile" -Level Warning
        }
    } else {
        Write-Detail -Message "No signature selected, will create new signature" -Level Warning
    }
} else {
    Write-Detail -Message "Could not locate signature path" -Level Error
}

#endregion Main Script Execution

#region GUI Form Creation

# Main GUI Form
Write-Detail -Message "Building GUI form" -Level Info

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Outlook Signature - Weekly Status Manager"
$form.Size = New-Object System.Drawing.Size(600, 800)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.MinimumSize = New-Object System.Drawing.Size(600, 600)
$form.AutoScroll = $false

# Form resize event to handle browser resizing
$form.Add_Resize({
    # Preview browser and text box will automatically resize due to anchor settings
    if ($previewBrowser -and $textPreviewBox) {
        Update-FormLayout
    }
})

# Title label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(10, 10)
$titleLabel.Size = New-Object System.Drawing.Size(560, 25)
$titleLabel.Text = "Configure Your Weekly Status"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 102, 0) # Brand Orange
$form.Controls.Add($titleLabel)

# Current signature label
$currentSigLabel = New-Object System.Windows.Forms.Label
$currentSigLabel.Location = New-Object System.Drawing.Point(10, 40)
$currentSigLabel.Size = New-Object System.Drawing.Size(400, 20)
$currentSigLabel.Text = "Current Signature: $sigName"
$currentSigLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($currentSigLabel)

# Open other signature button
$openSigButton = New-Object System.Windows.Forms.Button
$openSigButton.Location = New-Object System.Drawing.Point(420, 38)
$openSigButton.Size = New-Object System.Drawing.Size(150, 25)
$openSigButton.Text = "Open Other Signature"
$openSigButton.BackColor = [System.Drawing.Color]::LightGray
$openSigButton.FlatStyle = "Flat"
$form.Controls.Add($openSigButton)

# Open other signature click event
$openSigButton.Add_Click({
    Write-Detail -Message "User requested to open other signature" -Level Info
    
    $newSigName = Select-SignatureFile
    if ($newSigName) {
        # Update signature name
        $script:sigName = $newSigName
        
        # Load new signature
        $newHtmlFile = Join-Path $sigPath "$newSigName.htm"
        if (Test-Path $newHtmlFile) {
            $script:existingHTML = Get-Content -Path $newHtmlFile -Raw -Encoding UTF8
            $script:existingHTML = Remove-MSOTags -html $script:existingHTML
            Write-Detail -Message "Loaded new signature: $newHtmlFile" -Level Info
            
            # Update label
            $currentSigLabel.Text = "Current Signature: $newSigName"
            
            # Refresh preview
            & $updatePreview
            
            [System.Windows.Forms.MessageBox]::Show(
                "Signature loaded: $newSigName",
                "Signature Changed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } else {
            Write-Detail -Message "Signature file not found: $newHtmlFile" -Level Error
            [System.Windows.Forms.MessageBox]::Show(
                "Could not load signature file: $newSigName",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
})

# Number of days label
$numDaysLabel = New-Object System.Windows.Forms.Label
$numDaysLabel.Location = New-Object System.Drawing.Point(10, 70)
$numDaysLabel.Size = New-Object System.Drawing.Size(110, 20)
$numDaysLabel.Text = "Number of Days:"
$numDaysLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($numDaysLabel)

# Number of days dropdown
$numDaysRequired = New-Object System.Windows.Forms.ComboBox
$numDaysRequired.Location = New-Object System.Drawing.Point(125, 68)
$numDaysRequired.Size = New-Object System.Drawing.Size(50, 25)
$numDaysRequired.DropDownStyle = "DropDownList"
for ($nDay = 1; $nDay -le 14; $nDay++) { 
    [void]$numDaysRequired.Items.Add($nDay)
}
$numDaysRequired.SelectedIndex = $numDays - 1
$form.Controls.Add($numDaysRequired)

# Include today checkbox
$includeTodayCheckbox = New-Object System.Windows.Forms.CheckBox
$includeTodayCheckbox.Location = New-Object System.Drawing.Point(190, 68)
$includeTodayCheckbox.Size = New-Object System.Drawing.Size(120, 25)
$includeTodayCheckbox.Text = "Include Today"
$includeTodayCheckbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$includeTodayCheckbox.Checked = $includeToday
$form.Controls.Add($includeTodayCheckbox)

# Use AM/PM checkbox
$useAmPmCheckbox = New-Object System.Windows.Forms.CheckBox
$useAmPmCheckbox.Location = New-Object System.Drawing.Point(320, 68)
$useAmPmCheckbox.Size = New-Object System.Drawing.Size(240, 25)
$useAmPmCheckbox.Text = "Split AM/PM (show separate times)"
$useAmPmCheckbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$useAmPmCheckbox.Checked = $script:savedSplitMode
$form.Controls.Add($useAmPmCheckbox)


# Panel for day dropdowns
$panelDropDown = New-Object System.Windows.Forms.Panel;
$panelDropDown.Location =  New-Object System.Drawing.Size(10, ($useAmPmCheckbox.Location.y + 30) )
$panelDropDown.Size = New-Object System.Drawing.Size(560, 30)
$panelDropDown.AutoSize = $true
$panelDropDown.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowOnly;
$panelDropDown.Padding = New-Object System.Windows.Forms.Padding(5);
$form.Controls.Add($panelDropDown)

# HTML Preview Label
$htmlPreviewLabel = New-Object System.Windows.Forms.Label
$htmlPreviewLabel.Size = New-Object System.Drawing.Size(200, 20)
$htmlPreviewLabel.Text = "HTML Preview:"
$htmlPreviewLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($htmlPreviewLabel)

# HTML section - Move Up button (will be positioned by Update-FormLayout)
$htmlMoveUpButton = New-Object System.Windows.Forms.Button
$htmlMoveUpButton.Size = New-Object System.Drawing.Size(80, 30)
$htmlMoveUpButton.Text = "Move Up"
$htmlMoveUpButton.BackColor = [System.Drawing.Color]::LightBlue
$htmlMoveUpButton.FlatStyle = "Flat"
$htmlMoveUpButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$htmlMoveUpButton.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($htmlMoveUpButton)

# HTML section - Move Down button
$htmlMoveDownButton = New-Object System.Windows.Forms.Button
$htmlMoveDownButton.Size = New-Object System.Drawing.Size(80, 30)
$htmlMoveDownButton.Text = "Move Down"
$htmlMoveDownButton.BackColor = [System.Drawing.Color]::LightBlue
$htmlMoveDownButton.FlatStyle = "Flat"
$htmlMoveDownButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$htmlMoveDownButton.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($htmlMoveDownButton)

# Text section - Move Up button
$textMoveUpButton = New-Object System.Windows.Forms.Button
$textMoveUpButton.Size = New-Object System.Drawing.Size(80, 30)
$textMoveUpButton.Text = "Move Up"
$textMoveUpButton.BackColor = [System.Drawing.Color]::LightBlue
$textMoveUpButton.FlatStyle = "Flat"
$textMoveUpButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$textMoveUpButton.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($textMoveUpButton)

# Text section - Move Down button
$textMoveDownButton = New-Object System.Windows.Forms.Button
$textMoveDownButton.Size = New-Object System.Drawing.Size(80, 30)
$textMoveDownButton.Text = "Move Down"
$textMoveDownButton.BackColor = [System.Drawing.Color]::LightBlue
$textMoveDownButton.FlatStyle = "Flat"
$textMoveDownButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$textMoveDownButton.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($textMoveDownButton)

# HTML Move Up button click event
$htmlMoveUpButton.Add_Click({
    $script:tablePosition++
    if ($script:tablePosition -gt 10) {
        $script:tablePosition = 10
    }
    & $updatePreview
})

# HTML Move Down button click event
$htmlMoveDownButton.Add_Click({
    $script:tablePosition--
    if ($script:tablePosition -lt 0) {
        $script:tablePosition = 0
    }
    & $updatePreview
})

# Text Move Up button click event
$textMoveUpButton.Add_Click({
    $script:tablePosition++
    if ($script:tablePosition -gt 10) {
        $script:tablePosition = 10
    }
    & $updatePreview
})

# Text Move Down button click event
$textMoveDownButton.Add_Click({
    $script:tablePosition--
    if ($script:tablePosition -lt 0) {
        $script:tablePosition = 0
    }
    & $updatePreview
})


#endregion GUI Form Creation

#region Dynamic Day Controls Creation

# Function to create or destroy day controls based on number selected
$script:dropdowns = @{}
$script:maxDays = 14

Function Update-DayControls {
    param(
        [int]$requestedDays,
        [bool]$includeToday
    )
    
    Write-Detail -Message "Updating day controls: RequestedDays=$requestedDays, IncludeToday=$includeToday" -Level Debug
    # padding off the top of the panel
    $yPosition = 5

    # Calculate working days to display
    $today = Get-Date
    $workingDays = @()
    
    if ($includeToday) {
        # Include today if it's a working day
        if ($today.DayOfWeek -ne [System.DayOfWeek]::Saturday -and 
            $today.DayOfWeek -ne [System.DayOfWeek]::Sunday) {
            $workingDays += $today
        }
    }
    
    # Add future working days
    $currentDate = $today.AddDays(1)
    while ($workingDays.Count -lt $requestedDays) {
        # Skip weekends
        if ($currentDate.DayOfWeek -ne [System.DayOfWeek]::Saturday -and 
            $currentDate.DayOfWeek -ne [System.DayOfWeek]::Sunday) {
            $workingDays += $currentDate
        }
        $currentDate = $currentDate.AddDays(1)
    } # end of while working days calculation loop
    
    # Remove existing controls that are beyond requested days
    for ($i = $requestedDays; $i -lt $script:maxDays; $i++) {
        $dayKey = "Day$i"
        if ($script:dropdowns.ContainsKey($dayKey)) {
            $panelDropDown.Controls.Remove($script:dropdowns[$dayKey]['DayLabelMain'])
            $panelDropDown.Controls.Remove($script:dropdowns[$dayKey]['AMLabel'])
            $panelDropDown.Controls.Remove($script:dropdowns[$dayKey]['AM'])
            $panelDropDown.Controls.Remove($script:dropdowns[$dayKey]['PMLabel'])
            $panelDropDown.Controls.Remove($script:dropdowns[$dayKey]['PM'])
            $panelDropDown.Controls.Remove($script:dropdowns[$dayKey]['DayLabel'])
            $panelDropDown.Controls.Remove($script:dropdowns[$dayKey]['Day'])
            
            $script:dropdowns.Remove($dayKey)
        }
    } # end of remove controls loop
    
    # Create or update controls for requested days
    $isSplitMode = $useAmPmCheckbox.Checked
    
    for ($i = 0; $i -lt $requestedDays; $i++) {
        $dayDate = $workingDays[$i]
        $dayName = $dayDate.ToString('dddd')
        $dayKey = "Day$i"
        
        # Check if controls already exist
        if ($script:dropdowns.ContainsKey($dayKey)) {
            # Update existing controls
            $script:dropdowns[$dayKey]['Date'] = $dayDate
            $script:dropdowns[$dayKey]['DayName'] = $dayName
            $script:dropdowns[$dayKey]['DayLabelMain'].Text = "$dayName ($($dayDate.ToString('dd/MM')))"
            $script:dropdowns[$dayKey]['DayLabelMain'].Location = New-Object System.Drawing.Point(10, $yPosition)
            $script:dropdowns[$dayKey]['AMLabel'].Location = New-Object System.Drawing.Point(170, $yPosition)
            $script:dropdowns[$dayKey]['AM'].Location = New-Object System.Drawing.Point(205, $yPosition)
            $script:dropdowns[$dayKey]['PMLabel'].Location = New-Object System.Drawing.Point(340, $yPosition)
            $script:dropdowns[$dayKey]['PM'].Location = New-Object System.Drawing.Point(375, $yPosition)
            $script:dropdowns[$dayKey]['DayLabel'].Location = New-Object System.Drawing.Point(170, $yPosition)
            $script:dropdowns[$dayKey]['Day'].Location = New-Object System.Drawing.Point(215, $yPosition)
            
            # Set visibility based on split mode
            if ($isSplitMode) {
                $script:dropdowns[$dayKey]['DayLabel'].Visible = $false
                $script:dropdowns[$dayKey]['Day'].Visible = $false
                $script:dropdowns[$dayKey]['AMLabel'].Visible = $true
                $script:dropdowns[$dayKey]['AM'].Visible = $true
                $script:dropdowns[$dayKey]['PMLabel'].Visible = $true
                $script:dropdowns[$dayKey]['PM'].Visible = $true
            } else {
                $script:dropdowns[$dayKey]['DayLabel'].Visible = $true
                $script:dropdowns[$dayKey]['Day'].Visible = $true
                $script:dropdowns[$dayKey]['AMLabel'].Visible = $false
                $script:dropdowns[$dayKey]['AM'].Visible = $false
                $script:dropdowns[$dayKey]['PMLabel'].Visible = $false
                $script:dropdowns[$dayKey]['PM'].Visible = $false
            }
        } else {
            # Create new controls
            # Main day label (always visible)
            $dayLabelMain = New-Object System.Windows.Forms.Label
            $dayLabelMain.Location = New-Object System.Drawing.Point(10, $yPosition)
            $dayLabelMain.Size = New-Object System.Drawing.Size(150, 20)
            $dayLabelMain.Text = "$dayName ($($dayDate.ToString('dd/MM')))"
            $dayLabelMain.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $panelDropDown.Controls.Add($dayLabelMain)
            
            # AM label (hidden by default)
            $amLabel = New-Object System.Windows.Forms.Label
            $amLabel.Location = New-Object System.Drawing.Point(170, $yPosition)
            $amLabel.Size = New-Object System.Drawing.Size(30, 20)
            $amLabel.Text = "AM:"
            $amLabel.Visible = $isSplitMode
            $panelDropDown.Controls.Add($amLabel)
            
            # AM dropdown (hidden by default)
            $amDropdown = New-Object System.Windows.Forms.ComboBox
            $amDropdown.Location = New-Object System.Drawing.Point(205, $yPosition)
            $amDropdown.Size = New-Object System.Drawing.Size(120, 25)
            $amDropdown.DropDownStyle = "DropDownList"
            foreach ($option in $script:statusOptions) {
                [void]$amDropdown.Items.Add($option)
            }
            $amDropdown.SelectedIndex = 0
            $amDropdown.Visible = $isSplitMode
            $amDropdown.Add_SelectedIndexChanged($updatePreview)
            $panelDropDown.Controls.Add($amDropdown)
            
            # PM label (hidden by default)
            $pmLabel = New-Object System.Windows.Forms.Label
            $pmLabel.Location = New-Object System.Drawing.Point(340, $yPosition)
            $pmLabel.Size = New-Object System.Drawing.Size(30, 20)
            $pmLabel.Text = "PM:"
            $pmLabel.Visible = $isSplitMode
            $panelDropDown.Controls.Add($pmLabel)
            
            # PM dropdown (hidden by default)
            $pmDropdown = New-Object System.Windows.Forms.ComboBox
            $pmDropdown.Location = New-Object System.Drawing.Point(375, $yPosition)
            $pmDropdown.Size = New-Object System.Drawing.Size(120, 25)
            $pmDropdown.DropDownStyle = "DropDownList"
            foreach ($option in $script:statusOptions) {
                [void]$pmDropdown.Items.Add($option)
            }
            $pmDropdown.SelectedIndex = 0
            $pmDropdown.Visible = $isSplitMode
            $pmDropdown.Add_SelectedIndexChanged($updatePreview)
            $panelDropDown.Controls.Add($pmDropdown)
            
            # Full day label (visible by default)
            $dayOnlyLabel = New-Object System.Windows.Forms.Label
            $dayOnlyLabel.Location = New-Object System.Drawing.Point(170, $yPosition)
            $dayOnlyLabel.Size = New-Object System.Drawing.Size(40, 20)
            $dayOnlyLabel.Text = "Day:"
            $dayOnlyLabel.Visible = (-not $isSplitMode)
            $panelDropDown.Controls.Add($dayOnlyLabel)
            
            # Full day dropdown (visible by default)
            $dayDropdown = New-Object System.Windows.Forms.ComboBox
            $dayDropdown.Location = New-Object System.Drawing.Point(215, $yPosition)
            $dayDropdown.Size = New-Object System.Drawing.Size(280, 25)
            $dayDropdown.DropDownStyle = "DropDownList"
            foreach ($option in $script:statusOptions) {
                [void]$dayDropdown.Items.Add($option)
            }
            $dayDropdown.SelectedIndex = 0
            $dayDropdown.Visible = (-not $isSplitMode)
            $dayDropdown.Add_SelectedIndexChanged($updatePreview)
            $panelDropDown.Controls.Add($dayDropdown)
            
     

            # Store dropdown references
            $script:dropdowns[$dayKey] = @{
                'DayLabelMain' = $dayLabelMain
                'AMLabel' = $amLabel
                'AM' = $amDropdown
                'PMLabel' = $pmLabel
                'PM' = $pmDropdown
                'DayLabel' = $dayOnlyLabel
                'Day' = $dayDropdown
                'Date' = $dayDate
                'DayName' = $dayName
            }
        }
        
        $yPosition += $script:rowHeight
    } # end of create/update controls loop

    # Restore saved selections if available
    if ($script:savedWeeklySelections) {
        Write-Detail -Message "Restoring saved weekly selections" -Level Debug
        foreach ($dayKey in $script:dropdowns.Keys | Sort-Object) {
            $savedDay = $script:savedWeeklySelections | Where-Object { $_.DayKey -eq $dayKey } | Select-Object -First 1
            if ($savedDay) {
                # Restore AM/PM selections if in split mode
                if ($script:dropdowns[$dayKey]['AM'] -and $savedDay.AM) {
                    $amIndex = $script:statusOptions.IndexOf($savedDay.AM)
                    if ($amIndex -ge 0) {
                        $script:dropdowns[$dayKey]['AM'].SelectedIndex = $amIndex
                    }
                }
                if ($script:dropdowns[$dayKey]['PM'] -and $savedDay.PM) {
                    $pmIndex = $script:statusOptions.IndexOf($savedDay.PM)
                    if ($pmIndex -ge 0) {
                        $script:dropdowns[$dayKey]['PM'].SelectedIndex = $pmIndex
                    }
                }
                # Restore full day selection if not in split mode
                if ($script:dropdowns[$dayKey]['Day'] -and $savedDay.Day) {
                    $dayIndex = $script:statusOptions.IndexOf($savedDay.Day)
                    if ($dayIndex -ge 0) {
                        $script:dropdowns[$dayKey]['Day'].SelectedIndex = $dayIndex
                    }
                }
                Write-Detail -Message "Restored selections for $dayKey" -Level Debug
            }
        }
    }

    # Update title label with date range
    if ($workingDays.Count -gt 0) {
        $startDate = $workingDays[0].ToString('dd/MM/yyyy')
        $endDate = $workingDays[$workingDays.Count - 1].ToString('dd/MM/yyyy')
        $titleLabel.Text = "Next $requestedDays Working Day$(if($requestedDays -gt 1){'s'}): $startDate - $endDate"
    }

    # Position preview browser and buttons
    Update-FormLayout
    
} # end of Update-DayControls function

# Function to update form layout after control changes
Function Update-FormLayout {
    # Calculate current browser width
    $currentBrowserWidth = $form.ClientSize.Width - 20
    if ($currentBrowserWidth -lt 560) {
        $currentBrowserWidth = 560
    }

    # Position controls after panel
    $controlsYOffset = $panelDropDown.Location.y + $panelDropDown.Size.Height + 10

    # HTML Preview label
    $htmlPreviewLabel.Location = New-Object System.Drawing.Point(10, $controlsYOffset)

    # Position preview browser below label
    $browserYOffset = $controlsYOffset + 25

    # Temporarily remove anchor from preview browser to reposition it
    $previewBrowser.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $previewBrowser.Location = New-Object System.Drawing.Point(10, $browserYOffset)

    # Calculate dynamic height for preview browser (40% of remaining form height)
    $availableHeight = $form.ClientSize.Height - $browserYOffset - 300
    $browserHeight = [Math]::Max(250, $availableHeight * 0.5)
    $previewBrowser.Size = New-Object System.Drawing.Size($currentBrowserWidth, $browserHeight)

    # Restore anchor after positioning
    $previewBrowser.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    # Update copy button position relative to browser (top-right corner)
    $copyHtmlButton.Location = New-Object System.Drawing.Point((10 + $currentBrowserWidth - 90), ($browserYOffset + 5))

    # Position HTML up/down buttons to the right of browser
    $htmlMoveUpButton.Location = New-Object System.Drawing.Point((10 + $currentBrowserWidth - 180), ($browserYOffset + 5))
    $htmlMoveDownButton.Location = New-Object System.Drawing.Point((10 + $currentBrowserWidth - 180), ($browserYOffset + 40))

    # Position text preview section below HTML preview
    $textPreviewYOffset = $browserYOffset + $previewBrowser.Height + 10

    # Text preview label
    $textPreviewLabel.Location = New-Object System.Drawing.Point(10, $textPreviewYOffset)

    # Text preview textbox
    $textPreviewBox.Location = New-Object System.Drawing.Point(10, ($textPreviewYOffset + 25))
    $textPreviewBox.Width = $currentBrowserWidth

    # Calculate dynamic height for text preview (remaining space)
    $textBoxHeight = [Math]::Max(150, $availableHeight * 0.4)
    $textPreviewBox.Height = $textBoxHeight

    # Position text up/down buttons to the right of text box
    $textMoveUpButton.Location = New-Object System.Drawing.Point((10 + $currentBrowserWidth - 180), ($textPreviewYOffset + 30))
    $textMoveDownButton.Location = New-Object System.Drawing.Point((10 + $currentBrowserWidth - 180), ($textPreviewYOffset + 65))

    # Position action buttons at bottom, aligned to right edge
    $intButtonTop = $textPreviewBox.Location.Y + $textPreviewBox.Height + 10

    # Calculate button positions from right edge
    $rightEdge = 10 + $currentBrowserWidth

    $cancelButton.Location = New-Object System.Drawing.Point(($rightEdge - 80), $intButtonTop)
    $applyButton.Location = New-Object System.Drawing.Point(($rightEdge - 190), $intButtonTop)
    $startupButton.Location = New-Object System.Drawing.Point(($rightEdge - 320), $intButtonTop)

    # Ensure form is tall enough to show all buttons
    $requiredHeight = $intButtonTop + 70  # Button height (30) + margin (40)
    if ($form.ClientSize.Height -lt $requiredHeight) {
        $form.ClientSize = New-Object System.Drawing.Size($form.ClientSize.Width, $requiredHeight)
        Write-Detail -Message "Adjusted form height to $requiredHeight to fit all controls" -Level Debug
    }

} # end of Update-FormLayout function

#endregion Dynamic Day Controls Creation

#region GUI Controls - Preview Section

# Preview WebBrowser control for HTML rendering
$previewBrowser = New-Object System.Windows.Forms.WebBrowser
$previewBrowser.Location = New-Object System.Drawing.Point(10, ($panelDropDown.Location.y + $panelDropDown.Size.Height + 20))
$previewBrowser.Size = New-Object System.Drawing.Size(560, 250)
$previewBrowser.ScriptErrorsSuppressed = $true
$previewBrowser.AllowWebBrowserDrop = $false
$previewBrowser.ScrollBarsEnabled = $false
$previewBrowser.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($previewBrowser)

# Copy HTML button (initially hidden)
$copyHtmlButton = New-Object System.Windows.Forms.Button
$copyHtmlButton.Location = New-Object System.Drawing.Point(480, ($previewBrowser.Location.Y + 5))
$copyHtmlButton.Size = New-Object System.Drawing.Size(80, 25)
$copyHtmlButton.Text = "Copy HTML"
$copyHtmlButton.BackColor = [System.Drawing.Color]::LightGreen
$copyHtmlButton.FlatStyle = "Flat"
$copyHtmlButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$copyHtmlButton.Visible = $false
$copyHtmlButton.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($copyHtmlButton)

# Browser focus event to show copy button - using GotFocus instead of Enter for WebBrowser control
$previewBrowser.Add_GotFocus({
    $copyHtmlButton.Visible = $true
    $copyHtmlButton.BringToFront()
})

# Browser leave event to hide copy button - using LostFocus instead of Leave for WebBrowser control
$previewBrowser.Add_LostFocus({
    $copyHtmlButton.Visible = $false
})

# Copy button click event
$copyHtmlButton.Add_Click({
    if ($previewBrowser.Document -and $previewBrowser.Document.Body) {
        $htmlContent = $previewBrowser.DocumentText
        [System.Windows.Forms.Clipboard]::SetText($htmlContent)
        Write-Detail -Message "HTML content copied to clipboard" -Level Info

        # Brief visual feedback
        $originalColor = $copyHtmlButton.BackColor
        $copyHtmlButton.BackColor = [System.Drawing.Color]::DarkGreen
        $copyHtmlButton.Text = "Copied!"

        # Dispose of old timer if exists
        if ($null -ne $copyHtmlButton.Tag -and $copyHtmlButton.Tag -is [System.Windows.Forms.Timer]) {
            $copyHtmlButton.Tag.Stop()
            $copyHtmlButton.Tag.Dispose()
        }

        # Reset after 1 second
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000
        $timer.Add_Tick({
            $copyHtmlButton.BackColor = $originalColor
            $copyHtmlButton.Text = "Copy HTML"
            $timer.Stop()
            $timer.Dispose()
            $copyHtmlButton.Tag = $null
        })
        $copyHtmlButton.Tag = $timer  # Store for cleanup
        $timer.Start()
    }
})

# Text preview label
$textPreviewLabel = New-Object System.Windows.Forms.Label
$textPreviewLabel.Location = New-Object System.Drawing.Point(10, ($previewBrowser.Location.Y + $previewBrowser.Height + 10))
$textPreviewLabel.Size = New-Object System.Drawing.Size(560, 20)
$textPreviewLabel.Text = "Text Version Preview:"
$textPreviewLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$textPreviewLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($textPreviewLabel)

# Text preview textbox
$textPreviewBox = New-Object System.Windows.Forms.TextBox
$textPreviewBox.Location = New-Object System.Drawing.Point(10, ($textPreviewLabel.Location.Y + 25))
$textPreviewBox.Size = New-Object System.Drawing.Size(560, 150)
$textPreviewBox.Multiline = $true
$textPreviewBox.ScrollBars = "None"
$textPreviewBox.ReadOnly = $true
$textPreviewBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$textPreviewBox.BackColor = [System.Drawing.Color]::WhiteSmoke
$textPreviewBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($textPreviewBox)

# Update preview function
$updatePreview = {
    # Collect current selections
    $statusData = @{}
    $isSplitMode = $useAmPmCheckbox.Checked
    
    foreach ($dayKey in $($script:dropdowns.Keys | Sort-Object)) {
        if ($isSplitMode) {
            # Use separate AM/PM selections
            $statusData[$dayKey] = @{
                'AM' = $script:dropdowns[$dayKey]['AM'].SelectedItem
                'PM' = $script:dropdowns[$dayKey]['PM'].SelectedItem
                'Date' = $script:dropdowns[$dayKey]['Date']
                'DayName' = $script:dropdowns[$dayKey]['DayName']
            }
        } else {
            # Use full day selection for both AM and PM
            $dayStatus = $script:dropdowns[$dayKey]['Day'].SelectedItem
            $statusData[$dayKey] = @{
                'AM' = $dayStatus
                'PM' = $dayStatus
                'Date' = $script:dropdowns[$dayKey]['Date']
                'DayName' = $script:dropdowns[$dayKey]['DayName']
            }
        }
    } # end of collect selections loop
    
    # Generate new table HTML with split mode flag
    $tableHTML = New-StatusTableHTML -statusData $statusData -isSplitMode $isSplitMode
    
    # Generate new table text
    $tableText = New-StatusTableText -statusData $statusData -isSplitMode $isSplitMode
    
    # Combine with existing signature or create new
    $previewHTML = ""
    if ($existingHTML -match '(?s)<body[^>]*>(.*)</body>') {
        $bodyContent = $matches[1]
        
        # Check if table already exists (look for unique identifier comment)
        if ($bodyContent -match '(?s)<!-- OutlookSignatureManager:WeeklyStatusTable:Start -->.*?<!-- OutlookSignatureManager:WeeklyStatusTable:End -->') {
            # Table exists, replace it using identifier comments
            Write-Detail -Message "Existing status table found (by identifier), replacing" -Level Debug
            $newBodyContent = $bodyContent -replace '(?s)<!-- OutlookSignatureManager:WeeklyStatusTable:Start -->.*?<!-- OutlookSignatureManager:WeeklyStatusTable:End -->', $tableHTML
        } elseif ($bodyContent -match '(?s)(My Upcoming Week|<table[^>]*border="1"[^>]*cellpadding="4")') {
            # Old-style table exists, replace it
            Write-Detail -Message "Existing status table found (old-style), replacing" -Level Debug
            $newBodyContent = $bodyContent -replace '(?s)<p[^>]*>My Upcoming Week</p>\s*<table[^>]*border="1"[^>]*cellpadding="4".*?</table>', $tableHTML
            if ($newBodyContent -eq $bodyContent) {
                $newBodyContent = $bodyContent -replace '(?s)<table[^>]*border="1"[^>]*cellpadding="4".*?</table>', $tableHTML
            }
        } else {
            # No table exists, append at end
            Write-Detail -Message "No existing status table, appending to end" -Level Debug
            $newBodyContent = $bodyContent.TrimEnd() + "`n`n" + $tableHTML
        }
        
        $previewHTML = $existingHTML -replace '(?s)<body[^>]*>.*</body>', "<body>`n$newBodyContent`n</body>"
    } else {
        # Create new HTML document with table
        $previewHTML = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body { 
    font-family: Calibri, Arial, sans-serif; 
    font-size: 10pt;
    margin: 10px;
    background-color: #f5f5f5;
}
</style>
</head>
<body>
$tableHTML
</body>
</html>
"@
    }
    
    # Update HTML preview
    $previewBrowser.DocumentText = $previewHTML
    
    # Update text preview
    # Get current text version (if exists)
    $currentTextVersion = ""
    if ($sigName -and $sigPath) {
        $txtFile = Join-Path $sigPath "$sigName.txt"
        if (Test-Path $txtFile) {
            $currentTextVersion = Get-Content -Path $txtFile -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($currentTextVersion)) {
                $currentTextVersion = "(Current text signature is empty)"
            }
        } else {
            $currentTextVersion = "(No text signature file exists yet)"
        }
    } else {
        $currentTextVersion = "(No signature loaded)"
    }

    # Generate updated text version directly from status data
    $tableText = New-StatusTableText -statusData $statusData -isSplitMode $isSplitMode

    # For the updated version, we need to get the base signature text and add the table
    if ($existingHTML -and $existingHTML -match '(?s)<body[^>]*>(.*)</body>') {
        $bodyContent = $matches[1]

        # Remove any existing table from body
        $cleanBodyContent = $bodyContent -replace '(?s)<!-- OutlookSignatureManager:WeeklyStatusTable:Start -->.*?<!-- OutlookSignatureManager:WeeklyStatusTable:End -->', ''
        $cleanBodyContent = $cleanBodyContent -replace '(?s)<p[^>]*>My Upcoming Week</p>\s*<table[^>]*border="1"[^>]*cellpadding="4".*?</table>', ''

        # Convert cleaned HTML to text
        $baseText = ConvertFrom-HTMLToText -html "<body>$cleanBodyContent</body>"

        # Combine base text with new table text
        if ($baseText -and $baseText.Trim().Length -gt 0) {
            $updatedTextVersion = $baseText.TrimEnd() + "`n`n" + $tableText
        } else {
            $updatedTextVersion = $tableText
        }
    } else {
        $updatedTextVersion = $tableText
    }

    # Combine current and updated for display
    $textPreviewContent = "=== CURRENT TEXT VERSION ===`n"
    $textPreviewContent += $currentTextVersion
    $textPreviewContent += "`n`n=== UPDATED TEXT VERSION ===`n"
    $textPreviewContent += $updatedTextVersion

    $textPreviewBox.Text = $textPreviewContent
    
} # end of updatePreview scriptblock

# Number of days change event
$numDaysRequired.Add_SelectedIndexChanged({
    $requestedDays = $numDaysRequired.SelectedItem
    $includeToday = $includeTodayCheckbox.Checked
    
    Write-Detail -Message "Number of days changed to: $requestedDays" -Level Info
    
    # Update day controls
    Update-DayControls -requestedDays $requestedDays -includeToday $includeToday
    
    # Refresh preview
    & $updatePreview
})

# Include today checkbox change event
$includeTodayCheckbox.Add_CheckedChanged({
    $requestedDays = $numDaysRequired.SelectedItem
    $includeToday = $includeTodayCheckbox.Checked
    
    Write-Detail -Message "Include today changed to: $includeToday" -Level Info
    
    # Update day controls
    Update-DayControls -requestedDays $requestedDays -includeToday $includeToday
    
    # Refresh preview
    & $updatePreview
})

# Checkbox change event to show/hide AM/PM dropdowns
$useAmPmCheckbox.Add_CheckedChanged({
    $isSplitMode = $useAmPmCheckbox.Checked
    
    # Track cumulative Y position
    $cumulativeY = 100
    
    foreach ($dayKey in $script:dropdowns.Keys | Sort-Object) {
        # Position all items at the same Y level first
        $script:dropdowns[$dayKey]['DayLabelMain'].Location = New-Object System.Drawing.Point(10, $cumulativeY)
        $script:dropdowns[$dayKey]['AMLabel'].Location = New-Object System.Drawing.Point(170, $cumulativeY)
        $script:dropdowns[$dayKey]['AM'].Location = New-Object System.Drawing.Point(205, $cumulativeY)
        $script:dropdowns[$dayKey]['PMLabel'].Location = New-Object System.Drawing.Point(340, $cumulativeY)
        $script:dropdowns[$dayKey]['PM'].Location = New-Object System.Drawing.Point(375, $cumulativeY)
        $script:dropdowns[$dayKey]['DayLabel'].Location = New-Object System.Drawing.Point(170, $cumulativeY)
        $script:dropdowns[$dayKey]['Day'].Location = New-Object System.Drawing.Point(215, $cumulativeY)
        
        if ($isSplitMode) {
            # Split mode: Day label on first row, AM/PM on same row to the right
            $script:dropdowns[$dayKey]['DayLabel'].Visible = $false
            $script:dropdowns[$dayKey]['Day'].Visible = $false
            $script:dropdowns[$dayKey]['AMLabel'].Visible = $true
            $script:dropdowns[$dayKey]['AM'].Visible = $true
            $script:dropdowns[$dayKey]['PMLabel'].Visible = $true
            $script:dropdowns[$dayKey]['PM'].Visible = $true
        } else {
            # Full day mode: Day label and single dropdown
            $script:dropdowns[$dayKey]['DayLabel'].Visible = $true
            $script:dropdowns[$dayKey]['Day'].Visible = $true
            $script:dropdowns[$dayKey]['AMLabel'].Visible = $false
            $script:dropdowns[$dayKey]['AM'].Visible = $false
            $script:dropdowns[$dayKey]['PMLabel'].Visible = $false
            $script:dropdowns[$dayKey]['PM'].Visible = $false
        }
        
        # Move to next day (same spacing for both modes)
        $cumulativeY += $script:rowHeight
    } # end of foreach day layout adjustment loop

    # Update form layout
    Update-FormLayout

    # Refresh preview
    & $updatePreview
})

#endregion GUI Controls - Preview Section

# Calculate initial button positions
# This will be recalculated when Update-FormLayout is called
$intButtonTop = $textPreviewBox.Location.Y + $textPreviewBox.Height + 10

#region GUI Controls - Action Buttons

# Apply button
$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Location = New-Object System.Drawing.Point(380, $intButtonTop)
$applyButton.Size = New-Object System.Drawing.Size(100, 35)
$applyButton.Text = "Apply"
$applyButton.BackColor = [System.Drawing.Color]::FromArgb(255, 102, 0) # Brand Orange
$applyButton.ForeColor = [System.Drawing.Color]::White
$applyButton.FlatStyle = "Flat"
$applyButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$applyButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($applyButton)

# Cancel button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(490, $intButtonTop)
$cancelButton.Size = New-Object System.Drawing.Size(80, 35)
$cancelButton.Text = "Cancel"
$cancelButton.BackColor = [System.Drawing.Color]::LightGray
$cancelButton.FlatStyle = "Flat"
$cancelButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($cancelButton)

# Startup configuration button
$startupButton = New-Object System.Windows.Forms.Button
$startupButton.Location = New-Object System.Drawing.Point(270, $intButtonTop)
$startupButton.Size = New-Object System.Drawing.Size(100, 35)
$startupButton.Text = "Startup..."
$startupButton.BackColor = [System.Drawing.Color]::LightBlue
$startupButton.FlatStyle = "Flat"
$startupButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$startupButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($startupButton)

# Startup button click event (placeholder - original functionality not included in requirements)
$startupButton.Add_Click({
    Write-Detail -Message "Startup configuration requested" -Level Info
    [System.Windows.Forms.MessageBox]::Show(
        "Startup configuration functionality to be implemented.",
        "Startup Configuration",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# Apply button click event
$applyButton.Add_Click({
    Write-Detail -Message "Apply button clicked - processing signature update" -Level Info
    
    # Collect status data
    $statusData = @{}
    $isSplitMode = $useAmPmCheckbox.Checked
    $weeklySelections = @()

    foreach ($dayKey in $($script:dropdowns.Keys | Sort-Object)) {
        if ($isSplitMode) {
            # Use separate AM/PM selections
            $statusData[$dayKey] = @{
                'AM' = $script:dropdowns[$dayKey]['AM'].SelectedItem
                'PM' = $script:dropdowns[$dayKey]['PM'].SelectedItem
                'Date' = $script:dropdowns[$dayKey]['Date']
                'DayName' = $script:dropdowns[$dayKey]['DayName']
            }
            # Save for registry
            $weeklySelections += @{
                DayKey = $dayKey
                AM = $script:dropdowns[$dayKey]['AM'].SelectedItem
                PM = $script:dropdowns[$dayKey]['PM'].SelectedItem
            }
        } else {
            # Use full day selection for both AM and PM
            $dayStatus = $script:dropdowns[$dayKey]['Day'].SelectedItem
            $statusData[$dayKey] = @{
                'AM' = $dayStatus
                'PM' = $dayStatus
                'Date' = $script:dropdowns[$dayKey]['Date']
                'DayName' = $script:dropdowns[$dayKey]['DayName']
            }
            # Save for registry
            $weeklySelections += @{
                DayKey = $dayKey
                Day = $dayStatus
            }
        }
    } # end of collect selections loop

    # Save configuration to registry (including weekly selections)
    $requestedDays = $numDaysRequired.SelectedItem
    $includeToday = $includeTodayCheckbox.Checked
    $saved = Set-SignatureConfig -NumDays $requestedDays -IncludeToday $includeToday -SplitMode $isSplitMode -WeeklySelections $weeklySelections

    if ($saved) {
        Write-Detail -Message "Configuration saved: NumDays=$requestedDays, IncludeToday=$includeToday, SplitMode=$isSplitMode" -Level Info
    }
    
    # Confirmation dialog
    $confirmResult = [System.Windows.Forms.MessageBox]::Show(
        "This will update your Outlook signature with the selected weekly status. Continue?",
        "Confirm Update",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            Write-Detail -Message "User confirmed - proceeding with signature update" -Level Info
            
            # Get signature path and name
            $targetSigPath = Get-OutlookSignaturePath
            if (-not $targetSigPath) {
                throw "Cannot locate Outlook signature directory"
            }
            
            # Use the signature name we already determined at startup
            $targetSigName = $sigName
            if (-not $targetSigName) {
                # Prompt for signature name as last resort
                Add-Type -AssemblyName Microsoft.VisualBasic
                $targetSigName = [Microsoft.VisualBasic.Interaction]::InputBox(
                    "Enter signature file name (without extension):",
                    "Signature Name",
                    "Signature"
                )
                if ([string]::IsNullOrWhiteSpace($targetSigName)) {
                    throw "Signature name is required"
                }
            }
            
            $htmlFile = Join-Path $targetSigPath "$targetSigName.htm"
            $txtFile = Join-Path $targetSigPath "$targetSigName.txt"
            
            Write-Detail -Message "Target files: HTML=$htmlFile, TXT=$txtFile" -Level Debug
            
            # Read existing HTML signature if it exists (reload to ensure fresh)
            $currentHTML = ""
            if (Test-Path $htmlFile) {
                $currentHTML = Get-Content -Path $htmlFile -Raw -Encoding UTF8
                
                # Backup signature to file before making changes
                $backupResult = Backup-SignatureToFile -htmlContent $currentHTML -signatureFileName $targetSigName
                if ($backupResult) {
                    Write-Detail -Message "Signature backed up to: $backupResult" -Level Info
                }
            }
            
            # Clean existing HTML
            if ($currentHTML) {
                $currentHTML = Remove-MSOTags -html $currentHTML
            }
            
            # Generate new table HTML with split mode flag
            $tableHTML = New-StatusTableHTML -statusData $statusData -isSplitMode $isSplitMode
            
            # If existing signature, append or replace table, otherwise create new
            if ($currentHTML -match '(?s)<body[^>]*>(.*)</body>') {
                $bodyContent = $matches[1]
                
                # Check if table already exists (look for unique identifier comment first)
                if ($bodyContent -match '(?s)<!-- OutlookSignatureManager:WeeklyStatusTable:Start -->.*?<!-- OutlookSignatureManager:WeeklyStatusTable:End -->') {
                    # Table exists with identifier, replace it
                    Write-Detail -Message "Existing status table found (by identifier), replacing" -Level Info
                    $newBodyContent = $bodyContent -replace '(?s)<!-- OutlookSignatureManager:WeeklyStatusTable:Start -->.*?<!-- OutlookSignatureManager:WeeklyStatusTable:End -->', $tableHTML
                    $finalHTML = $currentHTML -replace '(?s)<body[^>]*>.*</body>', "<body>`n$newBodyContent`n</body>"
                } elseif ($bodyContent -match '(?s)(My Upcoming Week|<table[^>]*border="1"[^>]*cellpadding="4")') {
                    # Old-style table exists, replace it
                    Write-Detail -Message "Existing status table found (old-style), replacing" -Level Info
                    $newBodyContent = $bodyContent -replace '(?s)<p[^>]*>My Upcoming Week</p>\s*<table[^>]*border="1"[^>]*cellpadding="4".*?</table>', $tableHTML
                    if ($newBodyContent -eq $bodyContent) {
                        $newBodyContent = $bodyContent -replace '(?s)<table[^>]*border="1"[^>]*cellpadding="4".*?</table>', $tableHTML
                    }
                    $finalHTML = $currentHTML -replace '(?s)<body[^>]*>.*</body>', "<body>`n$newBodyContent`n</body>"
                } else {
                    # No table exists, ask user where to place it
                    Write-Detail -Message "No existing status table found" -Level Info
                    
                    $placementChoice = [System.Windows.Forms.MessageBox]::Show(
                        "No weekly status table found in your signature.`n`nWhere would you like to place the table?`n`nYes = At the top (before existing content)`nNo = At the bottom (after existing content)",
                        "Table Placement",
                        [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
                        [System.Windows.Forms.MessageBoxIcon]::Question
                    )
                    
                    if ($placementChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
                        # Place at top
                        Write-Detail -Message "User chose to place table at top" -Level Info
                        $newBodyContent = $tableHTML + "`n`n" + $bodyContent
                    } elseif ($placementChoice -eq [System.Windows.Forms.DialogResult]::No) {
                        # Place at bottom
                        Write-Detail -Message "User chose to place table at bottom" -Level Info
                        $newBodyContent = $bodyContent.TrimEnd() + "`n`n" + $tableHTML
                    } else {
                        # User cancelled
                        Write-Detail -Message "User cancelled table placement" -Level Info
                        throw "Table placement cancelled by user"
                    }
                    
                    $finalHTML = $currentHTML -replace '(?s)<body[^>]*>.*</body>', "<body>`n$newBodyContent`n</body>"
                }
            } else {
                # Create new HTML document
                $finalHTML = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body { font-family: Calibri, Arial, sans-serif; font-size: 10pt; }
</style>
</head>
<body>
$tableHTML
</body>
</html>
"@
            }
            
            # Write HTML file
            Set-Content -Path $htmlFile -Value $finalHTML -Encoding UTF8 -Force
            Write-Detail -Message "HTML signature file updated: $htmlFile" -Level Info

            # Generate text version with plain text table (not HTML entities)
            $tableText = New-StatusTableText -statusData $statusData -isSplitMode $isSplitMode

            # Get base signature text (without the table)
            if ($currentHTML -match '(?s)<body[^>]*>(.*)</body>') {
                $bodyContent = $matches[1]

                # Remove any existing table from body
                $cleanBodyContent = $bodyContent -replace '(?s)<!-- OutlookSignatureManager:WeeklyStatusTable:Start -->.*?<!-- OutlookSignatureManager:WeeklyStatusTable:End -->', ''
                $cleanBodyContent = $cleanBodyContent -replace '(?s)<p[^>]*>My Upcoming Week</p>\s*<table[^>]*border="1"[^>]*cellpadding="4".*?</table>', ''

                # Convert cleaned HTML to text
                $baseText = ConvertFrom-HTMLToText -html "<body>$cleanBodyContent</body>"

                # Combine base text with new plain text table
                if ($baseText -and $baseText.Trim().Length -gt 0) {
                    $finalText = $baseText.TrimEnd() + "`n`n" + $tableText
                } else {
                    $finalText = $tableText
                }
            } else {
                # No existing content, just use the table
                $finalText = $tableText
            }

            Set-Content -Path $txtFile -Value $finalText -Encoding UTF8 -Force
            Write-Detail -Message "Text signature file updated: $txtFile" -Level Info
            
            [System.Windows.Forms.MessageBox]::Show(
                "Signature updated successfully!`n`nFiles updated:`n$htmlFile`n$txtFile",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
            
        } catch {
            Write-Detail -Message "Error updating signature: $($_.Exception.Message)" -Level Error
            [System.Windows.Forms.MessageBox]::Show(
                "Error updating signature:`n$($_.Exception.Message)",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    } else {
        Write-Detail -Message "User cancelled signature update" -Level Info
    }
}) # end of apply button click event

# Cancel button click event
$cancelButton.Add_Click({
    Write-Detail -Message "User cancelled operation" -Level Info
    $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Close()
}) # end of cancel button click event

#endregion GUI Controls - Action Buttons

#region GUI Initialization and Display

try {
    # Initialize day controls with saved configuration
    Update-DayControls -requestedDays $numDays -includeToday $includeToday

    # Show initial preview
    & $updatePreview

    # Show form
    Write-Detail -Message "Displaying GUI form" -Level Info
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Detail -Message "Signature management completed successfully" -Level Info
        exit 0
    } else {
        Write-Detail -Message "Operation cancelled by user" -Level Info
        exit 0
    }
}
catch {
    Write-Detail -Message "Error in GUI execution: $($_.Exception.Message)" -Level Error
    [System.Windows.Forms.MessageBox]::Show(
        "An error occurred: $($_.Exception.Message)",
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}
finally {
    # Dispose of all controls and form resources
    Write-Detail -Message "Cleaning up resources" -Level Debug

    # Dispose of timer if it exists
    if ($null -ne $copyHtmlButton.Tag -and $copyHtmlButton.Tag -is [System.Windows.Forms.Timer]) {
        $copyHtmlButton.Tag.Stop()
        $copyHtmlButton.Tag.Dispose()
    }

    # Dispose of day control dropdowns
    if ($script:dropdowns) {
        foreach ($dayKey in $script:dropdowns.Keys) {
            if ($script:dropdowns[$dayKey]['AM']) { $script:dropdowns[$dayKey]['AM'].Dispose() }
            if ($script:dropdowns[$dayKey]['PM']) { $script:dropdowns[$dayKey]['PM'].Dispose() }
            if ($script:dropdowns[$dayKey]['Day']) { $script:dropdowns[$dayKey]['Day'].Dispose() }
            if ($script:dropdowns[$dayKey]['AMLabel']) { $script:dropdowns[$dayKey]['AMLabel'].Dispose() }
            if ($script:dropdowns[$dayKey]['PMLabel']) { $script:dropdowns[$dayKey]['PMLabel'].Dispose() }
            if ($script:dropdowns[$dayKey]['DayLabel']) { $script:dropdowns[$dayKey]['DayLabel'].Dispose() }
            if ($script:dropdowns[$dayKey]['DayLabelMain']) { $script:dropdowns[$dayKey]['DayLabelMain'].Dispose() }
        }
    }

    # Dispose of main controls
    if ($previewBrowser) { $previewBrowser.Dispose() }
    if ($copyHtmlButton) { $copyHtmlButton.Dispose() }
    if ($textPreviewBox) { $textPreviewBox.Dispose() }
    if ($textPreviewLabel) { $textPreviewLabel.Dispose() }
    if ($htmlPreviewLabel) { $htmlPreviewLabel.Dispose() }
    if ($applyButton) { $applyButton.Dispose() }
    if ($cancelButton) { $cancelButton.Dispose() }
    if ($startupButton) { $startupButton.Dispose() }
    if ($htmlMoveUpButton) { $htmlMoveUpButton.Dispose() }
    if ($htmlMoveDownButton) { $htmlMoveDownButton.Dispose() }
    if ($textMoveUpButton) { $textMoveUpButton.Dispose() }
    if ($textMoveDownButton) { $textMoveDownButton.Dispose() }
    if ($numDaysRequired) { $numDaysRequired.Dispose() }
    if ($includeTodayCheckbox) { $includeTodayCheckbox.Dispose() }
    if ($useAmPmCheckbox) { $useAmPmCheckbox.Dispose() }
    if ($openSigButton) { $openSigButton.Dispose() }
    if ($currentSigLabel) { $currentSigLabel.Dispose() }
    if ($titleLabel) { $titleLabel.Dispose() }
    if ($numDaysLabel) { $numDaysLabel.Dispose() }
    if ($panelDropDown) { $panelDropDown.Dispose() }
    if ($form) { $form.Dispose() }

    Write-Detail -Message "Resource cleanup completed" -Level Debug
}

#endregion GUI Initialization and Display
