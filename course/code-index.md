# Code Index - Find Examples Fast

## 📖 Quick Reference Guide

Looking for an example of a specific technique? This index maps concepts to actual code locations in the PSCode repository.

**How to use this:**
1. Find the concept you want to learn
2. See which script(s) demonstrate it
3. Open the file and jump to the line number
4. Read the code and comments
5. Try modifying it in your own script

---

## 🎯 By Concept

### Parameters & Validation

| Concept | Example | Location |
|---------|---------|----------|
| Basic parameters | Screen lock detector | `isScreenLocked:10` |
| ValidateSet | Registry value type checker | `Test-RegistryValueType.ps1:20-25` |
| ValidateRange | Export WU events | `Export-WindowsUpdateEventsToLog.ps1:30-35` |
| ValidateScript | LiquidFiles test | `Test-LiquidFilesAccess.ps1:25-30` |
| Mandatory parameters | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:35-50` |
| Parameter sets | LiquidFiles test | `Test-LiquidFilesAccess.ps1:20-60` |
| Switch parameters | SCCM collection creator | `Create-APP-AD-CollectionsAndRules.ps1:35-45` |
| Default values | RSS processor | `RssDownloadandStart-v2.ps1:25-30` |

### Logging & Output

| Concept | Example | Location |
|---------|---------|----------|
| **Write-Detail function** | Signature manager | `Add-WeektoSignature.ps1:150-180` |
| Log levels (Info/Warning/Error/Debug/Success) | Any script | Any script using Write-Detail |
| CM Log format | WU events exporter | `Export-WindowsUpdateEventsToLog.ps1:100-150` |
| Console colors | Write-Detail | `Add-WeektoSignature.ps1:165-175` |
| Timestamps | Write-Detail | `Add-WeektoSignature.ps1:155` |
| Line numbers | Write-Detail | `Add-WeektoSignature.ps1:156-157` |
| File logging | Serial terminal | `Serial/CheckComm.ps1:150-200` |
| CSV logging | Serial GPS logger | `Serial/CheckComm.ps1:250-300` |

### Configuration Management

| Concept | Example | Location |
|---------|---------|----------|
| **JSON config loading** | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:100-120` |
| Config validation | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:125-145` |
| Config templates | LiquidFiles template | `liquidfiles-config.json.template` |
| Missing config errors | RSS processor | `RssDownloadandStart-v2.ps1:80-95` |
| Required fields check | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:130-140` |
| Default values | RSS processor | `RssDownloadandStart-v2.ps1:100-110` |

### Registry Operations

| Concept | Example | Location |
|---------|---------|----------|
| **Read registry value** | Signature manager | `Add-WeektoSignature.ps1:700-720` |
| **Write registry value** | Signature manager | `Add-WeektoSignature.ps1:650-680` |
| **Test if key exists** | Signature manager | `Add-WeektoSignature.ps1:690-695` |
| **Create registry key** | Signature manager | `Add-WeektoSignature.ps1:685-690` |
| Registry data types | Registry type tester | `Test-RegistryValueType.ps1:80-120` |
| HKCU vs HKLM | Proxy settings | `Dev/Read-DefaultProxySettings.ps1:50-80` |
| Binary registry values | Proxy decoder | `Dev/Test-ProxySettingsDecoder.ps1:100-200` |
| Enumerate values | Registry type tester | `Test-RegistryValueType.ps1:140-160` |

### REST API Integration

| Concept | Example | Location |
|---------|---------|----------|
| **Basic GET request** | LiquidFiles test | `Test-LiquidFilesAccess.ps1:150-170` |
| **POST with JSON** | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:300-325` |
| **Basic Authentication** | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:120-130` |
| **Authorization headers** | LiquidFiles test | `Test-LiquidFilesAccess.ps1:140-145` |
| **Error handling** | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:350-380` |
| **Multipart file upload** | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:200-280` |
| **Rate limiting** | RSS processor | `RssDownloadandStart-v2.ps1:200-210` |
| **Plex API** | RSS processor | `RssDownloadandStart-v2.ps1:150-250` |
| **Delegation tokens** | RSS processor | `RssDownloadandStart-v2.ps1:130-140` |

### Windows Forms GUI

