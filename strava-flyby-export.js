// ── FLYBY QUICK EXPORT ───────────────────────────────────────────
// Paste into DevTools console on the Strava Flyby page.
//
// Fetches GPS data for every athlete (triggers load for any that
// haven't been fetched yet), then downloads flyby-export-*.json
// ready to load into strava-flyby-offline.html
//
// Each athlete stream includes: latlng, time, altitude
// ─────────────────────────────────────────────────────────────────

(function () {
  var COLORS = ['#fc5200','#4fc3f7','#81c784','#ffb74d','#f48fb1','#ce93d8','#80deea','#a5d6a7','#ef9a9a','#90caf9'];

  function getPoints(model) {
    var dm = model.data;
    if (!dm) return null;
    var pts = (typeof dm.get === 'function') ? dm.get('data') : null;
    if (!Array.isArray(pts) && dm.attributes) pts = dm.attributes.data;
    return (Array.isArray(pts) && pts.length > 1) ? pts : null;
  }

  function buildAthlete(model, idx) {
    var attr      = model.attributes;
    var points    = getPoints(model);
    var name      = attr.shortFirstName || (attr.athlete && attr.athlete.firstName) || attr.name || ('Athlete ' + idx);
    var color     = attr.streamColor || COLORS[idx % COLORS.length];
    var actId     = String(model.id || idx);
    var athleteId = attr.athleteId != null ? String(attr.athleteId) : null;

    if (!points) {
      console.warn('[Export] ' + name + ' (idx ' + idx + '): no data');
      return null;
    }

    var startTime = points[0].time;
    var latlng    = [];
    var time      = [];
    var altitude  = [];

    points.forEach(function (p) {
      if (!p || !p.point || p.time == null) return;
      latlng.push([p.point.lat, p.point.lng]);
      time.push(Math.round(p.time - startTime));
      altitude.push(p.elevation != null ? p.elevation : null);
    });

    console.log('[Export] ' + name + '  athleteId:' + (athleteId||'?') + '  actId:' + actId + '  ' + latlng.length + ' pts');

    return {
      id        : actId,
      athleteId : athleteId,
      name      : name,
      color     : color,
      startTime : startTime,
      streams   : { latlng: latlng, time: time, altitude: altitude }
    };
  }

  function download(athletes) {
    if (!athletes.length) { console.error('[Export] Nothing to export'); return; }
    var json = JSON.stringify(athletes, null, 2);
    var a    = document.createElement('a');
    a.href   = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
    a.download = 'flyby-export-' + Date.now() + '.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    console.log('[Export] ✓ ' + athletes.length + ' athletes · ' + Math.round(json.length / 1024) + ' KB');
    console.log('[Export] → Load flyby-export-*.json into strava-flyby-offline.html');
  }

  var models  = window.flyby.results.activities.models;
  var missing = models.filter(function (m) { return !getPoints(m); });

  if (!missing.length) {
    // All data already loaded — export immediately
    var athletes = models.map(buildAthlete).filter(Boolean);
    download(athletes);
    return;
  }

  // Some athletes need fetching — trigger and wait
  console.log('[Export] Fetching data for ' + missing.length + ' unloaded athlete(s)...');

  var fetches = missing.map(function (m) {
    var attr = m.attributes;
    console.log('[Export]  fetching: ' + (attr.shortFirstName || attr.name || m.id));
    return new Promise(function (resolve) {
      if (typeof m.data.fetch === 'function') {
        m.data.fetch({ success: resolve, error: resolve });
      } else {
        resolve();
      }
    });
  });

  Promise.all(fetches).then(function () {
    console.log('[Export] Fetch complete — building export...');
    var athletes = models.map(buildAthlete).filter(Boolean);
    download(athletes);
  });

})();
