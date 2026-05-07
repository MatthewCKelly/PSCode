// ── FLYBY QUICK EXPORT ───────────────────────────────────────────
// Paste into DevTools console on the Strava Flyby page.
// Downloads all athlete GPS tracks as flyby-export-*.json
// ready to load into strava-flyby-offline.html
// ─────────────────────────────────────────────────────────────────

(function () {
  var models = window.flyby.results.activities.models;
  var COLORS  = ['#fc5200','#4fc3f7','#81c784','#ffb74d','#f48fb1','#ce93d8','#80deea','#a5d6a7'];
  var athletes = [];

  models.forEach(function (model, idx) {
    var attr   = model.attributes;
    var name   = attr.shortFirstName || (attr.athlete && attr.athlete.firstName) || attr.name || ('Athlete ' + idx);
    var color  = attr.streamColor || COLORS[idx % COLORS.length];
    var actId  = String(model.id || idx);

    // GPS data: model.data is a Backbone model; points at .attributes.data
    var dataModel = model.data;
    var points    = (typeof dataModel.get === 'function')
                      ? dataModel.get('data')
                      : (dataModel.attributes && dataModel.attributes.data);

    if (!Array.isArray(points) || points.length < 2) {
      console.warn('[Export] ' + name + ': no data');
      return;
    }

    var startTime = points[0].time;
    var latlng = [], time = [];

    points.forEach(function (p) {
      if (p && p.point && p.time != null) {
        latlng.push([p.point.lat, p.point.lng]);
        time.push(Math.round(p.time - startTime));
      }
    });

    console.log('[Export] ' + name + '  ' + latlng.length + ' pts  color:' + color);
    athletes.push({ id: actId, name: name, color: color, startTime: startTime, streams: { latlng: latlng, time: time } });
  });

  if (!athletes.length) { console.error('[Export] Nothing to export'); return; }

  var json = JSON.stringify(athletes, null, 2);
  var a    = document.createElement('a');
  a.href   = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
  a.download = 'flyby-export-' + Date.now() + '.json';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);

  console.log('[Export] ✓ ' + athletes.length + ' athletes · ' + Math.round(json.length / 1024) + ' KB');
})();
