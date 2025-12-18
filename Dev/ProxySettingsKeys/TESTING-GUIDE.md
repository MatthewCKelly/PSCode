# Proxy Settings Testing Guide

## Overview

This guide explains how to use the automated test runners to execute all Windows proxy settings test cases and collect registry exports for validation.

---

## Available Tools

### 1. **Run-ProxyTests.cmd** (Batch File - Recommended)
Full-featured interactive test runner that works without PowerShell execution policy changes. Includes progress tracking, batch processing, and automatic decoder execution.

### 2. **run-single-test.cmd** (Batch File - Simple)
Simple batch file for running individual test cases one at a time.

### 3. **Run-ProxyTests.ps1** (PowerShell - Alternative)
PowerShell version with same features. Requires execution policy to be set.

---

## Quick Start

### Option A: Run All Tests (Batch File - Recommended)

```cmd
cd Dev\ProxySettingsKeys
Run-ProxyTests.cmd
```

This will:
- ✅ Run all 62 test cases interactively
- ✅ Display instructions for each test
- ✅ Launch Internet Options automatically
- ✅ Export registry after each configuration
- ✅ Save all results to `TestResults` folder
- ✅ Track progress in `test-progress.txt`
- ✅ Optionally run decoder when complete
- ✅ **No PowerShell execution policy required!**

### Option B: Run Single Test (Batch File)

```cmd
cd Dev\ProxySettingsKeys
run-single-test.cmd TC-101
```

### Option C: Run All Tests (PowerShell - Alternative)

```powershell
cd Dev/ProxySettingsKeys
.\Run-ProxyTests.ps1
```

**Note:** Requires PowerShell execution policy to be set:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## PowerShell Script Usage

### Basic Commands

**Run all tests:**
```powershell
.\Run-ProxyTests.ps1
```

**Run specific test:**
```powershell
.\Run-ProxyTests.ps1 -TestID TC-101
```

**Start from specific test:**
```powershell
.\Run-ProxyTests.ps1 -StartFrom TC-205
```

**Skip tests that already have .reg files:**
```powershell
.\Run-ProxyTests.ps1 -SkipExisting
```

**Custom output folder:**
```powershell
.\Run-ProxyTests.ps1 -OutputFolder "C:\ProxyTests\Exports"
```

**Combine parameters:**
```powershell
.\Run-ProxyTests.ps1 -StartFrom TC-201 -SkipExisting -OutputFolder ".\Results"
```

---

## Step-by-Step Test Execution

### What Happens During Each Test:

1. **Test Instructions Display**
   ```
   ================================================================================
     PROXY SETTINGS TEST RUNNER
   ================================================================================

     Test Progress: 1 of 62

     Test ID:   TC-101
     Test Name: Simple Proxy IP:Port

   ================================================================================

   CONFIGURATION INSTRUCTIONS:

     • 'Use same proxy' checked
     • HTTP: 192.168.1.101:8080

   ================================================================================

   EXPECTED RESULT:

     ✓ ProxyServer = 192.168.1.101:8080

   ================================================================================
   ```

2. **Press ENTER** to open Internet Options

3. **Internet Options Opens** to Connections tab automatically

4. **Click "LAN settings"** button

5. **Configure proxy** as shown in instructions:
   - Check/uncheck boxes
   - Enter proxy addresses
   - Enter bypass lists
   - Configure PAC URLs

6. **Click OK** on all dialogs to save

7. **Return to terminal** and press ENTER

8. **Registry Export** happens automatically

9. **Confirmation** displayed:
   ```
   ================================================================================
     ✓ TEST TC-101 COMPLETED SUCCESSFULLY
   ================================================================================

   Output saved to: .\TestResults\TC-101-SimpleProxy-IP-Port.reg
   ```

10. **Press any key** to continue to next test

---

## Interactive Controls

During test execution, you'll be prompted with these options:

### Main Prompt:
```
Ready to configure test TC-101? [Y/N/S/Q] (default: Y):
```

- **Y** (Yes) - Proceed with this test
- **N** (No) - Skip this test
- **S** (Skip) - Skip and move to next test
- **Q** (Quit) - Exit test runner

### After Export Prompt:
```
Run decoder on all exported files? [Y/N] (default: Y):
```

- **Y** - Run `Read-ProxyRegistryFiles.ps1` on all exported files
- **N** - Exit without running decoder

---

## Test Progress Tracking

The script automatically saves progress to `test-progress.json`:

```json
{
  "Tests": {
    "TC-101": {
      "Status": "Completed",
      "OutputFile": ".\\TestResults\\TC-101-SimpleProxy-IP-Port.reg",
      "Timestamp": "2025-12-17 14:32:15"
    },
    "TC-102": {
      "Status": "Skipped",
      "OutputFile": "",
      "Timestamp": "2025-12-17 14:33:42"
    }
  }
}
```

