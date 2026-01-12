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
│ STEP 1: Read Fixed Header (16 bytes)                            │
├─────────────────────────────────────────────────────────────────┤
│ Offset 0x00 (4 bytes) → Version Signature (usually 0x46)        │
│ Offset 0x04 (4 bytes) → Version/Counter                         │
│ Offset 0x08 (4 bytes) → FLAGS (CRITICAL - determines parsing)   │
│ Offset 0x0C (4 bytes) → Unknown/Reserved                        │
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
│ STEP 3: Read ProxyServer Section (Offset 0x10+)                 │
├─────────────────────────────────────────────────────────────────┤
│ Position = 0x10 (after 16-byte header)                          │
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
│ - VersionSignature                                               │
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

## Parsing Algorithm Pseudocode

```
FUNCTION ParseProxySettings(binaryData):
    // Step 1: Read 16-byte fixed header
    versionSignature = ReadInt32(binaryData, offset=0x00)
    counter = ReadInt32(binaryData, offset=0x04)
    flags = ReadInt32(binaryData, offset=0x08)
    unknown = ReadInt32(binaryData, offset=0x0C)

    // Step 2: Start parsing variable sections at offset 0x10
    position = 0x10  // After 16-byte header

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
        version: counter,
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

### Rule 1: Structure is 16-byte Header + Interleaved Sections
```
┌─────────────────────────────────────┐
│ Fixed Header: 16 bytes (0x00-0x0F) │
│                                     │
│ Variable Sections (from 0x10):     │
│   Section 1: Proxy Length + Data   │
│   Section 2: Bypass Length + Data  │
│   Section 3: AutoCfg Length + Data │
│                                     │
│ NOT all lengths then all data!     │
│ Each section is Length+Data pair   │
└─────────────────────────────────────┘
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
Position starts at 0x10 (after 16-byte header)

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

### Example 1: Auto-Config Only

**Binary Data (hex):**
```
Offset   Hex Data                       Description
───────  ─────────────────────────────  ─────────────────────────
0x00     46 00 00 00                    VersionSig = 0x46 (70)
0x04     4A 01 00 00                    Counter = 330
0x08     01 00 00 00                    Flags = 0x01 (Direct only)
0x0C     00 00 00 00                    Unknown = 0
0x10     01 00 00 00                    ProxyServer Length = 1
0x14     20                             ProxyServer Data = 0x20 (1 byte, space/null)
0x15     42 00 00 00                    ProxyBypass Length = 66 (0x42)
0x19     00 00 ... (66 bytes)           ProxyBypass Data (66 bytes)
0x5B     42 00 00 00                    AutoConfigURL Length = 66
0x5F     68 74 74 70 ...                "http://webdefence.global..." (66 bytes)
```

**Parsing Steps:**
```
1. Read 16-byte header:
   ├─ VersionSignature = 0x46
   ├─ Counter = 330
   ├─ Flags = 0x01 (Direct connection only)
   └─ Unknown = 0

2. Position = 0x10 (16 decimal)

3. Read ProxyServer section:
   ├─ Read length at 0x10 = 1 byte
   ├─ Position = 0x14 (20 decimal)
   ├─ Read 1 byte at 0x14 = 0x20 (space/null)
   └─ Position = 0x15 (21 decimal)

4. Read ProxyBypass section:
   ├─ Read length at 0x15 = 66 bytes (0x42)
   ├─ Position = 0x19 (25 decimal)
   ├─ Read 66 bytes at 0x19
   └─ Position = 0x5B (91 decimal)

5. Read AutoConfigURL section:
   ├─ Read length at 0x5B = 66 bytes (0x42)
   ├─ Position = 0x5F (95 decimal)
   └─ Read 66 bytes at 0x5F = "http://webdefence.global.blackspider.com..."

6. Result:
   ├─ ProxyEnabled = FALSE (Bit 1 clear)
   ├─ ProxyServer = " " (ignored due to flag)
   ├─ ProxyBypass = (66 bytes, but ignored)
   ├─ AutoConfigEnabled = FALSE (Bit 2 clear)
   └─ AutoConfigURL = "http://..." (data present but flag says not enabled)
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

- [ ] Correctly reads 16-byte fixed header
- [ ] Parses flags as 32-bit integer at offset 0x08
- [ ] Starts variable sections at offset 0x10
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
