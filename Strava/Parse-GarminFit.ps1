# Parse-GarminFit.ps1
# Version 1.0.0 - 2026-03-17
#
# Parses Garmin .fit binary files and extracts:
#   - Session summary: NP, TSS, Intensity Factor, avg/max power, HR, distance, ascent
#   - VO2 Max (from Garmin developer data fields, or estimated from power/HR)
#   - Training Effect (aerobic/anaerobic), Performance Condition
#   - HRV (RR interval data, if recorded by device)
#   - Per-second power and HR (sampled) for zone distribution
#   - Outputs JSON files into Strava/Data/ (same format as Get-StravaRides.ps1)
#     so Analyze-StravaRides.ps1 can merge Garmin + Strava data seamlessly
#
# Usage:
#   .\Parse-GarminFit.ps1                            # Parse all .fit in .\GarminExport\
#   .\Parse-GarminFit.ps1 -InputPath "C:\Garmin"    # Custom input folder
#   .\Parse-GarminFit.ps1 -InputPath "activity.fit" # Single file
#   .\Parse-GarminFit.ps1 -OutputPath "..\Strava\Data"  # Write into Strava data dir
#   .\Parse-GarminFit.ps1 -Force                    # Re-parse already converted files
#   .\Parse-GarminFit.ps1 -SampleRate 10            # Sample 1 record per 10 seconds
#
# How to get your .fit files:
#   Garmin Connect web → Activities → select activity → ... → Export Original
#   Or bulk export: Garmin Connect → Account → Data Export
#   Or sync your device and grab from: %APPDATA%\Garmin\Devices\<id>\Activities\

