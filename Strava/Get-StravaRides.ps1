# Get-StravaRides.ps1
# Version 1.0.0 - 2026-03-15
# Downloads the last N months of Strava rides (with full segment effort data)
# and saves them as JSON files for offline analysis.
#
# Usage:
#   .\Get-StravaRides.ps1                          # Download last 6 months
#   .\Get-StravaRides.ps1 -Months 3                # Download last 3 months
#   .\Get-StravaRides.ps1 -Force                   # Re-download already saved rides
#   .\Get-StravaRides.ps1 -SkipDetails             # List only, skip per-activity API calls
#
# Prerequisites:
#   1. Create strava-config.json from strava-config.json.template
#   2. Fill in ClientId and ClientSecret from https://www.strava.com/settings/api
#   3. Run script - a browser window opens for OAuth authorization on first run

param(
    [int]$Months = 6,
    [switch]$Force,
    [switch]$SkipDetails,
    [string]$ConfigPath = "$PSScriptRoot\strava-config.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
function Write-Detail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $caller    = (Get-PSCallStack)[1]
    $line      = $caller.ScriptLineNumber
    $color = switch ($Level) {
        'Info'    { 'Gray'    }
        'Success' { 'Green'   }
        'Warning' { 'Yellow'  }
        'Error'   { 'Red'     }
        'Debug'   { 'Cyan'    }
    }
    Write-Host "[$timestamp][$Level][L$line] $Message" -ForegroundColor $color
}

# ---------------------------------------------------------------------------
# Config helpers
# ---------------------------------------------------------------------------
function Load-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path`nCopy strava-config.json.template to strava-config.json and fill in your credentials."
    }
    $cfg = Get-Content $Path -Raw | ConvertFrom-Json
    foreach ($field in @('ClientId', 'ClientSecret')) {
        if (-not $cfg.$field -or $cfg.$field -like 'YOUR_*') {
            throw "Missing required config field '$field' in $Path"
        }
    }
    return $cfg
}

function Save-Config {
    param($Config, [string]$Path)
    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
}

# ---------------------------------------------------------------------------
# OAuth2 - Authorization Code Flow
# ---------------------------------------------------------------------------
function Get-AuthorizationCode {
    param($Config)

    $authUrl = "https://www.strava.com/oauth/authorize" +
               "?client_id=$($Config.ClientId)" +
               "&redirect_uri=http://localhost" +
               "&response_type=code" +
               "&approval_prompt=force" +
               "&scope=activity:read_all,read"

    Write-Detail "Opening browser for Strava authorization..." -Level Info
    Write-Host ""
    Write-Host "If the browser doesn't open automatically, go to:" -ForegroundColor White
    Write-Host $authUrl -ForegroundColor Cyan
    Write-Host ""

    try { Start-Process $authUrl } catch { }

    Write-Host "After authorizing, you will be redirected to a localhost URL that won't load." -ForegroundColor White
    Write-Host "Copy the full URL from the browser address bar and paste it here:" -ForegroundColor White
    $redirectUrl = Read-Host "Redirect URL"

    if ($redirectUrl -match '[?&]code=([^&]+)') {
        return $Matches[1]
    }
    throw "Could not extract authorization code from URL: $redirectUrl"
}

function Get-NewTokens {
    param($Config, [string]$AuthCode)

    $body = @{
        client_id     = $Config.ClientId
        client_secret = $Config.ClientSecret
        code          = $AuthCode
        grant_type    = 'authorization_code'
    }

    Write-Detail "Exchanging authorization code for tokens..." -Level Info
    $response = Invoke-RestMethod -Uri 'https://www.strava.com/oauth/token' `
                                  -Method POST `
                                  -Body $body `
                                  -ErrorAction Stop
    return $response
}

