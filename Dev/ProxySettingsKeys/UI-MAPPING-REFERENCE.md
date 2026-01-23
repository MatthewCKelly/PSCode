# Windows Proxy Settings UI → Registry Mapping Quick Reference

## Overview

This document maps the Windows Proxy Settings UI elements to the corresponding registry values in `DefaultConnectionSettings` binary data.

---

## UI Dialog Structure

### Main Dialog: LAN Settings

**Path to Access:**
- Windows 10/11: Settings → Network & Internet → Proxy → "Open proxy settings" (or use legacy `inetcpl.cpl`)
- Legacy: Control Panel → Internet Options → Connections → LAN Settings

![UI Reference: See screenshot in issue]

---

## Section 1: Automatic Configuration

| UI Element | Registry Field | Binary Flag | Notes |
|------------|----------------|-------------|-------|
| ☐ **Automatically detect settings** | `AutoDetectEnabled` | `0x08` bit in Flags | WPAD (Web Proxy Auto-Discovery) |
| ☐ **Use automatic configuration script** | `AutoConfigEnabled` | `0x04` bit in Flags | PAC file enabled |
| **Address:** [text field] | `AutoConfigURL` | String field | Full PAC URL with protocol |

### Examples:

**Auto-Detect Enabled:**
- UI: ☑ Automatically detect settings
- Registry: Flags bit `0x08` = 1
- Decoded: `AutoDetectEnabled = True`

**PAC URL Configured:**
- UI: ☑ Use automatic configuration script
- UI: Address: `http://config.company.com:8082/proxy.pac?p=PARAMS`
- Registry: Flags bit `0x04` = 1, AutoConfigURL string field populated
- Decoded: `AutoConfigEnabled = True`, `AutoConfigURL = "http://config.company.com:8082/proxy.pac?p=PARAMS"`

---

## Section 2: Proxy Server (Basic)

| UI Element | Registry Field | Binary Flag | Notes |
|------------|----------------|-------------|-------|
| ☐ **Use a proxy server for your LAN** | `ProxyEnabled` | `0x02` bit in Flags | Main proxy toggle |
| **Address:** [text field] | `ProxyServer` | String field | Simple mode: `host:port` |
| **Port:** [number field] | Part of `ProxyServer` | String field | Appended as `:port` |
| ☐ **Bypass proxy server for local addresses** | Part of `ProxyBypass` | String field | Adds `<local>` to bypass list |

### Examples:

**Simple Proxy (All Protocols):**
- UI: ☑ Use a proxy server
- UI: Address: `192.168.1.1`  Port: `8080`
- UI: ☑ Bypass proxy server for local addresses
- Registry: Flags bit `0x02` = 1, ProxyServer = `192.168.1.1:8080`, ProxyBypass = `<local>`
- Decoded: `ProxyEnabled = True`, `ProxyServer = "192.168.1.1:8080"`, `ProxyBypass = "<local>"`

---

## Section 3: Advanced Proxy Settings

**Accessed via:** [Advanced...] button in LAN Settings

### UI Element: "Use the same proxy server for all protocols"

| Checkbox State | ProxyServer Format | Example |
|----------------|-------------------|---------|
| **☑ CHECKED** | Simple format: `host:port` | `proxy.company.com:8080` |
| **☐ UNCHECKED** | Protocol-specific: `protocol=host:port;protocol=host:port` | `http=proxy1:8080;https=proxy2:443` |

### Protocol-Specific Fields (when "same proxy" is UNCHECKED)

| UI Field | Protocol Prefix | Example Input | Registry Value |
|----------|----------------|---------------|----------------|
| **HTTP:** [host] **:** [port] | `http=` | `proxy.local:8080` | `http=proxy.local:8080` |
| **Secure:** [host] **:** [port] | `https=` | `secure.local:8443` | `https=secure.local:8443` |
| **FTP:** [host] **:** [port] | `ftp=` | `ftp-proxy.local:21` | `ftp=ftp-proxy.local:21` |
| **Socks:** [host] **:** [port] | `socks=` | `socks-proxy:1080` | `socks=socks-proxy:1080` |

