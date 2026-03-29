# PowerShell Placement Quiz

## 📊 Find Your Starting Point

Not sure where to begin? This quiz will help you identify which modules you can skip and where you should start learning.

**Time Required:** 15 minutes
**Instructions:** Answer honestly - this helps you learn more efficiently!

---

## Section 1: PowerShell Basics (Module 1)

### Question 1.1
What does this command do?
```powershell
Get-Process | Where-Object { $_.CPU -gt 100 } | Sort-Object CPU -Descending
```

- [ ] A) Gets all processes and sorts them
- [ ] B) Gets processes using more than 100% CPU
- [ ] C) Gets processes using more than 100 CPU seconds, sorted by CPU usage
- [ ] D) I don't know

### Question 1.2
What's the difference?
```powershell
# Option 1
.\MyScript.ps1

# Option 2
. .\MyScript.ps1
```

- [ ] A) No difference
- [ ] B) Option 1 runs the script, Option 2 dot-sources it (functions stay in scope)
- [ ] C) Option 1 is relative path, Option 2 is absolute path
- [ ] D) I don't know

### Question 1.3
Fix this function:
```powershell
function GetUserInfo($name) {
    return "User: $name"
}
```

- [ ] A) It's already correct
- [ ] B) Should be `function Get-UserInfo` with proper param block
- [ ] C) Should use `Write-Output` instead of `return`
- [ ] D) I don't know

**Section 1 Score:** ___/3

**If you scored 0-1:** Start at Module 1
**If you scored 2-3:** Skip to Module 2 or 3

---

## Section 2: Logging & Debugging (Module 2)

### Question 2.1
Which log level is most appropriate?
```powershell
# User successfully created a signature
Write-Detail "Signature created: $fileName" -Level ???
```

- [ ] A) Info
- [ ] B) Success
- [ ] C) Warning
- [ ] D) I don't know

### Question 2.2
What's wrong with this logging?
```powershell
try {
    $result = Invoke-WebRequest -Uri $url
    Write-Host "Success"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
```

- [ ] A) Nothing wrong
- [ ] B) Should use Write-Error instead of Write-Host
- [ ] C) Should use structured logging with levels, timestamps, and line numbers
- [ ] D) I don't know

### Question 2.3
How do you enable verbose output?
```powershell
.\MyScript.ps1 -Verbose
```

What must be in the script?

- [ ] A) Nothing special needed
- [ ] B) Must use `Write-Verbose` commands
- [ ] C) Must have `[CmdletBinding()]` attribute
- [ ] D) I don't know

**Section 2 Score:** ___/3

**If you scored 0-1:** Start at Module 2
**If you scored 2-3:** Skip to Module 3

---

## Section 3: Configuration Management (Module 3)

### Question 3.1
Load this JSON config:
```json
{
  "ServerUrl": "https://api.example.com",
  "ApiKey": "secret123",
  "RetryCount": 3
}
```

```powershell
$config = ???
```

- [ ] A) `Get-Content config.json`
- [ ] B) `Get-Content config.json | ConvertFrom-Json`
- [ ] C) `Import-Csv config.json`
- [ ] D) I don't know

### Question 3.2
What should be in .gitignore?

- [ ] A) Only `*.log` files
- [ ] B) `config.json` (actual config with secrets)
- [ ] C) `config.json.template` (the template)
- [ ] D) I don't know

### Question 3.3
Validate required fields:
```powershell
$config = Get-Content config.json | ConvertFrom-Json

# How do you check if ApiKey exists and is not empty?
```

- [ ] A) `if ($config.ApiKey) { ... }`
- [ ] B) `if ([string]::IsNullOrWhiteSpace($config.ApiKey)) { throw "..." }`
- [ ] C) `if (-not $config.ApiKey) { throw "..." }`
- [ ] D) I don't know

**Section 3 Score:** ___/3

**If you scored 0-1:** Start at Module 3
**If you scored 2-3:** Skip to Module 4

---

## Section 4: Windows Registry (Module 4)

### Question 4.1
Read a registry value:
```powershell
# Get 'Version' from HKCU:\Software\MyApp
$value = ???
```

