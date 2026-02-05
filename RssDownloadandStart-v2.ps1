# Refactored script structure with proper functions

<#
    .SYNOPSIS
        Automated torrent downloader for Plex media library management
    .DESCRIPTION
        This script monitors RSS torrent feeds and automatically downloads episodes
        for TV shows that exist in your Plex library but are missing specific episodes.
        Integrates with Plex API to check existing content and avoid duplicates.
    .NOTES
        Requires PowerShell 5.1 or higher
        Requires network access to Plex server and torrent RSS feeds
        Configuration file required (rss-TorrentProcessor-config.json)
    .LINK
        https://github.com/your-repo/torrent-plex-integration
#>

class PlexMedia {
    [string]$GrandparentTitle
    [string]$ParentTitle
    [string]$Title
    [string]$EPString
    [datetime]$AddedAt
    [int]$ParentIndex
    [int]$Index
}

class TorrentItem {
    [string]$Title
    [string]$Link
    [string]$ShowTitle
    [string]$Episode
    [datetime]$PublishDate
}

# Example of improved error handling and configuration management

# Configuration file approach
$ConfigPath = Join-Path $PSScriptRoot "rss-TorrentProcessor-config.json"
if (-not (Test-Path $ConfigPath)) {
    throw "Configuration file not found at $ConfigPath"
}

try {
    $Config = Get-Content $ConfigPath | ConvertFrom-Json
} catch {
    Write-Error "Failed to load configuration: $_"
    exit 1
}

# Improved Write-Detail with logging levels
Function Write-Detail {
<#
    .SYNOPSIS
        Writes formatted messages to console and optionally to log file
    .DESCRIPTION
        Enhanced logging function that supports different log levels with color coding
        and optional file output with timestamps and line numbers
    .PARAMETER Message
        The message to write to the log
    .PARAMETER Level
        The logging level (Info, Warning, Error, Debug, Success). Default is Info
    .PARAMETER LogFile
        Optional path to log file for persistent logging
    .INPUTS
        [String] Message to log
    .OUTPUTS
        Console output with timestamp and formatting
    .EXAMPLE
        Write-Detail -Message "Processing started" -Level Info
    .EXAMPLE
        Write-Detail -Message "Error occurred" -Level Error -LogFile "C:\logs\app.log"
    .EXAMPLE
        Write-Detail -Message "Task completed successfully" -Level Success
    .NOTES
        Includes automatic line number detection and color-coded output
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info',

        [string]$LogFile = $null
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $lineNumber = $MyInvocation.ScriptLineNumber

    # Using format strings for precise alignment
    # {0} = timestamp, {1} = level (padded to 7 chars), {2} = line number (padded to 4 chars), {3} = message
    $logEntry = "[{0}] {1,-7} {2,4} {3}" -f $timestamp, $Level, $lineNumber, $Message

#     $logEntry = "[$timestamp] [$Level] [Line:$($MyInvocation.ScriptLineNumber)] $Message"

    # Console output with colors
    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor White -BackgroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Black -BackgroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Debug'   { Write-Host $logEntry -ForegroundColor Gray }
        default   { Write-Host $logEntry }
    }
    
    # Optional file logging
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logEntry
    }
}

