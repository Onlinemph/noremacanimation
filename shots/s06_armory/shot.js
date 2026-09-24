// s06_armory — 18s. 0-6s: KS-23 on the table under the swinging bulb, pump racks ~4.5s.
// 6-18s: five character/weapon cards, Soviet technical-manual style, Canvas2D over a
// dimmed/blurred hold of the 3D scene.

let smallCanvas, smallCtx; // reused offscreen canvas for the cheap card-phase blur

function pumpEnvelope(t) {
  const t0 = 4.15, t1 = 4.45, t2 = 4.8;
  if (t < t0 || t > t2) return 0;
  if (t < t1) return (t - t0) / (t1 - t0);
  return 1 - (t - t1) / (t2 - t1);
}

// ---------------------------------------------------------------- textures --
function drawStar(ctx, cx, cy, r, color, alpha) {
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = color;
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rad = i % 2 === 0 ? r : r * 0.42;
    const x = cx + Math.cos(a) * rad, y = cy + Math.sin(a) * rad;
    i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
  }
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function backWallTexture(ctx, w, h) {
  ctx.clearRect(0, 0, w, h);
  // red star, left of the stencil
  drawStar(ctx, w * 0.24, h * 0.38, w * 0.075, '#9c1c1c', 0.92);
  drawStar(ctx, w * 0.24, h * 0.38, w * 0.075, '#000', 0.15);

  // stencilled ОРУЖЕЙНАЯ across the middle, painted rough
  ctx.save();
  const label = 'ОРУЖЕЙНАЯ';
  let fsz = h * 0.12;
  ctx.font = `${Math.round(fsz)}px "Russo One"`;
  const avail = w * 0.98 - w * 0.36;
  let mw = ctx.measureText(label).width;
  if (mw > avail) { fsz *= avail / mw; ctx.font = `${Math.round(fsz)}px "Russo One"`; }
  ctx.textBaseline = 'middle';
  ctx.textAlign = 'left';
  let lx = w * 0.36, ly = h * 0.40;
  for (let pass = 0; pass < 3; pass++) {
    ctx.globalAlpha = pass === 0 ? 0.82 : 0.10;
    ctx.fillStyle = '#d9d2c0';
    ctx.fillText(label, lx + (pass ? (Math.random() - 0.5) * 4 : 0), ly);
  }
  ctx.globalAlpha = 1;
  ctx.restore();
  // paint drips under the stencil
  ctx.save();
  ctx.fillStyle = 'rgba(180,172,150,0.5)';
  for (let i = 0; i < 14; i++) {
    const x = lx + Math.random() * w * 0.55;
    const len = h * (0.03 + Math.random() * 0.08);
    ctx.fillRect(x, ly + h * 0.05, 2, len);
  }
  ctx.restore();

  // torn poster, lower-right: faded Soviet propaganda placard
  ctx.save();
  ctx.translate(w * 0.90, h * 0.78);
  ctx.rotate(-0.04);
  const pw = w * 0.26, ph = h * 0.42;
  ctx.beginPath();
  ctx.moveTo(-pw / 2, -ph / 2);
  ctx.lineTo(pw * 0.1, -ph / 2 + 6);
  ctx.lineTo(pw / 2, -ph / 2 - 4);
  ctx.lineTo(pw / 2 - 8, ph * 0.1);
  ctx.lineTo(pw / 2, ph / 2);
  ctx.lineTo(-pw * 0.05, ph / 2 - 14);
  ctx.lineTo(-pw / 2, ph / 2);
  ctx.lineTo(-pw / 2 + 10, ph * 0.15);
  ctx.closePath();
  ctx.fillStyle = '#7a2222';
  ctx.globalAlpha = 0.55;
  ctx.fill();
  ctx.globalAlpha = 0.85;
  ctx.fillStyle = '#e7d9b0';
  ctx.font = `bold ${Math.round(ph * 0.16)}px "Russo One"`;
  ctx.textAlign = 'center';
  ctx.fillText('СССР', 0, -ph * 0.1);
  ctx.font = `${Math.round(ph * 0.07)}px "Oswald"`;
  ctx.fillText('ВПЕРЁД', 0, ph * 0.08);
  ctx.restore();

  // general grime speckle
  ctx.save();
  ctx.globalAlpha = 0.06;
  ctx.fillStyle = '#000';
  for (let i = 0; i < 400; i++) {
    ctx.fillRect(Math.random() * w, Math.random() * h, 2, 2);
  }
  ctx.restore();
}