**Combined format:** Protocols are separated by semicolons (`;`)

### Examples:

**Example 1: All Protocols Use Same Proxy**
- UI: ☑ Use the same proxy server for all protocols
- UI: HTTP: `proxy.company.com` Port: `8080`
- Registry: `ProxyServer = "proxy.company.com:8080"`
- Decoded: `ProxyServer = "proxy.company.com:8080"`

**Example 2: Different Proxy for Each Protocol**
- UI: ☐ Use the same proxy server for all protocols (UNCHECKED)
- UI: HTTP: `http-proxy.local` Port: `8080`
- UI: Secure: `https-proxy.local` Port: `8443`
- UI: FTP: `ftp.local` Port: `21`
- UI: Socks: (empty)
- Registry: `ProxyServer = "http=http-proxy.local:8080;https=https-proxy.local:8443;ftp=ftp.local:21"`
- Decoded: `ProxyServer = "http=http-proxy.local:8080;https=https-proxy.local:8443;ftp=ftp.local:21"`

**Example 3: HTTP and HTTPS Only**
- UI: ☐ Use the same proxy server for all protocols (UNCHECKED)
- UI: HTTP: `web-proxy` Port: `3128`
- UI: Secure: `web-proxy` Port: `3128`
- UI: FTP: (empty)
- UI: Socks: (empty)
- Registry: `ProxyServer = "http=web-proxy:3128;https=web-proxy:3128"`
- Decoded: `ProxyServer = "http=web-proxy:3128;https=web-proxy:3128"`

---

## Section 4: Proxy Exceptions

### UI Element: "Do not use proxy server for addresses beginning with:"

| UI Input | ProxyBypass Format | Example |
|----------|-------------------|---------|
| (empty) | `""` or null | No bypass |
| Single domain | `domain.com` | `*.company.com` |
| Multiple entries (semicolon-separated) | `entry1;entry2;entry3` | `*.local;192.168.*;localhost` |
| **With** "Bypass local" checkbox | Adds `<local>` to list | `*.company.com;<local>` |

### Special Bypass Patterns

| Pattern Type | Example | Meaning |
|--------------|---------|---------|
| Wildcard domain | `*.company.com` | All hosts in company.com domain |
| Specific hostname | `intranet` | Only "intranet" |
| IP wildcard | `192.168.*` | All IPs starting with 192.168 |
| CIDR notation | `10.0.0.0/8` | IP range in CIDR format |
| **Local addresses** | `<local>` | All non-qualified hostnames (no dots) |

### Examples:

**Example 1: Bypass Local Only**
- UI: ☑ Bypass proxy server for local addresses
- UI: Exceptions field: (empty)
- Registry: `ProxyBypass = "<local>"`
- Decoded: `ProxyBypass = "<local>"`

**Example 2: Bypass Specific Domains**
- UI: ☐ Bypass proxy server for local addresses (UNCHECKED)
- UI: Exceptions: `*.company.com;*.internal.net;localhost`
- Registry: `ProxyBypass = "*.company.com;*.internal.net;localhost"`
- Decoded: `ProxyBypass = "*.company.com;*.internal.net;localhost"`

**Example 3: Complex Bypass List**
- UI: ☑ Bypass proxy server for local addresses (CHECKED)
- UI: Exceptions: `home.crash.co.nz;crash.local;<local>`
- Registry: `ProxyBypass = "home.crash.co.nz;crash.local;<local>"`
- Decoded: `ProxyBypass = "home.crash.co.nz;crash.local;<local>"`

**Note:** If user manually types `<local>` in the exceptions field AND checks the "Bypass local" checkbox, `<local>` might appear twice. The decoder should handle this gracefully.

---

## Section 5: Flag Combinations

### Common Flag Values (at offset 0x08 in binary data)

