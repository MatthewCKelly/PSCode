<#
    .SYNOPSIS
        Upload files to LiquidFiles server via API
    .DESCRIPTION
        This script uploads files to a LiquidFiles server using the REST API.
        Supports single or multiple file uploads with recipient notifications.
        Configuration is loaded from a JSON file containing API credentials.
    .PARAMETER FilePath
        Path to the file or files to upload. Accepts wildcards and arrays.
    .PARAMETER Recipients
        Email address(es) of recipient(s). Comma-separated for multiple recipients.
    .PARAMETER Subject
        Optional subject line for the file transfer notification
    .PARAMETER Message
        Optional message body for the file transfer notification
    .PARAMETER ConfigPath
        Path to the JSON configuration file. Default is "liquidfiles-config.json"
    .INPUTS
        [String] File path(s) to upload
    .OUTPUTS
        Upload status and download links
    .EXAMPLE
        Upload-ToLiquidFiles.ps1 -FilePath "C:\Documents\report.pdf" -Recipients "user@example.com"
    .EXAMPLE
        Upload-ToLiquidFiles.ps1 -FilePath "*.pdf" -Recipients "user1@example.com,user2@example.com" -Subject "Monthly Reports"
    .EXAMPLE
        Upload-ToLiquidFiles.ps1 -FilePath @("file1.txt", "file2.pdf") -Recipients "team@example.com" -Message "Please review"
    .NOTES
        Requires PowerShell 5.1 or higher
        Configuration file required (liquidfiles-config.json)
        API documentation: https://docs.liquidfiles.com/api/
    .LINK
        https://docs.liquidfiles.com/api/v4.1/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$FilePath,

    [Parameter(Mandatory = $true)]
    [string]$Recipients,

    [string]$Subject = "",

    [string]$Message = "",

    [string]$ConfigPath = (Join-Path $PSScriptRoot "liquidfiles-config.json")
)

# Enhanced logging function with color-coded output
function Write-Detail {
    <#
        .SYNOPSIS
            Writes formatted messages to console with log levels
        .DESCRIPTION
            Enhanced logging function that supports different log levels with color coding
            and timestamps for tracking upload progress
        .PARAMETER Message
            The message to write to the log
        .PARAMETER Level
            The logging level (Info, Warning, Error, Debug, Success). Default is Info
        .INPUTS
            [String] Message to log
        .OUTPUTS
            Console output with timestamp and formatting
        .EXAMPLE
            Write-Detail -Message "Upload started" -Level Info
        .NOTES
            Includes automatic line number detection and color-coded output
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $lineNumber = $MyInvocation.ScriptLineNumber

    $logEntry = "[{0}] {1,-7} {2,4} {3}" -f $timestamp, $Level, $lineNumber, $Message

    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor White -BackgroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Black -BackgroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Debug'   { Write-Host $logEntry -ForegroundColor Gray }
        default   { Write-Host $logEntry }
    }
}

# Load and validate configuration
function Get-LiquidFilesConfig {
    <#
        .SYNOPSIS
            Loads LiquidFiles configuration from JSON file
        .DESCRIPTION
            Reads and validates the configuration file containing API credentials
            and server information
        .PARAMETER ConfigPath
            Path to the JSON configuration file
        .INPUTS
            None
        .OUTPUTS
            [PSCustomObject] Configuration object with validated properties
        .EXAMPLE
            Get-LiquidFilesConfig -ConfigPath "config.json"
        .NOTES
            Validates required fields: ServerUrl, ApiKey
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found at: $ConfigPath"
    }

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        # Validate required fields
        if (-not $config.ServerUrl) {
            throw "ServerUrl is missing from configuration file"
        }
        if (-not $config.ApiKey) {
            throw "ApiKey is missing from configuration file"
        }

        # Ensure ServerUrl doesn't have trailing slash
        $config.ServerUrl = $config.ServerUrl.TrimEnd('/')

        Write-Detail "Configuration loaded successfully from $ConfigPath" -Level Debug
        return $config
    }
    catch {
        Write-Detail "Failed to load configuration: $_" -Level Error
        throw
    }
}

