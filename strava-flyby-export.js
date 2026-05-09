// ── FLYBY EXPORT  v2.0 ───────────────────────────────────────────
// Paste into DevTools console on the Strava Flyby page.
//
// Exports GPS data for every flyby athlete, then optionally lets you
// add extra riders by Strava activity ID (e.g. a friend whose activity
// didn't appear in the flyby match list).
//
// USAGE — paste the whole script, then optionally after it runs:
//   FlybyExport.addRider('12345678901')       // fetch & queue extra rider
//   FlybyExport.addRider('12345678901', 'Sam', '#ff0000')
//   FlybyExport.download()                    // re-download with additions
//   FlybyExport.list()                        // show current athlete list
//
// Streams exported per athlete: latlng, time, altitude
// ─────────────────────────────────────────────────────────────────

window.FlybyExport = (function () {

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
    var attr      = model.attributes || {};
    var points    = getPoints(model);
    var name      = nameOverride ||
                    attr.shortFirstName ||
                    (attr.athlete && attr.athlete.firstName) ||
                    attr.name || ('Athlete ' + (idx + 1));
    var color     = colorOverride || attr.streamColor || COLORS[idx % COLORS.length];
    var actId     = String(model.id || idx);
    var athleteId = attr.athleteId != null ? String(attr.athleteId) : null;

    if (!points) {
      console.warn('[FlybyExport] ' + name + ': no data points');
      return null;
    }

    var startTime = points[0].time;
    var latlng = [], time = [], altitude = [];

    points.forEach(function (p) {
      if (!p || !p.point || p.time == null) return;
      latlng.push([p.point.lat, p.point.lng]);
      time.push(Math.round(p.time - startTime));
      altitude.push(p.elevation != null ? p.elevation : null);
    });

    console.log('[FlybyExport]  ✓ ' + name +
      '  athleteId:' + (athleteId || '—') +
      '  actId:' + actId +
      '  ' + latlng.length + ' pts' +
      '  start:' + new Date(startTime * 1000).toLocaleTimeString());

    return {
      id:        actId,
      athleteId: athleteId,
      name:      name,
      color:     color,
      startTime: startTime,
      streams:   { latlng: latlng, time: time, altitude: altitude }
    };
  }

  function fetchMissing(models) {
    var missing = models.filter(function (m) { return !getPoints(m); });
    if (!missing.length) return Promise.resolve();

    console.log('[FlybyExport] Fetching ' + missing.length + ' unloaded stream(s)...');
    var fetches = missing.map(function (m) {
      var name = (m.attributes.shortFirstName || m.attributes.name || m.id);
      console.log('[FlybyExport]  fetching: ' + name);
      return new Promise(function (resolve) {
        if (m.data && typeof m.data.fetch === 'function') {
          m.data.fetch({ success: resolve, error: resolve });
        } else {
          resolve();
        }
      });
    });
    return Promise.all(fetches);
  }

  // ── extra-rider fetch using flyby's own Backbone model classes ───

  function fetchExtraRider(activityId, nameOverride, colorOverride) {
    var models = window.flyby.results.activities.models;
    if (!models.length) return Promise.reject(new Error('No reference models available'));

    var refModel = models[0];
    var actIdStr = String(activityId).trim();
    var idx = models.length + _api.athletes.length;

    console.log('[FlybyExport] Fetching extra rider — activity ' + actIdStr + '...');

    // Clone the model and data-model constructors from the existing flyby model
    var ModelClass = refModel.constructor;
    var DataClass  = refModel.data && refModel.data.constructor;

    if (!DataClass) {
      return Promise.reject(new Error(
        'Cannot determine flyby data model class from reference model. ' +
        'Try loading at least one athlete first.'
      ));
    }

    var newModel  = new ModelClass({ id: actIdStr });
    var dataModel = new DataClass({ id: actIdStr });
    newModel.data = dataModel;

    return new Promise(function (resolve, reject) {
      dataModel.fetch({
        success: function () {
          var athlete = buildAthlete(newModel, idx, nameOverride, colorOverride);
          if (athlete) {
            resolve(athlete);
          } else {
            reject(new Error('Stream fetched but no usable GPS data for activity ' + actIdStr));
          }
        },
        error: function (model, resp) {
          var status  = resp && resp.status;
          var msg     = resp && resp.responseJSON && resp.responseJSON.message;
          if (status === 404) {
            reject(new Error(
              'Activity ' + actIdStr + ' not found in this flyby match. ' +
              'Only activities that Strava matched to this flyby can be fetched this way.'
            ));
          } else if (status === 403 || status === 401) {
            reject(new Error('Not authorised to access activity ' + actIdStr + ' (status ' + status + ')'));
          } else {
            reject(new Error('Fetch failed for ' + actIdStr + ' — HTTP ' + (status || '?') + (msg ? ': ' + msg : '')));
          }
        }
      });
    });
  }

  // ── download ──────────────────────────────────────────────────────

  function download(athletes) {
    if (!athletes.length) { console.error('[FlybyExport] Nothing to export'); return; }
    var json = JSON.stringify(athletes, null, 2);
    var a    = document.createElement('a');
    a.href   = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
    a.download = 'flyby-export-' + Date.now() + '.json';
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    console.log('[FlybyExport] ✓ Downloaded ' + athletes.length + ' athletes · ' +
                Math.round(json.length / 1024) + ' KB');
    console.log('[FlybyExport] → Load flyby-export-*.json into strava-flyby-offline.html');
  }

  // ── public API ────────────────────────────────────────────────────

  var _api = {
    athletes: [],   // accumulated athlete list

    /** Fetch all flyby athletes and download. Prompts for extra rider IDs. */
    run: async function () {
      var models = window.flyby.results.activities.models;
      console.log('[FlybyExport] ' + models.length + ' athletes in flyby');

      await fetchMissing(models);

      _api.athletes = models.map(function (m, i) {
        return buildAthlete(m, i);
      }).filter(Boolean);

      console.log('[FlybyExport] ' + _api.athletes.length + ' athletes ready');

      // Prompt for extra rider IDs
      var input = window.prompt(
        'FlybyExport: ' + _api.athletes.length + ' flyby riders loaded.\n\n' +
        'Add extra rider activity IDs? (comma-separated, or Cancel to skip)\n\n' +
        'Note: only activities Strava matched to this flyby can be fetched.',
        ''
      );

      if (input && input.trim()) {
        var ids = input.split(/[\s,]+/).map(function (s) { return s.trim(); }).filter(Boolean);
        for (var i = 0; i < ids.length; i++) {
          await _api.addRider(ids[i]).catch(function (err) {
            console.error('[FlybyExport] Skipped ' + ids[i] + ': ' + err.message);
          });
        }
      }

      download(_api.athletes);
    },

    /**
     * Fetch and queue an extra rider after the initial export.
     * @param {string|number} activityId  Strava activity ID
     * @param {string}        [name]      Override display name
     * @param {string}        [color]     Override hex colour e.g. '#ff0000'
     * @returns Promise<athlete object>
     */
    addRider: async function (activityId, name, color) {
      var athlete = await fetchExtraRider(activityId, name, color);
      _api.athletes.push(athlete);
      console.log('[FlybyExport] Queued: ' + athlete.name + ' — call FlybyExport.download() to save');
      return athlete;
    },

    /** Re-download the current athlete list (including any addRider additions). */
    download: function () {
      download(_api.athletes);
    },

    /** Log the current athlete list to the console. */
    list: function () {
      if (!_api.athletes.length) { console.log('[FlybyExport] No athletes loaded yet'); return; }
      console.log('[FlybyExport] Athletes (' + _api.athletes.length + '):');
      _api.athletes.forEach(function (a, i) {
        console.log('  [' + i + '] ' + a.name +
          '  id:' + a.id +
          (a.athleteId ? '  athleteId:' + a.athleteId : '') +
          '  ' + a.streams.time.length + ' pts' +
          '  color:' + a.color);
      });
    },

    /** Remove an athlete by index or activity ID. */
    remove: function (idxOrId) {
      var before = _api.athletes.length;
      _api.athletes = _api.athletes.filter(function (a, i) {
        return i !== idxOrId && a.id !== String(idxOrId);
      });
      console.log('[FlybyExport] Removed ' + (before - _api.athletes.length) + ' athlete(s)');
    }
  };

  // Run immediately on paste
  _api.run();

  return _api;

})();
