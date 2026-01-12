# Windows Proxy Settings Registry - Binary Parsing Flowchart

## Overview

This document provides a flowchart and decision tree for parsing the `DefaultConnectionSettings` binary registry value.

**Registry Location:**
```
HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections
Value: DefaultConnectionSettings (REG_BINARY)
```

---

## Binary Structure Flowchart

```
┌─────────────────────────────────────────────────────────────────┐
│ START: Read DefaultConnectionSettings Binary Data               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: Read Fixed Header (24 bytes)                            │
├─────────────────────────────────────────────────────────────────┤
│ Offset 0x00 (4 bytes) → Version Signature (usually 0x46)        │
│ Offset 0x04 (4 bytes) → Version/Counter                         │
│ Offset 0x08 (4 bytes) → FLAGS (CRITICAL - determines parsing)   │
│ Offset 0x0C (4 bytes) → Unknown/Reserved                        │
│ Offset 0x10 (4 bytes) → ProxyServer Length (L1)                 │
│ Offset 0x14 (4 bytes) → ProxyBypass Length (L2)                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: Parse FLAGS (Offset 0x08)                               │
├─────────────────────────────────────────────────────────────────┤
│ Extract 4-byte value and check individual bits:                 │
│                                                                  │
│ Bit 0 (0x01) → DirectConnection flag                            │
│ Bit 1 (0x02) → ProxyEnabled flag                                │
│ Bit 2 (0x04) → AutoConfigEnabled flag                           │
│ Bit 3 (0x08) → AutoDetectEnabled flag                           │
│ Bit 4+ → Reserved/Unknown                                       │
└─────────────────────────────────────────────────────────────────┘
                            ↓
                ┌───────────┴───────────┐
                ↓                       ↓
    ┌─────────────────────┐   ┌─────────────────────┐
    │ Bit 1 SET (0x02)?   │   │ Bit 1 CLEAR?        │
    │ ProxyEnabled = TRUE │   │ ProxyEnabled = FALSE│
    └─────────────────────┘   └─────────────────────┘
                ↓                       ↓
                YES                     NO (Skip to Step 4)
                ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: Read Proxy Settings (Offset 0x18+)                      │
├─────────────────────────────────────────────────────────────────┤
│ Position = 0x18 (after header)                                  │
│                                                                  │
│ IF L1 > 0:                                                       │
│   ├─ Read L1 bytes → ProxyServer string                         │
│   └─ Position += L1                                             │
│                                                                  │
│ IF L2 > 0:                                                       │
│   ├─ Read L2 bytes → ProxyBypass string                         │
│   └─ Position += L2                                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: Check for AutoConfig URL                                │
├─────────────────────────────────────────────────────────────────┤
│ IF Bit 2 SET (0x04) - AutoConfigEnabled:                        │
│   ├─ Read 4 bytes at Position → AutoConfigURL Length (L3)       │
│   ├─ Position += 4                                              │
│   ├─ IF L3 > 0:                                                 │
│   │   ├─ Read L3 bytes → AutoConfigURL string                   │
│   │   └─ Position += L3                                         │
│   └─ ELSE: AutoConfigURL = empty                                │
│                                                                  │
│ IF Bit 2 CLEAR:                                                 │
│   └─ AutoConfigURL = empty (skip reading)                       │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 5: Set Boolean Flags                                       │
├─────────────────────────────────────────────────────────────────┤
│ DirectConnection = (Flags & 0x01) != 0                          │
│ ProxyEnabled = (Flags & 0x02) != 0                              │
│ AutoConfigEnabled = (Flags & 0x04) != 0                         │
│ AutoDetectEnabled = (Flags & 0x08) != 0                         │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ DONE: Return Decoded Settings                                   │
├─────────────────────────────────────────────────────────────────┤
│ - Version/Counter                                                │
│ - Flags (hex value)                                             │
│ - DirectConnection (bool)                                       │
│ - ProxyEnabled (bool)                                           │
│ - ProxyServer (string or empty)                                 │
│ - ProxyBypass (string or empty)                                 │
│ - AutoConfigEnabled (bool)                                      │
│ - AutoConfigURL (string or empty)                               │
│ - AutoDetectEnabled (bool)                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Decision Tree: Which Fields to Read?

```
                        ┌──────────────┐
                        │  Read Flags  │
                        │  (Offset 8)  │
                        └──────┬───────┘
                               │
                    ┌──────────┴──────────┐
                    ↓                     ↓
            ┌───────────────┐     ┌───────────────┐
            │ Bit 1 (0x02)  │     │ Bit 1 CLEAR   │
            │ ProxyEnabled? │     │ Skip Proxy    │
            └───────┬───────┘     └───────────────┘
                    │
              ┌─────┴─────┐
              ↓           ↓
          ┌─────┐     ┌─────┐
          │ YES │     │ NO  │
          └──┬──┘     └─────┘
             │
    ┌────────┴────────┐
    │ Read ProxyServer│
    │ Length at 0x10  │
    │ (4 bytes = L1)  │
    └────────┬────────┘
             │
      ┌──────┴──────┐
      ↓             ↓
  ┌────────┐    ┌────────┐
  │ L1 > 0 │    │ L1 = 0 │
  └───┬────┘    └────┬───┘
      │              │
      ↓              ↓
