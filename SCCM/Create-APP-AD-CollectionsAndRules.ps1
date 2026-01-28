# Version 1.3.1 - 2026-01-28
# - Fixed -Manufacturer parameter to properly resolve wildcards to actual publisher names
# - Manufacturer wildcards now query database first and show matches for confirmation
# - Changed wildcard syntax from SQL (%) to PowerShell (* and ?)
# - Prevents SQL IN clause errors when wildcards are used
#
# Version 1.3.0 - 2026-01-28
# - Added optional -Manufacturer parameter to pre-filter by publisher
# - Added optional -Product parameter to pre-filter products by name
# - Script now supports non-interactive execution when parameters provided
# - Added comprehensive help documentation with examples
#
# Version 1.2.2 - 2026-01-27
# - Fixed folder path building with proper UINT32 type casting
# - ContainerNodeID hashtable lookups now use correct type to match WMI data
# - Updated folder display to show full path instead of just name
#
# Version 1.2.1 - 2026-01-27
# - Optimized folder retrieval by sorting by ParentContainerNodeID and ContainerNodeID
# - Improved hierarchical folder processing efficiency
#
# Version 1.2 - 2026-01-23
# - Fixed collection name deduplication to prevent creating multiple collections with same name
# - Updated Get-SCCMCollectionFolders to show full folder path from root
# - Added duplicate collection detection and reporting
# - Folders now sorted by full path for better readability
#
# Version 1.1 - 2025-11-24
# - Added folder selection for SCCM collections
# - Added collection name validation (length and invalid characters)
# - Collections now created/moved to selected folder
# - Added comprehensive operation summary at end
# - Added error handling and tracking
# - Improved logging throughout script

<#
.SYNOPSIS
    Creates SCCM collections and rules based on installed software inventory.

.DESCRIPTION
    Queries SCCM database for installed applications, allows selection of products,
    and creates collections with query-based membership rules for software deployment.

.PARAMETER Manufacturer
    Optional. Specify the application manufacturer/publisher to filter results.
    Supports PowerShell wildcards (* and ?). Matched publishers will be shown for confirmation.
    If not provided, script will display all manufacturers for selection.

.PARAMETER Product
    Optional. Specify the product name to filter results.
    Supports PowerShell wildcards (* and ?). Filters the product GridView display.
    If not provided, script will display all products from selected manufacturer(s).

.EXAMPLE
    .\Create-APP-AD-CollectionsAndRules.ps1
    Runs interactively, prompting for manufacturer and product selection.

.EXAMPLE
    .\Create-APP-AD-CollectionsAndRules.ps1 -Manufacturer "Adobe*"
    Finds all publishers matching "Adobe*" (e.g., "Adobe Systems", "Adobe Inc."),
    shows them for confirmation, then prompts for product selection.

.EXAMPLE
    .\Create-APP-AD-CollectionsAndRules.ps1 -Manufacturer "Dell Inc." -Product "Dell Optimizer*"
    Uses exact manufacturer "Dell Inc.", filters products starting with "Dell Optimizer".
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false, HelpMessage="Application manufacturer/publisher (supports wildcards * and ?)")]
    [String]$Manufacturer,

    [Parameter(Mandatory=$false, HelpMessage="Product name (supports wildcards * and ?)")]
    [String]$Product
)

[STRING]$gCMSourceSite = "XXX";                           # SCCM Sitename
[STRING]$gCMSite  =      "ROOT\SMS\site_$gCMSourceSite"   # WMI path
[STRING]$gUPN     =      "SCCM.LOCAL"                     # Local UPN
[STRING]$gCMSServ =      "SCCMSITESEVER.SCCM.LOCAL"       # FQDN to Site
[STRING]$gDomain  =      $env:USERDOMAIN;                 # Run as local user ?

# Database parameters
$ConnectionTimeout = 30;
[STRING]$ServerName        = "SCCMSQLSRV.SCCM.LOCAL";     # FQDN To SQL Server
[STRING]$DatabaseName      = "CM_XXX";                    # SCCM DB



[INT]$psVer       = $PSVersionTable.PSVersion.Major;
$UsrObj = ([adsi]"LDAP://$(whoami /fqdn)")

<#
$UsrObj.mail
$UsrObj.displayName
$UsrObj.userPrincipalName
$UsrObj.sAMAccountName
#>


[STRING]$gStrLine = "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-";


#endregion


#region Helper Functions

##########################################################################################
#                                   Helper Functions
##########################################################################################

