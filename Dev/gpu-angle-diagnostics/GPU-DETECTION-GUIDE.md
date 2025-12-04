# GPU Detection in Browser - Intel Arc Support

## Overview
The `edge-angle-diagnostics.html` tool now includes comprehensive GPU detection, with specific support for detecting Intel Arc GPUs.

## How It Works

### WebGL Renderer Information
The tool uses the `WEBGL_debug_renderer_info` extension to access GPU details:

```javascript
const dbg = gl.getExtension('WEBGL_debug_renderer_info');
const vendor = gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL);
const renderer = gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL);
```

### Intel Arc Detection
The tool detects Intel Arc GPUs by searching the renderer string for:
- Vendor contains "Intel"
- Renderer contains "Arc"
- Extracts model number (A770, A750, A380, etc.)

**Example renderer strings:**
- `ANGLE (Intel, Intel(R) Arc(TM) A770 Graphics Direct3D11 vs_5_0 ps_5_0, D3D11)`
- `ANGLE (Intel, Intel(R) Arc(TM) A750 Graphics Direct3D11 vs_5_0 ps_5_0, D3D11)`

## Detected GPU Types

### Intel GPUs
- **Intel Arc** (Discrete) - A770, A750, A380, etc.
- **Intel UHD** (Integrated) - UHD 630, 730, etc.
- **Intel Iris** (Integrated) - Iris Xe, Iris Plus

### Other GPUs
- **NVIDIA** - RTX, GTX series
- **AMD** - Radeon RX, Vega series
- **Software Renderers** - SwiftShader, LLVMpipe

## UI Features

### GPU Detection Panel
Shows detected GPU with color coding:
- **Green** - Hardware GPU detected
- **Yellow** - Software renderer (no GPU)
- **Bold** - Intel Arc GPU (highlighted)

### Intel Arc Specific Notes
When Intel Arc is detected, a special panel appears with:
- Driver download link
- ANGLE backend recommendations
- Troubleshooting tips
- Link to `edge://gpu` for diagnostics

## Diagnostics Export

The "Download diagnostics JSON" now includes:

```json
{
  "when": "2025-12-02T...",
  "renderer": {
    "vendor": "Intel Inc.",
    "renderer": "ANGLE (Intel, Intel(R) Arc(TM) A770 Graphics...)",
    ...
  },
  "gpu": {
    "detected": "Intel Arc A770 (Discrete)",
    "angleBackend": "D3D11 (Hardware)",
    "isIntelArc": true
  },
  ...
}
```

## Testing the Tool

1. **Open the tool:**
   ```bash
   start Dev/edge-angle-diagnostics.html
   ```

2. **Check GPU Detection section:**
   - Should show your GPU model immediately
   - Intel Arc users will see special notes panel

3. **Verify renderer info:**
   - Check the "Renderer info" section
   - Full renderer string shown in console

4. **Export diagnostics:**
   - Click "Download diagnostics JSON"
   - Check the `gpu` object for detection results

## Browser Support

### Works In:
- ✅ Chrome/Edge on Windows (with ANGLE)
- ✅ Firefox on Windows
- ✅ Chrome on macOS/Linux
- ✅ Safari (limited - may not have debug extension)

### Privacy Policies:
Some enterprise environments block `WEBGL_debug_renderer_info` for privacy.
In these cases, vendor/renderer will show generic strings like "WebGL Vendor".

## Intel Arc Specific Issues

### Known Issues:
1. **Line rendering** - D3D11 may render curved lines instead of straight
2. **Driver updates** - Older drivers may have WebGL issues
3. **Performance** - First-gen Arc benefits from latest drivers

### Recommended Settings:
- **ANGLE Backend:** D3D11 (Hardware) - best performance
- **Fallback:** D3D11 WARP (Software) - fixes line issues but slower
- **Driver Version:** Latest from Intel Download Center

### Testing Line Rendering:
The tool includes specific line test patterns:
- Radial lines from center
- Diagonal crossing lines
- Horizontal/vertical reference lines
- Bézier curve polylines

If lines appear **curved** when they should be straight:
1. Update Intel Arc drivers
2. Try D3D11 WARP backend (`chrome://flags/#use-angle`)
3. Check `edge://gpu` for GPU feature status

## Code Locations

### Detection Logic
- **Lines 329-391** - GPU detection and classification
- **Lines 340-349** - Intel Arc specific detection
- **Lines 350-360** - Intel integrated graphics
- **Lines 362-379** - NVIDIA, AMD, software renderers

### UI Elements
- **Lines 119-129** - GPU Detection panel HTML
- **Lines 121-129** - Intel Arc notes (shown conditionally)

### Diagnostics Export
- **Lines 1623-1643** - JSON export with GPU data

## Future Enhancements

Potential additions:
- [ ] Detect Intel Arc generation (Alchemist, Battlemage, etc.)
- [ ] Show recommended driver version
- [ ] Detect discrete vs integrated GPU switching
- [ ] Memory size detection (if available)
- [ ] GPU utilization monitoring

## Resources

- [Intel Arc Drivers](https://www.intel.com/content/www/us/en/download/785597/intel-arc-iris-xe-graphics-windows.html)
- [ANGLE Project](https://chromium.googlesource.com/angle/angle)
- [WebGL Debug Extension](https://www.khronos.org/registry/webgl/extensions/WEBGL_debug_renderer_info/)
- [Chrome GPU Flags](chrome://flags/#use-angle)
- [Edge GPU Info](edge://gpu)

---

**Last Updated:** 2025-12-02
**Tool Version:** 1.1 (with GPU detection)
