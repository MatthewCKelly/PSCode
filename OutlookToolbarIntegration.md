# Adding Signature Manager to Outlook Toolbar

## Method 1: Quick Access Toolbar with VBA Macro (Recommended)

### Step 1: Create VBA Macro in Outlook

1. **Open Outlook**
2. Press `Alt + F11` to open the VBA Editor
3. In the VBA Editor, expand **Project1 (VbaProject.OTM)**
4. Right-click on **Modules** → **Insert** → **Module**
5. Paste the following VBA code:

```vba
Sub LaunchSignatureManager()
    Dim scriptPath As String
    Dim powerShellCommand As String
    Dim shell As Object

    ' Update this path to where your script is located
    scriptPath = "C:\Path\To\Your\Add-WeektoSignature.ps1"

    ' Build PowerShell command to run the script
    powerShellCommand = "powershell.exe -ExecutionPolicy Bypass -File """ & scriptPath & """"

    ' Create shell object and run the command
    Set shell = CreateObject("WScript.Shell")
    shell.Run powerShellCommand, 1, False

    Set shell = Nothing
End Sub
```

6. **IMPORTANT**: Update the `scriptPath` line with the actual path to your `Add-WeektoSignature.ps1` file
7. Save the macro: **File** → **Save** (or press `Ctrl + S`)
8. Close the VBA Editor

### Step 2: Add Macro to Quick Access Toolbar

1. In Outlook, click the **down arrow** on the Quick Access Toolbar (top-left corner)
2. Select **More Commands...**
3. In the dialog:
   - **Choose commands from**: Select **Macros**
   - Find and select: **Project1.LaunchSignatureManager**
   - Click **Add >>**
   - Click **OK**

### Step 3: Customize Button (Optional)

1. Right-click on the new button in the Quick Access Toolbar
2. Select **Customize Quick Access Toolbar...**
3. Select your macro button
4. Click **Modify...**
5. Choose an icon (suggest using signature or calendar icon)
6. In **Display name**, enter: "Weekly Status"
7. Click **OK**

---

## Method 2: Custom Ribbon Button (Advanced)

This requires creating an Office Add-in. For a simpler solution, use Method 1.

---

## Method 3: Create Desktop Shortcut with Custom Icon

If you prefer a desktop shortcut instead of toolbar integration:

### Step 1: Create Shortcut
1. Right-click on desktop → **New** → **Shortcut**
2. Enter this as the location:
   ```
   powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\Your\Add-WeektoSignature.ps1"
   ```
3. Click **Next**
4. Name it "Weekly Signature Manager"
5. Click **Finish**

### Step 2: Add Custom Icon (Optional)
1. Right-click the shortcut → **Properties**
2. Click **Change Icon...**
3. Browse to a suitable icon file or choose from system icons
4. Click **OK**

### Step 3: Pin to Taskbar
- Right-click the shortcut → **Pin to taskbar**

---

## Troubleshooting

### VBA Macro Doesn't Run
- **Security Settings**: File → Options → Trust Center → Trust Center Settings → Macro Settings
- Ensure "Notifications for digitally signed macros" or "Enable all macros" is selected
- Restart Outlook after changing settings

### PowerShell Execution Policy Error
The VBA macro includes `-ExecutionPolicy Bypass` to avoid this, but if you still get errors:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Script Path Issues
- Use full absolute path (e.g., `C:\Users\YourName\Documents\PSCode\Add-WeektoSignature.ps1`)
- Ensure path has no special characters that need escaping
- Test the path by running the PowerShell command directly first

### Macro Not Visible in List
- Save the VBA module in **VbaProject.OTM** (Outlook's global macro file)
- Restart Outlook
- Check that macros are enabled in Trust Center

---

## Alternative: Keyboard Shortcut

You can also assign a keyboard shortcut to the macro:

1. In VBA Editor, ensure your macro is selected
2. Add this comment at the top of your macro:
   ```vba
   ' Keyboard Shortcut: Ctrl+Shift+W
   ```
3. However, Outlook doesn't directly support keyboard shortcuts for macros
4. Use a third-party tool like AutoHotkey for custom keyboard shortcuts

---

## Script Location Recommendations

**Best Practice**: Place the script in a permanent location:
- `C:\Users\<YourName>\Documents\OutlookSignatureManager\Add-WeektoSignature.ps1`
- Or: `C:\Scripts\Add-WeektoSignature.ps1`

**Do NOT** place it in:
- Desktop (files can be deleted accidentally)
- Temp folders
- OneDrive/Dropbox (can cause sync issues when running)

---

## Testing the Integration

1. Click the button you added to the Quick Access Toolbar
2. The signature manager window should open
3. If nothing happens:
   - Check VBA macro path is correct
   - Open VBA Editor and run the macro manually (`F5`) to see error messages
   - Check Windows Event Viewer for PowerShell errors