<#
function Validate-Filename { 
	Param([ValidatePattern("^\d{8}_[a-zA-Z]{3,4}_[a-zA-Z]{1}\.jpg"]$filename) 
	Write-host "The filename $filename is valid" 
} #>

Function Write-Detail {
<#
    .SYNOPSIS
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
    # $(Get-CurrentLineNumber)
    # Write-Host "$(Get-CurrentLineNumber)`t$(Get-Date -Format s) - 
    Write-Host "$(Get-Date -Format s)`t$($MyInvocation.ScriptLineNumber) `t- $message"
}          # End of Write-Detail

Function Test-Cred {
<#
    .SYNOPSIS
	    Wrapper for Invoke-WebRequest to handle proxy configuration.
    .DESCRIPTION
    	"Test-Cred"
    .PARAMETER Credential
        The network credential to check.

    .INPUTS
        Expects an PSCredential to be passed to it. If not will prompt for the Credential.

    .OUTPUTS
        [Bool] True or False

    .EXAMPLE
        Test-Cred -Credential $(Get-Credential -Message "Enter username to be checked.`r`nExclude Domain prefix.")
	
#>
	[CmdletBinding()]
	Param(
	[Parameter(Mandatory=$True,HelpMessage="Please Enter Credentials")]
	$Credential
	)

	if ($Credential -isnot [System.Management.Automation.PSCredential]) {
		Write-Warning "Not the correct object type.."
		$Credential = Get-Credential -Message "`"$Credential`" is not in the correct format!`r`nEnter username to be checked.`r`nExclude Domain prefix." -UserName $Credential
		# could do error handling here as well..
	}

	# $Credentials = Get-Credential -Message "Please enter a the password for `"$lAdminUsr`"" -UserName $lAdminUsr;
	$UserName = $Credential.GetNetworkCredential().UserName;
	$Password = $Credential.GetNetworkCredential().Password;


	$CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
    # "LDAP://" + ([ADSI]"").upnSuffixes
	$domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

	if ($domain.name -eq $null) {
		write-detail "Authentication failed - please verify your username `"$UserName`" and password.";
		# exit #terminate the script.
		return $false;
	} else {
		write-detail "Successfully authenticated with domain $($domain.name)";
		return $true;
	}
}           # End of Test-Cred

function get-ProductQuery {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="Application Publisher")][STRING]$AppPublisher,
        [Parameter(Mandatory=$true, HelpMessage="Product displayname",ValueFromPipeline=$true)][String]$AppDisplayName
    )

$mySQLQuery = "Select
	[Program Type]
	, [Display Name]
	, [Publisher]
	, isNull([Version],'') as [Version]
	, [Display Name] + ' - ' + [Program Type] + ' - ' + isNull([Version],'') as [Collection/Rule Name]
	, count(ResourceID) [Count] 
	, [Product Code]
	, CASE [Program Type]

	When '32 Bit' then 
	'select ResourceID from SMS_R_System inner join SMS_G_System_ADD_REMOVE_PROGRAMS on SMS_G_System_ADD_REMOVE_PROGRAMS.ResourceId = SMS_R_System.ResourceId 
	where SMS_G_System_ADD_REMOVE_PROGRAMS.DisplayName like `"' + [Display Name] + '`" and SMS_G_System_ADD_REMOVE_PROGRAMS.Version = `"' + [Version] + '`"' 
	When '64 Bit' Then  
	'select ResourceID from SMS_R_System inner join SMS_G_System_ADD_REMOVE_PROGRAMS_64 on SMS_G_System_ADD_REMOVE_PROGRAMS_64.ResourceId = SMS_R_System.ResourceId 
	where SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName like `"' + [Display Name] + '`" and SMS_G_System_ADD_REMOVE_PROGRAMS_64.Version = `"' + [Version] + '`"' 
	ELSE ''
	end
	as [WQL query]



from ( 
-- 32 Bit Apps
SELECT  DISTINCT     
             
             v_R_System.ResourceID as 'ResourceID', 
			  '32 Bit' as 'Program Type',
			  v_GS_ADD_REMOVE_PROGRAMS.DisplayName0 AS 'Display Name', 
           
			  ISNULL(v_GS_ADD_REMOVE_PROGRAMS.Publisher0, '') AS 'Publisher',
			  v_GS_ADD_REMOVE_PROGRAMS.Version0 AS 'Version', 
              v_GS_ADD_REMOVE_PROGRAMS.ProdID0 AS 'Product Code'
              
FROM            v_R_System  with (nolock) INNER JOIN
                         v_GS_ADD_REMOVE_PROGRAMS with (nolock) ON v_R_System.ResourceID = v_GS_ADD_REMOVE_PROGRAMS.ResourceID
			
WHERE		
				Publisher0 like '{0}'
		AND DisplayName0 like '{1}'
UNION

-- 64 Bit Apps

SELECT   DISTINCT    
              
              v_R_System.ResourceID as 'ResourceID', 
			  '64 Bit' as 'Program Type',
			  v_GS_ADD_REMOVE_PROGRAMS_64.DisplayName0 AS 'Display Name', 
            
			  ISNULL(v_GS_ADD_REMOVE_PROGRAMS_64.Publisher0, '') AS 'Publisher', 
              v_GS_ADD_REMOVE_PROGRAMS_64.Version0 AS 'Version', 
			  v_GS_ADD_REMOVE_PROGRAMS_64.ProdID0 AS 'Product Code'

FROM          v_R_System with (nolock) 
				INNER JOIN
                         v_GS_ADD_REMOVE_PROGRAMS_64 with (nolock) ON v_R_System.ResourceID = v_GS_ADD_REMOVE_PROGRAMS_64.ResourceID
				
WHERE  
		Publisher0 like '{0}'
		AND DisplayName0 like '{1}'
) as combined
		
 group by [Program Type], [Display Name], [Publisher], [Version], [Product Code]

order by 'Display Name', 'Program Type', 'Version'" -f $AppPublisher,$AppDisplayName;
Return [STRING]$mySQLQuery;

}

function get-AppPublisher {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$false, HelpMessage="Application Publisher")][STRING]$AppPublisher
    )

$mySQLQuery = "SELECT  DISTINCT     
-- 32 Bit Apps             
			  ISNULL(v_GS_ADD_REMOVE_PROGRAMS.Publisher0, '') AS 'Publisher'
              
FROM            v_R_System  with (nolock) INNER JOIN
                         v_GS_ADD_REMOVE_PROGRAMS with (nolock) ON v_R_System.ResourceID = v_GS_ADD_REMOVE_PROGRAMS.ResourceID
			
	

UNION

-- 64 Bit Apps

SELECT   DISTINCT    
              
            
			  ISNULL(v_GS_ADD_REMOVE_PROGRAMS_64.Publisher0, '') AS 'Publisher'

FROM          v_R_System with (nolock) 
				INNER JOIN
                         v_GS_ADD_REMOVE_PROGRAMS_64 with (nolock) ON v_R_System.ResourceID = v_GS_ADD_REMOVE_PROGRAMS_64.ResourceID
						


order by 'Publisher';" -f $AppPublisher;
Return [STRING]$mySQLQuery;

}

function get-AppProducts {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="Application Publishers")][STRING]$Publisher
    )

$mySQLQuery = "Select
	[Program Type]
	, [Display Name]
	, [Publisher]
	, isNull([Version],'') as [Version]
	, [Display Name] + ' - ' + [Program Type] + ' - ' + isNull([Version],'') as [Collection/Rule Name]
	, count(ResourceID) [Count] 
	, [Product Code]
	, CASE [Program Type]

	When '32 Bit' then 
	'select ResourceID from SMS_R_System inner join SMS_G_System_ADD_REMOVE_PROGRAMS on SMS_G_System_ADD_REMOVE_PROGRAMS.ResourceId = SMS_R_System.ResourceId 
	where SMS_G_System_ADD_REMOVE_PROGRAMS.DisplayName like `"' + [Display Name] + '`" and SMS_G_System_ADD_REMOVE_PROGRAMS.Version = `"' + [Version] + '`"' 
	When '64 Bit' Then  
	'select ResourceID from SMS_R_System inner join SMS_G_System_ADD_REMOVE_PROGRAMS_64 on SMS_G_System_ADD_REMOVE_PROGRAMS_64.ResourceId = SMS_R_System.ResourceId 
	where SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName like `"' + [Display Name] + '`" and SMS_G_System_ADD_REMOVE_PROGRAMS_64.Version = `"' + [Version] + '`"' 
	ELSE ''
	end
	as [WQL query]



from ( 
-- 32 Bit Apps
SELECT  DISTINCT     
             
             v_R_System.ResourceID as 'ResourceID', 
			  '32 Bit' as 'Program Type',
			  v_GS_ADD_REMOVE_PROGRAMS.DisplayName0 AS 'Display Name', 
           
			  ISNULL(v_GS_ADD_REMOVE_PROGRAMS.Publisher0, '') AS 'Publisher',
			  v_GS_ADD_REMOVE_PROGRAMS.Version0 AS 'Version', 
              v_GS_ADD_REMOVE_PROGRAMS.ProdID0 AS 'Product Code'
              
FROM            v_R_System  with (nolock) INNER JOIN
                         v_GS_ADD_REMOVE_PROGRAMS with (nolock) ON v_R_System.ResourceID = v_GS_ADD_REMOVE_PROGRAMS.ResourceID
			
WHERE		
				Publisher0 in ({0})
UNION

-- 64 Bit Apps

SELECT   DISTINCT    
              
              v_R_System.ResourceID as 'ResourceID', 
			  '64 Bit' as 'Program Type',
			  v_GS_ADD_REMOVE_PROGRAMS_64.DisplayName0 AS 'Display Name', 
            
			  ISNULL(v_GS_ADD_REMOVE_PROGRAMS_64.Publisher0, '') AS 'Publisher', 
              v_GS_ADD_REMOVE_PROGRAMS_64.Version0 AS 'Version', 
			  v_GS_ADD_REMOVE_PROGRAMS_64.ProdID0 AS 'Product Code'

FROM          v_R_System with (nolock) 
				INNER JOIN
                         v_GS_ADD_REMOVE_PROGRAMS_64 with (nolock) ON v_R_System.ResourceID = v_GS_ADD_REMOVE_PROGRAMS_64.ResourceID
				
WHERE  
		Publisher0 in ({0})
) as combined
		
 group by [Program Type], [Display Name], [Publisher], [Version], [Product Code]

order by 'Display Name', 'Program Type', 'Version';" -f $Publisher;
Return [STRING]$mySQLQuery;

}

<#
    
    From...
    http://www.hasmug.com/2011/09/25/sccm-powershell-script-to-check-for-local-dp-get-sccmclienthaslocaldp/

#>
Function Get-SCCMClientHasLocalDP {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="ClientName",ValueFromPipeline=$true)][String] $clientName,
		[Parameter(Mandatory=$false,HelpMessage="Credentials to use" )][System.Management.Automation.PSCredential] $credential = $null
    )
 
    PROCESS {
		$DP = $false
        Write-Detail "SCCM Servers = `"$SccmServer`""
        Write-Detail "Client Name  = `"$clientName`""
    
		if ($credential -eq $null) {
			$client = Get-SCCMObject -sccmServer $SccmServer -class SMS_R_System -Filter "Name = '$($clientName)'"
			if (-not $client) {
				throw "Client does not exist in SCCM. Please check your spelling"
			}
			$Filter = "SMS_R_System.ADSiteName = '$($client.ADSiteName)' and Name IN (Select ServerName FROM SMS_DistributionPointInfo)"
            Write-Detail "Filter is `"$Filter`""
        	$DP = Get-SCCMObject -sccmServer $SccmServer -class SMS_R_System -Filter $Filter
		} else {
            Write-Detail "Get-SCCMObject -sccmServer $SccmServer -class SMS_R_System -Filter `"Name = '$($clientName)'`" -credential `$credential"
			$client = Get-SCCMObject -sccmServer $SccmServer -class SMS_R_System -Filter "Name = '$($clientName)' AND Client = 1" -credential $credential
            
			if (-not $client) {
				throw "Client does not exist in SCCM. Please check your spelling"
			}
            $Filter = "SMS_R_System.ADSiteName = '$($client.ADSiteName)' AND SystemRoles like 'SMS Distribution Point'"
			# $Filter = "SMS_R_System.ADSiteName = '$($client.ADSiteName)' and Name IN (Select ServerName FROM SMS_DistributionPointInfo)"
            Write-Detail "Filter is `"$Filter`""
        	$DP = Get-SCCMObject -sccmServer $SccmServer -class SMS_R_System -Filter $Filter -credential $credential
		}
 
		if ($DP) {
 			return $true
		} else {
			return $false
		}
    }
} # End of Get-SCCMClientHasLocalDP

Function Get-ADSiteHasLocalDP {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="Enter the AD SiteName you wish to find ",ValueFromPipeline=$true)][String] $ADSiteName,
		[Parameter(Mandatory=$false,HelpMessage="Credentials to use" )][System.Management.Automation.PSCredential] $credential = $null
    )
 
    PROCESS {
		$DP = $false
        Write-Detail "SCCM Servers = `"$SccmServer`""
        Write-Detail "Client Name  = `"$clientName`""
        $Filter = "SMS_R_System.ADSiteName = '$ADSiteName' AND SystemRoles like 'SMS Distribution Point'"
        Write-Detail "Filter is `"$Filter`""
		if ($credential -eq $null) {
        	$DP = Get-SCCMObject -sccmServer $SccmServer -class SMS_R_System -Filter $Filter
		} else {
        	$DP = Get-SCCMObject -sccmServer $SccmServer -class SMS_R_System -Filter $Filter -credential $credential
		}
 
        Write-Detail "Site DP is $($DP.Name)"
        # $DP | gm
        # $DP | Out-GridView
		if ($DP) {
            # Return the DP 
 			return $($DP.Name)
		} else {
			return $false
		}
    }
}     # End of Get-ADSiteHasLocalDP

Function Get-SCCMObject {
    #  Generic query tool
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipelineByPropertyName=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="SCCM Class to query",ValueFromPipeline=$true)][Alias("Table","View")][String] $class,
        [Parameter(Mandatory=$false,HelpMessage="Optional Filter on query")][String] $Filter = $null,
		[Parameter(Mandatory=$false,HelpMessage="Credentials to use" )][System.Management.Automation.PSCredential] $credential = $null

    )
 
    PROCESS {
        if ($Filter -eq $null -or $Filter -eq "")
        {
            Write-Detail "WMI Query: SELECT * FROM $class"
            $retObj = get-wmiobject -class $class -computername $SccmServer.Machine -namespace $SccmServer.Namespace -Credential $credential
        }
        else
        {
            Write-Detail "WMI Query: SELECT * FROM $class WHERE $Filter"
            $retObj = get-wmiobject -query "SELECT * FROM $class WHERE $Filter" -computername $SccmServer.Machine -namespace $SccmServer.Namespace  -Credential $credential
        }
 
        return $retObj
    }
}           # End of Get-SCCMObject

