<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="html" encoding="UTF-8" indent="yes"/>

<xsl:template match="/">
  <html>
    <head>
      <title>GPU &amp; ANGLE Configuration Reference</title>
      <style>
        :root { color-scheme: dark; }
        body {
          font-family: system-ui, -apple-system, Arial, sans-serif;
          background: #0f172a;
          color: #e2e8f0;
          margin: 0;
          padding: 0;
          line-height: 1.6;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; padding-top: 80px; }

        /* Sticky Navigation */
        .sticky-nav {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          background: #1e293b;
          border-bottom: 2px solid #334155;
          z-index: 1000;
          transition: all 0.3s ease;
        }

        .sticky-nav.collapsed {
          padding: 8px 0;
        }

        .nav-content {
          max-width: 1200px;
          margin: 0 auto;
          padding: 12px 20px;
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .nav-title {
          font-size: 1.2em;
          font-weight: 600;
          color: #93c5fd;
          margin: 0;
        }

        .nav-links {
          display: flex;
          gap: 20px;
          transition: all 0.3s ease;
        }

        .nav-links.collapsed {
          gap: 12px;
        }

        .nav-links a {
          color: #94a3b8;
          text-decoration: none;
          padding: 6px 12px;
          border-radius: 4px;
          transition: all 0.2s;
          font-size: 0.9em;
        }

        .nav-links a:hover {
          background: #334155;
          color: #e2e8f0;
        }
        h1 { color: #93c5fd; border-bottom: 2px solid #334155; padding-bottom: 12px; }
        h2 { color: #60a5fa; margin-top: 32px; }
        h3 { color: #93c5fd; margin-top: 20px; }
        h4 { color: #94a3b8; margin-top: 16px; }

        .metadata {
          background: #1e293b;
          border: 1px solid #334155;
          border-radius: 8px;
          padding: 16px;
          margin-bottom: 24px;
        }

        .metadata-grid {
          display: grid;
          grid-template-columns: 150px 1fr;
          gap: 8px;
        }

        .metadata-label {
          color: #94a3b8;
          font-weight: 500;
        }

        .metadata-value {
          color: #e2e8f0;
        }

        .gpu-card {
          background: #1e293b;
          border: 1px solid #334155;
          border-left: 4px solid #3b82f6;
          border-radius: 8px;
          padding: 20px;
          margin-bottom: 24px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        }

        .gpu-card.intel { border-left-color: #0ea5e9; }
        .gpu-card.nvidia { border-left-color: #10b981; }
        .gpu-card.amd { border-left-color: #f43f5e; }
        .gpu-card.default { border-left-color: #94a3b8; }

        .gpu-header {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-bottom: 16px;
        }

        .gpu-icon {
          font-size: 2em;
        }

        .gpu-title {
          flex: 1;
        }

        .gpu-title h3 {
          margin: 0;
          color: #93c5fd;
        }

        .gpu-subtitle {
          color: #94a3b8;
          font-size: 0.9em;
        }

        .info-grid {
          display: grid;
          grid-template-columns: 180px 1fr;
          gap: 12px 20px;
          margin: 16px 0;
        }

        .info-label {
          color: #94a3b8;
          font-weight: 500;
        }

        .info-value {
          color: #e2e8f0;
        }

        .badge {
          display: inline-block;
          padding: 4px 12px;
          border-radius: 12px;
          font-size: 0.85em;
          font-weight: 600;
          margin-right: 8px;
        }

        .badge.recommended { background: #22c55e; color: #0f172a; }
        .badge.fallback { background: #f59e0b; color: #0f172a; }
        .badge.excellent { background: #10b981; color: white; }
        .badge.good { background: #3b82f6; color: white; }
        .badge.acceptable { background: #f59e0b; color: white; }
        .badge.poor { background: #ef4444; color: white; }

        .severity-high { color: #ef4444; font-weight: 600; }
        .severity-medium { color: #f59e0b; font-weight: 600; }
        .severity-low { color: #3b82f6; font-weight: 600; }

        .issue-box {
          background: #0f172a;
          border: 1px solid #334155;
          border-radius: 6px;
          padding: 12px;
          margin: 8px 0;
        }

        .issue-problem {
          font-weight: 600;
          color: #e2e8f0;
          margin-bottom: 6px;
        }

        .issue-solution {
          color: #94a3b8;
          font-style: italic;
          margin-left: 16px;
        }

        .performance-table {
          width: 100%;
          border-collapse: collapse;
          margin: 12px 0;
        }

        .performance-table th {
          background: #0f172a;
          color: #93c5fd;
          padding: 10px;
          text-align: left;
          border-bottom: 2px solid #334155;
        }

        .performance-table td {
          padding: 10px;
          border-bottom: 1px solid #334155;
        }

        .performance-table tr:last-child td {
          border-bottom: none;
        }

        .backend-card {
          background: #1e293b;
          border: 1px solid #334155;
          border-radius: 6px;
          padding: 16px;
          margin-bottom: 16px;
        }

        .backend-name {
          color: #60a5fa;
          font-size: 1.1em;
          font-weight: 600;
          margin-bottom: 8px;
        }

        .backend-desc {
          color: #94a3b8;
          font-style: italic;
          margin-bottom: 12px;
        }

        .pros-cons {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 16px;
          margin-top: 12px;
        }

        .pros, .cons {
          padding: 12px;
          border-radius: 4px;
        }

        .pros {
          background: rgba(34, 197, 94, 0.1);
          border-left: 3px solid #22c55e;
        }

        .cons {
          background: rgba(239, 68, 68, 0.1);
          border-left: 3px solid #ef4444;
        }

        .pros h4, .cons h4 {
          margin: 0 0 8px 0;
          font-size: 0.9em;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }

        .pros h4 { color: #22c55e; }
        .cons h4 { color: #ef4444; }

        a {
          color: #60a5fa;
          text-decoration: none;
        }

        a:hover {
          text-decoration: underline;
        }

        .toc {
          background: #1e293b;
          border: 1px solid #334155;
          border-radius: 8px;
          padding: 20px;
          margin-bottom: 32px;
        }

        .toc h2 {
          margin-top: 0;
        }

        .toc ul {
          list-style: none;
          padding-left: 0;
        }

        .toc li {
          padding: 4px 0;
        }
      </style>
    </head>
    <body>
      <!-- Sticky Navigation -->
      <nav class="sticky-nav" id="stickyNav">
        <div class="nav-content">
          <h1 class="nav-title">🎮 GPU &amp; ANGLE Config</h1>
          <div class="nav-links" id="navLinks">
            <a href="#summary-table">Summary</a>
            <a href="#gpu-configs">GPU Configs</a>
            <a href="#angle-backends">Backends</a>
            <a href="#browser-info">Browsers</a>
          </div>
        </div>
      </nav>

      <div class="container">
        <!-- Metadata -->
        <div class="metadata">
          <div class="metadata-grid">
            <div class="metadata-label">Version:</div>
            <div class="metadata-value"><xsl:value-of select="/configuration/metadata/version"/></div>

            <div class="metadata-label">Last Updated:</div>
            <div class="metadata-value"><xsl:value-of select="/configuration/metadata/lastUpdated"/></div>

            <div class="metadata-label">Description:</div>
            <div class="metadata-value"><xsl:value-of select="/configuration/metadata/description"/></div>
          </div>
        </div>

        <!-- Quick Reference Summary Table -->
        <h2 id="summary-table">📊 Quick Reference Summary</h2>
        <xsl:call-template name="summaryTable"/>

        <!-- GPU Configurations -->
        <h2 id="gpu-configs">🖥️ GPU Configurations</h2>
        <xsl:apply-templates select="/configuration/gpuConfigs/gpu"/>

        <!-- ANGLE Backends -->
        <h2 id="angle-backends">⚙️ ANGLE Backends</h2>
        <xsl:apply-templates select="/configuration/angleBackends/backend"/>

        <!-- Browser Information -->
        <h2 id="browser-info">🌐 Browser Information</h2>
        <xsl:apply-templates select="/configuration/browsers/browser"/>

      </div>

      <!-- Scroll Handler Script -->
      <script>
        <xsl:text disable-output-escaping="yes">
        <![CDATA[
        // Sticky nav collapse on scroll
        const stickyNav = document.getElementById('stickyNav');
        const navLinks = document.getElementById('navLinks');
        let isCollapsed = false;

        window.addEventListener('scroll', () => {
          if (window.scrollY > 100 && !isCollapsed) {
            stickyNav.classList.add('collapsed');
            navLinks.classList.add('collapsed');
            isCollapsed = true;
          } else if (window.scrollY <= 100 && isCollapsed) {
            stickyNav.classList.remove('collapsed');
            navLinks.classList.remove('collapsed');
            isCollapsed = false;
          }
        });

        // Smooth scroll for nav links
        document.querySelectorAll('.nav-links a').forEach(link => {
          link.addEventListener('click', (e) => {
            e.preventDefault();
            const target = document.querySelector(link.getAttribute('href'));
            if (target) {
              const offset = 80; // Account for fixed nav
              const targetPos = target.offsetTop - offset;
              window.scrollTo({
                top: targetPos,
                behavior: 'smooth'
              });
            }
          });
        });
        ]]>
        </xsl:text>
      </script>
    </body>
  </html>
</xsl:template>

<!-- Summary Table Template (Generated from gpuConfigs) -->
<xsl:template name="summaryTable">
  <div style="background:#1e293b;border:1px solid #334155;border-radius:8px;padding:20px;margin-bottom:24px;overflow-x:auto;">
    <p style="color:#94a3b8;margin:0 0 16px;font-size:0.95em;">
      Quick reference for ANGLE backend recommendations and known issues by GPU type.
    </p>
    <table style="width:100%;border-collapse:collapse;background:#0f172a;border-radius:6px;overflow:hidden;">
      <thead>
        <tr style="background:#1e293b;">
          <th style="padding:12px;text-align:left;border-bottom:2px solid #334155;color:#93c5fd;font-weight:600;">GPU</th>
          <th style="padding:12px;text-align:left;border-bottom:2px solid #334155;color:#93c5fd;font-weight:600;">Recommended Backend</th>
          <th style="padding:12px;text-align:left;border-bottom:2px solid #334155;color:#93c5fd;font-weight:600;">Known Issues</th>
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="/configuration/gpuConfigs/gpu[@displayName]">
          <tr>
            <xsl:if test="position() mod 2 = 0">
              <xsl:attribute name="style">background:#1e293b;</xsl:attribute>
            </xsl:if>
            <td style="padding:12px;border-bottom:1px solid #334155;font-weight:600;color:#e2e8f0;">
              <xsl:value-of select="@displayName"/>
            </td>
            <td style="padding:12px;border-bottom:1px solid #334155;">
              <span style="display:inline-block;background:#22c55e;color:#0f172a;padding:4px 10px;border-radius:4px;font-size:0.85em;font-weight:600;">
                <xsl:value-of select="recommended"/>
              </span>
            </td>
            <td style="padding:12px;border-bottom:1px solid #334155;color:#94a3b8;font-size:0.85em;line-height:1.6;">
              <xsl:choose>
                <xsl:when test="issues/issue">
                  <ul style="margin:0;padding-left:20px;">
                    <xsl:for-each select="issues/issue">
                      <li style="margin:4px 0;">
                        <a href="#{generate-id(.)}" style="color:#60a5fa;text-decoration:none;">
                          <xsl:value-of select="problem"/>
                        </a>
                        <xsl:if test="@context='cesium'">
                          <span style="background:#f59e0b;color:#0f172a;padding:1px 6px;border-radius:3px;font-size:0.75em;font-weight:600;margin-left:6px;">PROPELLER</span>
                        </xsl:if>
                      </li>
                    </xsl:for-each>
                  </ul>
                </xsl:when>
                <xsl:otherwise>
                  <span style="color:#22c55e;">No known issues</span>
                </xsl:otherwise>
              </xsl:choose>
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </div>
</xsl:template>

<!-- GPU Configuration Template -->
<xsl:template match="gpu">
  <xsl:variable name="vendorLower" select="translate(@vendor, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"/>
  <div class="gpu-card {$vendorLower}">
    <div class="gpu-header">
      <div class="gpu-icon">
        <xsl:choose>
          <xsl:when test="@vendor='Intel'">🔷</xsl:when>
          <xsl:when test="@vendor='NVIDIA'">🟢</xsl:when>
          <xsl:when test="@vendor='AMD'">🔴</xsl:when>
          <xsl:otherwise>💻</xsl:otherwise>
        </xsl:choose>
      </div>
      <div class="gpu-title">
        <h3><xsl:value-of select="@vendor"/> <xsl:value-of select="@model"/></h3>
        <div class="gpu-subtitle">
          <span class="badge recommended">Recommended: <xsl:value-of select="recommended"/></span>
          <xsl:if test="fallback">
            <span class="badge fallback">Fallback: <xsl:value-of select="fallback"/></span>
          </xsl:if>
        </div>
      </div>
    </div>

    <div class="info-grid">
      <xsl:if test="notes">
        <div class="info-label">Notes:</div>
        <div class="info-value"><xsl:value-of select="notes"/></div>
      </xsl:if>

      <xsl:if test="driverLink">
        <div class="info-label">Driver Download:</div>
        <div class="info-value">
          <a href="{driverLink}" target="_blank">
            <xsl:value-of select="driverLink"/>
          </a>
        </div>
      </xsl:if>
    </div>

    <!-- Performance -->
    <xsl:if test="performance/backend">
      <h4>Performance Ratings</h4>
      <table class="performance-table">
        <thead>
          <tr>
            <th>Backend</th>
            <th>Rating</th>
            <th>FPS Range</th>
            <th>Notes</th>
          </tr>
        </thead>
        <tbody>
          <xsl:for-each select="performance/backend">
            <tr>
              <td><strong><xsl:value-of select="@name"/></strong></td>
              <td>
                <span class="badge {translate(@rating, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')}">
                  <xsl:value-of select="@rating"/>
                </span>
              </td>
              <td><xsl:value-of select="@fps"/></td>
              <td><xsl:value-of select="."/></td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </xsl:if>

    <!-- Issues -->
    <xsl:if test="issues/issue">
      <h4>Known Issues</h4>
      <xsl:for-each select="issues/issue">
        <div class="issue-box" id="{generate-id(.)}">
          <div class="issue-problem">
            <span class="severity-{@severity}">
              <xsl:choose>
                <xsl:when test="@severity='high'">🔴 HIGH</xsl:when>
                <xsl:when test="@severity='medium'">🟠 MEDIUM</xsl:when>
                <xsl:when test="@severity='low'">🔵 LOW</xsl:when>
              </xsl:choose>
            </span>
            &#160;
            <xsl:value-of select="problem"/>
            <xsl:if test="@context='cesium'">
              <span style="background:#f59e0b;color:#0f172a;padding:2px 8px;border-radius:3px;font-size:0.75em;font-weight:600;margin-left:8px;">⚠️ PROPELLER</span>
            </xsl:if>
          </div>
          <div class="issue-solution">
            💡 Solution: <xsl:value-of select="solution"/>
          </div>
          <xsl:if test="affectedVersions">
            <div style="color:#64748b;font-size:0.85em;margin-top:4px;">
              Affects: <xsl:value-of select="affectedVersions"/>
            </div>
          </xsl:if>
        </div>
      </xsl:for-each>
    </xsl:if>
  </div>
</xsl:template>

<!-- ANGLE Backend Template -->
<xsl:template match="angleBackends/backend">
  <div class="backend-card">
    <div class="backend-name"><xsl:value-of select="@name"/></div>
    <div class="backend-desc"><xsl:value-of select="description"/></div>

    <div class="pros-cons">
      <div class="pros">
        <h4>✅ Pros</h4>
        <p><xsl:value-of select="pros"/></p>
      </div>
      <div class="cons">
        <h4>❌ Cons</h4>
        <p><xsl:value-of select="cons"/></p>
      </div>
    </div>

    <div style="margin-top:12px;color:#94a3b8;font-size:0.9em;">
      <strong>Recommended for:</strong> <xsl:value-of select="recommendedFor"/>
    </div>
  </div>
</xsl:template>

<!-- Browser Template -->
<xsl:template match="browsers/browser">
  <div class="backend-card">
    <div class="backend-name"><xsl:value-of select="@name"/></div>
    <div class="info-grid">
      <div class="info-label">Flags URL:</div>
      <div class="info-value"><code><xsl:value-of select="flagsUrl"/></code></div>

      <div class="info-label">GPU Info URL:</div>
      <div class="info-value"><code><xsl:value-of select="gpuUrl"/></code></div>

      <div class="info-label">Notes:</div>
      <div class="info-value"><xsl:value-of select="notes"/></div>
    </div>
  </div>
</xsl:template>

</xsl:stylesheet>