function crateStencilTexture(ctx, w, h) {
  ctx.clearRect(0, 0, w, h);
  ctx.save();
  ctx.translate(w / 2, h / 2);
  ctx.globalAlpha = 0.88;
  ctx.fillStyle = '#160f08';
  ctx.strokeStyle = '#160f08';
  ctx.lineWidth = w * 0.012;
  ctx.strokeRect(-w * 0.36, -h * 0.30, w * 0.72, h * 0.60);
  ctx.font = `bold ${Math.round(h * 0.22)}px "PT Mono"`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('1944', 0, -h * 0.02);
  ctx.font = `${Math.round(h * 0.075)}px "PT Mono"`;
  ctx.fillText('МО СССР', 0, h * 0.20);
  drawStar(ctx, 0, -h * 0.30, h * 0.05, '#160f08', 0.9);
  ctx.restore();
}

// ------------------------------------------------------------ card drawing --
const CARDS = [
  { key: 'ks23', ru: 'КС-23', en: 'KS-23', spec: '23×75 mm · pump action',
    person: 'DR. ELLEN HOLLIS', role: 'glaciologist', extra: null },
  { key: 'aks74u', ru: 'АКС-74У', en: 'AKS-74U', spec: '5.45×39 mm · folding stock',
    person: 'Ml. SGT. MIKHAIL "MISHA" VOLKOV', role: 'last of the garrison', extra: '+ РГД-5 / RGD-5 grenades' },
  { key: 'ppsh41', ru: 'ППШ-41', en: 'PPSh-41', spec: '7.62×25 mm · drum · reserve stock, 1944',
    person: 'ANDERS LUNDQVIST', role: 'mechanic', extra: null },
  { key: 'spsh', ru: 'СПШ', en: 'SPSh flare pistol', spec: '26 mm + fire axe',
    person: 'RAY OKAFOR', role: 'radio operator', extra: null },
  { key: 'pm', ru: 'ПМ', en: 'Makarov PM', spec: '9×18 mm',
    person: '(spare.)', role: 'Nobody wants to think about what it’s for.', extra: null, dim: true },
];

// side-profile silhouettes, muzzle to the right (+x), built from stacked primitive
// shapes (technical-manual style) rather than a single freehand outline, so each
// signature feature reads clearly. Units are gun-local, scaled/positioned by caller.
function rrect(ctx, cx, cy, s, x, y, w, hh, r) {
  ctx.beginPath();
  ctx.roundRect(cx + x * s, cy + y * s, w * s, hh * s, (r || 1) * s);
}

