'use strict';

// ────────────────────────────────────────────────────────────────
// CONFIG
// ────────────────────────────────────────────────────────────────

let MY_ACTIVITY_ID = '';
const CAPTION_TIMEOUT_SEC = 10;
const FIT_EPOCH = 631065600;
const COLORS = ['#fc5200','#4fc3f7','#81c784','#ffb74d','#f48fb1','#ce93d8','#80deea','#a5d6a7','#ef9a9a','#90caf9','#ffe082','#bcaaa4','#b0bec5','#c5e1a5','#ffcc02'];
const GAUGE_META = [
  { key:'hr',   canvasId:'g-hr',   color:'#e74c3c', label:'bpm',  src:'heartrate',   max:210, avg:true  },
  { key:'pwr',  canvasId:'g-pwr',  color:'#f39c12', label:'W',    src:'power',       max:600, avg:true  },
  { key:'cad',  canvasId:'g-cad',  color:'#2ecc71', label:'rpm',  src:'cadence',     max:130, avg:true  },
  { key:'temp', canvasId:'g-temp', color:'#00bcd4', label:'°C',   src:'temperature', max:45,  avg:false },
  { key:'spd',  canvasId:'g-spd',  color:'#9b59b6', label:'km/h', src:'speed',       max:80,  avg:false },
];

// ────────────────────────────────────────────────────────────────
// STATE
// ────────────────────────────────────────────────────────────────

const S = {
  athletes:[], me:null, keyframes:[], hidden:new Set(), selectedTracks:new Set(),
  followCam:true, sortMode:'load', sidebarOpen:false, hoveredKf:null,
  trim:{start:null,end:null},
  tl:{start:0,end:0,cur:0,playing:false,speed:10,lastTick:null},
  map:null, markers:{}, tracks:{}, meMarker:null, meTrack:null,
  gauges:{}, lastKfUnix:null,
};
function $f(id){ return document.getElementById(id); }

// ────────────────────────────────────────────────────────────────
// HELPERS
// ────────────────────────────────────────────────────────────────

function pad(n){return String(n).padStart(2,'0');}
function fmtDur(sec){const h=Math.floor(sec/3600),m=Math.floor((sec%3600)/60),s=Math.floor(sec%60);return h+':'+pad(m)+':'+pad(s);}
function fmtTime(unix){const d=new Date(unix*1000);return pad(d.getHours())+':'+pad(d.getMinutes())+':'+pad(d.getSeconds());}
function fmtHHMM(unix){const d=new Date(unix*1000);return pad(d.getHours())+':'+pad(d.getMinutes());}
function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}

function posAt(streams, startTime, absT) {
  const rel=absT-startTime, times=streams.time, lls=streams.latlng;
  if(rel<0||!times.length||rel>times[times.length-1])return null;
  let lo=0,hi=times.length-1;
  while(lo<hi){const m=(lo+hi+1)>>1;times[m]<=rel?lo=m:hi=m-1;}
  const p0=lls[lo];
  if(!p0){for(let i=lo-1;i>=0;i--)if(lls[i])return lls[i];return null;}
  if(lo>=times.length-1)return p0;
  const p1=lls[lo+1];if(!p1)return p0;
  const t0=times[lo],t1=times[lo+1];if(t1===t0)return p0;
  const fr=(rel-t0)/(t1-t0);
  return[p0[0]+(p1[0]-p0[0])*fr,p0[1]+(p1[1]-p0[1])*fr];
}

function valAt(arr, times, rel) {
  if(!arr||!arr.length)return null;
  let lo=0,hi=times.length-1;
  while(lo<hi){const m=(lo+hi+1)>>1;times[m]<=rel?lo=m:hi=m-1;}
  return arr[lo]??null;
}

function avgAt(arr, times, rel, win=3) {
  if(!arr||!arr.length)return null;
  const lo=rel-win/2,hi=rel+win/2;
  let i=0,j=times.length-1;
  while(i<j){const m=(i+j)>>1;times[m]<lo?i=m+1:j=m;}
  let sum=0,cnt=0;
  while(i<times.length&&times[i]<=hi){const v=arr[i];if(v!=null){sum+=v;cnt++;}i++;}
  return cnt?sum/cnt:null;
}

// ────────────────────────────────────────────────────────────────
// MAP
// ────────────────────────────────────────────────────────────────

function initMap() {
  S.map=L.map('map',{center:[-42.7167,170.9667],zoom:12});
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{attribution:'© OpenStreetMap',maxZoom:19}).addTo(S.map);
  if(navigator.geolocation){
    navigator.geolocation.getCurrentPosition(
      pos=>{ if(!S.athletes.length&&!S.me)S.map.setView([pos.coords.latitude,pos.coords.longitude],13); },
      ()=>{}
    );
  }
}

