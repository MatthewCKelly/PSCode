# GPU & ANGLE Configuration System

## Overview

This system provides automatic GPU detection and ANGLE backend configuration recommendations for WebGL rendering in browsers. It consists of a web-based detection tool with an external XML configuration file that can be updated without modifying the HTML code.

## Files

### 1. `gpu-angle-config.html`
**Main configuration tool** - Detects GPU and displays recommendations

**Features:**
- 🔍 Automatic GPU detection (Intel Arc, NVIDIA, AMD, integrated graphics)
- ⚙️ ANGLE backend detection and analysis
- 📋 Configuration recommendations based on detected hardware
- 🌐 Browser-specific instructions (Chrome, Edge, Firefox)
- ✅ Visual status indicators (optimal/needs configuration)
- 💾 Loads recommendations from external XML

**How to Use:**
```bash
# Open in browser
start Dev/gpu-angle-config.html

# Or from web server
http://localhost/gpu-angle-config.html
```

### 2. `gpu-angle-config.xml`
**Configuration database** - Contains GPU-specific recommendations

**Structure:**
```xml
<configuration>
  <metadata>
    <version>1.0</version>
    <lastUpdated>2025-12-02</lastUpdated>
  </metadata>

  <gpuConfigs>
    <gpu vendor="Intel" model="Arc">
      <recommended>D3D11</recommended>
      <fallback>D3D11 WARP</fallback>
      <notes>...</notes>
      <issues>
        <issue severity="medium">
          <problem>...</problem>
          <solution>...</solution>
        </issue>
      </issues>
      <performance>
        <backend name="D3D11" rating="excellent" fps="60+">...</backend>
      </performance>
    </gpu>
  </gpuConfigs>

  <angleBackends>...</angleBackends>
  <browsers>...</browsers>
</configuration>
```

**Supported GPUs:**
- Intel Arc (A770, A750, A380, etc.)
- Intel UHD (Integrated)
- Intel Iris Xe (Integrated)
- NVIDIA RTX/GTX
- AMD Radeon
- Default/Unknown

### 3. `gpu-angle-config.xsl`
**XSLT stylesheet** - Transforms XML for human-readable viewing

**How to View:**
1. Open `gpu-angle-config.xml` directly in browser
2. XSLT will automatically format the configuration
3. Provides styled reference documentation

## Workflow

### User Perspective

1. **Open Configuration Tool**
   ```
   start gpu-angle-config.html
   ```

2. **System Detects Hardware**
   - Browser type
   - GPU vendor and model
   - Current ANGLE backend
   - WebGL version

3. **Recommendations Displayed**
   - ✅ Optimal: Current config matches recommendation
   - ⚠️ Needs Configuration: Change recommended
   - Specific instructions for your browser

4. **Follow Instructions**
   - Click browser tab (Chrome/Edge/Firefox)
   - Follow step-by-step guide
   - Click "Open Flags" button
   - Apply recommended backend
   - Relaunch browser

### Administrator Perspective

**Updating Recommendations (No Code Changes Required):**

1. **Edit XML File**
   ```xml
   <!-- Add new GPU configuration -->
   <gpu vendor="Intel" model="Arc">
     <recommended>D3D11on12</recommended>  <!-- Changed from D3D11 -->
     <fallback>D3D11</fallback>
     <notes>Updated for new driver version 32.0...</notes>
   </gpu>
   ```

2. **Save XML File**
   - No need to modify HTML
   - Changes take effect immediately
   - Version control friendly

3. **Test Changes**
   - Refresh `gpu-angle-config.html`
   - New recommendations load automatically

## Configuration Guide

### Adding a New GPU

```xml
<gpu vendor="NewVendor" model="NewModel">
  <recommended>D3D11</recommended>
  <fallback>D3D11 WARP</fallback>
  <notes>Description and general guidance</notes>
  <driverLink>https://driver-download-url</driverLink>

  <issues>
    <issue severity="medium">
      <problem>Describe the issue</problem>
      <solution>How to fix it</solution>
      <affectedVersions>Which versions are affected</affectedVersions>
    </issue>
  </issues>

  <performance>
    <backend name="D3D11" rating="excellent" fps="60+">
      Performance notes
    </backend>
    <backend name="D3D11 WARP" rating="acceptable" fps="30-45">
      Fallback performance
    </backend>
  </performance>
</gpu>
```

