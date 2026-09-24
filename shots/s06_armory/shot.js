// s06_armory — 18s. 0-6s: KS-23 on the table under the swinging bulb, pump racks ~4.5s.
// 6-18s: five character/weapon cards, Soviet technical-manual style, Canvas2D over a
// dimmed/blurred hold of the 3D scene.

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

function drawGun(ctx, key, cx, cy, s, ink) {
  ctx.save();
  ctx.fillStyle = ink;
  ctx.strokeStyle = ink;
  ctx.lineJoin = 'round';

  if (key === 'ks23') {
    // long thick barrel + slimmer tube magazine under it, blocky receiver,
    // ribbed wooden pump forend, sloped wooden stock. ~23mm bore, ~1m long.
    rrect(ctx, cx, cy, s, -6, -10, 28, 20, 3); ctx.fill();          // receiver
    rrect(ctx, cx, cy, s, 20, -6, 78, 8, 2); ctx.fill();            // barrel
    rrect(ctx, cx, cy, s, 26, 4, 58, 4.5, 1.5); ctx.fill();         // tube magazine (under barrel)
    rrect(ctx, cx, cy, s, 17, 1, 27, 9, 2.5); ctx.fill();           // pump forend (wraps tube)
    ctx.save(); ctx.strokeStyle = ink; ctx.lineWidth = 1.4 * s;
    for (let i = 0; i < 5; i++) { ctx.beginPath(); ctx.moveTo(cx + (20 + i * 5) * s, cy + 1 * s); ctx.lineTo(cx + (20 + i * 5) * s, cy + 10 * s); ctx.stroke(); }
    ctx.restore();                                                   // forend ribs
    ctx.beginPath();                                                 // wood stock, sloped
    ctx.moveTo(cx - 6 * s, cy - 3 * s);
    ctx.lineTo(cx - 46 * s, cy + 5 * s);
    ctx.lineTo(cx - 50 * s, cy + 16 * s);
    ctx.lineTo(cx - 30 * s, cy + 14 * s);
    ctx.lineTo(cx - 6 * s, cy + 9 * s);
    ctx.closePath(); ctx.fill();
    rrect(ctx, cx, cy, s, -3, 9, 8, 10, 2); ctx.fill();             // pistol grip stub
    ctx.beginPath(); ctx.ellipse(cx + 3 * s, cy + 12 * s, 5 * s, 4 * s, 0, 0, Math.PI * 2); ctx.lineWidth = 1.8 * s; ctx.stroke(); // trigger guard
    ctx.restore();
    return;
  }

  if (key === 'aks74u') {
    // short barrel + bulbous muzzle booster, gas block/front sight, receiver,
    // curved forward-sweeping magazine, pistol grip, extended skeleton stock.
    rrect(ctx, cx, cy, s, -32, -6.5, 26, 3, 1); ctx.fill();          // stock tube
    ctx.save(); ctx.lineWidth = 2.3 * s;                              // wire buttplate loop
    ctx.strokeRect(cx + -37 * s, cy + -9 * s, 4 * s, 13 * s);
    ctx.restore();
    rrect(ctx, cx, cy, s, -8, -9, 19, 12, 2.5); ctx.fill();          // receiver
    rrect(ctx, cx, cy, s, 10, -3, 13, 5.5, 1.5); ctx.fill();         // handguard
    rrect(ctx, cx, cy, s, 10, -6.5, 25, 3.2, 1); ctx.fill();         // barrel
    rrect(ctx, cx, cy, s, 33, -8, 12, 5.5, 2.2); ctx.fill();         // muzzle booster
    rrect(ctx, cx, cy, s, 18, -10, 6, 4, 1); ctx.fill();             // front sight / gas block
    rrect(ctx, cx, cy, s, -7, -12, 5, 3, 1); ctx.fill();             // rear sight
    ctx.save(); ctx.translate(cx - 3 * s, cy + 2 * s); ctx.rotate(0.35);
    ctx.beginPath(); ctx.roundRect(-3 * s, 0, 6.5 * s, 15 * s, 2 * s); ctx.fill(); ctx.restore(); // pistol grip
    ctx.beginPath(); ctx.ellipse(cx + 2 * s, cy + 5 * s, 4.5 * s, 3.2 * s, 0, 0, Math.PI * 2); ctx.lineWidth = 1.8 * s; ctx.stroke(); // trigger guard
    ctx.beginPath();                                                  // curved 30-rd magazine, sweeping forward
    ctx.moveTo(cx + 0 * s, cy + 2 * s);
    ctx.bezierCurveTo(cx + 18 * s, cy + 8 * s, cx + 20 * s, cy + 20 * s, cx + 13 * s, cy + 28 * s);
    ctx.bezierCurveTo(cx + 10 * s, cy + 18 * s, cx + 4 * s, cy + 10 * s, cx - 4 * s, cy + 7 * s);
    ctx.closePath(); ctx.fill();
    ctx.restore();
    return;
  }

  if (key === 'ppsh41') {
    // perforated barrel jacket with slanted muzzle brake, wooden rifle stock,
    // large 71-round drum magazine.
    ctx.beginPath();
    ctx.moveTo(cx + 68 * s, cy - 14 * s);
    ctx.lineTo(cx + 75 * s, cy - 18 * s);
    ctx.lineTo(cx + 75 * s, cy - 2 * s);
    ctx.lineTo(cx + 68 * s, cy - 2 * s);
    ctx.closePath(); ctx.fill();                                     // slanted muzzle brake
    rrect(ctx, cx, cy, s, 25, -14, 43, 12, 2); ctx.fill();           // barrel jacket
    ctx.save(); ctx.globalCompositeOperation = 'destination-out';
    for (let i = 0; i < 7; i++) { ctx.beginPath(); ctx.arc(cx + (30 + i * 6) * s, cy - 8 * s, 1.7 * s, 0, Math.PI * 2); ctx.fill(); }
    ctx.restore();
    ctx.beginPath();                                                  // full wood stock, comb + butt
    ctx.moveTo(cx + 25 * s, cy - 10 * s);
    ctx.lineTo(cx - 10 * s, cy - 8 * s);
    ctx.lineTo(cx - 42 * s, cy - 3 * s);
    ctx.lineTo(cx - 58 * s, cy + 3 * s);
    ctx.lineTo(cx - 58 * s, cy + 17 * s);
    ctx.lineTo(cx - 16 * s, cy + 19 * s);
    ctx.lineTo(cx + 4 * s, cy + 6 * s);
    ctx.lineTo(cx + 25 * s, cy - 1 * s);
    ctx.closePath(); ctx.fill();
    ctx.beginPath(); ctx.arc(cx + 3 * s, cy + 17 * s, 15 * s, 0, Math.PI * 2); ctx.fill(); // drum magazine
    ctx.restore();
    return;
  }

  if (key === 'spsh') {
    // stubby single-shot break-action flare pistol: thick short barrel, chunky
    // frame, hammer spur, raked grip.
    rrect(ctx, cx, cy, s, 4, -14, 26, 9, 2.5); ctx.fill();           // fat 26mm barrel
    rrect(ctx, cx, cy, s, -8, -13, 14, 8, 2); ctx.fill();            // frame
    ctx.beginPath(); ctx.moveTo(cx - 8 * s, cy - 13 * s); ctx.lineTo(cx - 13 * s, cy - 15 * s); ctx.lineTo(cx - 9 * s, cy - 9 * s); ctx.closePath(); ctx.fill(); // hammer spur
    ctx.save(); ctx.translate(cx - 6 * s, cy - 5 * s); ctx.rotate(0.55);
    ctx.beginPath(); ctx.roundRect(-4 * s, 0, 8 * s, 20 * s, 2 * s); ctx.fill(); ctx.restore(); // grip
    ctx.beginPath(); ctx.ellipse(cx - 1 * s, cy + 4 * s, 5 * s, 3.5 * s, 0, 0, Math.PI * 2); ctx.lineWidth = 1.8 * s; ctx.stroke();
    ctx.restore();
    return;
  }

  if (key === 'pm') {
    // compact blowback pistol: blocky slide, exposed hammer spur, short grip.
    rrect(ctx, cx, cy, s, -6, -9, 40, 7, 1.5); ctx.fill();           // slide + barrel
    ctx.beginPath(); ctx.moveTo(cx - 6 * s, cy - 9 * s); ctx.lineTo(cx - 11 * s, cy - 11 * s); ctx.lineTo(cx - 8 * s, cy - 5 * s); ctx.closePath(); ctx.fill(); // hammer spur
    rrect(ctx, cx, cy, s, -9, -3, 13, 6, 1.5); ctx.fill();           // frame / trigger guard block
    ctx.save(); ctx.translate(cx - 7 * s, cy + 2 * s); ctx.rotate(0.14);
    ctx.beginPath(); ctx.roundRect(-4 * s, 0, 8 * s, 15 * s, 2 * s); ctx.fill(); ctx.restore(); // grip
    ctx.beginPath(); ctx.ellipse(cx + 4 * s, cy + 3 * s, 4 * s, 3 * s, 0, 0, Math.PI * 2); ctx.lineWidth = 1.6 * s; ctx.stroke();
    ctx.restore();
    return;
  }
  ctx.restore();
}

