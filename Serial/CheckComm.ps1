
<#
&'D:\oneDrive\OneDrive - Fulton Hogan Limited\gSync\_scripts\Powershell\Dev\Serial\CheckComm.ps1' -comport COM5


https://en.wikipedia.org/wiki/NMEA_0183


 #>


[CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true,HelpMessage="Serial Port.  [COM1/COM2/COM3/COM4/COM5]")]
        [STRING]
        [ValidateNotNullOrEmpty()]
        $comport = "COM3",
        [Parameter(Mandatory = $false, ValueFromPipeline = $true,HelpMessage="Serial BAUD rate.")]
        [INT]
        [ValidateNotNullOrEmpty()]
        $baudrate = 4800,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true,HelpMessage="Serail Port Databits.")]
        [INT]
        [ValidateNotNullOrEmpty()]
        $DataBits = 8,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true,HelpMessage="CSV Log file path.")]
        [STRING]
        $LogFile = ""

    )

#region Helper Functions
##########################################################################################
#                                   Helper Functions
##########################################################################################
Function Write-Detail {
<#
    .SYNOPSIS&


	Writes to host formatted
    .DESCRIPTION
	"Write-Detail"
    .PARAMETER message

    .INPUTS
        [String]

    .OUTPUTS
        [Standard Out]
    .EXAMPLE
	    Write-Detail -message "This is my message for the log file."
    .LINK
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true,HelpMessage="Please Enter string to display.")]
        [string]
        [ValidateNotNullOrEmpty()]
        $message
    )
    Write-Host "$(Get-Date -Format s)`t$($MyInvocation.ScriptLineNumber) `t- $message"
}          # End of Write-Detail


Function Convert-NMEACoordinate {
<#
    .SYNOPSIS
    Converts NMEA coordinate format to decimal degrees
    .PARAMETER Coordinate
    NMEA coordinate (e.g., "4807.038" for latitude or "01131.000" for longitude)
    .PARAMETER Direction
    Direction (N, S, E, W)
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Coordinate,
        [Parameter(Mandatory = $true)]
        [string]$Direction
    )

    if ([string]::IsNullOrEmpty($Coordinate)) { return "" }

    try {
        # Latitude format: DDMM.MMMM, Longitude format: DDDMM.MMMM
        if ($Coordinate.Length -ge 7) {
            $dotIndex = $Coordinate.IndexOf('.')
            if ($dotIndex -gt 2) {
                $degrees = [double]$Coordinate.Substring(0, $dotIndex - 2)
                $minutes = [double]$Coordinate.Substring($dotIndex - 2)
                $decimal = $degrees + ($minutes / 60)

                # Apply direction
                if ($Direction -eq 'S' -or $Direction -eq 'W') {
                    $decimal = -$decimal
                }

                return [string]::Format("{0:F6}", $decimal)
            }
        }
    }
    catch {
        return ""
    }

    return ""
}


Function Write-CSVLog {
<#
    .SYNOPSIS
    Writes GPS data to CSV log file
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Data
    )

    if ([string]::IsNullOrEmpty($LogPath)) { return }

    try {
        # Create CSV line
        $csvLine = "$($Data.Timestamp),$($Data.MessageType),$($Data.Latitude),$($Data.Longitude),$($Data.Altitude),$($Data.Speed),$($Data.Course),$($Data.Satellites),$($Data.Quality),$($Data.HDOP)"
        Add-Content -Path $LogPath -Value $csvLine
    }
    catch {
        Write-Detail "Error writing to CSV: $_"
    }
}


function help {
	Write-Host "=========================================================="
	Write-Host "------------------ COM POWERSHELL TERMINAL ---------------"
	Write-Host ""
	Write-Host " Usage: CheckComm.ps1 [option] [value] ..."
	Write-Host " optional arguments:"
	Write-Host "   --help , -h : help command"
	Write-Host "   -v : show COM port available"
	Write-Host "   -comport : set COM port"
	Write-Host "   -baudrate : set Baudrate"
	Write-Host "   -DataBits : set DataBits"
	Write-Host "   -LogFile : CSV log file path for GPS data"
	Write-Host " Example: "
	Write-Host "   CheckComm.ps1"
	Write-Host "   CheckComm.ps1 -comport COM3"
	Write-Host "   CheckComm.ps1 -comport COM3 -baudrate 115200"
	Write-Host "   CheckComm.ps1 -comport COM3 -baudrate 4800 -LogFile 'gps_track.csv'"
	Write-Host " Empty [option] will use default values"
	Write-Host " Default Configuration:"
	Write-Host "-- Port:`t$comport"
	Write-Host "-- Baudrate:`t$baudrate"
	Write-Host "-- DataBits:`t$DataBits"
	exit 1
}


