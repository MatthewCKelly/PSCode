# Set Proxy Settings

## Overview

The `Set-ProxySettings.ps1` script provides a parameter-based interface to update Windows proxy settings with automatic validation rules. It encodes the settings into the binary `DefaultConnectionSettings` registry format and updates the system configuration.

## Features

- ✅ Command-line parameter support for all proxy configuration flags
- ✅ Automatic validation rules enforce consistency
- ✅ Creates backup before making changes
- ✅ Preserves version counter (doesn't change in practice)
- ✅ Shows before/after/verified settings
- ✅ Supports `-WhatIf` for dry-run testing
- ✅ Preserves current values when parameters not specified
- ✅ Detailed logging with timestamps

## Usage

### Basic Usage

```powershell
# Enable manual proxy server
.\Set-ProxySettings.ps1 -ProxyEnabled -ProxyServer "proxy.corp.com:8080"

# Enable with bypass list
.\Set-ProxySettings.ps1 -ProxyEnabled -ProxyServer "proxy.corp.com:8080" -ProxyBypass "localhost;*.corp.com;<local>"

# Enable automatic configuration
.\Set-ProxySettings.ps1 -AutoConfigEnabled -AutoConfigURL "http://proxy.corp.com/proxy.pac"

# Enable automatic detection
.\Set-ProxySettings.ps1 -AutoDetectEnabled

# Enable multiple options
.\Set-ProxySettings.ps1 -ProxyEnabled -ProxyServer "proxy:8080" -AutoConfigEnabled -AutoConfigURL "http://proxy.com/proxy.pac"

# Direct connection only (disables all proxies)
.\Set-ProxySettings.ps1 -DirectConnection

# Test without making changes
.\Set-ProxySettings.ps1 -ProxyEnabled -ProxyServer "test:8080" -WhatIf
```

## Parameters

### Connection Flags

| Parameter | Type | Description |
|-----------|------|-------------|
| **-DirectConnection** | Switch | Enable direct connection (no proxy) |
| **-ProxyEnabled** | Switch | Enable manual proxy server |
| **-AutoConfigEnabled** | Switch | Enable automatic configuration script (PAC file) |
| **-AutoDetectEnabled** | Switch | Enable automatic proxy detection (WPAD) |

### Configuration Values

| Parameter | Type | Description |
|-----------|------|-------------|
| **-ProxyServer** | String | Proxy server address and port (e.g., "proxy.example.com:8080") |
| **-ProxyBypass** | String | Semicolon-separated bypass list (e.g., "localhost;*.local;<local>") |
| **-AutoConfigURL** | String | URL to PAC file (e.g., "http://proxy.com/proxy.pac") |

### Utility Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| **-WhatIf** | Switch | Show what would be changed without making changes |

## Automatic Validation Rules

The script enforces consistency between flags and values:

### Rule 1: ProxyEnabled = False
When the proxy is disabled, related fields are automatically cleared:
- **ProxyServer** → cleared (empty string)
- **ProxyBypass** → cleared (empty string)

```powershell
# This will clear proxy settings even if specified
.\Set-ProxySettings.ps1 -ProxyServer "proxy:8080" -ProxyBypass "localhost"
# Result: ProxyEnabled=False, ProxyServer="", ProxyBypass=""
```

### Rule 2: AutoConfigEnabled = False
When auto-config is disabled, the URL is automatically cleared:
- **AutoConfigURL** → cleared (empty string)

```powershell
# This will clear the auto-config URL
.\Set-ProxySettings.ps1 -AutoConfigURL "http://proxy.com/proxy.pac"
# Result: AutoConfigEnabled=False, AutoConfigURL=""
```

### Rule 3: Flag Enabled, No Value Specified
When a flag is enabled but no corresponding value is provided, the current value is preserved:

```powershell
# If current ProxyServer is "old-proxy:8080", this preserves it
.\Set-ProxySettings.ps1 -ProxyEnabled
# Result: ProxyEnabled=True, ProxyServer="old-proxy:8080" (unchanged)
```

## Common Scenarios

### Scenario 1: Enable Manual Proxy with Bypass List

```powershell
.\Set-ProxySettings.ps1 `
    -ProxyEnabled `
    -ProxyServer "proxy.corp.com:8080" `
    -ProxyBypass "localhost;127.0.0.1;*.corp.com;<local>"
```

**Result:**
- Direct Connection: False
- Proxy Enabled: True
- Proxy Server: proxy.corp.com:8080
- Proxy Bypass: localhost;127.0.0.1;*.corp.com;<local>
- Auto Config Enabled: False
- Auto Detect Enabled: False

### Scenario 2: Enable PAC File Auto-Configuration

```powershell
.\Set-ProxySettings.ps1 `
    -AutoConfigEnabled `
    -AutoConfigURL "http://supergeek.nz:8082/proxy.pac?p=abc123" `
    -AutoDetectEnabled
```

**Result:**
- Direct Connection: False
- Proxy Enabled: False
- Auto Config Enabled: True
- Auto Config URL: http://supergeek.nz:8082/proxy.pac?p=abc123
- Auto Detect Enabled: True

### Scenario 3: Disable All Proxies (Direct Connection)

```powershell
.\Set-ProxySettings.ps1 -DirectConnection
```

**Result:**
- Direct Connection: True
- Proxy Enabled: False
- Proxy Server: (empty)
- Proxy Bypass: (empty)
- Auto Config Enabled: False
- Auto Config URL: (empty)
- Auto Detect Enabled: False

### Scenario 4: Combined Proxy and Auto-Config

```powershell
.\Set-ProxySettings.ps1 `
    -ProxyEnabled `
    -ProxyServer "http://127.20.20.20:3128" `
    -ProxyBypass "home.crash.co.nz;fh.local;<local>" `
    -AutoConfigEnabled `
    -AutoConfigURL "http://supergeek.nz:8082/proxy.pac?p=xyz789" `
    -AutoDetectEnabled
```

**Result:**
- All proxy methods enabled simultaneously (manual + auto-config + auto-detect)
- Windows will use the configuration in priority order

## Output

The script shows three stages of settings:

### 1. Current Settings (Before)
```
Current proxy settings:
  Version: 70
  Flags: 0x00000003
  Direct Connection: True
  Proxy Enabled: False
  ...
```

### 2. New Settings (Requested Changes)
```
New settings to apply:
  Version: 70 (preserved)
  Flags: 0x00000002
  Direct Connection: False
  Proxy Enabled: True
  Proxy Server: proxy.corp.com:8080
  ...
```

### 3. Verified Settings (After)
```
Verified updated settings from registry:
  Version: 70
  Flags: 0x00000002
  Direct Connection: False
  Proxy Enabled: True
  Proxy Server: proxy.corp.com:8080
  ...
```

## Backup Files

Before making changes, the script creates an automatic backup:

**Filename Format:**
```
DefaultConnectionSettings_backup_YYYYMMDD_HHmmss.reg
```

**Example:**
```
DefaultConnectionSettings_backup_20251120_143025.reg
```

**Restore from Backup:**
```cmd
reg import "DefaultConnectionSettings_backup_20251120_143025.reg"
```

## Requirements

- **PowerShell 5.1 or higher**
- **Administrative privileges** (for registry write operations)
- **Read-DefaultProxySettings.ps1** in the same directory (provides `Decode-ConnectionSettings` function)
- Windows operating system with registry access

## Dependencies

This script requires:
- **Read-DefaultProxySettings.ps1** - Contains the `Decode-ConnectionSettings` function and helper functions
- Registry path access: `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`

## Related Scripts

- **Read-DefaultProxySettings.ps1** - Read current proxy settings (read-only, no admin required)
- **Read-ProxyRegistryFiles.ps1** - Batch reader for comparing multiple registry export files
- **Test-ProxySettingsDecoder.ps1** - Test harness for validating decoder against sample files
- **defaultproxysettings.ps1** - Original interactive proxy settings tool

## Troubleshooting

### Error: "Cannot find decoder script"
Ensure `Read-DefaultProxySettings.ps1` is in the same folder as this script.

### Error: "Access to the registry key is denied"
The script requires administrative privileges to modify registry settings. Run PowerShell as Administrator.

### Error: "Failed to read current settings"
The registry key may not exist or may be corrupted. Check:
```powershell
Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
```

### Warning: "Proxy disabled - clearing proxy server and bypass list"
This is expected behavior when `-ProxyEnabled` is not specified. The validation rules automatically clear related fields.

### Warning: "Auto config disabled - clearing auto config URL"
This is expected behavior when `-AutoConfigEnabled` is not specified. The validation rules automatically clear related fields.

## Technical Details

### Binary Format

The script encodes settings into the Windows `DefaultConnectionSettings` binary format:

```
Offset  Length  Type    Description
------  ------  ------  -----------
0x00    4       DWORD   Version/Counter (preserved from current settings)
0x04    4       DWORD   Connection Flags (bit field)
0x08    4       DWORD   Unknown Field (varies 1-15, purpose unknown)
0x0C    4       DWORD   Proxy Server String Length (bytes)
0x10    N       ASCII   Proxy Server String (null-terminated, if length > 0)
---     4       DWORD   Proxy Bypass String Length (bytes)
---     N       ASCII   Proxy Bypass String (null-terminated, if length > 0)
---     4       DWORD   Auto Config URL String Length (bytes)
---     N       ASCII   Auto Config URL String (null-terminated, if length > 0)
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

### Version Counter

The version/counter field is preserved from the current settings:
- Script preserves the existing version value (doesn't change in practice)
- Purpose unknown (possibly used by Windows for change detection)
- Typical values: 46-100 (varies by system)

## Version History

- **1.0** (2025-11-20) - Initial release
  - Parameter-based proxy configuration
  - Automatic validation rules
  - Backup creation before changes
  - Version counter preservation (doesn't change)
  - Before/after/verified display
  - -WhatIf support for dry-run testing
  - Preserves current values when parameters not specified

## Author

Created by Claude AI for the PSCode repository.