- [ ] A) `Get-ItemProperty -Path "HKCU:\Software\MyApp" -Name "Version"`
- [ ] B) `Get-RegistryValue "HKCU:\Software\MyApp" "Version"`
- [ ] C) `Read-Registry -Path "HKCU:\Software\MyApp" -Key "Version"`
- [ ] D) I don't know

### Question 4.2
What's the difference between HKCU and HKLM?

- [ ] A) No difference
- [ ] B) HKCU = Current User (no admin needed), HKLM = Local Machine (admin required)
- [ ] C) HKCU = Local settings, HKLM = Cloud settings
- [ ] D) I don't know

### Question 4.3
Create a registry value:
```powershell
# Set 'RunCount' to 5 in HKCU:\Software\MyApp
```

- [ ] A) `New-ItemProperty -Path ... -Name "RunCount" -Value 5 -PropertyType DWORD`
- [ ] B) `Set-RegistryValue -Path ... -Name "RunCount" -Value 5`
- [ ] C) `Add-Registry -Path ... -Key "RunCount" -Value 5`
- [ ] D) I don't know

**Section 4 Score:** ___/3

**If you scored 0-1:** Don't skip Module 4
**If you scored 2-3:** Can skip Module 4

---

## Section 5: REST APIs (Module 5)

### Question 5.1
Make a GET request:
```powershell
# Call https://api.example.com/users
$response = ???
```

- [ ] A) `Get-WebRequest https://api.example.com/users`
- [ ] B) `Invoke-RestMethod -Uri https://api.example.com/users -Method Get`
- [ ] C) `Invoke-WebRequest https://api.example.com/users`
- [ ] D) I don't know

### Question 5.2
Add Basic Authentication:
```powershell
$apiKey = "mykey"
$headers = @{ Authorization = ??? }
```

- [ ] A) `"Basic $apiKey"`
- [ ] B) `"Bearer $apiKey"`
- [ ] C) `"Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($apiKey):"))`
- [ ] D) I don't know

### Question 5.3
POST JSON data:
```powershell
$body = @{ Name = "John"; Email = "john@example.com" }
# Send to https://api.example.com/users
```

- [ ] A) `Invoke-RestMethod -Uri $url -Method Post -Body $body`
- [ ] B) `Invoke-RestMethod -Uri $url -Method Post -Body ($body | ConvertTo-Json) -ContentType "application/json"`
- [ ] C) `Send-PostRequest -Url $url -Data $body`
- [ ] D) I don't know

**Section 5 Score:** ___/3

**If you scored 0-1:** Don't skip Module 5
**If you scored 2-3:** Can skip Module 5

---

## Section 6: Windows Forms GUI (Module 6)

### Question 6.1
Create a basic form:
```powershell
Add-Type -AssemblyName System.Windows.Forms

$form = ???
$form.Text = "My App"
$form.Size = ???
$form.ShowDialog()
```

- [ ] A) `New-Object Form` and `New-Object Size(800, 600)`
- [ ] B) `New-Object System.Windows.Forms.Form` and `New-Object System.Drawing.Size(800, 600)`
- [ ] C) `[Windows.Forms.Form]::new()` and `[Drawing.Size]::new(800, 600)`
- [ ] D) I don't know

### Question 6.2
Add a button click handler:
```powershell
$button = New-Object System.Windows.Forms.Button
$button.Text = "Click Me"

# Add event handler that shows a message
???
```

- [ ] A) `$button.OnClick = { [MessageBox]::Show("Clicked!") }`
- [ ] B) `$button.Add_Click({ [System.Windows.Forms.MessageBox]::Show("Clicked!") })`
- [ ] C) `$button.ClickEvent({ Show-Message "Clicked!" })`
- [ ] D) I don't know

### Question 6.3
What does this do?
```powershell
$textbox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
```

- [ ] A) Sets the textbox position
- [ ] B) Makes textbox stay at top-left, and stretch horizontally when form resizes
- [ ] C) Anchors the textbox to the form border
- [ ] D) I don't know

**Section 6 Score:** ___/3

**If you scored 0-1:** Don't skip Module 6
**If you scored 2-3:** Can skim Module 6

---

## Section 7: HTML Generation (Module 7)

### Question 7.1
Build an HTML table:
```powershell
$data = @(
    @{ Name = "Alice"; Age = 30 }
    @{ Name = "Bob"; Age = 25 }
)

# Generate HTML table
```

