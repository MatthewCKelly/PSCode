<#
.SYNOPSIS
    Signs PowerShell scripts with a code signing certificate
.DESCRIPTION
    This script helps sign PowerShell scripts for execution in environments
    that require script signing (e.g., AllSigned execution policy).

    Supports both self-signed certificates (for testing) and commercial
    certificates from trusted Certificate Authorities.
.PARAMETER ScriptPath
    Path to the PowerShell script(s) to sign. Supports wildcards.
.PARAMETER CertificateThumbprint
    Thumbprint of the certificate to use for signing
.PARAMETER CreateSelfSigned
    Creates a self-signed code signing certificate for testing
.PARAMETER TimeStampServer
    URL of timestamp server to use (default: Sectigo)
.EXAMPLE
    .\Sign-PowerShellScript.ps1 -CreateSelfSigned
    Creates a new self-signed certificate
.EXAMPLE
    .\Sign-PowerShellScript.ps1 -ScriptPath "Add-WeektoSignature.ps1" -CertificateThumbprint "ABC123..."
    Signs a single script with specified certificate
.EXAMPLE
    .\Sign-PowerShellScript.ps1 -ScriptPath "*.ps1"
    Signs all PS1 files in current directory
.NOTES
    Author: Claude AI
    Version: 1.0

    IMPORTANT: Self-signed certificates are only trusted on the machine where
    they are created. For production/distribution, use a certificate from a
    trusted CA (DigiCert, Sectigo, etc.)
#>

[CmdletBinding(DefaultParameterSetName='Sign')]
param(
    [Parameter(ParameterSetName='Sign', Mandatory=$true)]
    [string]$ScriptPath,

    [Parameter(ParameterSetName='Sign')]
    [string]$CertificateThumbprint,

    [Parameter(ParameterSetName='CreateCert')]
    [switch]$CreateSelfSigned,

    [Parameter(ParameterSetName='Sign')]
    [string]$TimeStampServer = "http://timestamp.sectigo.com"
)

#region Helper Functions

Function Write-Detail {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor White -BackgroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Black -BackgroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Debug'   { Write-Host $logEntry -ForegroundColor Gray }
        default   { Write-Host $logEntry }
    }
}

Function New-SelfSignedCodeSigningCert {
    <#
    .SYNOPSIS
        Creates a self-signed code signing certificate
    .DESCRIPTION
        Creates a self-signed certificate in the user's certificate store
        and exports it for installation on other machines if needed
    #>

    Write-Detail -Message "Creating self-signed code signing certificate..." -Level Info

    try {
        # Create the certificate
        $cert = New-SelfSignedCertificate `
            -Subject "CN=PowerShell Code Signing - $env:USERNAME" `
            -Type CodeSigningCert `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -NotAfter (Get-Date).AddYears(5) `
            -KeyUsage DigitalSignature `
            -KeyAlgorithm RSA `
            -KeyLength 2048

        Write-Detail -Message "Certificate created successfully!" -Level Success
        Write-Detail -Message "Thumbprint: $($cert.Thumbprint)" -Level Info
        Write-Detail -Message "Subject: $($cert.Subject)" -Level Info
        Write-Detail -Message "Valid until: $($cert.NotAfter)" -Level Info

        # Copy to Trusted Root (required for self-signed certs)
        $store = Get-Item "Cert:\CurrentUser\Root"
        $store.Open("ReadWrite")
        $store.Add($cert)
        $store.Close()

        Write-Detail -Message "Certificate added to Trusted Root store" -Level Success

        # Export certificate (without private key) for sharing
        $exportPath = Join-Path $PSScriptRoot "CodeSigningCert_$($cert.Thumbprint.Substring(0,8)).cer"
        Export-Certificate -Cert $cert -FilePath $exportPath | Out-Null

        Write-Detail -Message "Certificate exported to: $exportPath" -Level Success
        Write-Detail -Message "You can share this .cer file to trust scripts on other machines" -Level Info

        Write-Host ""
        Write-Detail -Message "To sign scripts, use:" -Level Info
        Write-Host "    .\Sign-PowerShellScript.ps1 -ScriptPath 'YourScript.ps1' -CertificateThumbprint '$($cert.Thumbprint)'" -ForegroundColor Cyan

        return $cert

    } catch {
        Write-Detail -Message "Failed to create certificate: $($_.Exception.Message)" -Level Error
        return $null
    }
}