Use `-SkipExisting` to resume testing without redoing completed tests.

---

## Output Files

All exported `.reg` files are saved to the output folder with this naming format:

```
TC-001-DirectConnectionOnly.reg
TC-101-SimpleProxy-IP-Port.reg
TC-205-AllProtocolsDifferent.reg
TC-505-PAC-QueryParams.reg
```

### Folder Structure:
```
ProxySettingsKeys/
├── TestResults/              # All exported .reg files
│   ├── TC-001-DirectConnectionOnly.reg
│   ├── TC-101-SimpleProxy-IP-Port.reg
│   ├── TC-102-SimpleProxy-Hostname.reg
│   └── ...
├── test-progress.json        # Progress tracking
├── Run-ProxyTests.ps1        # Main test runner
├── run-single-test.cmd       # Single test batch file
└── TEST-MATRIX.csv           # Test case definitions
```

---

## Batch File Usage

### Run a Single Test:

```cmd
run-single-test.cmd TC-101
```

### What It Does:

1. ✅ Creates `TestResults` folder if needed
2. ✅ Checks if output file already exists (asks to overwrite)
3. ✅ Displays test instructions
4. ✅ Opens Internet Options to Connections tab
5. ✅ Waits for you to configure and press a key
6. ✅ Exports registry to `.reg` file
7. ✅ Verifies export succeeded
8. ✅ Optionally runs decoder

### Example Session:

```
C:\PSCode\Dev\ProxySettingsKeys> run-single-test.cmd TC-101

============================================================================
 PROXY SETTINGS TEST RUNNER
============================================================================

 Test ID: TC-101

============================================================================

INSTRUCTIONS:

 1. The Internet Options dialog will open to the Connections tab
 2. Click the "LAN settings" button
 3. Configure proxy settings for test case TC-101
 4. Click OK to close all dialogs
 5. Return to this window and press any key

============================================================================

Press any key to open Internet Options...

Opening Internet Options (Connections tab)...

Configure the proxy settings, then press any key when ready to export...

============================================================================
 EXPORTING REGISTRY SETTINGS
============================================================================

 Source: HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections
 Target: TestResults\TC-101.reg

The operation completed successfully.

============================================================================
 SUCCESS: Registry exported successfully!
============================================================================

 File: TestResults\TC-101.reg
 Size: 1523 bytes

============================================================================

Run decoder on this file (Y/N)? Y

Running decoder...
[Decoder output...]
```

---

## Tips for Efficient Testing

### 1. **Test in Batches**

Break testing into logical groups:

```powershell
# Basic configurations (5 tests)
.\Run-ProxyTests.ps1 -TestID TC-001
.\Run-ProxyTests.ps1 -TestID TC-002
# ... or ...
.\Run-ProxyTests.ps1 -StartFrom TC-001 # (will prompt for each)

# Single proxy tests (TC-101 to TC-105)
.\Run-ProxyTests.ps1 -StartFrom TC-101 -SkipExisting

# Protocol-specific tests (TC-201 to TC-207)
.\Run-ProxyTests.ps1 -StartFrom TC-201 -SkipExisting

# Bypass lists (TC-301 to TC-309)
.\Run-ProxyTests.ps1 -StartFrom TC-301 -SkipExisting
```

### 2. **Resume After Interruption**

If you need to stop and resume later:

```powershell
# First session - complete TC-001 through TC-105
.\Run-ProxyTests.ps1

# Later session - skip completed tests and continue
.\Run-ProxyTests.ps1 -SkipExisting
```

### 3. **Verify Exports Immediately**

After each batch, run the decoder:

```powershell
..\Read-ProxyRegistryFiles.ps1 -FolderPath .\TestResults
```

This lets you catch any configuration errors early!

### 4. **Keep Notes**

For each test, document:
- ✅ Any unexpected behavior
- ✅ Differences from expected values
- ✅ Windows version and build
- ✅ Screenshots of unusual configurations

### 5. **Backup Your Proxy Settings First**

Before starting testing, export your current settings:

```cmd
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" MyOriginalSettings.reg
```

To restore later:
```cmd
reg import MyOriginalSettings.reg
```

---

## Validation Workflow

### After Running Tests:

1. **Run Decoder on All Files**
   ```powershell
   ..\Read-ProxyRegistryFiles.ps1 -FolderPath .\TestResults
   ```

2. **Review Output**
   - Check that all flags match expected values
   - Verify ProxyServer strings are correct
   - Confirm ProxyBypass lists parsed correctly
   - Validate AutoConfigURL extracted properly

3. **Compare Against TEST-MATRIX.csv**
   ```powershell
   # Import both for comparison
   $tests = Import-Csv .\TEST-MATRIX.csv
   $results = Import-Csv .\TestResults\decoded-results.csv  # if you export from decoder

   # Compare
   Compare-Object $tests $results -Property 'Test ID','Expected Behavior'
   ```