# Generate authentication headers
function Get-AuthHeaders {
    <#
        .SYNOPSIS
            Creates authentication headers for LiquidFiles API
        .DESCRIPTION
            Generates HTTP Basic Authentication header using base64 encoding
            of ApiKey followed by colon as per LiquidFiles API spec
        .PARAMETER ApiKey
            The API key from configuration
        .OUTPUTS
            [Hashtable] Headers with Authorization
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    # LiquidFiles uses Basic Auth with ApiKey followed by colon
    $authString = "${ApiKey}:"
    $encodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($authString))

    return @{
        "Authorization" = "Basic $encodedAuth"
    }
}

# Upload file to LiquidFiles
function Send-FileToLiquidFiles {
    <#
        .SYNOPSIS
            Uploads a single file to LiquidFiles server
        .DESCRIPTION
            Uploads a file using multipart/form-data and returns the file ID
            for use in message creation
        .PARAMETER Config
            Configuration object containing API credentials
        .PARAMETER File
            FileInfo object of the file to upload
        .INPUTS
            None
        .OUTPUTS
            [String] File ID from LiquidFiles server
        .EXAMPLE
            Send-FileToLiquidFiles -Config $config -File (Get-Item "document.pdf")
        .NOTES
            Uses multipart form data for file upload
            Supports files of any size within LiquidFiles limits
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    try {
        Write-Detail "Uploading file: $($File.Name) ($([math]::Round($File.Length / 1MB, 2)) MB)" -Level Info

        $uri = "$($Config.ServerUrl)/files"

        # Prepare multipart form data
        $boundary = [System.Guid]::NewGuid().ToString()
        $fileBytes = [System.IO.File]::ReadAllBytes($File.FullName)
        $fileName = $File.Name

        # Build multipart form data manually for better control
        $bodyLines = @(
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
            "Content-Type: application/octet-stream",
            "",
            [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($fileBytes),
            "--$boundary--"
        )

        $body = $bodyLines -join "`r`n"

        # Prepare headers
        $headers = Get-AuthHeaders -ApiKey $Config.ApiKey
        $headers["Content-Type"] = "multipart/form-data; boundary=$boundary"

        # Upload file
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ([System.Text.Encoding]::GetEncoding("iso-8859-1").GetBytes($body))

        Write-Detail "Successfully uploaded: $($File.Name)" -Level Success
        return $response
    }
    catch {
        Write-Detail "Failed to upload $($File.Name): $_" -Level Error
        throw
    }
}

# Create and send message with uploaded files
function Send-LiquidFilesMessage {
    <#
        .SYNOPSIS
            Creates a message and sends uploaded files to recipients
        .DESCRIPTION
            Creates a LiquidFiles message/filelink with uploaded files and sends
            notification to specified recipients
        .PARAMETER Config
            Configuration object containing API credentials
        .PARAMETER FileIds
            Array of file IDs from uploaded files
        .PARAMETER Recipients
            Array of recipient email addresses
        .PARAMETER Subject
            Message subject line
        .PARAMETER MessageBody
            Message body text
        .INPUTS
            None
        .OUTPUTS
            [PSCustomObject] Response from LiquidFiles API with download link
        .EXAMPLE
            Send-LiquidFilesMessage -Config $config -FileIds @("id1", "id2") -Recipients @("user@example.com")
        .NOTES
            Creates a filelink that recipients can use to download files
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $true)]
        [array]$FileIds,

        [Parameter(Mandatory = $true)]
        [array]$Recipients,

        [string]$Subject,
        [string]$MessageBody
    )

    try {
        Write-Detail "Creating message for $($Recipients.Count) recipient(s)" -Level Info

        $uri = "$($Config.ServerUrl)/messages"

        # Prepare message data
        $messageData = @{
            message = @{
                recipients = $Recipients
                subject = $Subject
                message = $MessageBody
                files = $FileIds
            }
        }

        $headers = Get-AuthHeaders -ApiKey $Config.ApiKey
        $headers["Content-Type"] = "application/json"

        $body = $messageData | ConvertTo-Json -Depth 10

        # Send message
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body

        Write-Detail "Message sent successfully" -Level Success
        return $response
    }
    catch {
        Write-Detail "Failed to send message: $_" -Level Error
        throw
    }
}