| Flags (Hex) | Bits Set | UI Configuration | Description |
|-------------|----------|------------------|-------------|
| `0x01` | 0000 0001 | All unchecked (or just direct) | Direct connection only |
| `0x02` | 0000 0010 | ☑ Use proxy server | Proxy enabled only |
| `0x03` | 0000 0011 | ☑ Use proxy (with direct fallback) | Proxy + Direct |
| `0x04` | 0000 0100 | ☑ Use auto config script | Auto-config PAC only |
| `0x05` | 0000 0101 | ☑ Use auto config (with direct) | Auto-config + Direct |
| `0x08` | 0000 1000 | ☑ Automatically detect | Auto-detect only |
| `0x09` | 0000 1001 | ☑ Auto-detect (with direct) | Auto-detect + Direct |
| `0x0B` | 0000 1011 | ☑ Auto-detect + ☑ Proxy | Auto-detect + Proxy + Direct |
| `0x0F` | 0000 1111 | All checkboxes | Direct + Proxy + PAC + Auto-detect |

### Flag Bit Meanings

| Bit Position | Hex Value | Flag Name | UI Element |
|--------------|-----------|-----------|------------|
| Bit 0 | `0x01` | Direct Connection | Baseline (usually always set?) |
| Bit 1 | `0x02` | Proxy Enabled | ☑ Use a proxy server |
| Bit 2 | `0x04` | Auto-Config Enabled | ☑ Use automatic configuration script |
| Bit 3 | `0x08` | Auto-Detect Enabled | ☑ Automatically detect settings |
| Bit 4 | `0x10` | ? | Unknown / Reserved |
| Bit 5 | `0x20` | ? | Unknown / Reserved |
| Bit 6 | `0x40` | ? | Unknown / Reserved |
| Bit 7 | `0x80` | ? | Unknown / Reserved |

**Note:** Bit 0 (`0x01`) often appears set even when "direct connection" isn't explicitly chosen. This may indicate a fallback mechanism or default state. Further testing needed to confirm exact behavior.

---

## Binary Structure Summary

### DefaultConnectionSettings Layout

```
Offset | Length | Field Name          | Description
-------|--------|---------------------|---------------------------------------
0x00   | 4      | Version Signature   | Usually 0x46 0x00 0x00 0x00
0x04   | 4      | Version/Counter     | Increments with each change
0x08   | 4      | Flags               | Bit field (see flag table above)
0x0C   | 4      | Unknown/Reserved    | Usually 0x00 0x00 0x00 0x00
0x10   | 4      | ProxyServer Length  | Length of ProxyServer string (0 if none)
0x14   | ?      | ProxyServer Data    | UTF-8/ASCII string (variable length)
?      | 4      | ProxyBypass Length  | Length of ProxyBypass string (0 if none)
?      | ?      | ProxyBypass Data    | UTF-8/ASCII string (variable length)
?      | 4      | AutoConfigURL Len   | Length of AutoConfigURL string (0 if none)
?      | ?      | AutoConfigURL Data  | UTF-8/ASCII string (variable length)
?      | ?      | Extra Data/Padding  | May include unknown fields
```

**String Format:**
- Strings are null-terminated
- Encoding: Usually ASCII/UTF-8
- Lengths include null terminator (or might not - needs verification)

---

## Testing Checklist for Each Configuration

When creating a test case, verify:

### 1. UI Configuration
- [ ] Screenshot of settings before export (optional but helpful)
- [ ] Document exact checkbox states
- [ ] Document exact text field values
- [ ] Note any special characters or unusual values

### 2. Registry Export
- [ ] Export with: `reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" TestCase.reg`
- [ ] Verify .reg file contains `DefaultConnectionSettings` entry
- [ ] Note file size for comparison

### 3. Decoding Verification
- [ ] Run: `.\Read-ProxyRegistryFiles.ps1`
- [ ] Verify Version/Counter value
- [ ] Verify Flags hex value
- [ ] Verify all boolean flags match UI checkbox states
- [ ] Verify ProxyServer string matches UI input
- [ ] Verify ProxyBypass string matches UI input (including `<local>` if applicable)
- [ ] Verify AutoConfigURL matches UI input
- [ ] Check for extra whitespace or null characters in strings
- [ ] Confirm total binary length is reasonable

