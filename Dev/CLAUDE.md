# CLAUDE.md - AI Assistant Guide for PSCode/Dev Directory

> **Last Updated:** 2025-11-18
> **Directory:** PSCode/Dev - Development & Testing Scripts
> **Parent Repository:** PSCode - PowerShell Utility Scripts Collection

---

## Table of Contents
1. [Directory Overview](#directory-overview)
2. [Script Reference](#script-reference)
3. [Binary Data Structures](#binary-data-structures)
4. [Function Reference](#function-reference)
5. [Common Patterns & Conventions](#common-patterns--conventions)
6. [Testing & Usage](#testing--usage)
7. [AI Assistant Guidelines](#ai-assistant-guidelines)

---

## Directory Overview

### Purpose
The **Dev** directory contains development and testing scripts for advanced Windows system configuration tasks:
- **Registry Binary Data Manipulation** - Decode/encode DefaultConnectionSettings
- **Internet Explorer/Windows Proxy Configuration** - Programmatic proxy management
- **Binary Protocol Parsing** - Little-endian DWORD structure handling

### Technology Stack
- **Language:** PowerShell 5.1+
- **Framework:** .NET Framework (System.BitConverter, System.Text.Encoding)
- **Windows APIs:** Registry manipulation (HKCU)
- **Data Formats:** Binary registry values, little-endian encoding

### Directory Contents
```
Dev/
└── defaultproxysettings.ps1    # Proxy settings decoder/encoder (537 lines)
```

### Script Statistics
- **Total Lines:** 537
- **Functions:** 5 custom functions
- **Registry Path:** `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`
- **Binary Structure:** DefaultConnectionSettings (variable length)

---

## Script Reference

### defaultproxysettings.ps1 (537 lines)

**Purpose:** Interactive tool to decode, display, and modify Windows DefaultConnectionSettings registry binary data

**Key Features:**
- Binary registry value decoding (little-endian DWORD structures)
- Hex dump display with ASCII representation
- Interactive modification of proxy settings
- Automatic registry backup before changes
- Version counter incrementation
- Flag-based configuration (Direct/Proxy/AutoConfig/AutoDetect)

**Registry Details:**
- **Path:** `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`
- **Value Name:** `DefaultConnectionSettings`
- **Data Type:** Binary (REG_BINARY)
- **Affects:** Internet Explorer and Windows system-wide proxy settings

**Execution Requirements:**
- Administrative privileges (for registry modifications)
- PowerShell 5.x or higher
- Windows operating system with registry access

**Usage:**
```powershell
# Interactive execution
.\defaultproxysettings.ps1

# Script prompts for modifications interactively
# Creates automatic backup: DefaultConnectionSettings_backup_YYYYMMDD_HHmmss.reg
```

**Output Format:**
- Detailed logging with timestamps and line numbers
- Hex dump visualization (16 bytes per row with ASCII)
- Current configuration summary
- Interactive modification prompts

**Exit Codes:**
- `0` - Success (decode/modification completed)
- `1` - Error (registry read failure, empty data, encoding error)

---

## Binary Data Structures

### DefaultConnectionSettings Binary Format

The registry value uses a variable-length binary structure with little-endian encoding:

```
Offset  Length  Type    Description
------  ------  ------  -----------
0x00    4       DWORD   Version/Counter (increments on each change)
0x04    4       DWORD   Connection Flags (bit field)
0x08    4       DWORD   Proxy Server String Length (bytes)
0x0C    N       ASCII   Proxy Server String (null-terminated)
---     4       DWORD   Proxy Bypass String Length (bytes)
---     N       ASCII   Proxy Bypass String (null-terminated)
---     4       DWORD   Auto Config URL String Length (bytes)
---     N       ASCII   Auto Config URL String (null-terminated)
```

### Connection Flags Bit Field (Offset 0x04)

```
Bit     Hex     Description
---     ----    -----------
0       0x01    Direct Connection (no proxy)
1       0x02    Proxy Server Enabled
2       0x04    Automatic Configuration Script Enabled
3       0x08    Automatic Proxy Detection Enabled
```

**Common Flag Values:**
- `0x01` (1) - Direct connection only
- `0x03` (3) - Direct connection + Proxy enabled
- `0x0B` (11) - Direct + Proxy + Auto Detect
- `0x09` (9) - Direct + Auto Detect

### Example Binary Structures

**Sample 1: Auto Config Enabled**
```
Offset  Hex Data                            Decoded Value
------  ----------------------------------  -------------
0x00    46 00 00 00                        Version: 70
0x04    1E 01 00 00                        Flags: 0x011E (286)
0x08    01 00 00 00                        Proxy Length: 1
0x0C    00                                 Proxy: (empty)
0x0D    00 00 00 00                        Bypass Length: 0
0x11    01 00 00 00                        Config Length: 1 (or next field)
0x15    20 42 00 00 00                     Likely start of URL length
```

**Sample 2: No Auto Config**
```
Offset  Hex Data                            Decoded Value
------  ----------------------------------  -------------
0x00    46 00 00 00                        Version: 70
0x04    62 1F 00 00                        Flags: 0x1F62 (8034)
0x08    01 00 00 00                        Proxy Length: 1
0x0C    00                                 Proxy: (empty)
0x0D    00 00 00 00                        Bypass Length: 0
0x11    00 00 00 00                        Config Length: 0
0x15    42 00 00 00                        Next field length: 66
```

**Key Observations:**
- Version counter is consistent (0x46 = 70)
- Flags field varies significantly between configurations
- String lengths are always stored as little-endian DWORDs
- Zero-length strings still have length field (0x00000000)

---

## Function Reference

### 1. Write-Detail

```powershell
Function Write-Detail {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',

        [string]$LogFile = $null
    )
}
```

**Purpose:** Enhanced logging with color-coded output, timestamps, and line numbers

**Parameters:**
- `Message` - The log message (required)
- `Level` - Log level: Info, Warning, Error, Debug (default: Info)
- `LogFile` - Optional file path for persistent logging

**Output Format:**
```
[2025-11-18 10:30:45] Info      123 Starting DefaultConnectionSettings decoder/updater tool
[TIMESTAMP]            LEVEL    LINE MESSAGE
```

**Color Coding:**
- **Error** - White text on Red background
- **Warning** - Black text on Yellow background
- **Debug** - Gray text
- **Info** - Default console colors

**Usage Examples:**
```powershell
Write-Detail -Message "Processing started" -Level Info
Write-Detail -Message "Error occurred: $($_.Exception.Message)" -Level Error
Write-Detail -Message "Offset value: $Offset" -Level Debug -LogFile "C:\logs\proxy.log"
```

---

### 2. Read-UInt32FromBytes

```powershell
Function Read-UInt32FromBytes {
    param(
        [byte[]]$Data,
        [int]$Start,
        [int]$Offset
    )
}
```

**Purpose:** Safely read a 32-bit unsigned integer from byte array with bounds checking

**Parameters:**
- `$Data` - Byte array containing binary data
- `$Start` - Starting position in array
- `$Offset` - Offset from start position

**Returns:**
- `[uint32]` - Decoded value on success
- `$null` - On error (insufficient bytes, conversion failure)

**Calculation:**
```powershell
$Position = $Start + $Offset
# Reads bytes at positions: $Position, $Position+1, $Position+2, $Position+3
```

**Error Handling:**
- Validates sufficient bytes available (needs 4 bytes)
- Logs detailed error messages with positions
- Returns null instead of throwing exceptions

**Debugging Output:**
```
[2025-11-18 10:30:45] Debug    108 Read UInt32 at position 8 (start 0 + offset 8): 0x01 00 00 00 = 1
```

**Usage Example:**
```powershell
$Version = Read-UInt32FromBytes -Data $Bytes -Start 0 -Offset 0
if ($null -eq $Version) {
    Write-Detail -Message "Failed to read version field" -Level Error
    return
}
```

**IMPORTANT:** This function was added to fix issues with direct `[System.BitConverter]::ToUInt32()` calls that didn't properly validate bounds. Always use this function instead of direct BitConverter calls for safer parsing.

---

### 3. Decode-ConnectionSettings

```powershell
Function Decode-ConnectionSettings {
    param([byte[]]$Data)
}
```

**Purpose:** Parse binary DefaultConnectionSettings data into structured hashtable

**Parameters:**
- `$Data` - Byte array from registry value

**Returns:** Hashtable with the following keys:
```powershell
@{
    Version              = [uint32]      # Version/counter value
    Flags                = [uint32]      # Raw flags DWORD
    DirectConnection     = [bool]        # Flag bit 0
    ProxyEnabled         = [bool]        # Flag bit 1
    AutoConfigEnabled    = [bool]        # Flag bit 2
    AutoDetectEnabled    = [bool]        # Flag bit 3
    ProxyServer          = [string]      # e.g., "proxy.example.com:8080"
    ProxyBypass          = [string]      # e.g., "localhost;127.0.0.1"
    AutoConfigURL        = [string]      # e.g., "http://proxy.example.com/proxy.pac"
}
```

**Parsing Logic:**
1. Read version (offset 0, 4 bytes)
2. Read flags (offset 4, 4 bytes)
3. Decode flag bits into boolean properties
4. Parse proxy server section (length + string)
5. Parse proxy bypass section (length + string)
6. Parse auto config URL section (length + string)

**String Extraction:**
- Reads length field first (4-byte DWORD)
- Extracts string bytes only if length > 0
- Converts ASCII bytes to string
- Trims null terminators with `TrimEnd([char]0)`

**Safety Features:**
- Validates sufficient bytes before each read
- Sanity checks for unreasonable lengths (>1000 bytes)
- Graceful handling of zero-length strings
- Detailed debug logging of all operations

**Usage Example:**
```powershell
$Settings = Decode-ConnectionSettings -Data $Bytes

Write-Host "Proxy Enabled: $($Settings.ProxyEnabled)"
if ($Settings.ProxyServer) {
    Write-Host "Proxy Server: $($Settings.ProxyServer)"
}
```

---

### 4. Encode-ConnectionSettings

```powershell
Function Encode-ConnectionSettings {
    param([hashtable]$Settings)
}
```

**Purpose:** Convert settings hashtable back to binary registry format

**Parameters:**
- `$Settings` - Hashtable with structure matching Decode-ConnectionSettings output

**Returns:**
- `[byte[]]` - Encoded binary data ready for registry write

**Encoding Process:**
1. **Version** - Convert to 4-byte little-endian DWORD
2. **Flags** - Build bit field from boolean properties:
   ```powershell
   $FlagsValue = 0
   if ($Settings.DirectConnection)   { $FlagsValue = $FlagsValue -bor 0x01 }
   if ($Settings.ProxyEnabled)       { $FlagsValue = $FlagsValue -bor 0x02 }
   if ($Settings.AutoConfigEnabled)  { $FlagsValue = $FlagsValue -bor 0x04 }
   if ($Settings.AutoDetectEnabled)  { $FlagsValue = $FlagsValue -bor 0x08 }
   ```
3. **Proxy Server** - If enabled and not empty:
   - Convert string to ASCII bytes
   - Append null terminator ([char]0)
   - Prepend length DWORD
   - Otherwise write length of 0
4. **Proxy Bypass** - Same process as proxy server
5. **Auto Config URL** - Same process as proxy server

**String Encoding:**
```powershell
$ProxyStringBytes = [System.Text.Encoding]::ASCII.GetBytes($Settings.ProxyServer + [char]0)
$ProxyLengthBytes = [System.BitConverter]::GetBytes([uint32]$ProxyStringBytes.Length)
```

**Usage Example:**
```powershell
$NewSettings = @{
    Version = 71
    DirectConnection = $false
    ProxyEnabled = $true
    AutoConfigEnabled = $false
    AutoDetectEnabled = $false
    ProxyServer = "proxy.corp.com:8080"
    ProxyBypass = "localhost;*.corp.com"
    AutoConfigURL = ""
}

$BinaryData = Encode-ConnectionSettings -Settings $NewSettings
Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value $BinaryData -Type Binary
```

---

## Common Patterns & Conventions

### 1. Binary Data Parsing Pattern

**Consistent offset tracking:**
```powershell
$Offset = 8  # Start after version and flags

# Read proxy server section
$ProxyLength = Read-UInt32FromBytes -Data $Data -Start $Offset -Offset 0
$Offset += 4

if ($ProxyLength -gt 0 -and ($Offset + $ProxyLength) -le $Data.Length) {
    $ProxyBytes = $Data[$Offset..($Offset + $ProxyLength - 1)]
    $ProxyServer = [System.Text.Encoding]::ASCII.GetString($ProxyBytes).TrimEnd([char]0)
}
$Offset += $ProxyLength

# Continue with next section...
```

**Key principles:**
- Always increment offset after reading length field
- Validate bounds before extracting string data
- Handle zero-length strings gracefully
- Increment offset by string length even if not extracted

### 2. Safe UInt32 Reading Pattern

**DO NOT use direct BitConverter without validation:**
```powershell
# ❌ WRONG - No bounds checking
$Value = [System.BitConverter]::ToUInt32($Data, $Offset)

# ✅ CORRECT - Uses safe wrapper
$Value = Read-UInt32FromBytes -Data $Data -Start 0 -Offset $Offset
if ($null -eq $Value) {
    Write-Detail -Message "Failed to read value at offset $Offset" -Level Error
    return $null
}
```

### 3. Hex Dump Display Pattern

```powershell
for ($i = 0; $i -lt $Bytes.Length; $i += 16) {
    $HexRow = ""
    $AsciiRow = ""
    $EndIndex = [Math]::Min($i + 15, $Bytes.Length - 1)

    for ($j = $i; $j -le $EndIndex; $j++) {
        $HexRow += $Bytes[$j].ToString("X2") + " "

        # Printable ASCII chars (32-126)
        if ($Bytes[$j] -ge 32 -and $Bytes[$j] -le 126) {
            $AsciiRow += [char]$Bytes[$j]
        } else {
            $AsciiRow += "."
        }
    }

    $HexRow = $HexRow.PadRight(48)  # Align to 16 bytes
    Write-Detail -Message "$($i.ToString('X4')): $HexRow | $AsciiRow" -Level Info
}
```

**Output Example:**
```
0000: 46 00 00 00 1E 01 00 00 01 00 00 00 00 00 00 00 | F...............
0010: 01 00 00 00 20 42 00 00 00 68 74 74 70 3A 2F 2F | .... B...http://
```

### 4. Registry Backup Pattern

```powershell
$BackupFile = "DefaultConnectionSettings_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
$ExportCommand = "reg export `"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections`" `"$BackupFile`""
Invoke-Expression $ExportCommand
Write-Detail -Message "Registry backup created: $BackupFile" -Level Info
```

**Backup filename format:**
```
DefaultConnectionSettings_backup_20251118_103045.reg
```

### 5. Interactive Configuration Pattern

```powershell
$ProxyChoice = Read-Host "Enable proxy server? (y/n) [Current: $($NewSettings.ProxyEnabled)]"
if ($ProxyChoice -eq 'y' -or $ProxyChoice -eq 'Y') {
    $NewSettings.ProxyEnabled = $true

    $ProxyServer = Read-Host "Enter proxy server (host:port) [Current: $($NewSettings.ProxyServer)]"
    if (-not [string]::IsNullOrEmpty($ProxyServer)) {
        $NewSettings.ProxyServer = $ProxyServer
    }
} else {
    $NewSettings.ProxyEnabled = $false
    $NewSettings.ProxyServer = ""
}
```

**Key features:**
- Show current value in prompt
- Accept both upper and lowercase input
- Only update if user provides new value
- Clear related fields when disabling features

### 6. Flag Bit Manipulation Pattern

**Reading flags:**
```powershell
$Settings.DirectConnection   = ($Settings.Flags -band 0x01) -eq 0x01
$Settings.ProxyEnabled       = ($Settings.Flags -band 0x02) -eq 0x02
$Settings.AutoConfigEnabled  = ($Settings.Flags -band 0x04) -eq 0x04
$Settings.AutoDetectEnabled  = ($Settings.Flags -band 0x08) -eq 0x08
```

**Writing flags:**
```powershell
$FlagsValue = 0
if ($Settings.DirectConnection)   { $FlagsValue = $FlagsValue -bor 0x01 }
if ($Settings.ProxyEnabled)       { $FlagsValue = $FlagsValue -bor 0x02 }
if ($Settings.AutoConfigEnabled)  { $FlagsValue = $FlagsValue -bor 0x04 }
if ($Settings.AutoDetectEnabled)  { $FlagsValue = $FlagsValue -bor 0x08 }
```

**Operators:**
- `-band` - Bitwise AND (for testing bits)
- `-bor` - Bitwise OR (for setting bits)

---

## Testing & Usage

### Testing Strategy

**Manual Testing Checklist:**
- [ ] Script reads registry value without errors
- [ ] Hex dump displays correctly (aligned columns)
- [ ] Current settings decode accurately
- [ ] Interactive prompts work correctly
- [ ] Registry backup created successfully
- [ ] Modified settings encode correctly
- [ ] Registry update succeeds
- [ ] Changes persist after reboot

### Safe Testing Approach

**1. Read-Only Testing (No Modifications):**
```powershell
.\defaultproxysettings.ps1
# When prompted "Do you want to modify these settings? (y/n)", answer 'n'
```

**2. Test with Backup Restoration Plan:**
```powershell
# Run script and make changes
.\defaultproxysettings.ps1

# If something goes wrong, restore from backup:
reg import "DefaultConnectionSettings_backup_YYYYMMDD_HHMMSS.reg"
```

### Validation Commands

**Verify current registry value:**
```powershell
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
$Data = Get-ItemProperty -Path $RegPath -Name "DefaultConnectionSettings"
$Bytes = $Data.DefaultConnectionSettings

Write-Host "Binary length: $($Bytes.Length) bytes"
Write-Host "First 16 bytes: $([System.BitConverter]::ToString($Bytes[0..15]))"
```

**Check Internet Explorer settings:**
```
1. Open Internet Explorer
2. Tools → Internet Options → Connections tab
3. Click "LAN settings"
4. Verify settings match script output
```

### Common Issues and Resolutions

**Issue:** "Registry value is empty or null"
```powershell
# Resolution: Ensure the registry key exists
Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
```

**Issue:** "Cannot read UInt32 at position X"
```
# Cause: Binary data structure doesn't match expected format
# Resolution: Check hex dump output for anomalies, ensure Windows version compatibility
```

**Issue:** "Config length X seems too large"
```
# Cause: Offset tracking error or corrupted data
# Resolution: Review debug output to identify where offset calculation diverged
```

---

## AI Assistant Guidelines

### When Working on This Script

#### 1. Understanding Binary Structures
- **Always analyze the hex dump** - The structure is documented but may have variations
- **Track offset carefully** - Offset tracking errors cause complete parsing failures
- **Validate assumptions** - Use debug output to confirm structure matches expectations
- **Test with real data** - Binary formats can have undocumented variations

#### 2. Code Modification Principles
- **Never remove bounds checking** - Binary parsing MUST validate before reading
- **Preserve debug logging** - Essential for troubleshooting parsing issues
- **Maintain offset tracking** - Every read operation must update offset correctly
- **Test encode/decode round-trip** - Encoding must produce decodable binary data

#### 3. PowerShell Binary Operations
- **Little-Endian Awareness** - Windows uses little-endian byte order
  ```powershell
  # Bytes: 46 00 00 00 → Value: 0x00000046 = 70
  # NOT: 0x46000000
  ```
- **BitConverter Methods:**
  - `ToUInt32($bytes, $offset)` - Read 4-byte unsigned int
  - `GetBytes([uint32]$value)` - Convert to byte array
  - Both operate in little-endian on Windows

#### 4. Registry Manipulation Safety
- **Always create backups** - Registry corruption can break system settings
- **Test modifications** - Verify encoded data before writing to registry
- **Use proper data types** - Registry binary values require `[byte[]]` type
- **Administrative context** - Some registry paths require elevation

#### 5. Function Usage Patterns

**DO use Read-UInt32FromBytes for all DWORD reads:**
```powershell
✅ $Value = Read-UInt32FromBytes -Data $Bytes -Start $Offset -Offset 0
❌ $Value = [System.BitConverter]::ToUInt32($Bytes, $Offset)  # No validation!
```

**DO check for null returns:**
```powershell
✅ $Value = Read-UInt32FromBytes -Data $Bytes -Start 0 -Offset 4
   if ($null -eq $Value) { return $null }

❌ $Value = Read-UInt32FromBytes -Data $Bytes -Start 0 -Offset 4
   # Continue without checking - will fail later!
```

**DO use consistent string encoding:**
```powershell
✅ [System.Text.Encoding]::ASCII.GetString($Bytes)
❌ [System.Text.Encoding]::UTF8.GetString($Bytes)  # Wrong encoding!
```

#### 6. Debugging Binary Parsing Issues

**Enable verbose debug output:**
```powershell
# The script has extensive debug logging
# Review debug messages to identify parsing issues
```

**Useful debugging commands:**
```powershell
# Display specific byte range
Write-Detail -Message "Bytes at offset ${Offset}: $([System.BitConverter]::ToString($Data[$Offset..($Offset+7)]))" -Level Debug

# Show calculated vs actual values
Write-Detail -Message "Expected offset: $Expected, Actual: $Offset, Difference: $($Offset - $Expected)" -Level Debug

# Validate string extraction
Write-Detail -Message "String length field: $Length, Available bytes: $($Data.Length - $Offset)" -Level Debug
```

#### 7. Version Control Best Practices

**When modifying this script:**
1. **Update version comments** - Document what changed and why
2. **Test with multiple registry states:**
   - Direct connection only
   - Proxy enabled
   - Auto config enabled
   - Auto detect enabled
   - Combinations of above
3. **Verify backward compatibility** - Don't break existing binary format support
4. **Document new fields** - If binary structure changes, update documentation

#### 8. Common Pitfalls to Avoid

❌ **Don't hardcode offsets** - Structure is variable-length, always calculate
```powershell
# WRONG
$ProxyServer = $Data[12..50]

# CORRECT
$Offset = 8
$ProxyLength = Read-UInt32FromBytes -Data $Data -Start $Offset -Offset 0
$Offset += 4
if ($ProxyLength -gt 0) {
    $ProxyServer = $Data[$Offset..($Offset + $ProxyLength - 1)]
}
```

❌ **Don't assume string lengths** - Always read length field first
```powershell
# WRONG
$ProxyServer = [System.Text.Encoding]::ASCII.GetString($Data[12..63])

# CORRECT
$Length = Read-UInt32FromBytes -Data $Data -Start $Offset -Offset 0
if ($Length -gt 0) {
    $ProxyServer = [System.Text.Encoding]::ASCII.GetString($Data[$Offset..($Offset+$Length-1)])
}
```

❌ **Don't skip validation** - Binary data can be malformed
```powershell
# WRONG
$Value = [System.BitConverter]::ToUInt32($Data, $Offset)

# CORRECT
if (($Offset + 4) -gt $Data.Length) {
    Write-Detail -Message "Not enough bytes at offset $Offset" -Level Error
    return $null
}
$Value = [System.BitConverter]::ToUInt32($Data, $Offset)
```

❌ **Don't modify flags without understanding implications**
```powershell
# Each flag bit has specific meaning
# Setting incompatible combinations can cause issues
# Example: DirectConnection typically means NO other options enabled
```

#### 9. Testing Modifications

**Before committing changes:**
1. Test with virgin registry data (fresh Windows install state)
2. Test with all flags enabled
3. Test with all flags disabled
4. Test with long strings (proxy bypass with many entries)
5. Test with empty strings (zero-length fields)
6. Verify encode → decode → encode produces identical binary data

**Test data sources:**
```powershell
# Export current settings for testing
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
$Data = Get-ItemProperty -Path $RegPath -Name "DefaultConnectionSettings"
$Bytes = $Data.DefaultConnectionSettings
$Bytes | Out-File -FilePath "test-registry-data.bin" -Encoding Byte
```

#### 10. Security Considerations

- **Registry modification risks** - Incorrect binary data can corrupt settings
- **Backup importance** - Always create backups before modifications
- **Administrative privileges** - Required for registry writes
- **No credential handling** - This script doesn't handle proxy credentials
- **Local user context** - Operates on HKCU (current user) only

#### 11. Performance Considerations

**Binary parsing performance:**
- Script processes small data structures (<1KB typically)
- No optimization needed for performance
- Clarity and safety > speed in this context

**Registry operations:**
- Registry reads/writes are fast (milliseconds)
- Backup export is slowest operation (seconds)
- No caching needed

#### 12. Integration with Other Scripts

This script is **standalone** and doesn't integrate with other PSCode scripts, but the patterns used here are relevant for:

- **Other registry manipulation scripts**
- **Binary protocol parsing tasks**
- **Configuration management utilities**

**Reusable components:**
- `Write-Detail` function (consistent with parent repo)
- `Read-UInt32FromBytes` pattern (any binary parsing)
- Hex dump display code (debugging binary data)
- Registry backup pattern (any registry modification)

---

## Script-Specific Technical Notes

### DefaultConnectionSettings Version Counter

The version/counter field (bytes 0-3) increments with each modification:
- **Purpose:** Unknown (possibly for change detection)
- **Behavior:** Script increments by 1 on each modification
- **Typical values:** 46-100 (varies by system and modification count)

### Flag Behavior Observations

**DirectConnection (0x01):**
- Usually set when no proxy/auto config/auto detect is enabled
- Can coexist with other flags but typically indicates fallback

**ProxyEnabled (0x02):**
- Requires ProxyServer string to be set
- ProxyBypass is optional

**AutoConfigEnabled (0x04):**
- Requires AutoConfigURL to be set (typically .pac file)
- Can coexist with direct connection

**AutoDetectEnabled (0x08):**
- Uses WPAD (Web Proxy Auto-Discovery) protocol
- No additional data fields required

### Known Binary Structure Variations

**Variation 1:** Auto config URL at offset 21-24 (seen in some Windows versions)
**Variation 2:** Auto config URL at offset 20-23 (seen in other Windows versions)

**Script handles both by:**
- Sequential parsing rather than fixed offsets
- Sanity checking length values (>1000 = likely error)
- Debug logging to identify structure

---

## Quick Reference Commands

### Decode Current Settings (Read-Only)
```powershell
.\defaultproxysettings.ps1
# Answer 'n' when prompted for modifications
```

### Modify Settings Interactively
```powershell
.\defaultproxysettings.ps1
# Answer 'y' when prompted, then follow interactive prompts
```

### Export Registry for Testing
```powershell
reg export "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" proxy-settings-backup.reg
```

### Restore from Backup
```powershell
reg import "DefaultConnectionSettings_backup_20251118_103045.reg"
```

### Manual Registry Read
```powershell
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
$Data = Get-ItemProperty -Path $RegPath -Name "DefaultConnectionSettings"
$Data.DefaultConnectionSettings | Format-Hex
```

---

## Related Documentation

### Microsoft Documentation
- Internet Explorer Proxy Settings: Various registry keys control IE behavior
- Windows Proxy Configuration: System-wide settings in HKCU
- Binary Registry Values: REG_BINARY type handling

### PowerShell Documentation
- `System.BitConverter` - Binary conversion methods
- `System.Text.Encoding.ASCII` - String encoding/decoding
- `Get-ItemProperty` / `Set-ItemProperty` - Registry manipulation

### Binary Format References
- Little-Endian Encoding: Least significant byte first
- DWORD: 4-byte unsigned integer (0 to 4,294,967,295)
- Null-Terminated Strings: String ending with 0x00 byte

---

## Changelog

### 2025-11-18 - Initial CLAUDE.md Creation
- Comprehensive documentation of defaultproxysettings.ps1
- Binary structure format documentation
- Function reference with correct syntax
- AI assistant guidelines for binary parsing
- Testing and debugging guidance

### Recent Script Updates (from git history)
- **2025-11-18** - Update Default Proxy string decoder
  - Improved Read-UInt32FromBytes function
  - Enhanced bounds checking
  - Fixed offset calculation issues

---

## Contact and Contributions

### Repository Owner
**GitHub:** MatthewCKelly/PSCode

### Contributing Guidelines
1. Test modifications with multiple registry states
2. Verify encode/decode round-trip integrity
3. Update binary structure documentation if format changes
4. Include debug logging for new parsing logic
5. Create registry backups before testing

### Issue Reporting
When reporting issues with this script, include:
- Windows version (Get-ComputerInfo | Select-Object WindowsVersion)
- PowerShell version ($PSVersionTable)
- Hex dump of registry value (first 64 bytes)
- Full error message and line number
- Expected vs actual behavior

---

**End of CLAUDE.md**

*This document is maintained for AI assistants working on the PSCode/Dev directory. Keep it updated as scripts evolve.*
