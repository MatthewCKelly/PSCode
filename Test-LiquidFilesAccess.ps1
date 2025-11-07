<#
    .SYNOPSIS
        Test LiquidFiles API access and retrieve file information
    .DESCRIPTION
        This script tests connectivity to LiquidFiles API and can retrieve
        information about files, messages, and filelinks to verify API access.
    .PARAMETER FileId
        Optional specific file ID to retrieve information about
    .PARAMETER MessageId
        Optional specific message ID to retrieve information about
    .PARAMETER ListMessages
        Switch to list recent messages
    .PARAMETER ListFilelinks
        Switch to list recent filelinks
    .PARAMETER ConfigPath
        Path to the JSON configuration file. Default is "liquidfiles-config.json"
    .INPUTS
        None
    .OUTPUTS
        API response with file/message information
    .EXAMPLE
        Test-LiquidFilesAccess.ps1 -ListMessages
    .EXAMPLE
        Test-LiquidFilesAccess.ps1 -FileId "abc123"
    .EXAMPLE
        Test-LiquidFilesAccess.ps1 -MessageId "msg456"
    .NOTES
        Requires PowerShell 5.1 or higher
        Configuration file required (liquidfiles-config.json)
    .LINK
        https://docs.liquidfiles.com/api/v4.1/
#>

[CmdletBinding(DefaultParameterSetName = 'TestConnection')]
param(
    [Parameter(ParameterSetName = 'GetFile')]
    [string]$FileId,

    [Parameter(ParameterSetName = 'GetMessage')]
    [string]$MessageId,

    [Parameter(ParameterSetName = 'ListMessages')]
    [switch]$ListMessages,

    [Parameter(ParameterSetName = 'ListFilelinks')]
    [switch]$ListFilelinks,

    [string]$ConfigPath = (Join-Path $PSScriptRoot "liquidfiles-config.json")
)

# Enhanced logging function with color-coded output
function Write-Detail {
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

# Load configuration
function Get-LiquidFilesConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found at: $ConfigPath`nPlease copy liquidfiles-config.json.template to liquidfiles-config.json and configure it."
    }

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        if (-not $config.ServerUrl) {
            throw "ServerUrl is missing from configuration file"
        }
        if (-not $config.ApiKey) {
            throw "ApiKey is missing from configuration file"
        }

        $config.ServerUrl = $config.ServerUrl.TrimEnd('/')
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
            [Hashtable] Headers with Authorization and Accept
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
        "Accept" = "application/json"
    }
}

# Test basic API connectivity
function Test-ApiConnection {
    <#
        .SYNOPSIS
            Tests basic connectivity to LiquidFiles API
        .DESCRIPTION
            Attempts to connect to the API and retrieve server information
            to verify credentials and connectivity
        .PARAMETER Config
            Configuration object containing API credentials
        .OUTPUTS
            [Boolean] True if connection successful
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    try {
        Write-Detail "Testing API connection to $($Config.ServerUrl)" -Level Info

        $uri = "$($Config.ServerUrl)/account"
        $headers = Get-AuthHeaders -ApiKey $Config.ApiKey

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop

        Write-Detail "API connection successful!" -Level Success
        Write-Detail "Server: $($Config.ServerUrl)" -Level Info

        if ($response) {
            Write-Host "`nAccount Information:" -ForegroundColor Cyan
            $response | ConvertTo-Json -Depth 5 | Write-Host
        }

        return $true
    }
    catch {
        Write-Detail "API connection failed: $_" -Level Error

        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Detail "Authentication failed. Please check your API key." -Level Error
        }
        elseif ($_.Exception.Response.StatusCode -eq 404) {
            Write-Detail "Endpoint not found. Please check your ServerUrl." -Level Error
        }

        return $false
    }
}

# Get specific file information
function Get-LiquidFile {
    <#
        .SYNOPSIS
            Retrieves information about a specific file
        .DESCRIPTION
            Gets detailed information about a file by its ID
        .PARAMETER Config
            Configuration object containing API credentials
        .PARAMETER FileId
            The ID of the file to retrieve
        .OUTPUTS
            File information from LiquidFiles API
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $true)]
        [string]$FileId
    )

    try {
        Write-Detail "Retrieving file information for ID: $FileId" -Level Info

        $uri = "$($Config.ServerUrl)/files/$FileId"
        $headers = Get-AuthHeaders -ApiKey $Config.ApiKey

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

        Write-Detail "File retrieved successfully" -Level Success
        Write-Host "`nFile Information:" -ForegroundColor Cyan
        $response | ConvertTo-Json -Depth 5 | Write-Host

        return $response
    }
    catch {
        Write-Detail "Failed to retrieve file: $_" -Level Error
        throw
    }
}