### Severity Levels

- **high** 🔴 - Critical issues affecting functionality
- **medium** 🟠 - Notable issues with workarounds
- **low** 🔵 - Minor issues or optimizations

### Rating Scale

- **excellent** - 60+ FPS, production-ready
- **good** - 45-60 FPS, suitable for most use cases
- **acceptable** - 30-45 FPS, usable but not optimal
- **poor** - <30 FPS, not recommended

## Detection Logic

### GPU Matching Algorithm

1. **Vendor Match**
   - Checks WebGL vendor string
   - Case-insensitive comparison
   - Supports partial matches

2. **Model Match**
   - Checks renderer string for model
   - Supports wildcards (`*`)
   - Prioritizes specific matches over wildcards

3. **Fallback**
   - If no match found, uses default config
   - Provides generic recommendations

**Example Detection:**
```javascript
// Detected: "ANGLE (Intel, Intel(R) Arc(TM) A770 Graphics Direct3D11...)"
// Matches: <gpu vendor="Intel" model="Arc">
```

### ANGLE Backend Detection

Detects from renderer string:
- `D3D11` - Contains "d3d11" or "direct3d11"
- `D3D11on12` - Contains "d3d11on12"
- `D3D9` - Contains "d3d9"
- `D3D11 WARP` - Contains "warp"
- `OpenGL` - Contains "opengl"
- `Metal` - Contains "metal" (macOS)

## Browser Support

### Fully Supported
✅ **Chrome** (Windows, macOS, Linux)
✅ **Edge** (Windows, macOS, Linux)
✅ **Firefox** (Windows - with limitations)

### Limited Support
⚠️ **Safari** (macOS/iOS - uses Metal, not ANGLE)
⚠️ **Firefox** (macOS/Linux - no ANGLE backend control)

### Enterprise Restrictions
🔒 Some organizations block `WEBGL_debug_renderer_info` extension for privacy
- Vendor/renderer will show generic strings
- Default configuration will be used
- Manual GPU selection not available

## Common Use Cases

### Case 1: Intel Arc Line Rendering Issue

**Problem:** Lines appear curved instead of straight

**Detection:**
- GPU: Intel Arc A770
- Backend: D3D11
- Status: ⚠️ Needs Configuration

**Recommendation:**
1. Update Intel Arc drivers to 31.0.101.5333+
2. If issue persists, switch to D3D11 WARP
3. Performance impact: Acceptable (30-45 FPS)

### Case 2: NVIDIA GPU Optimal Config

**Problem:** No issues, verification needed

**Detection:**
- GPU: NVIDIA RTX 3080
- Backend: D3D11
- Status: ✅ Optimal

**Recommendation:**
- Current configuration is optimal
- No changes needed

### Case 3: Unknown GPU

**Problem:** Enterprise policy masks GPU info

**Detection:**
- GPU: Masked (Policy Restricted)
- Backend: Unknown
- Status: Unknown

**Recommendation:**
- Use default D3D11 backend
- Contact IT if experiencing issues
- Try D3D11 WARP as fallback

## Maintenance

### Updating Driver Links

When GPU vendors release new drivers:

```xml
<gpu vendor="Intel" model="Arc">
  <!-- Update driver link -->
  <driverLink>https://www.intel.com/...new-version...</driverLink>
</gpu>
```

### Updating Issue Workarounds

When new driver fixes issues:

```xml
<issue severity="low">  <!-- Reduced from "medium" -->
  <problem>Curved line rendering with D3D11</problem>
  <solution>Fixed in driver 32.0.101.5555+</solution>
  <affectedVersions>Driver versions before 32.0.101.5555</affectedVersions>
</issue>
```

### Deprecating Old Backends

When backends are no longer recommended:

```xml
<backend name="D3D9">
  <description>Direct3D 9 - Legacy rendering backend (DEPRECATED)</description>
  <pros>Maximum compatibility</pros>
  <cons>Deprecated, will be removed in future browser versions</cons>
  <recommendedFor>Legacy hardware only - migrate to D3D11</recommendedFor>
</backend>
```