function Refresh-AccessToken {
    param($Config)

    if (-not $Config.RefreshToken) {
        throw "No refresh token available. Run the full OAuth flow first."
    }

    $body = @{
        client_id     = $Config.ClientId
        client_secret = $Config.ClientSecret
        refresh_token = $Config.RefreshToken
        grant_type    = 'refresh_token'
    }

    Write-Detail "Refreshing access token..." -Level Info
    $response = Invoke-RestMethod -Uri 'https://www.strava.com/oauth/token' `
                                  -Method POST `
                                  -Body $body `
                                  -ErrorAction Stop
    return $response
}

function Ensure-ValidToken {
    param($Config, [string]$ConfigPath)

    # No token yet - do full OAuth flow
    if (-not $Config.RefreshToken) {
        Write-Detail "No tokens stored. Starting OAuth authorization flow." -Level Warning
        $code   = Get-AuthorizationCode -Config $Config
        $tokens = Get-NewTokens -Config $Config -AuthCode $code
    }
    else {
        # Check if token is still valid (with 5 min buffer)
        $expiry = [DateTimeOffset]::FromUnixTimeSeconds([long]$Config.TokenExpiry)
        if ([DateTimeOffset]::UtcNow.AddMinutes(5) -lt $expiry) {
            Write-Detail "Access token still valid (expires $($expiry.LocalDateTime))" -Level Debug
            return $Config.AccessToken
        }
        $tokens = Refresh-AccessToken -Config $Config
    }

    # Persist updated tokens
    $Config.AccessToken  = $tokens.access_token
    $Config.RefreshToken = $tokens.refresh_token
    $Config.TokenExpiry  = $tokens.expires_at
    if ($tokens.athlete) {
        $Config.AthleteId = $tokens.athlete.id.ToString()
    }
    Save-Config -Config $Config -Path $ConfigPath
    Write-Detail "Token refreshed successfully. Athlete ID: $($Config.AthleteId)" -Level Success

    return $tokens.access_token
}

# ---------------------------------------------------------------------------
# Strava API helpers
# ---------------------------------------------------------------------------
function Invoke-StravaApi {
    param(
        [string]$Token,
        [string]$Endpoint,
        [hashtable]$Query = @{}
    )

    $baseUrl = "https://www.strava.com/api/v3"
    $uri = "$baseUrl/$Endpoint"

    if ($Query.Count -gt 0) {
        $queryString = ($Query.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'
        $uri = "$uri?$queryString"
    }

    $headers = @{ Authorization = "Bearer $Token" }

    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -ErrorAction Stop
        return $response
    }
    catch {
        $statusCode = $_.Exception.Response?.StatusCode?.value__
        if ($statusCode -eq 429) {
            $retryAfter = $_.Exception.Response.Headers['X-RateLimit-Reset']
            Write-Detail "Rate limited by Strava API. Waiting 15 minutes..." -Level Warning
            Start-Sleep -Seconds 900
            return Invoke-StravaApi -Token $Token -Endpoint $Endpoint -Query $Query
        }
        throw "Strava API error ($statusCode) on $Endpoint`: $($_.Exception.Message)"
    }
}

function Get-AllActivities {
    param(
        [string]$Token,
        [long]$AfterEpoch,
        [long]$BeforeEpoch
    )

    $activities = [System.Collections.Generic.List[object]]::new()
    $page       = 1
    $perPage    = 100

    Write-Detail "Fetching activity list from Strava..." -Level Info

    do {
        Write-Detail "  Page $page..." -Level Debug
        $batch = Invoke-StravaApi -Token $Token `
                                  -Endpoint 'athlete/activities' `
                                  -Query @{
                                      after    = $AfterEpoch
                                      before   = $BeforeEpoch
                                      page     = $page
                                      per_page = $perPage
                                  }

        if (-not $batch -or $batch.Count -eq 0) { break }

        # Filter to cycling activities only
        $rides = $batch | Where-Object { $_.type -in @('Ride', 'VirtualRide', 'MountainBikeRide', 'GravelRide', 'EBikeRide') }
        $activities.AddRange([object[]]$rides)
        Write-Detail "  Found $($rides.Count) rides on page $page (total: $($activities.Count))" -Level Info

        $page++
    } while ($batch.Count -eq $perPage)

    return $activities
}