function mkIcon(color,size=12,ring=false){
  const inner=ring
    ?'<div style="width:'+size+'px;height:'+size+'px;border-radius:50%;background:#fff;border:3px solid '+color+';box-shadow:0 0 8px '+color+'88"></div>'
    :'<div style="width:'+size+'px;height:'+size+'px;border-radius:50%;background:'+color+';border:2px solid #fff;box-shadow:0 0 4px rgba(0,0,0,.6)"></div>';
  return L.divIcon({className:'',html:inner,iconSize:[size,size],iconAnchor:[size/2,size/2]});
}

function redrawAthletes() {
  Object.values(S.markers).forEach(m=>m.remove());
  Object.values(S.tracks).forEach(t=>t.remove());
  S.markers={}; S.tracks={};
  if(!S.athletes.length)return;
  // Reveal panels that are hidden until data arrives
  const nm=$f('nodatamsg');if(nm)nm.style.display='none';
  const mb=$f('mapbadge');if(mb)mb.style.display='block';
  const metrics=$f('metrics');if(metrics)metrics.style.display='flex';
  if(!S.sidebarOpen){
    S.sidebarOpen=true;
    const sb=$f('sidebar');
    if(sb){sb.classList.remove('collapsed');setTimeout(()=>S.map&&S.map.invalidateSize(),220);}
  }
  for(const a of S.athletes){
    const coords=a.streams.latlng.filter(Boolean);
    if(!coords.length)continue;
    const sel=S.selectedTracks.has(a.id);
    S.tracks[a.id]=L.polyline(coords,{color:a.color,weight:sel?4:2,opacity:sel?1:0.28}).addTo(S.map);
    const mk=L.marker(coords[0],{icon:mkIcon(a.color),zIndexOffset:500});
    mk.addTo(S.map);
    mk.bindTooltip(a.name,{permanent:false,direction:'top',offset:[0,-7],className:'flyby-tip'});
    S.markers[a.id]=mk;
  }
}

function redrawMe() {
  if(S.meMarker){S.meMarker.remove();S.meMarker=null;}
  if(S.meTrack){S.meTrack.remove();S.meTrack=null;}
  if(!S.me)return;
  const coords=S.me.latlng.filter(Boolean);
  if(!coords.length)return;
  S.meTrack=L.polyline(coords,{color:'#fff',weight:3,opacity:0.4,dashArray:'5 5'}).addTo(S.map);
  S.meMarker=L.marker(coords[0],{icon:mkIcon('#fc5200',16,true),zIndexOffset:2000}).addTo(S.map);
  S.meMarker.bindTooltip('You',{permanent:false,direction:'top',offset:[0,-9],className:'flyby-tip'});
}

function fitBounds() {
  const pts=[];
  S.athletes.forEach(a=>a.streams.latlng.filter(Boolean).forEach(p=>pts.push(p)));
  if(S.me)S.me.latlng.filter(Boolean).forEach(p=>pts.push(p));
  if(pts.length)S.map.fitBounds(L.latLngBounds(pts),{padding:[30,30]});
}

// ────────────────────────────────────────────────────────────────
// KEYFRAMES
// ────────────────────────────────────────────────────────────────

function buildKeyframes(rawKfs) {
  const refUnix=S.tl.start||(Date.now()/1000);
  const refDate=new Date(refUnix*1000);
  S.keyframes=rawKfs.map(kf=>{
    const[h,m,s]=kf.time.split(':').map(Number);
    const d=new Date(refDate);d.setHours(h,m,s||0,0);
    return{time:kf.time,unix:d.getTime()/1000,caption:kf.caption||'',zoom:kf.zoom??15,speed:kf.speed??60,
      athletes:Object.prototype.hasOwnProperty.call(kf,'athletes')?kf.athletes:null};
  }).sort((a,b)=>a.unix-b.unix);
  console.log('[Timeline] '+S.keyframes.length+' keyframes loaded');
}

function getActiveKf(t) {
  let active=null;
  for(const kf of S.keyframes){if(kf.unix<=t)active=kf;else break;}
  return active;
}

let _captionTmr=null;

function applyKf(kf) {
  if(!kf||kf.unix===S.lastKfUnix)return;
  S.lastKfUnix=kf.unix;
  clearTimeout(_captionTmr);
  const cap=$f('caption');
  if(kf.caption&&kf.caption.trim()){
    cap.textContent=kf.caption;cap.style.display='block';
    if(CAPTION_TIMEOUT_SEC>0)_captionTmr=setTimeout(()=>cap.style.display='none',CAPTION_TIMEOUT_SEC*1000);
  } else {cap.style.display='none';}
  S.tl.speed=kf.speed||10;
  const spdEl=$f('spd');
  if(spdEl)spdEl.value=[1,5,10,30,60,120].reduce((p,c)=>Math.abs(c-kf.speed)<Math.abs(p-kf.speed)?c:p,10);
  applyAthleteFilter(kf.athletes);
  if(kf.zoom&&S.map)S.map.setZoom(kf.zoom,{animate:false});
}

