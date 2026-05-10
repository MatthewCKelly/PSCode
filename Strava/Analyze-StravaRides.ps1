# Analyze-StravaRides.ps1
# Version 1.0.0 - 2026-03-15
#
# Analyzes downloaded Strava ride data to:
#   - Identify your most frequently ridden segments
#   - Flag segments suitable for VO2 Max interval training (3-8 min, high effort)
#   - Estimate VO2 Max training zones from power and/or HR data
#   - Generate structured workout plans targeting your key climbs and sprints
#   - Export an HTML report + Strava workout descriptions
#
# Usage:
#   .\Analyze-StravaRides.ps1                          # Full analysis + HTML report
#   .\Analyze-StravaRides.ps1 -TopSegments 20          # Show top 20 segments
#   .\Analyze-StravaRides.ps1 -FTPWatts 250            # Provide FTP for zone calc
#   .\Analyze-StravaRides.ps1 -MaxHR 178               # Provide MaxHR for HR zones
#   .\Analyze-StravaRides.ps1 -ReportOnly               # Skip workout gen, report only
#
# VO2 Max Training Theory (Seiler / Coggan):
#   - VO2 Max intervals: 3-8 minutes at ~106-120% of FTP (or ~90-95% MaxHR)
#   - Typical session: 4-6 reps with equal recovery (e.g., 5x5min w/ 5min rest)
#   - Weekly volume: 2 VO2 Max sessions max; always leave 48h recovery
#   - Target segments: climbs or flat stretches lasting 3-8 min at max effort

param(
    [string]$DataDirectory  = "$PSScriptRoot\Data",
    [string]$ConfigPath     = "$PSScriptRoot\strava-config.json",
    [int]$TopSegments       = 15,
    [int]$FTPWatts          = 0,       # 0 = auto-estimate from ride data
    [int]$MaxHR             = 0,       # 0 = auto-estimate (220 - age, or from data)
    [int]$AthleteAgeYears   = 0,       # Used only if MaxHR not provided
    [switch]$ReportOnly,
    [switch]$Verbose
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
    if ($Level -eq 'Debug' -and -not $Verbose) { return }
    Write-Host "[$timestamp][$Level][L$line] $Message" -ForegroundColor $color
}

# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------
function Load-RideFiles {
    param([string]$Dir)

    if (-not (Test-Path $Dir)) {
        throw "Data directory not found: $Dir`nRun Get-StravaRides.ps1 first."
    }

    $files = Get-ChildItem -Path $Dir -Filter '*.json' | Where-Object { $_.Name -notlike '_*' }

    if ($files.Count -eq 0) {
        throw "No ride JSON files found in: $Dir`nRun Get-StravaRides.ps1 first."
    }

    Write-Detail "Loading $($files.Count) ride files..." -Level Info
    $rides = foreach ($f in $files) {
        try {
            $obj = Get-Content $f.FullName -Raw | ConvertFrom-Json
            # Ensure segment_efforts is an array (may be null for list-only downloads)
            if ($null -eq $obj.segment_efforts) {
                $obj | Add-Member -NotePropertyName segment_efforts -NotePropertyValue @() -Force
            }
            $obj
        }
        catch {
            Write-Detail "Could not parse $($f.Name): $($_.Exception.Message)" -Level Warning
        }
    }
    Write-Detail "Loaded $($rides.Count) rides successfully." -Level Success
    return $rides
}

# ---------------------------------------------------------------------------
# Zone calculations
# ---------------------------------------------------------------------------
function Get-PowerZones {
    param([int]$FTP)
    # Coggan power zones (% of FTP)
    return [ordered]@{
        'Z1 Active Recovery' = @{ Low = 0;    High = [int]($FTP * 0.55) }
        'Z2 Endurance'       = @{ Low = [int]($FTP * 0.56); High = [int]($FTP * 0.75) }
        'Z3 Tempo'           = @{ Low = [int]($FTP * 0.76); High = [int]($FTP * 0.90) }
        'Z4 Threshold'       = @{ Low = [int]($FTP * 0.91); High = [int]($FTP * 1.05) }
        'Z5 VO2 Max'         = @{ Low = [int]($FTP * 1.06); High = [int]($FTP * 1.20) }
        'Z6 Anaerobic'       = @{ Low = [int]($FTP * 1.21); High = [int]($FTP * 1.50) }
        'Z7 Neuromuscular'   = @{ Low = [int]($FTP * 1.51); High = 9999 }
    }
}