function Get-ActivityDetail {
    param(
        [string]$Token,
        [long]$ActivityId
    )
    return Invoke-StravaApi -Token $Token -Endpoint "activities/$ActivityId" -Query @{ include_all_efforts = 'true' }
}

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------
function Get-ActivityFilePath {
    param([string]$DataDir, $Activity)
    $date = ([DateTimeOffset]$Activity.start_date).ToString("yyyy-MM-dd")
    $name = $Activity.name -replace '[\\/:*?"<>|]', '_'
    return Join-Path $DataDir "$date`_$($Activity.id)`_$name.json"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
function Main {
    Write-Host ""
    Write-Detail ("=" * 70) -Level Info
    Write-Detail "  Get-StravaRides v1.0.0 - Strava Ride Downloader" -Level Info
    Write-Detail ("=" * 70) -Level Info
    Write-Host ""

    # Load configuration
    Write-Detail "Loading config from: $ConfigPath" -Level Info
    $config = Load-Config -Path $ConfigPath

    # Resolve data directory relative to script
    $dataDir = if ([System.IO.Path]::IsPathRooted($config.DataDirectory)) {
        $config.DataDirectory
    } else {
        Join-Path $PSScriptRoot $config.DataDirectory
    }

    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        Write-Detail "Created data directory: $dataDir" -Level Info
    }

    # OAuth
    $token = Ensure-ValidToken -Config $config -ConfigPath $ConfigPath

    # Date range - last N months
    $now        = [DateTimeOffset]::UtcNow
    $afterDate  = $now.AddMonths(-$Months)
    $afterEpoch = $afterDate.ToUnixTimeSeconds()
    $beforeEpoch = $now.ToUnixTimeSeconds()

    Write-Detail "Date range: $($afterDate.ToString('yyyy-MM-dd')) to $($now.ToString('yyyy-MM-dd')) ($Months months)" -Level Info
    Write-Host ""

    # Fetch activity list
    $activities = Get-AllActivities -Token $token -AfterEpoch $afterEpoch -BeforeEpoch $beforeEpoch

    if ($activities.Count -eq 0) {
        Write-Detail "No cycling activities found in the specified date range." -Level Warning
        return
    }

    Write-Detail "Found $($activities.Count) cycling activities total." -Level Success
    Write-Host ""

    # Download individual activity details (includes segment_efforts)
    $downloaded = 0
    $skipped    = 0
    $errors     = 0

    foreach ($activity in $activities) {
        $filePath = Get-ActivityFilePath -DataDir $dataDir -Activity $activity

        if ((Test-Path $filePath) -and -not $Force) {
            Write-Detail "  SKIP  [$($activity.start_date_local)] $($activity.name)" -Level Debug
            $skipped++
            continue
        }

        if ($SkipDetails) {
            # Save list-level data only (no per-activity API call)
            $activity | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
            $downloaded++
            Write-Detail "  SAVED [$($activity.start_date_local)] $($activity.name) (list data only)" -Level Info
            continue
        }

        try {
            Write-Detail "  FETCH [$($activity.start_date_local)] $($activity.name) (id: $($activity.id))" -Level Info
            $detail = Get-ActivityDetail -Token $token -ActivityId $activity.id
            $detail | ConvertTo-Json -Depth 15 | Set-Content -Path $filePath -Encoding UTF8
            $downloaded++

            $segCount = if ($detail.segment_efforts) { $detail.segment_efforts.Count } else { 0 }
            Write-Detail "        Saved - $($detail.distance / 1000 -as [int]) km, $segCount segment efforts" -Level Success

            # Strava rate limit: 100 req/15min, 1000/day - add small delay
            Start-Sleep -Milliseconds 200
        }
        catch {
            Write-Detail "  ERROR downloading activity $($activity.id): $($_.Exception.Message)" -Level Error
            $errors++
        }
    }

    Write-Host ""
    Write-Detail ("=" * 70) -Level Info
    Write-Detail "Download complete:" -Level Success
    Write-Detail "  Downloaded : $downloaded activities" -Level Info
    Write-Detail "  Skipped    : $skipped (already on disk, use -Force to re-download)" -Level Info
    Write-Detail "  Errors     : $errors" -Level Info
    Write-Detail "  Data path  : $dataDir" -Level Info
    Write-Detail ("=" * 70) -Level Info
    Write-Host ""

    # Save a summary index file
    $indexPath = Join-Path $dataDir "_index.json"
    $index = $activities | Select-Object id, name, type, start_date, start_date_local,
                                          distance, moving_time, elapsed_time,
                                          total_elevation_gain, average_speed, max_speed,
                                          average_watts, weighted_average_watts, max_watts,
                                          average_heartrate, max_heartrate, suffer_score,
                                          map
    $index | ConvertTo-Json -Depth 5 | Set-Content -Path $indexPath -Encoding UTF8
    Write-Detail "Activity index saved to: $indexPath" -Level Info
    Write-Host ""
}

Main