## Testing

### Manual Testing Checklist

1. ✅ Open `gpu-angle-config.html` in different browsers
2. ✅ Verify GPU detection shows correct hardware
3. ✅ Check ANGLE backend detection
4. ✅ Confirm recommendations match XML config
5. ✅ Test browser tab switching (Chrome/Edge/Firefox)
6. ✅ Click "Open Flags" links (verify they work)
7. ✅ View XML directly to test XSLT transformation

### Test GPUs

- Intel Arc A770 (discrete)
- Intel UHD 630 (integrated)
- NVIDIA RTX 3080
- AMD Radeon RX 6800
- Software renderer (WARP)

### Test Browsers

- Chrome 120+
- Edge 120+
- Firefox 120+

## Troubleshooting

### Issue: XML Not Loading

**Symptoms:** Recommendations show "No Specific Configuration Found"

**Causes:**
1. XML file not in same directory as HTML
2. CORS policy blocking file access
3. XML parsing error

**Solutions:**
```bash
# Verify file location
ls -la Dev/gpu-angle-config.xml

# Check browser console for errors
F12 -> Console tab -> Look for fetch/XML errors

# Test from web server (not file://)
python -m http.server 8000
# Navigate to http://localhost:8000/Dev/gpu-angle-config.html
```

### Issue: GPU Not Detected

**Symptoms:** GPU shows "Masked (Policy Restricted)"

**Causes:**
1. Browser policy blocks debug extension
2. WebGL disabled
3. GPU blacklisted

**Solutions:**
- Check `chrome://gpu` for GPU status
- Verify WebGL works at https://get.webgl.org/
- Contact IT about GPU info restrictions

### Issue: Wrong Recommendations

**Symptoms:** Recommendations don't match hardware

**Causes:**
1. XML not updated
2. Detection logic needs adjustment
3. GPU model not in database

**Solutions:**
1. Check XML file version and lastUpdated date
2. Add new GPU configuration to XML
3. Use default config as fallback

## Integration

### Embedding in Web Applications

```html
<!-- Minimal embedding example -->
<iframe
  src="gpu-angle-config.html"
  width="100%"
  height="800px"
  frameborder="0">
</iframe>
```

### Programmatic Access

```javascript
// Load configuration programmatically
async function getGPURecommendation() {
  const response = await fetch('gpu-angle-config.xml');
  const xmlText = await response.text();
  const parser = new DOMParser();
  const xmlDoc = parser.parseFromString(xmlText, 'text/xml');

  // Access configuration data
  const gpus = xmlDoc.querySelectorAll('gpu');
  // ... process recommendations
}
```

## Version History

### Version 1.0 (2025-12-02)
- Initial release
- Intel Arc GPU support with driver-specific guidance
- NVIDIA RTX/GTX configurations
- AMD Radeon configurations
- Browser-specific instructions
- XML-based configuration system
- XSLT transformation for reference viewing

## Contributing

### Adding New GPU Configurations

1. Research GPU-specific ANGLE issues
2. Test different backends on actual hardware
3. Document FPS ranges and issues
4. Add configuration to XML
5. Test detection in HTML tool
6. Update this README if needed

### XML Schema

See inline comments in `gpu-angle-config.xml` for field descriptions and examples.

## Resources

### Official Documentation
- [ANGLE Project](https://chromium.googlesource.com/angle/angle)
- [WebGL Specification](https://www.khronos.org/webgl/)
- [Chrome GPU Flags](https://peter.sh/experiments/chromium-command-line-switches/)

### GPU Driver Downloads
- [Intel Arc/UHD/Iris Drivers](https://www.intel.com/content/www/us/en/download/785597/)
- [NVIDIA Drivers](https://www.nvidia.com/Download/index.aspx)
- [AMD Radeon Drivers](https://www.amd.com/en/support)

### Browser GPU Information
- Chrome: `chrome://gpu`
- Edge: `edge://gpu`
- Firefox: `about:support` (Graphics section)

---

**Maintained by:** PSCode Repository
**Last Updated:** 2025-12-02
**License:** MIT (or your license)