function applyAthleteFilter(athletes) {
  for(const a of S.athletes){
    let show;
    if(athletes===null){show=true;}
    else if(athletes.length===0){show=(a.id===MY_ACTIVITY_ID||a.athleteId===MY_ACTIVITY_ID);}
    else{const ids=athletes.map(String);show=ids.includes(a.athleteId)||ids.includes(a.id)||a.id===MY_ACTIVITY_ID;}
    show?S.hidden.delete(a.id):S.hidden.add(a.id);
    const mk=S.markers[a.id],tr=S.tracks[a.id];
    if(mk)mk.setOpacity(show?1:0);
    if(tr)tr.setStyle({opacity:show?0.28:0});
  }
  renderList();
}

// ────────────────────────────────────────────────────────────────
// RECOMPUTE
// ────────────────────────────────────────────────────────────────

function recomputeRange() {
  const starts=[],ends=[];
  for(const a of S.athletes){
    starts.push(a.startTime);
    ends.push(a.endTime||a.startTime+(a.streams.time[a.streams.time.length-1]||0));
  }
  if(S.me&&S.me.startTime){starts.push(S.me.startTime);ends.push(S.me.startTime+S.me.duration);}
  if(!starts.length)return;
  const dataStart=Math.min(...starts),dataEnd=Math.max(...ends);
  S.tl.start=S.trim.start?Math.max(S.trim.start,dataStart):dataStart;
  S.tl.end=S.trim.end?Math.min(S.trim.end,dataEnd):dataEnd;
  if(S.tl.cur<S.tl.start)S.tl.cur=S.tl.start;
  $f('t-tot').textContent=fmtDur(S.tl.end-S.tl.start);
  S.lastKfUnix=null;
  drawTimeline();
}

// ────────────────────────────────────────────────────────────────
// TIMELINE DRAWING
// ────────────────────────────────────────────────────────────────

function drawTimeline() {
  const canvas=$f('tl-canvas');
  if(!canvas)return;
  const dur=S.tl.end-S.tl.start;
  const dpr=window.devicePixelRatio||1;
  const W=canvas.offsetWidth||canvas.parentElement&&canvas.parentElement.offsetWidth||200;
  const H=canvas.offsetHeight||36;
  canvas.width=W*dpr; canvas.height=H*dpr;
  const ctx=canvas.getContext('2d');
  ctx.scale(dpr,dpr);

  // Track groove
  const grooveY=H*0.6, grooveH=4;
  ctx.fillStyle='rgba(255,255,255,0.1)';
  ctx.beginPath(); ctx.roundRect(0,grooveY-grooveH/2,W,grooveH,2); ctx.fill();

  if(!dur){return;}
  const toX=t=>((t-S.tl.start)/dur)*W;

  // Time tick intervals
  const intervals=[[3600,'rgba(255,255,255,0.35)',12,true],[1800,'rgba(255,255,255,0.2)',8,false],[900,'rgba(255,255,255,0.13)',5,false]];
  for(const[iv,col,th,label] of intervals){
    if(dur/iv<2)continue;
    const t0=Math.ceil(S.tl.start/iv)*iv;
    for(let t=t0;t<=S.tl.end;t+=iv){
      const x=toX(t);
      ctx.strokeStyle=col; ctx.lineWidth=1;
      ctx.beginPath(); ctx.moveTo(x,grooveY-grooveH/2-1); ctx.lineTo(x,grooveY-grooveH/2-th); ctx.stroke();
      if(label){
        ctx.fillStyle='rgba(255,255,255,0.28)';
        ctx.font='9px -apple-system,sans-serif'; ctx.textAlign='center';
        ctx.fillText(fmtHHMM(t),x,grooveY-grooveH/2-th-3);
      }
    }
  }

  // Keyframe diamond markers
  const hovKf=S.hoveredKf;
  for(const kf of S.keyframes){
    const x=toX(kf.unix);
    if(x<0||x>W)continue;
    const ky=grooveY+9, ks=kf===hovKf?6:4;
    ctx.fillStyle=kf===hovKf?'#ff8a50':'#fc5200';
    if(kf===hovKf){ctx.shadowColor='#fc520088';ctx.shadowBlur=8;}
    ctx.beginPath(); ctx.moveTo(x,ky-ks); ctx.lineTo(x+ks,ky); ctx.lineTo(x,ky+ks); ctx.lineTo(x-ks,ky); ctx.closePath(); ctx.fill();
    ctx.shadowBlur=0;
  }
}