Function Connect-SCCMServer {
    # Connect to one SCCM server
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$false,HelpMessage="SCCM Server Name or FQDN",ValueFromPipeline=$true)][Alias("ServerName","FQDN","ComputerName")][String] $HostName = (Get-Content env:computername),
        [Parameter(Mandatory=$false,HelpMessage="Optional SCCM Site Code",ValueFromPipelineByPropertyName=$true )][String] $siteCode = $null,
        [Parameter(Mandatory=$false,HelpMessage="Credentials to use" )][System.Management.Automation.PSCredential] $credential = $null
    )
 
    PROCESS {
        # Get the pointer to the provider for the site code
        if ($siteCode -eq $null -or $siteCode -eq "") {
            Write-Detail "Getting provider location for default site on server $HostName"
            if ($credential -eq $null) {
                $sccmProviderLocation = Get-WmiObject -query "select * from SMS_ProviderLocation where ProviderForLocalSite = true" -Namespace "root\sms" -computername $HostName -errorAction Stop
            } else {
                $sccmProviderLocation = Get-WmiObject -query "select * from SMS_ProviderLocation where ProviderForLocalSite = true" -Namespace "root\sms" -computername $HostName -credential $credential -errorAction Stop
            }
        } else {
            Write-Detail "Getting provider location for site $siteCode on server $HostName"
            if ($credential -eq $null) {
                $sccmProviderLocation = Get-WmiObject -query "SELECT * FROM SMS_ProviderLocation where SiteCode = '$siteCode'" -Namespace "root\sms" -computername $HostName -errorAction Stop
            } else {
                $sccmProviderLocation = Get-WmiObject -query "SELECT * FROM SMS_ProviderLocation where SiteCode = '$siteCode'" -Namespace "root\sms" -computername $HostName -credential $credential -errorAction Stop
            }
        }
 
        # Split up the namespace path
        $parts = $sccmProviderLocation.NamespacePath -split "\\", 4
        Write-Detail "Provider is located on $($sccmProviderLocation.Machine) in namespace $($parts[3])"
 
        # Create a new object with information
        $retObj = New-Object -TypeName System.Object
        $retObj | add-Member -memberType NoteProperty -name Machine -Value $HostName
        $retObj | add-Member -memberType NoteProperty -name Namespace -Value $parts[3]
        $retObj | add-Member -memberType NoteProperty -name SccmProvider -Value $sccmProviderLocation
 
        return $retObj
    }
}       # End of Connect-SCCMServer

