# PowerShell Script Code Signing Guide

This guide explains how to sign PowerShell scripts in the PSCode repository for security and to meet execution policy requirements.

> **🚀 NEW: Automated Signing with GitHub Actions**
> For CI/CD pipelines and automated signing, see [AUTOMATED_SIGNING.md](AUTOMATED_SIGNING.md)
> • **FREE** for open source projects (SignPath.io)
> • Enterprise options with Azure Code Signing
> • No local certificate management required

---

## Signing Approaches

This repository supports **two signing methods**:

| Method | Best For | Guide |
|--------|----------|-------|
| **🤖 Automated (GitHub Actions)** | Teams, CI/CD, Open Source | [AUTOMATED_SIGNING.md](AUTOMATED_SIGNING.md) |
| **✋ Manual (Local)** | Personal use, Testing | This guide |

**Recommendation:** Use automated signing for production releases and manual signing for local development/testing.

---

## Table of Contents
1. [Why Sign Scripts?](#why-sign-scripts)
2. [Execution Policies](#execution-policies)
3. [Certificate Options](#certificate-options)
4. [Quick Start](#quick-start)
5. [Signing Scripts](#signing-scripts)
6. [Verifying Signatures](#verifying-signatures)
7. [Troubleshooting](#troubleshooting)

---

## Why Sign Scripts?

**Code signing provides:**
- ✅ **Authentication** - Verifies the script author
- ✅ **Integrity** - Ensures script hasn't been modified
- ✅ **Trust** - Allows execution in restricted environments
- ✅ **Compliance** - Meets enterprise security policies

**When you need signed scripts:**
- Running scripts with `AllSigned` execution policy
- Deploying scripts in enterprise environments
- Distributing scripts to other users/organizations
- Meeting security compliance requirements

---

## Execution Policies

PowerShell execution policies control which scripts can run:

| Policy | Description | Signature Required? |
|--------|-------------|---------------------|
| **Restricted** | No scripts run | N/A |
| **AllSigned** | Only signed scripts run | ✅ Yes |
| **RemoteSigned** | Local scripts run; remote scripts must be signed | Only for downloaded scripts |
| **Unrestricted** | All scripts run (with warnings) | ❌ No |
| **Bypass** | Nothing is blocked | ❌ No |

**Check your current policy:**
```powershell
Get-ExecutionPolicy -List
```

**Set execution policy (requires admin):**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Certificate Options

### Option 1: Self-Signed Certificate (Testing/Personal Use)

**Pros:**
- ✅ Free
- ✅ Quick to create
- ✅ Good for testing

**Cons:**
- ❌ Only trusted on your machine
- ❌ Not suitable for distribution
- ❌ Manual installation required on other machines

**Create self-signed certificate:**
```powershell
.\Sign-PowerShellScript.ps1 -CreateSelfSigned
```

### Option 2: Commercial Certificate (Production/Distribution)

**Pros:**
- ✅ Trusted across all machines
- ✅ Professional/enterprise standard
- ✅ Automatic trust chain

**Cons:**
- ❌ Costs $100-400/year
- ❌ Validation process required

**Recommended Certificate Authorities:**
- [DigiCert](https://www.digicert.com/code-signing/) - $469/year
- [Sectigo](https://sectigo.com/ssl-certificates-tls/code-signing) - $239/year
- [GlobalSign](https://www.globalsign.com/en/code-signing-certificate) - $249/year

**Certificate Requirements:**
- **Type:** Code Signing Certificate
- **Validation:** Organization Validation (OV) or Individual Validation
- **Key Length:** 2048-bit RSA minimum
- **Format:** PFX/P12 with private key

---

## Quick Start

### Step 1: Create or Obtain Certificate

**For Testing (Self-Signed):**
```powershell
# Create self-signed certificate
.\Sign-PowerShellScript.ps1 -CreateSelfSigned

# Note the thumbprint displayed
```

**For Production (Commercial CA):**
1. Purchase code signing certificate from CA
2. Complete validation process
3. Download and install PFX file
4. Import into `Cert:\CurrentUser\My` store:
   ```powershell
   $pfxPath = "C:\Path\To\Certificate.pfx"
   $pfxPassword = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
   Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\CurrentUser\My -Password $pfxPassword
   ```

### Step 2: List Available Certificates

```powershell
# List all code signing certificates
Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert

# Or use the signing tool
.\Sign-PowerShellScript.ps1 -ScriptPath "dummy.ps1"  # Will list certs if none specified
```

### Step 3: Sign Your Scripts

**Sign a single script:**
```powershell
.\Sign-PowerShellScript.ps1 -ScriptPath "Add-WeektoSignature.ps1" -CertificateThumbprint "ABC123DEF456..."
```

**Sign all scripts in directory:**
```powershell
.\Sign-PowerShellScript.ps1 -ScriptPath "*.ps1" -CertificateThumbprint "ABC123DEF456..."
```

**Sign with auto-detect (if only one valid cert):**
```powershell
.\Sign-PowerShellScript.ps1 -ScriptPath "Add-WeektoSignature.ps1"
```

---

## Signing Scripts

### Using Sign-PowerShellScript.ps1 Tool

The repository includes a signing tool that simplifies the process:

```powershell
# Show help
Get-Help .\Sign-PowerShellScript.ps1 -Full

# Create self-signed cert
.\Sign-PowerShellScript.ps1 -CreateSelfSigned

# Sign single script
.\Sign-PowerShellScript.ps1 -ScriptPath "Add-WeektoSignature.ps1" -CertificateThumbprint "THUMB"

# Sign multiple scripts
.\Sign-PowerShellScript.ps1 -ScriptPath "*.ps1" -CertificateThumbprint "THUMB"

# Use custom timestamp server
.\Sign-PowerShellScript.ps1 -ScriptPath "script.ps1" -CertificateThumbprint "THUMB" -TimeStampServer "http://timestamp.digicert.com"
```

### Manual Signing

```powershell
# Get certificate
$cert = Get-ChildItem -Path Cert:\CurrentUser\My\{THUMBPRINT}

# Sign script
Set-AuthenticodeSignature -FilePath "Add-WeektoSignature.ps1" -Certificate $cert -TimeStampServer "http://timestamp.sectigo.com"
```

### Timestamp Servers

**Why timestamp?**
- Signatures remain valid after certificate expires
- Proves when the script was signed

**Recommended timestamp servers:**
- Sectigo: `http://timestamp.sectigo.com`
- DigiCert: `http://timestamp.digicert.com`
- GlobalSign: `http://timestamp.globalsign.com/tsa/r6advanced1`
- Verisign: `http://timestamp.verisign.com/scripts/timstamp.dll`

---

## Verifying Signatures

### Check signature status:

```powershell
# Verify single script
Get-AuthenticodeSignature -FilePath "Add-WeektoSignature.ps1"

# Check all scripts
Get-ChildItem *.ps1 | Get-AuthenticodeSignature | Select-Object Path, Status, SignerCertificate
```

### Signature Status Values:

| Status | Meaning |
|--------|---------|
| **Valid** | ✅ Signature is valid and certificate is trusted |
| **NotSigned** | ⚠️ Script is not signed |
| **HashMismatch** | ❌ Script was modified after signing |
| **NotTrusted** | ❌ Certificate is not trusted (e.g., self-signed on different machine) |
| **UnknownError** | ❌ Other verification error |

### View signature details:

```powershell
$sig = Get-AuthenticodeSignature -FilePath "Add-WeektoSignature.ps1"

# Certificate details
$sig.SignerCertificate | Format-List Subject, Issuer, NotBefore, NotAfter, Thumbprint

# Timestamp details
$sig.TimeStamperCertificate
```

---

## Troubleshooting

### Issue: "Certificate not found"

**Solution:**
```powershell
# List available certificates
Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert

# Verify thumbprint is correct (no spaces or special characters)
```

### Issue: "Certificate has expired"

**Solution:**
- Obtain a new certificate
- For self-signed certs, create a new one with `-CreateSelfSigned`

### Issue: "NotTrusted" status on other machines (self-signed cert)

**Solution:**
1. Export certificate (without private key):
   ```powershell
   $cert = Get-ChildItem Cert:\CurrentUser\My\{THUMBPRINT}
   Export-Certificate -Cert $cert -FilePath "CodeSigningCert.cer"
   ```

2. On target machine, import to Trusted Root:
   ```powershell
   Import-Certificate -FilePath "CodeSigningCert.cer" -CertStoreLocation Cert:\CurrentUser\Root
   ```

### Issue: "HashMismatch" after signing

**Cause:** Script was modified after signing

**Solution:**
- Re-sign the script
- Never edit scripts after signing (sign as final step)

### Issue: Timestamp server timeout

**Solution:**
- Try a different timestamp server
- Check internet connection
- Skip timestamping (not recommended):
  ```powershell
  Set-AuthenticodeSignature -FilePath "script.ps1" -Certificate $cert
  ```

### Issue: "UnauthorizedAccess" when signing

**Solution:**
- Check file is not read-only: `(Get-Item "script.ps1").IsReadOnly`
- Ensure you have write permissions
- Close the script if it's open in an editor

---

## Best Practices

### 1. Sign Before Distribution
Always sign scripts immediately before distributing them.

### 2. Use Timestamps
Always include timestamp server to ensure signatures remain valid after certificate expires.

### 3. Protect Private Keys
- Never share certificates with private keys (.pfx files)
- Use strong passwords for PFX files
- Consider hardware security modules (HSM) for commercial use

### 4. Version Control
- **.gitignore** certificate files and private keys
- Sign scripts as part of release process, not development
- Keep unsigned versions in git

### 5. Renewal Process
- Set calendar reminders before certificate expires
- Renew 1-2 months before expiration
- Re-sign all distributed scripts with new certificate

### 6. Documentation
Document in README:
- That scripts are signed
- Where to get trusted certificates
- How users should verify signatures

---

## Scripts in This Repository

### Scripts to Sign for Distribution:

✅ **Recommended for signing:**
- `Add-WeektoSignature.ps1` - Main signature manager (1,900+ lines)
- `RssDownloadandStart-v2.ps1` - Torrent/Plex automation
- `Upload-ToLiquidFiles.ps1` - File upload utility
- `Test-LiquidFilesAccess.ps1` - API testing tool
- `Serial/CheckComm.ps1` - Serial communication tool
- `Sign-PowerShellScript.ps1` - This signing tool itself!

⚠️ **Not necessary:**
- Template/sample files (`.sample`, `.template`)
- Development/test scripts in `Dev/` folder

### Bulk Signing Command:

```powershell
# Sign all main scripts
$scripts = @(
    "Add-WeektoSignature.ps1",
    "RssDownloadandStart-v2.ps1",
    "Upload-ToLiquidFiles.ps1",
    "Test-LiquidFilesAccess.ps1",
    "Sign-PowerShellScript.ps1",
    "Serial/CheckComm.ps1"
)

foreach ($script in $scripts) {
    .\Sign-PowerShellScript.ps1 -ScriptPath $script -CertificateThumbprint "YOUR_THUMBPRINT"
}
```

---

## Additional Resources

### Microsoft Documentation
- [About Signing](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_signing)
- [Set-AuthenticodeSignature](https://docs.microsoft.com/powershell/module/microsoft.powershell.security/set-authenticodesignature)
- [Execution Policies](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies)

### Certificate Authorities
- [DigiCert Code Signing](https://www.digicert.com/code-signing/)
- [Sectigo Code Signing](https://sectigo.com/ssl-certificates-tls/code-signing)
- [GlobalSign Code Signing](https://www.globalsign.com/en/code-signing-certificate)

### Tools
- [Microsoft SignTool](https://docs.microsoft.com/windows/win32/seccrypto/signtool) - Alternative signing tool
- [DigiCert Certificate Utility](https://www.digicert.com/util/) - Certificate management

---

## Summary

**For Testing/Personal Use:**
```powershell
# 1. Create self-signed certificate
.\Sign-PowerShellScript.ps1 -CreateSelfSigned

# 2. Sign your scripts
.\Sign-PowerShellScript.ps1 -ScriptPath "*.ps1"
```

**For Production/Distribution:**
```powershell
# 1. Purchase certificate from CA (DigiCert, Sectigo, etc.)
# 2. Import PFX to certificate store
# 3. Sign scripts with timestamp
.\Sign-PowerShellScript.ps1 -ScriptPath "*.ps1" -CertificateThumbprint "YOUR_THUMB"
```

**Need Help?**
- Review this guide
- Check `Get-Help .\Sign-PowerShellScript.ps1 -Full`
- Open an issue on GitHub

---

*Last Updated: 2026-02-05*
