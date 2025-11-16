
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
        $DataBits = 8

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


function help {
	Write-Host "=========================================================="
	Write-Host "------------------ COM POWERSHELL TERMINAL ---------------"
	Write-Host ""
	Write-Host " Usage: CheckComm.ps1 [option] [value] ..."
	Write-Host " optional arguments:"
	Write-Host "   --help , -h : help command"
	Write-Host "   -v : show COM port available"
	Write-Host "   -p : set COM port"
	Write-Host "   -b : set Baudrate"
	Write-Host "   -d : set DataBits"
	Write-Host " Example: "
	Write-Host "   CheckComm.ps1"
	Write-Host "   CheckComm.ps1 -p COM3"
	Write-Host "   CheckComm.ps1 -p COM3 -b 115200"
	Write-Host "   CheckComm.ps1 -p COM3 -b 115200 -d 8"
	Write-Host " Empty [option] will use default values"
	Write-Host " Default Configuration:"
	Write-Host "-- Port:`t$comport"
	Write-Host "-- Baudrate:`t$baudrate"
	Write-Host "-- DataBits:`t$DataBits"
	exit 1
}


function read-console {
	if([Console]::KeyAvailable)
	{
	    $key = [Console]::ReadKey($true)
		$char = $key.KeyChar
		
		# Use "!" to close port and exit
		if($char -eq "!")
		{
			$port.Close()
			Write-Host "--> Port closed"
		}
		#ESC is send like Ctrl+C to end process in terminal
		elseif($char -eq [char]27)
		{
			$port.Write([char]3)
		}
		#Arrow Keys
		elseif($key.key -eq [ConsoleKey]::UpArrow)
		{
			$left = [char]27 + "[" + "A"
			$port.Write($left)
		}
		elseif($key.key -eq [ConsoleKey]::DownArrow)
		{
			$left = [char]27 + "[" + "B"
			$port.Write($left)
		}
		elseif($key.key -eq [ConsoleKey]::RightArrow)
		{
			$left = [char]27 + "[" + "C"
			$port.Write($left)
		}
		elseif($key.key -eq [ConsoleKey]::LeftArrow)
		{
			$left = [char]27 + "[" + "D"
			$port.Write($left)
		}
		#Delete Key
		elseif($key.key -eq [ConsoleKey]::Delete)
		{
			$left = [char]27 + "[" + "3" + "~"
			$port.Write($left)
		}
		#Homekey
		elseif($key.key -eq [ConsoleKey]::Home)
		{
			$left = [char]27 + "[" + "7" + "~"
			$port.Write($left)
		}
		#End key
		elseif($key.key -eq [ConsoleKey]::End)
		{
			$left = [char]27 + "[" + "8" + "~"
			$port.Write($left)
		}
		#Send char
		else
		{	
			$port.Write($char)
		}
	}
}

function main-process {


	$port= [System.IO.Ports.SerialPort]::new( $CMPort, $baudrate, [System.IO.Ports.Parity]::None, $DataBits, [System.IO.Ports.StopBits]::One );


	try{
		$port.Open()
		Write-Host "--> Connection established " 
	}
	catch{
		Write-Host "--> Failed to connect!" 
        $port.close()
		exit 1
	}

	do {
		read-com
		read-console
	}while ($port.IsOpen)
}



function read-com {
    # Write-Detail "+ $($port.BytesToRead)"
    
    $msge = $port.ReadLine();

    $thsLine = $msge -split ',';

    # Write-Detail ;

    switch ($thsLine[0].Substring(3,3)){
        'GGA' { 
            Write-Detail "Global Positioning System Fixed Data"

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


if($CurrentSerialPorts.Count -gt 1) {
    Write-Detail "Select a port"
    # prompt for port
    $CMPort = $CurrentSerialPorts | Out-GridView -Title "Select a serial port" -PassThru;
} else {
    Write-Detail "Only the one port [$CurrentSerialPorts]"
    $CMPort = $CurrentSerialPorts;

}





Write-Host "=========================================================="
Write-Host "------------------ COM POWERSHELL TERMINAL ---------------"
Write-Host "-- Type ! to close and exit"
Write-Host "-- Type ESC to end process in terminal (like Ctrl+C)"
Write-Host "-- Port:" $CMPort
Write-Host "-- Baudrate:" $baudrate
Write-Host "-- DataBits:"$DataBits
Write-Host "=========================================================="
Write-Host ""

main-process

Write-Host "--> End "