# Test-RegistryValueType.ps1
# Version 1.0 - 2025-12-08
# Tests registry value types to ensure they are not QWORD
#
# Usage:
#   .\Test-RegistryValueType.ps1 -ValueName "ConfigLock"
#   .\Test-RegistryValueType.ps1 -ValueName "ConfigLock" -ListAllValues

<#
.SYNOPSIS
    Tests registry value types in the DeviceManageabilityCSP path.

.DESCRIPTION
    Checks the type of registry values in HKLM\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server
    to ensure they are not QWORD (64-bit integer) type.

.PARAMETER ValueName
    The name of the registry value to check. If not specified, all values are checked.

.PARAMETER ListAllValues
    Lists all values in the registry path with their types.

.EXAMPLE
    .\Test-RegistryValueType.ps1 -ValueName "ConfigLock"
    Tests if the ConfigLock value is a QWORD type.

.EXAMPLE
    .\Test-RegistryValueType.ps1 -ListAllValues
    Lists all values and their types in the registry path.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ValueName,

    [Parameter(Mandatory = $false)]
    [switch]$ListAllValues
)

#region Logging Function
function Write-Detail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $caller = (Get-PSCallStack)[1]
    $lineNumber = $caller.ScriptLineNumber

    $colorMap = @{
        'Info'    = 'White'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
        'Debug'   = 'Cyan'
    }

    $color = $colorMap[$Level]
    Write-Host "[$timestamp] [$Level] [Line $lineNumber] $Message" -ForegroundColor $color
}
#endregion

#region Main Script
try {
    $registryPath = "HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server"

    Write-Detail "Testing registry path: $registryPath" -Level Info
    Write-Host ""

    # Check if registry path exists
    if (-not (Test-Path $registryPath)) {
        Write-Detail "Registry path does not exist: $registryPath" -Level Error
        exit 1
    }

    Write-Detail "Registry path exists" -Level Success
    Write-Host ""

    # Get the registry key
    $regKey = Get-Item -Path $registryPath -ErrorAction Stop

    if ($ListAllValues) {
        # List all values with their types
        Write-Detail "Listing all values in registry path:" -Level Info
        Write-Detail ("=" * 80) -Level Info
        Write-Host ""

        $allValues = $regKey.Property
        if ($allValues.Count -eq 0) {
            Write-Detail "No values found in registry path" -Level Warning
        }
        else {
            foreach ($value in $allValues) {
                $valueKind = $regKey.GetValueKind($value)
                $valueData = Get-ItemProperty -Path $registryPath -Name $value | Select-Object -ExpandProperty $value

                $isQWord = $valueKind -eq 'QWord'
                $statusColor = if ($isQWord) { 'Warning' } else { 'Success' }

                Write-Detail "Value Name: $value" -Level Info
                Write-Detail "  Type: $valueKind" -Level $statusColor
                Write-Detail "  Data: $valueData" -Level Debug

                if ($isQWord) {
                    Write-Detail "  [!] WARNING: This value is a QWORD type!" -Level Warning
                }

                Write-Host ""
            }

            # Summary
            $qwordCount = ($allValues | Where-Object { $regKey.GetValueKind($_) -eq 'QWord' }).Count
            Write-Detail ("=" * 80) -Level Info
            Write-Detail "Summary: Found $($allValues.Count) total value(s), $qwordCount QWORD type(s)" -Level Info

            if ($qwordCount -gt 0) {
                Write-Detail "Action Required: $qwordCount value(s) are QWORD type and may need conversion" -Level Warning
            }
        }
    }
    elseif ($ValueName) {
        # Test specific value
        Write-Detail "Testing specific value: $ValueName" -Level Info
        Write-Detail ("=" * 80) -Level Info
        Write-Host ""

        # Check if value exists
        $valueExists = $regKey.Property -contains $ValueName
        if (-not $valueExists) {
            Write-Detail "Value '$ValueName' does not exist in registry path" -Level Error
            Write-Detail "Available values: $($regKey.Property -join ', ')" -Level Info
            exit 1
        }

        # Get value type
        $valueKind = $regKey.GetValueKind($ValueName)
        $valueData = Get-ItemProperty -Path $registryPath -Name $ValueName | Select-Object -ExpandProperty $ValueName

        Write-Detail "Value Name: $ValueName" -Level Info
        Write-Detail "Value Type: $valueKind" -Level Info
        Write-Detail "Value Data: $valueData" -Level Info
        Write-Host ""

        # Check if QWORD
        if ($valueKind -eq 'QWord') {
            Write-Detail "RESULT: Value IS a QWORD type (64-bit integer)" -Level Warning
            Write-Detail "This value type should be converted to a different type" -Level Warning
            exit 1
        }
        else {
            Write-Detail "RESULT: Value is NOT a QWORD type" -Level Success
            Write-Detail "Current type ($valueKind) is acceptable" -Level Success
            exit 0
        }
    }
    else {
        # No parameters specified, show help
        Write-Detail "No parameters specified. Use -ValueName to test a specific value, or -ListAllValues to see all values" -Level Warning
        Write-Host ""
        Write-Detail "Examples:" -Level Info
        Write-Detail "  .\Test-RegistryValueType.ps1 -ListAllValues" -Level Info
        Write-Detail "  .\Test-RegistryValueType.ps1 -ValueName 'ConfigLock'" -Level Info
        Write-Host ""

        # Show available values
        $allValues = $regKey.Property
        if ($allValues.Count -gt 0) {
            Write-Detail "Available values in this registry path:" -Level Info
            foreach ($value in $allValues) {
                Write-Detail "  - $value" -Level Info
            }
        }
    }

}
catch {
    Write-Detail "Error occurred: $($_.Exception.Message)" -Level Error
    Write-Detail "Stack trace: $($_.ScriptStackTrace)" -Level Debug
    exit 1
}
finally {
    Write-Host ""
    Write-Detail "Script execution completed" -Level Info
}
#endregion
