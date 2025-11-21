<#
.SYNOPSIS
    Installs Outlook Signature Manager integration
.DESCRIPTION
    Sets up the signature manager script in the recommended location
    and provides instructions for adding to Outlook toolbar
.NOTES
    Author: Claude AI
    Version: 1.0
#>

[CmdletBinding()]
param()

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Outlook Signature Manager - Installation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Define paths
$installDir = "$env:USERPROFILE\Documents\OutlookSignatureManager"
$scriptSource = Join-Path $PSScriptRoot "Add-WeektoSignature.ps1"
$scriptDest = Join-Path $installDir "Add-WeektoSignature.ps1"
$macroSource = Join-Path $PSScriptRoot "SignatureManagerMacro.bas"
$macroBackup = Join-Path $installDir "SignatureManagerMacro.bas"
$docsSource = Join-Path $PSScriptRoot "OutlookToolbarIntegration.md"
$docsDest = Join-Path $installDir "OutlookToolbarIntegration.md"

# Check if source script exists
if (-not (Test-Path $scriptSource)) {
    Write-Host "ERROR: Add-WeektoSignature.ps1 not found in current directory!" -ForegroundColor Red
    Write-Host "Please run this script from the folder containing Add-WeektoSignature.ps1" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 1: Create installation directory
Write-Host "Step 1: Creating installation directory..." -ForegroundColor Green
if (-not (Test-Path $installDir)) {
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    Write-Host "  Created: $installDir" -ForegroundColor Gray
} else {
    Write-Host "  Directory already exists: $installDir" -ForegroundColor Gray
}
Write-Host ""

# Step 2: Copy files
Write-Host "Step 2: Copying files..." -ForegroundColor Green

# Copy main script
Copy-Item -Path $scriptSource -Destination $scriptDest -Force
Write-Host "  Copied: Add-WeektoSignature.ps1" -ForegroundColor Gray

# Copy macro file if exists
if (Test-Path $macroSource) {
    Copy-Item -Path $macroSource -Destination $macroBackup -Force
    Write-Host "  Copied: SignatureManagerMacro.bas" -ForegroundColor Gray
}

# Copy documentation if exists
if (Test-Path $docsSource) {
    Copy-Item -Path $docsSource -Destination $docsDest -Force
    Write-Host "  Copied: OutlookToolbarIntegration.md" -ForegroundColor Gray
}
Write-Host ""

# Step 3: Create desktop shortcut
Write-Host "Step 3: Creating desktop shortcut..." -ForegroundColor Green
$shortcutPath = "$env:USERPROFILE\Desktop\Weekly Signature Manager.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptDest`""
$shortcut.WorkingDirectory = $installDir
$shortcut.Description = "Outlook Weekly Signature Manager"
$shortcut.IconLocation = "C:\Windows\System32\shell32.dll,245" # Calendar icon
$shortcut.Save()
Write-Host "  Created desktop shortcut" -ForegroundColor Gray
Write-Host ""

# Step 4: Show VBA macro code
Write-Host "Step 4: VBA Macro for Outlook Toolbar" -ForegroundColor Green
Write-Host ""
Write-Host "To add this to your Outlook toolbar, you need to add a VBA macro." -ForegroundColor Yellow
Write-Host ""
Write-Host "=== VBA MACRO CODE (Copy this) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host @"
Sub LaunchSignatureManager()
    Dim shell As Object
    Set shell = CreateObject("WScript.Shell")
    shell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -File ""$scriptDest""", 1, False
    Set shell = Nothing
End Sub
"@ -ForegroundColor White
Write-Host ""
Write-Host "=== END OF MACRO CODE ===" -ForegroundColor Cyan
Write-Host ""

# Step 5: Instructions
Write-Host "Step 5: Add Macro to Outlook" -ForegroundColor Green
Write-Host ""
Write-Host "Follow these steps to add the button to Outlook:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Open Outlook" -ForegroundColor White
Write-Host "  2. Press Alt + F11 to open VBA Editor" -ForegroundColor White
Write-Host "  3. Insert > Module" -ForegroundColor White
Write-Host "  4. Paste the macro code shown above" -ForegroundColor White
Write-Host "  5. Save (Ctrl + S) and close VBA Editor" -ForegroundColor White
Write-Host "  6. In Outlook, click dropdown on Quick Access Toolbar" -ForegroundColor White
Write-Host "  7. More Commands > Macros > Select 'LaunchSignatureManager'" -ForegroundColor White
Write-Host "  8. Click 'Add >>' then 'OK'" -ForegroundColor White
Write-Host ""

# Offer to open documentation
Write-Host "Would you like to open the full documentation? (Y/N)" -ForegroundColor Cyan -NoNewline
Write-Host " " -NoNewline
$response = Read-Host

if ($response -eq 'Y' -or $response -eq 'y') {
    if (Test-Path $docsDest) {
        Start-Process "notepad.exe" -ArgumentList $docsDest
    }
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files installed to:" -ForegroundColor White
Write-Host "  $installDir" -ForegroundColor Gray
Write-Host ""
Write-Host "Desktop shortcut created:" -ForegroundColor White
Write-Host "  $shortcutPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test the desktop shortcut" -ForegroundColor White
Write-Host "  2. Add VBA macro to Outlook (see instructions above)" -ForegroundColor White
Write-Host "  3. Read full documentation in: OutlookToolbarIntegration.md" -ForegroundColor White
Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
