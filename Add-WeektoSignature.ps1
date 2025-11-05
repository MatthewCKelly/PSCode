<#
.SYNOPSIS
    Manages Outlook signature with weekly work location status table
.DESCRIPTION
    PowerShell script with Windows Forms GUI to update Outlook signature files (HTML and TXT)
    with current week's work status. Stores signature backup in registry, removes MSO-specific
    tags, limits table width to 400px, and provides interactive dropdown selection with preview.
.PARAMETER
    No parameters accepted - operates with GUI form interaction
.INPUTS
    User selections via Windows Forms dropdowns for each day's AM/PM status
.OUTPUTS
    Updated signature files in Outlook signature directory
    Console logging via Write-Detail
    Exit code 0 on success, 1 on error
.EXAMPLE
    .\Manage-OutlookSignature.ps1
    Launches GUI form for weekly status configuration
.NOTES
    Author: Claude AI
    Version: 1.0
    Requires: PowerShell 5.0+, .NET Framework for Windows Forms
    Registry: HKCU\Software\OutlookSignatureManager
.VERSION
    1.0 - Initial creation
#>

#region Initialization and Global Variables

# Load required assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Registry path for storing last known signature file name
$regPath = "HKCU:\Software\OutlookSignatureManager"
$regValueName = "LastSignatureFile"


# Backup directory in roaming appdata
$backupPath = "$env:APPDATA\OutlookSignatureManager\Backups"

# Registry property suffix for signature lists
$script:sigListSuffix = "_roaming_signature_list"

# Layout spacing constants
$script:rowHeight = 35          # Height for single row (full day mode)
$script:labelToControlGap = 25  # Gap between day label and AM/PM controls in split mode

# Global status options and display mapping
$script:statusOptions = @('Office', 'WFH', 'Leave', 'Meeting', 'Training', 'Travel', 'Client Site')
$script:statusMap = @{
    'Office' = '&#127970; Office'
    'WFH' = '&#127968; WFH'
    'Leave' = '&#127796; Leave'
    'Meeting' = '&#128101; Meeting'
    'Training' = '&#128218; Training'
    'Travel' = '&#9992; Travel'
    'Client Site' = '&#127970; Client Site'
}

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

