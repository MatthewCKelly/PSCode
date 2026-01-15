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
│ STEP 1: Read Fixed Header (12 bytes)                            │
├─────────────────────────────────────────────────────────────────┤
│ Offset 0x00 (4 bytes) → Version Signature (always 0x46 = 70)    │
│ Offset 0x04 (4 bytes) → Change Counter (auto-increments)        │
│ Offset 0x08 (4 bytes) → FLAGS (CRITICAL - determines parsing)   │
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
                YES                     NO (Skip proxy data)
                ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: Read ProxyServer Section (Offset 0x0C+)                 │
├─────────────────────────────────────────────────────────────────┤
│ Position = 0x0C (after 12-byte header)                          │
│                                                                  │
│ 1. Read 4 bytes → ProxyServer Length (L1)                       │
│    Position += 4                                                │
│                                                                  │
│ 2. IF L1 > 0:                                                    │
│      ├─ Read L1 bytes → ProxyServer string                      │
│      └─ Position += L1                                          │
│    ELSE:                                                        │
│      └─ ProxyServer = empty                                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: Read ProxyBypass Section (at current position)          │
├─────────────────────────────────────────────────────────────────┤
│ 1. Read 4 bytes → ProxyBypass Length (L2)                       │
│    Position += 4                                                │
│                                                                  │
│ 2. IF L2 > 0:                                                    │
│      ├─ Read L2 bytes → ProxyBypass string                      │
│      └─ Position += L2                                          │
│    ELSE:                                                        │
│      └─ ProxyBypass = empty                                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 5: Read AutoConfigURL Section (at current position)        │
├─────────────────────────────────────────────────────────────────┤
│ 1. Read 4 bytes → AutoConfigURL Length (L3)                     │
│    Position += 4                                                │
│                                                                  │
│ 2. IF L3 > 0:                                                    │
│      ├─ Read L3 bytes → AutoConfigURL string                    │
│      └─ Position += L3                                          │
│    ELSE:                                                        │
│      └─ AutoConfigURL = empty                                   │
│                                                                  │
│ 3. Check Bit 2 (0x04) - AutoConfigEnabled:                      │
│    If CLEAR, ignore the URL even if present                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 6: Set Boolean Flags                                       │
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
│ - VersionSignature (0x46)                                        │
│ - Change Counter (auto-increments)                              │
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

## Parsing Algorithm Pseudocode

```
FUNCTION ParseProxySettings(binaryData):
    // Step 1: Read 12-byte fixed header
    versionSignature = ReadInt32(binaryData, offset=0x00)  // Always 0x46 (70)
    changeCounter = ReadInt32(binaryData, offset=0x04)     // Auto-increments with each change
    flags = ReadInt32(binaryData, offset=0x08)             // Bit flags for proxy settings

    // Step 2: Start parsing variable sections at offset 0x0C
    position = 0x0C  // After 12-byte header

    // Step 3: Read ProxyServer section (Length + Data)
    proxyLength = ReadInt32(binaryData, position)
    position += 4
    proxyServer = ""
    IF proxyLength > 0:
        proxyServer = ReadString(binaryData, position, proxyLength)
        position += proxyLength

    // Step 4: Read ProxyBypass section (Length + Data)
    bypassLength = ReadInt32(binaryData, position)
    position += 4
    proxyBypass = ""
    IF bypassLength > 0:
        proxyBypass = ReadString(binaryData, position, bypassLength)
        position += bypassLength

    // Step 5: Read AutoConfigURL section (Length + Data)
    autoConfigLength = ReadInt32(binaryData, position)
    position += 4
    autoConfigURL = ""
    IF autoConfigLength > 0:
        autoConfigURL = ReadString(binaryData, position, autoConfigLength)
        position += autoConfigLength

    // Step 6: Extract boolean flags
    directConnection = (flags & 0x01) != 0
    proxyEnabled = (flags & 0x02) != 0
    autoConfigEnabled = (flags & 0x04) != 0
    autoDetectEnabled = (flags & 0x08) != 0

    // Return parsed settings
    RETURN {
        versionSignature: versionSignature,
        changeCounter: changeCounter,
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

### Rule 1: Structure is 12-byte Header + Interleaved Sections
```
┌──────────────────────────────────────────┐
│ Fixed Header: 12 bytes (0x00-0x0B)      │
│   0x00-0x03: Version Sig (0x46)         │
│   0x04-0x07: Change Counter (auto-inc)  │
│   0x08-0x0B: Flags (bit flags)          │
│                                          │
│ Variable Sections (from 0x0C):          │
│   Section 1: Proxy Length + Data        │
│   Section 2: Bypass Length + Data       │
│   Section 3: AutoCfg Length + Data      │
│                                          │
│ NOT all lengths then all data!          │
│ Each section is Length+Data pair        │
└──────────────────────────────────────────┘
```

### Rule 2: Read Length+Data Sequentially
```
┌─────────────────────────────────────┐
│ ALWAYS read in order:               │
│ 1. Read 4-byte length               │
│ 2. Read N bytes of data (if > 0)   │
│ 3. Move to next section             │
│                                     │
│ Position tracking is CRITICAL!     │
└─────────────────────────────────────┘
```

### Rule 3: Check Flags for Interpretation
```
┌─────────────────────────────────────┐
│ Data may exist even if flag CLEAR: │
│                                     │
│ IF Bit 1 (0x02) CLEAR:              │
│   → Ignore ProxyServer data         │
│   → But still READ past it!         │
│                                     │
│ IF Bit 2 (0x04) CLEAR:              │
│   → Ignore AutoConfigURL data       │
│   → But still READ past it!         │
└─────────────────────────────────────┘
```

### Rule 4: Position Tracking
```
Position starts at 0x0C (after 12-byte header)