| Concept | Example | Location |
|---------|---------|----------|
| **Form creation** | Signature manager | `Add-WeektoSignature.ps1:1100-1130` |
| **Button controls** | Signature manager | `Add-WeektoSignature.ps1:2200-2250` |
| **Textbox controls** | Signature manager | `Add-WeektoSignature.ps1:1300-1330` |
| **ComboBox (dropdown)** | Signature manager | `Add-WeektoSignature.ps1:1620-1680` |
| **Label controls** | Signature manager | `Add-WeektoSignature.ps1:1600-1620` |
| **Checkbox controls** | Signature manager | `Add-WeektoSignature.ps1:2050-2120` |
| **Panel containers** | Signature manager | `Add-WeektoSignature.ps1:1250-1280` |
| **WebBrowser control** | Signature manager | `Add-WeektoSignature.ps1:1822-1860` |
| **Button click events** | Signature manager | `Add-WeektoSignature.ps1:2380-2440` |
| **Textbox change events** | Signature manager | `Add-WeektoSignature.ps1:1340-1360` |
| **Checkbox change events** | Signature manager | `Add-WeektoSignature.ps1:2055-2120` |
| **Dropdown change events** | Signature manager | `Add-WeektoSignature.ps1:1633,1654,1675` |
| **Form resizing** | Signature manager | `Add-WeektoSignature.ps1:2150-2180` |
| **Anchoring controls** | Signature manager | `Add-WeektoSignature.ps1:1828` |
| **Dynamic control creation** | Signature manager | `Add-WeektoSignature.ps1:1518-1730` |
| **MessageBox dialogs** | Signature manager | `Add-WeektoSignature.ps1:2463-2468` |
| **COM port selector dialog** | Serial terminal | `Serial/CheckComm.ps1:50-120` |

### HTML Generation

| Concept | Example | Location |
|---------|---------|----------|
| **HTML string building** | Signature manager | `Add-WeektoSignature.ps1:950-1050` |
| **Table generation** | Signature manager | `Add-WeektoSignature.ps1:980-1030` |
| **HTML header** | Signature manager | `Add-WeektoSignature.ps1:960-975` |
| **Inline styles** | Signature manager | `Add-WeektoSignature.ps1:985-1000` |
| **Regex HTML manipulation** | Signature manager | `Add-WeektoSignature.ps1:1950-1970` |
| **MSO tag removal** | Signature manager | `Add-WeektoSignature.ps1:790-830` |
| **Plain text from HTML** | Signature manager | `Add-WeektoSignature.ps1:1070-1095` |
| **HTML entity decoding** | Signature manager | `Add-WeektoSignature.ps1:1080-1090` |

### Task Scheduling

| Concept | Example | Location |
|---------|---------|----------|
| **XML task definition** | Signature manager | `Add-WeektoSignature.ps1:420-500` |
| **Register scheduled task** | Signature manager | `Add-WeektoSignature.ps1:384-506` |
| **Unregister task** | Signature manager | `Add-WeektoSignature.ps1:508-530` |
| **SessionStateChangeTrigger** | Signature manager | `Add-WeektoSignature.ps1:440-445` |
| **Logon trigger** | Signature manager | `Add-WeektoSignature.ps1:447-450` |
| **User SID retrieval** | Signature manager | `Add-WeektoSignature.ps1:395-400` |
| **Interval throttling** | Signature manager | `Add-WeektoSignature.ps1:266-298` |
| **Last run timestamp** | Signature manager | `Add-WeektoSignature.ps1:300-320` |

### Serial Communication

| Concept | Example | Location |
|---------|---------|----------|
| **Open serial port** | Serial terminal | `Serial/CheckComm.ps1:200-220` |
| **Read serial data** | Serial terminal | `Serial/CheckComm.ps1:250-270` |
| **Write serial data** | Serial terminal | `Serial/CheckComm.ps1:280-295` |
| **NMEA parsing** | Serial GPS | `Serial/CheckComm.ps1:350-450` |
| **Coordinate conversion** | Serial GPS | `Serial/CheckComm.ps1:320-345` |
| **GPS data extraction** | Serial GPS | `Serial/CheckComm.ps1:370-430` |
| **CSV data logging** | Serial GPS | `Serial/CheckComm.ps1:300-315` |
| **Port detection** | Serial terminal | `Serial/CheckComm.ps1:50-90` |
| **Baud rate configuration** | Serial terminal | `Serial/CheckComm.ps1:210-215` |

