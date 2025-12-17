# Windows Proxy Settings - Comprehensive Test Plan

## Overview

This test plan covers all variations of Windows proxy settings as configured through:
- **Internet Properties → Connections → LAN Settings**
- **Settings → Network & Internet → Proxy**

The goal is to ensure our PowerShell scripts can correctly read and decode all proxy configuration scenarios stored in the Windows Registry at:
```
HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections
```

---

## Test Configuration Matrix

### 1. Basic Configuration States

| Test ID | Test Name | Configuration | Expected Behavior |
|---------|-----------|---------------|-------------------|
| TC-001 | Direct Connection Only | No proxy, no auto-config, no auto-detect | DirectConnection=True, ProxyEnabled=False, AutoConfigEnabled=False, AutoDetectEnabled=False |
| TC-002 | Auto-Detect Only | Only "Automatically detect settings" checked | DirectConnection=False, AutoDetectEnabled=True, ProxyEnabled=False |
| TC-003 | Auto-Config PAC Only | Only "Use automatic configuration script" with URL | DirectConnection=False, AutoConfigEnabled=True, AutoConfigURL set |
| TC-004 | Manual Proxy Only | Only "Use a proxy server" with single proxy | DirectConnection=False, ProxyEnabled=True, ProxyServer set |
| TC-005 | All Features Disabled | All checkboxes unchecked (edge case) | All flags False |

---

## 2. Manual Proxy Server Configurations

### 2.1 Single Proxy for All Protocols

| Test ID | Test Name | Configuration | Expected ProxyServer Value |
|---------|-----------|---------------|---------------------------|
| TC-101 | Simple Proxy IP:Port | "Use same proxy" checked<br>HTTP: `192.168.1.1:8080` | `192.168.1.1:8080` |
| TC-102 | Simple Proxy Hostname | "Use same proxy" checked<br>HTTP: `proxy.company.com:3128` | `proxy.company.com:3128` |
| TC-103 | Proxy No Port | "Use same proxy" checked<br>HTTP: `proxy.company.com` | `proxy.company.com` |
| TC-104 | Proxy with Non-Standard Port | "Use same proxy" checked<br>HTTP: `proxy.local:9999` | `proxy.local:9999` |
| TC-105 | IPv6 Proxy | "Use same proxy" checked<br>HTTP: `[2001:db8::1]:8080` | `[2001:db8::1]:8080` |

### 2.2 Protocol-Specific Proxies

| Test ID | Test Name | Configuration | Expected ProxyServer Value |
|---------|-----------|---------------|---------------------------|
| TC-201 | HTTP Only | "Use same proxy" **unchecked**<br>HTTP: `http-proxy:8080`<br>Others: empty | `http=http-proxy:8080` |
| TC-202 | HTTPS/Secure Only | "Use same proxy" **unchecked**<br>Secure: `secure-proxy:443`<br>Others: empty | `https=secure-proxy:443` |
| TC-203 | FTP Only | "Use same proxy" **unchecked**<br>FTP: `ftp-proxy:21`<br>Others: empty | `ftp=ftp-proxy:21` |
| TC-204 | SOCKS Only | "Use same proxy" **unchecked**<br>Socks: `socks-proxy:1080`<br>Others: empty | `socks=socks-proxy:1080` |
| TC-205 | All Protocols Different | "Use same proxy" **unchecked**<br>HTTP: `http-proxy:8080`<br>Secure: `https-proxy:8443`<br>FTP: `ftp-proxy:21`<br>Socks: `socks5:1080` | `http=http-proxy:8080;https=https-proxy:8443;ftp=ftp-proxy:21;socks=socks5:1080` |
| TC-206 | HTTP + HTTPS Only | "Use same proxy" **unchecked**<br>HTTP: `web-proxy:8080`<br>Secure: `secure:443`<br>FTP: empty<br>Socks: empty | `http=web-proxy:8080;https=secure:443` |
| TC-207 | Mixed with Shared Proxy | "Use same proxy" **unchecked**<br>HTTP: `proxy1:8080`<br>Secure: `proxy1:8080` (same as HTTP)<br>FTP: `ftpproxy:21` | `http=proxy1:8080;https=proxy1:8080;ftp=ftpproxy:21` |

---

## 3. Proxy Bypass / Exceptions Configurations