After reading Proxy length:
  position += 4
After reading Proxy data (if length > 0):
  position += proxyLength

After reading Bypass length:
  position += 4
After reading Bypass data (if length > 0):
  position += bypassLength

After reading AutoConfig length:
  position += 4
After reading AutoConfig data (if length > 0):
  position += autoConfigLength
```

---

## Example: Step-by-Step Parsing

### Example 1: Manual Proxy with Auto-Config

**Binary Data (hex):**
```
Offset   Hex Data                       Description
───────  ─────────────────────────────  ─────────────────────────
0x00     46 00 00 00                    VersionSig = 0x46 (70)
0x04     05 00 00 00                    Change Counter = 5 (increments with each change)
0x08     0F 00 00 00                    Flags = 0x0F (all enabled)
0x0C     18 00 00 00                    ProxyServer Length = 24 bytes (0x18)
0x10     68 74 74 70 3a 2f 2f ...       "http://127.20.20.20:3128!" (24 bytes)
0x28     2A 00 00 00                    ProxyBypass Length = 42 bytes (0x2A)
0x2C     68 6f 6d 65 2e 63 ...          "home.crash.co.nz;fh.local;<local>" (42 bytes)
0x56     42 00 00 00                    AutoConfigURL Length = 66 bytes (0x42)
0x5A     68 74 74 70 3a 2f 2f ...       "http://webdefence.global..." (66 bytes)
```

**Parsing Steps:**
```
1. Read 12-byte header:
   ├─ VersionSignature = 0x46 (70) [constant]
   ├─ Change Counter = 5 [auto-incremented by Windows on each change]
   └─ Flags = 0x0F (Direct=1, Proxy=1, AutoConfig=1, AutoDetect=1)

2. Position = 0x0C (12 decimal)

3. Read ProxyServer section:
   ├─ Read length at 0x0C = 24 bytes (0x18)
   ├─ Position = 0x10 (16 decimal)
   ├─ Read 24 bytes at 0x10 = "http://127.20.20.20:3128!"
   └─ Position = 0x28 (40 decimal)

4. Read ProxyBypass section:
   ├─ Read length at 0x28 = 42 bytes (0x2A)
   ├─ Position = 0x2C (44 decimal)
   ├─ Read 42 bytes at 0x2C = "home.crash.co.nz;fh.local;<local>"
   └─ Position = 0x56 (86 decimal)

5. Read AutoConfigURL section:
   ├─ Read length at 0x56 = 66 bytes (0x42)
   ├─ Position = 0x5A (90 decimal)
   └─ Read 66 bytes at 0x5A = "http://webdefence.global.blackspider.com..."

6. Result:
   ├─ ProxyEnabled = TRUE (Bit 1 set)
   ├─ ProxyServer = "http://127.20.20.20:3128!"
   ├─ ProxyBypass = "home.crash.co.nz;fh.local;<local>"
   ├─ AutoConfigEnabled = TRUE (Bit 2 set)
   └─ AutoConfigURL = "http://webdefence.global..."
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

## Error Handling

### Invalid Data Detection

```
IF versionSignature != 0x46:
    WARN: Unexpected version signature (should always be 70/0x46)

IF changeCounter is suspiciously large (> 1000000):
    WARN: Counter value seems unreasonable (possible corruption)

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

- [ ] Correctly reads 12-byte fixed header
- [ ] Parses flags as 32-bit integer at offset 0x08
- [ ] Starts variable sections at offset 0x0C
- [ ] Reads ProxyServer length+data sequentially
- [ ] Advances position after each length and data read
- [ ] Reads ProxyBypass length+data at correct offset
- [ ] Reads AutoConfigURL length+data at correct offset
- [ ] Handles zero-length strings without advancing position for data
- [ ] Trims null characters from strings
- [ ] Returns boolean flags correctly
- [ ] Handles all flag combinations (0x00 to 0x0F)
- [ ] Position tracking works correctly through all sections

---

**End of Flowchart Documentation**