### SCCM/ConfigMgr

| Concept | Example | Location |
|---------|---------|----------|
| **ConfigMgr module** | Collection creator | `Create-APP-AD-CollectionsAndRules.ps1:50-70` |
| **SQL queries** | Collection creator | `Create-APP-AD-CollectionsAndRules.ps1:200-300` |
| **Collection creation** | Collection creator | `Create-APP-AD-CollectionsAndRules.ps1:600-650` |
| **Query rules** | Collection creator | `Create-APP-AD-CollectionsAndRules.ps1:700-780` |
| **Wildcard to SQL** | Collection creator | `Create-APP-AD-CollectionsAndRules.ps1:150-180` |
| **Folder creation** | Collection creator | `Create-APP-AD-CollectionsAndRules.ps1:550-580` |
| **Event log queries** | WU events exporter | `Export-WindowsUpdateEventsToLog.ps1:200-280` |
| **CM Log format** | WU events exporter | `Export-WindowsUpdateEventsToLog.ps1:100-150` |
| **Monitor mode** | WU events exporter | `Export-WindowsUpdateEventsToLog.ps1:350-420` |

### Advanced Patterns

| Concept | Example | Location |
|---------|---------|----------|
| **Scriptblocks as variables** | Signature manager | `Add-WeektoSignature.ps1:1908-2055` |
| **Classes** | RSS processor | `RssDownloadandStart-v2.ps1:50-80` |
| **Regex patterns** | Signature manager | `Add-WeektoSignature.ps1:1950-1970` |
| **Pipeline operations** | Screen lock | `isScreenLocked:15` |
| **Hashtables** | Signature manager | `Add-WeektoSignature.ps1:1681-1691` |
| **Arrays** | Signature manager | `Add-WeektoSignature.ps1:85` |
| **String formatting** | Write-Detail | `Add-WeektoSignature.ps1:155-165` |
| **Date formatting** | Signature manager | `Add-WeektoSignature.ps1:620-650` |
| **Error handling (try-catch)** | LiquidFiles upload | `Upload-ToLiquidFiles.ps1:350-380` |
| **Finally blocks** | Serial terminal | `Serial/CheckComm.ps1:180-195` |
| **Scope management ($script:)** | Signature manager | `Add-WeektoSignature.ps1:844-847` |
| **Region organization** | All scripts | Search for `#region` |

---

## 🗂️ By Script

### Simple Scripts (Good for Beginners)

#### `isScreenLocked` (30 lines)
- Basic function structure
- Process detection
- Return hashtables
- Export-ModuleMember

#### `Test-RegistryValueType.ps1` (189 lines)
- Parameter sets
- Registry enumeration
- Color output
- ValidateSet

### Medium Complexity

#### `Upload-ToLiquidFiles.ps1` (474 lines)
- JSON configuration
- REST API (POST)
- Multipart file upload
- Basic authentication
- Error handling

#### `Test-LiquidFilesAccess.ps1` (419 lines)
- Parameter sets
- REST API (GET)
- Multiple endpoints
- Response parsing
- Config validation

#### `RssDownloadandStart-v2.ps1` (568 lines)
- Classes (PlexMedia, TorrentItem)
- Plex API integration
- RSS feed parsing
- Rate limiting
- Network path validation

#### `Serial/CheckComm.ps1` (478 lines)
- Serial port communication
- NMEA protocol parsing
- GPS coordinate conversion
- CSV logging
- Terminal emulation
- COM port selection GUI

### Complex Scripts

#### `Add-WeektoSignature.ps1` (2,499 lines)
**Everything is here! This is the master reference.**

- Windows Forms GUI (complete application)
- Dynamic control creation
- WebBrowser control with HTML preview
- Registry persistence
- HTML generation and manipulation
- Plain text generation
- Event-driven programming
- Scheduled task creation (XML-based)
- State management
- Form resizing and layout
- Error handling throughout
- Configuration via registry

**Study this script to see how all concepts come together!**

#### `Create-APP-AD-CollectionsAndRules.ps1` (~1,400 lines)
- SCCM/ConfigMgr automation
- SQL database queries
- GridView for user selection
- Collection and rule creation
- Wildcard pattern conversion
- Folder hierarchy

