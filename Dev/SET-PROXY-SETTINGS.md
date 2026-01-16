# Set-ProxySettings.ps1

## Overview

The `Set-ProxySettings.ps1` script is a **remediation-focused tool** that removes unwanted proxy configuration from Windows `DefaultConnectionSettings`. It automatically increments the change counter and keeps both `DefaultConnectionSettings` and `SavedLegacySettings` registry values synchronized.

**Version:** 2.1.0.2

## Purpose

This script is designed to work as a **remediation script** in SCCM/Intune compliance workflows:

1. **Detection script** (Detection-DefaultProxySettings.ps1) identifies non-compliant proxy settings
2. **Remediation script** (Set-ProxySettings.ps1) removes unwanted configuration
3. Both scripts use CMTrace-compatible logging for audit trails

## Features

- ✅ Removes AutoConfigURL (PAC file) configuration
- ✅ Removes manual ProxyServer configuration (optional)
- ✅ Ensures DirectConnection flag is enabled (optional)
- ✅ Auto-increments change counter (simulates Windows behavior)
- ✅ Synchronizes both DefaultConnectionSettings and SavedLegacySettings
- ✅ Creates registry backup before making changes
- ✅ Smart change detection (only writes if needed)
- ✅ CMTrace-compatible logging
- ✅ Dynamic log path (C:\Windows\Logs or %TEMP% fallback)
- ✅ Returns 0 (success) or 1 (error) for scripting

## Usage

### Basic Usage (Default Behavior)

```powershell
# Remove AutoConfigURL only (default)
.\Set-ProxySettings.ps1
```

**Default behavior:**
- RemoveAutoConfig: **True** (removes PAC URL)
- RemoveProxyServer: **False** (keeps manual proxy)
- EnableDirectConnection: **True** (enables direct connection)
- CreateBackup: **True** (creates .reg backup)

### Remove AutoConfig Only

```powershell
# Explicitly remove AutoConfigURL, keep proxy settings
.\Set-ProxySettings.ps1 -RemoveAutoConfig $true
```

### Remove Both AutoConfig and Proxy

```powershell
# Remove AutoConfigURL AND ProxyServer
.\Set-ProxySettings.ps1 -RemoveAutoConfig $true -RemoveProxyServer $true
```

### Remove Proxy Only (Keep AutoConfig)

```powershell
# Remove ProxyServer, keep AutoConfigURL
.\Set-ProxySettings.ps1 -RemoveAutoConfig $false -RemoveProxyServer $true
```

### Disable Backup Creation

```powershell
# Skip registry backup
.\Set-ProxySettings.ps1 -CreateBackup $false
```

### Keep Existing DirectConnection State