# Improved web request with retry logic
function Invoke-WebRequestWithRetry {
<#
    .SYNOPSIS
        Executes web requests with automatic retry logic
    .DESCRIPTION
        Wrapper around Invoke-WebRequest that includes retry logic with exponential backoff
        for handling transient network failures
    .PARAMETER Uri
        The URI to request
    .PARAMETER Headers
        Hashtable of HTTP headers to include
    .PARAMETER Method
        HTTP method to use (GET, POST, etc.). Default is GET
    .PARAMETER MaxRetries
        Maximum number of retry attempts. Default is 3
    .PARAMETER RetryDelaySeconds
        Delay between retry attempts in seconds. Default is 5
    .INPUTS
        None
    .OUTPUTS
        Microsoft.PowerShell.Commands.WebResponseObject
    .EXAMPLE
        Invoke-WebRequestWithRetry -Uri "https://api.example.com/data"
    .EXAMPLE
        Invoke-WebRequestWithRetry -Uri $uri -Headers $headers -MaxRetries 5
    .NOTES
        Includes timeout handling and detailed logging of retry attempts
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [hashtable]$Headers = @{},
        [string]$Method = 'GET',
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 5
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Detail "Attempting web request to $Uri (Attempt $i/$MaxRetries)" -Level Debug
            return Invoke-WebRequest -Uri $Uri -Headers $Headers -Method $Method -TimeoutSec 30
        }
        catch {
            Write-Detail "Request failed (Attempt $i/$MaxRetries): $_" -Level Warning
            if ($i -eq $MaxRetries) {
                Write-Detail "All retry attempts exhausted for $Uri" -Level Error
                throw
            }
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

# Improved file path validation
function Test-NetworkPath {
<#
    .SYNOPSIS
        Validates and creates network paths with write access testing
    .DESCRIPTION
        Tests if a network path exists, creates it if missing, and verifies write access
        Includes comprehensive error handling for network path operations
    .PARAMETER Path
        The network path to validate and test
    .INPUTS
        [String] Path to validate
    .OUTPUTS
        [Boolean] True if path is accessible and writable
    .EXAMPLE
        Test-NetworkPath -Path "\\server\share\folder"
    .EXAMPLE
        Test-NetworkPath -Path "C:\LocalFolder"
    .NOTES
        Creates missing directories and tests write permissions
        Throws terminating errors for access issues
#>
    param([Parameter(Mandatory = $true)]
          [string]$Path)
    
    if (-not $Path) {
        throw "Path cannot be null or empty"
    }
    
    if (-not (Test-Path $Path)) {
        Write-Detail "Creating directory: $Path" -Level Info
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
        catch {
            throw "Failed to create directory $Path`: $_"
        }
    }
    
    # Test write access
    try {
        # Generate a unique filename using temp file approach
        $tempFile = [System.IO.Path]::GetTempFileName()
        $testFileName = [System.IO.Path]::GetFileName($tempFile)
        $targetTestFile = Join-Path -Path $Path -ChildPath $testFileName
        
        # Clean up the temp file since we only needed the name
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        
        # Test write by creating and removing a file in target directory
        "test" | Out-File -FilePath $targetTestFile -Force
        Remove-Item -Path $targetTestFile -Force
        
        return $true
    }
    catch {
        throw "No write access to path $Path`: $_"
 
    }
}


function Get-PlexAuthToken {
<#
    .SYNOPSIS
        Retrieves a delegation token from Plex Media Server
    .DESCRIPTION
        Exchanges a permanent Plex token for a temporary delegation token
        used for subsequent API calls
    .PARAMETER ServerUrl
        Base URL of the Plex Media Server (e.g., http://localhost:32400)
    .PARAMETER AuthToken
        Permanent Plex authentication token
    .INPUTS
        None
    .OUTPUTS
        [String] Delegation token for API access
    .EXAMPLE
        Get-PlexAuthToken -ServerUrl "http://server:port" -AuthToken "xyz123"
    .NOTES
        Requires valid Plex server access and authentication token
#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerUrl,
        [Parameter(Mandatory = $true)]
        [string]$AuthToken
    )
    
    try {
        $uri = "$ServerUrl/security/token?type=delegation&scope=all"
        $response = Invoke-WebRequestWithRetry -Uri $uri -Headers @{'X-Plex-Token' = $AuthToken}
        $xml = [xml]$response.Content
        return $xml.MediaContainer.token
    }
    catch {
        Write-Detail "Failed to get Plex auth token: $_" -Level Error
        throw
    }
}

function Get-PlexLibraryContent {
<#
    .SYNOPSIS
        Retrieves all TV show episodes from specified Plex library
    .DESCRIPTION
        Connects to Plex Media Server and retrieves detailed information about
        all TV show episodes in the specified library section
    .PARAMETER ServerUrl
        Base URL of the Plex Media Server
    .PARAMETER AuthToken
        Plex authentication token (delegation token preferred)
    .PARAMETER LibraryId
        Plex library section ID for TV shows. Default is 1
    .INPUTS
        None
    .OUTPUTS
        [PlexMedia[]] Array of PlexMedia objects containing episode information
    .EXAMPLE
        Get-PlexLibraryContent -ServerUrl $server -AuthToken $token -LibraryId 2
    .NOTES
        Processes all shows and episodes in the library
        May take time for large libraries
#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerUrl,
        [Parameter(Mandatory = $true)]
        [string]$AuthToken,
        [int]$LibraryId = 1
    )
    
    $allMedia = @()
    
    try {
        # Get library sections
        $uri = "$ServerUrl/library/sections/$LibraryId/all?type=2"
        $response = Invoke-WebRequestWithRetry -Uri $uri -Headers @{'X-Plex-Token' = $AuthToken}
        $library = [xml]$response.Content
        
        Write-Detail "Processing $($library.MediaContainer.Directory.Count) shows from Plex library"
        
        foreach ($show in $library.MediaContainer.Directory) {
            Write-Detail "Processing: $($show.title) ($($show.childCount) seasons, $($show.leafCount) episodes)"
            
            # Get all episodes for this show
            $episodesUri = "$ServerUrl/library/metadata/$($show.ratingKey)/allLeaves"
            $episodesResponse = Invoke-WebRequestWithRetry -Uri $episodesUri -Headers @{'X-Plex-Token' = $AuthToken}
            $episodes = ([xml]$episodesResponse.Content).MediaContainer.Video
            
            foreach ($episode in $episodes) {
                $media = [PlexMedia]::new()
                $media.GrandparentTitle = ($episode.grandparentTitle -replace "'", "").Trim()
                $media.ParentTitle = ($episode.parentTitle -replace "'", "").Trim()
                $media.Title = $episode.title
                $media.EPString = "S$($episode.parentIndex.ToString().PadLeft(2, '0'))E$($episode.index.ToString().PadLeft(2, '0'))"
                # $media.AddedAt = [datetime]::FromFileTime($episode.addedAt * 10000000 + 621355968000000000)
                $media.AddedAt = [datetime]::FromFileTime($episode.addedAt)
                $media.ParentIndex = $episode.parentIndex
                $media.Index = $episode.index
                
                $allMedia += $media
            }
        }
        
        return $allMedia
    }
    catch {
        Write-Detail "Failed to get Plex library content: $_" -Level Error
        throw
    }
}