function Get-HRZones {
    param([int]$MaxHR)
    # Classic 5-zone HR model
    return [ordered]@{
        'Z1 Recovery'   = @{ Low = 0;                            High = [int]($MaxHR * 0.60) }
        'Z2 Aerobic'    = @{ Low = [int]($MaxHR * 0.61);        High = [int]($MaxHR * 0.70) }
        'Z3 Tempo'      = @{ Low = [int]($MaxHR * 0.71);        High = [int]($MaxHR * 0.80) }
        'Z4 Threshold'  = @{ Low = [int]($MaxHR * 0.81);        High = [int]($MaxHR * 0.90) }
        'Z5 VO2 Max'    = @{ Low = [int]($MaxHR * 0.91);        High = $MaxHR }
    }
}

function Estimate-FTP {
    param($Rides)
    # Estimate FTP from best 20-min normalised power * 0.95
    # Fall back to best average_watts * 0.90 across 40-70 min rides
    $candidates = $Rides | Where-Object {
        $_.weighted_average_watts -gt 50 -and
        $_.moving_time -ge 2400 -and   # >= 40 min
        $_.moving_time -le 7200        # <= 2 hrs
    } | Sort-Object weighted_average_watts -Descending | Select-Object -First 10

    if ($candidates.Count -gt 0) {
        $bestNP = ($candidates | Measure-Object weighted_average_watts -Maximum).Maximum
        $estFTP = [int]($bestNP * 0.90)
        Write-Detail "FTP estimated from weighted avg power: $estFTP W (from $($candidates.Count) candidate rides)" -Level Info
        return $estFTP
    }

    $avgCandidates = $Rides | Where-Object { $_.average_watts -gt 50 } |
                     Sort-Object average_watts -Descending | Select-Object -First 5
    if ($avgCandidates.Count -gt 0) {
        $bestAvg = ($avgCandidates | Measure-Object average_watts -Maximum).Maximum
        $estFTP  = [int]($bestAvg * 0.85)
        Write-Detail "FTP estimated from average power (rough): $estFTP W" -Level Warning
        return $estFTP
    }

    Write-Detail "No power data found. Power-based zones disabled." -Level Warning
    return 0
}

function Estimate-MaxHR {
    param($Rides, [int]$Age)
    # Use the highest recorded HR from rides, or 220-age formula
    $dataMax = ($Rides | Where-Object { $_.max_heartrate -gt 100 } |
                Measure-Object max_heartrate -Maximum).Maximum
    if ($dataMax -gt 140) {
        Write-Detail "MaxHR from ride data: $dataMax bpm" -Level Info
        return [int]$dataMax
    }
    if ($Age -gt 0) {
        $formula = 220 - $Age
        Write-Detail "MaxHR estimated (220-age): $formula bpm" -Level Warning
        return $formula
    }
    Write-Detail "No HR data or age provided. Using default MaxHR 180 bpm." -Level Warning
    return 180
}

