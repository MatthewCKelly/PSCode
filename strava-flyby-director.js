/**
 * ============================================================
 *  STRAVA FLYBY DIRECTOR  v2.9.2
 *  2026-05-07T00:00:00+12:00
 * ============================================================
 *
 *  Inject into the Strava Flyby viewer via browser console.
 *  Controls zoom, playback speed, athlete visibility (via the
 *  table checkboxes), and a speech bubble caption anchored to
 *  YOUR avatar dot on the map.
 *
 *  v2.9.0: Added exportData() -- downloads all athlete GPS
 *  streams as a JSON blob ready for the Offline Flyby Viewer.
 *
 *  HOW TO USE:
 *    1. Open your Flyby URL in Chrome
 *    2. Dismiss the cookie banner (click OK)
 *    3. Wait for athlete list to fully load
 *    4. Open DevTools Console (F12)
 *    5. Paste this entire script and press Enter
 *    6. Press Play in Flyby -- director syncs automatically
 *
 *  RUNTIME CONSOLE COMMANDS:
 *    FlybyDirector.stop()          -- pause director (keeps overlay)
 *    FlybyDirector.start()         -- resume after stop()
 *    FlybyDirector.follow(true)    -- enable follow-cam
 *    FlybyDirector.follow(false)   -- disable follow-cam (free pan)
 *    FlybyDirector.debug()         -- log current state snapshot
 *    FlybyDirector.cleanup()       -- full teardown, restores all athletes
 *    FlybyDirector.roster()        -- log all athlete IDs and names
 *    FlybyDirector.exportData()    -- download athlete GPS as JSON blob
 *    FlybyDirector.exportData(10)  -- same but sample every 10 seconds
 *
 *  KEYFRAME athletes FIELD:
 *    omit / null     show ALL athletes
 *    []              show only yourself
 *    [id1, id2]      show those athletes + yourself
 *
 *  SPEED REFERENCE:  30=slow  60=default  120=fast  300=skip
 *  ZOOM REFERENCE:   13=regional  15=default  16=street  17=close
 *
 * ============================================================
 */

// ============================================================
//  CONFIG
// ============================================================

const MY_ATHLETE_ID   = 19126131;
const MY_ACTIVITY_ID  = 18340006598;
const RACE_START_TIME = "09:00:00";
const POLL_MS         = 250;
const ZOOM_OFFSET     = 1;       // GL zoom = Leaflet zoom - ZOOM_OFFSET
const BUBBLE_OFFSET_Y = 60;      // px above avatar centre for bubble tail

// How many seconds of time-jump to treat as a scrub (reapply keyframe)
const SCRUB_THRESHOLD = 5;

// ============================================================
//  KEYFRAME TIMELINE
// ============================================================

const TIMELINE = [
  {
    time     : "09:00:00",
    caption  : "Race start -- neutral roll-out",
    zoom     : 15,
    speed    : 30,
    athletes : [16866317, 11302733, 11873051, 23423875, 120924019, 1659413, 3462828],
  },
  {
    time     : "09:02:00",
    caption  : "aaand we are rolling...",
    zoom     : 15,
    speed    : 30,
    athletes : [16866317, 11302733, 11873051, 23423875, 120924019, 1659413, 3462828],
  },
  {
    time     : "09:07:33",
    caption  : "Peloton forms up -- I get dropped from first bunch.",
    zoom     : 15,
    speed    : 30,
    athletes : [16866317, 11302733, 11873051, 23423875, 120924019, 1659413, 3462828],
  },
  {
    time     : "09:13:00",
    caption  : "Made a call.",
    zoom     : 15,
    speed    : 30,
    athletes : [16866317, 11302733, 11873051, 23423875, 120924019, 1659413, 3462828],
  },
  {
    time     : "09:37:00",
    caption  : "Next group catches up.",
    zoom     : 15,
    speed    : 30,
    athletes : [16866317, 11302733, 11873051, 23423875, 120924019, 1659413, 3462828],
  },
  {
    time     : "10:39:00",
    caption  : "Descent",
    zoom     : 15,
    speed    : 30,
    athletes : [16866317, 11302733, 11873051, 23423875, 120924019, 1659413, 3462828],
  },
  {
    time     : "10:54:46",
    caption  : "First of group into Kumara",
    zoom     : 15,
    speed    : 30,
    athletes : [16866317, 11302733, 11873051, 23423875],
  },
  {
    time     : "10:56:48",
    caption  : "Rear bottles both fall off, stopped to collect! Lost the group.",
    zoom     : 17,
    speed    : 30,
    athletes : [],   // just me while stopped
  },
  {
    time     : "11:10:00",
    caption  : "Back onto the group...",
    zoom     : 15,
    speed    : 30,
    // omit athletes = show all
  },
  {
    time     : "12:43:00",
    caption  : "Nice downhill push, felt good so pulled ahead.",
    zoom     : 15,
    speed    : 30,
  },
  {
    time     : "12:51:00",
    caption  : "I hear carbon wheels -- Jim catches me, along with the rest of the group.",
    zoom     : 15,
    speed    : 30,
  },
  {
    time     : "12:59:00",
    caption  : "The bunch caught me -- legs said no more. Didn't cramp, just lost the power.",
    zoom     : 15,
    speed    : 30,
  },
  {
    time     : "13:11:00",
    caption  : "Finished... Slower than last year, still a good day out...",
    zoom     : 15,
    speed    : 30,
  },
];