Function New-SCCMCollection {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="Collection Name", ValueFromPipeline=$true)][String] $name,
        [Parameter(Mandatory=$false, HelpMessage="Collection comment")][String] $comment = "",
        [Parameter(Mandatory=$false, HelpMessage="Refresh Rate in Minutes")] [ValidateRange(0, 59)] [int] $refreshMinutes = 0,
        [Parameter(Mandatory=$false, HelpMessage="Refresh Rate in Hours")] [ValidateRange(0, 23)] [int] $refreshHours = 0,
        [Parameter(Mandatory=$false, HelpMessage="Refresh Rate in Days")] [ValidateRange(0, 31)] [int] $refreshDays = 0,
        [Parameter(Mandatory=$false, HelpMessage="Parent CollectionID")][String] $parentCollectionID = "COLLROOT"
    )
 
    PROCESS {
        # Build the parameters for creating the collection
        $arguments = @{Name = $name; Comment = $comment; OwnedByThisSite = $true}
        # $newColl = Set-WmiInstance -class "SMS_Collection" -arguments $arguments -computername $SccmServer.Machine -namespace $SccmServer.Namespace
        $newCollClass = [WMICLASS]"\\$($SccmServer.Machine)\$($SccmServer.Namespace):SMS_Collection"
        $newColl = $newCollClass.CreateInstance()
 
        $newColl.Name = $name
        $newColl.Comment = $comment
        $newColl.OwnedByThisSite = $true
        $newColl.LimitToCollectionID = $parentCollectionID

        $newColl.Put();
        # Hack - for some reason without this we don't get the CollectionID value
        # $hack = $newColl.PSBase | select * | out-null
 
        # It's really hard to set the refresh schedule via Set-WmiInstance, so we'll set it later if necessary
        if ($refreshMinutes -gt 0 -or $refreshHours -gt 0 -or $refreshDays -gt 0) {
            Write-Verbose "Create the recur interval object"
            $intervalClass = [WMICLASS]"\\$($SccmServer.Machine)\$($SccmServer.Namespace):SMS_ST_RecurInterval"
            $interval = $intervalClass.CreateInstance()
            if ($refreshMinutes -gt 0) {
                $interval.MinuteSpan = $refreshMinutes
            }
            if ($refreshHours -gt 0) {
                $interval.HourSpan = $refreshHours
            }
            if ($refreshDays -gt 0) {
                $interval.DaySpan = $refreshDays
            }
 
            Write-Verbose "Set the refresh schedule"
            $newColl.RefreshSchedule = $interval
            $newColl.RefreshType=2
            $path = $newColl.Put()
        }
<# 
        Write-Verbose "Setting the new $($newColl.CollectionID) parent to $parentCollectionID"
        $subArguments  = @{SubCollectionID = $newColl.CollectionID}
        $subArguments += @{ParentCollectionID = $parentCollectionID}
 
        # Add the link
        $newRelation = Set-WmiInstance -Class "SMS_CollectToSubCollect" -arguments $subArguments -computername $SccmServer.Machine -namespace $SccmServer.Namespace
 #>
        Write-Verbose "Return the new collection with ID $($newColl.CollectionID)"
        return $newColl
    }
}
 
Function Add-SCCMCollectionRule {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true,  HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true,  HelpMessage="CollectionID", ValueFromPipelineByPropertyName=$true)] $collectionID,
        [Parameter(Mandatory=$false, HelpMessage="Computer name to add (direct)", ValueFromPipeline=$true)] [String] $name,
        [Parameter(Mandatory=$false, HelpMessage="WQL Query Expression", ValueFromPipeline=$true)] [String] $queryExpression = $null,
        [Parameter(Mandatory=$false, HelpMessage="Limit to collection (Query)", ValueFromPipeline=$false)] [String] $limitToCollectionId = $null,
        [Parameter(Mandatory=$true,  HelpMessage="Rule Name", ValueFromPipeline=$true)] [String] $queryRuleName
    )

    PROCESS {
        # Get the specified collection (to make sure we have the lazy properties)
        $coll = [wmi]"$($SccmServer.SccmProvider.NamespacePath):SMS_Collection.CollectionID='$collectionID'"

        # Build the new rule
        if ($queryExpression.Length -gt 0) {
            # Create a query rule
            $ruleClass = [WMICLASS]"$($SccmServer.SccmProvider.NamespacePath):SMS_CollectionRuleQuery"
            $newRule = $ruleClass.CreateInstance()
            $newRule.RuleName = $queryRuleName
            $newRule.QueryExpression = $queryExpression
            if ([string]::IsNullOrEmpty($limitToCollectionId) -ne $True) {
                $newRule.LimitToCollectionID = $limitToCollectionId
            }

            $null = $coll.AddMembershipRule($newRule)
        } else {
            $ruleClass = [WMICLASS]"$($SccmServer.SccmProvider.NamespacePath):SMS_CollectionRuleDirect"

            # Find each computer
            $computer = Get-SCCMComputer -sccmServer $SccmServer -NetbiosName $name
            # See if the computer is already a member
            $found = $false
            if ($coll.CollectionRules -ne $null) {
                foreach ($member in $coll.CollectionRules) {
                    if ($member.ResourceID -eq $computer.ResourceID) {
                        $found = $true
                    }
                }
            }
            if (-not $found) {
                Write-Verbose "Adding new rule for computer $name"
                $newRule = $ruleClass.CreateInstance()
                $newRule.RuleName = $name
                $newRule.ResourceClassName = "SMS_R_System"
                $newRule.ResourceID = $computer.ResourceID

                $null = $coll.AddMembershipRule($newRule)
            } else {
                Write-Verbose "Computer $name is already in the collection"
            }
        }
    }
}           # End of Add-SCCMCollectionRule

