# Proxy Registry File Reader

## Overview

The `Read-ProxyRegistryFiles.ps1` script reads all Windows registry export files (`.reg`) from the `ProxySettingsKeys` folder and displays the decoded proxy settings in an easy-to-compare format.

## Features

- ✅ Reads all `.reg` files from the ProxySettingsKeys folder
- ✅ Decodes the binary `DefaultConnectionSettings` data
- ✅ Displays settings in multiple output formats (Table, List, Grid)
- ✅ Color-coded output for easy identification
- ✅ Detailed logging with timestamps
- ✅ Error handling for malformed files

## Usage

### Basic Usage

```powershell
.\Read-ProxyRegistryFiles.ps1
```

This will read all `.reg` files and display the settings in **Table** format with detailed output.

### Output Formats

#### Table Format (Default)
```powershell
.\Read-ProxyRegistryFiles.ps1 -OutputFormat Table
```

Displays a summary table followed by detailed settings for each file:

```
File                          Version  ProxyEnabled  ProxyServer                AutoConfigEnabled  AutoDetectEnabled
----                          -------  ------------  -----------                -----------------  -----------------
ProxySettings-01.reg          3        False         (none)                     True               True
ProxySettings-02.reg          5        True          http://127.20.20.20:3128!  True               True
```

Followed by detailed color-coded output for each file.

#### List Format
```powershell
.\Read-ProxyRegistryFiles.ps1 -OutputFormat List
```

Displays all properties for each file in a detailed list view.

#### Grid Format (Interactive)
```powershell
.\Read-ProxyRegistryFiles.ps1 -OutputFormat Grid
```

Opens an interactive grid window where you can:
- Sort by any column
- Filter results
- Export to CSV

### Custom Folder Path

```powershell
.\Read-ProxyRegistryFiles.ps1 -FolderPath "C:\CustomPath\RegFiles"
```

Read registry files from a different folder.

## Output Fields

Each registry file is decoded to show:

| Field              | Description                                           |
|--------------------|-------------------------------------------------------|
| **File**           | Name of the .reg file                                 |
| **Version**        | Version/counter value (increments with each change)   |
| **Flags**          | Raw connection flags (hex format)                     |
| **DirectConnection**| Whether direct connection is enabled                 |
| **ProxyEnabled**   | Whether manual proxy server is enabled                |
| **ProxyServer**    | Proxy server address and port (if configured)         |
| **ProxyBypass**    | Proxy bypass list (semicolon-separated domains)       |
| **AutoConfigEnabled** | Whether automatic configuration script is enabled  |
| **AutoConfigURL**  | URL of the PAC (proxy auto-config) file              |
| **AutoDetectEnabled** | Whether WPAD auto-detection is enabled            |
| **ByteSize**       | Size of the binary data in bytes                      |

## Common Proxy Configurations

### Example 1: Auto-Config Only
```
ProxyEnabled      : False
AutoConfigEnabled : True
AutoConfigURL     : http://webdefence.global.blackspider.com:8082/proxy.pac?p=b9gwgvhs
AutoDetectEnabled : True
```

### Example 2: Manual Proxy with Auto-Config
```
ProxyEnabled      : True
ProxyServer       : http://127.20.20.20:3128!
ProxyBypass       : home.crash.co.nz;fh.local;<local>
AutoConfigEnabled : True
AutoConfigURL     : http://webdefence.global.blackspider.com:8082/proxy.pac?p=b9gwgvhs
AutoDetectEnabled : True
```

### Example 3: Direct Connection
```
ProxyEnabled      : False
AutoConfigEnabled : False
AutoDetectEnabled : False
DirectConnection  : True
```

## Dependencies

This script requires:
- **PowerShell 5.1 or higher**
- **Read-DefaultProxySettings.ps1** in the same directory (contains `Decode-ConnectionSettings` function)
- Registry files exported from: `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`

## Related Scripts

- **Read-DefaultProxySettings.ps1** - Reads current proxy settings from the live registry
- **Set-ProxySettings.ps1** - Parameter-based script to update proxy settings with automatic validation
- **Test-ProxySettingsDecoder.ps1** - Comprehensive test harness with validation
- **defaultproxysettings.ps1** - Original proxy settings tool

## Troubleshooting

### Error: "Cannot find decoder script"
Ensure `Read-DefaultProxySettings.ps1` is in the same folder as this script.

### Error: "No .reg files found"
Check that the `ProxySettingsKeys` folder exists and contains `.reg` files.

### Warning: "Could not find DefaultConnectionSettings"
The .reg file must contain the `DefaultConnectionSettings` binary value. Export from the correct registry path:

```cmd
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" filename.reg
```

## Color Coding

- **Green** - Enabled features
- **Gray** - Disabled features
- **Yellow** - Configuration values (URLs, servers)
- **Red** - Errors
- **Cyan** - Section headers

## Version History

- **1.1** (2025-11-20) - Critical decoder fix
  - Fixed binary structure parsing - corrected offsets (proxy length at offset 12, not 8)
  - Added Success level support to Write-Detail function
  - Fixed Write-Detail usage patterns (no empty strings, use parentheses for expressions)
  - All 12 sample registry files now parse correctly

- **1.0** (2025-11-20) - Initial release
  - Multi-format output support
  - Color-coded display
  - Comprehensive error handling
  - Integration with decoder functions

## Author

Created by Claude AI for the PSCode repository.