// ---- weapon line art, drawn from real dimensions (millimetres; x toward the muzzle, y down)
// Each profile is filled in ink, then engraved with paper-coloured detail lines, like a manual plate.
const PAPER = '#d9cba6';
function gunCtx(ctx, cx, cy, lenMM, widthPx, x0, y0) {
  const k = widthPx / lenMM;
  const X = x => cx + (x - x0) * k, Y = y => cy + (y - y0) * k;
  const poly = (pts, fill = true) => { ctx.beginPath(); pts.forEach(([x, y], i) => i ? ctx.lineTo(X(x), Y(y)) : ctx.moveTo(X(x), Y(y))); ctx.closePath(); fill ? ctx.fill() : ctx.stroke(); };
  const rect = (x, y, w, h, r = 0) => { ctx.beginPath(); ctx.roundRect(X(x), Y(y), w * k, h * k, r * k); ctx.fill(); };
  const line = (pts, wmm) => { ctx.lineWidth = Math.max(0.8, wmm * k); ctx.beginPath(); pts.forEach(([x, y], i) => i ? ctx.lineTo(X(x), Y(y)) : ctx.moveTo(X(x), Y(y))); ctx.stroke(); };
  const circ = (x, y, r, fill = true) => { ctx.beginPath(); ctx.arc(X(x), Y(y), r * k, 0, Math.PI * 2); fill ? ctx.fill() : ctx.stroke(); };
  const ring = (x, y, rx, ry, wmm) => { ctx.lineWidth = Math.max(0.8, wmm * k); ctx.beginPath(); ctx.ellipse(X(x), Y(y), rx * k, ry * k, 0, 0, Math.PI * 2); ctx.stroke(); };
  return { k, X, Y, poly, rect, line, circ, ring };
}