# Function to generate status table HTML
Function New-StatusTableHTML {
    param(
        [hashtable]$statusData,
        [bool]$isSplitMode = $true
    )
    
    Write-Detail -Message "Generating status table HTML (Split Mode: $isSplitMode)" -Level Debug
    
    $html = New-Object System.Text.StringBuilder
    
    # Add table title
    [void]$html.AppendLine('<p style="font-family: Calibri, Arial, sans-serif; font-size: 11pt; font-weight: bold; margin-bottom: 5px; color: #FF6600;">My Upcoming Week</p>')
    
    [void]$html.AppendLine('<table border="1" cellpadding="4" cellspacing="0" style="border-collapse: collapse; font-family: Calibri, Arial, sans-serif; font-size: 10pt; max-width: 400px; width: 100%;">')
    
    # Header row with Fulton Hogan orange
    [void]$html.AppendLine('  <tr style="background-color: #FF6600; color: white; font-weight: bold;">')
    
    # Get sorted day keys
    $dayKeys = $statusData.Keys | Sort-Object
    
    if ($isSplitMode) {
        # Split mode: Show time column + days
        [void]$html.AppendLine('    <td style="text-align: center; padding: 6px; width: 15%;"></td>')
        
        foreach ($dayKey in $dayKeys) {
            $dayData = $statusData[$dayKey]
            $dayHeader = "$($dayData.DayName)<br/><span style='font-size: 8pt;'>$($dayData.Date.ToString('dd/MM'))</span>"
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px; width: 17%;'>$dayHeader</td>")
        } # end of header day loop
        
        [void]$html.AppendLine('  </tr>')
        
        # AM row
        [void]$html.AppendLine('  <tr>')
        [void]$html.AppendLine('    <td style="background-color: #58595B; color: white; font-weight: bold; text-align: center; padding: 6px;">AM</td>')
        
        foreach ($dayKey in $dayKeys) {
            $statusKey = $statusData[$dayKey]['AM']
            $statusDisplay = $script:statusMap[$statusKey]
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px;'>$statusDisplay</td>")
        } # end of AM day loop
        
        [void]$html.AppendLine('  </tr>')
        
        # PM row
        [void]$html.AppendLine('  <tr>')
        [void]$html.AppendLine('    <td style="background-color: #58595B; color: white; font-weight: bold; text-align: center; padding: 6px;">PM</td>')
        
        foreach ($dayKey in $dayKeys) {
            $statusKey = $statusData[$dayKey]['PM']
            $statusDisplay = $script:statusMap[$statusKey]
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px;'>$statusDisplay</td>")
        } # end of PM day loop
        
        [void]$html.AppendLine('  </tr>')
    } else {
        # Full day mode: Just day headers, single row
        foreach ($dayKey in $dayKeys) {
            $dayData = $statusData[$dayKey]
            $dayHeader = "$($dayData.DayName)<br/><span style='font-size: 8pt;'>$($dayData.Date.ToString('dd/MM'))</span>"
            [void]$html.AppendLine("    <td style='text-align: center; padding: 6px; width: 20%;'>$dayHeader</td>")
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

    [void]$text.AppendLine("My Upcoming Week")
    [void]$text.AppendLine("=" * 50)

    $dayKeys = $statusData.Keys | Sort-Object

    if ($isSplitMode) {
        # Split mode: Show AM and PM for each day
        foreach ($dayKey in $dayKeys) {
            $dayData = $statusData[$dayKey]
            [void]$text.Append("$($dayData.DayName) $($dayData.Date.ToString('dd/MM'))")
            [void]$text.Append("  AM: $($statusData[$dayKey]['AM']) - PM: $($statusData[$dayKey]['PM'])")
            [void]$text.AppendLine()
        } # end of text day loop
    } else {
        # Full day mode: Show single status for each day
        foreach ($dayKey in $dayKeys) {
            $dayData = $statusData[$dayKey]
            [void]$text.Append("$($dayData.DayName) $($dayData.Date.ToString('dd/MM').PadRight(12, ' ')): $($statusData[$dayKey]['AM'])")
            [void]$text.AppendLine()
        }
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

# Check if running in startup/minimized mode
$isStartupMode = $false; #Test-StartupMode -Args $args

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
$numDays = 5;

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

# Calculate next 5 working days (excluding weekends)
$today = Get-Date
$workingDays = @()
$currentDate = $today.AddDays(1)  # Start from tomorrow

while ($workingDays.Count -lt $numDays) {
    # Skip weekends (Saturday = 6, Sunday = 0)
    if ($currentDate.DayOfWeek -ne [System.DayOfWeek]::Saturday -and 
        $currentDate.DayOfWeek -ne [System.DayOfWeek]::Sunday) {
        $workingDays += $currentDate
    }
    $currentDate = $currentDate.AddDays(1)
} # end of while working days calculation loop

Write-Detail -Message "Next $numDays working days: $($workingDays[0].ToString('yyyy-MM-dd')) to $($workingDays[4].ToString('yyyy-MM-dd'))" -Level Info

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Outlook Signature - Weekly Status Manager"
$form.Size = New-Object System.Drawing.Size(600, 620)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.MinimumSize = New-Object System.Drawing.Size(600, 500)
$form.AutoScroll = $true

# Form resize event to handle browser resizing
$form.Add_Resize({
    # Don't constrain maximum height - let form be freely resizable
    # The anchoring will handle control positioning
    
    # The preview browser will automatically resize due to its anchor settings
    # No manual adjustment needed
})

# Title label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(10, 10)
$titleLabel.Size = New-Object System.Drawing.Size(560, 25)
$titleLabel.Text = "Next 5 Working Days: $($workingDays[0].ToString('dd/MM/yyyy')) - $($workingDays[4].ToString('dd/MM/yyyy'))"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 102, 0) # Fulton Hogan Orange
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
        # Update global signature name
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

$updateDaysrequired = {
    # $numDaysRequired.SelectedItem
    Write-Detail "$numDays vs $($numDaysRequired.SelectedItem)"

}

$numDaysRequired = New-Object System.Windows.Forms.ComboBox;
$numDaysRequired.Location = New-Object System.Drawing.Point(10, 65)
$numDaysRequired.Size     = New-Object System.Drawing.Size(40, 20)
$numDaysRequired.DropDownStyle = "DropDownList"
for ($nDay = 1; $nDay -lt 15; $nDay++) { 
    [void]$numDaysRequired.Items.Add($nDay)
}
$numDaysRequired.SelectedIndex = $numDays-1
$numDaysRequired.Visible = $true
# $numDaysRequired.BackColor = "Red"

$form.Controls.Add($numDaysRequired)

$numDaysRequired.Add_SelectedIndexChanged = $updateDaysrequired


# Use AM/PM checkbox
$useAmPmCheckbox = New-Object System.Windows.Forms.CheckBox
$useAmPmCheckbox.Location = New-Object System.Drawing.Point(80, $numDaysRequired.Location.y)
$useAmPmCheckbox.Size = New-Object System.Drawing.Size(240, 20)
$useAmPmCheckbox.Text = "Split AM/PM (show separate times)"
$useAmPmCheckbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
#$useAmPmCheckbox.BackColor = "Red" 
$useAmPmCheckbox.Checked = $false

$form.Controls.Add($useAmPmCheckbox)

# Function to manage form layout - centralized layout logic
Function Update-FormLayout {
    param(
        [hashtable]$dropdowns,
        [bool]$isSplitMode,
        [System.Windows.Forms.WebBrowser]$previewBrowser,
        [System.Windows.Forms.Button]$startupButton,
        [System.Windows.Forms.Button]$applyButton,
        [System.Windows.Forms.Button]$cancelButton,
        [System.Windows.Forms.Form]$form
    )

    Write-Detail -Message "Updating form layout (Split Mode: $isSplitMode)" -Level Debug

    # Track cumulative Y position - start where day dropdowns begin
    $cumulativeY = 100

    foreach ($dayKey in $dropdowns.Keys | Sort-Object) {
        # Position day label (always visible)
        $dropdowns[$dayKey]['DayLabelMain'].Location = New-Object System.Drawing.Point(10, $cumulativeY)

        if ($isSplitMode) {
            # Split mode: Show AM/PM labels and dropdowns on the same row
            $dropdowns[$dayKey]['AMLabel'].Location = New-Object System.Drawing.Point(170, $cumulativeY)
            $dropdowns[$dayKey]['AM'].Location = New-Object System.Drawing.Point(205, $cumulativeY)
            $dropdowns[$dayKey]['PMLabel'].Location = New-Object System.Drawing.Point(340, $cumulativeY)
            $dropdowns[$dayKey]['PM'].Location = New-Object System.Drawing.Point(375, $cumulativeY)

            # Show AM/PM controls
            $dropdowns[$dayKey]['AMLabel'].Visible = $true
            $dropdowns[$dayKey]['AM'].Visible = $true
            $dropdowns[$dayKey]['PMLabel'].Visible = $true
            $dropdowns[$dayKey]['PM'].Visible = $true

            # Hide full day controls
            $dropdowns[$dayKey]['DayLabel'].Visible = $false
            $dropdowns[$dayKey]['Day'].Visible = $false
        } else {
            # Full day mode: Show single dropdown
            $dropdowns[$dayKey]['DayLabel'].Location = New-Object System.Drawing.Point(170, $cumulativeY)
            $dropdowns[$dayKey]['Day'].Location = New-Object System.Drawing.Point(215, $cumulativeY)

            # Show full day controls
            $dropdowns[$dayKey]['DayLabel'].Visible = $true
            $dropdowns[$dayKey]['Day'].Visible = $true

            # Hide AM/PM controls
            $dropdowns[$dayKey]['AMLabel'].Visible = $false
            $dropdowns[$dayKey]['AM'].Visible = $false
            $dropdowns[$dayKey]['PMLabel'].Visible = $false
            $dropdowns[$dayKey]['PM'].Visible = $false
        }

        # Move to next day row
        $cumulativeY += $script:rowHeight
    } # end of foreach day layout adjustment loop

    # Position preview browser
    $previewY = $cumulativeY + 10
    $previewBrowser.Location = New-Object System.Drawing.Point(10, $previewY)
    $previewBrowser.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 20), 200)

    # Position action buttons at bottom
    $buttonY = $previewY + $previewBrowser.Height + 10
    $startupButton.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 340), $buttonY)
    $applyButton.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 230), $buttonY)
    $cancelButton.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 120), $buttonY)

    # Adjust form height to fit all controls
    $requiredHeight = $buttonY + 70
    if ($form.Height -ne $requiredHeight) {
        $form.Height = $requiredHeight
    }

    Write-Detail -Message "Form layout updated" -Level Debug
} # end of Update-FormLayout function