| Test ID | Test Name | Configuration | Expected ProxyBypass Value |
|---------|-----------|---------------|---------------------------|
| TC-301 | No Bypass List | Proxy enabled, exceptions empty | ProxyBypass empty or null |
| TC-302 | Bypass Local Addresses | "Bypass proxy server for local addresses" checked<br>Exceptions: empty | `<local>` |
| TC-303 | Single Domain Bypass | Exceptions: `*.company.com` | `*.company.com` |
| TC-304 | Multiple Domains | Exceptions: `*.company.com;*.internal.net;localhost` | `*.company.com;*.internal.net;localhost` |
| TC-305 | IP Address Bypass | Exceptions: `192.168.1.*;10.0.0.*` | `192.168.1.*;10.0.0.*` |
| TC-306 | Bypass with <local> | "Bypass local" checked<br>Exceptions: `*.company.com` | `*.company.com;<local>` |
| TC-307 | Complex Bypass List | "Bypass local" checked<br>Exceptions: `*.company.com;192.168.*;10.*;localhost;intranet` | `*.company.com;192.168.*;10.*;localhost;intranet;<local>` |
| TC-308 | CIDR Notation | Exceptions: `192.168.1.0/24` | `192.168.1.0/24` |
| TC-309 | Hostname Patterns | Exceptions: `*.local;*.internal;*.corp` | `*.local;*.internal;*.corp` |

---

## 4. Automatic Configuration Scenarios

### 4.1 Auto-Detect Settings

| Test ID | Test Name | Configuration | Expected Behavior |
|---------|-----------|---------------|-------------------|
| TC-401 | Auto-Detect Enabled | "Automatically detect settings" checked only | AutoDetectEnabled=True, AutoConfigEnabled=False |
| TC-402 | Auto-Detect + Proxy | Auto-detect checked<br>Manual proxy configured | AutoDetectEnabled=True, ProxyEnabled=True |
| TC-403 | Auto-Detect + PAC | Auto-detect checked<br>Auto-config URL set | AutoDetectEnabled=True, AutoConfigEnabled=True |

### 4.2 Automatic Configuration Script (PAC)

| Test ID | Test Name | Configuration | Expected AutoConfigURL |
|---------|-----------|---------------|------------------------|
| TC-501 | PAC HTTP URL | "Use automatic configuration script" checked<br>Address: `http://proxy.company.com/proxy.pac` | `http://proxy.company.com/proxy.pac` |
| TC-502 | PAC HTTPS URL | Address: `https://secure.company.com/wpad.dat` | `https://secure.company.com/wpad.dat` |
| TC-503 | PAC with Port | Address: `http://config.local:8080/proxy.pac` | `http://config.local:8080/proxy.pac` |
| TC-504 | PAC File URL | Address: `file:///C:/config/proxy.pac` | `file:///C:/config/proxy.pac` |
| TC-505 | PAC with Query Params | Address: `http://config.company.com:8082/proxy.pac?p=PARAMS` | `http://config.company.com:8082/proxy.pac?p=PARAMS` |
| TC-506 | PAC + Manual Proxy | PAC URL configured<br>Manual proxy also set | AutoConfigURL set, ProxyServer set, both flags true |

---

## 5. Combination Scenarios

| Test ID | Test Name | Configuration | Expected Result |
|---------|-----------|---------------|-----------------|
| TC-601 | Direct + Auto-Detect | Both enabled (unusual but possible) | DirectConnection=True, AutoDetectEnabled=True |
| TC-602 | Proxy + Auto-Detect | Manual proxy + auto-detect | ProxyEnabled=True, AutoDetectEnabled=True |
| TC-603 | Proxy + PAC | Manual proxy + auto-config URL | ProxyEnabled=True, AutoConfigEnabled=True |
| TC-604 | Auto-Detect + PAC | Both auto settings | AutoDetectEnabled=True, AutoConfigEnabled=True |
| TC-605 | All Enabled | Direct + Proxy + PAC + Auto-Detect | All flags True (testing edge case) |
| TC-606 | Proxy + PAC + Bypass | Manual proxy + PAC + exceptions | ProxyEnabled, AutoConfigEnabled, ProxyBypass all set |

---

## 6. Edge Cases and Special Scenarios