function read-console {
	try {
		if([Console]::KeyAvailable)
		{
			$key = [Console]::ReadKey($true)
			$char = $key.KeyChar

			# Use "!" to close port and exit
			if($char -eq "!")
			{
				$script:port.Close()
				Write-Host "--> Port closed"
			}
			#ESC is send like Ctrl+C to end process in terminal
			elseif($char -eq [char]27)
			{
				$script:port.Write([char]3)
			}
			#Arrow Keys
			elseif($key.key -eq [ConsoleKey]::UpArrow)
			{
				$left = [char]27 + "[" + "A"
				$script:port.Write($left)
			}
			elseif($key.key -eq [ConsoleKey]::DownArrow)
			{
				$left = [char]27 + "[" + "B"
				$script:port.Write($left)
			}
			elseif($key.key -eq [ConsoleKey]::RightArrow)
			{
				$left = [char]27 + "[" + "C"
				$script:port.Write($left)
			}
			elseif($key.key -eq [ConsoleKey]::LeftArrow)
			{
				$left = [char]27 + "[" + "D"
				$script:port.Write($left)
			}
			#Delete Key
			elseif($key.key -eq [ConsoleKey]::Delete)
			{
				$left = [char]27 + "[" + "3" + "~"
				$script:port.Write($left)
			}
			#Homekey
			elseif($key.key -eq [ConsoleKey]::Home)
			{
				$left = [char]27 + "[" + "7" + "~"
				$script:port.Write($left)
			}
			#End key
			elseif($key.key -eq [ConsoleKey]::End)
			{
				$left = [char]27 + "[" + "8" + "~"
				$script:port.Write($left)
			}
			#Send char
			else
			{
				$script:port.Write($char)
			}
		}
	}
	catch {
		# Silently handle keyboard errors
	}
}

function main-process {


	$script:port= [System.IO.Ports.SerialPort]::new( $CMPort, $baudrate, [System.IO.Ports.Parity]::None, $DataBits, [System.IO.Ports.StopBits]::One );

	# Set timeouts to prevent hanging
	$script:port.ReadTimeout = 500  # 500ms timeout for reads
	$script:port.WriteTimeout = 500  # 500ms timeout for writes

	try{
		$script:port.Open()
		Write-Host "--> Connection established "
	}
	catch{
		Write-Host "--> Failed to connect!"
        $script:port.close()
		exit 1
	}

	do {
		read-com
		read-console
		Start-Sleep -Milliseconds 10  # Small delay to prevent CPU spinning
	}while ($script:port.IsOpen)
}