- [ ] A) `$data | ConvertTo-Html`
- [ ] B) Manually build with foreach loops and string concatenation
- [ ] C) `New-HtmlTable -Data $data`
- [ ] D) I don't know

### Question 7.2
Remove HTML tags from a string:
```powershell
$html = "<p>Hello <b>World</b></p>"
$text = ???  # Should be "Hello World"
```

- [ ] A) `$html -replace '<[^>]+>', ''`
- [ ] B) `Strip-HtmlTags $html`
- [ ] C) `$html.StripTags()`
- [ ] D) I don't know

### Question 7.3
What's wrong with this HTML generation?
```powershell
$html = "<html><body>"
foreach ($item in $items) {
    $html = $html + "<p>$item</p>"
}
$html = $html + "</body></html>"
```

- [ ] A) Nothing wrong
- [ ] B) Should use `+=` operator
- [ ] C) String concatenation in loop is slow; should use StringBuilder or array + `-join`
- [ ] D) I don't know

**Section 7 Score:** ___/3

**If you scored 0-2:** Don't skip Module 7
**If you scored 3:** Can skim Module 7

---

## Section 8: Task Scheduling (Module 8)

### Question 8.1
Create a scheduled task without admin rights:
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\script.ps1"
$trigger = ???  # Run at logon

Register-ScheduledTask -TaskName "MyTask" -Action $action -Trigger $trigger ???
```

- [ ] A) Use `New-ScheduledTaskTrigger -AtLogon` and `-RunLevel Highest`
- [ ] B) Use `New-ScheduledTaskTrigger -AtLogon` with no extra parameters
- [ ] C) Not possible without admin rights
- [ ] D) I don't know

### Question 8.2
Better approach: XML-based registration
```powershell
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task>...</Task>
"@