| Test ID | Test Name | Configuration | Purpose |
|---------|-----------|---------------|---------|
| TC-701 | Empty Proxy String | Proxy checkbox checked but no server entered | Test empty string handling |
| TC-702 | Proxy with Trailing Semicolon | ProxyServer: `proxy:8080;` | Test string cleanup |
| TC-703 | Bypass with Trailing Semicolon | ProxyBypass: `*.local;` | Test string cleanup |
| TC-704 | Very Long Bypass List | 50+ domains in bypass list | Test buffer handling |
| TC-705 | Very Long PAC URL | 500+ character URL | Test length limits |
| TC-706 | Unicode in Hostname | Proxy: `прокси.company.com:8080` | Test Unicode handling |
| TC-707 | Special Chars in Bypass | Exceptions: `test&co.com;test+plus.net` | Test special character handling |
| TC-708 | Whitespace Handling | Proxy: ` proxy.local:8080 ` (leading/trailing spaces) | Test trimming |
| TC-709 | Multiple Semicolons | ProxyBypass: `*.local;;*.internal;;;localhost` | Test delimiter cleanup |
| TC-710 | Mixed Case Protocol | ProxyServer: `HTTP=proxy:8080;HTTPS=secure:443` | Test case sensitivity |

---

## 7. Registry Value Types and Versions

| Test ID | Test Name | Configuration | Purpose |
|---------|-----------|---------------|---------|
| TC-801 | Version/Counter Increment | Make change, export, make another change, export | Verify version counter increments |
| TC-802 | Fresh Install State | Clean registry (no prior settings) | Test default/empty state |
| TC-803 | Legacy Settings Migration | Import old format registry settings | Test backward compatibility |
| TC-804 | Corrupted Binary Data | Manually create malformed registry entry | Test error handling |
| TC-805 | Minimal Binary Size | Smallest valid DefaultConnectionSettings | Test minimum structure |
| TC-806 | Maximum Binary Size | Largest possible configuration | Test buffer limits |

---

## 8. Windows Version Variations

| Test ID | Test Name | OS Version | Purpose |
|---------|-----------|------------|---------|
| TC-901 | Windows 10 (1909) | Export from Win10 1909 | Version-specific format |
| TC-902 | Windows 10 (21H2) | Export from Win10 21H2 | Version-specific format |
| TC-903 | Windows 11 (22H2) | Export from Win11 22H2 | Version-specific format |
| TC-904 | Windows Server 2019 | Export from Server 2019 | Server edition format |
| TC-905 | Windows Server 2022 | Export from Server 2022 | Server edition format |

---

## Test Execution Plan

### Phase 1: Basic Configurations (TC-001 to TC-005)
**Priority:** HIGH
**Goal:** Ensure fundamental direct/proxy/auto-config states work

**Steps:**
1. Configure each basic state in Windows proxy settings
2. Export registry: `reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" TC-00X.reg`
3. Run decoder script: `.\Read-ProxyRegistryFiles.ps1`
4. Verify flags match expected values
5. Document actual binary structure

**Success Criteria:**
- All 5 basic states decode correctly
- Flags match expected boolean values
- No parsing errors or warnings

---

### Phase 2: Manual Proxy Configurations (TC-101 to TC-207)
**Priority:** HIGH
**Goal:** Cover single and multi-protocol proxy scenarios

**Steps for TC-101 to TC-105 (Single Proxy):**
1. Open Internet Properties → LAN Settings
2. Check "Use a proxy server for your LAN"
3. Click "Advanced" button
4. **Ensure** "Use the same proxy server for all protocols" **IS CHECKED**
5. Enter proxy address in "HTTP" field
6. Export registry to `TC-10X.reg`
7. Test with decoder

**Steps for TC-201 to TC-207 (Protocol-Specific):**
1. Open Advanced proxy settings
2. **UNCHECK** "Use the same proxy server for all protocols"
3. Enter different proxies for each protocol as specified
4. Export registry to `TC-20X.reg`
5. Test with decoder

**Success Criteria:**
- Single proxy configurations show simple `host:port` format
- Multi-protocol shows `protocol=host:port;protocol=host:port` format
- All protocol separators parsed correctly

---

### Phase 3: Proxy Bypass Lists (TC-301 to TC-309)
**Priority:** MEDIUM
**Goal:** Test exception/bypass list parsing