### 4. Edge Case Checks
- [ ] Test with empty strings (unchecked boxes, empty fields)
- [ ] Test with very long strings (URLs, bypass lists)
- [ ] Test with special characters (Unicode, URL-encoded, etc.)
- [ ] Test with unusual but valid inputs (IPv6, IDN domains, etc.)

---

## Common Pitfalls & Gotchas

### ⚠️ "Use the same proxy" Checkbox State

**Critical:** The format of `ProxyServer` completely changes based on this checkbox!

- **Checked:** Simple `host:port` format
- **Unchecked:** Protocol-specific `protocol=host:port;protocol=host:port` format

**Common mistake:** Configuring different proxies in the UI but forgetting to UNCHECK the "same proxy" box results in only the HTTP proxy being saved.

### ⚠️ Bypass Local Checkbox

When "Bypass proxy server for local addresses" is checked:
- Windows adds `<local>` to the bypass list
- If user also manually types `<local>` in exceptions, it may appear twice
- The `<local>` token should be preserved exactly as-is (including angle brackets)

### ⚠️ Empty vs. Null Fields

Different between:
- Field length = 0 (field present but empty string)
- Field missing entirely (no length field)

Scripts should handle both cases gracefully.

### ⚠️ Registry vs. UI Discrepancy

Sometimes the registry may contain old/stale values even though UI shows different settings. Always:
1. Make a change in UI
2. Click OK to apply
3. Immediately export registry
4. Verify the change was actually written

### ⚠️ Port Numbers

Port numbers in UI are separate fields but stored as part of the `host:port` string in registry. Empty port field might result in:
- `proxy.local` (no colon)
- `proxy.local:` (colon but no number)
- Behavior may vary by Windows version

---

## Useful Registry Commands

### Query Proxy Settings (Alternative Keys)

These keys may contain duplicate or legacy data:

```cmd
# Main proxy enable flag (may be redundant with binary data)
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable

# Text-based proxy server (may be redundant)
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer

# Text-based bypass list (may be redundant)
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride

# Auto-config URL (may be redundant)
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL
```

**Note:** The `DefaultConnectionSettings` binary data is the authoritative source. The separate `ProxyEnable`, `ProxyServer`, `ProxyOverride`, and `AutoConfigURL` registry values may be duplicates maintained for legacy compatibility, but they can become out of sync. Always trust the binary structure.

### Export All Internet Settings

```cmd
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" InternetSettings-Full.reg
```

### View Binary Data in Hex

```cmd
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" /v DefaultConnectionSettings
```

Output will show hex bytes like:
```
DefaultConnectionSettings    REG_BINARY    46000000050000000F000000...
```

---

## Quick Reference: UI to Expected Values

| Scenario | UI Checkboxes | Expected Flags | Expected Strings |
|----------|---------------|----------------|------------------|
| **No Proxy** | All unchecked | `0x01` or `0x00` | All empty/null |
| **Simple Proxy** | ☑ Use proxy | `0x03` | ProxyServer: `host:port` |
| **Proxy + Bypass Local** | ☑ Use proxy<br>☑ Bypass local | `0x03` | ProxyServer: `host:port`<br>ProxyBypass: `<local>` |
| **PAC Only** | ☑ Auto-config script | `0x05` | AutoConfigURL: `http://...` |
| **Auto-Detect Only** | ☑ Auto-detect | `0x09` | All strings empty |
| **Proxy + PAC** | ☑ Use proxy<br>☑ Auto-config | `0x07` | ProxyServer + AutoConfigURL both set |
| **Everything Enabled** | All checked | `0x0F` | All fields populated |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-17 | Initial UI mapping reference created based on Windows 10/11 proxy dialogs |

---

**End of Reference Document**
