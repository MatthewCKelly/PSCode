# CLAUDE.md - AI Assistant Guide for PSCode Repository

> **Last Updated:** 2025-11-20
> **Repository:** PSCode - PowerShell Utility Scripts Collection

---

## Table of Contents
1. [Repository Overview](#repository-overview)
2. [Codebase Structure](#codebase-structure)
3. [Development Workflows](#development-workflows)
4. [Key Scripts Reference](#key-scripts-reference)
5. [Common Patterns & Conventions](#common-patterns--conventions)
6. [Configuration Management](#configuration-management)
7. [Testing & Deployment](#testing--deployment)
8. [AI Assistant Guidelines](#ai-assistant-guidelines)

---

## Repository Overview

### Purpose
**PSCode** is a collection of PowerShell automation scripts designed for:
- **Outlook Signature Management** - Dynamic email signatures with work location status tables
- **RSS/Torrent Processing** - Automated Plex media library management
- **LiquidFiles Integration** - Secure file transfer via REST API
- **Serial Communication** - GPS/NMEA data logging and terminal emulation
- **System Utilities** - Screen lock detection and other Windows utilities

### Technology Stack
- **Language:** PowerShell 5.1+ (100%)
- **Framework:** .NET Framework
- **Dependencies:** Windows Forms, System.IO.Ports
- **External APIs:** Plex Media Server, LiquidFiles
- **Total Lines of Code:** ~3,854 lines

### Project Statistics
```
PowerShell Scripts: 6 main files
Configuration Templates: 2 files
Total Scripts LOC: 3,854 lines
Largest Script: Add-WeektoSignature.ps1 (1,949 lines)
```

---

## Codebase Structure

```
PSCode/
├── Serial/                              # Serial communication module
│   └── CheckComm.ps1                   # GPS/NMEA terminal & logger (449 lines)
│
├── Add-WeektoSignature.ps1             # Outlook signature manager (1,949 lines)
├── RssDownloadandStart-v2.ps1          # Torrent/Plex integration (566 lines)
├── Test-LiquidFilesAccess.ps1          # LiquidFiles API tester (420 lines)
├── Upload-ToLiquidFiles.ps1            # LiquidFiles uploader (475 lines)
├── isScreenLocked                       # Screen lock utility (30 lines)
│
├── liquidfiles-config.json.template     # LiquidFiles configuration template
├── rss-TorrentProcessor-config.json.sample # Torrent config template
│
├── .gitignore                          # Protects config files & credentials
└── README.md                           # Basic project description
```

### Directory Organization
- **Root Directory:** Standalone utility scripts
- **Serial/:** Serial port communication scripts (GPS, NMEA, hardware)
- **Configuration Files:** JSON templates with `.template` or `.sample` suffix
- **Actual Configs:** Git-ignored (must be created from templates)

---

## Development Workflows

### Git Branching Strategy
- **Main Branch:** `main` (production-ready code)
- **Feature Branches:** `claude/[feature-description]-[session-id]`
- **Branch Naming:** Always prefix with `claude/` and include session ID

### Recent Development Activity
Based on recent commits:
```
✓ Serial communication improvements (COM port handling)
✓ GPS data CSV logging functionality
✓ Outlook signature form layout enhancements
✓ LiquidFiles authentication fixes (HTTP Basic Auth)
✓ Form resizing capabilities
✓ API integration testing scripts
```

### Commit Message Conventions
- **Format:** Descriptive imperative mood ("Add feature" not "Added feature")
- **Examples from repo:**
  - "Fix COM port parameter handling and serial communication reliability"
  - "Add CSV logging for GPS coordinates in CheckComm.ps1"
  - "Fix authentication to use HTTP Basic Auth with base64 encoding"

### Pull Request Workflow
1. Develop on `claude/[feature]-[session-id]` branch
2. Commit with descriptive messages
3. Push to origin with `-u` flag
4. Create PR to `main` branch
5. Merge after review

---

## Key Scripts Reference

### 1. Add-WeektoSignature.ps1 (1,949 lines)
**Purpose:** Outlook email signature manager with dynamic work status tables

**Key Features:**
- Windows Forms GUI for day selection (1-14 days)
- AM/PM split mode for granular scheduling
- Status options: Office, WFH, Leave, Meeting, Training, Travel, Client Site
- HTML and plain text signature generation
- Registry-based configuration persistence at `HKCU:\Software\OutlookSignatureManager`
- Backup system for existing signatures
- Real-time HTML/text preview
- MSO tag cleanup for clean HTML

**Important Functions:**
- `Show-SignatureForm` - Main GUI entry point
- `Update-TablePreview` - Real-time signature preview
- `Generate-SignatureFiles` - Creates HTML/TXT signatures
- `Save-ToRegistry` / `Load-FromRegistry` - Configuration persistence
- `Get-NextWeekdates` - Date calculation logic

**Configuration Storage:** Windows Registry (HKCU)

**File Locations:**
- Signatures: `%APPDATA%\Microsoft\Signatures\`
- Backups: `%APPDATA%\Microsoft\Signatures\Backup\`

---

### 2. RssDownloadandStart-v2.ps1 (566 lines)
**Purpose:** Automated torrent downloader for Plex media library

**Key Features:**
- RSS feed monitoring for TV show episodes
- Plex API integration (checks existing content)
- Downloads only missing episodes
- Rate limiting and retry logic
- Network path validation
- Delegation token authentication

**Classes:**
```powershell
class PlexMedia {
    [string]$Title
    [int]$Season
    [int]$Episode
}

class TorrentItem {
    [string]$Title
    [string]$Link
    [DateTime]$PubDate
}
```

**Required Config:** `rss-TorrentProcessor-config.json`

**Important Functions:**
- `Get-PlexLibraryContent` - Fetches existing media
- `Get-TorrentFeed` - Parses RSS feed
- `Download-Torrent` - Downloads .torrent files
- `Test-NetworkPath` - Validates UNC paths

---

### 3. Upload-ToLiquidFiles.ps1 (475 lines)
**Purpose:** Secure file upload to LiquidFiles via REST API

**Key Features:**
- Single or multiple file uploads
- Recipient email notifications
- Multipart form-data encoding
- HTTP Basic Authentication (base64)
- Custom subject and message
- Filelink creation with expiration

**Required Config:** `liquidfiles-config.json`

**Authentication Method:** HTTP Basic Auth
```powershell
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($apiKey):"))
$headers = @{ Authorization = "Basic $base64Auth" }
```

**API Endpoints:**
- `/message` - Create new message
- `/message/{id}/attach` - Upload files
- `/message/{id}/send` - Send notification

---

### 4. Test-LiquidFilesAccess.ps1 (420 lines)
**Purpose:** API connectivity testing and validation

**Parameter Sets:**
```powershell
# Test connection
.\Test-LiquidFilesAccess.ps1

# List messages
.\Test-LiquidFilesAccess.ps1 -ListMessages

# List filelinks
.\Test-LiquidFilesAccess.ps1 -ListFilelinks

# Get specific file
.\Test-LiquidFilesAccess.ps1 -FileId "abc123"

# Get account info
.\Test-LiquidFilesAccess.ps1 -GetAccount
```

**Use Cases:**
- Verify API connectivity before uploads
- Debug authentication issues
- Inspect message/filelink details
- Validate configuration files

---

### 5. Serial/CheckComm.ps1 (449 lines)
**Purpose:** Serial port terminal with GPS/NMEA data logging

**Key Features:**
- Serial port terminal emulator
- NMEA 0183 GPS sentence parsing (GGA, RMC, GLL, GSA, GSV, VTG)
- GPS coordinate conversion (NMEA → decimal degrees)
- CSV logging for GPS track recording
- Interactive keyboard input (arrow keys, delete, home, end)
- COM port selection GUI
- Configurable baud rate and data bits

**Default Configuration:**
```powershell
Port: COM3 (or user-selected via GUI)
Baud Rate: 4800
Data Bits: 8
```

**GPS Data Logged to CSV:**
- Timestamp
- Latitude (decimal degrees)
- Longitude (decimal degrees)
- Altitude (meters)
- Speed (knots)
- Course (degrees)
- Satellites in use
- Fix quality
- HDOP (horizontal dilution)

**NMEA Sentences Parsed:**
- `$GPGGA` - Global Positioning System Fix Data
- `$GPRMC` - Recommended Minimum Navigation Information
- `$GPGLL` - Geographic Position (Lat/Lon)
- `$GPGSA` - GPS DOP and Active Satellites
- `$GPGSV` - GPS Satellites in View
- `$GPVTG` - Track Made Good and Ground Speed

**Important Functions:**
- `Convert-NMEAToDecimal` - Coordinate conversion
- `Parse-NMEASentence` - GPS data extraction
- `Select-COMPort` - GUI port selection

---

### 6. isScreenLocked (30 lines)
**Purpose:** Utility function to detect Windows screen lock state

**Returns:** Boolean indicating lock state + Process object if locked

**Usage:**
```powershell
. .\isScreenLocked
$locked = Test-ScreenLock
if ($locked) { Write-Host "Screen is locked" }
```

---

## Common Patterns & Conventions

### Standardized Logging Function
All scripts use `Write-Detail` function with consistent format:

```powershell
function Write-Detail {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $caller = (Get-PSCallStack)[1]
    $lineNumber = $caller.ScriptLineNumber

    # Color-coded output based on level
    # Timestamp + Level + Line Number + Message
}
```

**Log Levels:**
- `Info` - General information (Gray/White)
- `Success` - Successful operations (Green)
- `Warning` - Non-critical issues (Yellow)
- `Error` - Critical failures (Red)
- `Debug` - Verbose debugging (Cyan/DarkGray)

**IMPORTANT - Write-Detail Usage:**
- ❌ **NEVER** use `Write-Detail ""` with an empty string - this will fail
- ❌ **NEVER** use `Write-Detail ""` for blank lines in output
- ❌ **NEVER** use `Write-Detail "=" * 80` - the string multiplication won't evaluate
- ✅ **ALWAYS** use `Write-Host ""` for blank lines instead
- ✅ **ALWAYS** use `Write-Detail ("=" * 80)` with parentheses for expression evaluation
- The `$Message` parameter in `Write-Detail` is marked as `[Parameter(Mandatory = $true)]`
- Empty strings will cause parameter validation errors
- String expressions must be evaluated before being passed to the function

**Example - Correct Usage:**
```powershell
Write-Detail "Processing started" -Level Info
Write-Host ""  # Blank line for readability
Write-Detail ("=" * 80) -Level Info  # String separator line (parentheses evaluate expression)
Write-Detail "Next step" -Level Info
```

**Example - INCORRECT Usage:**
```powershell
Write-Detail "Processing started" -Level Info
Write-Detail ""  # ❌ THIS WILL FAIL - Mandatory parameter cannot be empty
Write-Detail "=" * 80  # ❌ THIS WILL FAIL - Outputs literal '= * 80' text, not 80 equals signs
Write-Detail "Next step" -Level Info
```

### Error Handling Pattern
```powershell
try {
    # Main operation
    Write-Detail "Starting operation..." -Level Info

    # Perform work

    Write-Detail "Operation completed successfully" -Level Success
}
catch {
    Write-Detail "Error occurred: $($_.Exception.Message)" -Level Error
    Write-Detail "Stack trace: $($_.ScriptStackTrace)" -Level Debug
    throw  # Re-throw if needed
}
finally {
    # Cleanup resources
}
```

### Configuration Validation Pattern
```powershell
if (-not (Test-Path $configPath)) {
    throw "Configuration file not found: $configPath"
}

$config = Get-Content $configPath | ConvertFrom-Json

# Validate required fields
$requiredFields = @('ServerUrl', 'ApiKey')
foreach ($field in $requiredFields) {
    if (-not $config.$field) {
        throw "Missing required field in config: $field"
    }
}
```

### GUI Form Pattern (Windows Forms)
```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Application Title"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'Sizable'
$form.MinimumSize = New-Object System.Drawing.Size(600, 400)

# Add controls...

$form.ShowDialog()
```

### API Request Pattern
```powershell
$headers = @{
    'Authorization' = "Basic $base64Auth"
    'Content-Type' = 'application/json'
}

try {
    $response = Invoke-RestMethod `
        -Uri $url `
        -Method POST `
        -Headers $headers `
        -Body ($body | ConvertTo-Json -Depth 10) `
        -ErrorAction Stop

    return $response
}
catch {
    Write-Detail "API request failed: $($_.Exception.Message)" -Level Error
    throw
}
```

---

## Configuration Management

### Configuration File Types

#### 1. liquidfiles-config.json
**Location:** Root directory (git-ignored)
**Template:** `liquidfiles-config.json.template`

```json
{
  "ServerUrl": "https://your-server.liquidfiles.com",
  "ApiKey": "your-api-key-here",
  "DefaultExpirationDays": 7,
  "DefaultSubject": "File Transfer via LiquidFiles",
  "DefaultMessage": "Files have been shared with you via LiquidFiles"
}
```

**Used By:** `Upload-ToLiquidFiles.ps1`, `Test-LiquidFilesAccess.ps1`

#### 2. rss-TorrentProcessor-config.json
**Location:** Root directory (git-ignored)
**Template:** `rss-TorrentProcessor-config.json.sample`

```json
{
  "Plex": {
    "ServerUrl": "http://server:32400",
    "Token": "YOUR_PLEX_TOKEN_HERE",
    "LibraryId": 1
  },
  "Torrent": {
    "RssUrl": "https://rss-feed-url/feed.xml",
    "RateLimitMs": 500
  },
  "Paths": {
    "Download": "\\\\server\\share\\_ToGet\\Get",
    "Completed": "\\\\server\\share\\_ToGet\\Done"
  }
}
```

**Used By:** `RssDownloadandStart-v2.ps1`

### .gitignore Protection
The following patterns are protected from git commits:
```
liquidfiles-config.json
*-config.json
!*-config.json.sample
!*-config.json.template
*.log
*.tmp
*.temp
```

### Configuration Best Practices
1. **Never commit actual credentials** - Use templates only
2. **Validate configs on script startup** - Check required fields
3. **Provide helpful error messages** - Guide users to create configs
4. **Use relative paths when possible** - Improve portability
5. **Document all configuration options** - In templates and code comments

---

## Testing & Deployment

### Testing Strategy
**No formal unit testing framework** - Testing is primarily manual/interactive

**Available Test Scripts:**
- `Test-LiquidFilesAccess.ps1` - API connectivity and validation
- Manual testing via script execution

**Testing Checklist for New Features:**
- [ ] Script executes without syntax errors
- [ ] Configuration files load correctly
- [ ] Error handling works (test invalid inputs)
- [ ] Log output is clear and helpful
- [ ] GUI elements render correctly (if applicable)
- [ ] API calls succeed with valid credentials
- [ ] Script cleans up resources on exit

### Deployment Process
**Scripts are standalone executables** - No build process required

**Deployment Steps:**
1. Copy scripts to target directory
2. Create configuration files from templates:
   ```powershell
   Copy-Item liquidfiles-config.json.template liquidfiles-config.json
   # Edit with actual credentials
   ```
3. Update configurations with actual credentials/paths
4. Test script execution
5. Schedule via Task Scheduler (if needed)

### Prerequisites
- **PowerShell 5.1 or higher**
- **.NET Framework** (for Windows Forms)
- **API Keys/Tokens:**
  - LiquidFiles API key (for file transfer scripts)
  - Plex authentication token (for torrent processor)
- **Hardware Access:**
  - COM port access (for serial communication)
  - Network paths accessible (for torrent processor)

### Version History Pattern
Scripts include version numbers in comments:
```powershell
# Version 2.3 - 2024-11-16
# - Added form resizing capability
# - Improved panel layout
```

---

## AI Assistant Guidelines

### When Working on This Repository

#### 1. Understanding Context
- **Always read the entire script** before making changes
- **Check for version comments** at the top of files
- **Review recent git commits** to understand recent changes
- **Look for existing patterns** before introducing new ones

#### 2. Code Modification Principles
- **Preserve existing patterns** - Don't introduce new logging/error handling styles
- **Maintain backward compatibility** - Scripts may be in production use
- **Test configuration loading** - Ensure configs still work after changes
- **Update version comments** - Increment version numbers appropriately
- **Keep functions focused** - Follow single responsibility principle

#### 3. PowerShell-Specific Conventions
- **Use approved verbs** - `Get-`, `Set-`, `New-`, `Remove-`, etc.
- **PascalCase for functions** - `Get-PlexLibrary` not `get_plex_library`
- **camelCase for variables** - `$configPath` not `$config_path`
- **Parameter validation** - Use `[ValidateSet()]`, `[ValidateNotNullOrEmpty()]`
- **Proper scoping** - Be explicit about `$script:` or `$global:` when needed

#### 4. GUI Development (Windows Forms)
- **Always test resize behavior** - Forms should handle different screen sizes
- **Use anchoring/docking** - Controls should adapt to form size
- **Set minimum sizes** - Prevent unusable tiny windows
- **Center forms** - `StartPosition = "CenterScreen"`
- **Dispose resources** - Call `.Dispose()` on forms when done

#### 5. API Integration Best Practices
- **Use proper authentication** - Follow existing patterns (Basic Auth for LiquidFiles)
- **Include error handling** - APIs can fail, handle gracefully
- **Implement retry logic** - For transient network errors
- **Rate limiting** - Respect API limits (see torrent processor)
- **Validate responses** - Check status codes and response structure

#### 6. Serial Communication Guidelines
- **Always close ports** - Use try/finally to ensure cleanup
- **Handle port conflicts** - User-friendly errors if port is busy
- **Provide port selection** - Don't hardcode COM ports
- **Buffer management** - Handle data buffering for continuous streams
- **Encoding awareness** - Be explicit about text encoding (ASCII, UTF8, etc.)

#### 7. Configuration File Handling
- **Never create actual config files** - Only templates
- **Validate on load** - Check for required fields immediately
- **Provide clear error messages** - Tell users what's missing
- **Support relative paths** - Make scripts portable when possible
- **Document all options** - In templates and inline comments

#### 8. Logging and Debugging
- **Use Write-Detail consistently** - Don't mix with Write-Host
- **Include line numbers** - Helps with debugging
- **Log important operations** - API calls, file operations, config loading
- **Different levels** - Info for normal, Debug for verbose, Error for failures
- **Structured output** - Consistent timestamp and formatting

#### 9. Security Considerations
- **Never log credentials** - Sanitize log output
- **Use secure authentication** - HTTPS, proper auth headers
- **Validate file paths** - Prevent path traversal attacks
- **Handle credentials safely** - Use SecureString when appropriate
- **Git-ignore secrets** - Ensure configs are in .gitignore

#### 10. Git Workflow for AI Assistants
- **Branch naming:** Always use `claude/[feature]-[session-id]` format
- **Commit messages:** Clear, descriptive, imperative mood
- **One feature per branch** - Don't mix unrelated changes
- **Test before committing** - Ensure scripts still execute
- **Update version comments** - Reflect changes in version history

#### 11. Common Pitfalls to Avoid
- ❌ Don't hardcode credentials or API keys
- ❌ Don't break existing functionality when adding features
- ❌ Don't introduce dependencies without discussion
- ❌ Don't remove error handling to "simplify" code
- ❌ Don't commit actual configuration files
- ❌ Don't use `Write-Host` for logging (use `Write-Detail`)
- ❌ **Don't use `Write-Detail ""` with empty strings** (use `Write-Host ""` for blank lines)
- ❌ **Don't use `Write-Detail "=" * 80`** (use `Write-Detail ("=" * 80)` with parentheses)
- ❌ Don't leave resources (ports, files) unclosed
- ❌ Don't ignore existing code style/patterns

#### 12. What to Do When Stuck
1. **Read the existing code** - Patterns are already established
2. **Check git history** - See how similar problems were solved
3. **Test incrementally** - Small changes are easier to debug
4. **Ask for clarification** - If requirements are unclear
5. **Look for similar scripts** - Reuse patterns from other files

#### 13. Documentation Expectations
- **Inline comments** - For complex logic
- **Function headers** - Describe parameters and return values
- **Version history** - At top of file
- **Configuration examples** - In templates
- **This file (CLAUDE.md)** - Keep updated when architecture changes

---

## Script-Specific Notes

### Add-WeektoSignature.ps1
- **Complex UI** - 1,949 lines, mostly GUI code
- **Registry persistence** - All settings saved to registry
- **HTML generation** - Clean MSO tags, validate HTML output
- **Backup system** - Always backup before overwriting signatures
- **Testing tip** - Use test signature names during development

### RssDownloadandStart-v2.ps1
- **Plex dependency** - Requires valid Plex server and token
- **Network paths** - UNC paths must be accessible
- **Rate limiting** - 500ms delay between API calls (configurable)
- **Testing tip** - Use small RSS feed for testing

### Upload-ToLiquidFiles.ps1
- **Authentication** - HTTP Basic Auth with base64 encoding
- **Multipart uploads** - File encoding is critical
- **API versioning** - LiquidFiles API may change, test thoroughly
- **Testing tip** - Use Test-LiquidFilesAccess.ps1 first

### Serial/CheckComm.ps1
- **Port locking** - Only one process can use a COM port
- **GPS parsing** - NMEA sentences have specific formats
- **CSV logging** - Continuous append mode, manage file size
- **Testing tip** - Use GPS simulator or loopback adapter

---

## Quick Reference Commands

### Common Git Operations
```bash
# Check current branch
git branch

# Create and switch to feature branch
git checkout -b claude/feature-name-session-id

# Stage and commit changes
git add .
git commit -m "Descriptive commit message"

# Push to remote
git push -u origin claude/feature-name-session-id
```

### Script Execution Examples
```powershell
# Outlook Signature Manager
.\Add-WeektoSignature.ps1

# Torrent Processor (with config)
.\RssDownloadandStart-v2.ps1

# LiquidFiles Test
.\Test-LiquidFilesAccess.ps1 -ListMessages

# LiquidFiles Upload
.\Upload-ToLiquidFiles.ps1 -FilePath "C:\file.pdf" -Recipients "user@example.com"

# Serial Terminal
.\Serial\CheckComm.ps1 -Port COM3

# Screen Lock Check
. .\isScreenLocked; Test-ScreenLock
```

### Configuration Setup
```powershell
# Create config from template
Copy-Item liquidfiles-config.json.template liquidfiles-config.json
notepad liquidfiles-config.json  # Edit with actual values

# Validate config exists
Test-Path .\liquidfiles-config.json

# View config (sanitize output)
Get-Content .\liquidfiles-config.json | ConvertFrom-Json | Select-Object ServerUrl, DefaultExpirationDays
```

---

## Contact and Contributions

### Repository Owner
**GitHub:** MatthewCKelly/PSCode

### Contributing Guidelines
1. Create feature branch with `claude/` prefix
2. Follow existing code patterns and conventions
3. Test thoroughly before committing
4. Update version comments in modified files
5. Create pull request with clear description
6. Ensure all secrets are in .gitignore

### Issue Reporting
When reporting issues, include:
- PowerShell version (`$PSVersionTable`)
- Script name and version
- Full error message and stack trace
- Configuration (sanitized - no credentials)
- Steps to reproduce

---

## Changelog

### 2025-11-20 - Write-Detail Usage Guidelines
- Added critical warnings about `Write-Detail` function usage
- Documented that `Write-Detail ""` with empty strings will fail (mandatory parameter)
- Documented that `Write-Detail "=" * 80` must use parentheses: `Write-Detail ("=" * 80)`
- Added examples of correct vs incorrect usage patterns
- Updated "Common Pitfalls to Avoid" section with Write-Detail warnings
- Added to help prevent parameter validation errors in scripts

### 2025-11-17 - Initial CLAUDE.md Creation
- Comprehensive documentation of all scripts
- Development workflow guidelines
- AI assistant best practices
- Configuration management details
- Common patterns and conventions

---

**End of CLAUDE.md**

*This document is maintained for AI assistants working on the PSCode repository. Keep it updated as the codebase evolves.*