**Steps:**
1. Configure manual proxy
2. Click "Advanced" button
3. In "Exceptions" field, enter bypass patterns
4. Check/uncheck "Bypass proxy server for local addresses"
5. Export registry to `TC-30X.reg`
6. Test with decoder

**Success Criteria:**
- Bypass list parses correctly with semicolon separators
- `<local>` appears when local bypass is checked
- Wildcard patterns preserved
- No extra delimiters or whitespace

---

### Phase 4: Automatic Configuration (TC-401 to TC-506)
**Priority:** MEDIUM
**Goal:** Test PAC and auto-detect scenarios

**Steps for Auto-Detect (TC-401 to TC-403):**
1. Check "Automatically detect settings"
2. Combine with other settings as specified
3. Export registry
4. Verify `AutoDetectEnabled` flag

**Steps for PAC URL (TC-501 to TC-506):**
1. Check "Use automatic configuration script"
2. Enter various PAC URL formats
3. Export registry
4. Verify `AutoConfigURL` extracted correctly

**Success Criteria:**
- Auto-detect flag decodes correctly
- PAC URLs extracted with full path and parameters
- Combined scenarios parse both settings

---

### Phase 5: Combination Scenarios (TC-601 to TC-606)
**Priority:** LOW
**Goal:** Test unusual but valid combinations

**Steps:**
1. Enable multiple proxy settings simultaneously
2. Export each combination
3. Verify all flags decode independently
4. Check for flag interaction bugs

**Success Criteria:**
- Multiple flags can be true simultaneously
- No interference between settings
- All data fields preserved

---

### Phase 6: Edge Cases (TC-701 to TC-710)
**Priority:** MEDIUM
**Goal:** Test parser robustness and error handling

**Steps:**
1. Manually create unusual configurations
2. Test boundary conditions (very long strings, empty values)
3. Test special characters and Unicode
4. Export and decode

**Success Criteria:**
- Parser handles edge cases gracefully
- No crashes or exceptions
- Appropriate warnings for malformed data
- Strings properly trimmed/cleaned

---

### Phase 7: Registry Structure Tests (TC-801 to TC-806)
**Priority:** LOW
**Goal:** Understand binary structure variations

**Steps:**
1. Monitor version counter changes
2. Test minimal valid registry entries
3. Create intentionally corrupted data
4. Test error handling

**Success Criteria:**
- Version field purpose understood
- Minimum/maximum sizes documented
- Error handling works for corrupted data

---

### Phase 8: Windows Version Compatibility (TC-901 to TC-905)
**Priority:** LOW
**Goal:** Ensure cross-version compatibility

**Steps:**
1. Export same configuration from different Windows versions
2. Compare binary structures
3. Test decoder against all versions

**Success Criteria:**
- Decoder works across all Windows versions tested
- Document any version-specific differences
- Update decoder if needed for compatibility

---

## Validation Checklist

For each test case, verify:

- [ ] **Binary Extraction**: Successfully extracted from .reg file
- [ ] **Version Field**: Parsed correctly (typically increments with changes)
- [ ] **Flags Field**: Correct hexadecimal value
- [ ] **DirectConnection Flag**: Boolean matches configuration
- [ ] **ProxyEnabled Flag**: Boolean matches configuration
- [ ] **AutoConfigEnabled Flag**: Boolean matches configuration
- [ ] **AutoDetectEnabled Flag**: Boolean matches configuration
- [ ] **ProxyServer String**: Exact match to configured value
- [ ] **ProxyBypass String**: Exact match with proper delimiters
- [ ] **AutoConfigURL String**: Complete URL with parameters
- [ ] **String Termination**: No null characters in output
- [ ] **String Trimming**: No leading/trailing whitespace
- [ ] **Field Offsets**: Calculated correctly for variable-length data
- [ ] **Total Length**: Binary data length matches expected size

---

## Script Testing Requirements

### Scripts to Test

1. **Read-DefaultProxySettings.ps1**
   - Reads live registry
   - Decodes DefaultConnectionSettings

2. **Read-ProxyRegistryFiles.ps1**
   - Parses .reg files
   - Batch processes test cases

3. **Test-ProxySettingsDecoder.ps1**
   - Automated test harness
   - Validation checks