function drawGun(ctx, key, cx, cy, s, ink) {
  ctx.save();
  ctx.fillStyle = ink; ctx.strokeStyle = ink; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  const engrave = () => { ctx.strokeStyle = PAPER; ctx.fillStyle = PAPER; };
  const inkup = () => { ctx.strokeStyle = ink; ctx.fillStyle = ink; };

  if (key === 'ks23') {
    // KS-23: 1040 mm, 23 mm bore, pump action, tube magazine, wooden stock with semi-pistol grip
    const g = gunCtx(ctx, cx, cy, 1040, 410 * s, 520, 40);
    g.rect(470, -17, 570, 34, 6);                                   // barrel
    g.rect(1016, -27, 10, 12, 2);                                   // front sight
    g.rect(470, 17, 380, 26, 10);                                   // magazine tube
    g.rect(840, 12, 16, 36, 4);                                     // tube cap / barrel band
    g.rect(560, 6, 200, 46, 16);                                    // pump forend
    g.poly([[300, -30], [470, -30], [480, -20], [480, 46], [440, 52], [330, 52], [300, 44]]);  // receiver
    g.rect(430, -39, 22, 11, 3);                                    // rear sight
    g.line([[332, 52], [336, 80], [372, 86], [410, 70], [416, 52]], 7);  // trigger guard
    g.line([[372, 54], [366, 74]], 6);                              // trigger
    g.poly([[302, -28], [40, -6], [8, -8], [0, 2], [0, 124], [14, 132], [180, 80], [222, 72],
            [246, 126], [288, 132], [304, 72], [312, 46]]);          // wooden stock + grip
    engrave();
    for (let i = 0; i < 7; i++) g.line([[585 + i * 25, 12], [585 + i * 25, 46]], 5);  // forend grooves
    g.poly([[360, -18], [450, -18], [450, 4], [360, 4]], false);    // ejection port outline
    ctx.lineWidth = Math.max(0.8, 3 * g.k); g.poly([[360, -18], [450, -18], [450, 4], [360, 4]], false);
    g.line([[480, 0], [1030, 0]], 1.5);                             // barrel highlight
    g.line([[0, 10], [0, 118]], 6);                                 // buttplate seam
    g.line([[300, 30], [440, 30]], 2);                              // receiver seam
    inkup();
  }

  else if (key === 'aks74u') {
    // AKS-74U: 730 mm stock extended, 206 mm barrel, flash hider/booster, curved 30-rd magazine, skeleton folding stock
    const g = gunCtx(ctx, cx, cy, 730, 330 * s, 370, 90);
    g.poly([[672, -20], [700, -24], [730, -20], [730, 20], [700, 24], [672, 20]]);   // muzzle booster
    g.rect(600, -9, 76, 18, 3);                                     // barrel
    g.poly([[555, -12], [612, -12], [612, 14], [555, 14]]);         // gas block
    g.poly([[575, -12], [585, -46], [602, -46], [608, -12]]);       // front sight tower
    g.rect(400, -34, 165, 20, 8);                                   // gas tube + upper handguard
    g.poly([[400, -12], [558, -12], [558, 8], [548, 24], [410, 24], [400, 14]]);      // lower handguard
    g.poly([[170, -24], [410, -24], [410, 28], [170, 28]]);         // receiver
    g.poly([[170, -24], [180, -36], [360, -36], [400, -24]]);       // hinged top cover
    g.poly([[318, -36], [322, -48], [352, -48], [356, -36]]);       // flip rear sight
    // curved 30-round magazine sweeping forward
    ctx.beginPath();
    ctx.moveTo(g.X(328), g.Y(26)); ctx.lineTo(g.X(392), g.Y(26));
    ctx.quadraticCurveTo(g.X(412), g.Y(150), g.X(468), g.Y(246));
    ctx.lineTo(g.X(404), g.Y(270));
    ctx.quadraticCurveTo(g.X(350), g.Y(160), g.X(328), g.Y(26));
    ctx.fill();
    g.poly([[250, 26], [236, 150], [200, 152], [206, 26]]);         // pistol grip, raked back
    g.line([[252, 28], [262, 58], [300, 60], [318, 28]], 7);        // trigger guard
    g.line([[280, 30], [276, 50]], 5);                              // trigger
    // skeleton stock: top strut, angled lower strut, butt plate
    g.line([[170, -16], [12, -16]], 16);
    g.line([[170, 20], [18, 66]], 14);
    g.poly([[0, -26], [22, -26], [24, 84], [2, 86]]);
    engrave();
    g.line([[190, -4], [300, -4]], 2);                              // receiver rib
    g.poly([[300, -18], [360, -18], [360, -4], [300, -4]], false);  // ejection port
    for (let i = 0; i < 6; i++) g.line([[420 + i * 22, -6], [420 + i * 22, 18]], 3);   // handguard ribs
    for (let i = 0; i < 4; i++) g.line([[704, -16 + i * 10], [724, -16 + i * 10]], 2); // booster ports
    g.line([[36, -16], [150, -16]], 3);                             // strut lightening slot
    inkup();
  }

  else if (key === 'ppsh41') {
    // PPSh-41: 843 mm, perforated barrel jacket with slanted compensator, wooden stock, 71-rd drum
    const g = gunCtx(ctx, cx, cy, 843, 380 * s, 420, 50);
    g.poly([[520, -22], [843, -22], [812, 22], [520, 22]]);         // barrel jacket + slanted compensator front
    g.rect(812, -34, 12, 14, 3);                                    // front sight hood
    g.poly([[360, -26], [530, -26], [530, 24], [360, 24]]);         // receiver
    g.poly([[455, -26], [460, -40], [488, -40], [492, -26]]);       // L-flip rear sight
    g.circ(472, 118, 84);                                           // 71-round drum
    g.rect(446, 20, 54, 24, 4);                                     // drum neck
    g.poly([[362, -20], [230, -12], [0, 8], [0, 150], [38, 154], [252, 56], [330, 44],
            [360, 26], [560, 26], [560, 22], [362, 22]]);            // one-piece wooden stock
    g.line([[370, 44], [372, 72], [420, 74], [428, 44]], 7);        // trigger guard
    engrave();
    for (let r = 0; r < 2; r++) for (let i = 0; i < 7; i++) g.ring(560 + i * 34, -8 + r * 16, 11, 4.5, 3);  // cooling slots
    g.ring(472, 118, 70, 70, 3); g.ring(472, 118, 22, 22, 3);       // drum face
    g.line([[0, 16], [0, 140]], 6);                                 // buttplate
    g.line([[380, -12], [520, -12]], 2);                            // bolt track
    inkup();
  }

  else if (key === 'spsh') {
    // SPSh-44 signal pistol: 26 mm bore, fat barrel, break action, big hammer, raked grip
    const g = gunCtx(ctx, cx, cy, 280, 180 * s, 150, 55);
    g.rect(96, -24, 184, 48, 8);                                    // barrel
    g.rect(268, -28, 12, 56, 4);                                    // muzzle ring
    g.poly([[44, -28], [110, -28], [110, 32], [60, 34], [44, 18]]); // frame
    g.poly([[48, -26], [24, -46], [18, -38], [40, -12]]);           // hammer spur
    g.poly([[48, 26], [86, 30], [52, 150], [12, 146]]);             // grip
    g.line([[80, 32], [88, 64], [116, 64], [120, 32]], 6);          // trigger guard
    engrave();
    g.line([[110, -24], [110, 24]], 3);                             // break-action hinge seam
    g.line([[120, 0], [262, 0]], 2);
    for (let i = 0; i < 5; i++) g.line([[34 + i * 5, 60 + i * 18], [64 + i * 4, 64 + i * 18]], 2);  // grip checkering
    inkup();
  }

  else if (key === 'pm') {
    // Makarov PM: 161 mm, blowback, exposed hammer, star on the grip
    const g = gunCtx(ctx, cx, cy, 161, 170 * s, 85, 45);
    g.poly([[16, -20], [156, -20], [161, -14], [161, 6], [16, 6]]); // slide
    g.poly([[18, -16], [4, -24], [0, -18], [12, -4]]);              // hammer spur
    g.poly([[20, 6], [140, 6], [140, 18], [20, 22]]);               // frame
    g.poly([[24, 18], [70, 18], [58, 118], [14, 114]]);             // grip
    g.line([[72, 20], [80, 46], [116, 46], [124, 18]], 5);          // trigger guard
    engrave();
    for (let i = 0; i < 8; i++) g.line([[22 + i * 4, -18], [22 + i * 4, 4]], 1.4);  // slide serrations
    g.line([[16, -6], [150, -6]], 1.2);
    g.circ(42, 70, 12, false);                                     // star medallion
    ctx.lineWidth = Math.max(0.8, 2 * g.k); g.circ(42, 70, 12, false);
    inkup();
  }
  ctx.restore();
}