┌───────────┐  ┌───────────┐
│ Read L1   │  │ ProxyServer│
│ bytes at  │  │ = empty   │
│ 0x18      │  └───────────┘
│ →ProxyServer│
└───────────┘
      │
┌─────┴──────┐
│Read Bypass │
│Length 0x14 │
│(4 bytes=L2)│
└─────┬──────┘
      │
  ┌───┴───┐
  ↓       ↓
┌────────┐ ┌────────┐
│ L2 > 0 │ │ L2 = 0 │
└───┬────┘ └────┬───┘
    │           │
    ↓           ↓
┌───────────┐ ┌───────────┐
│ Read L2   │ │ProxyBypass│
│ bytes     │ │ = empty   │
│→ProxyBypass│ └───────────┘
└───────────┘

              ┌──────────────┐
              │  Bit 2 SET?  │
              │ (0x04) Auto  │
              │ Config?      │
              └──────┬───────┘
                     │
              ┌──────┴──────┐
              ↓             ↓
          ┌─────┐       ┌─────┐
          │ YES │       │ NO  │
          └──┬──┘       └─────┘
             │
    ┌────────┴────────┐
    │ Read PAC URL    │
    │ Length at       │
    │ Position (L3)   │
    └────────┬────────┘
             │
      ┌──────┴──────┐
      ↓             ↓
  ┌────────┐    ┌────────┐
  │ L3 > 0 │    │ L3 = 0 │
  └───┬────┘    └────┬───┘
      │              │
      ↓              ↓
┌───────────┐  ┌────────────┐
│ Read L3   │  │AutoConfigURL│
│ bytes     │  │ = empty    │
│→AutoConfigURL│└────────────┘
└───────────┘
```

---

## Flag Bit Reference

### Checking Individual Bits

```
Flags Value (32-bit DWORD at offset 0x08)
Example: 0x0000000F = 0000 0000 0000 0000 0000 0000 0000 1111

Bit Position:  ...  7  6  5  4  3  2  1  0
Hex Mask:          80 40 20 10 08 04 02 01
                                 ↑  ↑  ↑  ↑
                                 │  │  │  └─ Bit 0: Direct Connection
                                 │  │  └──── Bit 1: Proxy Enabled
                                 │  └─────── Bit 2: Auto Config (PAC)
                                 └────────── Bit 3: Auto Detect (WPAD)