```powershell
# Don't modify DirectConnection flag
.\Set-ProxySettings.ps1 -EnableDirectConnection $false
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **RemoveAutoConfig** | Boolean | `$true` | Remove AutoConfigURL and disable AutoConfig flag |
| **RemoveProxyServer** | Boolean | `$false` | Remove ProxyServer/ProxyBypass and disable Proxy flag |
| **EnableDirectConnection** | Boolean | `$true` | Ensure DirectConnection flag is enabled |
| **CreateBackup** | Boolean | `$true` | Create registry backup before making changes |

## Common Scenarios

### Scenario 1: Remove Unwanted PAC File (Default)

**Problem:** Corporate PAC file is no longer needed, but manual proxy settings should remain.

```powershell
.\Set-ProxySettings.ps1
```

**Result:**
- AutoConfigEnabled: False
- AutoConfigURL: (empty)
- ProxyEnabled: (unchanged)
- ProxyServer: (unchanged)
- DirectConnection: True
- Change Counter: (incremented)

### Scenario 2: Complete Proxy Removal

**Problem:** All proxy settings need to be removed.

```powershell
.\Set-ProxySettings.ps1 -RemoveAutoConfig $true -RemoveProxyServer $true
```

**Result:**
- AutoConfigEnabled: False
- AutoConfigURL: (empty)
- ProxyEnabled: False
- ProxyServer: (empty)
- ProxyBypass: (empty)
- DirectConnection: True
- Change Counter: (incremented)

### Scenario 3: Remove Manual Proxy Only

**Problem:** Manual proxy settings are incorrect, but AutoConfig should remain.

```powershell
.\Set-ProxySettings.ps1 -RemoveAutoConfig $false -RemoveProxyServer $true
```

**Result:**
- AutoConfigEnabled: (unchanged)
- AutoConfigURL: (unchanged)
- ProxyEnabled: False
- ProxyServer: (empty)
- ProxyBypass: (empty)
- Change Counter: (incremented)

## Output and Logging

### Console Output

The script uses **Write-CMLog** for all output, which provides:
- Timestamp on each line
- Severity levels (Note, Warning, Error)
- Component identification
- CMTrace-compatible format

### Log File Location

**Primary:** `C:\Windows\Logs\Remediation-ProxySettings-YYYYMMDD.log`
**Fallback:** `%TEMP%\Remediation-ProxySettings-YYYYMMDD.log`

The script automatically tests write access to `C:\Windows\Logs` and falls back to `$env:TEMP` if not writable.

### Sample Log Output

```
<![LOG[Starting Remediation Script - Set-ProxySettings - v2.1.0.2]LOG]!><time="14:30:25.123-480" date="01-16-2026" component="PreChecks" type="1" thread="5432" file="Set-ProxySettings.ps1">
<![LOG[Log file location: C:\Windows\Logs\Remediation-ProxySettings-20260116.log]LOG]!><time="14:30:25.124-480" date="01-16-2026" component="PreChecks" type="1" thread="5432" file="Set-ProxySettings.ps1">
<![LOG[CURRENT Settings - Change Counter: 8046]LOG]!><time="14:30:25.156-480" date="01-16-2026" component="CurrentSettings" type="1" thread="5432" file="Set-ProxySettings.ps1">
<![LOG[REMEDIATION: Removing AutoConfigURL and disabling AutoConfig flag]LOG]!><time="14:30:25.178-480" date="01-16-2026" component="Remediation" type="1" thread="5432" file="Set-ProxySettings.ps1">
<![LOG[Incremented change counter from 8046 to 8047]LOG]!><time="14:30:25.180-480" date="01-16-2026" component="Modification" type="1" thread="5432" file="Set-ProxySettings.ps1">
<![LOG[Writing modified settings to DefaultConnectionSettings]LOG]!><time="14:30:25.201-480" date="01-16-2026" component="RegistryWrite" type="1" thread="5432" file="Set-ProxySettings.ps1">
<![LOG[SavedLegacySettings updated successfully]LOG]!><time="14:30:25.215-480" date="01-16-2026" component="RegistryWrite" type="1" thread="5432" file="Set-ProxySettings.ps1">
<![LOG[Registry updated successfully (DefaultConnectionSettings + SavedLegacySettings)]LOG]!><time="14:30:25.220-480" date="01-16-2026" component="Success" type="1" thread="5432" file="Set-ProxySettings.ps1">
```

## Return Codes

| Code | Meaning | Description |
|------|---------|-------------|
| **0** | Success | Settings remediated successfully OR no changes needed (already compliant) |
| **1** | Error | Failed to read registry, encode settings, or write to registry |

## Backup Files

### Automatic Backup Creation

Before making changes, the script creates an automatic registry export (if `CreateBackup` is `$true`):

**Filename Format:**
```
DefaultConnectionSettings_backup_YYYYMMDD_HHmmss.reg
```

**Example:**
```
DefaultConnectionSettings_backup_20260116_143025.reg
```

**Location:**
```
%TEMP%\DefaultConnectionSettings_backup_20260116_143025.reg
```

### Restore from Backup

If you need to revert changes:

```cmd
reg import "%TEMP%\DefaultConnectionSettings_backup_20260116_143025.reg"
```

Or double-click the `.reg` file in Windows Explorer.

## Registry Values Updated

The script modifies two binary registry values in:

**Path:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`

**Values:**
1. **DefaultConnectionSettings** - Primary proxy configuration
2. **SavedLegacySettings** - Legacy settings (synchronized)

Both values are updated with the **same binary data** to ensure consistency.

## Technical Details

### Binary Structure (12-byte header)

```
Offset  Length  Type    Description
------  ------  ------  -----------
0x00    4       DWORD   Version Signature (always 0x46 = 70)
0x04    4       DWORD   Change Counter (auto-increments)
0x08    4       DWORD   Connection Flags (bit field)
0x0C    4       DWORD   Proxy Server String Length (bytes)
0x10    N       ASCII   Proxy Server String (null-terminated)
---     4       DWORD   Proxy Bypass String Length (bytes)
---     N       ASCII   Proxy Bypass String (null-terminated)
---     4       DWORD   Auto Config URL String Length (bytes)
---     N       ASCII   Auto Config URL String (null-terminated)
---     32      BYTES   Padding (0x00 bytes)
```

### Connection Flags