Function Get-CodeSigningCertificates {
    <#
    .SYNOPSIS
        Lists available code signing certificates
    #>

    Write-Detail -Message "Searching for code signing certificates..." -Level Info

    # Check CurrentUser\My store
    $certs = Get-ChildItem -Path "Cert:\CurrentUser\My" -CodeSigningCert -ErrorAction SilentlyContinue

    if ($certs) {
        Write-Host ""
        Write-Detail -Message "Found $($certs.Count) code signing certificate(s):" -Level Success
        Write-Host ""

        foreach ($cert in $certs) {
            $status = if ($cert.NotAfter -lt (Get-Date)) { "EXPIRED" } else { "Valid" }
            $statusColor = if ($status -eq "Valid") { "Green" } else { "Red" }

            Write-Host "  Thumbprint: " -NoNewline
            Write-Host $cert.Thumbprint -ForegroundColor Cyan
            Write-Host "  Subject:    $($cert.Subject)"
            Write-Host "  Issuer:     $($cert.Issuer)"
            Write-Host "  Expires:    $($cert.NotAfter)" -NoNewline
            Write-Host " [$status]" -ForegroundColor $statusColor
            Write-Host ""
        }

        return $certs
    } else {
        Write-Detail -Message "No code signing certificates found" -Level Warning
        Write-Host ""
        Write-Detail -Message "To create a self-signed certificate for testing, run:" -Level Info
        Write-Host "    .\Sign-PowerShellScript.ps1 -CreateSelfSigned" -ForegroundColor Cyan
        Write-Host ""

        return $null
    }
}

Function Sign-Script {
    param(
        [string]$Path,
        [string]$Thumbprint,
        [string]$TimestampUrl
    )

    try {
        # Get the certificate
        $cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$Thumbprint" -ErrorAction Stop

        if (-not $cert) {
            throw "Certificate with thumbprint $Thumbprint not found"
        }

        # Verify certificate is valid
        if ($cert.NotAfter -lt (Get-Date)) {
            throw "Certificate has expired on $($cert.NotAfter)"
        }

        if ($cert.NotBefore -gt (Get-Date)) {
            throw "Certificate is not yet valid (valid from $($cert.NotBefore))"
        }

        Write-Detail -Message "Signing: $Path" -Level Info
        Write-Detail -Message "Using certificate: $($cert.Subject)" -Level Debug

        # Sign the script
        $result = Set-AuthenticodeSignature -FilePath $Path -Certificate $cert -TimeStampServer $TimestampUrl -ErrorAction Stop

        if ($result.Status -eq 'Valid') {
            Write-Detail -Message "Successfully signed: $Path" -Level Success
        } else {
            throw "Signing failed with status: $($result.Status) - $($result.StatusMessage)"
        }

    } catch {
        Write-Detail -Message "Failed to sign $Path : $($_.Exception.Message)" -Level Error
    }
}

#endregion Helper Functions

#region Main Execution

Write-Detail -Message "PowerShell Script Signing Tool" -Level Info
Write-Host ""

# Handle CreateSelfSigned mode
if ($CreateSelfSigned) {
    $cert = New-SelfSignedCodeSigningCert

    if ($cert) {
        Write-Host ""
        Write-Detail -Message "Certificate creation complete!" -Level Success
        Write-Host ""
        Write-Detail -Message "IMPORTANT NOTES:" -Level Warning
        Write-Host "  • This is a SELF-SIGNED certificate - only trusted on THIS machine"
        Write-Host "  • For production use, obtain a certificate from a trusted CA (DigiCert, Sectigo, etc.)"
        Write-Host "  • To trust on other machines, install the exported .cer file in their Trusted Root store"
        Write-Host ""
    }

    exit 0
}

# Handle signing mode
if ($ScriptPath) {
    # List available certificates if no thumbprint provided
    if (-not $CertificateThumbprint) {
        $certs = Get-CodeSigningCertificates

        if (-not $certs) {
            exit 1
        }

        # If only one valid cert, offer to use it
        $validCerts = $certs | Where-Object { $_.NotAfter -gt (Get-Date) }

        if ($validCerts.Count -eq 1) {
            Write-Detail -Message "Using the only valid certificate found" -Level Info
            $CertificateThumbprint = $validCerts[0].Thumbprint
        } else {
            Write-Detail -Message "Please specify -CertificateThumbprint parameter" -Level Error
            exit 1
        }
    }

    # Resolve script paths (supports wildcards)
    $scripts = Get-ChildItem -Path $ScriptPath -Filter "*.ps1" -ErrorAction SilentlyContinue

    if (-not $scripts) {
        Write-Detail -Message "No PowerShell scripts found matching: $ScriptPath" -Level Error
        exit 1
    }

    Write-Detail -Message "Found $($scripts.Count) script(s) to sign" -Level Info
    Write-Host ""

    foreach ($script in $scripts) {
        Sign-Script -Path $script.FullName -Thumbprint $CertificateThumbprint -TimestampUrl $TimeStampServer
    }

    Write-Host ""
    Write-Detail -Message "Signing complete!" -Level Success

    # Verify signatures
    Write-Host ""
    Write-Detail -Message "Verifying signatures..." -Level Info

    foreach ($script in $scripts) {
        $sig = Get-AuthenticodeSignature -FilePath $script.FullName

        $statusColor = switch ($sig.Status) {
            'Valid' { 'Green' }
            'NotSigned' { 'Yellow' }
            default { 'Red' }
        }

        Write-Host "  $($script.Name): " -NoNewline
        Write-Host $sig.Status -ForegroundColor $statusColor
    }

    Write-Host ""
}

#endregion Main Execution
