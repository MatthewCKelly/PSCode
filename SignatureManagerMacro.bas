Attribute VB_Name = "SignatureManagerMacro"
' ============================================
' Outlook Signature Manager Toolbar Integration
' ============================================
' This macro launches the PowerShell signature manager script
' Author: Claude AI
' Version: 1.0
' ============================================

Sub LaunchSignatureManager()
    '
    ' LaunchSignatureManager Macro
    ' Launches the PowerShell script to manage Outlook signatures
    '
    Dim scriptPath As String
    Dim powerShellCommand As String
    Dim shell As Object
    Dim scriptDir As String

    ' Method 1: Try to find script in same directory as this Outlook profile
    scriptDir = Environ("USERPROFILE") & "\Documents\OutlookSignatureManager\"
    scriptPath = scriptDir & "Add-WeektoSignature.ps1"

    ' Check if script exists at expected location
    If Dir(scriptPath) = "" Then
        ' Method 2: Prompt user to locate the script
        scriptPath = BrowseForScript()

        If scriptPath = "" Then
            MsgBox "Script not found. Please ensure Add-WeektoSignature.ps1 is in:" & vbCrLf & vbCrLf & _
                   scriptDir & vbCrLf & vbCrLf & _
                   "Or select the script location when prompted.", _
                   vbExclamation, "Signature Manager"
            Exit Sub
        End If
    End If

    ' Build PowerShell command with execution policy bypass
    powerShellCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -File """ & scriptPath & """"

    ' Create shell object and run the command
    ' Parameters: command, windowStyle (1=normal, 0=hidden), waitOnReturn (False=don't wait)
    Set shell = CreateObject("WScript.Shell")
    shell.Run powerShellCommand, 1, False

    Set shell = Nothing
End Sub

Private Function BrowseForScript() As String
    '
    ' BrowseForScript Function
    ' Opens file dialog to let user locate the PowerShell script
    '
    Dim fileDialog As Object
    Dim selectedFile As String

    On Error Resume Next

    ' Create file dialog
    Set fileDialog = Application.FileDialog(1) ' 1 = msoFileDialogFilePicker

    With fileDialog
        .Title = "Locate Add-WeektoSignature.ps1"
        .Filters.Clear
        .Filters.Add "PowerShell Scripts", "*.ps1"
        .Filters.Add "All Files", "*.*"
        .AllowMultiSelect = False
        .InitialFileName = Environ("USERPROFILE") & "\Documents\"

        If .Show = -1 Then
            ' User selected a file
            selectedFile = .SelectedItems(1)
        Else
            ' User cancelled
            selectedFile = ""
        End If
    End With

    Set fileDialog = Nothing
    BrowseForScript = selectedFile
End Function

Sub InstallationInstructions()
    '
    ' InstallationInstructions Macro
    ' Displays instructions for adding the macro to the toolbar
    '
    Dim msg As String

    msg = "SIGNATURE MANAGER - INSTALLATION INSTRUCTIONS" & vbCrLf & vbCrLf & _
          "Step 1: Place Script File" & vbCrLf & _
          "Copy Add-WeektoSignature.ps1 to:" & vbCrLf & _
          Environ("USERPROFILE") & "\Documents\OutlookSignatureManager\" & vbCrLf & vbCrLf & _
          "Step 2: Add to Quick Access Toolbar" & vbCrLf & _
          "1. Click dropdown on Quick Access Toolbar (top-left)" & vbCrLf & _
          "2. Select 'More Commands...'" & vbCrLf & _
          "3. Choose commands from: Macros" & vbCrLf & _
          "4. Select 'Project1.LaunchSignatureManager'" & vbCrLf & _
          "5. Click 'Add >>' then 'OK'" & vbCrLf & vbCrLf & _
          "Step 3: Test" & vbCrLf & _
          "Click the new button to launch Signature Manager" & vbCrLf & vbCrLf & _
          "For more help, see OutlookToolbarIntegration.md"

    MsgBox msg, vbInformation, "Signature Manager - Installation"
End Sub

' ============================================
' CONFIGURATION NOTES
' ============================================
' Default Script Location:
' %USERPROFILE%\Documents\OutlookSignatureManager\Add-WeektoSignature.ps1
'
' To change the default location, edit the scriptDir variable
' in the LaunchSignatureManager subroutine above
'
' If script is not found at default location, user will be
' prompted to browse for it
' ============================================