Function Get-SCCMCollectionFolders {
<#
    .SYNOPSIS
    Retrieves SCCM collection folders for user selection
    .DESCRIPTION
    Gets all collection folders from SCCM and returns them for user selection.
    Builds full hierarchical path from root for each folder to distinguish folders
    with the same name in different locations.
    .PARAMETER SccmServer
    The SCCM server object
    .PARAMETER Credential
    Optional credentials for SCCM access
    .OUTPUTS
    Array of folder objects with ContainerNodeID, Name, ParentContainerNodeID, and Path (full path from root)
    .EXAMPLE
    Get-SCCMCollectionFolders -SccmServer $myServer
    Returns folders with paths like "\Applications\Adobe" or "\Workstations\Sales"
#>
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Credentials to use")][System.Management.Automation.PSCredential] $credential = $null
    )

    PROCESS {
        try {
            Write-Detail "Retrieving SCCM collection folders..."

            # ObjectType 5000 is for Device Collections
            $Filter = "ObjectType = 5000"

            if ($credential -eq $null) {
                $folders = Get-WmiObject -Class SMS_ObjectContainerNode -Namespace $SccmServer.Namespace -ComputerName $SccmServer.Machine -Filter $Filter
            } else {
                $folders = Get-WmiObject -Class SMS_ObjectContainerNode -Namespace $SccmServer.Namespace -ComputerName $SccmServer.Machine -Filter $Filter -Credential $credential
            }

            # Sort folders by parent-child relationship for efficient processing
            $folders = $folders | Sort-Object -Property ParentContainerNodeID, ContainerNodeID

            # Create hashtable for quick folder lookup by ID
            $folderHash = @{}
            foreach ($folder in $folders) {
                $folderHash[$folder.ContainerNodeID] = $folder
            }

            # Helper function to build full path from root
            function Get-FolderPath {
                param(
                    [UINT32]$FolderID,
                    [hashtable]$FolderLookup
                )

                if ($FolderID -eq 0) {
                    return "\"
                }

                $pathParts = @()
                [UINT32]$currentID = $FolderID

                # Walk up the parent chain
                while ($currentID -ne 0 -and $FolderLookup.ContainsKey([UINT32]$currentID)) {
                    $currentFolder = $FolderLookup[[UINT32]$currentID]
                    $pathParts = @($currentFolder.Name) + $pathParts
                    $currentID = $currentFolder.ParentContainerNodeID
                }

                # Build the full path
                if ($pathParts.Count -gt 0) {
                    return "\" + ($pathParts -join "\")
                } else {
                    return "\"
                }
            }

            # Build folder list with full paths
            $folderList = @()
            foreach ($folder in $folders) {
                $fullPath = Get-FolderPath -FolderID $folder.ContainerNodeID -FolderLookup $folderHash

                $folderObj = New-Object PSObject -Property @{
                    ContainerNodeID = $folder.ContainerNodeID
                    Name = $folder.Name
                    ParentContainerNodeID = $folder.ParentContainerNodeID
                    Path = $fullPath
                }
                $folderList += $folderObj
            }

            # Sort by path for better readability
            $folderList = $folderList | Sort-Object Path

            # Add root folder option at the beginning
            $rootFolder = New-Object PSObject -Property @{
                ContainerNodeID = 0
                Name = "Root (No Folder)"
                ParentContainerNodeID = 0
                Path = "\"
            }
            $folderList = @($rootFolder) + $folderList

            return $folderList
        }
        catch {
            Write-Detail "Error retrieving folders: $($_.Exception.Message)"
            throw
        }
    }
}           # End of Get-SCCMCollectionFolders

Function Move-SCCMCollectionToFolder {
<#
    .SYNOPSIS
    Moves an SCCM collection to a specified folder
    .DESCRIPTION
    Moves a collection to the specified folder using SMS_ObjectContainerItem
    .PARAMETER SccmServer
    The SCCM server object
    .PARAMETER CollectionID
    The collection ID to move
    .PARAMETER FolderID
    The target folder's ContainerNodeID
    .PARAMETER Credential
    Optional credentials for SCCM access
#>
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="Collection ID")][String] $CollectionID,
        [Parameter(Mandatory=$true, HelpMessage="Folder Container Node ID")][int] $FolderID,
        [Parameter(Mandatory=$false, HelpMessage="Credentials to use")][System.Management.Automation.PSCredential] $credential = $null
    )

    PROCESS {
        try {
            # Skip if folder is root (0)
            if ($FolderID -eq 0) {
                Write-Verbose "Collection will remain in root folder"
                return $true
            }

            # Check if collection is already in a folder
            $Filter = "InstanceKey = '$CollectionID' AND ObjectType = 5000"

            if ($credential -eq $null) {
                $existingItem = Get-WmiObject -Class SMS_ObjectContainerItem -Namespace $SccmServer.Namespace -ComputerName $SccmServer.Machine -Filter $Filter
            } else {
                $existingItem = Get-WmiObject -Class SMS_ObjectContainerItem -Namespace $SccmServer.Namespace -ComputerName $SccmServer.Machine -Filter $Filter -Credential $credential
            }

            if ($existingItem) {
                # Update existing folder assignment
                $existingItem.ContainerNodeID = $FolderID
                $existingItem.Put() | Out-Null
                Write-Verbose "Moved collection $CollectionID to folder $FolderID"
            } else {
                # Create new folder assignment
                $containerItemClass = [WMICLASS]"\\$($SccmServer.Machine)\$($SccmServer.Namespace):SMS_ObjectContainerItem"
                $newItem = $containerItemClass.CreateInstance()
                $newItem.ContainerNodeID = $FolderID
                $newItem.InstanceKey = $CollectionID
                $newItem.ObjectType = 5000  # Device Collection
                $newItem.Put() | Out-Null
                Write-Verbose "Added collection $CollectionID to folder $FolderID"
            }

            return $true
        }
        catch {
            Write-Detail "Error moving collection to folder: $($_.Exception.Message)"
            return $false
        }
    }
}           # End of Move-SCCMCollectionToFolder

Function Test-CollectionName {
<#
    .SYNOPSIS
    Validates SCCM collection name for length and invalid characters
    .DESCRIPTION
    Checks if a collection name is valid according to SCCM constraints:
    - Maximum 127 characters
    - No invalid characters: \ / : * ? " < > |
    .PARAMETER Name
    The collection name to validate
    .OUTPUTS
    Hashtable with IsValid (bool), Message (string), and SanitizedName (string)
#>
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="Collection name to validate")][String] $Name
    )

    PROCESS {
        $result = @{
            IsValid = $true
            Message = ""
            SanitizedName = $Name
            OriginalLength = $Name.Length
        }

        # Check for invalid characters
        $invalidChars = @('\', '/', ':', '*', '?', '"', '<', '>', '|')
        $foundInvalidChars = @()

        foreach ($char in $invalidChars) {
            if ($Name.Contains($char)) {
                $foundInvalidChars += $char
            }
        }

        if ($foundInvalidChars.Count -gt 0) {
            $result.IsValid = $false
            $result.Message = "Contains invalid characters: $($foundInvalidChars -join ', ')"
            # Sanitize by removing invalid characters
            $sanitized = $Name
            foreach ($char in $invalidChars) {
                $sanitized = $sanitized.Replace($char, '')
            }
            $result.SanitizedName = $sanitized
        }

        # Check length (SCCM max is 127 characters)
        if ($Name.Length -gt 127) {
            $result.IsValid = $false
            if ($result.Message.Length -gt 0) {
                $result.Message += "; "
            }
            $result.Message += "Name too long ($($Name.Length) characters, max 127)"
            # Truncate to 127 characters
            $result.SanitizedName = $result.SanitizedName.Substring(0, 127)
        }

        # Final check on sanitized name length
        if ($result.SanitizedName.Length -gt 127) {
            $result.SanitizedName = $result.SanitizedName.Substring(0, 127)
        }

        return $result
    }
}           # End of Test-CollectionName