function drawGrenade(ctx, cx, cy, s, ink) {
  // RGD-5: 114 mm tall egg body, fuse head and spoon lever
  ctx.save(); ctx.fillStyle = ink; ctx.strokeStyle = ink; ctx.lineJoin = 'round';
  const g = gunCtx(ctx, cx, cy, 114, 60 * s, 0, 30);
  ctx.beginPath(); ctx.ellipse(g.X(0), g.Y(50), 28 * g.k, 36 * g.k, 0, 0, Math.PI * 2); ctx.fill();
  g.rect(-9, -2, 18, 16, 2);                                        // fuse body
  g.poly([[9, 0], [18, -2], [30, 52], [24, 54]]);                   // spoon lever down the side
  g.ring(-12, 0, 7, 7, 3);                                          // pull ring
  ctx.strokeStyle = PAPER; g.line([[-28, 50], [28, 50]], 2); g.line([[-26, 34], [26, 34]], 1.2); g.line([[-26, 66], [26, 66]], 1.2);
  ctx.restore();
}

function drawAxe(ctx, cx, cy, s, ink) {
  // Soviet fire axe: long handle, blade and pick
  ctx.save(); ctx.fillStyle = ink; ctx.strokeStyle = ink; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  const g = gunCtx(ctx, cx, cy, 700, 150 * s, 0, 0);
  ctx.save(); ctx.translate(cx, cy); ctx.rotate(-1.2); ctx.translate(-cx, -cy);
  g.rect(-330, -16, 660, 32, 12);                                    // handle
  g.poly([[250, -18], [340, -18], [350, -95], [290, -120], [270, -40]]);   // blade (toward -y)
  g.poly([[270, 18], [330, 18], [300, 120]]);                        // pick
  ctx.strokeStyle = PAPER; g.line([[296, -110], [340, -92]], 4);     // edge bevel
  ctx.restore(); ctx.restore();
}

