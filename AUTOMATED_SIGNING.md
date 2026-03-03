# Automated Code Signing with GitHub Actions

This guide explains how to set up automated code signing for PowerShell scripts using GitHub Actions and cloud-based signing services.

---

## Table of Contents
1. [Why Automate Signing?](#why-automate-signing)
2. [Signing Service Options](#signing-service-options)
3. [GitHub Actions + Traditional Certificate](#github-actions--traditional-certificate)
4. [Azure Code Signing (Cloud-Based)](#azure-code-signing-cloud-based)
5. [SignPath.io (Free for Open Source)](#signpathio-free-for-open-source)
6. [Comparison Table](#comparison-table)
7. [Best Practices](#best-practices)

---

## Why Automate Signing?

**Benefits of automated signing:**
- ✅ **Security** - Certificate private keys never leave secure storage
- ✅ **Consistency** - Every release is signed automatically
- ✅ **Scalability** - Works for teams without sharing certificates
- ✅ **Audit Trail** - All signing operations logged
- ✅ **No Local Setup** - Developers don't need certificates installed
- ✅ **CI/CD Integration** - Sign as part of release process

**Manual signing problems:**
- ❌ Certificate sharing security risks
- ❌ Human error (forgetting to sign)
- ❌ Local machine dependency
- ❌ Hard to revoke access
- ❌ No central audit log

---

## Signing Service Options

### Option 1: GitHub Actions + Traditional Certificate

**Best for:** Small teams, existing certificates

**Pros:**
- ✅ Use existing code signing certificates
- ✅ No additional service costs
- ✅ Full control over certificate

**Cons:**
- ❌ Certificate stored in GitHub Secrets (encrypted but still stored)
- ❌ Manual certificate renewal
- ❌ No hardware security module (HSM)

**Cost:** Free (certificate cost only: $200-500/year)

---

### Option 2: Azure Code Signing (Microsoft)

**Best for:** Enterprise/Microsoft ecosystem

**Pros:**
- ✅ Hardware security module (HSM) backed
- ✅ Enterprise-grade security
- ✅ Azure integration
- ✅ Managed certificate lifecycle

**Cons:**
- ❌ Requires Azure subscription
- ❌ More complex setup
- ❌ Higher cost

**Cost:**
- Azure Code Signing: ~$10/month
- Certificate: Included in service

**More Info:** [Azure Trusted Signing Docs](https://learn.microsoft.com/azure/trusted-signing/)

---

### Option 3: SignPath.io (Cloud Service)

**Best for:** Open source projects, small teams

**Pros:**
- ✅ **FREE for open source projects**
- ✅ Purpose-built for code signing
- ✅ Easy GitHub Actions integration
- ✅ HSM-backed certificates
- ✅ Built-in approval workflows

**Cons:**
- ❌ Third-party service dependency
- ❌ Limited to specific signing policies

**Cost:**
- Open Source: **FREE**
- Commercial: Starting at $99/month

**More Info:** [SignPath.io](https://about.signpath.io/)

---

## GitHub Actions + Traditional Certificate

### Setup Steps

#### 1. Export Your Certificate

Export your code signing certificate as a PFX file with password:

```powershell
# Export certificate (interactive password prompt)
$cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.HasPrivateKey -and $_.EnhancedKeyUsageList -like "*Code Signing*" }
Export-PfxCertificate -Cert $cert -FilePath "CodeSigningCert.pfx" -Password (Read-Host -AsSecureString -Prompt "Enter password")
```

#### 2. Encode Certificate to Base64

```powershell
# Convert PFX to base64 string
$certBytes = [System.IO.File]::ReadAllBytes("CodeSigningCert.pfx")
$certBase64 = [System.Convert]::ToBase64String($certBytes)
$certBase64 | Set-Clipboard  # Copy to clipboard
Write-Host "Certificate base64 string copied to clipboard"
```

#### 3. Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add two secrets:

| Secret Name | Value |
|-------------|-------|
| `CODE_SIGNING_CERT` | Base64-encoded PFX file (from step 2) |
| `CODE_SIGNING_PASSWORD` | PFX file password |

**Security Note:** These secrets are encrypted and only accessible to GitHub Actions.

#### 4. Enable the Workflow

The workflow is in `.github/workflows/sign-scripts.yml`

**Triggers:**
- **Automatic:** On every release
- **Manual:** Via workflow dispatch

**Manual trigger:**
```bash
# Via GitHub UI: Actions → Sign PowerShell Scripts → Run workflow

# Via GitHub CLI
gh workflow run sign-scripts.yml -f scripts="all"
gh workflow run sign-scripts.yml -f scripts="Add-WeektoSignature.ps1,Upload-ToLiquidFiles.ps1"
```

#### 5. Create a Release

```bash
# Tag and create release
git tag v1.0.0
git push origin v1.0.0

# Or via GitHub UI: Releases → Draft a new release
```

The workflow will automatically:
1. Decode certificate from secret
2. Import to certificate store
3. Sign all PowerShell scripts
4. Verify signatures
5. Commit signed scripts back to repository
6. Upload signed scripts as artifacts

---

## Azure Code Signing (Cloud-Based)

### Prerequisites

- Azure subscription
- Azure Code Signing service enabled
- Certificate created in Azure

### Setup Steps

#### 1. Create Azure Code Signing Service

```bash
# Via Azure CLI
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource group
az group create --name rg-code-signing --location eastus

# Create Azure Code Signing account
az codesigning account create \
  --resource-group rg-code-signing \
  --name my-code-signing \
  --location eastus \
  --sku Basic

# Create certificate profile
az codesigning certificate-profile create \
  --resource-group rg-code-signing \
  --account-name my-code-signing \
  --profile-name PowerShellScripts \
  --profile-type PublicTrust
```

#### 2. Create Service Principal

```bash
# Create service principal for GitHub Actions
az ad sp create-for-rbac \
  --name "GitHub-Actions-CodeSigning" \
  --role "Code Signing Certificate User" \
  --scopes /subscriptions/{subscription-id}/resourceGroups/rg-code-signing \
  --sdk-auth
```

Save the output JSON - you'll need these values.

#### 3. Add GitHub Secrets

| Secret Name | Value | Source |
|-------------|-------|--------|
| `AZURE_TENANT_ID` | Tenant ID | Service principal JSON |
| `AZURE_CLIENT_ID` | App ID | Service principal JSON |
| `AZURE_CLIENT_SECRET` | Password | Service principal JSON |
| `AZURE_CODE_SIGNING_ENDPOINT` | Endpoint URL | Azure Code Signing account |
| `AZURE_CODE_SIGNING_PROFILE` | Profile name | Certificate profile name |

#### 4. Enable Workflow

The workflow is in `.github/workflows/sign-azure-code-signing.yml`

**Triggers:**
- On releases
- Manual workflow dispatch

#### 5. Run Workflow

```bash
# Via GitHub CLI
gh workflow run sign-azure-code-signing.yml
```

**Benefits:**
- ✅ Private keys never leave Azure HSM
- ✅ Enterprise-grade security
- ✅ Automated certificate renewal
- ✅ Compliance-ready audit logs

---

## SignPath.io (Free for Open Source)

### Setup Steps

#### 1. Create SignPath.io Account

1. Go to [SignPath.io](https://about.signpath.io/)
2. Sign up for free open source account
3. Verify your GitHub repository is public

#### 2. Create SignPath.io Project

1. Log in to SignPath.io
2. Create new project for your repository
3. Note your:
   - **Organization ID**
   - **Project Slug**

#### 3. Create API Token

1. In SignPath.io: Settings → API Tokens
2. Create new token with **Submit Signing Request** permission
3. Copy the token value

#### 4. Add GitHub Secrets

| Secret Name | Value |
|-------------|-------|
| `SIGNPATH_API_TOKEN` | API token from step 3 |
| `SIGNPATH_ORGANIZATION_ID` | Your organization ID |
| `SIGNPATH_PROJECT_SLUG` | Your project slug |

#### 5. Configure SignPath.io Signing Policy

In SignPath.io project settings, create a signing policy:

```yaml
# Example signing policy
name: release-signing
description: Sign PowerShell scripts for releases

artifact-configuration:
  kind: powershell-script-collection

origin-verification:
  github:
    repository: YourUsername/PSCode
    allowed-branches:
      - main
    allowed-tags:
      - v*
```

#### 6. Enable Workflow

The workflow is in `.github/workflows/sign-signpath.yml`

**Triggers:**
- On releases
- Manual workflow dispatch

**Benefits:**
- ✅ **Completely FREE for open source**
- ✅ Professional-grade signing
- ✅ Easy GitHub integration
- ✅ Built-in approval workflows
- ✅ HSM-backed certificates included

---

## Comparison Table

| Feature | GitHub Actions + Cert | Azure Code Signing | SignPath.io |
|---------|----------------------|-------------------|-------------|
| **Cost (Open Source)** | $200-500/year | ~$10/month + cert | **FREE** |
| **Setup Complexity** | ⭐⭐ Easy | ⭐⭐⭐⭐ Complex | ⭐⭐⭐ Moderate |
| **Security** | Good (encrypted secrets) | Excellent (HSM) | Excellent (HSM) |
| **Certificate Management** | Manual | Managed | Managed |
| **Private Key Storage** | GitHub (encrypted) | Azure HSM | SignPath HSM |
| **Audit Logging** | GitHub Actions logs | Azure Monitor | SignPath dashboard |
| **CI/CD Integration** | Native | Good | Excellent |
| **Certificate Renewal** | Manual | Automatic | Automatic |
| **Team Access Control** | GitHub permissions | Azure RBAC | SignPath policies |
| **Approval Workflows** | ❌ No | Limited | ✅ Yes |

**Recommendation:**
- **Open Source Projects**: Use **SignPath.io** (free!)
- **Enterprise/Large Teams**: Use **Azure Code Signing**
- **Small Teams/Existing Cert**: Use **GitHub Actions + Traditional Certificate**

---

## Workflow Files Reference

### `.github/workflows/sign-scripts.yml`
**Traditional certificate signing**
- Uses certificate stored in GitHub Secrets
- Signs on releases or manual trigger
- Commits signed scripts back to repository

### `.github/workflows/sign-azure-code-signing.yml`
**Azure Code Signing integration**
- Uses Azure-hosted HSM certificates
- Service principal authentication
- Enterprise-grade security

### `.github/workflows/sign-signpath.yml`
**SignPath.io cloud signing**
- FREE for open source
- HSM-backed certificates included
- Built-in approval workflows

---

## Best Practices

### 1. Secret Management
- ✅ Use GitHub Secrets for sensitive data
- ✅ Rotate secrets regularly
- ✅ Limit secret access to specific workflows
- ❌ Never commit secrets to repository
- ❌ Never log secret values

### 2. Signing Workflow
- ✅ Sign only on releases/tags
- ✅ Verify signatures after signing
- ✅ Upload signed artifacts
- ✅ Tag commits with signed scripts
- ❌ Don't sign every commit (performance)

### 3. Certificate Lifecycle
- ✅ Monitor certificate expiration
- ✅ Plan renewal 30-60 days ahead
- ✅ Test new certificates before rotation
- ✅ Keep backup certificates secure
- ❌ Don't wait until expiration day

### 4. Security
- ✅ Use branch protection rules
- ✅ Require code review before merge
- ✅ Enable two-factor authentication
- ✅ Audit GitHub Actions logs
- ❌ Don't share certificates between projects

### 5. Testing
- ✅ Test signing workflow in fork first
- ✅ Verify signatures on different machines
- ✅ Test with different execution policies
- ✅ Validate timestamp server accessibility
- ❌ Don't test with production certificates

---

## Troubleshooting

### "Certificate not found in secrets"

**Solution:**
```bash
# Re-encode and update secret
$certBytes = [System.IO.File]::ReadAllBytes("cert.pfx")
$certBase64 = [System.Convert]::ToBase64String($certBytes)
# Update CODE_SIGNING_CERT secret with new value
```

### "Invalid password"

**Solution:**
- Verify password secret matches PFX password
- Check for extra spaces/newlines in secret value
- Re-export certificate with new password

### "Timestamp server timeout"

**Solution:**
- Check GitHub Actions runner internet connectivity
- Try alternate timestamp server:
  ```yaml
  -TimestampServer "http://timestamp.digicert.com"
  ```
- Implement retry logic

### "Signature verification failed"

**Solution:**
```powershell
# Manually verify signature
Get-AuthenticodeSignature -FilePath "script.ps1"

# Check certificate trust chain
$sig = Get-AuthenticodeSignature -FilePath "script.ps1"
$sig.SignerCertificate | Format-List *
```

### Azure Code Signing: "Access Denied"

**Solution:**
- Verify service principal has correct role
- Check subscription is active
- Confirm certificate profile exists
- Review Azure RBAC permissions

### SignPath.io: "Signing request rejected"

**Solution:**
- Check signing policy matches your workflow
- Verify branch/tag permissions
- Review SignPath.io project settings
- Check API token permissions

---

## Migration Path

### From Manual to Automated Signing

**Phase 1: Setup (Week 1)**
1. Choose signing service
2. Create accounts/resources
3. Configure GitHub Secrets
4. Test workflow in fork

**Phase 2: Testing (Week 2)**
1. Run workflow manually
2. Verify signatures
3. Test signed scripts on multiple machines
4. Document any issues

**Phase 3: Production (Week 3)**
1. Enable workflow on main repository
2. Create test release
3. Verify automated signing
4. Update documentation

**Phase 4: Transition (Week 4)**
1. Communicate change to team
2. Revoke old certificate access
3. Monitor first few releases
4. Gather feedback

---

## Additional Resources

### Documentation
- [GitHub Actions: Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Azure Code Signing](https://learn.microsoft.com/azure/trusted-signing/)
- [SignPath.io Docs](https://about.signpath.io/documentation/)
- [PowerShell Signing](https://docs.microsoft.com/powershell/module/microsoft.powershell.security/set-authenticodesignature)

### Tools
- [GitHub CLI](https://cli.github.com/) - Manage workflows from command line
- [Azure CLI](https://docs.microsoft.com/cli/azure/) - Azure resource management
- [SignPath GitHub Action](https://github.com/signpath/github-action-submit-signing-request)

### Community
- [GitHub Actions Community](https://github.community/c/github-actions/41)
- [PowerShell Gallery](https://www.powershellgallery.com/) - Published signed modules
- [SignPath Community](https://community.signpath.io/)

---

## Summary

**Quick Start:**

1. **Choose your approach:**
   - Open source? → **SignPath.io** (FREE)
   - Enterprise? → **Azure Code Signing**
   - Existing cert? → **GitHub Actions**

2. **Set up GitHub Secrets**
   - Certificate or API credentials
   - Test in fork first

3. **Enable workflow**
   - Choose appropriate workflow file
   - Trigger manually to test

4. **Create release**
   - Scripts automatically signed
   - Verified and committed back

**Next Steps:**
- Review workflow files in `.github/workflows/`
- Set up GitHub Secrets
- Test signing workflow
- Create first automated release

---

*Last Updated: 2026-02-05*
*Maintained by: PSCode Repository*