function Get-TorrentFeed {
<#
    .SYNOPSIS
        Parses RSS torrent feed and extracts TV episode information
    .DESCRIPTION
        Downloads and parses an RSS feed containing torrent links,
        extracting show titles and episode numbers using regex patterns
    .PARAMETER RssUrl
        URL of the RSS torrent feed
    .INPUTS
        None
    .OUTPUTS
        [TorrentItem[]] Array of TorrentItem objects with parsed episode data
    .EXAMPLE
        Get-TorrentFeed -RssUrl "https://example.com/rss/feed"
    .NOTES
        Uses regex pattern matching to identify TV show episodes
        Filters out non-matching torrent titles
#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RssUrl
    )
    
    try {
        Write-Detail "Fetching torrent RSS feed"
        $response = Invoke-WebRequestWithRetry -Uri $RssUrl
        $rss = [xml]$response.Content
        
        $torrents = @()
        $regex = '(.*?)(S\d{2}E\d{2})'
        
        foreach ($item in $rss.rss.channel.item) {
            $match = [Regex]::Match($item.title, $regex)
            if ($match.Success) {
                $torrent = [TorrentItem]::new()
                $torrent.Title = $item.title
                $torrent.Link = $item.link
                $torrent.ShowTitle = $match.Groups[1].Value.Trim()
                $torrent.Episode = $match.Groups[2].Value.Trim()
                $torrent.PublishDate = [datetime]$item.pubDate
                
                $torrents += $torrent
            }
        }
        
        Write-Detail "Found $($torrents.Count) valid torrent episodes"
        return $torrents | Sort-Object ShowTitle, Episode
    }
    catch {
        Write-Detail "Failed to get torrent feed: $_" -Level Error
        throw
    }
}

function Test-EpisodeExists {
<#
    .SYNOPSIS
        Checks if a specific TV episode exists in the Plex library
    .DESCRIPTION
        Searches the Plex media library for a specific show title and episode
        to determine if it already exists before downloading
    .PARAMETER PlexLibrary
        Array of PlexMedia objects representing the current library
    .PARAMETER ShowTitle
        Name of the TV show to search for
    .PARAMETER Episode
        Episode identifier in SxxExx format
    .INPUTS
        None
    .OUTPUTS
        [PlexMedia] Matching episode object if found, null otherwise
    .EXAMPLE
        Test-EpisodeExists -PlexLibrary $library -ShowTitle "Breaking Bad" -Episode "S01E01"
    .NOTES
        Performs case-insensitive title matching
#>
    param(
        [Parameter(Mandatory = $true)]
        [PlexMedia[]]$PlexLibrary,
        [Parameter(Mandatory = $true)]
        [string]$ShowTitle,
        [Parameter(Mandatory = $true)]
        [string]$Episode
    )
    
    return $PlexLibrary | Where-Object { 
        $_.GrandparentTitle -eq $ShowTitle -and $_.EPString -eq $Episode 
    }
}