# Checkbox change event to show/hide AM/PM dropdowns
$useAmPmCheckbox.Add_CheckedChanged({
    $isSplitMode = $useAmPmCheckbox.Checked

    # Use centralized layout function
    Update-FormLayout -dropdowns $dropdowns -isSplitMode $isSplitMode `
                      -previewBrowser $previewBrowser `
                      -startupButton $startupButton -applyButton $applyButton -cancelButton $cancelButton `
                      -form $form

    # Refresh preview
    & $updatePreview
})


#endregion GUI Form Creation

#region GUI Controls - Day Dropdowns

# Create dropdowns for each of the next 5 working days
$dropdowns = @{}
$yPosition = 100

for ($i = 0; $i -lt 5; $i++) {
    $dayDate = $workingDays[$i]
    $dayName = $dayDate.ToString('dddd')
    $dayKey = "Day$i"  # Use Day0, Day1, etc. as keys
    
    # Main day label (always visible)
    $dayLabelMain = New-Object System.Windows.Forms.Label
    $dayLabelMain.Location = New-Object System.Drawing.Point(10, $yPosition)
    $dayLabelMain.Size = New-Object System.Drawing.Size(150, 20)
    $dayLabelMain.Text = "$dayName ($($dayDate.ToString('dd/MM')))"
    $dayLabelMain.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($dayLabelMain)
    
    # AM label (hidden by default)
    $amLabel = New-Object System.Windows.Forms.Label
    $amLabel.Location = New-Object System.Drawing.Point(170, $($yPosition + 25))
    $amLabel.Size = New-Object System.Drawing.Size(30, 20)
    $amLabel.Text = "AM:"
    $amLabel.Visible = $false
    $form.Controls.Add($amLabel)
    
    # AM dropdown (hidden by default)
    $amDropdown = New-Object System.Windows.Forms.ComboBox
    $amDropdown.Location = New-Object System.Drawing.Point(205, $($yPosition + 25))
    $amDropdown.Size = New-Object System.Drawing.Size(120, 25)
    $amDropdown.DropDownStyle = "DropDownList"
    foreach ($option in $script:statusOptions) {
        [void]$amDropdown.Items.Add($option)
    }
    $amDropdown.SelectedIndex = 0
    $amDropdown.Visible = $false
    $form.Controls.Add($amDropdown)
    
    # PM label (hidden by default)
    $pmLabel = New-Object System.Windows.Forms.Label
    $pmLabel.Location = New-Object System.Drawing.Point(340, $($yPosition + 25))
    $pmLabel.Size = New-Object System.Drawing.Size(30, 20)
    $pmLabel.Text = "PM:"
    $pmLabel.Visible = $false
    $form.Controls.Add($pmLabel)
    
    # PM dropdown (hidden by default)
    $pmDropdown = New-Object System.Windows.Forms.ComboBox
    $pmDropdown.Location = New-Object System.Drawing.Point(375, $($yPosition + 25))
    $pmDropdown.Size = New-Object System.Drawing.Size(120, 25)
    $pmDropdown.DropDownStyle = "DropDownList"
    foreach ($option in $script:statusOptions) {
        [void]$pmDropdown.Items.Add($option)
    }
    $pmDropdown.SelectedIndex = 0
    $pmDropdown.Visible = $false
    $form.Controls.Add($pmDropdown)
    
    # Full day label (visible by default)
    $dayOnlyLabel = New-Object System.Windows.Forms.Label
    $dayOnlyLabel.Location = New-Object System.Drawing.Point(170, $yPosition)
    $dayOnlyLabel.Size = New-Object System.Drawing.Size(40, 20)
    $dayOnlyLabel.Text = "Day:"
    $dayOnlyLabel.Visible = $true
    $form.Controls.Add($dayOnlyLabel)
    
    # Full day dropdown (visible by default)
    $dayDropdown = New-Object System.Windows.Forms.ComboBox
    $dayDropdown.Location = New-Object System.Drawing.Point(215, $yPosition)
    $dayDropdown.Size = New-Object System.Drawing.Size(280, 25)
    $dayDropdown.DropDownStyle = "DropDownList"
    foreach ($option in $script:statusOptions) {
        [void]$dayDropdown.Items.Add($option)
    }
    $dayDropdown.SelectedIndex = 0
    $dayDropdown.Visible = $true
    $form.Controls.Add($dayDropdown)
    
    # Store dropdown references
    $dropdowns[$dayKey] = @{
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
    
    $yPosition += $script:rowHeight
} # end of for each working day dropdown creation loop

#endregion GUI Controls - Day Dropdowns

#region GUI Controls - Preview Section

# Preview WebBrowser control for HTML rendering
$previewBrowser = New-Object System.Windows.Forms.WebBrowser
$previewBrowser.Location = New-Object System.Drawing.Point(10, $($yPosition + 20))
$previewBrowser.Size = New-Object System.Drawing.Size(560, 220)
$previewBrowser.ScriptErrorsSuppressed = $true
$previewBrowser.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($previewBrowser)

# Update preview function
$updatePreview = {
    # Collect current selections
    $statusData = @{}
    $isSplitMode = $useAmPmCheckbox.Checked
    
    foreach ($dayKey in $($dropdowns.Keys | Sort-Object)) {
        # Write-Detail "Key is $dayKey - $($dropdowns[$dayKey]['Date'])"
        if ($isSplitMode) {
            # Use separate AM/PM selections
            $statusData[$dayKey] = @{
                'AM' = $dropdowns[$dayKey]['AM'].SelectedItem
                'PM' = $dropdowns[$dayKey]['PM'].SelectedItem
                'Date' = $dropdowns[$dayKey]['Date']
                'DayName' = $dropdowns[$dayKey]['DayName']
            }
        } else {
            # Use full day selection for both AM and PM
            $dayStatus = $dropdowns[$dayKey]['Day'].SelectedItem
            $statusData[$dayKey] = @{
                'AM' = $dayStatus
                'PM' = $dayStatus
                'Date' = $dropdowns[$dayKey]['Date']
                'DayName' = $dropdowns[$dayKey]['DayName']
            }
        }

    } # end of collect selections loop
    
    # Generate new table HTML with split mode flag
    $tableHTML = New-StatusTableHTML -statusData $statusData -isSplitMode $isSplitMode
    
    # Combine with existing signature or create new
    $previewHTML = ""
    if ($existingHTML -match '(?s)<body[^>]*>(.*)</body>') {
        $bodyContent = $matches[1]
        
        # Check if table already exists in signature
        if ($bodyContent -match '(?s)(My Upcoming Week|<table[^>]*border="1"[^>]*cellpadding="4")') {
            # Table exists, replace it
            Write-Detail -Message "Existing status table found, will replace" -Level Debug
            # Remove the title and table together
            $newBodyContent = $bodyContent -replace '(?s)<p[^>]*>My Upcoming Week</p>\s*<table[^>]*border="1"[^>]*cellpadding="4".*?</table>', $tableHTML
            # Fallback: try to replace just the table if title wasn't found
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
    
    $previewBrowser.DocumentText = $previewHTML
} # end of updatePreview scriptblock

# Add change events to all dropdowns to update preview automatically
foreach ($dayKey in $dropdowns.Keys) {
    $dropdowns[$dayKey]['AM'].Add_SelectedIndexChanged($updatePreview)
    $dropdowns[$dayKey]['PM'].Add_SelectedIndexChanged($updatePreview)
    $dropdowns[$dayKey]['Day'].Add_SelectedIndexChanged($updatePreview)
} # end of add change events loop

#endregion GUI Controls - Preview Section


$intButtonTop = $previewBrowser.Location.Y + $previewBrowser.Height + 10;


#region GUI Controls - Action Buttons

# Apply button
$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Location = New-Object System.Drawing.Point(380, $intButtonTop)
$applyButton.Size = New-Object System.Drawing.Size(100, 35)
$applyButton.Text = "Apply"
$applyButton.BackColor = [System.Drawing.Color]::FromArgb(255, 102, 0) # Fulton Hogan Orange
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

# Startup button click event
$startupButton.Add_Click({
    Write-Detail -Message "Startup configuration requested" -Level Info
    
    $startupFolder = [System.Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupFolder "Outlook Signature Manager.lnk"
    $isEnabled = Test-Path $shortcutPath
    
    if ($isEnabled) {
        # Startup is enabled, offer to disable
        $response = [System.Windows.Forms.MessageBox]::Show(
            "Startup prompt is currently ENABLED.`n`nThe script will prompt you to update your signature each time Windows starts.`n`nWould you like to DISABLE the startup prompt?",
            "Startup Configuration",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
            $removed = Remove-StartupShortcut
            if ($removed) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Startup prompt has been disabled.",
                    "Startup Disabled",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
        }
    } else {
        # Startup is disabled, offer to enable
        $response = [System.Windows.Forms.MessageBox]::Show(
            "Startup prompt is currently DISABLED.`n`nWould you like to ENABLE a prompt at Windows startup to update your signature?`n`nThe script will be copied to your AppData folder and a shortcut will be created in your Startup folder.",
            "Startup Configuration",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Install script to AppData
            $installedScript = Install-ScriptToAppData
            if ($installedScript) {
                # Create startup shortcut
                $shortcut = New-StartupShortcut -scriptPath $installedScript
                if ($shortcut) {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Startup prompt has been enabled!`n`nScript location: $installedScript`nShortcut: $shortcut`n`nYou will be prompted to update your signature each time Windows starts.",
                        "Startup Enabled",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to install script to AppData. Please check the log for details.",
                    "Installation Failed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    }
})