// deterministic pseudo-random in [0,1), so per-frame overlay redraws are stable
// (Math.random() would flicker every frame since overlay() runs each frame)
function rand(seed) {
  const x = Math.sin(seed * 12.9898) * 43758.5453;
  return x - Math.floor(x);
}

function drawPortrait(ctx, x, y, w, hh, s, dim) {
  ctx.save();
  ctx.fillStyle = '#8c8064';
  ctx.strokeStyle = '#241d12';
  ctx.lineWidth = 2.5 * s;
  ctx.fillRect(x, y, w, hh);
  ctx.strokeRect(x, y, w, hh);
  if (!dim) {
    ctx.fillStyle = '#241d12';
    const cx = x + w / 2;
    // bust silhouette: head + shoulders
    ctx.beginPath();
    ctx.arc(cx, y + hh * 0.38, w * 0.22, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(x + w * 0.12, y + hh * 0.98);
    ctx.quadraticCurveTo(x + w * 0.08, y + hh * 0.60, cx, y + hh * 0.56);
    ctx.quadraticCurveTo(x + w * 0.92, y + hh * 0.60, x + w * 0.88, y + hh * 0.98);
    ctx.closePath();
    ctx.fill();
  } else {
    // unclaimed spare: empty frame, a faint diagonal scratch
    ctx.strokeStyle = 'rgba(36,29,18,0.35)';
    ctx.lineWidth = 1.5 * s;
    ctx.beginPath(); ctx.moveTo(x + w * 0.15, y + hh * 0.2); ctx.lineTo(x + w * 0.85, y + hh * 0.85); ctx.stroke();
  }
  ctx.restore();
}

function stamp(ctx, cx, cy, scale, alpha, W) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(-0.24);
  ctx.scale(scale, scale);
  ctx.globalAlpha = alpha * 0.85;
  ctx.strokeStyle = '#a11c1c';
  ctx.fillStyle = '#a11c1c';
  ctx.lineWidth = 3 * (W / 1280);
  const rw = 250 * (W / 1280), rh = 62 * (W / 1280);
  ctx.strokeRect(-rw / 2, -rh / 2, rw, rh);
  ctx.font = `bold ${Math.round(15 * (W / 1280))}px "Special Elite"`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('СОВЕРШЕННО СЕКРЕТНО', 0, 0);
  ctx.restore();
}