4. **Update Test Status**
   - Mark tests as PASS/FAIL in tracking spreadsheet
   - Document any discrepancies
   - File issues for failed tests

---

## Troubleshooting

### Internet Options Won't Open

**Problem:** Script reports "Failed to open Internet Options"

**Solution:**
```powershell
# Try opening manually:
rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl,,4

# Or use control panel directly:
control.exe inetcpl.cpl
```

### Registry Export Fails

**Problem:** "Registry export failed" error

**Solution:**
- Ensure you have permissions to write to output folder
- Check registry path exists:
  ```cmd
  reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
  ```
- Run as Administrator if needed

### File Already Exists

**Problem:** Output file exists from previous run

**Solution:**
- Use `-SkipExisting` to skip these tests
- Or delete the `TestResults` folder to start fresh:
  ```powershell
  Remove-Item .\TestResults -Recurse -Force
  ```

### Decoder Script Not Found

**Problem:** "Cannot find decoder script"

**Solution:**
- Ensure `Read-ProxyRegistryFiles.ps1` exists in parent folder:
  ```
  Dev/
  ├── Read-ProxyRegistryFiles.ps1  ← Should be here
  └── ProxySettingsKeys/
      └── Run-ProxyTests.ps1
  ```

### Progress Lost

**Problem:** Need to start over but progress file exists

**Solution:**
```powershell
# Delete progress file to reset
Remove-Item .\test-progress.json

# Or manually edit it to mark tests as incomplete
```

---

## Advanced Usage

### Custom Test Subset

Create a custom CSV with just the tests you want:

```powershell
# Extract specific tests
$allTests = Import-Csv .\TEST-MATRIX.csv
$subset = $allTests | Where-Object { $_.'Test ID' -like 'TC-2*' }
$subset | Export-Csv .\MyTests.csv -NoTypeInformation

# Modify script to use custom CSV (line ~125):
# $csvPath = Join-Path $PSScriptRoot "MyTests.csv"
```

### Automated Testing (No Prompts)

For CI/CD or automated testing, you would need to:
1. Pre-configure proxy settings programmatically
2. Remove interactive prompts
3. Export registry automatically

**Note:** This is advanced and not covered by current scripts.

### Export to Different Formats

After running decoder, convert results:

```powershell
# Export to JSON
$results | ConvertTo-Json | Out-File results.json

# Export to HTML report
$results | ConvertTo-Html | Out-File results.html

# Export to Excel (requires ImportExcel module)
$results | Export-Excel results.xlsx
```

---

## Best Practices

### ✅ DO:
- Run tests in logical groups (basic, single proxy, multi-protocol, etc.)
- Use `-SkipExisting` when resuming sessions
- Validate results immediately after each batch
- Document any unexpected behavior
- Keep original proxy settings backed up
- Take screenshots of complex configurations

### ❌ DON'T:
- Run all 62 tests in one sitting (it's tedious!)
- Skip validation until all tests are done
- Forget to document edge cases
- Mix test sessions without tracking progress
- Modify .reg files manually (breaks validation)

---

## Example Testing Session

### Complete Workflow:

```powershell
# 1. Backup current settings
cd Dev\ProxySettingsKeys
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" .\MyBackup.reg

# 2. Run basic tests first (TC-001 to TC-005)
.\Run-ProxyTests.ps1 -StartFrom TC-001
# Complete first 5 tests...
# (Press Q to quit after TC-005)

# 3. Validate basic tests
..\Read-ProxyRegistryFiles.ps1 -FolderPath .\TestResults

# 4. Continue with single proxy tests
.\Run-ProxyTests.ps1 -StartFrom TC-101 -SkipExisting
# Complete TC-101 through TC-105
# (Press Q after TC-105)

# 5. Validate again
..\Read-ProxyRegistryFiles.ps1 -FolderPath .\TestResults

# 6. Take a break! 😊

# 7. Resume with protocol-specific tests
.\Run-ProxyTests.ps1 -StartFrom TC-201 -SkipExisting
# Continue...

# 8. Final validation
..\Read-ProxyRegistryFiles.ps1 -FolderPath .\TestResults -OutputFormat Grid

# 9. Restore original settings
reg import .\MyBackup.reg
```

---

## Summary

The automated test runners make it easy to:
- ✅ Execute all 62 test cases systematically
- ✅ Track progress and resume testing
- ✅ Validate decoder scripts against real data
- ✅ Document test results
- ✅ Identify edge cases and bugs

Choose the right tool for your needs:
- **PowerShell script**: Full automation, batch processing, progress tracking
- **Batch file**: Quick single-test runs, simple usage

Happy testing! 🎯

---

**Questions or Issues?**
- Check TEST-PLAN.md for test case details
- Review UI-MAPPING-REFERENCE.md for configuration guidance
- See README.md for general project information
