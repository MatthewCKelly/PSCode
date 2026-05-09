// ── FLYBY EXPORT  v2.1 ───────────────────────────────────────────
// Paste into DevTools console on the Strava Flyby page.
//
// Immediately exports all flyby athletes, then leaves FlybyExport
// available in the console so you can add extra riders and re-download.
//
//  After pasting, use these console commands:
//
//   FlybyExport.list()
//     → show all currently loaded athletes
//
//   FlybyExport.addRider('12345678901')
//     → fetch an extra rider by Strava activity ID and queue them
//
//   FlybyExport.addRider('12345678901', 'Sam', '#ff0000')
//     → same, with a custom name and colour
//
//   FlybyExport.download()
//     → download the current athlete list (including any additions)
//
//   FlybyExport.remove(2)
//     → drop athlete at index 2 (use .list() to find the index)
//
// ─────────────────────────────────────────────────────────────────

var FlybyExport = (function () {

  var COLORS = [
    '#fc5200','#4fc3f7','#81c784','#ffb74d','#f48fb1',
    '#ce93d8','#80deea','#a5d6a7','#ef9a9a','#90caf9',
    '#ffe082','#bcaaa4','#b0bec5','#c5e1a5','#ffcc02'
  ];

  // ── helpers ──────────────────────────────────────────────────────

  function getPoints(model) {
    var dm = model.data;
    if (!dm) return null;
    var pts = (typeof dm.get === 'function') ? dm.get('data') : null;
    if (!Array.isArray(pts) && dm.attributes) pts = dm.attributes.data;
    return (Array.isArray(pts) && pts.length > 1) ? pts : null;
  }

  function buildAthlete(model, idx, nameOverride, colorOverride) {
    var attr  = model.attributes || {};
    var pts   = getPoints(model);
    var name  = nameOverride
              || attr.shortFirstName
              || (attr.athlete && attr.athlete.firstName)
              || attr.name
              || ('Athlete ' + (idx + 1));
    var color     = colorOverride || attr.streamColor || COLORS[idx % COLORS.length];
    var actId     = String(model.id || idx);
    var athleteId = attr.athleteId != null ? String(attr.athleteId) : null;

    if (!pts) {
      console.warn('[FlybyExport]  ✗ ' + name + ' — no data');
      return null;
    }

    var startTime = pts[0].time;
    var latlng = [], time = [], altitude = [];
    pts.forEach(function (p) {
      if (!p || !p.point || p.time == null) return;
      latlng.push([p.point.lat, p.point.lng]);
      time.push(Math.round(p.time - startTime));
      altitude.push(p.elevation != null ? p.elevation : null);
    });

    console.log('[FlybyExport]  ✓ ' + name
      + '  athleteId:' + (athleteId || '—')
      + '  actId:' + actId
      + '  ' + latlng.length + ' pts'
      + '  ' + new Date(startTime * 1000).toLocaleTimeString());

    return { id: actId, athleteId: athleteId, name: name, color: color,
             startTime: startTime,
             streams: { latlng: latlng, time: time, altitude: altitude } };
  }

  function doDownload(athletes) {
    if (!athletes.length) { console.error('[FlybyExport] Nothing to download'); return; }
    var json = JSON.stringify(athletes, null, 2);
    var a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
    a.download = 'flyby-export-' + Date.now() + '.json';
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    console.log('[FlybyExport] Downloaded: ' + athletes.length + ' athletes · '
      + Math.round(json.length / 1024) + ' KB  →  flyby-export-*.json');
  }

  // ── initial load: fetch missing streams then export ───────────────

  var models  = window.flyby.results.activities.models;
  var missing = models.filter(function (m) { return !getPoints(m); });

  function buildAndDownload() {
    var athletes = models.map(function (m, i) { return buildAthlete(m, i); }).filter(Boolean);
    api.athletes = athletes;
    doDownload(athletes);
    console.log('');
    console.log('%c FlybyExport is ready ', 'background:#fc5200;color:#fff;font-weight:bold;border-radius:3px');
    console.log('  FlybyExport.list()                          — show loaded athletes');
    console.log('  FlybyExport.addRider("ACTIVITY_ID")         — fetch & queue extra rider');
    console.log('  FlybyExport.addRider("ID", "Name", "#hex")  — with custom name / colour');
    console.log('  FlybyExport.download()                      — re-download updated list');
    console.log('  FlybyExport.remove(index)                   — drop athlete by index');
  }

  if (missing.length) {
    console.log('[FlybyExport] ' + models.length + ' athletes — fetching '
      + missing.length + ' unloaded stream(s)...');
    var fetches = missing.map(function (m) {
      console.log('[FlybyExport]  fetching: ' + (m.attributes.shortFirstName || m.attributes.name || m.id));
      return new Promise(function (resolve) {
        if (m.data && typeof m.data.fetch === 'function') {
          m.data.fetch({ success: resolve, error: resolve });
        } else { resolve(); }
      });
    });
    Promise.all(fetches).then(buildAndDownload);
  } else {
    buildAndDownload();
  }

  // ── public API ────────────────────────────────────────────────────

  var api = {
    athletes: [],

    list: function () {
      if (!api.athletes.length) { console.log('[FlybyExport] No athletes loaded'); return; }
      console.log('[FlybyExport] ' + api.athletes.length + ' athlete(s):');
      api.athletes.forEach(function (a, i) {
        console.log('  [' + i + '] ' + a.name
          + '  id:' + a.id
          + (a.athleteId ? '  athleteId:' + a.athleteId : '')
          + '  ' + a.streams.time.length + ' pts'
          + '  color:' + a.color);
      });
    },

    addRider: function (activityId, name, color) {
      var actIdStr = String(activityId).trim();
      var idx = api.athletes.length;

      if (!models.length) {
        console.error('[FlybyExport] No reference model available');
        return Promise.reject(new Error('No models'));
      }

      var ref = models[0];
      if (!ref.data || !ref.data.constructor) {
        console.error('[FlybyExport] Cannot determine flyby data model class');
        return Promise.reject(new Error('No DataClass'));
      }

      var ModelClass = ref.constructor;
      var DataClass  = ref.data.constructor;
      var newModel   = new ModelClass({ id: actIdStr });
      newModel.data  = new DataClass({ id: actIdStr });

      console.log('[FlybyExport] Fetching activity ' + actIdStr + '...');

      return new Promise(function (resolve, reject) {
        newModel.data.fetch({
          success: function () {
            var athlete = buildAthlete(newModel, idx, name, color);
            if (!athlete) { reject(new Error('No usable GPS data')); return; }
            api.athletes.push(athlete);
            console.log('[FlybyExport] Added "' + athlete.name + '" — call FlybyExport.download() to save');
            resolve(athlete);
          },
          error: function (m, resp) {
            var status = resp && resp.status;
            if (status === 404) {
              console.error('[FlybyExport] Activity ' + actIdStr
                + ' not found in this flyby match — only matched activities can be fetched this way');
            } else {
              console.error('[FlybyExport] Fetch failed for ' + actIdStr
                + ' (HTTP ' + (status || '?') + ')');
            }
            reject(new Error('HTTP ' + status));
          }
        });
      });
    },

    download: function () { doDownload(api.athletes); },

    remove: function (idxOrId) {
      var before = api.athletes.length;
      api.athletes = api.athletes.filter(function (a, i) {
        return i !== Number(idxOrId) && a.id !== String(idxOrId);
      });
      console.log('[FlybyExport] Removed ' + (before - api.athletes.length) + ' athlete(s)');
    }
  };

  return api;

})();