#endregion


if ($myCred -isnot [System.Management.Automation.PSCredential]) {
    if ($psVer -ge 4) {
            $myCred = Get-Credential -Message "Please enter the Admin user and password for `"$($UsrObj.displayName)`"";
	    } else {
		    $myCred = Get-Credential
	    }
}


$bTestAccount = Test-Cred -Credential $myCred;
	if ($bTestAccount -ne $True ) {
		write-detail "Credentials failed to check out.";
		return [Bool]$false;    
	} else {

        Write-Detail "Creds are good..."

    }


<#
[Security.Principal.WindowsIdentity]::GetCurrent().Groups

$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
$currentUser | gm

#>


# $NoProxy = [System.Net.WebProxy]::new();


$LogFileTime = Get-Date -Format "yyyyMMdd-HHmm"
$logPath = [System.Environment]::ExpandEnvironmentVariables("%tmp%");
$logFile = Join-Path -Path $logPath -ChildPath  "$($myInvocation.MyCommand)-$LogFileTime.log";


$numNew    = 0;
$numExst   = 0;



# Start the logging 
Start-Transcript -Path $logFile;


$csvdelimiter = ",";


# Query for App Collections..


[void][Reflection.Assembly]::LoadWithPartialName("System.Data");
[void][Reflection.Assembly]::LoadWithPartialName("System.Data.SqlClient");




#Action of connecting to the Database and executing the query and returning results if there were any.
$ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerName,$DatabaseName,$ConnectionTimeout

# Check if Manufacturer parameter was provided
if ([string]::IsNullOrEmpty($Manufacturer)) {
    # No manufacturer specified - show interactive selection
    Write-Detail "No manufacturer specified, retrieving all publishers for selection..."

    $SQLQuery = get-AppPublisher;

    $dataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SQLQuery, $ConnectionString)
    $SQLdataTable = New-object "System.Data.DataTable"
    $dataAdapter.Fill($SQLdataTable);
    $dataAdapter.Dispose()

    $MyAppPublisher = $SQLdataTable | Out-GridView -Title "Choose a application publisher..." -PassThru

    if ($MyAppPublisher.Publisher.Count -gt 0 ) {
        Write-Detail "Looking products associated with the following publisher(s) '$($MyAppPublisher.Publisher -join "', '")' [$($MyAppPublisher.Publisher.count)]"
    } else {
        Write-detail "Nothing selected..."
        throw "Nothing selected, no Publisher selected"
        Stop-Transcript
    }
} else {
    # Manufacturer parameter provided - resolve wildcards to actual publisher names
    Write-Detail "Manufacturer parameter specified: '$Manufacturer'"
    Write-Detail "Querying database to resolve manufacturer name(s)..."

    # Query all publishers from database
    $SQLQuery = get-AppPublisher;
    $dataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SQLQuery, $ConnectionString)
    $SQLdataTable = New-object "System.Data.DataTable"
    $dataAdapter.Fill($SQLdataTable);
    $dataAdapter.Dispose()

    # Filter publishers using the manufacturer parameter (supports wildcards)
    $matchedPublishers = $SQLdataTable | Where-Object { $_.Publisher -like $Manufacturer }

    if ($matchedPublishers.Count -eq 0) {
        Write-Detail "ERROR: No publishers matched '$Manufacturer'"
        Write-Detail "Available publishers will be shown for selection..."

        # Show all for selection as fallback
        $MyAppPublisher = $SQLdataTable | Out-GridView -Title "No matches for '$Manufacturer' - Choose publisher(s)..." -PassThru

        if ($MyAppPublisher.Publisher.Count -eq 0) {
            Write-detail "Nothing selected..."
            throw "Nothing selected, no Publisher selected"
            Stop-Transcript
        }
    } else {
        Write-Detail "Found $($matchedPublishers.Count) matching publisher(s):"
        foreach ($pub in $matchedPublishers) {
            Write-Detail "  - $($pub.Publisher)"
        }

        # Show matched publishers for confirmation
        $MyAppPublisher = $matchedPublishers | Out-GridView -Title "Confirm publisher(s) matching '$Manufacturer'..." -PassThru

        if ($MyAppPublisher.Publisher.Count -eq 0) {
            Write-detail "Nothing selected..."
            throw "Nothing selected, no Publisher selected"
            Stop-Transcript
        }
    }

    Write-Detail "Using $($MyAppPublisher.Publisher.Count) publisher(s): '$($MyAppPublisher.Publisher -join "', '")'"
}


# 

$SQLQuery = get-AppProducts -Publisher "'$($MyAppPublisher.Publisher -join "', '")'";


$dataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SQLQuery, $ConnectionString)
$SQLdataTable       = New-object “System.Data.DataTable”
$dataAdapter.Fill($SQLdataTable);
$dataAdapter.Dispose()


# $MyAppProduct 

# $SQLQuery = get-ProductQuery -AppPublisher 'Dell Inc.' -AppDisplayName 'Dell SupportAssist for Business PCs';
# $SQLQuery = get-ProductQuery -AppPublisher 'Adobe%' -AppDisplayName 'Adobe Acrobat%';
# $SQLQuery = get-ProductQuery -AppPublisher 'Adobe%' -AppDisplayName '%';

# $SQLQuery = get-ProductQuery -AppPublisher 'Dell' -AppDisplayName 'Dell Optimizer';

# 
# $SQLQuery = get-ProductQuery -AppPublisher 'CrowdStrike, Inc.' -AppDisplayName 'CrowdStrike Sensor Platform';
# $SQLQuery = get-ProductQuery -AppPublisher 'Dell Inc.' -AppDisplayName 'Dell SupportAssist for Business PCs';
# $SQLQuery = get-ProductQuery -AppPublisher 'M-Files Corporation' -AppDisplayName 'M-Files Online';


if( $SQLdataTable.Rows.Count -ge 1 ) {
    Write-Detail "We have $($SQLdataTable.Rows.Count) Rows in our dataset"

} else {

    Write-Detail "No product found.."
    Stop-Transcript
    Exit
}

# Filter by Product parameter if provided
if (-not [string]::IsNullOrEmpty($Product)) {
    Write-Detail "Filtering products by: '$Product'"
    $filteredTable = $SQLdataTable | Where-Object { $_.'Display Name' -like $Product }

    if ($filteredTable.Count -eq 0) {
        Write-Detail "WARNING: No products matched filter '$Product'"
        Write-Detail "Showing all $($SQLdataTable.Rows.Count) products for selection..."
        $CollectionsToCreate = $SQLdataTable | Out-GridView -Title "No matches for '$Product' - Select products to create collections for" -PassThru
    } else {
        Write-Detail "Found $($filteredTable.Count) product(s) matching filter"
        $CollectionsToCreate = $filteredTable | Out-GridView -Title "Products matching '$Product' - Select collections to create" -PassThru
    }
} else {
    # No product filter - show all
    $CollectionsToCreate = $SQLdataTable | Out-GridView -Title "Select only the collections you wish to create" -PassThru
}



# $CollectionsToCreate | Out-GridView 



    $UpdatedCollections = @();

    # Parse results
    $Colname            = @{name="Name";Expression={$_.'Collection/Rule Name' + ' - Current Installs' }}
    $RuleName           = @{name="RuleName";Expression={$_.'Collection/Rule Name'}}
    $RuleQuery          = @{name="RuleQry";Expression={$_.'WQL query'}}
    $UpdatedCollections += $CollectionsToCreate | Select-Object -Property $Colname, $RuleName, $RuleQuery 

    $Colname            = @{name="Name";Expression={$_.'Collection/Rule Name' + ' - Install' }}
    $RuleName           = @{name="RuleName";Expression={''}}
    $UpdatedCollections += $CollectionsToCreate | Select-Object -Property $Colname, $RuleName 

    $Colname            = @{name="Name";Expression={$_.'Collection/Rule Name' + ' - UnInstall' }}
    $RuleName           = @{name="RuleName";Expression={''}}
    $UpdatedCollections += $CollectionsToCreate | Select-Object -Property $Colname, $RuleName 


    # Validate and sanitize collection names
    $validatedCollections = @()
    $nameIssues = @()

    foreach ($ColCheck in $UpdatedCollections) {
        $validation = Test-CollectionName -Name $ColCheck.Name

        if (-not $validation.IsValid) {
            Write-Detail "WARNING: Name validation issue: $($validation.Message)"
            Write-Detail "  Original: `"$($ColCheck.Name)`""
            Write-Detail "  Sanitized: `"$($validation.SanitizedName)`""

            $nameIssues += [PSCustomObject]@{
                Original = $ColCheck.Name
                Sanitized = $validation.SanitizedName
                Issue = $validation.Message
            }

            # Update the collection name with sanitized version
            $ColCheck.Name = $validation.SanitizedName
        }

        $validatedCollections += $ColCheck
    }

    # Show name issues if any were found
    if ($nameIssues.Count -gt 0) {
        Write-Host ""
        Write-Detail "WARNING: The following collection names had issues and were sanitized:"
        $nameIssues | Out-GridView -Title "Collection Name Issues - Review Sanitized Names" -Wait
    }

    $UpdatedCollections = $validatedCollections | Sort-Object Name | Out-GridView  -Title "Select only the collections you wish to create" -PassThru

    # Deduplicate collections by name
    Write-Host ""
    Write-Detail "Checking for duplicate collection names..."
    $beforeCount = $UpdatedCollections.Count
    $duplicates = @()
    $seenNames = @{}
    $deduplicatedCollections = @()

    foreach ($col in $UpdatedCollections) {
        if ($seenNames.ContainsKey($col.Name)) {
            # This is a duplicate
            $duplicates += [PSCustomObject]@{
                Name = $col.Name
                RuleName = $col.RuleName
            }
            Write-Detail "  Skipping duplicate: `"$($col.Name)`""
        } else {
            # First occurrence, keep it
            $seenNames[$col.Name] = $true
            $deduplicatedCollections += $col
        }
    }

    if ($duplicates.Count -gt 0) {
        Write-Host ""
        Write-Detail "WARNING: Found $($duplicates.Count) duplicate collection name(s) that were removed"
        Write-Detail "Original count: $beforeCount | Deduplicated count: $($deduplicatedCollections.Count)"
        $duplicates | Out-GridView -Title "Duplicate Collections Removed" -Wait
    } else {
        Write-Detail "No duplicate collection names found"
    }

    # Update the collection list with deduplicated version
    $UpdatedCollections = $deduplicatedCollections