4. **Set-ProxySettings.ps1** (if exists)
   - Sets proxy configuration
   - Encodes binary data correctly

### Required Test Coverage

Each script must correctly handle:

✅ **All flag combinations**
- Direct connection only
- Proxy only
- Auto-config only
- Auto-detect only
- Multiple flags enabled

✅ **All ProxyServer formats**
- Simple: `host:port`
- Protocol-specific: `http=host:port;https=host2:port2`
- Edge cases: empty, very long, special characters

✅ **All ProxyBypass formats**
- Empty (no bypass)
- `<local>` only
- Domain wildcards: `*.domain.com`
- IP ranges: `192.168.*`
- Complex lists: `*.domain.com;192.168.*;10.*;localhost;<local>`

✅ **All AutoConfigURL formats**
- HTTP URLs
- HTTPS URLs
- File URLs
- URLs with query parameters
- Very long URLs

---

## Test Data Management

### File Naming Convention

```
TC-XXX-Description.reg
```

**Examples:**
- `TC-001-DirectConnectionOnly.reg`
- `TC-101-SimpleProxy-IP-Port.reg`
- `TC-205-AllProtocolsDifferent.reg`
- `TC-306-BypassWithLocal.reg`
- `TC-505-PAC-WithQueryParams.reg`

### Documentation Requirements

For each .reg file, create a companion `.txt` file:

```
TC-XXX-Description.txt
```

**Contents:**
```
Test ID: TC-XXX
Test Name: [Full name]
Windows Version: Windows 10 21H2 / Windows 11 22H2
Export Date: 2025-12-17

Configuration Steps:
1. Open Internet Properties → Connections → LAN Settings
2. [Detailed steps to reproduce configuration]
3. Export registry with: reg export "HKCU\...\Connections" TC-XXX.reg

Expected Results:
- ProxyEnabled: True/False
- ProxyServer: [expected value]
- ProxyBypass: [expected value]
- AutoConfigEnabled: True/False
- AutoConfigURL: [expected value]
- AutoDetectEnabled: True/False
- DirectConnection: True/False

Actual Results:
[Paste output from decoder script]

Notes:
[Any special observations or issues]
```

---

## Automated Testing

### Test Runner Script

Create `Run-AllProxyTests.ps1`:

```powershell
# Pseudo-code structure
$TestResults = @()

foreach ($RegFile in Get-ChildItem "TC-*.reg") {
    $TestCase = Import-TestMetadata "$($RegFile.BaseName).txt"
    $Decoded = Decode-RegistryFile $RegFile

    # Compare expected vs actual
    $Result = Compare-ProxySettings -Expected $TestCase.Expected -Actual $Decoded

    $TestResults += $Result
}

# Generate test report
Export-TestReport -Results $TestResults -OutputPath "TestReport.html"
```

### Continuous Testing

- Run test suite after any decoder changes
- Verify all existing test cases still pass
- Add new test case for any reported bugs
- Maintain test coverage metrics

---

## Success Criteria

### Overall Project Success

✅ **100% of basic configurations** (TC-001 to TC-005) decode correctly
✅ **95%+ of manual proxy configs** (TC-101 to TC-309) decode correctly
✅ **90%+ of auto-config scenarios** (TC-401 to TC-506) decode correctly
✅ **80%+ of edge cases** handled gracefully (TC-701 to TC-710)
✅ **All scripts** produce identical results for same configuration
✅ **Error handling** works for corrupted/invalid data
✅ **Documentation** complete for all test cases

### Performance Criteria

- Decode time < 100ms per registry entry
- Batch processing of 100 files < 5 seconds
- Memory usage < 50MB for full test suite

---

## Known Issues & Limitations

### Current Gaps

- [ ] **Protocol-specific proxy parsing**: Need to verify correct format
- [ ] **SOCKS version detection**: SOCKS4 vs SOCKS5 distinction
- [ ] **IPv6 proxy addresses**: Bracket notation handling
- [ ] **International domains**: IDN (Internationalized Domain Names) encoding
- [ ] **Registry permissions**: Handling access denied scenarios

### Future Enhancements

- Automated test case generation
- Visual diff tool for binary comparison
- GUI for test management
- Integration with CI/CD pipeline
- Coverage report generation

---