# Get specific message information
function Get-LiquidMessage {
    <#
        .SYNOPSIS
            Retrieves information about a specific message
        .DESCRIPTION
            Gets detailed information about a message by its ID
        .PARAMETER Config
            Configuration object containing API credentials
        .PARAMETER MessageId
            The ID of the message to retrieve
        .OUTPUTS
            Message information from LiquidFiles API
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $true)]
        [string]$MessageId
    )

    try {
        Write-Detail "Retrieving message information for ID: $MessageId" -Level Info

        $uri = "$($Config.ServerUrl)/messages/$MessageId"
        $headers = Get-AuthHeaders -ApiKey $Config.ApiKey

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

        Write-Detail "Message retrieved successfully" -Level Success
        Write-Host "`nMessage Information:" -ForegroundColor Cyan
        $response | ConvertTo-Json -Depth 5 | Write-Host

        return $response
    }
    catch {
        Write-Detail "Failed to retrieve message: $_" -Level Error
        throw
    }
}

# List recent messages
function Get-LiquidMessages {
    <#
        .SYNOPSIS
            Lists recent messages
        .DESCRIPTION
            Retrieves a list of recent messages from LiquidFiles
        .PARAMETER Config
            Configuration object containing API credentials
        .OUTPUTS
            Array of message objects
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    try {
        Write-Detail "Retrieving recent messages" -Level Info

        $uri = "$($Config.ServerUrl)/messages"
        $headers = Get-AuthHeaders -ApiKey $Config.ApiKey

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

        Write-Detail "Messages retrieved successfully" -Level Success

        if ($response) {
            Write-Host "`nRecent Messages:" -ForegroundColor Cyan

            if ($response.PSObject.Properties['messages']) {
                $messages = $response.messages
            } else {
                $messages = $response
            }

            if ($messages -is [array] -and $messages.Count -gt 0) {
                Write-Host "Found $($messages.Count) message(s):" -ForegroundColor Yellow
                $messages | Format-Table -AutoSize -Property id, subject, sender, @{Name="Recipients"; Expression={$_.recipients -join ", "}}, created_at
                Write-Host "`nFull Details:" -ForegroundColor Cyan
                $response | ConvertTo-Json -Depth 5 | Write-Host
            } else {
                Write-Host "No messages found or unexpected response format" -ForegroundColor Yellow
                $response | ConvertTo-Json -Depth 5 | Write-Host
            }
        }

        return $response
    }
    catch {
        Write-Detail "Failed to retrieve messages: $_" -Level Error
        throw
    }
}

# List recent filelinks
function Get-LiquidFilelinks {
    <#
        .SYNOPSIS
            Lists recent filelinks
        .DESCRIPTION
            Retrieves a list of recent filelinks from LiquidFiles
        .PARAMETER Config
            Configuration object containing API credentials
        .OUTPUTS
            Array of filelink objects
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    try {
        Write-Detail "Retrieving recent filelinks" -Level Info

        $uri = "$($Config.ServerUrl)/filelinks"
        $headers = Get-AuthHeaders -ApiKey $Config.ApiKey

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

        Write-Detail "Filelinks retrieved successfully" -Level Success

        if ($response) {
            Write-Host "`nRecent Filelinks:" -ForegroundColor Cyan

            if ($response.PSObject.Properties['filelinks']) {
                $filelinks = $response.filelinks
            } else {
                $filelinks = $response
            }

            if ($filelinks -is [array] -and $filelinks.Count -gt 0) {
                Write-Host "Found $($filelinks.Count) filelink(s):" -ForegroundColor Yellow
                $filelinks | Format-Table -AutoSize -Property id, link, expires_at, downloads
                Write-Host "`nFull Details:" -ForegroundColor Cyan
                $response | ConvertTo-Json -Depth 5 | Write-Host
            } else {
                Write-Host "No filelinks found or unexpected response format" -ForegroundColor Yellow
                $response | ConvertTo-Json -Depth 5 | Write-Host
            }
        }

        return $response
    }
    catch {
        Write-Detail "Failed to retrieve filelinks: $_" -Level Error
        throw
    }
}

# Main execution
try {
    Write-Detail "=== LiquidFiles API Access Test ===" -Level Info

    # Load configuration
    $config = Get-LiquidFilesConfig -ConfigPath $ConfigPath

    # Execute based on parameter set
    switch ($PSCmdlet.ParameterSetName) {
        'GetFile' {
            Get-LiquidFile -Config $config -FileId $FileId
        }
        'GetMessage' {
            Get-LiquidMessage -Config $config -MessageId $MessageId
        }
        'ListMessages' {
            Get-LiquidMessages -Config $config
        }
        'ListFilelinks' {
            Get-LiquidFilelinks -Config $config
        }
        'TestConnection' {
            # Default: Test connection
            $result = Test-ApiConnection -Config $config

            if ($result) {
                Write-Host "`n" -NoNewline
                Write-Detail "You can now test other commands:" -Level Info
                Write-Host "  - List messages:  .\Test-LiquidFilesAccess.ps1 -ListMessages" -ForegroundColor Gray
                Write-Host "  - List filelinks: .\Test-LiquidFilesAccess.ps1 -ListFilelinks" -ForegroundColor Gray
                Write-Host "  - Get message:    .\Test-LiquidFilesAccess.ps1 -MessageId 'id'" -ForegroundColor Gray
                Write-Host "  - Get file:       .\Test-LiquidFilesAccess.ps1 -FileId 'id'" -ForegroundColor Gray
            }
        }
    }

    Write-Detail "`n=== Test Complete ===" -Level Success
}
catch {
    Write-Detail "Test failed: $_" -Level Error
    exit 1
}