// ============================================================
//  END CONFIG
// ============================================================

(function () {
  'use strict';

  const PREFIX = '[FlybyDirector]';

  // ----------------------------------------------------------
  //  Time helpers
  // ----------------------------------------------------------

  function wallClockToUnix(hms, activityStartUnix) {
    const [h, m, s] = hms.split(':').map(Number);
    const base = new Date(activityStartUnix * 1000);
    base.setHours(h, m, s || 0, 0);
    return base.getTime() / 1000;
  }

  function unixToHMS(unix) {
    const d = new Date(unix * 1000);
    return [d.getHours(), d.getMinutes(), d.getSeconds()]
      .map(v => String(v).padStart(2, '0')).join(':');
  }

  function fmtElapsed(sec) {
    const sign = sec < 0 ? '-' : '+';
    const abs  = Math.abs(Math.floor(sec));
    const h    = Math.floor(abs / 3600);
    const m    = Math.floor((abs % 3600) / 60);
    const s    = abs % 60;
    return sign + [h, m, s].map(v => String(v).padStart(2, '0')).join(':');
  }

  // ----------------------------------------------------------
  //  Acquire Flyby internals
  // ----------------------------------------------------------

  function getHandles() {
    const fb = window.flyby;
    if (!fb) return null;

    const lMap = fb.map && fb.map.map;
    if (!lMap || typeof lMap.setView !== 'function') return null;

    const glMap = fb.map && fb.map.gl && fb.map.gl._glMap;

    const ps = fb.playbackState;
    if (!ps || !ps.startTime) return null;

    const models  = (fb.results && fb.results.activities &&
                     fb.results.activities.models) || [];
    const myModel = models.find(function (m) { return m.id === MY_ACTIVITY_ID; });
    if (!myModel) {
      console.warn(PREFIX + ' Activity ' + MY_ACTIVITY_ID + ' not found');
      return null;
    }

    return { lMap: lMap, glMap: glMap || null, ps: ps, myModel: myModel, models: models };
  }

  // ----------------------------------------------------------
  //  Checkbox map
  //  Built once at startup: athleteId (number) -> checkbox element
  // ----------------------------------------------------------

  var cbMap = {};

  function buildCheckboxMap() {
    const rows   = document.querySelectorAll('#activity_table tr');
    const models = window.flyby && window.flyby.results &&
                   window.flyby.results.activities &&
                   window.flyby.results.activities.models;
    if (!models || rows.length < 2) {
      console.warn(PREFIX + ' Checkbox map: table not ready');
      return false;
    }

    cbMap = {};
    rows.forEach(function (row, rowIdx) {
      if (rowIdx === 0) return;
      const cb    = row.querySelector('input[type="checkbox"]');
      const model = models[rowIdx - 1];
      if (!cb || !model) return;
      cbMap[model.attributes.athleteId] = cb;
    });

    const count = Object.keys(cbMap).length;
    console.log(PREFIX + ' Checkbox map: ' + count + ' athletes mapped');
    return count > 0;
  }

  // ----------------------------------------------------------
  //  Athlete visibility
  //
  //  athletes=null  -> show ALL (check everyone)
  //  athletes=[]    -> show only MY_ATHLETE_ID
  //  athletes=[ids] -> show those + MY_ATHLETE_ID
  //
  //  Force flag bypasses the dedup key (used on scrub)
  // ----------------------------------------------------------

  var lastAthleteKey = null;

  function applyAthleteVisibility(athleteFilter, force) {
    var key;
    if (athleteFilter === null) {
      key = 'ALL';
    } else if (athleteFilter.length === 0) {
      key = 'ONLY_ME';
    } else {
      key = athleteFilter.slice().sort().join(',');
    }

    if (!force && key === lastAthleteKey) return;
    lastAthleteKey = key;

    Object.keys(cbMap).forEach(function (aidStr) {
      var aid = parseInt(aidStr, 10);
      var cb  = cbMap[aid];
      if (!cb) return;

      var shouldBeChecked;
      if (athleteFilter === null) {
        // Show everyone
        shouldBeChecked = true;
      } else {
        // Show MY_ATHLETE_ID + listed
        shouldBeChecked = (aid === MY_ATHLETE_ID) ||
                          (athleteFilter.indexOf(aid) !== -1);
      }

      if (cb.checked !== shouldBeChecked) {
        cb.click();
      }
    }); // end forEach

    console.log(PREFIX + ' Athletes -> ' +
      (athleteFilter === null ? 'all' :
       athleteFilter.length === 0 ? 'only me' :
       'me + [' + athleteFilter.join(', ') + ']'));
  } // end of applyAthleteVisibility()

  // ----------------------------------------------------------
  //  Keyframe parsing
  // ----------------------------------------------------------

  var keyframes     = [];
  var raceStartUnix = null;

  function buildKeyframes(activityStartUnix) {
    raceStartUnix = wallClockToUnix(RACE_START_TIME, activityStartUnix);
    keyframes = TIMELINE
      .map(function (kf) {
        return {
          time     : kf.time,
          caption  : kf.caption  !== undefined ? kf.caption  : '',
          zoom     : kf.zoom     !== undefined ? kf.zoom     : 15,
          speed    : kf.speed    !== undefined ? kf.speed    : 60,
          // null = show all; [] = only me; [ids] = those + me
          athletes : Object.prototype.hasOwnProperty.call(kf, 'athletes')
                       ? kf.athletes : null,
          unix     : wallClockToUnix(kf.time, activityStartUnix),
        };
      })
      .sort(function (a, b) { return a.unix - b.unix; });

    console.log(PREFIX + ' Keyframes anchored to: ' +
      new Date(activityStartUnix * 1000).toDateString());
    keyframes.forEach(function (kf, i) {
      var athStr = kf.athletes === null ? 'all' :
                   kf.athletes.length === 0 ? 'only me' :
                   'me+[' + kf.athletes.join(',') + ']';
      console.log('  [' + i + '] ' + kf.time +
        '  zoom:' + kf.zoom +
        '  speed:' + kf.speed +
        '  athletes:' + athStr +
        '  "' + kf.caption + '"');
    });
  }

  // ----------------------------------------------------------
  //  Position lookup
  // ----------------------------------------------------------

  function getMyPosition(myModel, unixTime) {
    try {
      var pos = myModel.data.timeToPos(unixTime);
      if (Array.isArray(pos) && pos.length === 2 && !isNaN(pos[0])) {
        return { lat: pos[0], lng: pos[1] };
      }
    } catch (e) {}
    return null;
  }

  // ----------------------------------------------------------
  //  Lat/lng -> screen pixel
  // ----------------------------------------------------------

  function latLngToScreen(lMap, lat, lng) {
    var point   = lMap.latLngToContainerPoint([lat, lng]);
    var mapRect = lMap.getContainer().getBoundingClientRect();
    return { x: mapRect.left + point.x, y: mapRect.top + point.y };
  }

  // ----------------------------------------------------------
  //  Keyframe lookup
  // ----------------------------------------------------------

  function getActiveKeyframe(unixTime) {
    var active = null;
    for (var i = 0; i < keyframes.length; i++) {
      if (keyframes[i].unix <= unixTime) { active = keyframes[i]; }
      else { break; }
    }
    return active;
  }

  // ----------------------------------------------------------
  //  Speed control
  // ----------------------------------------------------------

  var lastSpeed = null;

  function applySpeed(targetSpeed, ps, force) {
    if (!force && targetSpeed === lastSpeed) return;
    ps.speed = targetSpeed;
    lastSpeed = targetSpeed;
    console.log(PREFIX + ' Speed -> ' + targetSpeed + 's/s');
  }

  // ----------------------------------------------------------
  //  Follow-cam + zoom
  // ----------------------------------------------------------

  var followEnabled = true;
  var currentZoom   = 15;

  function applyFollowAndZoom(pos, lMap, targetGLZoom) {
    currentZoom = targetGLZoom;
    var leafletZoom = targetGLZoom + ZOOM_OFFSET;
    if (!followEnabled || !pos) {
      if (lMap.getZoom() !== leafletZoom) {
        lMap.setZoom(leafletZoom, { animate: false });
      }
      return;
    }
    lMap.setView([pos.lat, pos.lng], leafletZoom, { animate: false, duration: 0 });
  }

  // ----------------------------------------------------------
  //  Speech bubble
  // ----------------------------------------------------------

  var bubbleEl      = null;
  var statsEl       = null;
  var lastBubbleMsg = null;

  function createOverlay() {
    if (document.getElementById('fd-bubble')) return;

    bubbleEl = document.createElement('div');
    bubbleEl.id = 'fd-bubble';
    bubbleEl.style.cssText = [
      'position:fixed',
      'z-index:99999',
      'pointer-events:none',
      'display:none',
      'flex-direction:column',
      'align-items:center',
      'transform:translate(-50%, -100%)',
      'font-family:Helvetica Neue,Arial,sans-serif',
    ].join(';');

    var body = document.createElement('div');
    body.id = 'fd-bubble-body';
    body.style.cssText = [
      'background:rgba(0,0,0,0.85)',
      'color:#fff',
      'font-size:14px',
      'font-weight:600',
      'letter-spacing:0.02em',
      'padding:8px 14px',
      'border-radius:10px',
      'text-align:center',
      'max-width:300px',
      'min-width:100px',
      'border:2px solid #fc4c02',
      'line-height:1.45',
    ].join(';');

    var tail = document.createElement('div');
    tail.style.cssText = [
      'width:0',
      'height:0',
      'border-left:9px solid transparent',
      'border-right:9px solid transparent',
      'border-top:11px solid #fc4c02',
      'margin-top:-1px',
    ].join(';');

    bubbleEl.appendChild(body);
    bubbleEl.appendChild(tail);
    document.body.appendChild(bubbleEl);

    statsEl = document.createElement('div');
    statsEl.id = 'fd-stats';
    statsEl.style.cssText = [
      'position:fixed',
      'bottom:72px',
      'left:50%',
      'transform:translateX(-50%)',
      'z-index:99999',
      'pointer-events:none',
      'background:rgba(0,0,0,0.52)',
      'color:#bbb',
      'font-size:11px',
      'letter-spacing:0.06em',
      'padding:3px 12px',
      'border-radius:3px',
      'font-variant-numeric:tabular-nums',
      'font-family:Helvetica Neue,Arial,sans-serif',
    ].join(';');
    document.body.appendChild(statsEl);
  } // end of createOverlay()

  function updateBubble(caption, screenPos) {
    if (!bubbleEl) return;
    var bodyEl = document.getElementById('fd-bubble-body');
    if (!bodyEl) return;

    if (caption !== null && caption !== lastBubbleMsg) {
      lastBubbleMsg = caption;
      if (caption && caption.trim()) {
        bodyEl.textContent = caption;
        bubbleEl.style.display = 'flex';
      } else {
        bubbleEl.style.display = 'none';
        return;
      }
    }

    if (bubbleEl.style.display !== 'none' && screenPos) {
      bubbleEl.style.left = screenPos.x + 'px';
      bubbleEl.style.top  = (screenPos.y - BUBBLE_OFFSET_Y) + 'px';
    }
  }

  function updateStats(kf, currentUnix) {
    if (!statsEl) return;
    var elapsed   = raceStartUnix ? currentUnix - raceStartUnix : 0;
    var followStr = followEnabled ? 'follow ON' : 'follow OFF';
    statsEl.textContent = [
      unixToHMS(currentUnix),
      fmtElapsed(elapsed),
      (kf ? kf.speed + 's/s' : '?'),
      (kf ? 'zoom ' + kf.zoom : 'zoom ?'),
      followStr,
    ].join('  |  ');
  }

  function removeOverlay() {
    ['fd-bubble', 'fd-stats'].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.remove();
    });
    bubbleEl = null; statsEl = null; lastBubbleMsg = null;
  }

  // ----------------------------------------------------------
  //  Main tick -- with scrub detection
  // ----------------------------------------------------------

  var tickTimer        = null;
  var lastKeyframeUnix = null;
  var lastTickTime     = null;   // for scrub detection
  var handles          = null;

  function applyKeyframe(kf, ps, screenPos, force) {
    console.log(PREFIX + ' KF @ ' + kf.time +
      '  speed:' + kf.speed +
      '  zoom:'  + kf.zoom  +
      (force ? '  [scrub reapply]' : '') +
      '  "' + kf.caption + '"');
    applySpeed(kf.speed, ps, force);
    applyAthleteVisibility(kf.athletes, force);
    updateBubble(kf.caption, screenPos);
    lastBubbleMsg    = kf.caption;
    lastKeyframeUnix = kf.unix;
  }

  function tick() {
    if (!handles) {
      handles = getHandles();
      if (!handles) return;
      buildKeyframes(handles.ps.startTime);
    }

    var lMap    = handles.lMap;
    var ps      = handles.ps;
    var myModel = handles.myModel;

    var currentUnix = ps.time;
    var pos         = getMyPosition(myModel, currentUnix);
    var kf          = getActiveKeyframe(currentUnix);
    var targetZoom  = kf ? kf.zoom : currentZoom;

    var screenPos = (pos && followEnabled)
      ? latLngToScreen(lMap, pos.lat, pos.lng)
      : null;

    // Scrub detection -- time jumped more than SCRUB_THRESHOLD seconds
    // non-linearly (either direction) means user dragged the scrubber
    var scrubbed = false;
    if (lastTickTime !== null) {
      var expectedAdvance = POLL_MS / 1000 * (ps.speed || 60);
      var actualAdvance   = Math.abs(currentUnix - lastTickTime);
      // If actual advance is way more than expected, it's a scrub
      if (actualAdvance > expectedAdvance + SCRUB_THRESHOLD) {
        scrubbed = true;
        console.log(PREFIX + ' Scrub detected -- reapplying keyframe');
        // Reset dedup state so everything reapplies
        lastKeyframeUnix = null;
        lastAthleteKey   = null;
        lastSpeed        = null;
        lastBubbleMsg    = null;
      }
    }
    lastTickTime = currentUnix;

    if (kf) {
      if (kf.unix !== lastKeyframeUnix || scrubbed) {
        // Keyframe advanced or scrubbed -- reapply everything
        applyKeyframe(kf, ps, screenPos, scrubbed);
      } else {
        // Same keyframe -- reposition bubble + refresh stats
        updateBubble(null, screenPos);
      }
    } // end of if kf

    updateStats(kf, currentUnix);
    applyFollowAndZoom(pos, lMap, targetZoom);
  } // end of tick()

  // ----------------------------------------------------------
  //  DATA EXPORT  (v2.9.2)
  //
  //  Reads GPS data from model.data (Backbone model) whose
  //  attributes.data is an Array of:
  //    { elevation: 115, point: { lat, lng }, time: unixSeconds }
  //
  //  For athletes whose data hasn't loaded yet, triggers
  //  model.data.fetch() and waits before downloading.
  //
  //  Downloads a JSON blob compatible with strava-flyby-offline.html.
  // ----------------------------------------------------------

  function getPoints(model) {
    var dm = model.data;
    if (!dm) return null;
    var pts = (typeof dm.get === 'function') ? dm.get('data') : null;
    if (!Array.isArray(pts) && dm.attributes) pts = dm.attributes.data;
    return (Array.isArray(pts) && pts.length > 1) ? pts : null;
  }

  function buildAthleteObj(model, idx) {
    var attr  = model.attributes || {};
    var name  = attr.shortFirstName ||
                (attr.athlete && attr.athlete.firstName) ||
                attr.name || ('Athlete ' + (idx + 1));
    var color = attr.streamColor || COLORS[idx % COLORS.length];
    var actId = String(model.id || attr.id || idx);

    var points = getPoints(model);
    if (!points) {
      console.warn(PREFIX + ' [' + idx + '] ' + name + ': no data');
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

    if (latlng.length < 2) {
      console.warn(PREFIX + ' [' + idx + '] ' + name + ': no valid GPS points after filter');
      return null;
    }

    console.log(PREFIX + ' [' + idx + '] ' + name + '  ' + latlng.length + ' pts  ' +
      new Date(startTime * 1000).toISOString());

    return {
      id        : actId,
      name      : name,
      color     : color,
      startTime : startTime,
      streams   : { latlng: latlng, time: time, altitude: altitude },
    };
  }

  function doDownload(athletes) {
    if (!athletes.length) {
      console.error(PREFIX + ' exportData: no data to download');
      return;
    }
    var totalPts = athletes.reduce(function (s, a) { return s + a.streams.time.length; }, 0);
    var json     = JSON.stringify(athletes, null, 2);
    var blob     = new Blob([json], { type: 'application/json' });
    var url      = URL.createObjectURL(blob);
    var a        = document.createElement('a');
    a.href       = url;
    a.download   = 'flyby-export-' + Date.now() + '.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 8000);
    console.log(PREFIX + ' ✓ ' + athletes.length + ' athletes · ' +
      totalPts + ' pts · ' + Math.round(json.length / 1024) + ' KB');
    console.log(PREFIX + ' → Load flyby-export-*.json into strava-flyby-offline.html');
  }

  function exportData() {
    var fb = window.flyby;
    if (!fb || !fb.results || !fb.results.activities) {
      console.error(PREFIX + ' exportData: window.flyby not ready');
      return;
    }

    var allModels = fb.results.activities.models || [];
    if (!allModels.length) {
      console.error(PREFIX + ' exportData: no activity models found');
      return;
    }

    console.log(PREFIX + ' exportData: ' + allModels.length + ' athletes');

    var missing = allModels.filter(function (m) { return !getPoints(m); });

    if (!missing.length) {
      doDownload(allModels.map(buildAthleteObj).filter(Boolean));
      return;
    }

    // Trigger fetch for any athletes not yet loaded
    console.log(PREFIX + ' Fetching ' + missing.length + ' unloaded athlete(s)...');
    var fetches = missing.map(function (m) {
      var name = (m.attributes || {}).shortFirstName || m.id;
      console.log(PREFIX + '  fetching: ' + name);
      return new Promise(function (resolve) {
        if (m.data && typeof m.data.fetch === 'function') {
          m.data.fetch({ success: resolve, error: resolve });
        } else {
          resolve();
        }
      });
    });

    Promise.all(fetches).then(function () {
      console.log(PREFIX + ' Fetches done — building export...');
      doDownload(allModels.map(buildAthleteObj).filter(Boolean));
    });
  } // end exportData()

  // Fallback color palette used if model has no streamColor
  var COLORS = [
    '#fc5200','#4fc3f7','#81c784','#ffb74d','#f48fb1',
    '#ce93d8','#80deea','#a5d6a7','#ef9a9a','#90caf9',
  ];

  // ----------------------------------------------------------
  //  Public API
  // ----------------------------------------------------------

  var isRunning = false;

  function start() {
    if (isRunning) {
      console.warn(PREFIX + ' Already running -- call stop() first');
      return;
    }

    console.log(PREFIX + ' v2.9.0 starting');
    console.log(PREFIX + ' athletes: null=all  []=only me  [ids]=me+those');
    console.log(PREFIX + ' exportData() available at any time -- even before start()');

    buildCheckboxMap();

    handles = getHandles();
    if (handles) {
      buildKeyframes(handles.ps.startTime);
    } else {
      console.warn(PREFIX + ' Flyby not ready -- keyframes build on first tick');
    }

    createOverlay();
    tickTimer = setInterval(tick, POLL_MS);
    isRunning = true;

    console.log(PREFIX + ' Running. Press Play in Flyby.');
    console.log(PREFIX + ' Commands: stop() | start() | follow(bool) | debug() | cleanup() | roster() | exportData()');
  }

  function stop() {
    clearInterval(tickTimer);
    tickTimer        = null;
    isRunning        = false;
    lastSpeed        = null;
    lastKeyframeUnix = null;
    lastAthleteKey   = null;
    lastTickTime     = null;
    console.log(PREFIX + ' Stopped. Call start() to resume. exportData() still available.');
  }

  function cleanup() {
    if (isRunning) stop();

    removeOverlay();

    // Restore all athletes to visible
    Object.keys(cbMap).forEach(function (aidStr) {
      var cb = cbMap[parseInt(aidStr, 10)];
      if (cb && !cb.checked) cb.click();
    });
    console.log(PREFIX + ' All athletes restored to visible');

    var lMap = window.flyby && window.flyby.map && window.flyby.map.map;
    if (lMap) {
      lMap.off('zoom'); lMap.off('zoomstart'); lMap.off('zoomend');
      delete lMap.panTo; delete lMap.setZoom;
    }

    if (window._restoreSetZoom) { window._restoreSetZoom(); delete window._restoreSetZoom; }
    if (window._stopZoomWatch)  { window._stopZoomWatch();  delete window._stopZoomWatch;  }
    if (window._cbMap)          { delete window._cbMap; }

    handles = null; keyframes = []; raceStartUnix = null;
    lastBubbleMsg = null; followEnabled = true; currentZoom = 15; cbMap = {};

    delete window.FlybyDirector;
    console.log(PREFIX + ' Cleaned up. Paste script again to re-inject.');
  }

  function setFollow(enabled) {
    followEnabled = !!enabled;
    console.log(PREFIX + ' Follow-cam ' + (followEnabled ? 'ON' : 'OFF'));
  }

  function roster() {
    const rows   = document.querySelectorAll('#activity_table tr');
    const models = window.flyby && window.flyby.results &&
                   window.flyby.results.activities &&
                   window.flyby.results.activities.models;
    if (!models) { console.warn(PREFIX + ' No models'); return; }
    console.group(PREFIX + ' Athlete roster');
    rows.forEach(function (row, i) {
      if (i === 0) return;
      const cb  = row.querySelector('input[type="checkbox"]');
      const m   = models[i - 1];
      if (!m) return;
      const a = m.attributes;
      console.log('[' + (i-1) + '] athleteId:' + a.athleteId +
        '  name:"' + (a.shortFirstName || a.name) + '"' +
        '  checked:' + (cb ? cb.checked : '?') +
        '  color:' + a.streamColor);
    });
    console.groupEnd();
  }

  function debug() {
    var h = handles || getHandles();
    if (!h) { console.warn(PREFIX + ' No handles'); return; }
    var t   = h.ps.time;
    var pos = getMyPosition(h.myModel, t);
    var scr = pos ? latLngToScreen(h.lMap, pos.lat, pos.lng) : null;
    var kf  = getActiveKeyframe(t);
    console.group(PREFIX + ' Debug snapshot');
    console.log('time:',         unixToHMS(t), '(unix ' + Math.floor(t) + ')');
    console.log('playing:',      h.ps.playing);
    console.log('speed:',        h.ps.speed);
    console.log('Leaflet zoom:', h.lMap.getZoom(),
      '  GL zoom:', h.glMap ? h.glMap.getZoom() : 'n/a');
    console.log('my position:',  pos);
    console.log('screen pos:',   scr);
    console.log('active KF:',    kf);
    console.log('KF athletes:',  kf ? (kf.athletes === null ? 'all' :
      kf.athletes.length === 0 ? 'only me' : kf.athletes) : 'n/a');
    console.log('raceStart:',    raceStartUnix ? unixToHMS(raceStartUnix) : 'not set');
    console.groupEnd();
  }

  window.FlybyDirector = {
    start      : start,
    stop       : stop,
    follow     : setFollow,
    debug      : debug,
    cleanup    : cleanup,
    roster     : roster,
    exportData : exportData,
    get keyframes() { return keyframes; },
  };

  start();

})();