# ---------------------------------------------------------------------------
# Segment analysis
# ---------------------------------------------------------------------------
function Analyze-Segments {
    param($Rides)

    # Collect all segment efforts across all rides
    $allEfforts = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($ride in $Rides) {
        foreach ($effort in $ride.segment_efforts) {
            $allEfforts.Add(@{
                SegmentId         = $effort.segment.id
                SegmentName       = $effort.segment.name
                ActivityId        = $ride.id
                ActivityName      = $ride.name
                ActivityDate      = $ride.start_date_local
                ElapsedTime       = $effort.elapsed_time       # seconds
                MovingTime        = $effort.moving_time        # seconds
                Distance          = $effort.distance           # metres
                AveragePower      = if ($effort.average_watts)     { $effort.average_watts }     else { 0 }
                MaxPower          = if ($effort.max_watts)         { $effort.max_watts }          else { 0 }
                AverageHR         = if ($effort.average_heartrate) { $effort.average_heartrate }  else { 0 }
                MaxHR             = if ($effort.max_heartrate)     { $effort.max_heartrate }      else { 0 }
                ElevGain          = if ($effort.segment.elevation_high -and $effort.segment.elevation_low) {
                                        [math]::Max(0, $effort.segment.elevation_high - $effort.segment.elevation_low)
                                    } else { 0 }
                AverageGrade      = if ($effort.segment.average_grade) { $effort.segment.average_grade } else { 0 }
                ClimbCategory     = if ($effort.segment.climb_category) { $effort.segment.climb_category } else { 0 }
                PRRank            = $effort.pr_rank
                KOMRank           = $effort.kom_rank
                Starred           = $effort.segment.starred
            })
        }
    }

    Write-Detail "Total segment efforts collected: $($allEfforts.Count)" -Level Info

    # Group by segment
    $grouped = $allEfforts | Group-Object -Property { $_['SegmentId'] }

    $segments = foreach ($grp in $grouped) {
        $efforts   = $grp.Group
        $first     = $efforts[0]
        $durations = $efforts | ForEach-Object { $_['ElapsedTime'] }
        $powers    = $efforts | Where-Object { $_['AveragePower'] -gt 0 } | ForEach-Object { $_['AveragePower'] }
        $hrs       = $efforts | Where-Object { $_['AverageHR']    -gt 0 } | ForEach-Object { $_['AverageHR'] }
        $prEffort  = $efforts | Where-Object { $_['PRRank'] -eq 1 } | Select-Object -First 1

        $bestTime  = ($durations | Measure-Object -Minimum).Minimum
        $avgTime   = [int](($durations | Measure-Object -Average).Average)
        $avgPower  = if ($powers.Count -gt 0) { [int](($powers | Measure-Object -Average).Average) } else { 0 }
        $bestPower = if ($powers.Count -gt 0) { [int](($powers | Measure-Object -Maximum).Maximum) } else { 0 }
        $avgHR     = if ($hrs.Count -gt 0)    { [int](($hrs    | Measure-Object -Average).Average) } else { 0 }

        # VO2 Max suitability score: favour 3-8 min duration, high grade, high power
        $durationScore = if ($avgTime -ge 180 -and $avgTime -le 480) { 30 }
                         elseif ($avgTime -ge 120 -and $avgTime -le 600) { 15 }
                         else { 0 }
        $gradeScore    = [math]::Min(30, $first['AverageGrade'] * 3)
        $freqScore     = [math]::Min(20, $grp.Count * 2)
        $climbScore    = $first['ClimbCategory'] * 5
        $vo2Score      = [int]($durationScore + $gradeScore + $freqScore + $climbScore)

        [PSCustomObject]@{
            SegmentId        = $first['SegmentId']
            SegmentName      = $first['SegmentName']
            RideCount        = $grp.Count
            BestTimeSec      = $bestTime
            BestTimeFormatted = ('{0}:{1:D2}' -f [int]($bestTime / 60), ($bestTime % 60))
            AvgTimeSec       = $avgTime
            AvgTimeFormatted = ('{0}:{1:D2}' -f [int]($avgTime  / 60), ($avgTime  % 60))
            DistanceM        = [int]$first['Distance']
            ElevGainM        = [int]$first['ElevGain']
            AverageGrade     = $first['AverageGrade']
            ClimbCategory    = $first['ClimbCategory']
            AvgPowerW        = $avgPower
            BestPowerW       = $bestPower
            AvgHRbpm         = $avgHR
            HasPR            = ($null -ne $prEffort)
            Starred          = $first['Starred']
            VO2Score         = $vo2Score
            LastRidden       = ($efforts | Sort-Object { $_['ActivityDate'] } -Descending | Select-Object -First 1)['ActivityDate']
            Efforts          = $efforts
        }
    }

    return $segments | Sort-Object VO2Score -Descending
}

