# Proxy Settings Test Files

This folder contains registry exports (`.reg` files) used for testing the DefaultConnectionSettings decoder.

## How to Add Test Files

### 1. Export Current Settings

On a Windows machine, export your current proxy settings:

```cmd
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" CurrentSettings.reg
```

### 2. Export Different Scenarios

Create different proxy configurations in Windows and export each:

**Example scenarios to test:**
- **DirectConnection.reg** - No proxy, direct connection only
- **ProxyEnabled.reg** - Manual proxy server configured
- **AutoConfig.reg** - Automatic configuration script (PAC file)
- **AutoDetect.reg** - Automatic proxy detection enabled
- **ProxyWithBypass.reg** - Proxy with bypass list
- **Combined.reg** - Multiple settings enabled

### 3. Naming Convention

Use descriptive names that indicate what the test file contains:
- `DirectConnection-NoProxy.reg`
- `Proxy-192-168-1-1-8080.reg`
- `AutoConfig-WebDefence.reg`
- `AutoDetect-WPAD.reg`

## Test File Format

The `.reg` files should contain the `DefaultConnectionSettings` binary value:

```
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections]
"DefaultConnectionSettings"=hex:46,00,00,00,4a,01,00,00,01,00,00,00,00,00,00,00,\
  01,00,00,00,20,42,00,00,00,68,74,74,70,3a,2f,2f,77,65,62,64,65,66,65,6e,63,\
  65,2e,67,6c,6f,62,61,6c,2e,62,6c,61,63,6b,73,70,69,64,65,72,2e,63,6f,6d,3a,\
  ...
```

## Running Tests

Once you've added `.reg` files to this folder, run the test script:

```powershell
.\Test-ProxySettingsDecoder.ps1
```

With verbose output:

```powershell
.\Test-ProxySettingsDecoder.ps1 -Verbose
```

## What the Tests Validate

The test harness checks:
- ✅ Binary data extraction from .reg files
- ✅ Correct parsing of version and flags
- ✅ Proper decoding of proxy server settings
- ✅ Correct parsing of proxy bypass lists
- ✅ Accurate extraction of auto config URLs
- ✅ Unknown field handling
- ✅ String length validation
- ✅ Null terminator removal
- ✅ Offset tracking accuracy

## Sample Test Files

You can create sample test files manually for edge cases:

### Minimal Direct Connection

Create a file with just the basic structure (no proxy/autoconfig):
```
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections]
"DefaultConnectionSettings"=hex:46,00,00,00,01,00,00,00,00,00,00,00,00,00,00,00,\
  00,00,00,00,00,00,00,00
```

### With Proxy Server

Test file with proxy configured:
```
"DefaultConnectionSettings"=hex:46,00,00,00,03,00,00,00,15,00,00,00,70,72,6f,78,\
  79,2e,65,78,61,6d,70,6c,65,2e,63,6f,6d,3a,38,30,38,30,00,00,00,00,00,00,00,\
  00,00,00,00,00,00
```

## Contributing Test Cases

If you find edge cases or bugs:
1. Export the problematic registry settings
2. Add the `.reg` file to this folder with a descriptive name
3. Document what makes it special in the filename or a comment
4. Run the tests to verify the issue

## Current Test Coverage

Add your test files here to improve coverage of different scenarios.