## References

### Registry Locations

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections
- DefaultConnectionSettings (REG_BINARY)
- SavedLegacySettings (REG_BINARY)
```

### Related Registry Keys

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings
- ProxyEnable (REG_DWORD)
- ProxyServer (REG_SZ)
- ProxyOverride (REG_SZ)
- AutoConfigURL (REG_SZ)
```

**Note:** These REG_SZ keys may be duplicates or overridden by the binary DefaultConnectionSettings data. Always trust the binary structure as authoritative.

### Useful Commands

**Export current proxy settings:**
```cmd
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" proxy-current.reg
```

**Query current proxy values:**
```cmd
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride
```

**View binary data:**
```cmd
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" /v DefaultConnectionSettings
```

---

## Appendix A: Windows Proxy Settings UI Mapping

### LAN Settings Dialog (Internet Properties)

**Automatic configuration section:**
- ☐ Automatically detect settings → `AutoDetectEnabled` flag
- ☐ Use automatic configuration script → `AutoConfigEnabled` flag
  - Address: _____________ → `AutoConfigURL` field

**Proxy server section:**
- ☐ Use a proxy server for your LAN → `ProxyEnabled` flag
  - Address: _____________ Port: _____ → `ProxyServer` field (simple mode)
  - **[Advanced]** button → Opens protocol-specific dialog
  - ☐ Bypass proxy server for local addresses → Adds `<local>` to `ProxyBypass`

### Advanced Proxy Settings Dialog

**Servers section:**
- ☐ Use the same proxy server for all protocols
  - When **CHECKED**: Simple format `host:port`
  - When **UNCHECKED**: Protocol-specific format

**When unchecked, separate fields:**
- HTTP: _____________ Port: _____ → `http=host:port`
- Secure: ___________ Port: _____ → `https=host:port`
- FTP: ______________ Port: _____ → `ftp=host:port`
- Socks: ____________ Port: _____ → `socks=host:port`

**Exceptions section:**
- Do not use proxy server for addresses beginning with:
  - ______________________ → `ProxyBypass` field (semicolon-separated)
- ☐ Use semicolons (;) to separate entries

---

## Appendix B: Binary Structure Reference

### DefaultConnectionSettings Structure

**Header (Fixed 24 bytes):**
```
Offset  Length  Description
------  ------  -----------
0x00    4       Structure version/counter (usually 0x46, 0x00, 0x00, 0x00)
0x04    4       Version/counter increment value
0x08    4       Flags (bit field for proxy/auto-config/auto-detect settings)
0x0C    4       Unknown field (usually 0x00)
0x10    4       Length of ProxyServer string (0 if none)
0x14    4       Length of ProxyBypass string (0 if none)
0x18    ?       Variable-length ProxyServer string (null-terminated)
?       ?       Variable-length ProxyBypass string (null-terminated)
?       4       Length of AutoConfigURL string (0 if none)
?       ?       Variable-length AutoConfigURL string (null-terminated)
?       ?       Possible extra fields/padding
```

**Flags Field (Offset 0x08) - Bit Meanings:**
```
Bit     Description
---     -----------
0x01    Direct connection (no proxy)
0x02    Proxy server enabled
0x04    Auto-config script enabled (PAC)
0x08    Auto-detect settings enabled
0x10    Unknown
...     (Other bits to be documented)
```

**Example Common Flag Values:**
- `0x01` = Direct connection only
- `0x03` = Direct + Proxy enabled
- `0x05` = Direct + Auto-config
- `0x09` = Direct + Auto-detect
- `0x0F` = All enabled

---

## Appendix C: Test Execution Tracking

### Test Status Matrix

| Test ID | Status | Tested By | Date | Pass/Fail | Notes |
|---------|--------|-----------|------|-----------|-------|
| TC-001 | ⬜ Not Started | | | | |
| TC-002 | ⬜ Not Started | | | | |
| TC-003 | ⬜ Not Started | | | | |
| ... | | | | | |

**Status Legend:**
- ⬜ Not Started
- 🔄 In Progress
- ✅ Passed
- ❌ Failed
- ⚠️ Partial Pass (with notes)
- 🔧 Blocked (awaiting fix)

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-17 | Claude AI | Initial comprehensive test plan created |

---

**End of Test Plan**