# ---------------------------------------------------------------------------
# Workout generator
# ---------------------------------------------------------------------------
function New-VO2MaxWorkout {
    param(
        $Segment,
        [int]$FTP,
        [int]$MaxHR,
        [int]$RepCount = 0   # 0 = auto
    )

    $durationMin = [math]::Round($Segment.AvgTimeSec / 60, 1)

    # Auto reps: shorter = more reps, longer = fewer reps
    if ($RepCount -eq 0) {
        $RepCount = if ($Segment.AvgTimeSec -le 240) { 6 }
                    elseif ($Segment.AvgTimeSec -le 360) { 5 }
                    else { 4 }
    }

    $recoveryMin = [math]::Round($durationMin * 1.0, 0)   # 1:1 work:rest

    $targetPowerText = if ($FTP -gt 0) {
        $lo = [int]($FTP * 1.06)
        $hi = [int]($FTP * 1.20)
        "$lo-$hi W ($([int](($lo/$FTP)*100))-$([int](($hi/$FTP)*100))% FTP)"
    } else { "Max sustainable effort / 'comfortably hard'" }

    $targetHRText = if ($MaxHR -gt 0) {
        $lo = [int]($MaxHR * 0.91)
        "≥$lo bpm ($([int](($lo/$MaxHR)*100))% MaxHR)"
    } else { "High - breathing hard but controlled" }

    $workout = [PSCustomObject]@{
        WorkoutName     = "VO2 Max - $($Segment.SegmentName)"
        TargetSegment   = $Segment.SegmentName
        SegmentId       = $Segment.SegmentId
        Reps            = $RepCount
        WorkDuration    = "$durationMin min"
        RecoveryDuration = "$recoveryMin min easy spin"
        TotalWorkTime   = "$([math]::Round($RepCount * $durationMin, 0)) min"
        TargetPower     = $targetPowerText
        TargetHR        = $targetHRText
        WarmUp          = "15-20 min Z2 easy + 3x30sec accelerations"
        CoolDown        = "10-15 min Z1 easy spin"
        StravaDesc      = @"
VO2 MAX INTERVALS - $($Segment.SegmentName)

Warm-up: 15-20 min easy Z2 + 3 x 30sec pick-ups
Main set: $RepCount x $durationMin min @ $targetPowerText | HR target: $targetHRText
Recovery: $recoveryMin min easy spin between each rep
Cool-down: 10-15 min easy

TARGET SEGMENT: $($Segment.SegmentName)
  Distance: $([math]::Round($Segment.DistanceM/1000, 2)) km
  Elevation: +$($Segment.ElevGainM) m ($($Segment.AverageGrade)% avg grade)
  Your best time: $($Segment.BestTimeFormatted)
  Your avg time:  $($Segment.AvgTimeFormatted)

KEY TIPS:
- Start conservatively on rep 1 - reps 3-4 should feel hard
- Keep cadence up on climbs (>80 rpm if possible)
- Full recovery between reps - DO NOT cut rest short
- Rate of perceived exertion: 8-9/10 by end of each rep
"@
        Notes           = "Segment ridden $($Segment.RideCount)x in period. Best: $($Segment.BestTimeFormatted), Avg: $($Segment.AvgTimeFormatted)"
    }

    return $workout
}