Register-ScheduledTask ???
```

- [ ] A) `-Xml $taskXml`
- [ ] B) `-TaskDefinition $taskXml`
- [ ] C) `-XmlFile $taskXml`
- [ ] D) I don't know

### Question 8.3
Prevent task from running too frequently:
```powershell
# Should only run if last run was 7+ hours ago
```

How would you implement this?

- [ ] A) Built into scheduled task settings
- [ ] B) Script checks registry for last run timestamp and exits if too recent
- [ ] C) Use task scheduler's repetition settings
- [ ] D) I don't know

**Section 8 Score:** ___/3

**If you scored 0-1:** Don't skip Module 8
**If you scored 2-3:** Can skip Module 8

---

## Section 9: Serial Communication (Module 9)

### Question 9.1
Open a COM port:
```powershell
$port = New-Object System.IO.Ports.SerialPort "COM3", ???
```

What goes in place of ???

- [ ] A) Just the port name is enough
- [ ] B) Baud rate (e.g., 9600)
- [ ] C) Connection string
- [ ] D) I don't know

### Question 9.2
Read data from serial port:
```powershell
$port.Open()
$data = ???
```

- [ ] A) `$port.Read()`
- [ ] B) `$port.ReadLine()` or `$port.ReadExisting()`
- [ ] C) `Get-SerialData $port`
- [ ] D) I don't know

### Question 9.3
What's NMEA?

- [ ] A) A PowerShell module
- [ ] B) A protocol for GPS data
- [ ] C) Network Management Application
- [ ] D) I don't know

**Section 9 Score:** ___/3

**If you scored 0:** Skip Module 9 unless you need serial communication
**If you scored 1-3:** Don't skip if you need serial communication

---

## Section 10: SCCM/ConfigMgr (Module 10)

### Question 10.1
Load ConfigMgr module:
```powershell
Import-Module ???
```

- [ ] A) `ConfigurationManager`
- [ ] B) `SCCM`
- [ ] C) Need to import from specific path based on installation
- [ ] D) I don't know

### Question 10.2
Query WMI for installed software:
```powershell
Get-WmiObject ???
```

- [ ] A) `Win32_Product`
- [ ] B) `Win32_InstalledSoftware`
- [ ] C) `SMS_InstalledSoftware` (in ConfigMgr namespace)
- [ ] D) I don't know

### Question 10.3
What's a collection query rule?

- [ ] A) A database query
- [ ] B) WQL query that determines collection membership based on device properties
- [ ] C) A PowerShell script
- [ ] D) I don't know

**Section 10 Score:** ___/3

**If you scored 0:** Skip Module 10 unless you work with SCCM
**If you scored 1-3:** Don't skip if you need SCCM automation

---

## 📊 Calculate Your Results

### Total Your Scores

- **Section 1 (Basics):** ___/3
- **Section 2 (Logging):** ___/3
- **Section 3 (Config):** ___/3
- **Section 4 (Registry):** ___/3
- **Section 5 (APIs):** ___/3
- **Section 6 (GUI):** ___/3
- **Section 7 (HTML):** ___/3
- **Section 8 (Scheduling):** ___/3
- **Section 9 (Serial):** ___/3
- **Section 10 (SCCM):** ___/3

**TOTAL:** ___/30

---

## 🎯 Recommended Starting Points

### Score: 0-10 (Beginner)
**Start:** Module 1 - PowerShell Foundations

You're new to PowerShell or scripting in general. That's great! Start from the beginning and work through each module. The course is designed to take you from basics to advanced.

**Estimated Time:** 12 weeks (full course)

**Track Recommendation:** Start with Track 1 (System Administrator) to build solid foundations

---

### Score: 11-20 (Intermediate)
**Start:** Module 3 or 4 (skip basics and logging)

You know PowerShell basics but haven't worked with more advanced topics like APIs, GUIs, or scheduling. Skip the first couple of modules but review the labs if you need practice.

**Estimated Time:** 8-10 weeks

**Track Recommendation:** Track 2 (GUI Developer) or Track 3 (API Integration) based on interest

---

### Score: 21-27 (Advanced)
**Start:** Jump to topics you scored low on

You're experienced with PowerShell. Use this course to fill gaps in knowledge. Focus on specific modules where you scored 0-1, and tackle the capstone projects.

**Estimated Time:** 4-6 weeks (selective learning)

**Track Recommendation:** Track 4 (Full Stack) - Focus on advanced patterns and best practices

---

### Score: 28-30 (Expert)
**Start:** Module 11 (Advanced Patterns) and Capstone Projects

You already know most of this material. Focus on:
- Learning the specific patterns used in this codebase
- Advanced optimization techniques in Module 11
- Building the capstone projects
- Contributing improvements to the course

**Estimated Time:** 2-3 weeks

**Track Recommendation:** Contribute to the course! Add lessons, improve exercises, build additional projects

---

## 📝 Answer Key

<details>
<summary>Click to reveal answers (but try the quiz first!)</summary>

### Section 1
1. C - Gets processes using more than 100 CPU seconds, sorted
2. B - Dot-sourcing keeps functions in scope
3. B - Should use `Get-UserInfo` with proper param block

### Section 2
1. B - Success level is most appropriate
2. C - Should use structured logging
3. B and C - Need both Write-Verbose and [CmdletBinding()]

### Section 3
1. B - Get-Content | ConvertFrom-Json
2. B - Actual config with secrets
3. B - Check IsNullOrWhiteSpace and throw

### Section 4
1. A - Get-ItemProperty
2. B - HKCU = User, HKLM = Machine
3. A - New-ItemProperty with PropertyType

### Section 5
1. B - Invoke-RestMethod
2. C - Base64 encode credentials
3. B - ConvertTo-Json and set ContentType

### Section 6
1. B - Full type names
2. B - Add_Click with scriptblock
3. B - Anchoring makes it resize

### Section 7
1. A or B - Both work, manual is more flexible
2. A - Regex to strip tags
3. C - String concatenation in loop is slow

### Section 8
1. B - No admin needed for user-level tasks
2. A - Use -Xml parameter
3. B - Script checks timestamp

### Section 9
1. B - Baud rate required
2. B - ReadLine() or ReadExisting()
3. B - GPS data protocol

### Section 10
1. C - Specific installation path
2. C - SMS_InstalledSoftware
3. B - WQL query for membership

</details>

---

## 🚀 Ready to Start?

Based on your score, jump to your recommended starting point in [COURSE.md](./COURSE.md).

Remember: These are recommendations, not requirements. If you want to start from the beginning for a thorough understanding, go for it!

**Happy Learning! 📚**