function initKfHit() {
  const hit=$f('kf-hit'), tip=$f('kf-tip');
  if(!hit||!tip)return;

  function kfAtX(clientX) {
    if(!S.keyframes.length||!S.tl.end||S.tl.end<=S.tl.start)return null;
    const rect=hit.getBoundingClientRect();
    const x=clientX-rect.left, W=rect.width;
    const dur=S.tl.end-S.tl.start;
    const THRESH=8;
    let best=null,bestDx=Infinity;
    for(const kf of S.keyframes){
      const kx=((kf.unix-S.tl.start)/dur)*W;
      const dx=Math.abs(x-kx);
      if(dx<THRESH&&dx<bestDx){best=kf;bestDx=dx;}
    }
    return best;
  }

  hit.addEventListener('mousemove',e=>{
    const kf=kfAtX(e.clientX);
    if(kf!==S.hoveredKf){
      S.hoveredKf=kf;
      drawTimeline();
    }
    if(kf&&kf.caption){
      const rect=hit.getBoundingClientRect();
      const dur=S.tl.end-S.tl.start;
      const x=((kf.unix-S.tl.start)/dur)*rect.width;
      tip.textContent=kf.time+' — '+kf.caption;
      tip.style.left=x+'px';
      tip.style.display='block';
      hit.style.cursor='pointer';
    } else {
      tip.style.display='none';
      hit.style.cursor='default';
    }
  });

  hit.addEventListener('mouseleave',()=>{
    S.hoveredKf=null; tip.style.display='none'; drawTimeline();
  });

  hit.addEventListener('click',e=>{
    const kf=kfAtX(e.clientX);
    if(kf){
      S.lastKfUnix=null;
      seekTo(kf.unix);
      toast(kf.time+' — '+(kf.caption||'keyframe'),'info');
    }
  });
}

// ────────────────────────────────────────────────────────────────
// PLAYBACK
// ────────────────────────────────────────────────────────────────

let raf=null;

function seekTo(t) {
  S.tl.cur=Math.max(S.tl.start,Math.min(S.tl.end,t));
  const el=S.tl.cur-S.tl.start,tot=S.tl.end-S.tl.start||1;
  $f('t-cur').textContent=fmtDur(el);
  $f('badge-t').textContent=fmtTime(S.tl.cur);
  $f('timeline').value=(el/tot)*100;
  applyKf(getActiveKf(S.tl.cur));
  let followPos=null;
  for(const a of S.athletes){
    if(S.hidden.has(a.id))continue;
    const mk=S.markers[a.id];if(!mk)continue;
    const pos=posAt(a.streams,a.startTime,S.tl.cur);
    mk.setOpacity(pos?1:0);
    if(pos){mk.setLatLng(pos);if(a.id===MY_ACTIVITY_ID&&!S.me)followPos=pos;}
    const dot=document.querySelector('[data-aid="'+a.id+'"] .astatus');
    if(dot)dot.style.background=pos?a.color:'transparent';
  }
  if(S.me&&S.meMarker){
    const pos=posAt(S.me,S.me.startTime,S.tl.cur);
    S.meMarker.setOpacity(pos?1:0);
    if(pos){S.meMarker.setLatLng(pos);followPos=pos;}
  }
  if(S.followCam&&followPos&&S.map)S.map.panTo(followPos,{animate:false,duration:0});
  updateGauges();
  if(S.sortMode==='position')renderList();
}

function updateGauges() {
  const rel=S.me?S.tl.cur-S.me.startTime:null;
  if(!S.me||rel===null||rel<0||rel>S.me.duration){
    GAUGE_META.forEach(m=>{if(S.gauges[m.key])drawGauge(S.gauges[m.key],null,m.max,m.color,m.label);});
  } else {
    GAUGE_META.forEach(m=>{
      if(!S.gauges[m.key])return;
      const v=m.avg?avgAt(S.me[m.src],S.me.time,rel):valAt(S.me[m.src],S.me.time,rel);
      drawGauge(S.gauges[m.key],v,m.max,m.color,m.label);
    });
  }
  drawAltChart();
}

function togglePlay(){
  if(!S.tl.end||S.tl.end<=S.tl.start){
    toast('Data not loaded yet','warn');
    console.warn('[Viewer] play blocked — start='+S.tl.start+' end='+S.tl.end);
    return;
  }
  S.tl.playing=!S.tl.playing;
  $f('play-btn').innerHTML=S.tl.playing?'⏸':'▶';
  const sb=$f('sidebar');if(sb)sb.classList.toggle('playing',S.tl.playing);
  console.log('[Viewer] play:',S.tl.playing,'cur:',fmtTime(S.tl.cur),'→',fmtTime(S.tl.end),'speed:',S.tl.speed+'x');
  if(S.tl.playing){S.tl.lastTick=performance.now();raf=requestAnimationFrame(tick);}
  else if(raf)cancelAnimationFrame(raf);
}

function tick(now){
  if(!S.tl.playing)return;
  const dt=(now-S.tl.lastTick)/1000;S.tl.lastTick=now;
  const spd=S.tl.speed||10;
  const next=S.tl.cur+dt*spd;
  if(next>=S.tl.end){seekTo(S.tl.end);S.tl.playing=false;$f('play-btn').innerHTML='▶';return;}
  seekTo(next);raf=requestAnimationFrame(tick);
}