# Alternative: Create a filelink (simpler than message)
function New-LiquidFilesLink {
    <#
        .SYNOPSIS
            Creates a filelink with uploaded files
        .DESCRIPTION
            Creates a shareable link for uploaded files that can be sent to recipients
            This is an alternative to sending a message directly
        .PARAMETER Config
            Configuration object containing API credentials
        .PARAMETER FileIds
            Array of file IDs from uploaded files
        .PARAMETER ExpiresIn
            Number of days until link expires (default from config or 7 days)
        .INPUTS
            None
        .OUTPUTS
            [PSCustomObject] Response from LiquidFiles API with download link
        .EXAMPLE
            New-LiquidFilesLink -Config $config -FileIds @("id1", "id2") -ExpiresIn 7
        .NOTES
            Returns a URL that can be shared with recipients
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $true)]
        [array]$FileIds,

        [int]$ExpiresIn = 7
    )

    try {
        Write-Detail "Creating filelink (expires in $ExpiresIn days)" -Level Info

        $uri = "$($Config.ServerUrl)/filelinks"

        # Prepare filelink data
        $linkData = @{
            filelink = @{
                files = $FileIds
                expires_at = (Get-Date).AddDays($ExpiresIn).ToString("yyyy-MM-ddTHH:mm:ss")
            }
        }

        $headers = Get-AuthHeaders -ApiKey $Config.ApiKey
        $headers["Content-Type"] = "application/json"

        $body = $linkData | ConvertTo-Json -Depth 10

        # Create filelink
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body

        Write-Detail "Filelink created successfully" -Level Success
        return $response
    }
    catch {
        Write-Detail "Failed to create filelink: $_" -Level Error
        throw
    }
}

# Main execution function
function Start-LiquidFilesUpload {
    <#
        .SYNOPSIS
            Main function to orchestrate the file upload process
        .DESCRIPTION
            Coordinates all components: loads configuration, validates files,
            uploads files, and sends to recipients
        .PARAMETER FilePaths
            Array of file paths to upload
        .PARAMETER RecipientList
            Comma-separated list of recipient email addresses
        .PARAMETER Subject
            Message subject
        .PARAMETER MessageText
            Message body
        .PARAMETER ConfigPath
            Path to configuration file
        .INPUTS
            None
        .OUTPUTS
            Upload results and download link
        .EXAMPLE
            Start-LiquidFilesUpload -FilePaths @("file.pdf") -RecipientList "user@example.com"
        .NOTES
            Main entry point for the script execution
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FilePaths,

        [Parameter(Mandatory = $true)]
        [string]$RecipientList,

        [string]$Subject,
        [string]$MessageText,
        [string]$ConfigPath
    )

    try {
        Write-Detail "=== LiquidFiles Upload Started ===" -Level Info

        # Load configuration
        $config = Get-LiquidFilesConfig -ConfigPath $ConfigPath

        # Resolve and validate file paths
        $files = @()
        foreach ($path in $FilePaths) {
            $resolvedFiles = Get-Item -Path $path -ErrorAction Stop
            $files += $resolvedFiles
        }

        if ($files.Count -eq 0) {
            throw "No files found to upload"
        }

        Write-Detail "Found $($files.Count) file(s) to upload" -Level Info

        # Upload files
        $uploadedFiles = @()
        foreach ($file in $files) {
            if ($file.PSIsContainer) {
                Write-Detail "Skipping directory: $($file.Name)" -Level Warning
                continue
            }

            $uploadResult = Send-FileToLiquidFiles -Config $config -File $file
            $uploadedFiles += $uploadResult.id
        }

        if ($uploadedFiles.Count -eq 0) {
            throw "No files were successfully uploaded"
        }

        # Parse recipients
        $recipients = $RecipientList -split ',' | ForEach-Object { $_.Trim() }

        # Send message to recipients
        $messageResult = Send-LiquidFilesMessage -Config $config -FileIds $uploadedFiles -Recipients $recipients -Subject $Subject -MessageBody $MessageText

        Write-Detail "=== Upload Complete ===" -Level Success
        Write-Detail "Files uploaded: $($uploadedFiles.Count)" -Level Info
        Write-Detail "Recipients notified: $($recipients.Count)" -Level Info

        if ($messageResult.link) {
            Write-Detail "Download link: $($messageResult.link)" -Level Success
        }

        return $messageResult
    }
    catch {
        Write-Detail "Upload failed: $_" -Level Error
        throw
    }
}

# Execute main function
Start-LiquidFilesUpload -FilePaths $FilePath -RecipientList $Recipients -Subject $Subject -MessageText $Message -ConfigPath $ConfigPath