```

### Bit Check Logic

```
IF (Flags & 0x01) THEN DirectConnection = TRUE
IF (Flags & 0x02) THEN ProxyEnabled = TRUE
IF (Flags & 0x04) THEN AutoConfigEnabled = TRUE
IF (Flags & 0x08) THEN AutoDetectEnabled = TRUE
```

### Common Flag Combinations

```
Flags  Binary         Meaning
────────────────────────────────────────────────────────────
0x01   0000 0001      Direct connection only
0x02   0000 0010      Proxy only (unusual - usually with 0x01)
0x03   0000 0011      Direct + Proxy (most common for manual proxy)
0x04   0000 0100      Auto-config only
0x05   0000 0101      Direct + Auto-config
0x08   0000 1000      Auto-detect only
0x09   0000 1001      Direct + Auto-detect
0x0B   0000 1011      Direct + Proxy + Auto-detect
0x0D   0000 1101      Direct + Auto-config + Auto-detect
0x0F   0000 1111      All flags enabled
```

---

## Parsing Algorithm Pseudocode

```
FUNCTION ParseProxySettings(binaryData):
    // Step 1: Read header
    version = ReadInt32(binaryData, offset=0x00)
    counter = ReadInt32(binaryData, offset=0x04)
    flags = ReadInt32(binaryData, offset=0x08)
    unknown = ReadInt32(binaryData, offset=0x0C)
    proxyLength = ReadInt32(binaryData, offset=0x10)
    bypassLength = ReadInt32(binaryData, offset=0x14)

    position = 0x18  // Start of variable data

    // Step 2: Read proxy server if enabled
    proxyServer = ""
    IF (flags & 0x02) != 0:  // Bit 1 set
        IF proxyLength > 0:
            proxyServer = ReadString(binaryData, position, proxyLength)
            position += proxyLength

    // Step 3: Read proxy bypass list
    proxyBypass = ""
    IF bypassLength > 0:
        proxyBypass = ReadString(binaryData, position, bypassLength)
        position += bypassLength

    // Step 4: Read auto-config URL if enabled
    autoConfigURL = ""
    IF (flags & 0x04) != 0:  // Bit 2 set
        autoConfigLength = ReadInt32(binaryData, position)
        position += 4
        IF autoConfigLength > 0:
            autoConfigURL = ReadString(binaryData, position, autoConfigLength)
            position += autoConfigLength

    // Step 5: Extract boolean flags
    directConnection = (flags & 0x01) != 0
    proxyEnabled = (flags & 0x02) != 0
    autoConfigEnabled = (flags & 0x04) != 0
    autoDetectEnabled = (flags & 0x08) != 0

    // Return parsed settings
    RETURN {
        version: version,
        counter: counter,
        flags: flags,
        directConnection: directConnection,
        proxyEnabled: proxyEnabled,
        proxyServer: proxyServer,
        proxyBypass: proxyBypass,
        autoConfigEnabled: autoConfigEnabled,
        autoConfigURL: autoConfigURL,
        autoDetectEnabled: autoDetectEnabled
    }
END FUNCTION
```

---

## Critical Parsing Rules

### Rule 1: Always Read Header First
```
┌─────────────────────────────────────┐
│ ALWAYS read first 24 bytes          │
│ These contain lengths for all       │
│ variable-length fields              │
└─────────────────────────────────────┘
```

### Rule 2: Check Flags Before Reading Data
```
┌─────────────────────────────────────┐
│ IF Bit 1 (0x02) CLEAR:              │
│   → Skip reading ProxyServer        │
│   → ProxyLength may still be > 0!   │
│   → Don't trust length alone        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ IF Bit 2 (0x04) CLEAR:              │
│   → Skip reading AutoConfigURL      │
│   → Don't even read the length field│
└─────────────────────────────────────┘
```

### Rule 3: Track Position Carefully
```
Position starts at 0x18 (after 24-byte header)

After reading ProxyServer:
  position += proxyLength

After reading ProxyBypass:
  position += bypassLength

Before reading AutoConfigURL:
  Read length at current position
  position += 4
  Then read string at position
  position += autoConfigLength
```

### Rule 4: Handle Edge Cases
```
┌─────────────────────────────────────┐
│ ProxyLength = 0:                    │
│   → ProxyServer = empty string      │
│   → Don't advance position          │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ String may be null-terminated:      │
│   → Trim null characters            │
│   → Length includes null terminator │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Bypass list separator:              │
│   → Semicolon (;) separates entries │
│   → <local> is special token        │
└─────────────────────────────────────┘
```

---

## Example: Step-by-Step Parsing

### Example 1: Manual Proxy with Bypass

**Binary Data (hex):**
```
Offset   Hex Data
───────  ─────────────────────────────
0x00     46 00 00 00                 Version = 0x46
0x04     03 00 00 00                 Counter = 3
0x08     03 00 00 00                 Flags = 0x03 (Direct + Proxy)
0x0C     00 00 00 00                 Unknown
0x10     18 00 00 00                 ProxyLength = 24 bytes
0x14     21 00 00 00                 BypassLength = 33 bytes
0x18     31 39 32 2E 31 36 38...     "192.168.1.101:8080" (24 bytes)
0x30     2A 2E 63 6F 6D 70 61...     "*.company.com;<local>" (33 bytes)
```

**Parsing Steps:**
```
1. Read flags at 0x08 = 0x03
   ├─ Bit 0 (0x01) SET → DirectConnection = TRUE
   ├─ Bit 1 (0x02) SET → ProxyEnabled = TRUE
   ├─ Bit 2 (0x04) CLEAR → AutoConfigEnabled = FALSE
   └─ Bit 3 (0x08) CLEAR → AutoDetectEnabled = FALSE

2. Bit 1 SET, so read proxy:
   ├─ ProxyLength at 0x10 = 24
   └─ Read 24 bytes at 0x18 = "192.168.1.101:8080"