function setSpeed(v){S.tl.speed=parseFloat(v);}
function scrub(e){if(S.tl.playing)togglePlay();S.lastKfUnix=null;seekTo(S.tl.start+(e.target.value/100)*(S.tl.end-S.tl.start));}
function toggleFollow(){S.followCam=!S.followCam;$f('follow-btn').classList.toggle('active',S.followCam);toast(S.followCam?'Follow-cam ON':'Follow-cam OFF',S.followCam?'success':'warn');}
function toggleSidebar(){S.sidebarOpen=!S.sidebarOpen;$f('sidebar').classList.toggle('collapsed',!S.sidebarOpen);setTimeout(()=>S.map&&S.map.invalidateSize(),220);}
function toggleSort(){S.sortMode=S.sortMode==='position'?'load':'position';$f('sort-btn').classList.toggle('active',S.sortMode==='position');renderList();}

// ────────────────────────────────────────────────────────────────
// GAUGES  (arc dial)
// ────────────────────────────────────────────────────────────────

function initGauges(){
  GAUGE_META.forEach(m=>{
    const canvas=$f(m.canvasId);
    if(!canvas)return;
    S.gauges[m.key]=canvas;
    drawGauge(canvas,null,m.max,m.color,m.label);
  });
}

function showTempGauge(hasTemp){
  const cell=$f('temp-cell');
  if(cell)cell.style.display=hasTemp?'':'none';
  if(hasTemp){ S.gauges.temp=$f('g-temp'); drawGauge(S.gauges.temp,null,45,'#00bcd4','°C'); }
}

function showSpeedGauge(hasSpd){
  const cell=$f('spd-cell');
  if(cell)cell.style.display=hasSpd?'':'none';
  if(hasSpd){ S.gauges.spd=$f('g-spd'); drawGauge(S.gauges.spd,null,80,'#9b59b6','km/h'); }
}

function drawGauge(canvas, value, max, color, unit){
  const wrap=canvas.parentElement;
  const dpr=window.devicePixelRatio||1;
  const W=wrap.clientWidth||120, H=wrap.clientHeight||120;
  canvas.width=W*dpr; canvas.height=H*dpr;
  const ctx=canvas.getContext('2d');
  ctx.scale(dpr,dpr);

  const cx=W/2, cy=H*0.62;
  const r=Math.min(W*0.4,H*0.55);
  const lw=Math.max(5,r*0.13);
  const START=Math.PI*0.78, SPAN=Math.PI*1.44;

  // Background arc
  ctx.beginPath();
  ctx.arc(cx,cy,r,START,START+SPAN);
  ctx.strokeStyle='rgba(255,255,255,0.1)';
  ctx.lineWidth=lw; ctx.lineCap='round'; ctx.stroke();

  // Value arc
  if(value!=null&&!isNaN(value)){
    const frac=Math.min(Math.max(value/max,0),1);
    const g=ctx.createLinearGradient(cx-r,cy,cx+r,cy);
    g.addColorStop(0,color+'aa'); g.addColorStop(1,color);
    ctx.beginPath();
    ctx.arc(cx,cy,r,START,START+frac*SPAN);
    ctx.strokeStyle=g; ctx.lineWidth=lw; ctx.lineCap='round'; ctx.stroke();
  }

  // Value text
  ctx.textAlign='center'; ctx.textBaseline='middle';
  if(value!=null&&!isNaN(value)){
    ctx.fillStyle='#fff';
    ctx.font='bold '+Math.round(r*0.52)+'px -apple-system,sans-serif';
    ctx.fillText(Math.round(value),cx,cy+r*0.08);
    ctx.fillStyle='rgba(255,255,255,0.4)';
    ctx.font=Math.round(r*0.24)+'px sans-serif';
    ctx.fillText(unit,cx,cy+r*0.48);
  } else {
    ctx.fillStyle='rgba(255,255,255,0.2)';
    ctx.font=Math.round(r*0.45)+'px sans-serif';
    ctx.fillText('—',cx,cy+r*0.1);
  }

  // Tick marks
  ctx.strokeStyle='rgba(255,255,255,0.18)';
  ctx.lineWidth=1;
  [0,0.5,1].forEach(f=>{
    const a=START+f*SPAN;
    const x1=cx+(r-lw)*Math.cos(a), y1=cy+(r-lw)*Math.sin(a);
    const x2=cx+(r+lw*0.5)*Math.cos(a), y2=cy+(r+lw*0.5)*Math.sin(a);
    ctx.beginPath(); ctx.moveTo(x1,y1); ctx.lineTo(x2,y2); ctx.stroke();
  });
}