```
Bit     Hex     Description
---     ----    -----------
0       0x01    Direct Connection (no proxy)
1       0x02    Proxy Server Enabled
2       0x04    Automatic Configuration Script Enabled
3       0x08    Automatic Proxy Detection Enabled
```

### Change Counter Behavior

- The script **auto-increments** the change counter by 1
- This simulates Windows behavior when modifying proxy settings
- The counter value (e.g., 8046 → 8047) helps Windows detect configuration changes
- Counter values typically range from 1 to several thousand depending on system history

## Smart Change Detection

The script only writes to the registry if changes are actually needed:

```powershell
if (-not $ChangesMade) {
    Write-CMLog "No changes needed - settings already compliant"
    Return 0
}
```

**Example scenarios where no write occurs:**
- AutoConfig already disabled and RemoveAutoConfig requested
- Proxy already disabled and RemoveProxyServer requested
- DirectConnection already enabled and EnableDirectConnection requested

This prevents unnecessary registry writes and change counter increments.

## Requirements

- **PowerShell 5.1 or higher**
- **Windows operating system** with registry access
- **User context:** Runs under HKCU (current user)
- **Permissions:** Standard user permissions (modifies HKCU, not HKLM)

## Error Handling

The script includes comprehensive error handling:

### Registry Path Not Found
```
ERROR: Registry path not found
Returns: 1
```

### Registry Value Empty
```
ERROR: Registry value is empty or null
Returns: 1
```

### Encoding/Decoding Errors
```
ERROR: Error encoding settings: <message>
Returns: 1
```

### SavedLegacySettings Update Failure
```
WARNING: Failed to update SavedLegacySettings: <message>
Returns: 0 (non-blocking error)
```

## Integration with Detection Script

### Detection-Remediation Workflow

**Step 1: Detection**
```powershell
# Check for unwanted AutoConfig URL
.\Detection-DefaultProxySettings.ps1 -AutoConfigPattern "*unwanted.pac*"
# Returns: 1 (non-compliant) if pattern found
```

**Step 2: Remediation**
```powershell
# Remove the unwanted AutoConfig URL
.\Set-ProxySettings.ps1 -RemoveAutoConfig $true
# Returns: 0 (success)
```

**Step 3: Verification (optional)**
```powershell
# Re-run detection to verify compliance
.\Detection-DefaultProxySettings.ps1 -AutoConfigPattern "*unwanted.pac*"
# Returns: 0 (compliant) after remediation
```

## Related Scripts

- **Detection-DefaultProxySettings.ps1** - Detection rule for compliance checking
- **Read-DefaultProxySettings.ps1** - Read current proxy settings (read-only)
- **defaultproxysettings.ps1** - Interactive proxy configuration tool
- **Test-ProxySettingsDecoder.ps1** - Test harness for binary decoder

## Troubleshooting

### "No remediation actions specified"

**Problem:** Both RemoveAutoConfig and RemoveProxyServer are set to `$false`.

**Solution:** Enable at least one remediation action:
```powershell
.\Set-ProxySettings.ps1 -RemoveAutoConfig $true
```

### "Registry path not found"

**Problem:** The registry path doesn't exist on this system.

**Solution:** Verify the registry path exists:
```powershell
Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
```

### "No changes needed - settings already compliant"

**Problem:** The requested changes are already applied (not an error).

**Solution:** This is expected behavior. The script returns 0 (success) without making unnecessary writes.

### "WARNING: Failed to update SavedLegacySettings"

**Problem:** SavedLegacySettings update failed (non-critical).

**Solution:** DefaultConnectionSettings was updated successfully. SavedLegacySettings failure is logged as a warning but doesn't fail the script.

### Log file in TEMP instead of C:\Windows\Logs

**Problem:** User doesn't have write access to C:\Windows\Logs.

**Solution:** This is expected behavior. The script automatically falls back to `$env:TEMP` when C:\Windows\Logs is not writable.

## Version History

- **2.1.0.2** (2026-01-16)
  - Added dynamic log path selection with fallback to TEMP directory
  - Log location now determined by write access test

- **2.1.0.1** (2026-01-16)
  - Added SavedLegacySettings synchronization
  - Both registry values updated with same data

- **2.0.0.1** (2026-01-16)
  - Complete rewrite as remediation-focused script
  - Changed from parameter-based configuration to remediation actions
  - Added auto-incrementing change counter
  - Updated to use 12-byte header structure
  - Added CMTrace logging

## Author

Created for the PSCode repository by MatthewCKelly.

## License

Part of the PSCode repository. See repository for license details.