function drawCard(ctx, card, ct, s, W, H, idx) {
  const enter = Math.min(1, ct / 0.22);
  const ease = 1 - Math.pow(1 - enter, 3);
  const slide = (1 - ease) * 160 * s;

  const cx = W * 0.5 + slide, cy = H * 0.52;
  const cw = 980 * s, ch = 480 * s;
  const tilt = -0.012 + (rand(idx * 3.1 + 1) - 0.5) * 0.03;

  ctx.save();
  ctx.globalAlpha = ease;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(tilt);

  // worn deckled-edge panel outline (deterministic jitter, stable across frames)
  const seg = 28;
  ctx.beginPath();
  for (let i = 0; i <= seg; i++) {
    const tt = i / seg;
    const px = -cw / 2 + tt * cw;
    const jitter = (rand(idx * 50 + i) - 0.5) * 5 * s;
    if (i === 0) ctx.moveTo(px, -ch / 2 + jitter); else ctx.lineTo(px, -ch / 2 + jitter);
  }
  for (let i = 0; i <= seg; i++) {
    const tt = i / seg;
    const py = -ch / 2 + tt * ch;
    const jitter = (rand(idx * 71 + i) - 0.5) * 5 * s;
    ctx.lineTo(cw / 2 + jitter, py);
  }
  for (let i = 0; i <= seg; i++) {
    const tt = i / seg;
    const px = cw / 2 - tt * cw;
    const jitter = (rand(idx * 33 + i) - 0.5) * 5 * s;
    ctx.lineTo(px, ch / 2 + jitter);
  }
  for (let i = 0; i <= seg; i++) {
    const tt = i / seg;
    const py = ch / 2 - tt * ch;
    const jitter = (rand(idx * 19 + i) - 0.5) * 5 * s;
    ctx.lineTo(-cw / 2 + jitter, py);
  }
  ctx.closePath();

  // drop shadow onto the dimmed scene, then the paper fill (shadow cleared right after)
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.65)';
  ctx.shadowBlur = 26 * s;
  ctx.shadowOffsetX = 10 * s;
  ctx.shadowOffsetY = 14 * s;
  ctx.fillStyle = '#c9bd9c';
  ctx.fill();
  ctx.restore();

  ctx.strokeStyle = '#2a2318';
  ctx.lineWidth = 3 * s;
  ctx.stroke();
  ctx.strokeRect(-cw / 2 + 10 * s, -ch / 2 + 10 * s, cw - 20 * s, ch - 20 * s);

  // faint paper grain + foxing spots (deterministic, no per-frame flicker)
  ctx.globalAlpha = ease * 0.07;
  ctx.fillStyle = '#000';
  for (let i = 0; i < 150; i++) {
    const x = (rand(idx * 200 + i * 2) - 0.5) * cw, y = (rand(idx * 200 + i * 2 + 1) - 0.5) * ch;
    ctx.fillRect(x, y, 1.5 * s, 1.5 * s);
  }
  ctx.globalAlpha = ease * 0.05;
  ctx.fillStyle = '#5a4020';
  for (let i = 0; i < 6; i++) {
    const x = (rand(idx * 90 + i * 3) - 0.5) * cw, y = (rand(idx * 90 + i * 3 + 1) - 0.5) * ch;
    const rr = (8 + rand(idx * 90 + i * 3 + 2) * 18) * s;
    ctx.beginPath(); ctx.arc(x, y, rr, 0, Math.PI * 2); ctx.fill();
  }
  ctx.globalAlpha = ease;

  // personnel photo block, lower-left (below the gun art, clear of it)
  drawPortrait(ctx, -cw * 0.41, ch * 0.10, cw * 0.16, ch * 0.34, s, !!card.dim);

  // gun silhouette, upper-left
  const gx = -cw * 0.25, gy = -ch * 0.22;
  drawGun(ctx, card.key, card.key === 'spsh' ? gx - 70 * s : gx, gy, s, '#241d12');
  if (card.key === 'spsh') drawAxe(ctx, gx + 110 * s, gy + 5 * s, s, '#241d12');
  if (card.key === 'aks74u') drawGrenade(ctx, gx + 185 * s, gy + 50 * s, s, '#241d12');

  // designation block, right side
  const tx = cw * 0.06, ty0 = -ch * 0.30;
  ctx.textAlign = 'left';
  ctx.fillStyle = '#241d12';
  ctx.font = `${Math.round(46 * s)}px "Russo One"`;
  ctx.fillText(card.ru, tx, ty0);
  ctx.font = `${Math.round(24 * s)}px "Oswald"`;
  ctx.fillText(card.en.toUpperCase(), tx, ty0 + 40 * s);
  ctx.font = `${Math.round(17 * s)}px "PT Mono"`;
  ctx.fillStyle = '#453a24';
  ctx.fillText(card.spec, tx, ty0 + 78 * s);
  if (card.extra) ctx.fillText(card.extra, tx, ty0 + 104 * s);

  // rule
  ctx.strokeStyle = '#5a4c30';
  ctx.lineWidth = 1.5 * s;
  ctx.beginPath();
  ctx.moveTo(tx, ty0 + 128 * s);
  ctx.lineTo(cw * 0.44, ty0 + 128 * s);
  ctx.stroke();

  // assigned to: typewriter reveal
  ctx.font = `${Math.round(17 * s)}px "Special Elite"`;
  ctx.fillStyle = '#2a2318';
  ctx.fillText('ВЫДАНО / ISSUED TO:', tx, ty0 + 160 * s);
  const full = card.person;
  const reveal = Math.max(0, Math.min(1, (ct - 0.30) / 0.9));
  const n = Math.round(full.length * reveal);
  const shown = full.slice(0, n);
  ctx.font = `${Math.round(24 * s)}px "Special Elite"`;
  ctx.fillText(shown + (reveal < 1 ? '_' : ''), tx, ty0 + 196 * s);
  if (reveal > 0.55) {
    ctx.globalAlpha = ease * Math.min(1, (reveal - 0.55) / 0.3);
    ctx.font = `italic ${Math.round(18 * s)}px "Special Elite"`;
    ctx.fillStyle = '#453a24';
    ctx.fillText(card.role, tx, ty0 + 224 * s);
    ctx.globalAlpha = ease;
  }

  // stamp near the end of the card
  const stampA = Math.max(0, Math.min(1, (ct - 1.5) / 0.25));
  stamp(ctx, cw * 0.30, ch * 0.30, 1.0, stampA, W);

  ctx.restore(); // card transform
  ctx.restore(); // alpha
}