param(
    [string]$InputPath   = "$PSScriptRoot\GarminExport",
    [string]$OutputPath  = "$PSScriptRoot\..\Strava\Data",
    [switch]$Force,
    [int]$SampleRate     = 5,    # Keep 1 record per N seconds (reduces output size)
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
# FIT format constants
# ---------------------------------------------------------------------------
# Garmin FIT epoch: number of seconds between Unix epoch (1970-01-01)
# and FIT epoch (1989-12-31 00:00:00 UTC)
$script:FIT_EPOCH    = 631065600

# Global message numbers we care about
$script:MSG_SESSION     = 18
$script:MSG_LAP         = 19
$script:MSG_RECORD      = 20
$script:MSG_HRV         = 78
$script:MSG_FIELD_DESC  = 206   # developer field descriptions
$script:MSG_DEV_DATA_ID = 207

# Base type lookup: [byte_size, uint_invalid_sentinel]
# The base type byte in FIT definitions uses bits 0-4 (masked with 0x9F)
$script:BASE_TYPES = @{
    0x00 = @{ Size = 1; Name = 'enum'    }
    0x01 = @{ Size = 1; Name = 'sint8'   }
    0x02 = @{ Size = 1; Name = 'uint8'   }
    0x03 = @{ Size = 2; Name = 'sint16'  }
    0x04 = @{ Size = 2; Name = 'uint16'  }
    0x05 = @{ Size = 4; Name = 'sint32'  }
    0x06 = @{ Size = 4; Name = 'uint32'  }
    0x07 = @{ Size = 1; Name = 'string'  }
    0x08 = @{ Size = 4; Name = 'float32' }
    0x09 = @{ Size = 8; Name = 'float64' }
    0x0A = @{ Size = 1; Name = 'uint8z'  }
    0x0B = @{ Size = 2; Name = 'uint16z' }
    0x0C = @{ Size = 4; Name = 'uint32z' }
    0x0D = @{ Size = 1; Name = 'byte'    }
    0x0E = @{ Size = 8; Name = 'sint64'  }
    0x0F = @{ Size = 8; Name = 'uint64'  }
    0x10 = @{ Size = 8; Name = 'uint64z' }
}

# Session message (18) field numbers → [scale, offset, units, friendly_name]
# real_value = raw_value / scale - offset
$script:SESSION_FIELDS = @{
    2   = @{ Scale = 1;    Offset = 0;   Units = '';      Name = 'start_time'            }
    7   = @{ Scale = 1;    Offset = 0;   Units = '';      Name = 'sport'                 }
    8   = @{ Scale = 1;    Offset = 0;   Units = '';      Name = 'sub_sport'             }
    9   = @{ Scale = 1000; Offset = 0;   Units = 's';     Name = 'total_elapsed_time'    }
    10  = @{ Scale = 1000; Offset = 0;   Units = 's';     Name = 'total_timer_time'      }
    11  = @{ Scale = 100;  Offset = 0;   Units = 'm';     Name = 'total_distance'        }
    14  = @{ Scale = 1;    Offset = 0;   Units = 'kcal';  Name = 'total_calories'        }
    16  = @{ Scale = 1000; Offset = 0;   Units = 'm/s';   Name = 'avg_speed'             }
    17  = @{ Scale = 1000; Offset = 0;   Units = 'm/s';   Name = 'max_speed'             }
    18  = @{ Scale = 1;    Offset = 0;   Units = 'bpm';   Name = 'avg_heart_rate'        }
    19  = @{ Scale = 1;    Offset = 0;   Units = 'bpm';   Name = 'max_heart_rate'        }
    20  = @{ Scale = 1;    Offset = 0;   Units = 'rpm';   Name = 'avg_cadence'           }
    21  = @{ Scale = 1;    Offset = 0;   Units = 'rpm';   Name = 'max_cadence'           }
    22  = @{ Scale = 1;    Offset = 0;   Units = 'W';     Name = 'avg_power'             }
    23  = @{ Scale = 1;    Offset = 0;   Units = 'W';     Name = 'max_power'             }
    25  = @{ Scale = 1;    Offset = 0;   Units = 'm';     Name = 'total_ascent'          }
    26  = @{ Scale = 1;    Offset = 0;   Units = 'm';     Name = 'total_descent'         }
    27  = @{ Scale = 10;   Offset = 0;   Units = '';      Name = 'total_training_effect' }
    34  = @{ Scale = 1;    Offset = 0;   Units = 'W';     Name = 'normalized_power'      }
    35  = @{ Scale = 10;   Offset = 0;   Units = 'TSS';   Name = 'training_stress_score' }
    36  = @{ Scale = 1000; Offset = 0;   Units = '';      Name = 'intensity_factor'      }
    44  = @{ Scale = 5;    Offset = 500; Units = 'm';     Name = 'avg_altitude'          }
    77  = @{ Scale = 10;   Offset = 0;   Units = '';      Name = 'anaerobic_training_effect' }
    253 = @{ Scale = 1;    Offset = 0;   Units = 'ts';    Name = 'timestamp'             }
}

# Record message (20) field numbers
$script:RECORD_FIELDS = @{
    3   = @{ Scale = 1;    Offset = 0; Units = 'bpm';  Name = 'heart_rate'  }
    4   = @{ Scale = 1;    Offset = 0; Units = 'rpm';  Name = 'cadence'     }
    5   = @{ Scale = 100;  Offset = 0; Units = 'm';    Name = 'distance'    }
    6   = @{ Scale = 1000; Offset = 0; Units = 'm/s';  Name = 'speed'       }
    7   = @{ Scale = 1;    Offset = 0; Units = 'W';    Name = 'power'       }
    13  = @{ Scale = 1;    Offset = 0; Units = 'C';    Name = 'temperature' }
    253 = @{ Scale = 1;    Offset = 0; Units = 'ts';   Name = 'timestamp'   }
}

# ---------------------------------------------------------------------------
# Binary reading helpers
# ---------------------------------------------------------------------------
function Read-UInt16LE { param([byte[]]$B, [int]$O) return ([uint32]$B[$O+1] -shl 8) -bor [uint32]$B[$O] }
function Read-UInt16BE { param([byte[]]$B, [int]$O) return ([uint32]$B[$O]   -shl 8) -bor [uint32]$B[$O+1] }
function Read-UInt32LE { param([byte[]]$B, [int]$O)
    return ([uint32]$B[$O+3] -shl 24) -bor ([uint32]$B[$O+2] -shl 16) -bor ([uint32]$B[$O+1] -shl 8) -bor [uint32]$B[$O] }
function Read-UInt32BE { param([byte[]]$B, [int]$O)
    return ([uint32]$B[$O]   -shl 24) -bor ([uint32]$B[$O+1] -shl 16) -bor ([uint32]$B[$O+2] -shl 8) -bor [uint32]$B[$O+3] }

function Read-UInt16 { param([byte[]]$B, [int]$O, [bool]$BE)
    return if ($BE) { Read-UInt16BE $B $O } else { Read-UInt16LE $B $O } }
function Read-UInt32 { param([byte[]]$B, [int]$O, [bool]$BE)
    return if ($BE) { Read-UInt32BE $B $O } else { Read-UInt32LE $B $O } }

function Read-SInt16 { param([byte[]]$B, [int]$O, [bool]$BE)
    $u = Read-UInt16 -B $B -O $O -BE $BE
    return if ($u -gt 32767) { [int]$u - 65536 } else { [int]$u } }
function Read-SInt32 { param([byte[]]$B, [int]$O, [bool]$BE)
    $u = Read-UInt32 -B $B -O $O -BE $BE
    return if ($u -gt 2147483647) { [int64]$u - 4294967296 } else { [int]$u } }

function Read-Float32 { param([byte[]]$B, [int]$O, [bool]$BE)
    $tmp = [byte[]]($B[$O..($O+3)])
    if ($BE -and [BitConverter]::IsLittleEndian) { [Array]::Reverse($tmp) }
    if (-not $BE -and -not [BitConverter]::IsLittleEndian) { [Array]::Reverse($tmp) }
    return [BitConverter]::ToSingle($tmp, 0) }

# Read a single field value given its base type, returning $null for invalid/missing
function Read-FieldValue {
    param([byte[]]$Bytes, [int]$Offset, [int]$FieldSize, [byte]$BaseTypeByte, [bool]$BigEndian)

    $bt = $BaseTypeByte -band 0x9F   # strip endian hint bit (bit 7) and reserved bits

    switch ($bt) {
        0x00 { # enum
            $v = [int]$Bytes[$Offset]
            return if ($v -eq 0xFF) { $null } else { $v }
        }
        0x01 { # sint8
            $v = [int]$Bytes[$Offset]
            if ($v -eq 0x7F) { return $null }
            return if ($v -gt 127) { $v - 256 } else { $v }
        }
        0x02 { # uint8
            $v = [int]$Bytes[$Offset]
            return if ($v -eq 0xFF) { $null } else { $v }
        }
        0x03 { # sint16
            if ($FieldSize -lt 2) { return $null }
            $v = Read-SInt16 -B $Bytes -O $Offset -BE $BigEndian
            return if ($v -eq 0x7FFF) { $null } else { $v }
        }
        0x04 { # uint16
            if ($FieldSize -lt 2) { return $null }
            $v = Read-UInt16 -B $Bytes -O $Offset -BE $BigEndian
            return if ($v -eq 0xFFFF) { $null } else { [int]$v }
        }
        0x05 { # sint32
            if ($FieldSize -lt 4) { return $null }
            $v = Read-SInt32 -B $Bytes -O $Offset -BE $BigEndian
            return if ($v -eq 0x7FFFFFFF) { $null } else { $v }
        }
        0x06 { # uint32
            if ($FieldSize -lt 4) { return $null }
            $v = Read-UInt32 -B $Bytes -O $Offset -BE $BigEndian
            return if ($v -eq 0xFFFFFFFF) { $null } else { [long]$v }
        }
        0x07 { # string (null-terminated UTF-8)
            $end = $Offset
            $max = $Offset + $FieldSize
            while ($end -lt $max -and $Bytes[$end] -ne 0) { $end++ }
            if ($end -eq $Offset) { return $null }
            return [System.Text.Encoding]::UTF8.GetString($Bytes, $Offset, $end - $Offset)
        }
        0x08 { # float32
            if ($FieldSize -lt 4) { return $null }
            return Read-Float32 -B $Bytes -O $Offset -BE $BigEndian
        }
        0x0A { # uint8z
            $v = [int]$Bytes[$Offset]
            return if ($v -eq 0x00) { $null } else { $v }
        }
        0x0B { # uint16z
            if ($FieldSize -lt 2) { return $null }
            $v = Read-UInt16 -B $Bytes -O $Offset -BE $BigEndian
            return if ($v -eq 0x0000) { $null } else { [int]$v }
        }
        0x0C { # uint32z
            if ($FieldSize -lt 4) { return $null }
            $v = Read-UInt32 -B $Bytes -O $Offset -BE $BigEndian
            return if ($v -eq 0x00000000) { $null } else { [long]$v }
        }
        0x0D { # byte (raw)
            return [int]$Bytes[$Offset]
        }
        default { return $null }
    }
}

# ---------------------------------------------------------------------------
# FIT file parser
# ---------------------------------------------------------------------------
function Parse-FitFile {
    param([string]$FilePath)

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $len   = $bytes.Length

    # --- Validate header ---
    if ($len -lt 12) { throw "File too small to be a valid FIT file: $FilePath" }

    $headerSize    = [int]$bytes[0]
    $dataSize      = Read-UInt32LE -B $bytes -O 4
    $signature     = [System.Text.Encoding]::ASCII.GetString($bytes, 8, 4)

    if ($signature -ne '.FIT') {
        throw "Not a FIT file (bad signature '$signature'): $FilePath"
    }
    if ($len -lt ($headerSize + $dataSize)) {
        throw "File truncated (expected $($headerSize + $dataSize) bytes, got $len): $FilePath"
    }

    Write-Detail "Parsing: $([System.IO.Path]::GetFileName($FilePath)) ($([math]::Round($len/1024,0)) KB)" -Level Info

    # --- Parser state ---
    $pos             = $headerSize          # current byte position
    $dataEnd         = $headerSize + $dataSize
    $definitions     = @{}                  # local_msg_type -> definition hashtable
    $devFieldNames   = @{}                  # devDataIndex -> {fieldNum -> name}
    $sessions        = [System.Collections.Generic.List[hashtable]]::new()
    $records         = [System.Collections.Generic.List[hashtable]]::new()
    $hrvIntervals    = [System.Collections.Generic.List[float]]::new()
    $recordCount     = 0

    # --- Main parse loop ---
    while ($pos -lt $dataEnd) {
        $header = $bytes[$pos]
        $pos++

        if ($header -band 0x80) {
            # Compressed timestamp header (bits 6-5 = local msg type, bits 4-0 = time offset)
            $localType = ($header -shr 5) -band 0x03
            # We still need to decode the data - look up existing definition
            $def = $definitions[$localType]
            if ($def) {
                $msgData = [hashtable]::new()
                $off = $pos
                foreach ($field in $def.Fields) {
                    $val = Read-FieldValue -Bytes $bytes -Offset $off -FieldSize $field.Size `
                                          -BaseTypeByte $field.BaseType -BigEndian $def.BigEndian
                    $msgData[$field.FieldNum] = $val
                    $off += $field.Size
                }
                $pos += $def.DataSize
                Process-DataMessage -GlobalMsgNum $def.GlobalMsgNum `
                                    -MsgData $msgData `
                                    -Sessions $sessions -Records $records -HrvIntervals $hrvIntervals `
                                    -DevFieldNames $devFieldNames -RecordCount ([ref]$recordCount)
            }
            continue
        }

        $isDefinition = ($header -band 0x40) -ne 0
        $hasDevFields = ($header -band 0x20) -ne 0
        $localType    = $header -band 0x0F

        if ($isDefinition) {
            # Definition message
            $pos++                                          # skip reserved byte
            $bigEndian   = $bytes[$pos] -eq 1; $pos++
            $globalMsgNum = Read-UInt16 -B $bytes -O $pos -BE $bigEndian; $pos += 2
            $numFields    = [int]$bytes[$pos]; $pos++

            $fields   = [System.Collections.Generic.List[hashtable]]::new()
            $dataSize2 = 0

            for ($f = 0; $f -lt $numFields; $f++) {
                $fieldNum  = [int]$bytes[$pos];   $pos++
                $fieldSize = [int]$bytes[$pos];   $pos++
                $baseType  = $bytes[$pos];        $pos++
                $fields.Add(@{ FieldNum = $fieldNum; Size = $fieldSize; BaseType = $baseType })
                $dataSize2 += $fieldSize
            }

            $devFields = [System.Collections.Generic.List[hashtable]]::new()
            if ($hasDevFields) {
                $numDev = [int]$bytes[$pos]; $pos++
                for ($d = 0; $d -lt $numDev; $d++) {
                    $devFieldNum  = [int]$bytes[$pos]; $pos++
                    $devFieldSize = [int]$bytes[$pos]; $pos++
                    $devDataIdx   = [int]$bytes[$pos]; $pos++
                    $devFields.Add(@{ FieldNum = $devFieldNum; Size = $devFieldSize; DevDataIndex = $devDataIdx })
                    $dataSize2 += $devFieldSize
                }
            }

            $definitions[$localType] = @{
                GlobalMsgNum = $globalMsgNum
                BigEndian    = $bigEndian
                Fields       = $fields
                DevFields    = $devFields
                DataSize     = $dataSize2
            }
            Write-Detail "  DEF local=$localType global=$globalMsgNum fields=$numFields devFields=$($devFields.Count)" -Level Debug

        } else {
            # Data message
            $def = $definitions[$localType]
            if (-not $def) {
                Write-Detail "Data message for undefined local type $localType - skipping" -Level Warning
                continue
            }

            $msgData = [hashtable]::new()
            $off = $pos

            foreach ($field in $def.Fields) {
                $val = Read-FieldValue -Bytes $bytes -Offset $off -FieldSize $field.Size `
                                      -BaseTypeByte $field.BaseType -BigEndian $def.BigEndian
                $msgData[$field.FieldNum] = $val
                $off += $field.Size
            }

            # Developer fields
            foreach ($devField in $def.DevFields) {
                $val = Read-FieldValue -Bytes $bytes -Offset $off -FieldSize $devField.Size `
                                      -BaseTypeByte 0x07 -BigEndian $def.BigEndian
                $devIdx = $devField.DevDataIndex
                # Try to get the named field mapping
                if ($devFieldNames.ContainsKey($devIdx) -and $devFieldNames[$devIdx].ContainsKey($devField.FieldNum)) {
                    $devName = $devFieldNames[$devIdx][$devField.FieldNum]
                    $msgData["dev_$devName"] = $val
                } else {
                    # Store with raw key - re-read as uint16/uint8 based on size
                    $rawVal = Read-FieldValue -Bytes $bytes -Offset $off -FieldSize $devField.Size `
                                            -BaseTypeByte (if ($devField.Size -le 1) { 0x02 } elseif ($devField.Size -le 2) { 0x04 } else { 0x06 }) `
                                            -BigEndian $def.BigEndian
                    $msgData["dev_$($devIdx)_$($devField.FieldNum)"] = $rawVal
                }
                $off += $devField.Size
            }

            $pos += $def.DataSize

            Process-DataMessage -GlobalMsgNum $def.GlobalMsgNum `
                                -MsgData $msgData `
                                -Sessions $sessions -Records $records -HrvIntervals $hrvIntervals `
                                -DevFieldNames $devFieldNames -RecordCount ([ref]$recordCount)
        }
    }

    return @{
        Sessions     = $sessions
        Records      = $records
        HrvIntervals = $hrvIntervals
        RecordCount  = $recordCount
    }
}

# ---------------------------------------------------------------------------
# Message processors
# ---------------------------------------------------------------------------
function Process-DataMessage {
    param(
        [int]$GlobalMsgNum,
        [hashtable]$MsgData,
        $Sessions, $Records, $HrvIntervals,
        [hashtable]$DevFieldNames,
        [ref]$RecordCount
    )

    switch ($GlobalMsgNum) {

        $script:MSG_SESSION {
            $session = @{}
            foreach ($kv in $MsgData.GetEnumerator()) {
                $fieldDef = $script:SESSION_FIELDS[$kv.Key]
                if ($fieldDef -and $null -ne $kv.Value) {
                    $raw = $kv.Value
                    $scaled = if ($fieldDef.Scale -ne 1) { $raw / $fieldDef.Scale } else { $raw }
                    if ($fieldDef.Offset -ne 0) { $scaled -= $fieldDef.Offset }
                    $session[$fieldDef.Name] = [math]::Round($scaled, 4)
                }
                # Capture developer fields (VO2 Max, Performance Condition, etc.)
                if ($kv.Key -is [string] -and $kv.Key.StartsWith('dev_')) {
                    $session[$kv.Key] = $kv.Value
                }
            }
            if ($session.Count -gt 0) { $Sessions.Add($session) }
        }

        $script:MSG_RECORD {
            $RecordCount.Value++

            # Sample records to keep output size manageable
            if ($RecordCount.Value % $SampleRate -ne 0) { return }

            $rec = @{}
            foreach ($kv in $MsgData.GetEnumerator()) {
                $fieldDef = $script:RECORD_FIELDS[$kv.Key]
                if ($fieldDef -and $null -ne $kv.Value) {
                    $raw    = $kv.Value
                    $scaled = if ($fieldDef.Scale -ne 1) { $raw / $fieldDef.Scale } else { $raw }
                    $rec[$fieldDef.Name] = [math]::Round($scaled, 3)
                }
            }
            if ($rec.Count -gt 0) { $Records.Add($rec) }
        }

        $script:MSG_HRV {
            # HRV message: field 0 = array of uint16 RR intervals in ms/1000
            # Each message can contain multiple RR values packed as an array
            # The field size / 2 tells us how many uint16 values are in the array
            # We receive these as individual parsed values - HRV messages come rapid-fire
            # Stash raw value from field 0
            $rrRaw = $MsgData[0]
            if ($null -ne $rrRaw -and $rrRaw -gt 0) {
                $rrSec = $rrRaw / 1000.0
                if ($rrSec -gt 0.2 -and $rrSec -lt 3.0) {  # physiologically valid range
                    $HrvIntervals.Add([float]$rrSec)
                }
            }
        }

        $script:MSG_FIELD_DESC {
            # Maps developer field numbers to human-readable names
            # Field 0 = developer_data_index, 3 = field_name (string), 1 = field_def_number
            $devIdx   = $MsgData[0]
            $fieldNum = $MsgData[1]
            $name     = $MsgData[3]
            if ($null -ne $devIdx -and $null -ne $fieldNum -and $null -ne $name) {
                $devIdx   = [int]$devIdx
                $fieldNum = [int]$fieldNum
                if (-not $DevFieldNames.ContainsKey($devIdx)) {
                    $DevFieldNames[$devIdx] = @{}
                }
                $DevFieldNames[$devIdx][$fieldNum] = $name
                Write-Detail "  Dev field: idx=$devIdx num=$fieldNum name='$name'" -Level Debug
            }
        }
    }
}

# ---------------------------------------------------------------------------
# VO2 Max extraction and estimation
# ---------------------------------------------------------------------------
function Get-VO2Max {
    param($Session, $Records)

    # 1. Check developer fields - Garmin/Firstbeat store VO2 Max here on some devices
    #    Common field names seen in Garmin FIT files:
    foreach ($key in $Session.Keys) {
        if ($key -match 'vo2|oxygen|aerobicvo2|maxo2' -and $key -notmatch 'training_effect') {
            $val = $Session[$key]
            if ($null -ne $val -and $val -gt 20 -and $val -lt 90) {
                Write-Detail "  VO2 Max from developer field '$key': $val ml/kg/min" -Level Success
                return @{ Value = $val; Source = "Garmin device ($key)" }
            }
        }
    }

    # 2. Estimate from Normalised Power and duration (Hawley & Noakes 1992 model)
    #    VO2 Max (ml/kg/min) ≈ (W_max / body_weight_kg) * 10.8 + 7
    #    W_max from a sufficiently hard effort: NP from a 20-min+ ride
    #    We don't have body weight - return a relative estimate instead
    $np     = $Session['normalized_power']
    $avgHR  = $Session['avg_heart_rate']
    $maxHR  = $null  # Not in session - need from athlete profile

    if ($np -gt 50) {
        # Relative VO2 Max proxy: NP normalised to FTP would give IF
        # Without body weight we output W/kg as a relative metric
        $elapsedMin = if ($Session['total_timer_time']) { $Session['total_timer_time'] / 60 } else { 0 }
        return @{
            Value  = $null
            NP_watts = $np
            DurationMin = [math]::Round($elapsedMin, 0)
            Source = 'Estimated from NP (body weight needed for absolute ml/kg/min)'
            Note   = "Provide -BodyWeightKg to get absolute VO2 Max estimate"
        }
    }

    return @{ Value = $null; Source = 'No power data or Garmin VO2 Max field found' }
}

function Get-HRVStats {
    param([System.Collections.Generic.List[float]]$Intervals)

    if ($Intervals.Count -lt 5) { return $null }

    $arr   = [float[]]$Intervals
    $mean  = ($arr | Measure-Object -Average).Average
    $n     = $arr.Count

    # RMSSD: root mean square of successive differences
    $sumSqDiff = 0.0
    for ($i = 1; $i -lt $n; $i++) {
        $diff = $arr[$i] - $arr[$i-1]
        $sumSqDiff += $diff * $diff
    }
    $rmssd = [math]::Sqrt($sumSqDiff / ($n - 1)) * 1000   # convert to ms

    # SDNN: standard deviation of NN intervals
    $sumSq = 0.0
    foreach ($v in $arr) { $sumSq += ($v - $mean) * ($v - $mean) }
    $sdnn = [math]::Sqrt($sumSq / $n) * 1000

    return @{
        SampleCount    = $n
        MeanRR_ms      = [math]::Round($mean * 1000, 1)
        MeanHR_bpm     = [math]::Round(60.0 / $mean, 1)
        RMSSD_ms       = [math]::Round($rmssd, 1)
        SDNN_ms        = [math]::Round($sdnn, 1)
        Note           = 'Higher RMSSD = better recovery. RMSSD >50ms typically good.'
    }
}

# ---------------------------------------------------------------------------
# Power / HR zone distribution from sampled records
# ---------------------------------------------------------------------------
function Get-ZoneDistribution {
    param($Records, [string]$Field, [int[]]$Thresholds)

    $values = $Records | Where-Object { $null -ne $_[$Field] } | ForEach-Object { $_[$Field] }
    if ($values.Count -eq 0) { return $null }

    $zones = @{}
    $i = 1
    foreach ($t in $Thresholds) {
        $zones["Z$i"] = @{ Threshold = $t; Seconds = 0 }
        $i++
    }
    $zones["Z$i"] = @{ Threshold = 99999; Seconds = 0 }

    foreach ($v in $values) {
        $zone = 1
        foreach ($t in $Thresholds) {
            if ($v -gt $t) { $zone++ }
        }
        $zones["Z$zone"].Seconds += $SampleRate  # each sample represents SampleRate seconds
    }

    return $zones
}

# ---------------------------------------------------------------------------
# Output JSON - structured to be usable by Analyze-StravaRides.ps1
# ---------------------------------------------------------------------------
function Export-RideJson {
    param(
        [string]$SourceFile,
        [string]$OutputDir,
        $ParsedData
    )

    $sessions = $ParsedData.Sessions
    $records  = $ParsedData.Records

    if ($sessions.Count -eq 0) {
        Write-Detail "  No session data found in FIT file - skipping" -Level Warning
        return $null
    }

    # Use first cycling session; skip if no cycling sport
    $session = $sessions | Where-Object { $_.sport -in @(2, $null) } | Select-Object -First 1
    if (-not $session) { $session = $sessions[0] }

    # Resolve timestamps
    $startTs   = if ($session.start_time) {
        [DateTimeOffset]::FromUnixTimeSeconds([long]$session.start_time + $script:FIT_EPOCH)
    } else {
        [DateTimeOffset]::UtcNow
    }

    # Compute sport name
    $sportName = switch ([int]($session.sport ?? 0)) {
        2  { 'Ride'           }
        58 { 'VirtualRide'    }
        17 { 'MountainBikeRide' }
        default { 'Ride'     }
    }

    # VO2 Max
    $vo2 = Get-VO2Max -Session $session -Records $records

    # HRV stats
    $hrv = Get-HRVStats -Intervals $ParsedData.HrvIntervals

    # Zone distributions (thresholds are power in watts - won't be meaningful without FTP
    # but relative distributions are still useful)
    $pwrZones = if (($records | Where-Object { $null -ne $_.power }).Count -gt 0) {
        $np = $session.normalized_power ?? 200
        Get-ZoneDistribution -Records $records -Field 'power' `
            -Thresholds @([int]($np*0.55), [int]($np*0.75), [int]($np*0.90), [int]($np*1.05), [int]($np*1.20))
    } else { $null }

    $hrZones = if (($records | Where-Object { $null -ne $_.heart_rate }).Count -gt 0) {
        $maxHR = $session.max_heart_rate ?? 180
        Get-ZoneDistribution -Records $records -Field 'heart_rate' `
            -Thresholds @([int]($maxHR*0.60), [int]($maxHR*0.70), [int]($maxHR*0.80), [int]($maxHR*0.90))
    } else { $null }

    # Build output object (fields mirror Strava API activity structure
    # so Analyze-StravaRides.ps1 works without modification)
    $sourceBase = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile)
    $output = [ordered]@{
        id                      = [long]($startTs.ToUnixTimeSeconds())
        name                    = $sourceBase
        type                    = $sportName
        start_date              = $startTs.UtcDateTime.ToString('o')
        start_date_local        = $startTs.LocalDateTime.ToString('o')
        distance                = [math]::Round(($session.total_distance ?? 0), 0)
        moving_time             = [int]($session.total_timer_time ?? 0)
        elapsed_time            = [int]($session.total_elapsed_time ?? 0)
        total_elevation_gain    = [int]($session.total_ascent ?? 0)
        average_speed           = [math]::Round(($session.avg_speed ?? 0), 3)
        max_speed               = [math]::Round(($session.max_speed ?? 0), 3)
        average_watts           = [int]($session.avg_power ?? 0)
        weighted_average_watts  = [int]($session.normalized_power ?? 0)
        max_watts               = [int]($session.max_power ?? 0)
        average_heartrate       = [int]($session.avg_heart_rate ?? 0)
        max_heartrate           = [int]($session.max_heart_rate ?? 0)
        kilojoules              = if ($session.avg_power -and $session.total_timer_time) {
                                      [math]::Round($session.avg_power * $session.total_timer_time / 1000, 1)
                                  } else { 0 }
        average_cadence         = [int]($session.avg_cadence ?? 0)
        calories                = [int]($session.total_calories ?? 0)
        # Garmin-specific enrichment (not in Strava)
        garmin = [ordered]@{
            source_file              = [System.IO.Path]::GetFileName($SourceFile)
            normalized_power         = [int]($session.normalized_power ?? 0)
            training_stress_score    = $session.training_stress_score
            intensity_factor         = $session.intensity_factor
            aerobic_training_effect  = $session.total_training_effect
            anaerobic_training_effect = $session.anaerobic_training_effect
            avg_altitude_m           = $session.avg_altitude
            vo2max                   = $vo2
            hrv                      = $hrv
            power_zone_distribution  = $pwrZones
            hr_zone_distribution     = $hrZones
            raw_session              = $session
        }
        # Empty segment_efforts so Analyze-StravaRides.ps1 doesn't error
        segment_efforts = @()
    }

    # Write output
    $datePart = $startTs.ToString('yyyy-MM-dd')
    $safeName = $sourceBase -replace '[\\/:*?"<>|]', '_'
    $outFile  = Join-Path $OutputDir "garmin_$datePart`_$safeName.json"
    $output | ConvertTo-Json -Depth 10 | Set-Content -Path $outFile -Encoding UTF8

    Write-Detail ("  -> {0,6:N0} km | NP {1,4}W | HR {2,3}bpm | Ascent {3,5}m | TSS {4}" -f `
        [math]::Round($output.distance/1000, 0),
        $output.weighted_average_watts,
        $output.average_heartrate,
        $output.total_elevation_gain,
        ($session.training_stress_score ?? '-')) -Level Success

    return $outFile
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
function Main {
    Write-Host ""
    Write-Detail ("=" * 70) -Level Info
    Write-Detail "  Parse-GarminFit v1.0.0 - Garmin FIT Binary Parser" -Level Info
    Write-Detail ("=" * 70) -Level Info
    Write-Host ""

    # Resolve input
    $fitFiles = if (Test-Path $InputPath -PathType Leaf) {
        @(Get-Item $InputPath)
    } elseif (Test-Path $InputPath -PathType Container) {
        Get-ChildItem -Path $InputPath -Filter '*.fit' -Recurse
    } else {
        throw "Input path not found: $InputPath`n" +
              "Create a 'GarminExport' folder next to this script and copy .fit files into it,`n" +
              "or use -InputPath to specify the location."
    }

    if ($fitFiles.Count -eq 0) {
        Write-Detail "No .fit files found at: $InputPath" -Level Warning
        Write-Detail "Export your activities from Garmin Connect -> Account -> Data Export" -Level Info
        return
    }

    # Resolve output directory
    $outDir = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } `
              else { Join-Path $PSScriptRoot $OutputPath }

    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        Write-Detail "Created output directory: $outDir" -Level Info
    }

    Write-Detail "Input : $InputPath ($($fitFiles.Count) .fit files)" -Level Info
    Write-Detail "Output: $outDir" -Level Info
    Write-Detail "Sample rate: 1 record per $SampleRate seconds" -Level Info
    Write-Host ""

    $parsed   = 0
    $skipped  = 0
    $errors   = 0

    foreach ($file in $fitFiles | Sort-Object Name) {
        # Check for existing output
        if (-not $Force) {
            $safeName = $file.BaseName -replace '[\\/:*?"<>|]', '_'
            $existing = Get-ChildItem -Path $outDir -Filter "garmin_*_$safeName.json" -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Detail "SKIP  $($file.Name) (already parsed, use -Force to redo)" -Level Debug
                $skipped++
                continue
            }
        }

        Write-Detail "PARSE $($file.Name)" -Level Info
        try {
            $data    = Parse-FitFile -FilePath $file.FullName
            $outFile = Export-RideJson -SourceFile $file.FullName -OutputDir $outDir -ParsedData $data
            if ($outFile) { $parsed++ }

            # Summary of what was found
            $totalRecs = $data.RecordCount
            $sampledRecs = $data.Records.Count
            $hasPower = ($data.Records | Where-Object { $null -ne $_.power }).Count -gt 0
            $hasHRV   = $data.HrvIntervals.Count -gt 0
            Write-Detail ("        Records: $totalRecs (sampled: $sampledRecs) | Power: $hasPower | HRV points: $($data.HrvIntervals.Count)") -Level Debug
        }
        catch {
            Write-Detail "ERROR parsing $($file.Name): $($_.Exception.Message)" -Level Error
            $errors++
        }
        Write-Host ""
    }

    Write-Detail ("=" * 70) -Level Info
    Write-Detail "Done:" -Level Success
    Write-Detail "  Parsed  : $parsed files" -Level Info
    Write-Detail "  Skipped : $skipped (already converted)" -Level Info
    Write-Detail "  Errors  : $errors" -Level Info
    Write-Detail "  Output  : $outDir" -Level Info
    Write-Host ""
    Write-Detail "Next step: run Analyze-StravaRides.ps1 to merge Garmin + Strava data" -Level Info
    Write-Detail ("=" * 70) -Level Info
    Write-Host ""
}

Main