#### `Export-WindowsUpdateEventsToLog.ps1` (~550 lines)
- Event log queries
- CM Log format generation
- Monitor mode (continuous operation)
- Admin privilege checking
- Multiple log sources
- Date range filtering

---

## 🎯 By Learning Goal

### "I want to build a GUI application"
**Start with:**
1. `Serial/CheckComm.ps1` (lines 50-120) - Simple COM port selector
2. `Add-WeektoSignature.ps1` (lines 1100-1280) - Form and basic controls
3. `Add-WeektoSignature.ps1` (lines 1518-1730) - Dynamic controls
4. `Add-WeektoSignature.ps1` (lines 1822-1860) - WebBrowser control
5. `Add-WeektoSignature.ps1` (lines 2050-2180) - Events and resizing

### "I want to work with APIs"
**Start with:**
1. `Test-LiquidFilesAccess.ps1` (lines 140-170) - Simple GET
2. `Test-LiquidFilesAccess.ps1` (lines 120-145) - Authentication
3. `Upload-ToLiquidFiles.ps1` (lines 300-325) - POST with JSON
4. `Upload-ToLiquidFiles.ps1` (lines 200-280) - Multipart upload
5. `RssDownloadandStart-v2.ps1` (lines 150-250) - Plex API

### "I want to automate system tasks"
**Start with:**
1. `isScreenLocked` (all) - Process detection
2. `Test-RegistryValueType.ps1` (all) - Registry operations
3. `Add-WeektoSignature.ps1` (lines 384-530) - Scheduled tasks
4. `Export-WindowsUpdateEventsToLog.ps1` (all) - Event logs

### "I want to work with hardware"
**Start with:**
1. `Serial/CheckComm.ps1` (lines 200-220) - Serial port basics
2. `Serial/CheckComm.ps1` (lines 250-295) - Read/write data
3. `Serial/CheckComm.ps1` (lines 350-450) - Protocol parsing

### "I want to work with HTML/emails"
**Start with:**
1. `Add-WeektoSignature.ps1` (lines 950-1050) - HTML generation
2. `Add-WeektoSignature.ps1` (lines 790-830) - HTML cleanup
3. `Add-WeektoSignature.ps1` (lines 1070-1095) - Plain text conversion
4. `Add-WeektoSignature.ps1` (lines 1822-1860) - HTML preview

---

## 🔍 Search Tips

### Find by Keyword

Use these PowerShell commands to search the codebase:

```powershell
# Find all uses of a function
Select-String -Path *.ps1 -Pattern "Write-Detail" -Recursive

# Find all GUI controls
Select-String -Path *.ps1 -Pattern "System.Windows.Forms" -Recursive

# Find all API calls
Select-String -Path *.ps1 -Pattern "Invoke-RestMethod" -Recursive

# Find error handling
Select-String -Path *.ps1 -Pattern "try\s*\{" -Recursive

# Find registry operations
Select-String -Path *.ps1 -Pattern "Get-ItemProperty|Set-ItemProperty" -Recursive
```

### VS Code Search

If using VS Code:
- **Ctrl+Shift+F** - Search all files
- **Ctrl+T** - Go to symbol (function)
- **Ctrl+P** - Quick file open
- **F12** - Go to definition

---

## 📚 Related Resources

- **[COURSE.md](../COURSE.md)** - Full course structure
- **[CLAUDE.md](../CLAUDE.md)** - Repository guide and patterns
- **[Placement Quiz](./placement-quiz.md)** - Find your starting point
- **[Lessons](./lessons/)** - Structured learning paths
- **[Labs](./labs/)** - Hands-on projects

---

## 💡 How to Use This Index

### Method 1: Concept-First Learning
1. Choose a concept you want to learn
2. Find it in the "By Concept" section
3. Navigate to the example location
4. Read the code and surrounding context
5. Try modifying it in your own script

### Method 2: Script Exploration
1. Pick a script from "By Script"
2. Read through it top-to-bottom
3. Use this index to understand unfamiliar patterns
4. Modify the script to add features

### Method 3: Goal-Oriented Learning
1. Find your goal in "By Learning Goal"
2. Follow the progression of examples
3. Build up from simple to complex
4. Apply to your own project

---

**Happy Coding! 🚀**

This index is maintained as the repository evolves. If you find better examples or add new code, please update this file!