function read-com {
    # Check if there's data available to read
    if ($script:port.BytesToRead -eq 0) {
        return
    }

    try {
        $msge = $script:port.ReadLine();

        $thsLine = $msge -split ',';

        # Check if we have a valid NMEA sentence
        if ($thsLine.Count -lt 1 -or $thsLine[0].Length -lt 6) {
            return
        }

        $messageType = $thsLine[0].Substring(3,3)

        # Initialize GPS data object
        $gpsData = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            MessageType = $messageType
            Latitude = ""
            Longitude = ""
            Altitude = ""
            Speed = ""
            Course = ""
            Satellites = ""
            Quality = ""
            HDOP = ""
        }

        switch ($messageType){
            'GGA' {
                Write-Detail "Global Positioning System Fixed Data"

                # GGA Format: $GPGGA,time,lat,N/S,lon,E/W,quality,satellites,HDOP,altitude,M,geoid,M,age,station
                # Example: $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
                if ($thsLine.Count -ge 15) {
                    $gpsData.Latitude = Convert-NMEACoordinate -Coordinate $thsLine[2] -Direction $thsLine[3]
                    $gpsData.Longitude = Convert-NMEACoordinate -Coordinate $thsLine[4] -Direction $thsLine[5]
                    $gpsData.Quality = $thsLine[6]
                    $gpsData.Satellites = $thsLine[7]
                    $gpsData.HDOP = $thsLine[8]
                    $gpsData.Altitude = $thsLine[9]

                    # Log to CSV if logging is enabled and we have valid coordinates
                    if (![string]::IsNullOrEmpty($script:LogFile) -and ![string]::IsNullOrEmpty($gpsData.Latitude)) {
                        Write-CSVLog -LogPath $script:LogFile -Data $gpsData
                    }
                }

                break;
            }
            'GLL' {
                Write-Detail "Geographic Position—Latitude and Longitude"
                break;
            }
            'GSA' {
                Write-Detail "GNSS DOP and active satellites"
                break;
            }
            'GSV' {
                Write-Detail "GNSS satellites in view"
                break;
            }
            'RMC' {
                Write-Detail "Recommended minimum specific GPS data!"

                # RMC Format: $GPRMC,time,status,lat,N/S,lon,E/W,speed,course,date,magvar,E/W,mode
                # Example: $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
                if ($thsLine.Count -ge 12) {
                    $gpsData.Latitude = Convert-NMEACoordinate -Coordinate $thsLine[3] -Direction $thsLine[4]
                    $gpsData.Longitude = Convert-NMEACoordinate -Coordinate $thsLine[5] -Direction $thsLine[6]
                    $gpsData.Speed = $thsLine[7]  # Speed in knots
                    $gpsData.Course = $thsLine[8]  # Course in degrees

                    # Log to CSV if logging is enabled and we have valid coordinates
                    if (![string]::IsNullOrEmpty($script:LogFile) -and ![string]::IsNullOrEmpty($gpsData.Latitude)) {
                        Write-CSVLog -LogPath $script:LogFile -Data $gpsData
                    }
                }

                break;
            }
            'VTG' {
                Write-Detail "Course over ground and ground speed"
                break;
            }
            Default { Write-Detail "[$($thsLine[0])]`r`n" }
        }

        for ($i = 1; $i -lt $thsLine.count; $i++) {
            Write-Detail "$i`t[$($thsLine[$i] -replace "`r", "\R" -replace "`n", "\N" )]"
        }
    }
    catch [System.TimeoutException] {
        # Timeout is expected when no data is available, just return
        return
    }
    catch {
        # Handle other errors gracefully
        Write-Detail "Error reading serial port: $_"
    }

<#
Sentence	Description
$Talker ID+GGA	Global Positioning System Fixed Data
$Talker ID+GLL	Geographic Position—Latitude and Longitude
$Talker ID+GSA	GNSS DOP and active satellites
$Talker ID+GSV	GNSS satellites in view
$Talker ID+RMC	Recommended minimum specific GPS data
$Talker ID+VTG	Course over ground and ground speed

 #>



}

#endregion



##########################################################################################
#                                   Global Variables
##########################################################################################
#region Global Variables
## Variables: Script Name and Script Paths



$CurrentSerialPorts = [System.IO.Ports.SerialPort]::getportnames();


#endregion


# Check if user specified a COM port via parameter
if ($PSBoundParameters.ContainsKey('comport')) {
    Write-Detail "Using specified port: $comport"
    $CMPort = $comport
} elseif($CurrentSerialPorts.Count -gt 1) {
    Write-Detail "Select a port"
    # prompt for port
    $CMPort = $CurrentSerialPorts | Out-GridView -Title "Select a serial port" -PassThru;
} else {
    Write-Detail "Only the one port [$CurrentSerialPorts]"
    $CMPort = $CurrentSerialPorts;
}

# Initialize CSV log file if specified
if (![string]::IsNullOrEmpty($LogFile)) {
    # Create default filename if not provided
    if ($LogFile -eq "") {
        $LogFile = "GPS_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    }

    # Create CSV header if file doesn't exist
    if (!(Test-Path $LogFile)) {
        $csvHeader = "Timestamp,MessageType,Latitude,Longitude,Altitude,Speed,Course,Satellites,Quality,HDOP"
        Set-Content -Path $LogFile -Value $csvHeader
        Write-Detail "Created CSV log file: $LogFile"
    } else {
        Write-Detail "Appending to existing CSV log file: $LogFile"
    }
}





Write-Host "=========================================================="
Write-Host "------------------ COM POWERSHELL TERMINAL ---------------"
Write-Host "-- Type ! to close and exit"
Write-Host "-- Type ESC to end process in terminal (like Ctrl+C)"
Write-Host "-- Port:" $CMPort
Write-Host "-- Baudrate:" $baudrate
Write-Host "-- DataBits:"$DataBits
if (![string]::IsNullOrEmpty($LogFile)) {
    Write-Host "-- CSV Log: $LogFile (GPS data will be logged)"
} else {
    Write-Host "-- CSV Log: Disabled (use -LogFile to enable)"
}
Write-Host "=========================================================="
Write-Host ""

main-process

Write-Host "--> End "