function drawGrenade(ctx, cx, cy, s, ink) {
  ctx.save();
  ctx.fillStyle = ink;
  ctx.strokeStyle = ink;
  // RGD-5: segmented egg-shaped body
  ctx.beginPath();
  ctx.ellipse(cx, cy + 6 * s, 11 * s, 14 * s, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(0,0,0,0.35)';
  ctx.lineWidth = 1 * s;
  ctx.beginPath(); ctx.moveTo(cx - 11 * s, cy + 6 * s); ctx.lineTo(cx + 11 * s, cy + 6 * s); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx, cy - 8 * s); ctx.lineTo(cx, cy + 20 * s); ctx.stroke();
  // fuse assembly + lever on top
  ctx.fillStyle = ink;
  ctx.fillRect(cx - 4 * s, cy - 16 * s, 8 * s, 9 * s);
  ctx.beginPath();
  ctx.moveTo(cx + 4 * s, cy - 15 * s);
  ctx.lineTo(cx + 13 * s, cy - 17 * s);
  ctx.lineTo(cx + 13 * s, cy - 12 * s);
  ctx.lineTo(cx + 4 * s, cy - 10 * s);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawAxe(ctx, cx, cy, s, ink) {
  ctx.save();
  ctx.fillStyle = ink;
  ctx.strokeStyle = ink;
  ctx.lineCap = 'round';
  // handle, angled
  ctx.lineWidth = 4 * s;
  ctx.beginPath();
  ctx.moveTo(cx - 8 * s, cy + 46 * s);
  ctx.lineTo(cx + 10 * s, cy - 34 * s);
  ctx.stroke();
  // axe head: curved bit on one side, small poll on the other
  ctx.beginPath();
  ctx.moveTo(cx + 10 * s, cy - 34 * s);
  ctx.quadraticCurveTo(cx + 40 * s, cy - 40 * s, cx + 46 * s, cy - 18 * s);
  ctx.quadraticCurveTo(cx + 28 * s, cy - 12 * s, cx + 6 * s, cy - 18 * s);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(cx + 10 * s, cy - 34 * s);
  ctx.lineTo(cx - 8 * s, cy - 30 * s);
  ctx.lineTo(cx - 6 * s, cy - 18 * s);
  ctx.lineTo(cx + 6 * s, cy - 18 * s);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
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
  const gscale = card.key === 'ks23' ? 2.5 * s : card.key === 'pm' ? 4.0 * s : 3.1 * s;
  drawGun(ctx, card.key, gx, gy, gscale, '#241d12');
  if (card.key === 'spsh') drawAxe(ctx, gx + 120 * s, gy + 20 * s, 1.0 * s, '#241d12');
  if (card.key === 'aks74u') drawGrenade(ctx, gx + 145 * s, gy + 40 * s, 1.4 * s, '#241d12');

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
    if (t < 6) return { ...base, exposure: 1.5 };
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
    // blur + dim the composited 3D frame in place, so the scene reads behind the card
    try {
      ctx.filter = 'blur(' + Math.round(14 * s) + 'px) brightness(0.8) saturate(0.7)';
      ctx.drawImage(ctx.canvas, 0, 0);
      ctx.filter = 'none';
    } catch (e) { /* canvas filter unsupported: fall back to a flat dim */ }
    ctx.fillStyle = 'rgba(6,7,9,0.50)';
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