function Download-Torrent {
<#
    .SYNOPSIS
        Downloads torrent files to specified directory
    .DESCRIPTION
        Downloads torrent files from RSS feed links, handles duplicate detection,
        and manages file placement in download and completed directories
    .PARAMETER Torrent
        TorrentItem object containing download information
    .PARAMETER DownloadPath
        Directory path for active downloads
    .PARAMETER CompletedPath
        Directory path for completed downloads
    .INPUTS
        None
    .OUTPUTS
        [Boolean] True if download was successful, False if skipped or failed
    .EXAMPLE
        Download-Torrent -Torrent $torrent -DownloadPath "C:\Downloads" -CompletedPath "C:\Completed"
    .NOTES
        Includes duplicate detection and error handling
        Uses temporary files to prevent corruption
#>
    param(
        [Parameter(Mandatory = $true)]
        [TorrentItem]$Torrent,
        [Parameter(Mandatory = $true)]
        [string]$DownloadPath,
        [Parameter(Mandatory = $true)]
        [string]$CompletedPath
    )
    
    try {
        # Get filename from headers
        $headResponse = Invoke-WebRequest -Uri $Torrent.Link -Method HEAD
        $filename = ($headResponse.Headers.'Content-Disposition' -split "=")[1] -replace '"', ''
        
        $downloadFile = Join-Path -Path $DownloadPath -ChildPath $filename
        $completedFile = Join-Path -Path $CompletedPath -ChildPath $filename
        
        # Check if already completed
        if (Test-Path -Path $completedFile) {
            Write-Detail "Already completed: $filename" -Level Info
            return $false
        }
        
        # Check if already downloading
        if (Test-Path -Path $downloadFile) {
            Write-Detail "Already downloading: $filename" -Level Info
            return $false
        }
        
        # Download torrent
        Write-Detail "Downloading: $filename"
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        Invoke-WebRequest -Uri $Torrent.Link -OutFile $tempFile -TimeoutSec 60
        Move-Item -Path $tempFile -Destination $downloadFile
        
        Write-Detail "Successfully downloaded: $filename" -Level Info
        return $true
    }
    catch {
        Write-Detail "Failed to download torrent $($Torrent.Title): $_" -Level Error
        return $false
    }
}

# Main execution function
function Start-TorrentProcessor {
<#
    .SYNOPSIS
        Main function to orchestrate the torrent downloading process
    .DESCRIPTION
        Coordinates all components: loads configuration, connects to Plex,
        retrieves torrent feeds, compares content, and downloads missing episodes
    .PARAMETER ConfigPath
        Path to the JSON configuration file. Default is "rss-TorrentProcessor-config.json"
    .INPUTS
        None
    .OUTPUTS
        Console logging of process status
    .EXAMPLE
        Start-TorrentProcessor
    .EXAMPLE
        Start-TorrentProcessor -ConfigPath "C:\Config\torrents.json"
    .NOTES
        Requires valid configuration file with Plex and torrent settings
        Main entry point for the script execution
#>
    param(
        [string]$ConfigPath = "rss-TorrentProcessor-config.json"
    )
    
    try {
        # Load configuration
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        
        # Validate paths
        Test-NetworkPath -Path $config.Paths.Download
        Test-NetworkPath -Path $config.Paths.Completed
        
        # Get Plex content
        $authToken = Get-PlexAuthToken -ServerUrl $config.Plex.ServerUrl -AuthToken $config.Plex.Token
        $plexLibrary = Get-PlexLibraryContent -ServerUrl $config.Plex.ServerUrl -AuthToken $authToken
        
        # Get available torrents
        $torrents = Get-TorrentFeed -RssUrl $config.Torrent.RssUrl
        
        # Process torrents
        $downloadCount = 0
        $showTitles = $plexLibrary.GrandparentTitle | Select-Object -Unique
        
        foreach ($torrent in $torrents) {
            Write-Detail $torrent.ShowTitle -Level Info
            
            if ($showTitles -contains $torrent.ShowTitle) {
                if (-not (Test-EpisodeExists -PlexLibrary $plexLibrary -ShowTitle $torrent.ShowTitle -Episode $torrent.Episode)) {
                    Write-Detail "New episode found: $($torrent.ShowTitle) - $($torrent.Episode)"
                    
                    if (Download-Torrent -Torrent $torrent -DownloadPath $config.Paths.Download -CompletedPath $config.Paths.Completed) {
                        $downloadCount++
                        Start-Sleep -Milliseconds 500  # Rate limiting
                    }
                }
            }
        }
        
        Write-Detail "Processing complete. Downloaded $downloadCount new episodes." -Level Info
    }
    catch {
        Write-Detail "Script execution failed: $_" -Level Error
        throw
    }
}

Start-TorrentProcessor -ConfigPath $ConfigPath