# Get SCCM object from server..
$myServer = Connect-SCCMServer -HostName $gCMSServ -siteCode $gCMSourceSite -credential $myCred


Write-Detail "SCCM Server    `t$($myServer.Machine)"
Write-Detail "SCCM Namespace `t$($myServer.Namespace)"
Write-Detail "SCCM SccmProvider`t$($myServer.SccmProvider)"

# Get and select folder for collections
Write-Host ""
Write-Detail "Retrieving SCCM collection folders..."
$availableFolders = Get-SCCMCollectionFolders -SccmServer $myServer -credential $myCred
$selectedFolder = $availableFolders | Select-Object ContainerNodeID, Name, Path | Out-GridView -Title "Select folder for collections (or choose Root)" -OutputMode Single

if ($null -eq $selectedFolder) {
    Write-Detail "No folder selected, using root folder"
    $selectedFolder = $availableFolders | Where-Object { $_.ContainerNodeID -eq 0 }
} else {
    Write-Detail "Selected folder: $($selectedFolder.Path) [ID: $($selectedFolder.ContainerNodeID)]"
}

# Initialize tracking variables for summary
$createdCollections = @()
$existingCollections = @()
$addedRules = @()
$errors = @()

# Process the Collections

foreach ($bndCol in $UpdatedCollections) {
    # Collection
    $AddQueryToCollection = $true;
    $ColName = $bndcol.Name
    $colRuleName = $bndCol.RuleName
    $colRuleQry  = $bndCol.RuleQry


    $filter = "Name = '$ColName'"
    $CollectionsToUpdate = Get-SCCMObject -sccmServer $myServer -class SMS_Collection -Filter $Filter

    if ($CollectionsToUpdate.Name -like $ColName) {

            Write-Detail "Collection exists: `"$ColName`""
            $existingCollections += [PSCustomObject]@{
                Name = $ColName
                CollectionID = ""
                Action = "Already Exists"
            }

            Foreach ($TmoCollection in $CollectionsToUpdate) {

                $ColID = $TmoCollection.CollectionID.ToString();
                $TmoCollection.psBase.Get()
                Write-Detail "Rule count = $($TmoCollection.CollectionRules.Count)"

                # Update the tracking with actual collection ID
                $existingCollections[-1].CollectionID = $ColID

                if (   $TmoCollection.CollectionRules.Count -gt 0) {
                    # Already has rules
                    # $TmoCollection.CollectionRules.__CLASS
                    foreach ($tmpRule in $TmoCollection.CollectionRules) {

                                        # Continue if the rule is a query based rule
                    if ($tmpRule.__CLASS -eq "SMS_CollectionRuleQuery") {

                        # Get the query
                        $query = $tmpRule.queryExpression
                        Write-Detail "Found query rule called `"$($tmpRule.RuleName)`""
                        Write-Detail "Query `"$query`""

                        # Have existing query ?
                        $AddQueryToCollection = $false;

                    }
                        



<#
    ExcludeCollectionID Property      string ExcludeCollectionID {get;set;}
    RuleName            Property      string RuleName {get;set;}
    
    
    QueryExpression  Property      string QueryExpression {get;set;}
    QueryID          Property      uint32 QueryID {get;set;}        
    RuleName         Property      string RuleName {get;set;}       
    
           
#>
                    }  # Collection Rules


                } else {

                    Write-Detail "No Rules exist for for `"$($TmoCollection.Name)`" [$ColID] - `"$colRuleName`""

                    if ([string]::IsNullOrEmpty($colRuleQry)  -eq $True) {
                        Write-Detail "No Rule for collection."

                    } else {
                        write-Detail "Creating rule for `"$($TmoCollection.Name)`" [$ColID] - `"$colRuleName`""
                        try {
                            Add-SCCMCollectionRule -Server $myServer -collectionID $ColID -queryExpression $colRuleQry -queryRuleName $colRuleName -Verbose
                            write-Detail "Added rule to `"$($TmoCollection.Name)`""
                            $numADDRule++
                            $addedRules += [PSCustomObject]@{
                                CollectionName = $TmoCollection.Name
                                CollectionID = $ColID
                                RuleName = $colRuleName
                            }
                        }
                        catch {
                            Write-Detail "ERROR: Failed to add rule: $($_.Exception.Message)"
                            $errors += "Failed to add rule to $($TmoCollection.Name): $($_.Exception.Message)"
                        }
                    }
                    # Created New collection Rule
                    $AddQueryToCollection = $false;

                }


                if( $AddQueryToCollection -and  ($ColID -like  "$($gCMSourceSite)?????") ) {

                    # Add-SCCMCollectionRule -Server $myServer -collectionID $ColID -queryExpression "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.SecurityGroupName like `"DOMAIN\\PROJ_EOL_$dateVal`"" -queryRuleName "Members of ad Group DOMAIN\\PROJ_EOL_$dateVal" -Verbose

                    if ([string]::IsNullOrEmpty($colRuleQry)  -eq $True) {
                        Write-Detail "No Rule for collection."

                    } else {
                        write-Detail "Creating rule for `"$($TmoCollection.Name)`" [$ColID] - `"$colRuleName`""
                        try {
                            Add-SCCMCollectionRule -Server $myServer -collectionID $ColID -queryExpression $colRuleQry -queryRuleName $colRuleName -Verbose
                            $numADDRule++
                            $addedRules += [PSCustomObject]@{
                                CollectionName = $TmoCollection.Name
                                CollectionID = $ColID
                                RuleName = $colRuleName
                            }
                            write-Detail "Added rule to `"$($TmoCollection.Name)`""
                        }
                        catch {
                            Write-Detail "ERROR: Failed to add rule: $($_.Exception.Message)"
                            $errors += "Failed to add rule to $($TmoCollection.Name): $($_.Exception.Message)"
                        }
                    }
                }


            }



        } else {

            Write-Detail "Creating the collection `"$ColName`""

            try {
                $newCollection = New-SCCMCollection -SccmServer $myServer -name $ColName -parentCollectionID 'SMS00001' -refreshDays 7 -Verbose
                if ($newCollection.Count -gt 1) {
                    $newCollection = $newCollection[1]
                    $numNew++
                }

                [VOID]$newCollection.psBase.Get();
                $ColID = $newCollection.CollectionID.ToString();

                Write-Detail "Successfully created collection [$ColID]"

                # Move collection to selected folder
                if ($selectedFolder.ContainerNodeID -ne 0) {
                    Write-Detail "Moving collection to folder `"$($selectedFolder.Name)`"..."
                    $moveResult = Move-SCCMCollectionToFolder -SccmServer $myServer -CollectionID $ColID -FolderID $selectedFolder.ContainerNodeID -credential $myCred
                    if ($moveResult) {
                        Write-Detail "Successfully moved to folder"
                    }
                }

                # Track the creation
                $createdCollections += [PSCustomObject]@{
                    Name = $ColName
                    CollectionID = $ColID
                    Folder = $selectedFolder.Name
                }

                # Add rule if present
                if ( $ColID -like "$($gCMSourceSite)?????"  ) {

                    if ([string]::IsNullOrEmpty($colRuleQry)  -eq $True) {
                        Write-Detail "No Rule for collection."

                    } else {
                        write-Detail "Creating rule for `"$($newCollection.Name)`" [$ColID] - `"$colRuleName`""
                        try {
                            Add-SCCMCollectionRule -Server $myServer -collectionID $ColID -queryExpression $colRuleQry -queryRuleName $colRuleName -Verbose
                            write-Detail "    > Added rule to `"$($newCollection.Name)`" - `"$colRuleName`""
                            $addedRules += [PSCustomObject]@{
                                CollectionName = $newCollection.Name
                                CollectionID = $ColID
                                RuleName = $colRuleName
                            }
                        }
                        catch {
                            Write-Detail "ERROR: Failed to add rule: $($_.Exception.Message)"
                            $errors += "Failed to add rule to $($newCollection.Name): $($_.Exception.Message)"
                        }
                    }
                }
            }
            catch {
                Write-Detail "ERROR: Failed to create collection `"$ColName`": $($_.Exception.Message)"
                $errors += "Failed to create collection $ColName`: $($_.Exception.Message)"
            }

        }



}

# Display Summary
Write-Host ""
Write-Host ""
Write-Detail "================================================================================"
Write-Detail "                            OPERATION SUMMARY                                   "
Write-Detail "================================================================================"
Write-Host ""

Write-Detail "Selected Folder: $($selectedFolder.Path) [ID: $($selectedFolder.ContainerNodeID)]"
Write-Host ""

if ($createdCollections.Count -gt 0) {
    Write-Detail "CREATED COLLECTIONS: $($createdCollections.Count)"
    foreach ($col in $createdCollections) {
        Write-Detail "  [+] $($col.CollectionID) - $($col.Name)"
        Write-Detail "      Folder: $($col.Folder)"
    }
    Write-Host ""
}

if ($existingCollections.Count -gt 0) {
    Write-Detail "EXISTING COLLECTIONS (Not Modified): $($existingCollections.Count)"
    foreach ($col in $existingCollections) {
        Write-Detail "  [=] $($col.CollectionID) - $($col.Name)"
    }
    Write-Host ""
}

if ($addedRules.Count -gt 0) {
    Write-Detail "RULES ADDED: $($addedRules.Count)"
    foreach ($rule in $addedRules) {
        Write-Detail "  [>] $($rule.CollectionID) - $($rule.CollectionName)"
        Write-Detail "      Rule: $($rule.RuleName)"
    }
    Write-Host ""
}

if ($errors.Count -gt 0) {
    Write-Detail "ERRORS ENCOUNTERED: $($errors.Count)"
    foreach ($error in $errors) {
        Write-Detail "  [!] $error"
    }
    Write-Host ""
}

Write-Detail "================================================================================"
Write-Detail "Summary:"
Write-Detail "  - Created: $($createdCollections.Count) collections"
Write-Detail "  - Existing: $($existingCollections.Count) collections"
Write-Detail "  - Rules Added: $($addedRules.Count)"
Write-Detail "  - Errors: $($errors.Count)"
Write-Detail "================================================================================"
Write-Host ""

Write-Detail "Logs : `"$logFile`""

Stop-Transcript