function resizeGauges(){
  GAUGE_META.forEach(m=>{
    const canvas=S.gauges[m.key];if(!canvas)return;
    const v=S.me?valAt(S.me[m.src],S.me.time,S.tl.cur-S.me.startTime):null;
    drawGauge(canvas,v,m.max,m.color,m.label);
  });
  drawAltChart();
  drawTimeline();
}

function drawAltChart() {
  const canvas=$f('g-alt');
  if(!canvas)return;
  let altArr=null, timeArr=null, startTime=null, duration=null;
  if(S.me&&S.me.altitude&&S.me.altitude.some(v=>v!=null)){
    altArr=S.me.altitude; timeArr=S.me.time; startTime=S.me.startTime; duration=S.me.duration;
  } else {
    const me=S.athletes.find(a=>a.id===MY_ACTIVITY_ID||a.athleteId===MY_ACTIVITY_ID);
    if(me&&me.streams.altitude&&me.streams.altitude.some(v=>v!=null)){
      altArr=me.streams.altitude; timeArr=me.streams.time; startTime=me.startTime;
      duration=me.streams.time[me.streams.time.length-1]||0;
    }
  }

  const wrap=canvas.parentElement;
  const dpr=window.devicePixelRatio||1;
  const W=wrap.clientWidth||200, H=wrap.clientHeight||100;
  canvas.width=W*dpr; canvas.height=H*dpr;
  const ctx=canvas.getContext('2d');
  ctx.scale(dpr,dpr);

  if(!altArr||!timeArr||!duration){
    ctx.fillStyle='rgba(255,255,255,0.1)';
    ctx.font='11px sans-serif'; ctx.textAlign='center'; ctx.textBaseline='middle';
    ctx.fillText('No elevation data',W/2,H/2);
    return;
  }

  const pts=[];
  for(let i=0;i<timeArr.length;i++){if(altArr[i]!=null)pts.push({t:timeArr[i],a:altArr[i]});}
  if(pts.length<2){ctx.fillStyle='rgba(255,255,255,0.1)';ctx.font='11px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('No elevation data',W/2,H/2);return;}

  const minA=Math.min(...pts.map(p=>p.a));
  const maxA=Math.max(...pts.map(p=>p.a));
  const rangeA=Math.max(1,maxA-minA);
  const pad=8;
  const toX=t=>(t/duration)*(W-pad*2)+pad;
  const toY=a=>H-pad-(a-minA)/rangeA*(H-pad*2.5);

  const grad=ctx.createLinearGradient(0,0,0,H);
  grad.addColorStop(0,'rgba(52,152,219,0.55)');
  grad.addColorStop(1,'rgba(52,152,219,0.05)');
  ctx.beginPath(); ctx.moveTo(toX(pts[0].t),H);
  pts.forEach(p=>ctx.lineTo(toX(p.t),toY(p.a)));
  ctx.lineTo(toX(pts[pts.length-1].t),H); ctx.closePath();
  ctx.fillStyle=grad; ctx.fill();

  ctx.beginPath(); pts.forEach((p,i)=>i?ctx.lineTo(toX(p.t),toY(p.a)):ctx.moveTo(toX(p.t),toY(p.a)));
  ctx.strokeStyle='rgba(52,152,219,0.85)'; ctx.lineWidth=1.5; ctx.lineJoin='round'; ctx.stroke();

  if(startTime&&S.tl.cur>=startTime&&S.tl.cur<=startTime+duration){
    const rel=S.tl.cur-startTime;
    const px=toX(rel);
    const curAlt=valAt(altArr,timeArr,rel);
    ctx.strokeStyle='rgba(255,255,255,0.7)'; ctx.lineWidth=1; ctx.setLineDash([3,3]);
    ctx.beginPath(); ctx.moveTo(px,0); ctx.lineTo(px,H); ctx.stroke(); ctx.setLineDash([]);
    if(curAlt!=null){
      const py=toY(curAlt);
      ctx.fillStyle='#3498db'; ctx.beginPath(); ctx.arc(px,py,3,0,Math.PI*2); ctx.fill();
      ctx.fillStyle='#fff'; ctx.font='bold 9px sans-serif'; ctx.textAlign='left'; ctx.textBaseline='bottom';
      ctx.fillText(Math.round(curAlt)+'m',px+4,py-1);
    }
  }

  ctx.fillStyle='rgba(255,255,255,0.3)'; ctx.font='9px sans-serif'; ctx.textAlign='right'; ctx.textBaseline='top';
  ctx.fillText(Math.round(maxA)+'m',W-2,pad);
  ctx.textBaseline='bottom';
  ctx.fillText(Math.round(minA)+'m',W-2,H-2);
}

// ────────────────────────────────────────────────────────────────
// RENDER LIST
// ────────────────────────────────────────────────────────────────

function positionFrac(a) {
  if(S.tl.cur < a.startTime) return -1;
  if(S.tl.cur > a.endTime) return 2 + (a.endTime - a.startTime);
  return (S.tl.cur - a.startTime) / Math.max(1, a.endTime - a.startTime);
}

function renderList(){
  $f('acnt').textContent=S.athletes.length;
  const list=$f('alist');

  if(!S.athletes.length){
    list.innerHTML='<div style="padding:10px 12px;font-size:11px;color:var(--dim)">Load athletes JSON or click Sample</div>';
  } else {
    let athletes=[...S.athletes];
    if(S.sortMode==='position'){
      athletes.sort((a,b)=>{
        const fa=positionFrac(a), fb=positionFrac(b);
        if(fa>=2&&fb>=2) return a.endTime-b.endTime;
        if(fa>=2) return -1; if(fb>=2) return 1;
        if(fa<0&&fb<0) return 0;
        if(fa<0) return 1; if(fb<0) return -1;
        return fb-fa;
      });
    }
    list.innerHTML=athletes.map((a,rank)=>{
      const dur=fmtDur(a.streams.time[a.streams.time.length-1]||0);
      const isMe=a.id===MY_ACTIVITY_ID;
      const frac=positionFrac(a);
      const active=frac>=0&&frac<2;
      const finished=frac>=2;
      let statusMeta='';
      if(S.sortMode==='position'){
        if(finished) statusMeta='<span style="color:var(--green)">✓ '+fmtDur(a.endTime-a.startTime)+'</span>';
        else if(active) statusMeta='<span style="color:var(--dim)">'+Math.round(Math.min(frac,1)*100)+'%</span>';
        else statusMeta='<span style="color:var(--dim)">waiting</span>';
      }
      const rankBadge=S.sortMode==='position'?'<span class="apos'+(rank===0?' lead':'')+'">'+  (rank+1)+'</span>':'';
      const progBar=S.sortMode==='position'&&active
        ?'<div class="aprog"><div class="aprog-fill" style="width:'+Math.round(Math.min(frac,1)*100)+'%;background:'+a.color+'"></div></div>':''
      ;
      const chk='<input type="checkbox" class="route-chk" title="Highlight route"'
        +(S.selectedTracks.has(a.id)?' checked':'')
        +' onclick="event.stopPropagation();toggleRouteSelect(\''+a.id+'\')">';
      return '<div class="aitem'+(S.hidden.has(a.id)?' off':'')+'" data-aid="'+a.id+'" onclick="toggleAth(\''+a.id+'\')">'
        +rankBadge
        +chk
        +'<div class="adot" style="background:'+a.color+(isMe?';border:2px solid #fff':'')+'"></div>'
        +'<div class="ainfo">'
        +'<div class="aname">'+esc(a.name)+(isMe?'<span class="mybadge" style="margin-left:4px">ME</span>':'')+'</div>'
        +'<div class="ameta">'+(statusMeta||dur)+'</div>'
        +progBar
        +'</div>'
        +'<div class="astatus" style="background:'+a.color+'"></div>'
        +'</div>';
    }).join('');
  }

  if(S.me){
    list.innerHTML+='<div style="margin-top:5px;border-top:1px solid var(--border);padding-top:5px">'
      +'<div class="aitem" style="cursor:default">'
      +'<div class="adot" style="background:#fc5200;border:2px solid #fff;box-sizing:border-box"></div>'
      +'<div class="ainfo">'
      +'<div class="aname">You <span class="mybadge">FIT</span></div>'
      +'<div class="ameta">'+fmtDur(S.me.duration)+'</div>'
      +'</div>'
      +'</div></div>';
  }
}

function toggleAth(id){
  S.hidden.has(id)?S.hidden.delete(id):S.hidden.add(id);
  const mk=S.markers[id],tr=S.tracks[id];
  if(S.hidden.has(id)){
    if(mk)mk.setOpacity(0);if(tr)tr.setStyle({opacity:0});
    S.selectedTracks.delete(id);
  } else {
    const sel=S.selectedTracks.has(id);
    if(tr)tr.setStyle({opacity:sel?1:0.28,weight:sel?4:2});
    seekTo(S.tl.cur);
  }
  renderList();
}

function toggleRouteSelect(id){
  if(S.tl.playing)return;
  const tr=S.tracks[id];
  if(S.selectedTracks.has(id)){
    S.selectedTracks.delete(id);
    if(tr)tr.setStyle({opacity:S.hidden.has(id)?0:0.28,weight:2});
  } else {
    S.selectedTracks.add(id);
    if(tr)tr.setStyle({opacity:1,weight:4});
  }
  renderList();
  fitSelectedBounds();
}

function fitSelectedBounds(){
  if(!S.selectedTracks.size)return;
  const pts=[];
  for(const id of S.selectedTracks){
    const a=S.athletes.find(a=>a.id===id);
    if(a)a.streams.latlng.filter(Boolean).forEach(p=>pts.push(p));
  }
  if(pts.length)S.map.fitBounds(L.latLngBounds(pts),{padding:[30,30]});
}

// ────────────────────────────────────────────────────────────────
// DATA APPLY
// ────────────────────────────────────────────────────────────────

function _applyData(d) {
  console.log('[Viewer] _applyData: athletes='+(d.athletes||[]).length+' fit='+!!d.me+' kf='+(d.keyframes||[]).length);
  if(d.myActivityId)MY_ACTIVITY_ID=d.myActivityId;
  if(d.athletes&&d.athletes.length){
    S.athletes=d.athletes;
    console.log('[Viewer] athletes loaded:',S.athletes.length,'| first startTime:',fmtTime(S.athletes[0].startTime));
  }
  if(d.me){
    S.me=d.me;
    showTempGauge(d.me.temperature&&d.me.temperature.some(v=>v!=null));
    showSpeedGauge(d.me.speed&&d.me.speed.some(v=>v!=null));
    console.log('[Viewer] FIT: startTime='+d.me.startTime+' duration='+d.me.duration+'s pts='+d.me.time.length);
  }
  if(d.keyframes&&d.keyframes.length){S.keyframes=d.keyframes;console.log('[Viewer] keyframes:',S.keyframes.length);}
  if(d.trim)console.log('[Viewer] pre-trimmed:',fmtTime(d.trim.start),'→',fmtTime(d.trim.end));
}

function _setupViewer() {
  if(!S.athletes.length){console.warn('[Viewer] _setupViewer: no athletes');return;}
  recomputeRange();
  console.log('[Viewer] range:',fmtTime(S.tl.start),'→',fmtTime(S.tl.end),'('+(S.tl.end-S.tl.start)+'s)');
  redrawAthletes();
  if(S.me)redrawMe();
  fitBounds();
  renderList();
  seekTo(S.tl.start);
  $f('nodatamsg').style.display='none';
  $f('mapbadge').style.display='block';
  requestAnimationFrame(()=>{resizeGauges();drawTimeline();if(S.keyframes.length)S.lastKfUnix=null;});
  console.log('[Viewer] ready — press play or space');
}

function loadEmbedded() {
  const el=document.getElementById('__flyby_data__');
  if(!el)return false;
  try{_applyData(JSON.parse(el.textContent));return true;}
  catch(err){console.error('[Embedded] parse error:',err);return false;}
}

// ────────────────────────────────────────────────────────────────
// TOAST
// ────────────────────────────────────────────────────────────────

let toastTmr=null;
function toast(msg,type='info'){
  const el=$f('toast');
  el.textContent=msg;el.className='show '+(type||'');
  clearTimeout(toastTmr);
  toastTmr=setTimeout(()=>el.className='',3800);
}

// ────────────────────────────────────────────────────────────────
// ROTATE PROMPT
// ────────────────────────────────────────────────────────────────

function updateRotatePrompt(){
  const portrait=window.innerHeight>window.innerWidth;
  const touch=navigator.maxTouchPoints>0;
  $f('rotate-prompt').style.display=(portrait&&touch)?'flex':'';
}

// ────────────────────────────────────────────────────────────────
// INIT SHARED
// ────────────────────────────────────────────────────────────────

function initShared(){
  initMap();
  initGauges();
  initKfHit();
  $f('follow-btn').classList.toggle('active',S.followCam);
  // Start with sidebar collapsed; redrawAthletes expands it on first data load
  const sb=$f('sidebar');if(sb)sb.classList.add('collapsed');

  document.addEventListener('keydown',function(e){
    if(e.target.tagName==='INPUT'||e.target.tagName==='SELECT'||e.target.tagName==='TEXTAREA')return;
    const step=e.shiftKey?60:10;
    switch(e.key){
      case ' ':          e.preventDefault();togglePlay();break;
      case 'ArrowRight': e.preventDefault();if(S.tl.playing)togglePlay();S.lastKfUnix=null;seekTo(S.tl.cur+step);break;
      case 'ArrowLeft':  e.preventDefault();if(S.tl.playing)togglePlay();S.lastKfUnix=null;seekTo(S.tl.cur-step);break;
      case '+':case '=': if(S.map)S.map.setZoom(S.map.getZoom()+1);break;
      case '-':case '_': if(S.map)S.map.setZoom(S.map.getZoom()-1);break;
      case 'h':case 'H': toggleSidebar();break;
      case 'f':case 'F': toggleFollow();break;
      case 'p':case 'P': toggleSort();break;
      case 'i':case 'I': if(typeof setTrimStart==='function')setTrimStart();break;
      case 'o':case 'O': if(typeof setTrimEnd==='function')setTrimEnd();break;
    }
  });

  window.addEventListener('resize',()=>{resizeGauges();drawTimeline();updateRotatePrompt();});
  window.addEventListener('orientationchange',()=>{setTimeout(()=>{resizeGauges();drawTimeline();updateRotatePrompt();},150);});
}