3. Read bypass:
   ├─ BypassLength at 0x14 = 33
   └─ Read 33 bytes at 0x30 = "*.company.com;<local>"

4. Bit 2 CLEAR, so skip AutoConfigURL
   └─ Don't read any more data

5. Result:
   ├─ ProxyEnabled = TRUE
   ├─ ProxyServer = "192.168.1.101:8080"
   ├─ ProxyBypass = "*.company.com;<local>"
   ├─ AutoConfigEnabled = FALSE
   └─ AutoDetectEnabled = FALSE
```

### Example 2: Auto-Config Only

**Binary Data (hex):**
```
Offset   Hex Data
───────  ─────────────────────────────
0x00     46 00 00 00                 Version = 0x46
0x04     05 00 00 00                 Counter = 5
0x08     05 00 00 00                 Flags = 0x05 (Direct + AutoConfig)
0x0C     00 00 00 00                 Unknown
0x10     00 00 00 00                 ProxyLength = 0
0x14     00 00 00 00                 BypassLength = 0
0x18     42 00 00 00                 AutoConfigLength = 66 bytes
0x1C     68 74 74 70 3A 2F...        "http://config.company.com:8082/proxy.pac?p=PARAMS"
```

**Parsing Steps:**
```
1. Read flags at 0x08 = 0x05
   ├─ Bit 0 (0x01) SET → DirectConnection = TRUE
   ├─ Bit 1 (0x02) CLEAR → ProxyEnabled = FALSE
   ├─ Bit 2 (0x04) SET → AutoConfigEnabled = TRUE
   └─ Bit 3 (0x08) CLEAR → AutoDetectEnabled = FALSE

2. Bit 1 CLEAR, so skip proxy:
   ├─ ProxyLength = 0 (confirm)
   └─ ProxyServer = empty

3. BypassLength = 0:
   └─ ProxyBypass = empty

4. Bit 2 SET, so read AutoConfigURL:
   ├─ Position = 0x18 (no proxy or bypass data)
   ├─ Read length at 0x18 = 66
   └─ Read 66 bytes at 0x1C = "http://config.company.com:8082/proxy.pac?p=PARAMS"

5. Result:
   ├─ ProxyEnabled = FALSE
   ├─ AutoConfigEnabled = TRUE
   └─ AutoConfigURL = "http://config.company.com:8082/proxy.pac?p=PARAMS"
```

---

## Quick Reference: Field Dependencies

```
┌──────────────────────┬────────────────────┬────────────────────┐
│ Flag Bit             │ Controls Reading   │ Location           │
├──────────────────────┼────────────────────┼────────────────────┤
│ Bit 1 (0x02)         │ ProxyServer        │ Offset 0x18+       │
│ ProxyEnabled         │ ProxyBypass        │ Offset 0x18+L1     │
├──────────────────────┼────────────────────┼────────────────────┤
│ Bit 2 (0x04)         │ AutoConfigURL      │ After Proxy/Bypass │
│ AutoConfigEnabled    │                    │ Read length first  │
├──────────────────────┼────────────────────┼────────────────────┤
│ Bit 0 (0x01)         │ (No data fields)   │ Flag only          │
│ DirectConnection     │                    │                    │
├──────────────────────┼────────────────────┼────────────────────┤
│ Bit 3 (0x08)         │ (No data fields)   │ Flag only          │
│ AutoDetectEnabled    │                    │                    │
└──────────────────────┴────────────────────┴────────────────────┘
```

---

## Error Handling

### Invalid Data Detection

```
IF version != 0x46:
    WARN: Unexpected version signature

IF proxyLength > 1000:
    ERROR: ProxyServer length unreasonable

IF bypassLength > 5000:
    ERROR: ProxyBypass length unreasonable

IF position + length > binaryData.length:
    ERROR: Length extends beyond data boundary

IF proxyServer contains null characters:
    TRIM: Remove nulls and trim whitespace

IF flags has unexpected bits set (> 0x0F):
    WARN: Unknown flags detected
```

---

## Testing Checklist

When implementing a parser, verify:

- [ ] Correctly reads 24-byte header
- [ ] Parses flags as 32-bit integer
- [ ] Checks bit 1 before reading proxy
- [ ] Handles zero-length proxy strings
- [ ] Reads bypass list when present
- [ ] Checks bit 2 before reading PAC URL
- [ ] Tracks position correctly through variable fields
- [ ] Trims null characters from strings
- [ ] Returns boolean flags correctly
- [ ] Handles all flag combinations (0x00 to 0x0F)

---

**End of Flowchart Documentation**
