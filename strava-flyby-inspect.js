/**
 * ============================================================
 *  FLYBY DATA INSPECTOR
 *  Run in DevTools console on the Strava Flyby viewer page.
 *  Logs every model's attribute and data structure so you can
 *  see exactly which property names hold the GPS arrays.
 * ============================================================
 *
 *  Usage (paste into console, press Enter):
 *
 *    flybyInspect()            -- inspect all athletes
 *    flybyInspect(0)           -- inspect athlete at index 0 only
 *    flybyInspect(0, true)     -- also dump raw data object keys (verbose)
 * ============================================================
 */

function flybyInspect(idx, verbose) {
  var fb = window.flyby;
  if (!fb) { console.error('[Inspect] window.flyby not found -- is this the Flyby page?'); return; }

  var ps = fb.playbackState;
  if (!ps) { console.error('[Inspect] playbackState missing'); return; }

  var models = fb.results && fb.results.activities && fb.results.activities.models;
  if (!models || !models.length) { console.error('[Inspect] No activity models found -- wait for athletes to load'); return; }

  console.log('%c[Inspect] Flyby internals', 'color:lime;font-weight:bold');
  console.log('  playbackState.startTime :', ps.startTime, '→', new Date(ps.startTime * 1000).toISOString());
  console.log('  playbackState.endTime   :', ps.endTime,   '→', ps.endTime ? new Date(ps.endTime * 1000).toISOString() : 'not set');
  console.log('  playbackState.speed     :', ps.speed);
  console.log('  playbackState.playing   :', ps.playing);
  console.log('  models.length           :', models.length);
  console.log('');

  var toCheck = (typeof idx === 'number') ? [models[idx]] : models;

  toCheck.forEach(function (model, i) {
    var realIdx = (typeof idx === 'number') ? idx : i;
    var attr    = model.attributes || {};
    var data    = model.data       || {};

    console.groupCollapsed(
      '%c[' + realIdx + '] ' + (attr.shortFirstName || attr.name || 'Athlete') +
      '  (activityId=' + model.id + '  athleteId=' + attr.athleteId + ')',
      'color:#4fc3f7'
    );

    // --- Attributes ---
    console.group('attributes');
    [
      'athleteId','activityId','shortFirstName','name',
      'streamColor','startTime','elapsedTime','movingTime',
      'distance','totalElevationGain','sport'
    ].forEach(function (k) {
      if (attr[k] !== undefined) console.log(k + ':', attr[k]);
    });
    // Show any extra keys not in our list
    var knownAttrKeys = new Set([
      'athleteId','activityId','shortFirstName','name','streamColor',
      'startTime','elapsedTime','movingTime','distance','totalElevationGain','sport'
    ]);
    Object.keys(attr).forEach(function (k) {
      if (!knownAttrKeys.has(k)) console.log('%c' + k + ':', 'color:#aaa', attr[k]);
    });
    console.groupEnd();

    // --- Data keys and array shapes ---
    console.group('data — key inventory');
    var dataKeys = Object.keys(data);
    if (!dataKeys.length) {
      console.warn('data object is empty');
    } else {
      dataKeys.forEach(function (k) {
        var v = data[k];
        if (Array.isArray(v)) {
          var first = v[0];
          var sample = Array.isArray(first)
            ? '[' + first.slice(0,2).join(', ') + ']'
            : (typeof first === 'object' && first !== null)
              ? '{' + Object.keys(first).slice(0,4).join(', ') + '}'
              : String(first);
          console.log(
            '%c' + k + '%c  Array(' + v.length + ')  first: ' + sample,
            'color:#ffb74d;font-weight:bold', 'color:inherit'
          );
        } else if (typeof v === 'function') {
          console.log('%c' + k + '%c  function', 'color:#81c784;font-weight:bold', 'color:inherit');
        } else if (v !== null && typeof v === 'object') {
          var subKeys = Object.keys(v).slice(0, 8).join(', ');
          console.log('%c' + k + '%c  Object {' + subKeys + '}', 'color:#ce93d8;font-weight:bold', 'color:inherit');
          // recurse one level for nested stream objects
          Object.keys(v).forEach(function (sk) {
            var sv = v[sk];
            if (Array.isArray(sv) && sv.length > 0) {
              console.log(
                '    %c' + sk + '%c  Array(' + sv.length + ')  first: ' + JSON.stringify(sv[0]).slice(0, 60),
                'color:#ffb74d', 'color:inherit'
              );
            }
          });
        } else {
          console.log(k + ':', v);
        }
      });
    }
    console.groupEnd();

    // --- timeToPos probe ---
    if (typeof data.timeToPos === 'function') {
      var probeT = ps.startTime + 300; // 5 min in
      var pos;
      try { pos = data.timeToPos(probeT); } catch(e) { pos = e.message; }
      console.log(
        'timeToPos(startTime+5min):',
        Array.isArray(pos) ? '[' + pos[0].toFixed(5) + ', ' + pos[1].toFixed(5) + ']' : pos
      );
    } else {
      console.warn('timeToPos: not a function');
    }

    // --- Verbose: full raw dump ---
    if (verbose) {
      console.group('raw data object (verbose)');
      console.log(data);
      console.groupEnd();
    }

    console.groupEnd(); // athlete group
  });

  // --- Quick property-match report ---
  console.group('%c[Inspect] GPS array candidate match', 'color:lime');
  var TIME_KEYS = ['times','time','timestamps','t'];
  var POS_KEYS  = ['latLngs','latlng','positions','coords','latLng','latlngs'];

  models.forEach(function (model, i) {
    var data   = model.data || {};
    var attr   = model.attributes || {};
    var found  = [];
    var hasTPF = typeof data.timeToPos === 'function';

    TIME_KEYS.forEach(function (tk) {
      POS_KEYS.forEach(function (pk) {
        var ta = data[tk], pa = data[pk];
        if (Array.isArray(ta) && ta.length > 5 && Array.isArray(pa) && pa.length > 5) {
          found.push(tk + ' / ' + pk + ' (' + ta.length + ' pts)');
        }
      });
    });

    // Check nested
    ['stream','streams','streamData'].forEach(function (nk) {
      var nested = data[nk];
      if (nested && typeof nested === 'object') {
        TIME_KEYS.forEach(function (tk) {
          POS_KEYS.forEach(function (pk) {
            var ta = nested[tk], pa = nested[pk];
            if (Array.isArray(ta) && ta.length > 5 && Array.isArray(pa) && pa.length > 5) {
              found.push('data.' + nk + '.' + tk + ' / ' + pk + ' (' + ta.length + ' pts)');
            }
          });
        });
      }
    });

    var name   = attr.shortFirstName || attr.name || ('Athlete ' + i);
    if (found.length) {
      console.log('%c✓ ' + name + ':%c ' + found.join(' | '), 'color:#2ecc71', 'color:inherit');
    } else if (hasTPF) {
      console.log('%c~ ' + name + ':%c no raw arrays, but timeToPos() available → will sample', 'color:#f39c12', 'color:inherit');
    } else {
      console.log('%c✗ ' + name + ':%c no GPS arrays and no timeToPos()', 'color:#e74c3c', 'color:inherit');
    }
  });
  console.groupEnd();
}

flybyInspect();