# ---------------------------------------------------------------------------
# HTML report
# ---------------------------------------------------------------------------
function Export-HTMLReport {
    param(
        $Rides,
        $Segments,
        $Workouts,
        [int]$FTP,
        [int]$MaxHR,
        [string]$OutputPath
    )

    $generatedDate = Get-Date -Format "dddd d MMMM yyyy, HH:mm"
    $rideCount     = $Rides.Count
    $totalDistKm   = [math]::Round(($Rides | Measure-Object { $_.distance / 1000 } -Sum).Sum, 0)
    $totalElevM    = [int](($Rides | Measure-Object total_elevation_gain -Sum).Sum)
    $totalHours    = [math]::Round(($Rides | Measure-Object moving_time -Sum).Sum / 3600, 1)
    $ftpText       = if ($FTP -gt 0) { "$FTP W" } else { "Not available" }
    $maxHRText     = if ($MaxHR -gt 0) { "$MaxHR bpm" } else { "Not available" }

    $segRowsHtml = foreach ($seg in ($Segments | Select-Object -First $TopSegments)) {
        $vo2Badge = if ($seg.VO2Score -ge 40) { '<span class="badge vo2">VO2 Target</span>' }
                    elseif ($seg.ClimbCategory -gt 0) { '<span class="badge climb">Cat ' + $seg.ClimbCategory + '</span>' }
                    else { '' }
        "<tr>
            <td>$($seg.SegmentName) $vo2Badge</td>
            <td class='num'>$($seg.RideCount)</td>
            <td class='num'>$([math]::Round($seg.DistanceM/1000,2)) km</td>
            <td class='num'>+$($seg.ElevGainM) m</td>
            <td class='num'>$($seg.AverageGrade)%</td>
            <td class='num'>$($seg.BestTimeFormatted)</td>
            <td class='num'>$($seg.AvgTimeFormatted)</td>
            <td class='num'>$(if ($seg.AvgPowerW -gt 0) { "$($seg.AvgPowerW) W" } else { '-' })</td>
            <td class='num'>$(if ($seg.AvgHRbpm -gt 0) { "$($seg.AvgHRbpm) bpm" } else { '-' })</td>
            <td class='num score-$([math]::Min(5, [int]($seg.VO2Score/20)))'>$($seg.VO2Score)</td>
        </tr>"
    }

    $workoutHtml = foreach ($wkt in $Workouts) {
        "<div class='workout-card'>
            <h3>$($wkt.WorkoutName)</h3>
            <div class='workout-meta'>
                <span>$($wkt.Reps) reps &times; $($wkt.WorkDuration)</span>
                <span>Recovery: $($wkt.RecoveryDuration)</span>
                <span>Total work: $($wkt.TotalWorkTime)</span>
            </div>
            <table class='workout-detail'>
                <tr><td>Power target</td><td>$($wkt.TargetPower)</td></tr>
                <tr><td>HR target</td><td>$($wkt.TargetHR)</td></tr>
                <tr><td>Warm-up</td><td>$($wkt.WarmUp)</td></tr>
                <tr><td>Cool-down</td><td>$($wkt.CoolDown)</td></tr>
            </table>
            <details>
                <summary>Strava workout description (copy/paste)</summary>
                <pre class='strava-desc'>$($wkt.StravaDesc)</pre>
            </details>
            <p class='notes'>$($wkt.Notes)</p>
        </div>"
    }

    # Power zones table
    $powerZoneHtml = if ($FTP -gt 0) {
        $zones = Get-PowerZones -FTP $FTP
        $rows = foreach ($z in $zones.GetEnumerator()) {
            $isVO2 = if ($z.Key -like '*VO2*') { ' class="highlight"' } else { '' }
            "<tr$isVO2><td>$($z.Key)</td><td>$($z.Value.Low)-$($z.Value.High) W</td></tr>"
        }
        "<table class='zones'>
            <thead><tr><th>Zone</th><th>Power Range</th></tr></thead>
            <tbody>$($rows -join '')</tbody>
        </table>"
    } else {
        "<p class='warning'>No power data available. Provide -FTPWatts parameter or upload rides with a power meter.</p>"
    }

    $hrZoneHtml = if ($MaxHR -gt 0) {
        $zones = Get-HRZones -MaxHR $MaxHR
        $rows = foreach ($z in $zones.GetEnumerator()) {
            $isVO2 = if ($z.Key -like '*VO2*') { ' class="highlight"' } else { '' }
            "<tr$isVO2><td>$($z.Key)</td><td>$($z.Value.Low)-$($z.Value.High) bpm</td></tr>"
        }
        "<table class='zones'>
            <thead><tr><th>Zone</th><th>HR Range</th></tr></thead>
            <tbody>$($rows -join '')</tbody>
        </table>"
    } else {
        "<p class='warning'>No HR data found.</p>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Strava Ride Analysis - VO2 Max Report</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #0d0d0d; color: #e8e8e8; line-height: 1.5; padding: 20px; }
  h1 { color: #fc4c02; font-size: 1.8rem; margin-bottom: 4px; }
  h2 { color: #fc4c02; font-size: 1.2rem; margin: 30px 0 12px; border-bottom: 1px solid #333; padding-bottom: 6px; }
  h3 { color: #ff8c55; font-size: 1rem; margin-bottom: 8px; }
  .subtitle { color: #888; font-size: 0.85rem; margin-bottom: 24px; }
  .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; margin-bottom: 24px; }
  .stat-card { background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 14px; text-align: center; }
  .stat-value { font-size: 1.6rem; font-weight: bold; color: #fc4c02; }
  .stat-label { font-size: 0.75rem; color: #888; margin-top: 2px; }
  table { width: 100%; border-collapse: collapse; font-size: 0.82rem; margin-bottom: 20px; }
  th { background: #1e1e1e; color: #fc4c02; padding: 8px 10px; text-align: left; border-bottom: 2px solid #333; }
  td { padding: 7px 10px; border-bottom: 1px solid #222; }
  .num { text-align: right; }
  tr:hover td { background: #1a1a1a; }
  .badge { font-size: 0.65rem; padding: 2px 6px; border-radius: 4px; margin-left: 6px; }
  .vo2  { background: #fc4c02; color: white; }
  .climb { background: #1e6b20; color: #7fff7f; }
  .score-5 { color: #fc4c02; font-weight: bold; }
  .score-4 { color: #ff8c55; }
  .score-3 { color: #ffcc00; }
  .highlight td { background: #1a1200 !important; }
  .zones { max-width: 400px; }
  .zones-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
  .workout-card { background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px;
                  padding: 16px; margin-bottom: 16px; }
  .workout-meta { display: flex; gap: 16px; font-size: 0.8rem; color: #aaa; margin-bottom: 10px; }
  .workout-detail { font-size: 0.82rem; max-width: 600px; }
  .workout-detail td:first-child { color: #888; width: 140px; }
  details summary { cursor: pointer; color: #fc4c02; font-size: 0.82rem; margin-top: 10px; }
  pre.strava-desc { background: #111; padding: 12px; border-radius: 4px; font-size: 0.78rem;
                    white-space: pre-wrap; margin-top: 8px; color: #bbb; border: 1px solid #333; }
  .notes { font-size: 0.75rem; color: #666; margin-top: 8px; }
  .warning { color: #ffcc00; font-size: 0.85rem; }
  .section-note { color: #888; font-size: 0.8rem; margin-bottom: 12px; }
  a { color: #fc4c02; }
</style>
</head>
<body>
<h1>&#x1F6B4; Strava Ride Analysis</h1>
<p class="subtitle">VO2 Max Training Report &mdash; Generated $generatedDate</p>

<h2>Ride Summary</h2>
<div class="stats-grid">
  <div class="stat-card"><div class="stat-value">$rideCount</div><div class="stat-label">Total Rides</div></div>
  <div class="stat-card"><div class="stat-value">$totalDistKm km</div><div class="stat-label">Total Distance</div></div>
  <div class="stat-card"><div class="stat-value">$totalElevM m</div><div class="stat-label">Total Elevation</div></div>
  <div class="stat-card"><div class="stat-value">$totalHours h</div><div class="stat-label">Moving Time</div></div>
  <div class="stat-card"><div class="stat-value">$ftpText</div><div class="stat-label">FTP</div></div>
  <div class="stat-card"><div class="stat-value">$maxHRText</div><div class="stat-label">Max HR</div></div>
</div>

<h2>Training Zones</h2>
<div class="zones-grid">
  <div><h3>Power Zones (Coggan)</h3>$powerZoneHtml</div>
  <div><h3>Heart Rate Zones</h3>$hrZoneHtml</div>
</div>

<h2>Top Segments (VO2 Score Ranked)</h2>
<p class="section-note">VO2 Score ranks segments by suitability for VO2 Max intervals (3-8 min duration, climb grade, frequency). Higher = better VO2 target.</p>
<table>
  <thead>
    <tr>
      <th>Segment</th><th>Rides</th><th>Dist</th><th>Elev</th>
      <th>Grade</th><th>Best</th><th>Avg</th><th>Avg Power</th><th>Avg HR</th><th>VO2 Score</th>
    </tr>
  </thead>
  <tbody>$($segRowsHtml -join '')</tbody>
</table>

<h2>VO2 Max Workout Plans</h2>
<p class="section-note">Structured workouts targeting your best VO2 Max segments. Aim for 1-2 sessions/week with ≥48h between hard efforts.</p>
$($workoutHtml -join '')

<h2>Training Principles</h2>
<table>
  <thead><tr><th>Principle</th><th>Guidance</th></tr></thead>
  <tbody>
    <tr><td>VO2 Max intensity</td><td>106-120% FTP (power) or 91-95% MaxHR</td></tr>
    <tr><td>Interval duration</td><td>3-8 minutes per rep (shorter = higher intensity)</td></tr>
    <tr><td>Recovery between reps</td><td>Equal to work interval (1:1 ratio) at Z1-Z2</td></tr>
    <tr><td>Sessions per week</td><td>Max 2 VO2 Max sessions; never on consecutive days</td></tr>
    <tr><td>Block structure</td><td>3 weeks build + 1 week recovery (reduce volume 40%)</td></tr>
    <tr><td>Progression</td><td>Add 1 rep per week before increasing intensity</td></tr>
    <tr><td>Signs of too much</td><td>HR won't rise, legs heavy day 2, poor sleep</td></tr>
  </tbody>
</table>

</body></html>
"@

    $html | Set-Content -Path $OutputPath -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
function Main {
    Write-Host ""
    Write-Detail ("=" * 70) -Level Info
    Write-Detail "  Analyze-StravaRides v1.0.0 - VO2 Max Training Analysis" -Level Info
    Write-Detail ("=" * 70) -Level Info
    Write-Host ""

    # Resolve data directory
    $dataDir = if ([System.IO.Path]::IsPathRooted($DataDirectory)) {
        $DataDirectory
    } else {
        Join-Path $PSScriptRoot $DataDirectory
    }

    # Load ride files
    $rides = Load-RideFiles -Dir $dataDir

    # Determine FTP
    $effectiveFTP = $FTPWatts
    if ($effectiveFTP -eq 0) {
        $effectiveFTP = Estimate-FTP -Rides $rides
    } else {
        Write-Detail "Using provided FTP: $effectiveFTP W" -Level Info
    }

    # Determine MaxHR
    $effectiveMaxHR = $MaxHR
    if ($effectiveMaxHR -eq 0) {
        $effectiveMaxHR = Estimate-MaxHR -Rides $rides -Age $AthleteAgeYears
    } else {
        Write-Detail "Using provided MaxHR: $effectiveMaxHR bpm" -Level Info
    }

    Write-Host ""

    # Display zones
    if ($effectiveFTP -gt 0) {
        Write-Detail "--- Power Zones (FTP = $effectiveFTP W) ---" -Level Success
        $pZones = Get-PowerZones -FTP $effectiveFTP
        foreach ($z in $pZones.GetEnumerator()) {
            $marker = if ($z.Key -like '*VO2*') { '  <-- TARGET' } else { '' }
            Write-Detail ("  {0,-25} {1,4}-{2,4} W{3}" -f $z.Key, $z.Value.Low, $z.Value.High, $marker) -Level Info
        }
        Write-Host ""
    }

    if ($effectiveMaxHR -gt 0) {
        Write-Detail "--- HR Zones (MaxHR = $effectiveMaxHR bpm) ---" -Level Success
        $hrZones = Get-HRZones -MaxHR $effectiveMaxHR
        foreach ($z in $hrZones.GetEnumerator()) {
            $marker = if ($z.Key -like '*VO2*') { '  <-- TARGET' } else { '' }
            Write-Detail ("  {0,-20} {1,3}-{2,3} bpm{3}" -f $z.Key, $z.Value.Low, $z.Value.High, $marker) -Level Info
        }
        Write-Host ""
    }

    # Analyze segments
    Write-Detail "Analyzing segments across all rides..." -Level Info
    $segments = Analyze-Segments -Rides $rides

    $totalUniqueSegs = $segments.Count
    $vo2Candidates   = $segments | Where-Object { $_.VO2Score -ge 40 }
    Write-Detail "Unique segments found: $totalUniqueSegs" -Level Info
    Write-Detail "VO2 Max candidate segments (score >=40): $($vo2Candidates.Count)" -Level Success
    Write-Host ""

    # Display top segments table
    Write-Detail "--- Top $TopSegments Segments by VO2 Score ---" -Level Success
    $colWidths = @(35, 6, 8, 8, 7, 8, 8, 9, 8, 6)
    $header    = '{0,-35} {1,6} {2,8} {3,8} {4,7} {5,8} {6,8} {7,9} {8,8} {9,6}' -f
                 'Segment', 'Rides', 'Dist(m)', 'Elev(m)', 'Grade%', 'BestTime', 'AvgTime', 'AvgPwr(W)', 'AvgHR', 'VO2Sc'
    Write-Host $header -ForegroundColor DarkGray
    Write-Host ('-' * 100) -ForegroundColor DarkGray

    foreach ($seg in ($segments | Select-Object -First $TopSegments)) {
        $color = if ($seg.VO2Score -ge 40) { 'Yellow' }
                 elseif ($seg.VO2Score -ge 20) { 'Gray' }
                 else { 'DarkGray' }
        $row = '{0,-35} {1,6} {2,8} {3,8} {4,7} {5,8} {6,8} {7,9} {8,8} {9,6}' -f
               ($seg.SegmentName.Substring(0, [math]::Min(34, $seg.SegmentName.Length))),
               $seg.RideCount,
               $seg.DistanceM,
               $seg.ElevGainM,
               $seg.AverageGrade,
               $seg.BestTimeFormatted,
               $seg.AvgTimeFormatted,
               (if ($seg.AvgPowerW -gt 0) { $seg.AvgPowerW } else { '-' }),
               (if ($seg.AvgHRbpm -gt 0) { $seg.AvgHRbpm } else { '-' }),
               $seg.VO2Score
        Write-Host $row -ForegroundColor $color
    }
    Write-Host ""

    if ($ReportOnly) {
        Write-Detail "Skipping workout generation (-ReportOnly specified)." -Level Info
    } else {
        # Generate workouts for top VO2 candidates
        $workoutTargets = if ($vo2Candidates.Count -gt 0) {
            $vo2Candidates | Select-Object -First 5
        } else {
            Write-Detail "No high-score VO2 segments found - generating workouts for top-3 by ride count." -Level Warning
            $segments | Sort-Object RideCount -Descending | Select-Object -First 3
        }

        Write-Detail "--- VO2 Max Workout Plans ---" -Level Success
        $workouts = foreach ($seg in $workoutTargets) {
            $wkt = New-VO2MaxWorkout -Segment $seg -FTP $effectiveFTP -MaxHR $effectiveMaxHR
            Write-Host ""
            Write-Host ("  Workout: {0}" -f $wkt.WorkoutName) -ForegroundColor Yellow
            Write-Host ("    {0} x {1} @ {2}" -f $wkt.Reps, $wkt.WorkDuration, $wkt.TargetPower) -ForegroundColor White
            Write-Host ("    Recovery: {0}" -f $wkt.RecoveryDuration) -ForegroundColor Gray
            $wkt
        }
        Write-Host ""

        # Save workouts as JSON
        $workoutsPath = Join-Path $dataDir "_workouts.json"
        $workouts | ConvertTo-Json -Depth 5 | Set-Content -Path $workoutsPath -Encoding UTF8
        Write-Detail "Workout plans saved to: $workoutsPath" -Level Success
    }

    # Export HTML report
    $reportPath = Join-Path $PSScriptRoot "StravaAnalysis-Report.html"
    Write-Detail "Generating HTML report..." -Level Info
    Export-HTMLReport `
        -Rides    $rides `
        -Segments $segments `
        -Workouts (if ($workouts) { $workouts } else { @() }) `
        -FTP      $effectiveFTP `
        -MaxHR    $effectiveMaxHR `
        -OutputPath $reportPath

    Write-Host ""
    Write-Detail ("=" * 70) -Level Info
    Write-Detail "Analysis complete!" -Level Success
    Write-Detail "  HTML Report : $reportPath" -Level Info
    if (-not $ReportOnly) {
        Write-Detail "  Workouts    : $(Join-Path $dataDir '_workouts.json')" -Level Info
    }
    Write-Detail ("=" * 70) -Level Info
    Write-Host ""

    # Open report in browser
    try { Start-Process $reportPath } catch { }
}

Main