export default {
  duration: 18,
  sceneScale: 0.62,
  post(t) {
    const base = {
      bar: 0.12, grain: 0.07, aberr: 0.0016, vignette: 0.95, bloom: 0.4,
      contrast: 1.08, sat: 0.92, temp: -0.05,
    };
    if (t < 6) return { ...base, exposure: 1.35 };
    // dim the 3D scene during the card sequence; snap-flash on each transition
    const local = t - 6, idx = Math.min(4, Math.floor(local / 2.4)), ct = local - idx * 2.4;
    const flash = ct < 0.06 ? 1 - ct / 0.06 : 0;
    return { ...base, exposure: 1.15, flash: flash * 0.8, flashColor: [1, 0.95, 0.85] };
  },
  params(t) {
    return [pumpEnvelope(t)];
  },
  textures: [
    { w: 1160, h: 1000, draw: backWallTexture },
    { w: 512, h: 512, draw: crateStencilTexture },
  ],
  overlay(ctx, t, W, H) {
    if (t < 6) return;
    const s = W / 1280;
    // dim + soften the composited 3D frame in place, so the scene reads behind the
    // card: downscale to a tiny offscreen canvas and stretch it back up. This gives a
    // cheap blur-like effect (bilinear box filtering) without a full-res CSS blur pass,
    // which is expensive in software (SwiftShader/Skia) at 1280x720 every frame.
    if (!smallCanvas) { smallCanvas = (typeof OffscreenCanvas !== 'undefined') ? new OffscreenCanvas(1, 1) : document.createElement('canvas'); smallCtx = smallCanvas.getContext('2d'); }
    const sw = 96, sh = 54;
    if (smallCanvas.width !== sw || smallCanvas.height !== sh) { smallCanvas.width = sw; smallCanvas.height = sh; }
    smallCtx.drawImage(ctx.canvas, 0, 0, sw, sh);
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(smallCanvas, 0, 0, sw, sh, 0, 0, W, H);
    ctx.fillStyle = 'rgba(6,7,9,0.42)';
    ctx.fillRect(0, 0, W, H);

    const local = t - 6, idx = Math.min(4, Math.floor(local / 2.4)), ct = local - idx * 2.4;
    drawCard(ctx, CARDS[idx], ct, s, W, H, idx);

    // shutter-close flash frame at each cut
    if (ct < 0.05) {
      ctx.fillStyle = `rgba(255,250,240,${(1 - ct / 0.05) * 0.7})`;
      ctx.fillRect(0, 0, W, H);
    }
  },
};
