// ── PASTE INTO CONSOLE ON THE FLYBY PAGE ──────────────────────
// Dumps model[0] so you can see exactly where the GPS data lives.

(function () {
  var m = window.flyby.results.activities.models[0];

  console.log('=== model top-level keys ===');
  console.log(Object.keys(m));

  console.log('=== model.attributes ===');
  console.log(m.attributes);

  console.log('=== model.data top-level keys ===');
  console.log(Object.keys(m.data || {}));

  // Log every key in model.data with its type and size
  console.log('=== model.data contents ===');
  Object.keys(m.data || {}).forEach(function (k) {
    var v = m.data[k];
    if (Array.isArray(v)) {
      console.log(k, '→ Array(' + v.length + ')  [0]:', JSON.stringify(v[0]).slice(0, 80));
    } else if (typeof v === 'function') {
      console.log(k, '→ function');
    } else if (v && typeof v === 'object') {
      console.log(k, '→ Object', Object.keys(v));
      // one level deeper
      Object.keys(v).forEach(function (sk) {
        var sv = v[sk];
        if (Array.isArray(sv)) {
          console.log('  ' + sk, '→ Array(' + sv.length + ')  [0]:', JSON.stringify(sv[0]).slice(0, 80));
        }
      });
    } else {
      console.log(k, '→', v);
    }
  });

  // Quick timeToPos probe
  if (typeof m.data.timeToPos === 'function') {
    var t = window.flyby.playbackState.startTime + 300;
    console.log('timeToPos(start+5min):', m.data.timeToPos(t));
  }
})();