# Apply button click event
$applyButton.Add_Click({
    Write-Detail -Message "Apply button clicked - processing signature update" -Level Info
    
    # Collect status data
    $statusData = @{}
    $isSplitMode = $useAmPmCheckbox.Checked



    foreach ($dayKey in $($dropdowns.Keys | Sort-Object)) {
        Write-Detail "Key is $dayKey - $($dropdowns[$dayKey]['Date'])"
        if ($isSplitMode) {
            # Use separate AM/PM selections
            $statusData[$dayKey] = @{
                'AM' = $dropdowns[$dayKey]['AM'].SelectedItem
                'PM' = $dropdowns[$dayKey]['PM'].SelectedItem
                'Date' = $dropdowns[$dayKey]['Date']
                'DayName' = $dropdowns[$dayKey]['DayName']
            }
        } else {
            # Use full day selection for both AM and PM
            $dayStatus = $dropdowns[$dayKey]['Day'].SelectedItem
            $statusData[$dayKey] = @{
                'AM' = $dayStatus
                'PM' = $dayStatus
                'Date' = $dropdowns[$dayKey]['Date']
                'DayName' = $dropdowns[$dayKey]['DayName']
            }
        }

    } # end of collect selections loop

    <#
    foreach ($day in $weekDays) {
        if ($isSplitMode) {
            # Use separate AM/PM selections
            $statusData[$day] += @{
                'AM' = $dropdowns[$day]['AM'].SelectedItem
                'PM' = $dropdowns[$day]['PM'].SelectedItem
            }
        } else {
            # Use full day selection for both AM and PM
            $dayStatus = $dropdowns[$day]['Day'].SelectedItem
            $statusData[$day] += @{
                'AM' = $dayStatus
                'PM' = $dayStatus
            }
        }
    
    } # end of collect status data loop
    #>
    Write-Detail "StatusData contains $($statusData.Count)"

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
                
                # Check if table already exists in signature (look for title or table pattern)
                if ($bodyContent -match '(?s)(My Upcoming Week|<table[^>]*border="1"[^>]*cellpadding="4")') {
                    # Table exists, replace it (including title)
                    Write-Detail -Message "Existing status table found, replacing" -Level Info
                    # Remove the title and table together
                    $newBodyContent = $bodyContent -replace '(?s)<p[^>]*>My Upcoming Week</p>\s*<table[^>]*border="1"[^>]*cellpadding="4".*?</table>', $tableHTML
                    # Fallback: try to replace just the table if title wasn't found
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
            
            # Generate text version from the final HTML
            $existingText = ConvertFrom-HTMLToText -html $finalHTML
            $tableText = New-StatusTableText -statusData $statusData -isSplitMode $isSplitMode
            
            # Combine existing text content with table text
            if ($existingText) {
                $finalText = $existingText.TrimEnd() + "`n`n" + $tableText
            } else {
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

#region GUI Display and Exit

# Show initial preview
& $updatePreview

# Show form
Write-Detail -Message "Displaying GUI form" -Level Info
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Detail -Message "Signature management completed successfully" -Level Info
    # exit 0
} else {
    Write-Detail -Message "Operation cancelled by user" -Level Info
    # exit 0
}

#endregion GUI Display and Exit